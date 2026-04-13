#!/usr/bin/env bash
set -euo pipefail

# Source common formatting functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# ============================================================================
# CONFIG
# ============================================================================

KIND_CFG="${KIND_CFG:-cluster/cluster-config.yaml}"
ARGOCD_NS="${ARGOCD_NS:-orchestration}"
ARGOCD_CHART_DIR="${CHART_DIR:-platform-apps/orchestration/argocd}"
ARGOCD_RELEASE="${ARGOCD_RELEASE:-argocd}"

TOTAL_STEPS=9
LDP_START_TS=$(date +%s)

# ============================================================================
# COREDNS PATCHING FUNCTION
# ============================================================================

# Patches CoreDNS to route *.nip.io traffic to Traefik inside the cluster.
# Uses a rewrite rule so Node.js getaddrinfo accepts the response name.
patch_coredns_for_nip_io() {
  local traefik_ns="$1"
  local traefik_svc="$2"

  local traefik_ip
  traefik_ip="$(kubectl --context "$CONTEXT_NAME" -n "$traefik_ns" get service "$traefik_svc" -o jsonpath='{.spec.clusterIP}')"

  if kubectl --context "$CONTEXT_NAME" get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' 2>/dev/null | grep -q "127-0-0-1.nip.io"; then
    ok "CoreDNS already patched for nip.io"
    return 0
  fi

  run_step "Patching CoreDNS for nip.io resolution" \
    bash -c "
      kubectl --context '$CONTEXT_NAME' get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' |
        awk -v traefik_ip='$traefik_ip' '
          /^\.:[0-9]+ \{/ {
            print \$0
            print \"    hosts {\"
            print \"      \" traefik_ip \" 127-0-0-1.nip.io\"
            print \"      fallthrough\"
            print \"    }\"
            print \"    rewrite stop {\"
            print \"      name regex (.+)-127-0-0-1\\\\.nip\\\\.io 127-0-0-1.nip.io\"
            print \"      answer auto\"
            print \"    }\"
            next
          }
          { print }
        ' > /tmp/coredns-corefile.txt

      kubectl --context '$CONTEXT_NAME' create configmap coredns --from-file=Corefile=/tmp/coredns-corefile.txt \
        --dry-run=client -o yaml |
        kubectl --context '$CONTEXT_NAME' apply -n kube-system -f -

      kubectl --context '$CONTEXT_NAME' rollout restart deployment/coredns -n kube-system
    "

  wait_for 60 \
    "CoreDNS to be ready" "kubectl --context '$CONTEXT_NAME' -n kube-system rollout status deployment/coredns --timeout=1s"

  wait_for 60 \
    "DNS to stabilize in repo-server" "kubectl --context '$CONTEXT_NAME' -n '$ARGOCD_NS' exec deploy/argocd-repo-server -- getent hosts github.com"
}


# ============================================================================
# [1/9] PREFLIGHT CHECKS
# ============================================================================

step 1 $TOTAL_STEPS "Preflight Checks"

detect_container_engine
check_required_tools "kind" "kubectl" "helm"
check_port_availability 80 443 9000
check_available_resources


# ============================================================================
# [2/9] CREATE KIND CLUSTER
# ============================================================================

step 2 $TOTAL_STEPS "Creating Kind Cluster"

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  ok "Cluster '$CLUSTER_NAME' already exists"
else
  run_step "Creating cluster '$CLUSTER_NAME'" \
    kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CFG"
fi

# Set kubectl context to the Kind cluster for safety
run_step "Setting kubectl context to '$CONTEXT_NAME'" \
  kubectl config use-context "$CONTEXT_NAME"

# A stale dns-check pod from a previous interrupted run (kubectl run --rm -i
# only cleans up on graceful kubectl exit) will block every retry with
# "already exists". Clear it up front so the wait below is idempotent.
kubectl --context "$CONTEXT_NAME" delete pod dns-check --ignore-not-found --now >/dev/null 2>&1 || true

wait_for 60 \
  "CoreDNS to resolve external hosts" "kubectl --context '$CONTEXT_NAME' run dns-check --rm -i --restart=Never --image=busybox -- nslookup github.com"


# ============================================================================
# [3/9] INSTALL ARGO CD
# ============================================================================

step 3 $TOTAL_STEPS "Installing Argo CD"

run_step "Deploying Argo CD (without ApplicationSets)" \
  helm upgrade --install "$ARGOCD_RELEASE" "$ARGOCD_CHART_DIR" \
    --kube-context "$CONTEXT_NAME" \
    --namespace "$ARGOCD_NS" \
    --create-namespace \
    --set platform.claims.enabled=false \
    --set platform.applicationSets.enabled=false \
    --dependency-update \
    --wait \
    --timeout=5m

wait_for 60 \
  "repo-server DNS resolution" "kubectl --context '$CONTEXT_NAME' -n '$ARGOCD_NS' exec deploy/argocd-repo-server -- getent hosts github.com"

run_step "Enabling ApplicationSets" \
  helm upgrade --install "$ARGOCD_RELEASE" "$ARGOCD_CHART_DIR" \
    --kube-context "$CONTEXT_NAME" \
    --namespace "$ARGOCD_NS" \
    --set platform.claims.enabled=false \
    --timeout=5m


# ============================================================================
# DEPLOYING PLATFORM (GITOPS)
# ============================================================================
# ArgoCD will now deploy all platform apps in sync-wave order:
#   wave-1: cert-manager, external-secrets, crossplane  (CRDs & foundations)
#   wave-2: crossplane-compositions                     (XRDs & compositions)
#   wave-3: traefik, trust-manager, lldap, reloader,    (core infra)
#           kubernetes-replicator, argocd
#   wave-4: authelia, cloudnative-pg                     (OIDC & operators)
#   wave-5: gitea, kargo                                (VCS & delivery)
#   wave-6: backstage                                   (developer portal)
# ============================================================================


# ============================================================================
# [4/9] WAVE 1 — FOUNDATIONS
# ============================================================================

step 4 $TOTAL_STEPS "Wave 1: Foundations"

wait_for 180 \
  "cert-manager"     "kubectl --context '$CONTEXT_NAME' -n pki wait --for=condition=Available deployment/cert-manager --timeout=1s" \
  "external-secrets" "kubectl --context '$CONTEXT_NAME' -n secrets wait --for=condition=Available deployment/external-secrets --timeout=1s" \
  "crossplane"       "kubectl --context '$CONTEXT_NAME' -n orchestration wait --for=condition=Available deployment/crossplane --timeout=1s"


# ============================================================================
# [5/9] WAVE 2 — CROSSPLANE COMPOSITIONS
# ============================================================================

step 5 $TOTAL_STEPS "Wave 2: Crossplane Compositions"

wait_for 180 \
  "Crossplane provider-kubernetes" "kubectl --context '$CONTEXT_NAME' wait --for=condition=Healthy provider/provider-kubernetes --timeout=1s"


# ============================================================================
# [6/9] WAVE 3 — CORE INFRASTRUCTURE
# ============================================================================

step 6 $TOTAL_STEPS "Wave 3: Core Infrastructure"

TRAEFIK_NS="networking"
TRAEFIK_SVC="traefik"

wait_for 180 \
  "Traefik service" "kubectl --context '$CONTEXT_NAME' -n '$TRAEFIK_NS' get service '$TRAEFIK_SVC'" \
  "LLDAP"           "kubectl --context '$CONTEXT_NAME' -n auth wait --for=condition=Ready pod -l app.kubernetes.io/name=lldap-chart --timeout=1s"

# Configure CoreDNS to route *.nip.io traffic to Traefik inside the cluster
patch_coredns_for_nip_io "$TRAEFIK_NS" "$TRAEFIK_SVC"


# ============================================================================
# [7/9] WAVE 4 — AUTHENTICATION & OPERATORS
# ============================================================================

step 7 $TOTAL_STEPS "Wave 4: Authentication & Operators"

wait_for 300 \
  "Authelia" "kubectl --context '$CONTEXT_NAME' -n auth wait --for=condition=Ready pod -l app.kubernetes.io/name=authelia --timeout=1s"


# ============================================================================
# [8/9] WAVE 5 — VERSION CONTROL & DELIVERY
# ============================================================================

step 8 $TOTAL_STEPS "Wave 5: Version Control & Delivery"

wait_for 300 \
  "Gitea" "kubectl --context '$CONTEXT_NAME' -n vcs wait --for=condition=Ready pod -l app.kubernetes.io/name=gitea --timeout=1s"


# ============================================================================
# [9/9] WAVE 6 — DEVELOPER PORTAL
# ============================================================================

step 9 $TOTAL_STEPS "Wave 6: Developer Portal"

wait_for 300 \
  "Backstage" "kubectl --context '$CONTEXT_NAME' -n portal wait --for=condition=Ready pod -l app.kubernetes.io/name=backstage --timeout=1s"


# ============================================================================
# DONE
# ============================================================================

LDP_END_TS=$(date +%s)
LDP_DURATION=$(( LDP_END_TS - LDP_START_TS ))
LDP_MINUTES=$(( LDP_DURATION / 60 ))
LDP_SECONDS=$(( LDP_DURATION % 60 ))

printf "\n${GREEN}${BOLD}Platform ready in ${LDP_MINUTES}m${LDP_SECONDS}s${NC}\n"

bash "${SCRIPT_DIR}/show-info.sh"
