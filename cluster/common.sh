#!/usr/bin/env bash
# shellcheck disable=SC2034

GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RED="\033[31m"
NC="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

section()    { printf "\n${BOLD}${BLUE}==> %s${NC}\n\n" "$1"; }
step()       { printf "\n${BOLD}${BLUE}==> [%s/%s] %s${NC}\n\n" "$1" "$2" "$3"; }
subsection() { printf "${BOLD}%s${NC}\n\n" "$1"; }
ok()         { printf "  ${GREEN}✔${NC} %s\n" " $1"; }
warn()       { printf "  ${YELLOW}!${NC} %s\n" " $1"; }
error()      { printf "  ${RED}✖${NC} %s\n" " $1"; }

# Prompt on stderr so $(...) captures only the value.
prompt_secret() {
  local value="$1"
  if [ -z "$value" ] && [ -t 0 ]; then
    printf "  ${BLUE}?${NC}  %s (input hidden, Enter to skip): " "$2" >&2
    read -rs value || value=""
    printf "\n" >&2
  fi
  printf '%s' "$value"
}

banner() {
  printf "${BOLD}${BLUE}"
  cat <<'EOT'

  ██╗     ██████╗  ██████╗
  ██║     ██╔══██╗ ██╔══██╗
  ██║     ██║  ██║ ██████╔╝
  ██║     ██║  ██║ ██╔═══╝
  ███████╗██████╔╝ ██║
  ╚══════╝╚═════╝  ╚═╝
EOT
  printf "${NC}\n  ${BOLD}Local Developer Platform${NC}  by Billy Michael\n"
}

# One top-level trap runs pending cleanups so nested run_step/wait_for do not stomp on each other's traps.

_CLEANUP_CMDS=()
_LAST_CLEANUP_IDX=-1

_push_cleanup() {
  _CLEANUP_CMDS+=( "$1" )
  _LAST_CLEANUP_IDX=$(( ${#_CLEANUP_CMDS[@]} - 1 ))
}

_pop_cleanup() {
  [ -n "$1" ] && unset "_CLEANUP_CMDS[$1]"
}

_run_cleanups() {
  local cmd
  # ${arr[@]+...}: bash 3.2 (macOS) treats an empty array as unbound under set -u.
  for cmd in ${_CLEANUP_CMDS[@]+"${_CLEANUP_CMDS[@]}"}; do
    [ -n "$cmd" ] && eval "$cmd" 2>/dev/null || true
  done
  _CLEANUP_CMDS=()
}

printf "\033[?25l"
trap '_run_cleanups; printf "\033[?25h"' EXIT
trap '_run_cleanups; printf "\033[?25h"; exit 130' INT
trap '_run_cleanups; printf "\033[?25h"; exit 143' TERM

SPINNER_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)

spinner() {
  local msg="$1" pid="$2" i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${BLUE}%s${NC}  %s..." "${SPINNER_FRAMES[$i]}" "$msg"
    i=$(( (i + 1) % ${#SPINNER_FRAMES[@]} ))
    sleep 0.1
  done
}

run_step() {
  local msg="$1"; shift

  local start_ts logfile
  start_ts=$(date +%s)
  logfile=$(mktemp "/tmp/ldp-step-XXXXXX")

  "$@" >"$logfile" 2>&1 &
  local cmd_pid=$!
  spinner "$msg" "$cmd_pid" &
  local spinner_pid=$!

  _push_cleanup "kill $cmd_pid 2>/dev/null; kill $spinner_pid 2>/dev/null; rm -f '$logfile'"
  local _cleanup_idx=$_LAST_CLEANUP_IDX

  local status=0
  wait "$cmd_pid" || status=$?
  kill "$spinner_pid" 2>/dev/null || true
  wait "$spinner_pid" 2>/dev/null || true
  _pop_cleanup "$_cleanup_idx"

  local duration=$(( $(date +%s) - start_ts ))
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

# Docker wins when both work: kind's podman support is experimental.
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

engine_works() {
  command -v "$1" >/dev/null 2>&1 && "$1" info >/dev/null 2>&1
}

# Not `kind get clusters`: its `ps` template breaks on podman >= 5.8 and silently reports none.
cluster_exists() {
  [ -n "$("$CE" ps -a --filter "label=io.x-k8s.kind.cluster=${CLUSTER_NAME}" --format '{{.Names}}' 2>/dev/null)" ]
}

port_in_use() {
  if command -v ss >/dev/null 2>&1; then
    ss -tlnH "sport = :$1" 2>/dev/null | grep -q .
  else
    lsof -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
  fi
}

check_port_availability() {
  local blocked=false port
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

  if [[ "$CE" == "podman" ]] && [[ "$(podman info --format '{{.Host.Security.Rootless}}')" == "true" ]]; then
    warn "Rootless podman cannot bind ports 80/443. Either run:"
    warn "  sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80"
    warn "or use rootful podman (sudo systemctl start podman.socket)."
  fi
}

LDP_MIN_MEM_GB=11   # a 12GB VM reports ~11GiB

# Prints "<bytes> <cpus>" of the engine VM; docker keys them at the top level, podman under .Host.
engine_resources() {
  local out
  out=$("$CE" info --format '{{.MemTotal}} {{.NCPU}}' 2>/dev/null) || out=""
  [[ "$out" =~ ^[0-9]+\ [0-9]+$ ]] || out=$("$CE" info --format '{{.Host.MemTotal}} {{.Host.CPUs}}' 2>/dev/null) || out=""
  [[ "$out" =~ ^[0-9]+\ [0-9]+$ ]] || out="0 0"
  printf '%s' "$out"
}

check_available_resources() {
  local mem_bytes mem_gb cpus
  read -r mem_bytes cpus <<<"$(engine_resources)"
  mem_gb=$(( mem_bytes / 1024 / 1024 / 1024 ))

  if (( mem_gb == 0 )); then
    warn "Could not determine the memory available to ${CE}"
  elif (( mem_gb < LDP_MIN_MEM_GB )); then
    error "${CE} has only ~${mem_gb}GB RAM; the platform needs 12GB+."
  else
    ok "${mem_gb}GB RAM available to ${CE}"
  fi
  (( cpus > 0 )) && ok "${cpus} CPUs available to ${CE}"
  (( mem_gb == 0 || mem_gb >= LDP_MIN_MEM_GB )) && return 0

  if [[ "$CE" == "podman" ]]; then
    error "Resize the VM: podman machine stop && podman machine set --memory 12288 && podman machine start"
  else
    error "Raise the VM allocation under Settings > Resources in Docker Desktop."
  fi
  if [[ "${LDP_SKIP_RESOURCE_CHECK:-}" == "1" ]]; then
    warn "LDP_SKIP_RESOURCE_CHECK=1 set; continuing anyway. Expect slow or stalled waves."
    return 0
  fi
  error "Set LDP_SKIP_RESOURCE_CHECK=1 to run on a smaller machine anyway."
  exit 1
}

check_required_tools() {
  local tool
  for tool in "$@"; do
    if command -v "$tool" >/dev/null 2>&1; then
      ok "$tool found"
    else
      error "$tool not found"
      exit 1
    fi
  done
}

preflight() {
  detect_container_engine
  check_required_tools kind kubectl helm
  if cluster_exists; then
    ok "Ports 80/443 belong to the existing '$CLUSTER_NAME' cluster"
  else
    check_port_availability 80 443
  fi
  check_available_resources
}

# wait_for <timeout_seconds> <label> <cmd> [<label> <cmd> ...]; each cmd runs via `bash -c`.
wait_for() {
  local timeout="$1"; shift

  local -a labels=() cmds=()
  while [ $# -ge 2 ]; do
    labels+=( "$1" )
    cmds+=( "$2" )
    shift 2
  done

  local tmpdir start_ts
  tmpdir=$(mktemp -d "/tmp/ldp-wait-XXXXXX")
  start_ts=$(date +%s)

  # set -m: each worker leads a process group, so cleanup also kills its kubectl/sleep children.
  set -m
  local -a pids=()
  local i
  for i in "${!labels[@]}"; do
    (
      local deadline=$(( start_ts + timeout ))
      while :; do
        # stdin from /dev/null so `kubectl run -i` does not fight for the tty.
        if bash -c "${cmds[$i]}" </dev/null >"$tmpdir/$i.log" 2>&1; then
          # write-then-rename: the render loop must never read a truncated file
          echo "ok $(( $(date +%s) - start_ts ))" > "$tmpdir/$i.status.tmp" && mv "$tmpdir/$i.status.tmp" "$tmpdir/$i.status"
          exit 0
        fi
        if (( $(date +%s) >= deadline )); then
          echo "fail $(( $(date +%s) - start_ts ))" > "$tmpdir/$i.status.tmp" && mv "$tmpdir/$i.status.tmp" "$tmpdir/$i.status"
          exit 1
        fi
        sleep 5
      done
    ) &
    pids+=( $! )
  done
  set +m

  _push_cleanup "for p in ${pids[*]}; do kill -- -\$p 2>/dev/null; done; rm -rf '$tmpdir'"
  local _cleanup_idx=$_LAST_CLEANUP_IDX

  for _ in "${labels[@]}"; do echo; done

  local frame=0 done_count=0
  while (( done_count < ${#labels[@]} )); do
    done_count=0
    printf "\033[%dA" "${#labels[@]}"

    for i in "${!labels[@]}"; do
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

CLUSTER_NAME="${CLUSTER_NAME:-ldp}"
CONTEXT_NAME="kind-${CLUSTER_NAME}"
