#!/bin/sh
# Run every Dead Tired offline suite. From the repo root: sh DeadTired/tests/run_all.sh
# Exits non-zero if any suite fails.
cd "$(dirname "$0")/../.." || exit 2
LUA="${LUA:-lua5.1}"
if ! command -v "$LUA" >/dev/null 2>&1; then echo "lua5.1 not found"; exit 2; fi
status=0
for pair in core:Core guild:Guild comms:Comms roster:Roster alts:Alts welcome:Welcome crypt:Crypt; do
  m="${pair%%:*}"; mod="DeadTired/${pair#*:}.lua"
  f="DeadTired/tests/test_$m.lua"
  if [ ! -f "$f" ]; then
    # A module with no suite is a failure; a module not built yet is only noted.
    if [ -f "$mod" ]; then echo "$m: MISSING $f"; status=1; else echo "$m: not built yet"; fi
    continue
  fi
  "$LUA" "$f" || status=1
done
[ $status -eq 0 ] && echo "ALL GREEN" || echo "SOMETHING IS ROTTEN"
exit $status
