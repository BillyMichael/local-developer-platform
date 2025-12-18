#!/usr/bin/env bash

# ============================================================================
# COLOURS & FORMATTING
# ============================================================================

GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RED="\033[31m"
NC="\033[0m"
BOLD="\033[1m"

# ============================================================================
# FORMATTING FUNCTIONS
# ============================================================================

section() {
  printf "\n${BOLD}${BLUE}==> %s${NC}\n\n" "$1"
}

subsection() {
  printf "${BOLD}%s${NC}\n\n" "$1"
}

info()  { printf "  ${BLUE}➜${NC} %s\n" " $1"; }
ok()    { printf "  ${GREEN}✔${NC} %s\n" " $1"; }
warn()  { printf "  ${YELLOW}!${NC} %s\n" " $1"; }
error() { printf "  ${RED}✖${NC} %s\n" " $1"; }

# ============================================================================
# SPINNER & STEP EXECUTION LOGIC
# ============================================================================

SPINNER_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)

spinner() {
  local msg="$1"
  local pid="$2"
  local i=0

  # Stop spinner on interrupt
  trap "exit 1" INT TERM

  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${BLUE}%s${NC}  %s..." "${SPINNER_FRAMES[$i]}" "$msg"
    i=$(( (i + 1) % ${#SPINNER_FRAMES[@]} ))
    sleep 0.1
  done
}

run_step() {
  local msg="$1"; shift

  local start_ts
  start_ts=$(date +%s)

  # Run command in background
  "$@" >/dev/null 2>&1 &
  local cmd_pid=$!

  # Start spinner bound to command PID
  spinner "$msg" "$cmd_pid" &
  local spinner_pid=$!

  # Trap Ctrl-C and clean up both processes
  trap "kill $cmd_pid 2>/dev/null; kill $spinner_pid 2>/dev/null; exit 1" INT TERM

  # Wait for main command
  wait "$cmd_pid"
  local status=$?

  # Cleanup spinner
  kill "$spinner_pid" 2>/dev/null || true
  wait "$spinner_pid" 2>/dev/null || true

  local end_ts
  end_ts=$(date +%s)
  local duration=$(( end_ts - start_ts ))

  # Final output replacing spinner line
  if [ "$status" -eq 0 ]; then
    printf "\r  ${GREEN}✔${NC}  %s (${duration}s)\n" "$msg"
  else
    printf "\r  ${RED}✖${NC}  %s (${duration}s)\n" "$msg"
  fi

  return "$status"
}

# Optional: Sugar syntax
step() {
  run_step "$@"
}

# ============================================================================
# CONTAINER ENGINE DETECTION
# ============================================================================

detect_container_engine() {
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

  export CE
}

# ============================================================================
# REQUIRED TOOLS CHECK
# ============================================================================

check_required_tools() {
  local tools=("$@")

  section "Checking Required Tools"

  for tool in "${tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
      ok "$tool found"
    else
      error "$tool not found"
      exit 1
    fi
  done
}
