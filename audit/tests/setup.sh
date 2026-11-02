#!/bin/sh
# Check out every card branch read-only (detached) into a scratch directory, for the audit tests.
#   sh audit/tests/setup.sh            (from the repo root)
# DT_AUDIT_WT picks the directory (default /tmp/dt-audit-wt). Re-running refreshes each checkout
# to the branch's current head. Nothing is written to any card branch.
cd "$(dirname "$0")/../.." || exit 2
WT="${DT_AUDIT_WT:-/tmp/dt-audit-wt}"
mkdir -p "$WT"
git fetch -q origin 'refs/heads/card/*:refs/remotes/origin/card/*' || echo "setup: fetch failed; using local refs"
for b in dt_foundation dt_crypt dt_pvp dt_prep dt_stretch dt_logs dt_probe; do
  if [ -d "$WT/$b/.git" ] || [ -f "$WT/$b/.git" ]; then
    git -C "$WT/$b" checkout -q --detach "origin/card/$b" || exit 1
  else
    git worktree add -q --detach "$WT/$b" "origin/card/$b" || exit 1
  fi
  echo "setup: $b at $(git -C "$WT/$b" rev-parse --short HEAD)"
done
