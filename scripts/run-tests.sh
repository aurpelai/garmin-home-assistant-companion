#!/usr/bin/env bash
# Build and run the Monkey C unit tests headlessly, and translate the result
# into a real exit code.
#
# Gotcha this script exists to solve: `monkeydo` always exits 0 regardless of
# test pass/fail, so CI must parse the console output. We treat the run as
# failing unless the summary line reports PASSED with zero failures/errors.
#
# Env:
#   CIQ_SDK   SDK root (defaults to tools on PATH)
#   DEVICE    target device id (default venu3)
#   KEY       developer key path (default developer_key.der)
set -euo pipefail

DEVICE="${DEVICE:-venu3}"
KEY="${KEY:-developer_key.der}"
JUNGLE="${JUNGLE:-monkey.jungle}"

if [[ -n "${CIQ_SDK:-}" ]]; then
  MONKEYC="$CIQ_SDK/bin/monkeyc"
  MONKEYDO="$CIQ_SDK/bin/monkeydo"
  CONNECTIQ="$CIQ_SDK/bin/connectiq"
else
  MONKEYC="monkeyc"; MONKEYDO="monkeydo"; CONNECTIQ="connectiq"
fi

mkdir -p bin
echo "== Building unit-test binary for $DEVICE =="
# -l 3 -w: strictest type checking + show warnings (unused vars, unreachable
# code). monkeyc has no warnings-as-errors flag, so fail the build if any
# WARNING line appears.
build_out=$("$MONKEYC" -f "$JUNGLE" -d "$DEVICE" --unit-test -o bin/test.prg -y "$KEY" -l 3 -w 2>&1)
echo "$build_out"
if echo "$build_out" | grep -qE '^WARNING'; then
  echo "== Build produced warnings (treated as failure) ==" >&2
  exit 1
fi

echo "== Launching simulator =="
"$CONNECTIQ" >/tmp/ciq_sim.log 2>&1 &
SIM_PID=$!
trap 'kill "$SIM_PID" 2>/dev/null || true' EXIT
sleep 8

echo "== Running tests =="
LOG=/tmp/ciq_test.log
"$MONKEYDO" bin/test.prg "$DEVICE" -t >"$LOG" 2>&1 &
DO_PID=$!
for _ in $(seq 1 60); do
  grep -qiE 'ran [0-9]+ tests' "$LOG" && break
  sleep 1
done
kill "$DO_PID" 2>/dev/null || true

cat "$LOG"

if grep -qE '^PASSED \(' "$LOG"; then
  echo "== Tests passed =="
  exit 0
fi
echo "== Tests failed (see output above) ==" >&2
exit 1
