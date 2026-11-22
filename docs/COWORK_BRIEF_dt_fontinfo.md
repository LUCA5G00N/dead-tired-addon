# Cowork brief: the self-test stops crying font (0.3.6)

You are in `LUCA5G00N/dead-tired-addon`, building in a cloud session; Tim walks the result in game.
Read first, in order:
1. `CLAUDE.md` on `main`, and `docs/DECISIONS.md` 0001.
2. This brief and its walk-sheet, `docs/UAT_dt_fontinfo.md`.
3. `DeadTired/Selftest.lua` (the `DT.fail` wrapper, `session`, S6, S7, `DT.selftest`) and
   `DeadTired/tests/test_selftest.lua`.

**Draft-status: written 22 Nov 2026, 14:05, against `main` at `e195a00` (0.3.5; PR #28's brief merged).**
Re-read the names above against the tree as Task 1's first act.

## Origin
The 0.3.5 walk found S6 failing on `ui:font` ("SetFont refused Fonts\MORPHEUS_CYR.TTF"). `dt_fontload` assumed
the cause was the first load at login, and was closed unmerged (PR #29, 22 Nov 13:59) after:
- **the 0.3.6 walk**, where S6 still failed after a fresh login;
- **the probe at 13:53**, where one `/dt debug fit` took `ui:font` from 174 to 237 (screenshots
  `WoWScrnShot_112226_1353*.jpg`).

So the gothic title font is refused whenever DT repaints its own strings in that skin, mid-session too,
although a fresh FontString accepts it (probe, 13:08). The cause is not known. It goes to the skin-switch
probe round. Meanwhile S6 fails for every guildie on that refusal, and S7's own `DT.fitCheck` adds about 63
refusals, so **a second `/dt selftest` in one session fails S6 because of the first.**

## Precondition
`main` at `e195a00` or later, carrying this brief and its walk-sheet; `run_all.sh` `ALL GREEN`.

## Rulings in force (cited, not restated)
`dt_selftest` R-F8-1 (S1–S11) and R-F8-2 (the record). R-F5-5 (a false from `SetFont` counted under
`ui:font`): unchanged here.

## Rulings for this round (to ratify)
- **R-F10-1 The font is information, for now.** S6 leaves the `ui:font` error id out of its pass or fail. If
  any were counted this session, the S6 line says so after its verdict (`…; ui:font <n> (known, not counted)`).
  Every other error id fails S6 as now.
- **R-F10-2 The self-test doesn't fail itself.** Errors recorded *while* `DT.selftest` runs (S7's repaints,
  above all) don't count in a later run's S6. They are still recorded under `errors` as now.
- **R-F10-3 Nothing else changes.** `ui:font` is still counted and shown by `/dt debug errors`. Fonts, skins,
  and every other check stay as they are. `dt_fontload`'s retry is not built.
- **R-F10-4 Version.** 0.3.6. The release notes say S6 treats the font refusal as known, and that the font is
  being investigated.

## Deliverable
On `claude/dt-fontinfo` from `main`, DeadTired **0.3.6**. In the harness, a client that counts `ui:font`
refusals at load and during S7 reads **10 passed, 0 failed on two runs in a row**. A client with any other
error this session still fails S6. Done when `run_all.sh` is `ALL GREEN`, every Task 3 guard has been removed
once and turned a named check red, and `dist/DeadTired-0.3.6.zip` passes `diff -r`.

## Working rules
- Changes are confined to `Selftest.lua` and its tests (and the version, docs and zip).
- No new player-facing text except the S6 suffix in R-F10-1.

## Tasks
1. **Baseline** at the branch point; re-verify the names in "Read first".
2. **`Selftest.lua`**: R-F10-1 and R-F10-2.
3. **Tests and guard proofs** in `test_selftest.lua`. Tests:
   - a `ui:font` failure this session: S6 passes, with the suffix;
   - another id: S6 fails, naming it;
   - both together: S6 fails, naming only the other id;
   - an error recorded during a run: the next run's S6 passes;
   - two runs in a row with S7 producing `ui:font`: 10 passed both times.
   Guards (remove once, a named check red, restore): the `ui:font` exclusion; other ids still fail; the
   in-run exclusion. Also every guard 0.3.5 proved, with S6's existing guard kept red.
4. **Docs**: `FEATURES.md` *Ruled 22 Nov (for `dt_fontinfo`, 0.3.6)*; `docs/RELEASE_0.3.6.md`.
5. **Version and zip**: 0.3.6; `dist/DeadTired-0.3.6.zip`, `diff -r` clean. Draft the #dt-crypt-workshop
   post in the PR.
6. **Report** `docs/COWORK_REPORT_dt_fontinfo.md`; PR to `main`, not stacked.

## Out of scope
The font refusal itself and the skin switch that doesn't repaint open windows (the skin-switch probe round).
Resetting saved error counts. Changing S7, or any other check.

## The one deliberate widening
R-F10-1 makes one error id not count against S6. It is bounded by naming exactly `ui:font`, by still
showing the count on the S6 line and in `/dt debug errors`, and it is meant to be removed by the round that
fixes the font. That round's brief must say so.

## Stop conditions
- Baseline not `ALL GREEN`, or `lua5.1` can't be installed → stop.
- The change needs code outside `Selftest.lua` → stop.
- A guard removal turns nothing red: strengthen the test (test files only); if that needs addon code → stop.

## UAT: acceptance checks
`docs/UAT_dt_fontinfo.md`: **3 [G] offline, 1 [G] in game, 0 [H].**

## Reporting
`docs/COWORK_REPORT_dt_fontinfo.md`: branch and heads; counts per suite; each test and guard; the S6 line's
new text, verbatim; zip name, size, sha256; anything in this brief that turned out wrong. Never write a
`_results.md` file.
