# Default goal so `make` runs the cluster
.DEFAULT_GOAL := up

.PHONY: up down restart kubeconfig info preflight status trust-ca help


# ------------------------------------------------------------------------------
# Cluster Lifecycle
# ------------------------------------------------------------------------------

up: ## Create the kind cluster
	@bash cluster/cluster-up.sh

down: ## Delete the kind cluster
	@bash cluster/cluster-down.sh

restart: ## Restart the cluster
	@$(MAKE) --no-print-directory down
	@$(MAKE) --no-print-directory up


# ------------------------------------------------------------------------------
# Utilities
# ------------------------------------------------------------------------------

kubeconfig: ## Export updated kubeconfig
	@kind export kubeconfig --name $${CLUSTER_NAME:-ldp} >/dev/null

info: ## Show Local Development Platform info
	@bash cluster/show-info.sh

preflight: ## Check prerequisites without creating cluster
	@bash -c 'source cluster/common.sh && detect_container_engine && check_required_tools kind kubectl helm && check_port_availability 80 443 9000 && check_available_resources'

trust-ca: ## Trust the platform CA certificate (eliminates TLS warnings)
	@bash cluster/trust-ca.sh

status: ## Show platform health status
	@kubectl --context kind-$${CLUSTER_NAME:-ldp} get pods -A --no-headers 2>/dev/null | \
		awk '$$4 != "Running" && $$4 != "Completed" && $$4 != "Succeeded" {print}' | \
		{ result=$$(cat); if [ -z "$$result" ]; then echo "All pods healthy"; else echo "$$result"; fi; } || \
		echo "Cluster not running"


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
