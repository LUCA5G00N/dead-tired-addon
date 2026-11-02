# UAT walk-sheet: dt_pvp

Brief: `docs/COWORK_BRIEF_dt_pvp.md`. Extracted from its acceptance section.
**Checks: 12. `[H]` count: 1** (whether a button press fits how the guild really fights).
Results go to `docs/UAT_dt_pvp_results.md`, written by Tim after walking.

**Offline (the build session runs these):**
- [ ] `[G]` G1: `DeadTired/tests/run_all.sh` exits 0 and runs seven suites (core, guild, comms,
  roster, alts, welcome, gank).
- [ ] `[G]` G2: the report lists all eight Task 9 guard removals, each with the check that went
  red.
- [ ] `[G]` G3: `grep -rE "COMBAT_LOG|CombatLog|SendChatMessage|C_DeathRecap|UNIT_DIED|PARTY_KILL|NotifyInspect|UnitAura|C_UnitAuras|UnitRace|UnitHealth" DeadTired/`
  finds nothing.
- [ ] `[G]` G4: `git diff card/dt_foundation --stat -- DeadTired/` lists only `Gank.lua`,
  `tests/test_gank.lua`, `DeadTired.toc` (1 line added) and `tests/run_all.sh` (1 line changed).
- [ ] `[G]` G5: the report gives the byte length of the longest GANK, and it is at most 250.

**In game (Tim, with one guildie, both on this branch):**
- [ ] `[G]` G6: `/reload` shows no Lua error, and the only line printed is card 1's welcome.
- [ ] `[G]` G7: Tim makes a macro `/dt gank` and presses it on: no target; an NPC; a Horde player.
  Each gets its refusal line and nothing is recorded (`/dt ganks` still says "No grudges yet").
- [ ] `[G]` G8: Tim presses it on an Alliance player: one "Noted: …" line with the right name,
  class, level and zone. A second press within 5 minutes: "Already noted."
- [ ] `[G]` G9: on the guildie's side nothing was printed. Their `/dt ganks` lists that player
  first, with the class, level, zone and "by 1 guildie", and ends with "Only logs from guildies
  running the addon, seen while you were online."
- [ ] `[G]` G10: the guildie runs `/dt ganks <that name>` and gets the entry, logged by Tim's
  character.
- [ ] `[G]` G11: Tim presses the macro on an Alliance player **in combat**. Either a "Noted"
  line with the right name, or the "won't say who that is" line with nothing recorded. Write down
  which: it answers the secret-value question for the next card.
- [ ] `[H]` H1: **mid-fight, did you actually press it, or did you forget it existed until
  afterwards?**

**`[H]` count: 1.** Whether a button press fits how the guild really fights is a judgement only a
fight answers. If H1 is "forgot it existed", the board stays thin whatever the code does. Note it
before card 6 or the bounty board is briefed.
