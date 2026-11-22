# Walk-sheet: the font the game refuses once (hotfix 0.3.6)

Brief: `docs/COWORK_BRIEF_dt_fontload.md`. **[G]** offline = the build session proves it in its report;
**[G] in game** = Tim types, and the saved file decides; **[H]** = Tim's judgement. **3 [G] offline, 1 [G] in
game, 1 [H].** Back up first, the same way as for 0.3.5, into `_dt_backups\2026-11-22_before_0.3.6`.

## Offline [G]
- [ ] G1 `run_all.sh` ALL GREEN with counts; zip `diff -r` clean; `.toc`/`DT.VERSION` 0.3.6.
- [ ] G2 Refused at load then accepted: `ui:font` unchanged and the self-test reports 10 passed. Refused
      twice: counted once. One retry only.
- [ ] G3 Every Task 4 guard removed → a named check red → restored.

## In game [G] (after a full restart of WoW, not a /reload)
- [ ] G4 `/dt selftest`, then `/reload`. The saved record reads `S6 errors: pass` and the summary reads
      10 passed, 0 failed. Check with:
      `Select-String "<_forever_>\WTF\Account\*\SavedVariables\DeadTired.lua" -Pattern '"S6 '`

## In game [H]
- [ ] H1 The gothic titles look the same as in 0.3.5: Rest in Pieces, Who runs Dead Tired, settings.
