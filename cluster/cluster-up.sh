#!/usr/bin/env bash
set -euo pipefail

# Source common formatting functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# ============================================================================
# CONFIG
# ============================================================================

CLUSTER_NAME="${CLUSTER_NAME:-ldp}"
CONTEXT_NAME="kind-${CLUSTER_NAME}"
KIND_CFG="${KIND_CFG:-cluster/cluster-config.yaml}"
ARGOCD_NS="${ARGOCD_NS:-orchestration}"
ARGOCD_CHART_DIR="${CHART_DIR:-platform-apps/orchestration/argocd}"
ARGOCD_RELEASE="${ARGOCD_RELEASE:-argocd}"
APPSET_FILE="${APPSET_FILE:-${ARGOCD_CHART_DIR}/templates/applicationsets-platform.yaml}"


# ============================================================================
# DETECT CONTAINER ENGINE & CHECK TOOLS
# ============================================================================

detect_container_engine
check_required_tools "kind" "kubectl" "helm"
check_port_availability 80 443 9000
check_available_resources


# ============================================================================
# CREATE KIND CLUSTER
# ============================================================================

section "Creating Kind Cluster"

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  ok "Cluster '$CLUSTER_NAME' already exists"
else
  run_step "Creating cluster '$CLUSTER_NAME'" \
    kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CFG"
fi

# Set kubectl context to the Kind cluster for safety
run_step "Setting kubectl context to '$CONTEXT_NAME'" \
  kubectl config use-context "$CONTEXT_NAME"


# ============================================================================
# WAIT FOR CLUSTER DNS
# ============================================================================

section "Waiting for Cluster DNS"

run_step "Waiting for CoreDNS to resolve external hosts" \
  bash -c "
    for i in {1..30}; do
      kubectl --context '$CONTEXT_NAME' run dns-check --rm -i --restart=Never \
        --image=busybox -- nslookup github.com >/dev/null 2>&1 && exit 0
      sleep 2
    done
    echo 'DNS still not resolving after 60s'
    exit 1
  "


# ============================================================================
# INSTALL ARGO CD
# ============================================================================

section "Installing Argo CD"

run_step "Installing Argo CD (without ApplicationSets)" \
  helm upgrade --install "$ARGOCD_RELEASE" "$ARGOCD_CHART_DIR" \
    --kube-context "$CONTEXT_NAME" \
    --namespace "$ARGOCD_NS" \
    --create-namespace \
    --set platform.claims.enabled=false \
    --set platform.applicationSets.enabled=false \
    --dependency-update \
    --wait \
    --timeout=5m

run_step "Waiting for repo-server DNS resolution" \
  bash -c "
    POD=\$(kubectl --context '$CONTEXT_NAME' -n '$ARGOCD_NS' get pod \
      -l app.kubernetes.io/component=repo-server -o jsonpath='{.items[0].metadata.name}')
    for i in {1..30}; do
      kubectl --context '$CONTEXT_NAME' -n '$ARGOCD_NS' exec \"\$POD\" -- \
        bash -c 'getent hosts github.com' >/dev/null 2>&1 && exit 0
      sleep 2
    done
    echo 'repo-server DNS not resolving after 60s'
    exit 1
  "

run_step "Enabling ApplicationSets" \
  helm upgrade --install "$ARGOCD_RELEASE" "$ARGOCD_CHART_DIR" \
    --kube-context "$CONTEXT_NAME" \
    --namespace "$ARGOCD_NS" \
    --set platform.claims.enabled=false \
    --timeout=5m

# ============================================================================
# CONFIGURE COREDNS
# ============================================================================

section "Configuring CoreDNS (nip.io → Traefik)"

TRAEFIK_NS="networking"
TRAEFIK_SVC="traefik"

wait_for "Waiting for Traefik service (may take a few minutes while ArgoCD deploys apps)" 180 \
  kubectl --context "$CONTEXT_NAME" -n "$TRAEFIK_NS" get service "$TRAEFIK_SVC"

TRAEFIK_IP="$(kubectl --context "$CONTEXT_NAME" -n "$TRAEFIK_NS" get service "$TRAEFIK_SVC" -o jsonpath='{.spec.clusterIP}')"

# Check if CoreDNS is already patched to avoid duplicate injection
if kubectl --context "$CONTEXT_NAME" get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' 2>/dev/null | grep -q "127-0-0-1.nip.io"; then
  ok "CoreDNS already patched for nip.io"
else
  run_step "Patching CoreDNS config" \
    bash -c "
      kubectl --context '$CONTEXT_NAME' get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' |
        awk -v traefik_ip='$TRAEFIK_IP' '
          /^\.:[0-9]+ \{/ {
            print \$0
            print \"    hosts {\"
            print \"      \" traefik_ip \" 127-0-0-1.nip.io\"
            print \"      fallthrough\"
            print \"    }\"
            # Use rewrite block with answer auto to rewrite response name back to original
            # This fixes Node.js getaddrinfo which rejects responses where answer name != query name
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

  run_step "Waiting for CoreDNS to be ready" \
    kubectl --context "$CONTEXT_NAME" rollout status deployment/coredns -n kube-system --timeout=60s
fi
# ============================================================================
# WAIT FOR LLDAP SECRETS
# ============================================================================

section "Waiting for Authentication Provider"

LLDAP_NS="auth"

wait_for "Waiting for 'maintainer' credentials" 300 \
  kubectl --context "$CONTEXT_NAME" -n "$LLDAP_NS" get secret lldap-maintainer-credentials

wait_for "Waiting for 'user' credentials" 300 \
  kubectl --context "$CONTEXT_NAME" -n "$LLDAP_NS" get secret lldap-user-credentials

wait_for "Waiting for Authelia to be Ready" 300 \
  kubectl --context "$CONTEXT_NAME" -n "$LLDAP_NS" wait --for=condition=Ready pod -l app.kubernetes.io/name=authelia --timeout=1s


# ============================================================================
# FINAL INFO
# ============================================================================

bash cluster/show-info.sh
