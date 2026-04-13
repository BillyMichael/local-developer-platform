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

detect_container_engine() {
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

  # Warn if Podman is running in rootless mode (KIND requires rootful)
  if [[ "$CE" == "podman" ]]; then
    local rootless
    rootless=$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null || echo "unknown")
    if [[ "$rootless" == "true" ]]; then
      warn "Podman is running in rootless mode."
      warn "KIND requires rootful Podman. If cluster creation fails, try:"
      warn "  systemctl start podman.socket"
      warn "  export CONTAINER_HOST=unix:///run/podman/podman.sock"
    fi
  fi

  export CE
}

# ============================================================================
# PORT AVAILABILITY CHECK
# ============================================================================

check_port_availability() {
  local ports=("$@")
  local blocked=false
  for port in "${ports[@]}"; do
    if command -v ss >/dev/null 2>&1 && ss -tlnH "sport = :${port}" 2>/dev/null | grep -q .; then
      error "Port $port is already in use"
      blocked=true
    elif command -v lsof >/dev/null 2>&1 && lsof -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1; then
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
}


# ============================================================================
# RESOURCE CHECK
# ============================================================================

check_available_resources() {
  local mem_kb=0
  if [[ "$(uname)" == "Darwin" ]]; then
    mem_kb=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1024 ))
  elif [[ -f /proc/meminfo ]]; then
    mem_kb=$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
  fi

  if (( mem_kb > 0 )); then
    local mem_gb=$(( mem_kb / 1024 / 1024 ))
    if (( mem_gb < 10 )); then
      warn "Only ~${mem_gb}GB RAM available. The platform recommends 12GB+."
      warn "Consider reducing worker nodes in cluster-config.yaml if you hit issues."
    else
      ok "${mem_gb}GB RAM available"
    fi
  else
    warn "Could not determine available memory"
  fi
}


# ============================================================================
# WAIT FOR RESOURCE HELPER
# ============================================================================

# wait_for <timeout_seconds> <label1> <cmd1> [<label2> <cmd2> ...]
# Polls each cmd every 2s until all succeed or the timeout is reached.
# Renders one independent line per task with its own spinner, so tasks
# tick off as they become ready rather than serially. Pass a single
# label/cmd pair for a single wait; pass multiple for parallel waits.
# cmd is executed via `bash -c`, so quote it as a single argument.
wait_for() {
  local timeout="$1"; shift

  local -a labels=() cmds=()
  while [ $# -ge 2 ]; do
    labels+=( "$1" )
    cmds+=( "$2" )
    shift 2
  done

  local n="${#labels[@]}"
  if [ "$n" -eq 0 ]; then
    return 0
  fi

  local tmpdir
  tmpdir=$(mktemp -d "/tmp/ldp-par-XXXXXX")
  local start_ts
  start_ts=$(date +%s)

  # Enable job control so each background worker is its own process group
  # leader. That lets us SIGTERM the whole group on abort and take the
  # worker's kubectl/sleep children with it, instead of orphaning them.
  set -m

  # Launch one worker per task. Each writes:
  #   $tmpdir/<i>.status -> ok|fail (only after done)
  #   $tmpdir/<i>.end    -> completion epoch
  #   $tmpdir/<i>.log    -> last attempt's combined output
  local -a pids=()
  local i
  for i in "${!labels[@]}"; do
    (
      local attempts=$(( timeout / 2 ))
      local j rc=1
      local log="$tmpdir/$i.log"
      for j in $(seq 1 "$attempts"); do
        # Redirect stdin from /dev/null so commands using `-i` (kubectl run -i,
        # kubectl exec -i, etc.) don't trigger SIGTTIN/SIGTTOU under `set -m`
        # and stop the worker waiting on the controlling terminal.
        if bash -c "${cmds[$i]}" </dev/null >"$log" 2>&1; then
          rc=0
          break
        fi
        sleep 2
      done
      date +%s > "$tmpdir/$i.end"
      if [ "$rc" -eq 0 ]; then
        echo ok > "$tmpdir/$i.status"
      else
        echo fail > "$tmpdir/$i.status"
      fi
    ) &
    pids+=( $! )
  done
  set +m

  # On abort: kill each worker's whole process group (negative PID) and
  # drop the tmpdir. Registered on the shared stack so it composes with
  # any outer run_step/wait_for.
  _push_cleanup "for p in ${pids[*]}; do kill -- -\$p 2>/dev/null; done; rm -rf '$tmpdir'"
  local _cleanup_idx=$_LAST_CLEANUP_IDX

  # Reserve N output lines (one per task).
  for _ in "${labels[@]}"; do echo; done

  local frame=0
  while :; do
    local done_count=0
    # Build the entire frame in one buffer and flush atomically to avoid
    # tearing/flicker from multiple partial writes per tick.
    local frame_buf
    printf -v frame_buf "\033[%dA" "$n"

    for i in "${!labels[@]}"; do
      local status="running"
      if [ -f "$tmpdir/$i.status" ]; then
        status=$(cat "$tmpdir/$i.status")
      elif ! kill -0 "${pids[$i]}" 2>/dev/null; then
        # Worker died without writing a status (e.g. external SIGKILL).
        # Mark as failed so the render loop can complete instead of
        # spinning forever on a missing file.
        echo fail > "$tmpdir/$i.status"
        echo "worker exited without writing status" > "$tmpdir/$i.log"
        date +%s > "$tmpdir/$i.end"
        status="fail"
      fi

      local elapsed
      if [ -f "$tmpdir/$i.end" ]; then
        elapsed=$(( $(cat "$tmpdir/$i.end") - start_ts ))
      else
        elapsed=$(( $(date +%s) - start_ts ))
      fi

      local line
      case "$status" in
        ok)
          printf -v line "\r\033[K  ${GREEN}✔${NC}  Waiting for %s (%ss)\n" "${labels[$i]}" "$elapsed"
          done_count=$(( done_count + 1 ))
          ;;
        fail)
          printf -v line "\r\033[K  ${RED}✖${NC}  Waiting for %s (%ss)\n" "${labels[$i]}" "$elapsed"
          done_count=$(( done_count + 1 ))
          ;;
        *)
          printf -v line "\r\033[K  ${BLUE}%s${NC}  Waiting for %s...\n" "${SPINNER_FRAMES[$frame]}" "${labels[$i]}"
          ;;
      esac
      frame_buf+="$line"
    done

    printf '%s' "$frame_buf"

    [ "$done_count" -eq "$n" ] && break
    frame=$(( (frame + 1) % ${#SPINNER_FRAMES[@]} ))
    sleep 0.125
  done

  # Reap any remaining workers
  wait 2>/dev/null || true

  _pop_cleanup "$_cleanup_idx"

  # Collect failures and emit diagnostics
  local rc=0
  for i in "${!labels[@]}"; do
    if [[ "$(cat "$tmpdir/$i.status" 2>/dev/null)" == "fail" ]]; then
      rc=1
      printf "     ${RED}Log (%s):${NC}\n" "${labels[$i]}"
      tail -10 "$tmpdir/$i.log" 2>/dev/null | sed 's/^/     /'
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
# SHARED CONFIG
# ============================================================================

CLUSTER_NAME="${CLUSTER_NAME:-ldp}"
CONTEXT_NAME="kind-${CLUSTER_NAME}"
