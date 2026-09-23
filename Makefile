# Default goal so `make` runs the cluster
.DEFAULT_GOAL := up

.PHONY: up down restart kubeconfig info preflight status trust-ca help _banner


# ------------------------------------------------------------------------------
# Cluster Lifecycle
# ------------------------------------------------------------------------------

_banner:
	@bash -c 'source cluster/common.sh; banner'

up: _banner ## Create the kind cluster
	@bash cluster/cluster-up.sh

down: _banner ## Delete the kind cluster
	@bash cluster/cluster-down.sh

restart: down up ## Restart the cluster


# ------------------------------------------------------------------------------
# Utilities
# ------------------------------------------------------------------------------

kubeconfig: ## Export updated kubeconfig
	@kind export kubeconfig --name $${CLUSTER_NAME:-ldp} >/dev/null

info: ## Show Local Development Platform info
	@bash cluster/show-info.sh

preflight: ## Check prerequisites without creating cluster
	@bash -c 'source cluster/common.sh && preflight'

trust-ca: ## Trust the platform CA certificate (eliminates TLS warnings)
	@bash cluster/trust-ca.sh

status: ## Show platform health status
	@pods=$$(kubectl --context kind-$${CLUSTER_NAME:-ldp} get pods -A --no-headers 2>/dev/null) || { echo "Cluster not running"; exit 0; }; \
		echo "$$pods" | awk '$$4 != "Running" && $$4 != "Completed" && $$4 != "Succeeded"' | grep . || echo "All pods healthy"


# ------------------------------------------------------------------------------
# Help
# ------------------------------------------------------------------------------

help: ## Show this help
	@printf "\nLocal Development Platform Make Commands\n"
	@printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
	@awk 'BEGIN {FS=":.*##"; printf "Usage: make <target>\n\nAvailable targets:\n"} \
		/^[a-zA-Z0-9_-]+:.*##/ \
		{ printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@printf "\n"
