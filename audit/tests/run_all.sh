#!/bin/sh
# Run every audit test. From the repo root: sh audit/tests/run_all.sh
# Checks out the card branches first (setup.sh). Each reproducing test asserts the behaviour the
# audit says is right, so on the audited heads it FAILS (red): that is the finding reproduced.
# After a fix round, each should pass. Exits non-zero while any test fails.
cd "$(dirname "$0")/../.." || exit 2
LUA="${LUA:-lua5.1}"
if ! command -v "$LUA" >/dev/null 2>&1; then echo "lua5.1 not found"; exit 2; fi
sh audit/tests/setup.sh || exit 2
status=0
for t in roster_reload:AUD-01 prep_reload:AUD-02 stash_reload:AUD-03 gank_reboot:AUD-04 \
         realm_spelling:AUD-06 death_flood:AUD-07 traffic:traffic; do
  f="audit/tests/test_${t%%:*}.lua"
  if "$LUA" "$f" >"/tmp/dt-audit-${t%%:*}.out" 2>&1; then r=green; else r=RED; status=1; fi
  echo "${t#*:} ${t%%:*}: $r ($(tail -1 "/tmp/dt-audit-${t%%:*}.out"))"
done
exit $status
