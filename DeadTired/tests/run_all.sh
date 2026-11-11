#!/bin/sh
# Run every Dead Tired offline suite. From the repo root: sh DeadTired/tests/run_all.sh
# Every DeadTired/<File>.lua (but Config.lua) must have DeadTired/tests/test_<file>.lua; a missing
# suite is a failure. Then the cross-file suites (taint), then the bundled libraries' hashes
# (Libs/SHA256SUMS: unmodified upstream files). Exits non-zero if anything fails.
cd "$(dirname "$0")/../.." || exit 2
LUA="${LUA:-lua5.1}"
if ! command -v "$LUA" >/dev/null 2>&1; then echo "lua5.1 not found"; exit 2; fi
status=0
for mod in DeadTired/*.lua; do
  base=$(basename "$mod" .lua)
  [ "$base" = Config ] && continue
  f="DeadTired/tests/test_$(echo "$base" | tr 'A-Z' 'a-z').lua"
  if [ ! -f "$f" ]; then echo "$base: MISSING $f"; status=1; continue; fi
  "$LUA" "$f" || status=1
done
"$LUA" DeadTired/tests/test_taint.lua || status=1
if (cd DeadTired/Libs && sha256sum -c --quiet SHA256SUMS); then echo "libs: unmodified (SHA256SUMS)"; else echo "libs: CHANGED"; status=1; fi
[ $status -eq 0 ] && echo "ALL GREEN" || echo "SOMETHING IS ROTTEN"
exit $status
