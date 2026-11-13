# Cowork brief: DEAD TIRED fix round 5 (two-line rows; skin switch repaints; 0.3.2)

You are in `LUCA5G00N/dead-tired-addon`, building in a cloud session; Tim walks the result in game.
Read first, in order:
1. `CLAUDE.md` on `main` (including *What every module must do*).
2. This brief and its walk-sheet, `docs/UAT_dt_fixes5.md`.
3. `docs/UAT_dt_fixes4_results.md`: *Defects and requests* 1-3.
4. `DeadTired/UI.lua` (`DT.text`, `DT.list`, `DT.fitCheck`), `Skins.lua`, then `Events.lua`,
   `Stash.lua`, `Played.lua`.

**Draft-status: ratified by Tim 2026-11-13** (15:10: R-F5-1 to R-F5-5 as written). Written
against `main` at `9ae2fd6` (0.3.1); if `main` has moved, re-read the file references before
Task 1. The drafting session had no `lua5.1`: the baseline (26 suites, 1319 checks) is the
`dt_fixes4` report's, not re-run.

## Origin
The 0.3.1 walk (13 Nov) carried three findings, and Tim's `/dt events` shot of 14:32 a fourth:
1. Switching skin doesn't repaint a window that is already open (H1 partial).
2. Glacial Progress cuts the name (`Stromham Hams...`) and its tooltip shows the name twice.
3. The cut mark shows as three dots in game where the brief said `…`.
4. Events cuts both halves of its row: `Stranglethorn Fishing Extrava...` and
   `Sunday 14:00 server time, in 1d...`. Tim: "we could make these cards two lines first the name
   second the details."

## Precondition
`main` at `9ae2fd6` or later, carrying this brief and its walk-sheet, with
`sh DeadTired/tests/run_all.sh` printing `ALL GREEN`.

## Rulings in force (cited, not restated)
`CLAUDE.md`, all of it. `docs/FEATURES.md`, *Ruled 12 Nov (for `dt_fixes4`)*: R-F4-1 (text fit),
R-F4-2 (DT cuts the text itself), R-F4-3 (the skins). Tim, 13 Nov, on the `dt_fixes4` report's
questions: the On cards keep the stock wording; the AddOns-page title, template button labels and
the log prompt left up in combat stay as they are.

## Rulings for this round (ratified 2026-11-13)
- **R-F5-1 Two-line rows amend R-F4-1.** A list row is one line, or two where the list
  declares a detail line: the first line as now, the second one muted line of detail under it.
  Each line is still a `line` (cut to its width, the full text in the row's tooltip), and every
  row in a list is one height.
- **R-F5-2 Which lists.** Two-line: Events, Who has it, Glacial Progress. One-line, as
  they are: the graveyard, Grudges, Who.
- **R-F5-3 The detail lines.** Events: the `when` text. Who has it: the items.
  Glacial Progress: the three existing texts joined with commas, `3.0 h/level, level 36,
  108.6 h played`. No other new wording.
- **R-F5-4 The cut mark.** DT writes `…` (one character); the game's font draws it as
  three dots. That is accepted: no code change, and the docs say "three dots".
- **R-F5-5 The skin switch, cause unproven.** The guess is that a font not
  yet used this session isn't ready when the open window is re-fonted (the gothic font stopped
  being loaded at login when `clean` became the default). The round therefore does two things:
  every skin's fonts are set once on a hidden string at load, and a skin change repaints at once
  and again on the next frame. **This is an experiment: its falsifier is H1.** If H1 fails, the
  guess is wrong, the two changes stay (they are harmless), and the next round starts with an
  in-game probe instead of another guess.

## Deliverable
On a branch from `main` (the session's own branch is fine), DeadTired **0.3.2**: Events, Who has
it and Glacial Progress draw two-line rows under R-F5-1 and R-F5-3; a cut cell's text is not
repeated in a tooltip that already shows it; every skin's fonts are loaded at start and a skin
change repaints twice. Done when `run_all.sh` prints `ALL GREEN`, every guard in Task 6 has been
removed once and turned a named check red, `/dt debug fit` in the harness reports `0 over` on all
three skins with the 0.3.1 fixture's event row no longer cut, and `dist/DeadTired-0.3.2.zip`
passes `diff -r`.

## Working rules
- New player-facing text: only R-F5-3's joined line. Anything else goes in the report as a question.
- Window sizes, titles, footers and every 0.3.1 line stay. The three one-line lists are not touched.
- All text through `DT.text` (`test_textfit.lua` stays green). No new library, hook or global.

## Tasks
1. **Baseline.** `run_all.sh` at the branch point: `ALL GREEN`; record suites and checks.
2. **`DT.list`: the detail line (`UI.lua`).** New option `detail = { key = "<row field>" }`.
   With it each row has a second `line` (role `small`, colour `muted`) under the first, starting
   at the flex column's left edge and running to the list's right padding. The row height is one
   fixed number per list, from the skin's row spacing and small font size (never from the text),
   recomputed on a skin change. `count` becomes the number of such rows that fit the list's
   declared height (the viewport body's, declared the way `dtWidth` is, never a layout read), so the last row sits inside the body; a list without `detail` behaves exactly
   as in 0.3.1. A cut detail line adds its full text to the tooltip like a cut cell.
   `DT.fitCheck` counts detail lines among the strings and the cut rows.
3. **Tooltips don't repeat.** New option `tipCovers = { "<key>", ... }`: keys whose full text the
   module's own `tip` already shows; the list does not add those when cut. Set it for `name` on
   Glacial Progress, the graveyard and Grudges.
4. **The three lists.**
   - `Events.lua`: columns `{ name flex }`, `detail = when`.
   - `Stash.lua`: columns `{ holder flex }`, `detail = items`.
   - `Played.lua`: columns `{ n fixed, name flex }`, `detail = detailText`, where `detailText` is
     `rateText .. ", " .. lvlText .. ", " .. hoursText`. Search text unchanged.
5. **Skin switch (`Skins.lua`, `UI.lua`).**
   - On the `loaded` signal, for every skin in `DT.skins` and every font role it or the base
     names, call `SetFont` once on a hidden string (reuse `DT.measure`'s host).
   - On a `core.skin` change, `DT.restyle()` runs as now and once more through `DT.after(0, ...)`.
   - `DT.fontTo`: where `SetFont` returns exactly `false`, count it in `DeadTiredDB.errors` under
     `ui:font` and carry on.
6. **Guard proofs** (`tools/guard_proofs.lua`; remove once, a named check red, restore): the
   detail line is cut to its width; a cut detail's text reaches the tooltip; a detail list's rows
   are one height; `count` keeps the last row inside the body; `tipCovers` suppresses the repeat;
   a list without `detail` is unchanged (0.3.1's list checks still pass untouched); fonts set at
   load for every skin; the second repaint is scheduled on a skin change; a `false` from
   `SetFont` is counted. Plus every guard 0.3.1 proved (109), still proved.
7. **Docs.** `docs/FEATURES.md`: add *Ruled 13 Nov (for `dt_fixes5`)* with R-F5-1 to R-F5-5 and
   Tim's four answers on the `dt_fixes4` report's questions; where it says `…`, say "three dots
   (the game's font draws `…` that way)". New `docs/RELEASE_0.3.2.md` (draft, DT's voice, short).
8. **Version and zip.** `.toc` and `DT.VERSION` to `0.3.2`; `sh tools/package.sh` →
   `dist/DeadTired-0.3.2.zip`, `diff -r` clean. Leave the older zips.
9. **Report** `docs/COWORK_REPORT_dt_fixes5.md`.

## Out of scope
The waypointer; profiles and the sharing panel; the gank rework; changing columns, widths or
window sizes on the graveyard, Grudges or Who; two-line rows anywhere else; template button
labels; the On cards' wording; the AddOns-page title; the log prompt in combat; a font setting;
replacing `…` with three typed dots; publishing the release (Tim's).

## The one deliberate widening
R-F5-1 crosses R-F4-1's "rows are one line". Bounded by: only where a list declares `detail`,
only the three lists in R-F5-2, each line still cut and tooltipped, one height per list.

## Stop conditions
- Baseline not `ALL GREEN`, or `lua5.1`/`luac5.1` can't be installed → stop.
- The detail line can't be added without changing a one-line list's layout or a 0.3.1 list check → stop.
- Fitting two-line rows needs a window resized or a footer moved → stop.
- A list would show fewer than three rows at its declared height → stop.
- Loading fonts at start needs anything but `SetFont` on DT's own hidden string → stop.
- A guard removal turns nothing red: strengthen the test (test files only); if that needs addon
  code → stop.

## UAT: acceptance checks
`docs/UAT_dt_fixes5.md`, written with this brief: 7 `[G]`, 6 `[H]`.

## Reporting
`docs/COWORK_REPORT_dt_fixes5.md`: branch, old and new heads; baseline and final counts per
suite; each of the three lists' row height and visible row count per skin under the harness; the
harness `/dt debug fit` line per skin, and whether the event row is cut; which fonts are set at
load, per skin; guard proofs (removal → the check that went red); every player-facing line added;
zip name, size, sha256; anything in this brief that turned out wrong; questions for Tim. Say
plainly that the skin fix is unproven until H1 is walked. Never write a `_results.md` file.
