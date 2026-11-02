# UAT walk-sheet: dt_stretch

Brief: `docs/COWORK_BRIEF_dt_stretch.md`. Extracted from its acceptance section.
**Checks: 11. `[H]` count: 1** (whether the slowest-leveller award lands as a joke).
Results go to `docs/UAT_dt_stretch_results.md`, written by Tim after walking.

**Offline (the build session runs these):**
- [ ] `[G]` G1: `DeadTired/tests/run_all.sh` exits 0 and runs nine suites (core, guild, comms,
  roster, alts, welcome, stash, played, events).
- [ ] `[G]` G2: the report lists all seventeen Task 10 guard removals, each with the check that
  went red.
- [ ] `[G]` G3:
  `grep -rnE "RequestTimePlayed|SendChatMessage|COMBAT_LOG|CombatLog|C_DeathRecap|C_Calendar" DeadTired/ --include=*.lua | grep -v "/tests/"`
  finds nothing.
- [ ] `[G]` G4: `git diff card/dt_foundation --stat -- DeadTired/` lists only the four new files,
  the three new suites, `DeadTired.toc` (4 lines added) and `tests/run_all.sh` (1 line changed).
- [ ] `[G]` G5: the report gives the byte length of the longest STASH, STASHQ and PLAYED, each
  at most 250.

**In game (Tim, with one or two guildies, all on this branch):**
- [ ] `[G]` G6: `/reload` shows no Lua error, and the only line printed is card 1's welcome.
- [ ] `[G]` G7: guildie A runs `/dt stash share on`, then opens their bank once; guildie B leaves
  sharing off. Tim's `/dt stash linen`: after 10 s, A's character and the right count are listed
  (bank included), and B isn't. A soulbound item searched by name never appears.
- [ ] `[G]` G8: Tim runs `/dt slowest share on` and then types `/played`. A guildie's
  `/dt slowest` lists Tim's character with hours per level matching `/played ÷ level` to one
  decimal place. No `/played` lines ever appeared in Tim's chat except when he typed it.
- [ ] `[G]` G9: `/dt events` names the next Fishing Extravaganza. Its day and time match
  Forever's real schedule and the realm clock. If they don't, write down the real schedule (it
  goes in `EventsList.lua`) and the clock's offset.
- [ ] `[G]` G10: `/dt events remind on` with an event 35 minutes away (edit `EventsList.lua`
  locally to make one): one line 30 minutes before, one at the start, nothing else. Then
  `/dt events remind off`: nothing.
- [ ] `[H]` H1: **would the slowest leveller laugh at the award, or feel singled out?**

**`[H]` count: 1.** Whether a joke award lands on the person it names is the guild's call, and
only a person can make it. If H1 is "singled out", `/dt slowest` is removed from the `.toc`
before merge; nothing else depends on it.
