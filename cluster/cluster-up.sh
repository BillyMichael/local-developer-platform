#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# --- config -------------------------------------------------------------------

KIND_CFG="${KIND_CFG:-cluster/cluster-config.yaml}"
ARGOCD_NS="${ARGOCD_NS:-orchestration}"
ARGOCD_CHART_DIR="${CHART_DIR:-platform-apps/orchestration/argocd}"
ARGOCD_RELEASE="${ARGOCD_RELEASE:-argocd}"

# Argo CD deploys this checkout: its .git directory is mounted into every node
# at LDP_GIT_MOUNT and served in-cluster by the ldp-git Deployment in the argocd
# chart, which the platform ApplicationSets read (platform.repoURL).
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
LDP_GIT_MOUNT="/ldp/repo.git"
LDP_GIT_URL="http://ldp-git.${ARGOCD_NS}.svc.cluster.local/ldp.git"

TOTAL_STEPS=11

# --- coredns ------------------------------------------------------------------

# Routes *.nip.io to Traefik inside the cluster. A rewrite rule (not a plain
# hosts entry) so Node.js getaddrinfo accepts the answer name.
patch_coredns_for_nip_io() {
  local traefik_ip="$1"

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

# --- platform source (this checkout) ------------------------------------------

# --git-common-dir so a linked worktree serves the main repository's objects
# (and its HEAD).
ldp_git_dir() {
  (cd "$REPO_DIR" && cd "$(git rev-parse --git-common-dir)" && pwd -P)
}

# kind takes absolute host paths only, so KIND_CFG carries a __LDP_GIT_DIR__
# placeholder. Bash substitution, so no sed delimiter can clash with the path.
render_kind_config() {
  local git_dir="$1" out="$2" line
  while IFS= read -r line || [ -n "$line" ]; do
    printf '%s\n' "${line//__LDP_GIT_DIR__/$git_dir}"
  done < "$KIND_CFG" > "$out"
}

# $1 is "existing" or "new": a cluster created before the mount existed needs
# recreating; a new one that lacks it means the engine VM does not share the dir.
require_checkout_mount() {
  if "$CE" exec "${CLUSTER_NAME}-control-plane" test -f "${LDP_GIT_MOUNT}/HEAD" >/dev/null 2>&1; then
    ok "Nodes see this checkout at ${LDP_GIT_MOUNT}"
    return 0
  fi
  error "The cluster nodes cannot see this checkout at ${LDP_GIT_MOUNT}."
  error "Argo CD deploys the platform from here, so nothing would sync."
  if [ "$1" = "existing" ]; then
    error "The cluster predates the mount: run 'make down && make up' to recreate it."
  else
    error "Check that your container engine shares $(ldp_git_dir) with its VM"
    error "(Docker Desktop: Settings > Resources > File sharing; Podman: 'podman machine init -v')."
  fi
  exit 1
}

# Argo CD only sees commits; uncommitted platform-apps edits are the usual
# reason a change "does not apply".
report_platform_source() {
  local branch dirty
  branch=$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
  ok "Argo CD deploys the committed HEAD of this checkout (branch: ${branch})"
  dirty=$(git -C "$REPO_DIR" status --porcelain -- platform-apps 2>/dev/null | wc -l | tr -d ' ')
  if [ "${dirty:-0}" -gt 0 ]; then
    warn "platform-apps has ${dirty} uncommitted change(s); Argo CD only sees commits"
  fi
}

# --- node registry trust ------------------------------------------------------

# containerd on the nodes uses neither CoreDNS nor the platform CA, so each node
# gets a /etc/hosts entry for the Gitea registry and a hosts.toml with the CA.
# Docker rewrites /etc/hosts when a node restarts, hence on every `make up`.
REGISTRY_HOST="vcs-127-0-0-1.nip.io"

_trust_registry_on_node() {
  local node="$1" host="$2" ip="$3" ca_file="$4"
  local dir="/etc/containerd/certs.d/${host}"

  "$CE" exec -i "$node" sh -c "mkdir -p '$dir' && cat > '$dir/ca.crt'" < "$ca_file"

  "$CE" exec -i "$node" sh -c "cat > '$dir/hosts.toml'" <<EOT
server = "https://${host}"

[host."https://${host}"]
  capabilities = ["pull", "resolve"]
  ca = "${dir}/ca.crt"
EOT

  # /etc/hosts is a bind mount: rewrite in place, sed -i's rename fails
  "$CE" exec "$node" sh -c \
    "grep -v ' ${host}\$' /etc/hosts > /tmp/hosts.new; echo '${ip} ${host}' >> /tmp/hosts.new; cat /tmp/hosts.new > /etc/hosts"
}

trust_registry_on_nodes() {
  local traefik_ip="$1"

  wait_for 120 \
    "platform CA" "kubectl --context '$CONTEXT_NAME' -n pki get secret root-ca"

  local ca_file
  ca_file=$(mktemp "/tmp/ldp-ca-XXXXXX")
  kubectl --context "$CONTEXT_NAME" -n pki get secret root-ca -o jsonpath='{.data.tls\.crt}' | base64 -d > "$ca_file"

  local node
  for node in $(kind get nodes --name "$CLUSTER_NAME" 2>/dev/null); do
    run_step "Trusting Gitea registry on $node" \
      _trust_registry_on_node "$node" "$REGISTRY_HOST" "$traefik_ip" "$ca_file"
  done
  rm -f "$ca_file"
}

# --- proxy ca trust -----------------------------------------------------------

# A TLS-inspecting proxy (Netskope, Zscaler, ...) re-signs every HTTPS
# connection with a CA only the host trusts. Its CA goes into each node's trust
# store (image pulls), the ldp-ca-bundle ConfigMap that Argo CD and Crossplane
# mount over /etc/ssl/certs/ca-certificates.crt (git, helm and package
# fetches), and ldp-extra-ca, which trust-manager folds into the platform
# bundle. LDP_EXTRA_CA_FILE bypasses detection.
CA_BUNDLE_CM="ldp-ca-bundle"
EXTRA_CA_CM="ldp-extra-ca"
CA_PROBE_HOST="github.com"

# First readable public root store; tells a proxy CA from a real intermediate.
_public_roots() {
  local f
  for f in /etc/ssl/cert.pem /etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt; do
    [ -r "$f" ] && { echo "$f"; return 0; }
  done
  return 1
}

# Writes the private CAs on the TLS path to CA_PROBE_HOST into $1; prints count.
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
    # Proxies do not always serve their root; Netskope keeps it here on macOS.
    local netskope="/Library/Application Support/Netskope/STAgent/data/nscacert.pem"
    [ -r "$netskope" ] && cat "$netskope" >> "$raw"
  fi

  # Split, drop anything a public root vouches for, dedupe by fingerprint.
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

# One "CN=..." line per certificate in $1.
describe_cas() {
  awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' "$1" \
    | awk -v cmd="openssl x509 -noout -subject" '{print | cmd} /END CERTIFICATE/{close(cmd)}' \
    | sed -e 's/^subject= *//' -e 's/.*\(CN *= *[^,]*\).*/\1/'
}

# containerd re-reads the trust store only on restart; restart it only on change.
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
    run_step "Trusting proxy CA on $node" _trust_extra_ca_on_node "$node" "$ca_file"
  done
}

# Publishes the node's full bundle (always, so the chart mounts resolve) and
# the proxy CA on its own when there is one.
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

# --- [1/11] preflight ---------------------------------------------------------

step 1 $TOTAL_STEPS "Preflight Checks"

preflight

# --- [2/11] kind cluster ------------------------------------------------------

step 2 $TOTAL_STEPS "Creating Kind Cluster"

if cluster_exists; then
  ok "Cluster '$CLUSTER_NAME' already exists"

  # An engine/VM restart leaves kind's nodes stopped (no restart policy under
  # podman) and may drop the kubeconfig entry.
  stopped_nodes=$("$CE" ps -a --filter "name=${CLUSTER_NAME}-" --filter status=exited --format '{{.Names}}')
  if [ -n "$stopped_nodes" ]; then
    run_step "Starting stopped cluster nodes" "$CE" start $stopped_nodes
  fi

  run_step "Refreshing kubeconfig for '$CLUSTER_NAME'" \
    kind export kubeconfig --name "$CLUSTER_NAME"

  require_checkout_mount existing
else
  rendered_kind_cfg=$(mktemp "/tmp/ldp-kind-config-XXXXXX")
  render_kind_config "$(ldp_git_dir)" "$rendered_kind_cfg"
  run_step "Creating cluster '$CLUSTER_NAME'" \
    kind create cluster --name "$CLUSTER_NAME" --config "$rendered_kind_cfg"
  rm -f "$rendered_kind_cfg"

  require_checkout_mount new
fi

run_step "Setting kubectl context to '$CONTEXT_NAME'" \
  kubectl config use-context "$CONTEXT_NAME"

# `kubectl run --rm` leaves the pod behind on an interrupted run and every
# retry then fails with "already exists".
kubectl --context "$CONTEXT_NAME" delete pod dns-check --ignore-not-found --now >/dev/null 2>&1 || true

wait_for 60 \
  "CoreDNS to resolve external hosts" "kubectl --context '$CONTEXT_NAME' run dns-check --rm -i --restart=Never --image=busybox -- nslookup github.com"

# --- [3/11] proxy ca ----------------------------------------------------------

step 3 $TOTAL_STEPS "Trusting TLS Proxy CA"

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

# --- [4/11] optional credentials ---------------------------------------------
# Prompts are skipped when the env var is set or stdin is not a terminal.

step 4 $TOTAL_STEPS "Optional Credentials"

# Anonymous GitHub API access (60 req/hr) is exhausted by the catalog's
# 5-minute refresh. Honours $GITHUB_TOKEN.
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

# Always created (possibly empty) so agent pods can start; the annotations let
# tenant namespaces pull a copy via kubernetes-replicator. Honours $ANTHROPIC_API_KEY.
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

# --- [5/11] argo cd -----------------------------------------------------------

step 5 $TOTAL_STEPS "Installing Argo CD"

argocd_helm=(helm upgrade --install "$ARGOCD_RELEASE" "$ARGOCD_CHART_DIR"
  --kube-context "$CONTEXT_NAME" --namespace "$ARGOCD_NS"
  --set platform.claims.enabled=false --timeout=5m)

run_step "Deploying Argo CD (without ApplicationSets)" \
  "${argocd_helm[@]}" --create-namespace --set platform.applicationSets.enabled=false --dependency-update --wait

# helm --wait already rolled out ldp-git; prove the repo-server can fetch from
# it before the ApplicationSets start generating.
wait_for 60 \
  "repo-server to read this checkout" "kubectl --context '$CONTEXT_NAME' -n '$ARGOCD_NS' exec deploy/argocd-repo-server -- git ls-remote '$LDP_GIT_URL' HEAD"

report_platform_source

run_step "Enabling ApplicationSets" "${argocd_helm[@]}"

# --- platform rollout ---------------------------------------------------------
# Argo CD syncs the platform apps in waves (ldp.syncWave in each values.yaml):
#   1 cert-manager, external-secrets, crossplane, kagent-crds
#   2 crossplane-compositions
#   3 traefik, trust-manager, lldap, reloader, kubernetes-replicator, argocd
#   4 authelia, cloudnative-pg, keda
#   5 gitea, kargo
#   6 backstage, gitea-actions, kagent, victoria-metrics, victoria-logs,
#     victoria-logs-collector, perses
#   7 tenant-appsets
# The waits are sized for a laptop VM: cold image pulls through a proxy and
# operator start-up take several times longer than on an idle machine.

# --- [6/11] wave 1 ------------------------------------------------------------

step 6 $TOTAL_STEPS "Wave 1: Foundations"

wait_for 300 \
  "cert-manager"     "kubectl --context '$CONTEXT_NAME' -n pki wait --for=condition=Available deployment/cert-manager --timeout=1s" \
  "external-secrets" "kubectl --context '$CONTEXT_NAME' -n secrets wait --for=condition=Available deployment/external-secrets --timeout=1s" \
  "crossplane"       "kubectl --context '$CONTEXT_NAME' -n orchestration wait --for=condition=Available deployment/crossplane --timeout=1s"

# --- [7/11] wave 2 ------------------------------------------------------------

step 7 $TOTAL_STEPS "Wave 2: Crossplane Compositions"

wait_for 300 \
  "Crossplane function-go-templating" "kubectl --context '$CONTEXT_NAME' wait --for=condition=Healthy function/function-go-templating --timeout=1s" \
  "oidc.ldp XRDs"                     "kubectl --context '$CONTEXT_NAME' wait --for=condition=Established xrd/clients.oidc.ldp xrd/users.oidc.ldp --timeout=1s"

# --- [8/11] wave 3 ------------------------------------------------------------

step 8 $TOTAL_STEPS "Wave 3: Core Infrastructure"

wait_for 300 \
  "Traefik service" "kubectl --context '$CONTEXT_NAME' -n networking get service traefik" \
  "LLDAP"           "kubectl --context '$CONTEXT_NAME' -n auth wait --for=condition=Ready pod -l app.kubernetes.io/name=lldap-chart --timeout=1s"

traefik_ip="$(kubectl --context "$CONTEXT_NAME" -n networking get service traefik -o jsonpath='{.spec.clusterIP}')"
patch_coredns_for_nip_io "$traefik_ip"
trust_registry_on_nodes "$traefik_ip"

# --- [9/11] wave 4 ------------------------------------------------------------

step 9 $TOTAL_STEPS "Wave 4: Authentication & Operators"

wait_for 600 \
  "Authelia" "kubectl --context '$CONTEXT_NAME' -n auth wait --for=condition=Ready pod -l app.kubernetes.io/name=authelia --timeout=1s"

# --- [10/11] wave 5 -----------------------------------------------------------

step 10 $TOTAL_STEPS "Wave 5: Version Control & Delivery"

# Follow the rollout, not pods by label: replaced pods linger while terminating.
wait_for 900 \
  "Gitea" "kubectl --context '$CONTEXT_NAME' -n vcs rollout status deployment/gitea --timeout=1s"

# --- [11/11] wave 6 -----------------------------------------------------------

step 11 $TOTAL_STEPS "Wave 6: Developer Portal, Observability & Tenants"

# A cold node pulls Postgres and Backstage's image in sequence here. The
# observability apps are single small processes and come up alongside.
wait_for 900 \
  "Backstage" "kubectl --context '$CONTEXT_NAME' -n portal wait --for=condition=Ready pod -l app.kubernetes.io/name=backstage --timeout=1s" \
  "kagent"    "kubectl --context '$CONTEXT_NAME' -n devtools wait --for=condition=Available deployment/kagent-controller --timeout=1s" \
  "VictoriaMetrics" "kubectl --context '$CONTEXT_NAME' -n observability rollout status statefulset/victoria-metrics-victoria-metrics-single-server --timeout=1s" \
  "VictoriaLogs"    "kubectl --context '$CONTEXT_NAME' -n observability rollout status statefulset/victoria-logs-victoria-logs-single-server --timeout=1s" \
  "Perses"          "kubectl --context '$CONTEXT_NAME' -n observability rollout status statefulset/perses --timeout=1s" \
  "tenant ApplicationSets" "kubectl --context '$CONTEXT_NAME' -n '$ARGOCD_NS' get applicationset tenant-bootstrap tenant-apps"

# --- done ---------------------------------------------------------------------

printf "\n${GREEN}${BOLD}Platform ready in %dm%ds${NC}\n" $(( SECONDS / 60 )) $(( SECONDS % 60 ))
report_platform_source

bash "${SCRIPT_DIR}/show-info.sh"
