# UAT walk-sheet: dt_logs (combat-log prompt)

Brief: `docs/COWORK_BRIEF_dt_logs.md`. **Checks: 10. `[H]` count: 1** (whether the prompt helps
or nags is the guild's call).

**Offline (the build session runs these):**
- [ ] `[G]` G1: `DeadTired/tests/run_all.sh` exits 0 and runs seven suites (core, guild, comms,
  roster, alts, welcome, logs).
- [ ] `[G]` G2: the report lists all seven Task 6 guard removals, each with the check that went
  red.
- [ ] `[G]` G3: `grep -rnE "LoggingChat|COMBAT_LOG|CombatLog|SendChatMessage" DeadTired/ --include=*.lua | grep -v "/tests/"`
  finds nothing, and `grep -rn "LoggingCombat(" DeadTired/ --include=*.lua | grep -v "/tests/"`
  finds only a call with no argument.
- [ ] `[G]` G4: `git diff card/dt_foundation --stat -- DeadTired/` lists only `Logs.lua`,
  `tests/test_logs.lua`, `DeadTired.toc` (1 line added) and `tests/run_all.sh` (1 line changed).

**In game (Tim, in the guild, combat log off: check with `/dt logs`):**
- [ ] `[G]` G5: `/reload` in Orgrimmar: no Lua error, no dialog (login asking is off by default).
- [ ] `[G]` G6: walk into a dungeon: the dialog shows once. **Log it**: the line says logging, and
  `/dt logs` agrees. A new `WoWCombatLog-*.txt` appears in `_forever_\Logs`.
- [ ] `[G]` G7: `/combatlog` to switch it off, leave, re-enter: dialog. **Not now**. `/reload`
  inside: no dialog. Leave and re-enter: dialog again.
- [ ] `[G]` G8: `/dt logs off`, leave and re-enter: no dialog. `/dt logs on` restores it. In a
  battleground: never a dialog.
- [ ] `[G]` G9: `/dt logs login on`, `/reload`: the dialog shows at login. `/dt logs login off`:
  it doesn't.
- [ ] `[H]` H1: **after a week of dungeons and a raid night: did the prompt mean the logs got
  taken, or did people just click it away?**
