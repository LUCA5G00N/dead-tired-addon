# UAT walk-sheet: dt_audit

Brief: `docs/COWORK_BRIEF_dt_audit.md`. **Checks: 6. `[H]` count: 1.**

- [ ] `[G]` G1: `docs/AUDIT_2026-11-02.md` exists on `audit/2026-11-02`, starting with the branch
  heads audited, the baseline counts and the findings per severity.
- [ ] `[G]` G2: every blocker and high has a test in `audit/tests/` that fails now, or a stated
  reason it can't be reproduced offline. `audit/tests/README.md` says how to run each.
- [ ] `[G]` G3: `git diff main --stat` on `audit/2026-11-02` lists files under `audit/` and
  `docs/` only, and no card branch moved during the round.
- [ ] `[G]` G4: the traffic section gives messages per minute at login and over the hour, peak
  queue length, and anything dropped, for 20 clients.
- [ ] `[G]` G5: every finding has a *known to the report?* value.
- [ ] `[H]` H1: **reading the summary table, would you change anything before launch because of
  it, and which findings do you want fixed in the fix round?** (Tim's ruling feeds the fix brief.)
