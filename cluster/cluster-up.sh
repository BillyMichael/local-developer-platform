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

TOTAL_STEPS=10
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
# NODE REGISTRY TRUST
# ============================================================================

# Lets kubelet pull images that CI pushed to the in-cluster Gitea registry.
# containerd on the kind nodes uses neither CoreDNS nor the platform CA, so each
# node gets a /etc/hosts entry pointing the vcs hostname at Traefik's ClusterIP
# and a containerd hosts.toml carrying the CA (config_path is set in
# cluster-config.yaml). Docker rewrites /etc/hosts when a node container
# restarts, which is why this runs on every `make up`, not only on create.
REGISTRY_HOST="vcs-127-0-0-1.nip.io"

_trust_registry_on_node() {
  local node="$1" host="$2" ip="$3" ca_file="$4"
  local dir="/etc/containerd/certs.d/${host}"

  "$CE" exec -i "$node" sh -c "mkdir -p '$dir' && cat > '$dir/ca.crt'" < "$ca_file"

  "$CE" exec -i "$node" sh -c "cat > '$dir/hosts.toml'" <<EOF
server = "https://${host}"

[host."https://${host}"]
  capabilities = ["pull", "resolve"]
  ca = "${dir}/ca.crt"
EOF

  # /etc/hosts is a bind mount: rewrite in place rather than sed -i (rename fails)
  "$CE" exec "$node" sh -c \
    "grep -v ' ${host}\$' /etc/hosts > /tmp/hosts.new; echo '${ip} ${host}' >> /tmp/hosts.new; cat /tmp/hosts.new > /etc/hosts"
}

trust_registry_on_nodes() {
  local traefik_ns="$1"
  local traefik_svc="$2"

  wait_for 120 \
    "platform CA" "kubectl --context '$CONTEXT_NAME' -n pki get secret root-ca"

  local traefik_ip ca_file
  traefik_ip="$(kubectl --context "$CONTEXT_NAME" -n "$traefik_ns" get service "$traefik_svc" -o jsonpath='{.spec.clusterIP}')"
  ca_file=$(mktemp "/tmp/ldp-ca-XXXXXX")
  kubectl --context "$CONTEXT_NAME" -n pki get secret root-ca -o jsonpath='{.data.tls\.crt}' | base64 -d > "$ca_file"

  local node
  for node in $(kind get nodes --name "$CLUSTER_NAME"); do
    run_step "Trusting Gitea registry on $node" \
      _trust_registry_on_node "$node" "$REGISTRY_HOST" "$traefik_ip" "$ca_file"
  done
  rm -f "$ca_file"
}


# ============================================================================
# [1/10] PREFLIGHT CHECKS
# ============================================================================

step 1 $TOTAL_STEPS "Preflight Checks"

preflight


# ============================================================================
# [2/10] CREATE KIND CLUSTER
# ============================================================================

step 2 $TOTAL_STEPS "Creating Kind Cluster"

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  ok "Cluster '$CLUSTER_NAME' already exists"

  # An engine/VM restart leaves kind's node containers stopped (they carry no
  # restart policy under podman), and the kubeconfig entry may be gone too.
  stopped_nodes=$("$CE" ps -a --filter "name=${CLUSTER_NAME}-" --filter status=exited --format '{{.Names}}')
  if [ -n "$stopped_nodes" ]; then
    run_step "Starting stopped cluster nodes" "$CE" start $stopped_nodes
  fi

  run_step "Refreshing kubeconfig for '$CLUSTER_NAME'" \
    kind export kubeconfig --name "$CLUSTER_NAME"
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
# [3/10] OPTIONAL CREDENTIALS
# ============================================================================
# Both prompts are skipped when the matching env var is set or stdin is not a
# terminal, so unattended runs never block here.

step 3 $TOTAL_STEPS "Optional Credentials"

# Optional GitHub token for Backstage's catalog reads of this repo.
# Anonymous GitHub API access is capped at 60 req/hr, which the catalog's
# 5-minute refresh exhausts. Honours $GITHUB_TOKEN, prompts otherwise.
if kubectl --context "$CONTEXT_NAME" -n portal get secret github-token >/dev/null 2>&1; then
  ok "GitHub token secret already exists"
else
  gh_token="${GITHUB_TOKEN:-}"
  if [ -z "$gh_token" ] && [ -t 0 ]; then
    printf "  ${BLUE}?${NC}  Provide a GitHub token for Backstage catalog reads? [y/N] "
    read -r gh_reply || gh_reply=""
    if [[ "$gh_reply" =~ ^[Yy] ]]; then
      printf "  ${BLUE}➜${NC}  Enter token (input hidden): "
      read -rs gh_token || gh_token=""
      printf "\n"
    fi
  fi
  if [ -n "$gh_token" ]; then
    kubectl --context "$CONTEXT_NAME" create namespace portal --dry-run=client -o yaml |
      kubectl --context "$CONTEXT_NAME" apply -f - >/dev/null
    kubectl --context "$CONTEXT_NAME" -n portal create secret generic github-token \
      --from-literal=token="$gh_token" >/dev/null
    ok "GitHub token stored as secret 'github-token' in namespace 'portal'"
  else
    warn "No GitHub token provided; GitHub reads run anonymously (60 req/hr)"
  fi
  unset gh_token
fi

# Anthropic API key for kagent agents. Honours $ANTHROPIC_API_KEY, prompts
# otherwise. Always created (possibly empty) so agent pods can start; the
# annotations let tenant namespaces pull a copy via kubernetes-replicator.
if kubectl --context "$CONTEXT_NAME" -n devtools get secret kagent-anthropic >/dev/null 2>&1; then
  ok "Anthropic API key secret already exists"
else
  anthropic_key="${ANTHROPIC_API_KEY:-}"
  if [ -z "$anthropic_key" ] && [ -t 0 ]; then
    printf "  ${BLUE}?${NC}  Provide an Anthropic API key for kagent agents? [y/N] "
    read -r ak_reply || ak_reply=""
    if [[ "$ak_reply" =~ ^[Yy] ]]; then
      printf "  ${BLUE}➜${NC}  Enter key (input hidden): "
      read -rs anthropic_key || anthropic_key=""
      printf "\n"
    fi
  fi
  kubectl --context "$CONTEXT_NAME" create namespace devtools --dry-run=client -o yaml |
    kubectl --context "$CONTEXT_NAME" apply -f - >/dev/null
  kubectl --context "$CONTEXT_NAME" -n devtools create secret generic kagent-anthropic \
    --from-literal=ANTHROPIC_API_KEY="$anthropic_key" >/dev/null
  kubectl --context "$CONTEXT_NAME" -n devtools annotate secret kagent-anthropic \
    replicator.v1.mittwald.de/replication-allowed="true" \
    replicator.v1.mittwald.de/replication-allowed-namespaces=".*" >/dev/null
  if [ -n "$anthropic_key" ]; then
    ok "Anthropic API key stored as secret 'kagent-anthropic' in namespace 'devtools'"
  else
    warn "No Anthropic API key provided; agents will fail until 'kagent-anthropic' in 'devtools' is populated"
  fi
  unset anthropic_key
fi


# ============================================================================
# [4/10] INSTALL ARGO CD
# ============================================================================

step 4 $TOTAL_STEPS "Installing Argo CD"

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
#   wave-1: cert-manager, external-secrets, crossplane, (CRDs & foundations)
#           kagent-crds
#   wave-2: crossplane-compositions                     (XRDs & compositions)
#   wave-3: traefik, trust-manager, lldap, reloader,    (core infra)
#           kubernetes-replicator, argocd
#   wave-4: authelia, cloudnative-pg                     (OIDC & operators)
#   wave-5: gitea, kargo                                (VCS & delivery)
#   wave-6: backstage, gitea-actions, kagent            (portal, CI runner, agents)
# ============================================================================


# ============================================================================
# [5/10] WAVE 1 — FOUNDATIONS
# ============================================================================

step 5 $TOTAL_STEPS "Wave 1: Foundations"

wait_for 180 \
  "cert-manager"     "kubectl --context '$CONTEXT_NAME' -n pki wait --for=condition=Available deployment/cert-manager --timeout=1s" \
  "external-secrets" "kubectl --context '$CONTEXT_NAME' -n secrets wait --for=condition=Available deployment/external-secrets --timeout=1s" \
  "crossplane"       "kubectl --context '$CONTEXT_NAME' -n orchestration wait --for=condition=Available deployment/crossplane --timeout=1s"


# ============================================================================
# [6/10] WAVE 2 — CROSSPLANE COMPOSITIONS
# ============================================================================

step 6 $TOTAL_STEPS "Wave 2: Crossplane Compositions"

wait_for 180 \
  "Crossplane provider-kubernetes" "kubectl --context '$CONTEXT_NAME' wait --for=condition=Healthy provider/provider-kubernetes --timeout=1s"


# ============================================================================
# [7/10] WAVE 3 — CORE INFRASTRUCTURE
# ============================================================================

step 7 $TOTAL_STEPS "Wave 3: Core Infrastructure"

TRAEFIK_NS="networking"
TRAEFIK_SVC="traefik"

wait_for 180 \
  "Traefik service" "kubectl --context '$CONTEXT_NAME' -n '$TRAEFIK_NS' get service '$TRAEFIK_SVC'" \
  "LLDAP"           "kubectl --context '$CONTEXT_NAME' -n auth wait --for=condition=Ready pod -l app.kubernetes.io/name=lldap-chart --timeout=1s"

# Configure CoreDNS to route *.nip.io traffic to Traefik inside the cluster
patch_coredns_for_nip_io "$TRAEFIK_NS" "$TRAEFIK_SVC"

# Let kubelet pull from the in-cluster Gitea registry (needs Traefik's ClusterIP and the CA)
trust_registry_on_nodes "$TRAEFIK_NS" "$TRAEFIK_SVC"


# ============================================================================
# [8/10] WAVE 4 — AUTHENTICATION & OPERATORS
# ============================================================================

step 8 $TOTAL_STEPS "Wave 4: Authentication & Operators"

wait_for 300 \
  "Authelia" "kubectl --context '$CONTEXT_NAME' -n auth wait --for=condition=Ready pod -l app.kubernetes.io/name=authelia --timeout=1s"


# ============================================================================
# [9/10] WAVE 5 — VERSION CONTROL & DELIVERY
# ============================================================================

step 9 $TOTAL_STEPS "Wave 5: Version Control & Delivery"

wait_for 300 \
  "Gitea" "kubectl --context '$CONTEXT_NAME' -n vcs wait --for=condition=Ready pod -l app.kubernetes.io/name=gitea --timeout=1s"


# ============================================================================
# [10/10] WAVE 6 — DEVELOPER PORTAL
# ============================================================================

step 10 $TOTAL_STEPS "Wave 6: Developer Portal"

wait_for 300 \
  "Backstage" "kubectl --context '$CONTEXT_NAME' -n portal wait --for=condition=Ready pod -l app.kubernetes.io/name=backstage --timeout=1s" \
  "kagent"    "kubectl --context '$CONTEXT_NAME' -n devtools wait --for=condition=Available deployment/kagent-controller --timeout=1s"


# ============================================================================
# DONE
# ============================================================================

LDP_END_TS=$(date +%s)
LDP_DURATION=$(( LDP_END_TS - LDP_START_TS ))
LDP_MINUTES=$(( LDP_DURATION / 60 ))
LDP_SECONDS=$(( LDP_DURATION % 60 ))

printf "\n${GREEN}${BOLD}Platform ready in ${LDP_MINUTES}m${LDP_SECONDS}s${NC}\n"

bash "${SCRIPT_DIR}/show-info.sh"
