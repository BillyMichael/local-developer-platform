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

# ============================================================================
# DETECT CONTAINER ENGINE
# ============================================================================

section "Detecting Container Engine"

if [[ "${KIND_EXPERIMENTAL_PROVIDER:-}" == "podman" ]]; then
  if command -v podman >/dev/null 2>&1; then
    ok "Using Podman (via KIND_EXPERIMENTAL_PROVIDER)"
    CE="podman"
  else
    error "KIND_EXPERIMENTAL_PROVIDER=podman is set but Podman is not installed."
    exit 1
  fi

elif command -v podman >/dev/null 2>&1; then
  ok "Using Podman"
  CE="podman"
  export KIND_EXPERIMENTAL_PROVIDER=podman

elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  if [ "$(docker info --format '{{.OperatingSystem}}')" = "Docker Desktop" ]; then
    error "Docker Desktop detected — not supported. Use Podman or Docker Engine."
    exit 1
  fi

  ok "Using Docker Engine"
  CE="docker"

else
  error "No supported container engine found (need Docker Engine or Podman)."
  exit 1
fi

# ============================================================================
# DELETE CLUSTER
# ============================================================================

section "Deleting Kind Cluster"

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  run_step "Deleting cluster '$CLUSTER_NAME'" \
    kind delete cluster --name "$CLUSTER_NAME"
else
  ok "Cluster '$CLUSTER_NAME' does not exist"
fi
