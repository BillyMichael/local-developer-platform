#!/usr/bin/env bash
set -euo pipefail

# Source common formatting functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

LLDAP_NS="${LLDAP_NS:-auth}"

# ============================================================================
# HEADER
# ============================================================================

section "Local Development Platform Info"

subsection "User Credentials:"

# ============================================================================
# FETCH CREDENTIALS
# ============================================================================

get_secret_field() {
  kubectl --context "$CONTEXT_NAME" -n "$LLDAP_NS" get secret "$1" -o jsonpath="{.data.$2}" 2>/dev/null | base64 -d ||
    printf "(not yet available)"
}

MAINT_USER=$(get_secret_field "lldap-maintainer-credentials" "id")
MAINT_PASS=$(get_secret_field "lldap-maintainer-credentials" "password")

USER_USER=$(get_secret_field "lldap-user-credentials" "id")
USER_PASS=$(get_secret_field "lldap-user-credentials" "password")


# ============================================================================
# PRINT CREDENTIAL TABLE
# ============================================================================

printf "  ┌────────────┬──────────────────────┬──────────────────────────────────┐\n"
printf "  │ %-10s │ %-20s │ %-32s │\n" "Role" "Username" "Password"
printf "  ├────────────┼──────────────────────┼──────────────────────────────────┤\n"
printf "  │ %-10s │ %-20s │ %-32s │\n" "Maintainer" "$MAINT_USER" "$MAINT_PASS"
printf "  │ %-10s │ %-20s │ %-32s │\n" "User"       "$USER_USER"  "$USER_PASS"
printf "  └────────────┴──────────────────────┴──────────────────────────────────┘\n\n"


# ============================================================================
# URL TABLE
# ============================================================================

subsection "URLs:"

printf "  ┌──────────────┬────────────────────────────────────────────┐\n"
printf "  │ %-12s │ %-42s │\n" "Service" "URL"
printf "  ├──────────────┼────────────────────────────────────────────┤\n"
printf "  │ %-12s │ %-42s │\n" "ArgoCD"   "https://cd-127-0-0-1.nip.io"
printf "  │ %-12s │ %-42s │\n" "Authelia" "https://auth-127-0-0-1.nip.io"
printf "  │ %-12s │ %-42s │\n" "Gitea"    "https://vcs-127-0-0-1.nip.io"
printf "  │ %-12s │ %-42s │\n" "Backstage" "https://portal-127-0-0-1.nip.io"
printf "  │ %-12s │ %-42s │\n" "kagent"   "https://agents-127-0-0-1.nip.io"
printf "  └──────────────┴────────────────────────────────────────────┘\n\n"


# ============================================================================
# COMMANDS TABLE
# ============================================================================

subsection "Useful Commands:"

printf "  ┌──────────────────┬─────────────────────────────────────────┐\n"
printf "  │ %-16s │ %-39s │\n" "Command" "Description"
printf "  ├──────────────────┼─────────────────────────────────────────┤\n"
printf "  │ %-16s │ %-39s │\n" "make down"       "Delete cluster"
printf "  │ %-16s │ %-39s │\n" "make restart"    "Restart cluster"
printf "  │ %-16s │ %-39s │\n" "make kubeconfig" "Update kubeconfig"
printf "  │ %-16s │ %-39s │\n" "make trust-ca"   "Trust the platform CA (no TLS warnings)"
printf "  │ %-16s │ %-39s │\n" "make info"       "Show LDP info"
printf "  └──────────────────┴─────────────────────────────────────────┘\n\n"


# ============================================================================
# CA TRUST NOTICE
# ============================================================================
# curl exit 60 = the OS trust store lacks the platform CA; anything else prints nothing.
# Under WSL the CA lives in Windows, so Linux curl fails even after `make trust-ca`.

if command -v curl >/dev/null 2>&1; then
  ca_rc=0
  curl -s -o /dev/null --max-time 5 https://portal-127-0-0-1.nip.io || ca_rc=$?
  if [ "$ca_rc" -eq 60 ]; then
    warn "Browsers will show TLS warnings until the platform CA is trusted."
    printf "  ${BLUE}\u279c${NC}  Run ${DIM}\`${NC}${BOLD}${YELLOW}make trust-ca${NC}${DIM}\`${NC}, then restart your browser.\n"
    if grep -qi microsoft /proc/version 2>/dev/null; then
      printf "  ${BLUE}\u279c${NC}  ${DIM}Already ran it under WSL? The CA is stored in Windows, where your browser reads it.${NC}\n"
    fi
    printf "\n"
  fi
fi
