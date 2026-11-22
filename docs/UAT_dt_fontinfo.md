# Walk-sheet: the self-test stops crying font (0.3.6)

Brief: `docs/COWORK_BRIEF_dt_fontinfo.md`. **[G]** offline = the build session proves it in its report;
**[G] in game** = Tim types, and the saved file decides. **3 [G] offline, 1 [G] in game, 0 [H].** Back up first,
into `_dt_backups\2026-11-22_before_0.3.6b`.

## Offline [G]
- [ ] G1 `run_all.sh` ALL GREEN with counts; zip `diff -r` clean; `.toc`/`DT.VERSION` 0.3.6.
- [ ] G2 `ui:font` this session: S6 passes with `ui:font <n> (known, not counted)`. Any other id: S6 fails,
      naming it. Two runs in a row with S7 producing `ui:font`: 10 passed both times.
- [ ] G3 Every Task 3 guard removed → a named check red → restored.

## In game [G] (after a full restart of WoW)
- [ ] G4 `/dt selftest` **twice**, then `/reload`. Chat shows 10 passed, 0 failed both times, and the saved S6
      line reads `pass` with the `ui:font` note:
      `Select-String "<_forever_>\WTF\Account\*\SavedVariables\DeadTired.lua" -Pattern '"S6 '`
