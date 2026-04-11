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
# INSTALL ARGO CD
# ============================================================================

section "Installing Argo CD"

run_step "Adding Argo CD Helm repository" \
  helm repo add argo https://argoproj.github.io/argo-helm --kube-context "$CONTEXT_NAME"

run_step "Updating Helm repositories" \
  helm repo update --kube-context "$CONTEXT_NAME"

run_step "Installing Argo CD (core chart)" \
  helm upgrade --install "$ARGOCD_RELEASE" argo/argo-cd \
    --kube-context "$CONTEXT_NAME" \
    --namespace "$ARGOCD_NS" \
    --create-namespace \
    --wait \
    --timeout=5m

run_step "Migrating to custom Argo CD chart" \
  helm upgrade --install "$ARGOCD_RELEASE" "$ARGOCD_CHART_DIR" \
    --kube-context "$CONTEXT_NAME" \
    --namespace "$ARGOCD_NS" \
    --wait \
    --dependency-update \
    --timeout=5m

# ============================================================================
# CONFIGURE COREDNS
# ============================================================================

section "Configuring CoreDNS (nip.io → Traefik)"

TRAEFIK_NS="networking"
TRAEFIK_SVC="traefik"

run_step "Waiting for Traefik service (may take a few minutes while ArgoCD deploys apps)" \
  bash -c "
    for i in {1..90}; do
      kubectl --context '$CONTEXT_NAME' -n '$TRAEFIK_NS' get service '$TRAEFIK_SVC' >/dev/null 2>&1 && exit 0
      sleep 2
    done
    echo 'Timed out after 180s waiting for service/$TRAEFIK_SVC in namespace $TRAEFIK_NS'
    echo ''
    echo 'Namespace status:'
    kubectl --context '$CONTEXT_NAME' get namespace '$TRAEFIK_NS' 2>&1 || echo 'Namespace $TRAEFIK_NS does not exist yet'
    echo ''
    echo 'ArgoCD app status:'
    kubectl --context '$CONTEXT_NAME' -n '$ARGOCD_NS' get applications.argoproj.io 2>&1 || echo 'No ArgoCD applications found'
    exit 1
  "

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
fi
# ============================================================================
# WAIT FOR LLDAP SECRETS
# ============================================================================

section "Waiting for Authentication Provider"

LLDAP_NS="auth"
LLDAP_SECRETS=("maintainer" "user")

for SECRET in "${LLDAP_SECRETS[@]}"; do
  run_step "Waiting for '${SECRET}' credentials" \
    bash -c "
      for i in {1..150}; do
        kubectl --context '$CONTEXT_NAME' -n '$LLDAP_NS' get secret 'lldap-${SECRET}-credentials' >/dev/null 2>&1 && exit 0
        sleep 2
      done
      echo 'Timed out after 300s waiting for secret/lldap-${SECRET}-credentials in namespace $LLDAP_NS'
      echo ''
      echo 'Pods in $LLDAP_NS:'
      kubectl --context '$CONTEXT_NAME' -n '$LLDAP_NS' get pods 2>&1
      echo ''
      echo 'Events in $LLDAP_NS (last 10):'
      kubectl --context '$CONTEXT_NAME' -n '$LLDAP_NS' get events --sort-by=.lastTimestamp 2>&1 | tail -10
      exit 1
    "
done

run_step "Waiting for Authelia to be Ready" \
  bash -c "
    for i in {1..150}; do
      READY=\$(kubectl --context '$CONTEXT_NAME' -n '$LLDAP_NS' get pods -l app.kubernetes.io/name=authelia \
        -o jsonpath='{.items[*].status.conditions[?(@.type==\"Ready\")].status}' 2>/dev/null)

      if [[ \"\$READY\" =~ ^(True|true)$ ]]; then
        exit 0
      fi

      sleep 2
    done

    echo 'Timed out after 300s waiting for Authelia pod to become Ready'
    echo ''
    echo 'Authelia pods:'
    kubectl --context '$CONTEXT_NAME' -n '$LLDAP_NS' get pods -l app.kubernetes.io/name=authelia 2>&1
    echo ''
    echo 'Authelia pod logs (last 20 lines):'
    kubectl --context '$CONTEXT_NAME' -n '$LLDAP_NS' logs -l app.kubernetes.io/name=authelia --tail=20 2>&1
    exit 1
  "


# ============================================================================
# FINAL INFO
# ============================================================================

bash cluster/show-info.sh
