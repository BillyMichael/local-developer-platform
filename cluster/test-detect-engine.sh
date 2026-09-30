#!/usr/bin/env bash
# Self-check for detect_container_engine. Stubs docker/podman on PATH so all
# three engines can be exercised on any machine.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASH=$(command -v bash)
STUBS=$(mktemp -d)
trap 'rm -rf "$STUBS"' EXIT

# stub <name> <info_exit_code>
stub() {
  cat > "$STUBS/$1" <<STUB
#!$BASH
exit $2
STUB
  chmod +x "$STUBS/$1"
}

# run <desc> <expected_CE> <expected_provider> <expected_rc> <KIND_EXPERIMENTAL_PROVIDER>
run() {
  local desc="$1" want_ce="$2" want_prov="$3" want_rc="$4" env_prov="$5"
  local out rc
  # Stubs only on PATH so a real docker/podman cannot leak in.
  out=$(PATH="$STUBS" KIND_EXPERIMENTAL_PROVIDER="$env_prov" \
    "$BASH" -c 'source '"$SCRIPT_DIR"'/common.sh
             detect_container_engine
             echo "RESULT ${CE:-} ${KIND_EXPERIMENTAL_PROVIDER:-}"' 2>&1)
  rc=$?
  local got
  got=$(grep -o 'RESULT.*' <<<"$out" | tail -1)
  local expect="RESULT $want_ce $want_prov"
  if [ "$rc" -ne "$want_rc" ]; then
    echo "FAIL $desc: rc=$rc want $want_rc"; echo "$out"; return 1
  fi
  if [ "$want_rc" -eq 0 ] && [ "$got" != "$expect" ]; then
    echo "FAIL $desc: got '$got' want '$expect'"; return 1
  fi
  echo "ok   $desc"
}

fails=0

rm -f "$STUBS"/*; stub docker 0
run "docker only -> docker"               docker ""       0 "" || fails=1

rm -f "$STUBS"/*; stub podman 0
run "podman only -> podman"               podman podman   0 "" || fails=1

rm -f "$STUBS"/*; stub docker 0; stub podman 0
run "both -> docker wins"                 docker ""       0 "" || fails=1

rm -f "$STUBS"/*; stub docker 0; stub podman 0
run "both, env=podman -> podman honoured"  podman podman  0 "podman" || fails=1

rm -f "$STUBS"/*; stub docker 1; stub podman 0
run "docker daemon down -> podman"        podman podman   0 "" || fails=1

rm -f "$STUBS"/*
run "no engine -> exit 1"                 ""     ""       1 "" || fails=1

rm -f "$STUBS"/*; stub docker 0
run "env=podman but absent -> exit 1"     ""     ""       1 "podman" || fails=1

[ "$fails" -eq 0 ] && echo "all passed"
exit "$fails"
