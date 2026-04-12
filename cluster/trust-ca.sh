#!/usr/bin/env bash
set -euo pipefail

# Source common formatting functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# ============================================================================
# EXTRACT CA CERTIFICATE
# ============================================================================

section "Trust Platform CA Certificate"

CA_CERT="/tmp/ldp-ca.crt"

run_step "Extracting CA certificate from cluster" \
  bash -c "
    kubectl --context '$CONTEXT_NAME' get secret root-ca -n pki \
      -o jsonpath='{.data.tls\.crt}' | base64 -d > '$CA_CERT'
    # Verify it's a valid certificate
    openssl x509 -in '$CA_CERT' -noout -subject
  "

# ============================================================================
# INSTALL INTO OS TRUST STORE
# ============================================================================

case "$(uname -s)" in
  Darwin)
    run_step "Adding CA to macOS System Keychain (requires sudo)" \
      sudo security add-trusted-cert -d -r trustRoot \
        -k /Library/Keychains/System.keychain "$CA_CERT"
    ok "CA trusted — restart your browser for changes to take effect"
    ;;

  MINGW*|MSYS*|CYGWIN*)
    run_step "Adding CA to Windows certificate store" \
      certutil -addstore -user -f "Root" "$CA_CERT"
    ok "CA trusted — restart your browser for changes to take effect"
    ;;

  Linux)
    # Check if running under WSL
    if grep -qi microsoft /proc/version 2>/dev/null; then
      CERTUTIL=$(command -v certutil.exe 2>/dev/null || wslpath -u "C:/Windows/System32/certutil.exe" 2>/dev/null || true)
      if [[ -n "$CERTUTIL" ]]; then
        WIN_CERT=$(wslpath -w "$CA_CERT")
        run_step "Adding CA to Windows certificate store (WSL)" \
          "$CERTUTIL" -addstore -user -f "Root" "$WIN_CERT"
        ok "CA trusted in Windows — restart your browser for changes to take effect"
      else
        error "certutil.exe not found — import $CA_CERT manually into Windows"
        exit 1
      fi
    else
      error "Linux host detected — import $CA_CERT into your browser or OS trust store manually"
      exit 1
    fi
    ;;

  *)
    error "Unsupported OS: $(uname -s)"
    error "Import $CA_CERT into your trust store manually"
    exit 1
    ;;
esac

rm -f "$CA_CERT"
