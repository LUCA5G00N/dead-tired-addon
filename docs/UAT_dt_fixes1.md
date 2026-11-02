# UAT walk-sheet: dt_fixes1 (audit fix round 1)

Brief: `docs/COWORK_BRIEF_dt_fixes1.md`. **Checks: 7. `[H]` count: 0.**

**Offline (the build session runs these):**
- [ ] `[G]` G1: every card branch's `DeadTired/tests/run_all.sh` exits 0 at its new head.
- [ ] `[G]` G2: `sh audit/tests/run_all.sh` (unchanged audit tests) against the new heads:
  AUD-01, 02, 03, 04, 07 pass; AUD-06 still fails; traffic passes.
- [ ] `[G]` G3: the traffic table shows S1b (20 logins in 2 s) well under the audit's 400
  messages, and nothing dropped in any scenario.
- [ ] `[G]` G4: the report lists every Task 6 guard removal with the check that went red.
- [ ] `[G]` G5: `git diff <old head> --stat` on each card branch 3-7 shows card 1's files changed
  only by the merge (identical to `card/dt_foundation`'s new files).
- [ ] `[G]` G6: no `audit/` file changed (`git diff origin/audit/2026-11-02 -- audit/` on the
  audit worktree is empty).

**In game (added to card 1's walk, after its G6):**
- [ ] `[G]` G7: with Tim and the guildie both online and listing each other, Tim `/reload`s:
  within 20 seconds `/dt who` on Tim lists the guildie again. Then Tim logs out and back in: the
  same.
