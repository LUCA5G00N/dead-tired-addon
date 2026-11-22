# Cowork brief: the font the game refuses once (hotfix 0.3.6)

You are in `LUCA5G00N/dead-tired-addon`, building in a cloud session; Tim walks the result in game.
Read first, in order:
1. `CLAUDE.md` on `main`, and `docs/DECISIONS.md` 0001.
2. This brief and its walk-sheet, `docs/UAT_dt_fontload.md`.
3. `DeadTired/UI.lua` (`DT.preloadFonts`, `DT.preloaded`, the `loaded` listener), `DeadTired/Skins.lua`
   (`DT.font`, `fetch`, `DT.fontTo`), `DeadTired/Core.lua` (`DT.after`, `DT.fail`),
   `DeadTired/tests/test_skins.lua` (the R-F5-5 block), `DeadTired/Selftest.lua` (S6).

**Draft-status: written 22 Nov 2026, 13:15, against `main` at `cbd4055` (0.3.5, released 12:58).**
Re-read every name above against the tree as Task 1's first act.

## Origin
The 0.3.5 walk (22 Nov, 12:47). `/dt selftest` on its first live run: 9 passed, 1 failed,
`S6 errors: FAIL - ui:font 1`. `/dt debug errors`: `ui:font: 108 "title: SetFont refused
Fonts\MORPHEUS_CYR.TTF"`, so one refusal has been counted at nearly every login since 0.3.2 (R-F5-5's preload).
**Probe, 13:08** (Tim, `/run` on a fresh FontString, screenshot `WoWScrnShot_112226_130817.jpg`):
`CYR true`, `CYR again true`, `plain true`. The file works once loaded, and the gothic titles show in
every window. **The refusal comes only from the first touch at login,** while the client is still loading
the file. LibSharedMedia's western mapping of "Morpheus" to `MORPHEUS_CYR.TTF` is not the cause.

## Precondition
`main` at `cbd4055` or later, carrying this brief and its walk-sheet; `run_all.sh` `ALL GREEN`.

## Rulings in force (cited, not restated)
R-F5-5 (fonts set at load on one hidden string; a false from `SetFont` counted under `ui:font`).
`dt_selftest` R-F8-1 (S6 fails on any error this session).

## Rulings for this round (to ratify)
- **R-F9-1 Once more, then count.** In `DT.preloadFonts`, a `SetFont` that answers `false` is tried once
  more, about 1 second later (`DT.after`), on the same hidden string. Only a second `false` is counted under
  `ui:font`, with the same text as now. A font accepted on the retry is counted nowhere.
- **R-F9-2 Everything else as now.** `DT.fontTo` (live windows) still counts a `false` at once. Which font
  paths are used, LibSharedMedia's part in that, and `DT.preloaded` are unchanged.
- **R-F9-3 History stays.** The `ui:font` count already saved (108 on Tim's account) is not reset.
  It is history, and S6 counts this session only.
- **R-F9-4 Version.** 0.3.6, a fix. The release notes drop 0.3.5's "one known failure" line.

## Deliverable
On `claude/dt-fontload` from `main`, DeadTired **0.3.6**. In the harness, a font refused at load and
accepted 1 s later counts nothing, and `/dt selftest` then reports 10 passed, 0 failed. A font refused twice
is counted once, as now. Done when `run_all.sh` is `ALL GREEN`, every Task 4 guard has been removed once
and turned a named check red, and `dist/DeadTired-0.3.6.zip` passes `diff -r`.

## Working rules
- Only `DT.preloadFonts` changes behaviour. The retry uses `DT.after`, touches only DT's own hidden
  string, and runs at most once per refused font per load.
- No new player-facing text, event, setting or saved key.

## Tasks
1. **Baseline** at the branch point: suites and checks; re-verify the names in "Read first".
2. **`UI.lua`**: R-F9-1 in `DT.preloadFonts`.
3. **`tests/test_skins.lua`**: the R-F5-5 "false at load is counted" check becomes two checks:
   - refused at load and then accepted: counted 0;
   - refused at load and again on the retry: counted 1.
   Add a check that the retry happens once only (a third call is never made). `test_selftest`: a client
   whose first gothic `SetFont` answers `false` reports 10 passed after the retry.
4. **Guard proofs** (remove once, a named check red, restore):
   - the retry, if removed, counts the first refusal;
   - only a second false is counted;
   - one retry only;
   - `fontTo` still counts at once.
   Also every guard 0.3.5 proved.
5. **Docs**: `FEATURES.md` *Ruled 22 Nov (for `dt_fontload`, 0.3.6)*; `docs/RELEASE_0.3.6.md` (DT's
   voice, short: the self-test's one failure is gone; nothing else changes).
6. **Version and zip**: 0.3.6; `dist/DeadTired-0.3.6.zip`, `diff -r` clean. Draft the #dt-crypt-workshop
   post in the PR.
7. **Report** `docs/COWORK_REPORT_dt_fontload.md`; PR to `main`, not stacked.

## Out of scope
- Changing font paths, or how LibSharedMedia is asked.
- Resetting saved error counts.
- The skin switch that doesn't repaint open windows (0.3.2's H1). It may share a cause with this, but it
  has its own probe round.
- Anything else the self-test may report.

## The one deliberate widening
None. This narrows when R-F5-5 counts; it doesn't widen anything.

## Stop conditions
- Baseline not `ALL GREEN`, or `lua5.1` can't be installed → stop.
- The fix needs a change outside `DT.preloadFonts` (bar tests) → stop.
- A guard removal turns nothing red: strengthen the test (test files only); if that needs addon code → stop.

## UAT: acceptance checks
`docs/UAT_dt_fontload.md`: **3 [G] offline, 1 [G] in game, 1 [H].**

## Reporting
`docs/COWORK_REPORT_dt_fontload.md`: branch and heads; counts per suite; the test diff in `test_skins.lua`
and why each old check changed; guard proofs; zip name, size, sha256; anything in this brief that turned
out wrong. Never write a `_results.md` file.
