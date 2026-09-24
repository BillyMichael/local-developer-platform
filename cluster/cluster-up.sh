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

TOTAL_STEPS=11

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
  for node in $(kind get nodes --name "$CLUSTER_NAME" 2>/dev/null); do
    run_step "Trusting Gitea registry on $node" \
      _trust_registry_on_node "$node" "$REGISTRY_HOST" "$traefik_ip" "$ca_file"
  done
  rm -f "$ca_file"
}


# ============================================================================
# CORPORATE CA TRUST
# ============================================================================

# Corporate networks often run a TLS-inspecting proxy (Netskope, Zscaler, ...)
# that re-signs every HTTPS connection with a private CA. The host trusts it
# through the OS keychain, but nothing inside the cluster does: the kind nodes
# (image pulls), the Argo CD repo-server (git and helm fetches) and Crossplane
# (package pulls) all fail with "x509: certificate signed by unknown authority".
#
# Any such CA is installed in three places:
#   1. each node's system trust store, so containerd trusts it
#   2. ConfigMap ldp-ca-bundle in the Argo CD namespace, holding the node's full
#      bundle (public roots + corporate CA). The Argo CD and Crossplane charts
#      mount it over /etc/ssl/certs/ca-certificates.crt, which is the one file
#      Go, GnuTLS (git) and helm all read. It is published even when no proxy
#      is found so those mounts always resolve.
#   3. ConfigMap ldp-extra-ca in the trust namespace, which trust-manager folds
#      into the platform bundle every other consumer already mounts
#
# Set LDP_EXTRA_CA_FILE to a PEM file to bypass auto-detection.
CA_BUNDLE_CM="ldp-ca-bundle"
EXTRA_CA_CM="ldp-extra-ca"
CA_PROBE_HOST="github.com"

# First readable public root store on the host; used to tell a proxy's private
# CA apart from a legitimate intermediate in the served chain.
_public_roots() {
  local f
  for f in /etc/ssl/cert.pem /etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt; do
    [ -r "$f" ] && { echo "$f"; return 0; }
  done
  return 1
}

# Writes the private CA certificates on the TLS path to CA_PROBE_HOST into $1
# and prints how many there are.
collect_extra_cas() {
  local out="$1"
  : > "$out"

  local workdir
  workdir=$(mktemp -d "/tmp/ldp-cas-XXXXXX")
  local raw="$workdir/raw.pem"

  if [ -n "${LDP_EXTRA_CA_FILE:-}" ]; then
    cat "$LDP_EXTRA_CA_FILE" > "$raw"
  elif command -v openssl >/dev/null 2>&1; then
    # Every certificate the server presents except the leaf.
    openssl s_client -showcerts -connect "${CA_PROBE_HOST}:443" -servername "$CA_PROBE_HOST" </dev/null 2>/dev/null \
      | awk '/BEGIN CERTIFICATE/{n++} n>1 && /BEGIN CERTIFICATE/,/END CERTIFICATE/' > "$raw" || true
    # Netskope's client keeps its root here on macOS; proxies do not always
    # serve their root in the chain.
    local netskope="/Library/Application Support/Netskope/STAgent/data/nscacert.pem"
    [ -r "$netskope" ] && cat "$netskope" >> "$raw"
  fi

  # Split, drop anything a public root already vouches for, dedupe.
  awk -v dir="$workdir" '/BEGIN CERTIFICATE/{n++; f=sprintf("%s/%03d.pem", dir, n)} n>0 {print > f}' "$raw"
  local roots; roots=$(_public_roots || true)
  local cert fp count=0 seen=" "
  for cert in "$workdir"/[0-9]*.pem; do
    [ -f "$cert" ] || continue
    if [ -n "$roots" ] && [ -z "${LDP_EXTRA_CA_FILE:-}" ] && openssl verify -CAfile "$roots" "$cert" >/dev/null 2>&1; then
      continue
    fi
    fp=$(openssl x509 -in "$cert" -noout -fingerprint -sha256 2>/dev/null || echo "$cert")
    case "$seen" in *" $fp "*) continue ;; esac
    seen="$seen$fp "
    cat "$cert" >> "$out"
    count=$((count + 1))
  done

  rm -rf "$workdir"
  echo "$count"
}

# One line per CA in $1: "CN=..., O=..."
describe_cas() {
  awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' "$1" \
    | awk -v cmd="openssl x509 -noout -subject" '{print | cmd} /END CERTIFICATE/{close(cmd)}' \
    | sed -e 's/^subject= *//' -e 's/.*\(CN *= *[^,]*\).*/\1/'
}

# Installs $2 into node $1's trust store. containerd only re-reads the store on
# restart, so restart it only when update-ca-certificates reports a change.
_trust_extra_ca_on_node() {
  local node="$1" ca_file="$2"
  local dest="/usr/local/share/ca-certificates/ldp-extra-ca.crt"

  "$CE" exec -i "$node" sh -c "cat > '$dest'" < "$ca_file"
  local summary
  summary=$("$CE" exec "$node" update-ca-certificates 2>&1 | grep -E '^[0-9]+ added' || true)
  echo "$summary"
  case "$summary" in
    "0 added, 0 removed"*) ;;
    *) "$CE" exec "$node" systemctl restart containerd ;;
  esac
}

trust_extra_ca_on_nodes() {
  local ca_file="$1" node
  for node in $(kind get nodes --name "$CLUSTER_NAME" 2>/dev/null); do
    run_step "Trusting corporate CA on $node" _trust_extra_ca_on_node "$node" "$ca_file"
  done
}

# Publishes the trust material as ConfigMaps (see the header comment above).
publish_ca_bundles() {
  local extra_ca_file="$1" extra_count="$2"

  local node
  node=$(kind get nodes --name "$CLUSTER_NAME" 2>/dev/null | grep -- '-control-plane$' | head -1)
  local bundle
  bundle=$(mktemp "/tmp/ldp-ca-bundle-XXXXXX")
  "$CE" exec "$node" cat /etc/ssl/certs/ca-certificates.crt > "$bundle"

  local ns
  for ns in "$ARGOCD_NS" pki; do
    kubectl --context "$CONTEXT_NAME" create namespace "$ns" --dry-run=client -o yaml |
      kubectl --context "$CONTEXT_NAME" apply -f -
  done

  kubectl --context "$CONTEXT_NAME" -n "$ARGOCD_NS" create configmap "$CA_BUNDLE_CM" \
    --from-file=ca-certificates.crt="$bundle" --dry-run=client -o yaml |
    kubectl --context "$CONTEXT_NAME" apply -f -

  if [ "$extra_count" -gt 0 ]; then
    kubectl --context "$CONTEXT_NAME" -n pki create configmap "$EXTRA_CA_CM" \
      --from-file=ca.crt="$extra_ca_file" --dry-run=client -o yaml |
      kubectl --context "$CONTEXT_NAME" label --local -f - trust.ldp.dev/extra-ca=true -o yaml |
      kubectl --context "$CONTEXT_NAME" apply -f -
  else
    kubectl --context "$CONTEXT_NAME" -n pki delete configmap "$EXTRA_CA_CM" --ignore-not-found
  fi

  rm -f "$bundle"
}


# ============================================================================
# [1/11] PREFLIGHT CHECKS
# ============================================================================

step 1 $TOTAL_STEPS "Preflight Checks"

preflight


# ============================================================================
# [2/11] CREATE KIND CLUSTER
# ============================================================================

step 2 $TOTAL_STEPS "Creating Kind Cluster"

if cluster_exists; then
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
# [3/11] CORPORATE CA TRUST
# ============================================================================

step 3 $TOTAL_STEPS "Trusting Corporate CA"

extra_ca_file=$(mktemp "/tmp/ldp-extra-ca-XXXXXX")
extra_ca_count=$(collect_extra_cas "$extra_ca_file")

if [ "$extra_ca_count" -gt 0 ]; then
  warn "TLS-inspecting proxy detected on the path to ${CA_PROBE_HOST}; trusting its CA in the cluster:"
  describe_cas "$extra_ca_file" | sed 's/^/       /'
  trust_extra_ca_on_nodes "$extra_ca_file"
else
  ok "No TLS-inspecting proxy detected; public trust roots only"
fi

run_step "Publishing CA bundle to the cluster" \
  publish_ca_bundles "$extra_ca_file" "$extra_ca_count"
rm -f "$extra_ca_file"


# ============================================================================
# [4/11] OPTIONAL CREDENTIALS
# ============================================================================
# Both prompts are skipped when the matching env var is set or stdin is not a
# terminal, so unattended runs never block here.

step 4 $TOTAL_STEPS "Optional Credentials"

# Optional GitHub token for Backstage's catalog reads of this repo.
# Anonymous GitHub API access is capped at 60 req/hr, which the catalog's
# 5-minute refresh exhausts. Honours $GITHUB_TOKEN, prompts otherwise.
if kubectl --context "$CONTEXT_NAME" -n portal get secret github-token >/dev/null 2>&1; then
  ok "GitHub token secret already exists"
else
  gh_token="$(prompt_secret "${GITHUB_TOKEN:-}" "GitHub token for Backstage catalog reads")"
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
  anthropic_key="$(prompt_secret "${ANTHROPIC_API_KEY:-}" "Anthropic API key for kagent agents")"
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
# [5/11] INSTALL ARGO CD
# ============================================================================

step 5 $TOTAL_STEPS "Installing Argo CD"

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
#   wave-4: authelia, cloudnative-pg, keda               (OIDC & operators)
#   wave-5: gitea, kargo                                (VCS & delivery)
#   wave-6: backstage, gitea-actions, kagent            (portal, CI runner, agents)
# ============================================================================


# ============================================================================
# [6/11] WAVE 1 — FOUNDATIONS
# ============================================================================

step 6 $TOTAL_STEPS "Wave 1: Foundations"

wait_for 180 \
  "cert-manager"     "kubectl --context '$CONTEXT_NAME' -n pki wait --for=condition=Available deployment/cert-manager --timeout=1s" \
  "external-secrets" "kubectl --context '$CONTEXT_NAME' -n secrets wait --for=condition=Available deployment/external-secrets --timeout=1s" \
  "crossplane"       "kubectl --context '$CONTEXT_NAME' -n orchestration wait --for=condition=Available deployment/crossplane --timeout=1s"


# ============================================================================
# [7/11] WAVE 2 — CROSSPLANE COMPOSITIONS
# ============================================================================

step 7 $TOTAL_STEPS "Wave 2: Crossplane Compositions"

wait_for 180 \
  "Crossplane provider-kubernetes" "kubectl --context '$CONTEXT_NAME' wait --for=condition=Healthy provider/provider-kubernetes --timeout=1s"


# ============================================================================
# [8/11] WAVE 3 — CORE INFRASTRUCTURE
# ============================================================================

step 8 $TOTAL_STEPS "Wave 3: Core Infrastructure"

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
# [9/11] WAVE 4 — AUTHENTICATION & OPERATORS
# ============================================================================

step 9 $TOTAL_STEPS "Wave 4: Authentication & Operators"

wait_for 300 \
  "Authelia" "kubectl --context '$CONTEXT_NAME' -n auth wait --for=condition=Ready pod -l app.kubernetes.io/name=authelia --timeout=1s"


# ============================================================================
# [10/11] WAVE 5 — VERSION CONTROL & DELIVERY
# ============================================================================

step 10 $TOTAL_STEPS "Wave 5: Version Control & Delivery"

wait_for 300 \
  "Gitea" "kubectl --context '$CONTEXT_NAME' -n vcs wait --for=condition=Ready pod -l app.kubernetes.io/name=gitea --timeout=1s"


# ============================================================================
# [11/11] WAVE 6 — DEVELOPER PORTAL
# ============================================================================

step 11 $TOTAL_STEPS "Wave 6: Developer Portal"

wait_for 300 \
  "Backstage" "kubectl --context '$CONTEXT_NAME' -n portal wait --for=condition=Ready pod -l app.kubernetes.io/name=backstage --timeout=1s" \
  "kagent"    "kubectl --context '$CONTEXT_NAME' -n devtools wait --for=condition=Available deployment/kagent-controller --timeout=1s"


# ============================================================================
# DONE
# ============================================================================

# $SECONDS: bash's count of seconds since this script started
printf "\n${GREEN}${BOLD}Platform ready in %dm%ds${NC}\n" $(( SECONDS / 60 )) $(( SECONDS % 60 ))

bash "${SCRIPT_DIR}/show-info.sh"
