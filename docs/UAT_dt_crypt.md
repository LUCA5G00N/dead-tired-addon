# UAT walk-sheet: dt_crypt

Brief: `docs/COWORK_BRIEF_dt_crypt.md`. Extracted from its acceptance section.
**Checks: 12. `[H]` count: 1** (whether notices are welcome or noise is the guild's call).
Results go to `docs/UAT_dt_crypt_results.md`, written by Tim after walking.
**Amended 2026-11-02 (rulings round, A2):** G6 and G11 rewritten; see `docs/COWORK_BRIEF_dt_rulings.md`.

**Offline (the build session runs these):**
- [ ] `[G]` G1: `DeadTired/tests/run_all.sh` exits 0 and runs seven suites (core, guild, comms,
  roster, alts, welcome, crypt).
- [ ] `[G]` G2: the report lists all nine Task 9 guard removals, each with the check that went
  red.
- [ ] `[G]` G3: `grep -rE "COMBAT_LOG|CombatLog|SendChatMessage|C_DeathRecap|UNIT_DIED|PARTY_KILL" DeadTired/`
  finds nothing.
- [ ] `[G]` G4: `git diff card/dt_foundation --stat -- DeadTired/` lists only `Crypt.lua`,
  `tests/test_crypt.lua`, `DeadTired.toc` (1 line added) and `tests/run_all.sh` (1 line changed).
- [ ] `[G]` G5: the report gives the byte length of the longest DEATH, and it is at most 250.

**In game (Tim, with one guildie, both on this branch):**
- [ ] `[G]` G6 *(amended)*: `/reload` on a normal character shows no Lua error, and the only line is card 1's
  welcome.
- [ ] `[G]` G7: on a normal realm, Tim dies with `share` never set: the guildie sees no notice.
  Tim runs `/dt rip share on` and dies again: the guildie sees exactly one line naming Tim's
  character, level and zone.
- [ ] `[G]` G8: `/dt graveyard` on both sides lists that second death (and Tim's own list has the
  first too), and ends with "Only guildies running the addon, and only deaths seen while you were
  online."
- [ ] `[G]` G9: the guildie runs `/dt rip off`; Tim dies again: no line on the guildie's side,
  but their `/dt graveyard` has it.
- [ ] `[G]` G10: Tim runs `/dt bedtime` set to 2 minutes from now: one line at that minute, no
  second line inside 30 minutes. `/dt bedtime off` and `/reload`: no line.
- [ ] `[G]` G11 *(amended)*: *only if Forever has a hardcore realm:* a new hardcore character in the guild logs
  in: one line pointing at `/dt rip share on`. `/reload`: the line does not come back. It dies with
  `share` unset: the guildie sees nothing. After `/dt rip share on`, its next death shows the
  guildie the "Rest in Pieces … Hardcore. Gone for good." line. No hardcore realm: write
  "not walkable" in the results.
- [ ] `[H]` H1: **after a raid night, did the notices feel like part of the guild, or like noise
  you'd turn off?**

**`[H]` count: 1.** Whether a death notice is welcome or noise is the guild's call, and R1 is a
bet on it. If H1 comes back "noise", the default for R1 flips to off before merge.
