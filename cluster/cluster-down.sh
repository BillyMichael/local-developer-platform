#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

TOTAL_STEPS=2

step 1 $TOTAL_STEPS "Preflight Checks"

detect_container_engine
check_required_tools "kind"

step 2 $TOTAL_STEPS "Deleting Kind Cluster"

if cluster_exists; then
  run_step "Deleting cluster '$CLUSTER_NAME'" \
    kind delete cluster --name "$CLUSTER_NAME"
else
  ok "Cluster '$CLUSTER_NAME' does not exist"
fi
