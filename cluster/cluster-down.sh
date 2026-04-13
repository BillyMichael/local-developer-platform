#!/usr/bin/env bash
set -euo pipefail

# Source common formatting functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

TOTAL_STEPS=2


# ============================================================================
# [1/2] PREFLIGHT CHECKS
# ============================================================================

step 1 $TOTAL_STEPS "Preflight Checks"

detect_container_engine
check_required_tools "kind"


# ============================================================================
# [2/2] DELETE CLUSTER
# ============================================================================

step 2 $TOTAL_STEPS "Deleting Kind Cluster"

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  run_step "Deleting cluster '$CLUSTER_NAME'" \
    kind delete cluster --name "$CLUSTER_NAME"
else
  ok "Cluster '$CLUSTER_NAME' does not exist"
fi
