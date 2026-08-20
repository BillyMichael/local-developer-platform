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

# step <current> <total> <description>
# Prints a section header with a progress counter, e.g. [3/9] Deploying ...
step() {
  local current="$1"; shift
  local total="$1"; shift
  printf "\n${BOLD}${BLUE}==> [%s/%s] %s${NC}\n\n" "$current" "$total" "$1"
}

subsection() {
  printf "${BOLD}%s${NC}\n\n" "$1"
}

info()  { printf "  ${BLUE}➜${NC} %s\n" " $1"; }
ok()    { printf "  ${GREEN}✔${NC} %s\n" " $1"; }
warn()  { printf "  ${YELLOW}!${NC} %s\n" " $1"; }
error() { printf "  ${RED}✖${NC} %s\n" " $1"; }

banner() {
  printf "${BOLD}${BLUE}"
  cat <<'EOF'

  ██╗     ██████╗  ██████╗
  ██║     ██╔══██╗ ██╔══██╗
  ██║     ██║  ██║ ██████╔╝
  ██║     ██║  ██║ ██╔═══╝
  ███████╗██████╔╝ ██║
  ╚══════╝╚═════╝  ╚═╝
EOF
  printf "${NC}\n  ${BOLD}Local Developer Platform${NC}\n"
}

# ============================================================================
# CURSOR MANAGEMENT + SHARED CLEANUP STACK
# ============================================================================
# Hide the terminal cursor for the entire script run and restore it on any
# exit path, including INT/TERM and `set -e` aborts.
#
# Functions that spawn background work (run_step, wait_for) push a cleanup
# closure onto _CLEANUP_CMDS on entry and pop it on normal completion.
# A single top-level trap runs whatever remains on abort, so the traps do
# not stomp on each other when functions are nested.
_CLEANUP_CMDS=()
_LAST_CLEANUP_IDX=-1

_push_cleanup() {
  _CLEANUP_CMDS+=( "$1" )
  _LAST_CLEANUP_IDX=$(( ${#_CLEANUP_CMDS[@]} - 1 ))
}

_pop_cleanup() {
  local idx="$1"
  [ -n "$idx" ] && unset "_CLEANUP_CMDS[$idx]"
}

_run_cleanups() {
  local cmd
  for cmd in "${_CLEANUP_CMDS[@]}"; do
    [ -n "$cmd" ] && eval "$cmd" 2>/dev/null || true
  done
  _CLEANUP_CMDS=()
}

printf "\033[?25l"
trap '_run_cleanups; printf "\033[?25h"' EXIT
trap '_run_cleanups; printf "\033[?25h"; exit 130' INT
trap '_run_cleanups; printf "\033[?25h"; exit 143' TERM

# ============================================================================
# SPINNER & STEP EXECUTION LOGIC
# ============================================================================

SPINNER_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)

spinner() {
  local msg="$1"
  local pid="$2"
  local i=0

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

  local logfile
  logfile=$(mktemp "/tmp/ldp-step-XXXXXX")

  # Run command in background, capturing output to logfile
  "$@" >"$logfile" 2>&1 &
  local cmd_pid=$!

  # Start spinner bound to command PID
  spinner "$msg" "$cmd_pid" &
  local spinner_pid=$!

  # Register cleanup on the shared stack; popped on normal completion below
  _push_cleanup "kill $cmd_pid 2>/dev/null; kill $spinner_pid 2>/dev/null; rm -f '$logfile'"
  local _cleanup_idx=$_LAST_CLEANUP_IDX

  # Wait for main command and capture exit status
  local status=0
  wait "$cmd_pid" || status=$?

  # Cleanup spinner immediately
  kill "$spinner_pid" 2>/dev/null || true
  wait "$spinner_pid" 2>/dev/null || true

  _pop_cleanup "$_cleanup_idx"

  local end_ts
  end_ts=$(date +%s)
  local duration=$(( end_ts - start_ts ))

  # Final output replacing spinner line
  if [ "$status" -eq 0 ]; then
    printf "\r  ${GREEN}✔${NC}  %s (${duration}s)\n" "$msg"
    rm -f "$logfile"
  else
    printf "\r  ${RED}✖${NC}  %s (${duration}s)\n" "$msg"
    printf "     ${RED}Log:${NC} %s\n" "$logfile"
    tail -10 "$logfile" 2>/dev/null | sed 's/^/     /'
  fi

  return "$status"
}

# ============================================================================
# CONTAINER ENGINE DETECTION
# ============================================================================

# Sets CE to "docker" or "podman". Docker wins if both work, since kind's
# podman support is still experimental. Set KIND_EXPERIMENTAL_PROVIDER=podman
# to force podman.
detect_container_engine() {
  if [[ "${KIND_EXPERIMENTAL_PROVIDER:-}" == "podman" ]]; then
    engine_works podman || { error "KIND_EXPERIMENTAL_PROVIDER=podman but podman is not working."; exit 1; }
    CE="podman"
  elif engine_works docker; then
    CE="docker"
    unset KIND_EXPERIMENTAL_PROVIDER
  elif engine_works podman; then
    CE="podman"
    export KIND_EXPERIMENTAL_PROVIDER=podman
  else
    error "No container engine found. Install Docker or Podman and start it."
    exit 1
  fi

  ok "Using ${CE}"
  export CE
}

# True if the engine is installed and its daemon is responding.
engine_works() {
  command -v "$1" >/dev/null 2>&1 && "$1" info >/dev/null 2>&1
}

# ============================================================================
# PORT AVAILABILITY CHECK
# ============================================================================

port_in_use() {
  if command -v ss >/dev/null 2>&1; then
    ss -tlnH "sport = :$1" 2>/dev/null | grep -q .
  else
    lsof -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
  fi
}

check_port_availability() {
  local blocked=false
  for port in "$@"; do
    if port_in_use "$port"; then
      error "Port $port is already in use"
      blocked=true
    else
      ok "Port $port is available"
    fi
  done

  if [[ "$blocked" == "true" ]]; then
    error "Free the ports listed above before running 'make up'."
    exit 1
  fi

  # Rootless podman cannot bind ports below 1024 at all.
  if [[ "$CE" == "podman" ]] && [[ "$(podman info --format '{{.Host.Security.Rootless}}')" == "true" ]]; then
    warn "Rootless podman cannot bind ports 80/443. Either run:"
    warn "  sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80"
    warn "or use rootful podman (sudo systemctl start podman.socket)."
  fi
}

# ============================================================================
# RESOURCE CHECK
# ============================================================================

# Asks the container engine how much RAM it has. On Docker Desktop and
# podman machine that is the VM's allocation, which is what actually
# constrains the cluster -- the host may have far more.
check_available_resources() {
  local mem_gb=$(( $("$CE" info --format '{{.MemTotal}}' 2>/dev/null || echo 0) / 1024 / 1024 / 1024 ))

  if (( mem_gb == 0 )); then
    warn "Could not determine available memory"
  elif (( mem_gb < 10 )); then
    warn "${CE} has only ~${mem_gb}GB RAM. The platform recommends 12GB+."
    warn "Raise it in your engine's settings, or drop a worker from cluster-config.yaml."
  else
    ok "${mem_gb}GB RAM available to ${CE}"
  fi
}


# ============================================================================
# WAIT FOR RESOURCE HELPER
# ============================================================================

# wait_for <timeout_seconds> <label> <cmd> [<label> <cmd> ...]
# Polls each cmd until it succeeds or the timeout passes. Multiple pairs are
# polled in parallel, each getting its own spinner line that ticks off as it
# becomes ready. cmd runs via `bash -c`, so quote it as one argument.
wait_for() {
  local timeout="$1"; shift

  local -a labels=() cmds=()
  while [ $# -ge 2 ]; do
    labels+=( "$1" )
    cmds+=( "$2" )
    shift 2
  done

  local tmpdir
  tmpdir=$(mktemp -d "/tmp/ldp-wait-XXXXXX")
  local start_ts
  start_ts=$(date +%s)

  # One background worker per task. Each writes its exit status to
  # <i>.status when done; the render loop below reads those files.
  #
  # `set -m` makes each worker its own process group leader, so the cleanup
  # below can kill the group (negative PID) and take the worker's kubectl
  # and sleep children with it instead of orphaning them.
  set -m
  local -a pids=()
  local i
  for i in "${!labels[@]}"; do
    (
      local deadline=$(( start_ts + timeout ))
      while :; do
        # stdin from /dev/null so `kubectl run -i` doesn't fight for the tty.
        if bash -c "${cmds[$i]}" </dev/null >"$tmpdir/$i.log" 2>&1; then
          echo "ok $(( $(date +%s) - start_ts ))" > "$tmpdir/$i.status"
          exit 0
        fi
        if (( $(date +%s) >= deadline )); then
          echo "fail $(( $(date +%s) - start_ts ))" > "$tmpdir/$i.status"
          exit 1
        fi
        sleep 2
      done
    ) &
    pids+=( $! )
  done
  set +m

  _push_cleanup "for p in ${pids[*]}; do kill -- -\$p 2>/dev/null; done; rm -rf '$tmpdir'"
  local _cleanup_idx=$_LAST_CLEANUP_IDX

  # Reserve one output line per task, then repaint them in place each tick.
  for _ in "${labels[@]}"; do echo; done

  local frame=0 done_count=0
  while (( done_count < ${#labels[@]} )); do
    done_count=0
    printf "\033[%dA" "${#labels[@]}"

    for i in "${!labels[@]}"; do
      # Finished workers record their own elapsed time, so the line freezes.
      local status elapsed
      status=running
      [[ -f "$tmpdir/$i.status" ]] && read -r status elapsed < "$tmpdir/$i.status"

      case "$status" in
        ok)   printf "\r\033[K  ${GREEN}✔${NC}  Waiting for %s (%ss)\n" "${labels[$i]}" "$elapsed"
              done_count=$(( done_count + 1 )) ;;
        fail) printf "\r\033[K  ${RED}✖${NC}  Waiting for %s (%ss)\n" "${labels[$i]}" "$elapsed"
              done_count=$(( done_count + 1 )) ;;
        *)    printf "\r\033[K  ${BLUE}%s${NC}  Waiting for %s...\n" "${SPINNER_FRAMES[$frame]}" "${labels[$i]}" ;;
      esac
    done

    frame=$(( (frame + 1) % ${#SPINNER_FRAMES[@]} ))
    sleep 0.125
  done

  wait 2>/dev/null || true
  _pop_cleanup "$_cleanup_idx"

  # Report failures with the last attempt's output.
  local rc=0
  for i in "${!labels[@]}"; do
    if [[ "$(<"$tmpdir/$i.status")" == fail* ]]; then
      rc=1
      printf "     ${RED}Log (%s):${NC}\n" "${labels[$i]}"
      tail -10 "$tmpdir/$i.log" | sed 's/^/     /'
    fi
  done

  rm -rf "$tmpdir"
  return "$rc"
}

# ============================================================================
# REQUIRED TOOLS CHECK
# ============================================================================

check_required_tools() {
  local tools=("$@")
  for tool in "${tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
      ok "$tool found"
    else
      error "$tool not found"
      exit 1
    fi
  done
}

# ============================================================================
# PREFLIGHT
# ============================================================================

# Everything `make up` needs before it touches the cluster. Also exposed on
# its own as `make preflight`.
preflight() {
  detect_container_engine
  check_required_tools kind kubectl helm
  check_port_availability 80 443 9000
  check_available_resources
}

# ============================================================================
# SHARED CONFIG
# ============================================================================

CLUSTER_NAME="${CLUSTER_NAME:-ldp}"
CONTEXT_NAME="kind-${CLUSTER_NAME}"
