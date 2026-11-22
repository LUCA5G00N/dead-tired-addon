# Cowork brief: the font probe (0.3.7)

You are in `LUCA5G00N/dead-tired-addon`, building in a cloud session; Tim walks the result in game.
Read first, in order:
1. `CLAUDE.md` on `main`, and `docs/DECISIONS.md` 0001 and 0002.
2. This brief and its walk-sheet, `docs/UAT_dt_fontprobe.md`.
3. `DeadTired/UI.lua`: `measurer`, `DT.preloadFonts`, `DT.measure`, `DT.text`, the viewport's search box
   (`vp.search:SetFont`), `DT.fitCheck`. Then `DeadTired/Skins.lua`: `DT.font`, `fetch`, `DT.fontTo`,
   `DT.restyle`, the `setting` listener. Then `DeadTired/Debug.lua`, `DeadTired/Selftest.lua` (`KNOWN`)
   and `tests/test_textfit.lua` (`CreateFontString` only in `UI.lua`).

**Draft-status: written 22 Nov 2026, 18:10, against `main` at `4e38d1b` (0.3.6, released 15:33).** Re-read
every name above against the tree as Task 1's first act.

## Origin
Today's walks (22 Nov):
- **0.3.5 (12:47):** S6 failed on `ui:font`, "SetFont refused Fonts\MORPHEUS_CYR.TTF", 108 counted since 0.3.2.
- **Probe, 13:08:** a fresh `UIParent:CreateFontString()` accepted the same file. It printed `CYR true`,
  `CYR again true`, `plain true`.
- **0.3.6 first try, closed as #29:** a retry at load didn't clear the failure.
- **Probe, 13:53:** one `/dt debug fit` took `ui:font` from 174 to 237. DT's own strings are refused
  mid-session.
- **Since 0.3.2 (H1):** `/dt skin deadtired` leaves open windows' titles plain, yet a window opened
  afterwards is gothic. A `SetFont` the client refuses leaves the old font, which would explain it.

What differs between the accepted probe and DT's strings, as the code stands:
- every DT string is created with the template `GameFontHighlight`; the probe's had none;
- the preload and measure strings live on a **hidden** frame;
- DT's strings already hold a font when they are re-fonted.

The cause is not known. **This round only observes.** The fix is the next round, written from what this one
records.

## Precondition
`main` at `4e38d1b` or later, carrying this brief and its walk-sheet; `run_all.sh` `ALL GREEN`.

## Rulings in force (cited, not restated)
R-F5-5 (preload; `ui:font` counted); R-F10-1 (S6: `ui:font` is information); `CLAUDE.md` module rules 1–14,
the `CreateFontString`-only-in-`UI.lua` rule (`test_textfit`).

## Rulings for this round (to ratify)
- **R-F11-1 One door for DT's fonts.** Every `SetFont` DT makes goes through one function,
  `DT.fontCall(fs, path, size, flags, site, role)`, in `UI.lua`. The sites are `preload`, `fontTo`, `measure`
  and `search`. It returns what `SetFont` returned, and does what each site does now, nothing more. With the
  probe off it records nothing.
- **R-F11-2 The recorder.** `/dt debug fontprobe on` (this session only, never saved) records each
  `DT.fontCall` as one entry:
  - `site`, `role`, `skin` (`DT.skinName()`) and `path`, `size`, `flags`;
  - `res` (what `SetFont` returned) and `before` / `after` (`GetFont()` path, size and flags);
  - `vis` (`IsVisible()`) and `tpl` (`"GameFontHighlight"` or `"none"`, as DT created it).

  `/dt debug fontprobe off` stops it. Entries are saved as `DeadTiredDB.fontprobe.calls`, the last 300,
  overwritten by the next `on`.
- **R-F11-3 The matrix.** `/dt debug fontprobe matrix` creates eight control strings, once per session, all
  in `UI.lua`:
  - template `GameFontHighlight` or none;
  - on a shown frame or a hidden one;
  - starting from Friz Quadrata (each string is first set to `Fonts\FRIZQT__.TTF`).

  On each string it sets `Fonts\MORPHEUS_CYR.TTF` and then `Fonts\MORPHEUS.TTF` at 16 with flags `""`,
  recording `res` and `after` for each. The shown frame is 1×1, off-screen, with no text. Results go to
  `DeadTiredDB.fontprobe.matrix`, overwritten each run. It prints one line per string: `<tpl> <shown|hidden>:
  CYR <res>, plain <res>`.
- **R-F11-4 The summary.** `/dt debug fontprobe` prints the calls recorded, the refused calls broken down
  by `site`, `vis` and `tpl`, and how many refused calls had `after` still equal to `before` (the font
  didn't take).
- **R-F11-5 Only observes.** No font, path, skin or retry changes. `ui:font` is counted exactly as now, and
  S6 is unchanged.
- **R-F11-6 Version.** 0.3.7, and merging publishes it. The probe stays as a debug tool, like
  `/dt debug fit`. Tim walks it by installing from the branch.

## Deliverable
On `claude/dt-fontprobe` from `main`, DeadTired **0.3.7**:
- Every `SetFont` in `DeadTired/` goes through `DT.fontCall`. A static check proves it: no `:SetFont(`
  outside `DT.fontCall` and the matrix.
- In the harness, `fontprobe on` records each call with every field; `off` stops it.
- The matrix records eight strings × two paths.
- Behaviour with the probe off is unchanged: every existing suite is green without edits other than
  version lines.

Done when `run_all.sh` is `ALL GREEN`, every Task 6 guard has been removed once and turned a named check
red, and `dist/DeadTired-0.3.7.zip` passes `diff -r`.

## Working rules
- `CreateFontString` stays in `UI.lua` only (the matrix's strings too).
- Every read is guarded (`try`, `clean`). `GetFont`, `IsVisible` and `SetFont` results are recorded as
  `clean` gives them.
- In-memory "on". The saved data is capped and overwritten, and lives under its own key.

## Tasks
1. **Baseline** at the branch point; re-verify every name in "Read first"; list every `SetFont` call site.
2. **`UI.lua`**: `DT.fontCall` and the recorder; route `preload`, `measure` and `search` through it; the
   matrix strings.
3. **`Skins.lua`**: `DT.fontTo` calls `DT.fontCall`.
4. **`Debug.lua`** (or a new `FontProbe.lua` module with an On card; the report says which and why):
   the `debug fontprobe on|off|matrix` verbs and the summary.
5. **`tests/test_textfit.lua`**: the static check, no `:SetFont(` outside `DT.fontCall` and the matrix,
   with a fixture that must be caught.
6. **Tests and guard proofs**, in `test_ui.lua` (or `test_fontprobe.lua` for a new module).
   - **Tests:** every field recorded; refusals recorded with `after == before` when the stub refuses; `off`
     stops; capped at 300; overwritten by the next `on`; `on` is never saved; the matrix has 8 × 2 entries
     with the right labels; the summary's numbers; nothing recorded with the probe off; `ui:font` still
     counted at `fontTo` and the preload.
   - **Guards** (remove once, a named check red, restore): the record gate (off records nothing); the cap;
     the static check; `on` kept in memory; each site still counting `ui:font`.
   - Also every guard 0.3.6 proved.
7. **Docs**: `FEATURES.md` *Ruled 22 Nov (for `dt_fontprobe`, 0.3.7)*; `docs/RELEASE_0.3.7.md` (short: a
   tool for finding out why the gothic font is refused; nothing changes for players).
8. **Version and zip**: 0.3.7; `dist/DeadTired-0.3.7.zip`, `diff -r` clean. Draft the #dt-crypt-workshop
   post in the PR.
9. **Report** `docs/COWORK_REPORT_dt_fontprobe.md`; PR to `main`, not stacked.

## Out of scope
- Fixing the font, the skin switch or the repaint; any retry; any path change.
- Removing `ui:font` from S6's `KNOWN` (the fix round does that).
- Reading the recorded data. Tim sends it, and the next brief is written from it.

## The one deliberate widening
None. One function now routes calls that four sites made directly. With the probe off, its behaviour is
identical.

## Stop conditions
- Baseline not `ALL GREEN`, or `lua5.1` can't be installed → stop.
- A `SetFont` site that can't be routed through `DT.fontCall` without changing what it does → stop.
- Any existing suite needs an edit other than version lines → stop and report which and why.
- A guard removal turns nothing red: strengthen the test (test files only); if that needs addon code → stop.

## UAT: acceptance checks
`docs/UAT_dt_fontprobe.md`: **3 [G] offline, 2 [G] in game, 1 [H].**

## Reporting
`docs/COWORK_REPORT_dt_fontprobe.md`:
- branch and heads; counts per suite;
- every `SetFont` site and how it is routed;
- the static check and its fixture;
- each test and guard;
- the player-facing lines verbatim;
- zip name, size, sha256;
- anything in this brief that turned out wrong.

Never write a `_results.md` file.
