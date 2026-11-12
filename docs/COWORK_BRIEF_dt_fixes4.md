# Cowork brief: DEAD TIRED fix round 4 (text that fits; clean-font skin; five switches; 0.3.1)

You are in `LUCA5G00N/dead-tired-addon`, building in a cloud session; Tim walks the result in game.
Read first, in order:
1. `CLAUDE.md` on `main`.
2. This brief and its walk-sheet, `docs/UAT_dt_fixes4.md`.
3. `docs/UAT_dt_port2_results.md` (*Tim's rulings during the walk*, *Defects and requests* 1-5).
4. `DeadTired/UI.lua`, `Skins.lua`, `Core.lua` (the module core: `optional`, `DT.enabled`,
   `DT.apply`), then every file that calls `CreateFontString`, `DT.list` or `DT.viewport`.
5. `docs/FEATURES.md` § *General requirements* and § *Versions and releases*.

**Draft-status: ratified by Tim 2026-11-12** (14:26: R-F4-1 to R-F4-10 accepted as proposed).
Written against `main` at `4637b47` (0.3.0). File and line references below were read from that
commit; if `main` has moved, re-read them before Task 1. The drafting session had no `lua5.1`, so
the baseline counts are the walk log's (25 suites, 1136 checks at `ef2a768`), not re-run.

## Origin
The Port 2 walk (12 Nov) left five defects for a fix round: dates and zones that wrap, a footer and
a dialog whose text overflows, tooltips showing the raw realm key, and a nudge lost on `/reload`.
Tim's design session the same day (project note `claude/14_addon_design_2026-11-12.md`, and his
decisions of 13:01-13:46 in `01_restart_addon.md`) added: fix the text overflow once, properly; a
clean-font skin as the default; a hint when `/dt played` is typed with sharing off; master switches
on the five Port 2 modules; and the module template written into `CLAUDE.md`.

## Precondition
- `main` is at `4637b47` or later, carries this brief and its walk-sheet, and
  `sh DeadTired/tests/run_all.sh` prints `ALL GREEN`.

## Rulings in force (cited, not restated)
`CLAUDE.md`: *The guild's rules* (quiet by default; opt-in for anything personal), *Ruled
exceptions* (the recruit nudge is the only one this round touches), *Code rules* (no Blizzard
global or hook; `reference/` read-only; no new library). `UAT_dt_port2_results.md`, *Tim's rulings
during the walk*: tooltips show the character name only on the slowest board and in the graveyard;
no player-facing line from 0.3.0 is cut in this round. R-P5 (Port 1): names without realm, realm
only on a collision. R-P2-2: Escape closes viewports.

## The rulings (ratified 2026-11-12)
- **R-F4-1 Text fit.** Rows are one line, cut with "…", the full text in the row's tooltip.
  Footers, descriptions, empty-state lines, dialogs and toasts are bounded both sides and wrapped,
  their box sized from the measured height. Date, level, count and version columns are measured
  from their widest value at the current font; each list has exactly one flexible column. No
  shrink-to-fit. Modules never create raw text.
- **R-F4-2 DT cuts the text itself.** The round relies on none of the client's truncation calls
  (`IsTruncated`, `SetMaxLines`). DT measures with `GetStringWidth` (already used by `Bar.lua` and
  walked) on a hidden string and trims to fit, so the rule is tested offline.
- **R-F4-3 The clean skin.** In 0.3.0 the Dead Tired skin differs from Forever in font only by its
  titles (Morpheus 16); body text is already Friz Quadrata. A third skin, id `clean`, shown as
  **Dead Tired**: the Dead Tired colours and edges with the game's own lettering (Friz Quadrata)
  throughout. The gothic skin keeps id `deadtired` and is shown as **Dead Tired Gothic**. `clean`
  is the default. Typed: `/dt skin clean|deadtired|forever`.
- **R-F4-4 Who is switched.** Once per account, anyone on `deadtired` (or with no saved choice)
  is moved to `clean`; anyone who chose `forever` is left alone. Silent: no chat line (the release
  notes say it). `/dt skin deadtired` afterwards sticks.
- **R-F4-5 Master switches** on Gank, Played, Stash, Events, Logs: the framework's existing `On`
  card (`optional = true`), default on. Off means the module registers no events, ignores its
  inbound messages, sends nothing, prints nothing unasked, and a typed verb of its own answers
  with the line Who already uses, `<id>.enabled = off`, and does nothing else. Off is **not** a
  withdrawal: what was already shared stays on guildies' boards until its own expiry; only the
  sharing toggle withdraws.
- **R-F4-6 The nudge and `/reload`.** A `/reload` while a post's cooldown is still running re-arms
  the nudge for the time left. A fresh login never does. If the cooldown ended during the reload,
  no late line. `CLAUDE.md`'s nudge line gains "(a `/reload` keeps it)".
- **R-F4-7 The hint.** `/dt played` with sharing off prints, after asking the client as now:
  `Sharing's off. /dt slowest share on`
- **R-F4-8 The skin card's description:** `How every Dead Tired window and the bar look: Dead
  Tired (the guild's colours, plain lettering), Dead Tired Gothic (the same, with gothic titles)
  or Forever (the game's stone and metal).`
- **R-F4-9 Version.** 0.3.1, though `FEATURES.md` says PATCH is fixes only and this round adds a
  skin and five switches: a one-off, noted in the release notes.
- **R-F4-10 Other tooltips.** The Who list's and the Grudges board's tooltips keep their realm
  line (Who by R-P5; Grudges until the gank rework).

## Deliverable
On a branch from `main` (the session's own branch is fine), DeadTired **0.3.1**: every piece of
text DT draws is created by one helper in `UI.lua` under R-F4-1; the walk's defects 1-5 are fixed;
the `clean` skin exists, is the default, and existing accounts are moved to it once; Gank, Played,
Stash, Events and Logs each have an `On` switch; `/dt played` hints when sharing is off;
`/dt debug fit` reports text that doesn't fit; `CLAUDE.md` carries the module template. Done when
`run_all.sh` prints `ALL GREEN` including a new static suite that goes red on any
`CreateFontString` outside `UI.lua`, every guard in Task 10 has been removed once and turned a
named check red, and `dist/DeadTired-0.3.1.zip` passes `diff -r`.

## Working rules
- New player-facing text: only the lines this brief gives (R-F4-7, R-F4-8, the two skin titles,
  `/dt debug fit`'s output). Anything else you need goes in the report as a question.
- Window sizes, titles, column order and every 0.3.0 line stay as they are.
- No new library, no hook, no Blizzard global (`test_taint.lua` stays green).
- Every game read through the guarded helpers; `/dt debug fit` saves nothing.

## Tasks
1. **Baseline.** `run_all.sh` on the branch point: `ALL GREEN`; record suites and checks.
2. **The text helper (`UI.lua`).** `DT.text(parent, kind, opts)` is the only caller of
   `CreateFontString` in `DeadTired/` (tests excluded). Kinds:
   - `line`: one line, a stated width, word wrap off where the client has the call; its text is set
     through `DT.fitLine(text, width, role)`, which returns the text unchanged when
     `DT.measure(text, role)` ≤ width, else the longest prefix (cut on a UTF-8 character boundary)
     that fits with `…` appended. `DT.measure` uses one hidden string per font role and
     `GetStringWidth`; a non-number or a width ≤ 0 for non-empty text counts in
     `DeadTiredDB.errors` under `ui:measure` and the text is treated as fitting.
   - `block`: bounded left and right, wrapped; `DT.textHeight` gives the height and the owner sizes
     from it.
   - `label`: one line, unbounded, allowed only where the parent is sized from the text (bar
     buttons). Any other use is a `/dt debug fit` fault.
   Every string is fonted through the skin (`DT.fontTo`) and re-fitted when the skin changes,
   except strings created with `fixedFont = true` (the log dialogs, which are not skinned).
   Each is recorded (window id, kind, box) for Task 5.
3. **Lists (`DT.list`).** Cells are `line`s. A column is `fixed = true` (width = the widest
   `DT.measure` over every row in the model, re-measured when rows or skin change), `width = n`
   (static), or `flex = true` (the rest of the list's width, taken from the viewport's declared
   width, never from a layout read that can be 0). Not exactly one `flex` column → `DT.list`
   raises. Rows are one fixed height. When any cell was cut, the row's tooltip shows, after the
   module's own lines, each cut cell's full text; a list with no `tip` gets a tooltip only for cut
   rows. Columns:

   | List | fixed | static | flex |
   |---|---|---|---|
   | Graveyard (`Crypt.lua`) | day, lvl | name 160 | zone |
   | Grudges (`Gank.lua`) | n, what, day | name 130, by 100 | last |
   | Glacial Progress (`Played.lua`) | n, rateText, lvlText, hoursText | | name |
   | Who (`Who.lua`) | v, when | | name |
   | Who has it (`Stash.lua`) | | holder 130 | items |
   | Events (`Events.lua`) | | name 190 | when |

   Any other `DT.list` caller (Prep, the settings view's lists): the same rule; list your column
   choices in the report.
4. **Footers, dialogs, toasts, titles.** `DT.viewport{ footer = "<text>" }` takes the text, not a
   pixel count: the viewport creates it as a `block` between the paddings and insets the body by
   its measured height. The six modules' hand-made `note` strings go. The viewport title is a
   `line` ending left of the close button. The toast's text is a `block` and the toast's height
   comes from it. In `Logs.lua` both dialogs' title and status are `block`s (`fixedFont`), the
   dialog's height comes from them and the buttons sit below; size once at creation, never while
   `InCombatLockdown()`. `Bar.lua` and `SettingsView.lua` create their text through `DT.text`
   (labels `line`, descriptions and hints `block`) with no change to their layout.
5. **`/dt debug fit`** (`Debug.lua`). Each module that owns a window declares `fit = function()`
   in its `DT.module` table, which builds its windows with its current data, hidden, printing
   nothing. The verb calls every `fit` under `pcall`, then for each skin in `DT.skins` (applied in
   memory, the saved choice restored afterwards and never written) checks every recorded string
   and prints one line per fault: `fit: <skin> <window> <kind> "<first 24 bytes>" <measured>/<box>`.
   Faults: a `block` taller than its box; a `label` wider than its parent; a `fixed` column narrower
   than its widest value; a `flex` column under 60; a `line` with no width. Last line always:
   `fit: <n> checked, <m> over, <k> rows cut, measure failures <f>`. Cut rows are counted, not faults.
6. **The static suite** `DeadTired/tests/test_textfit.lua`, added to `run_all.sh` beside
   `test_taint.lua`: red if `CreateFontString` is called anywhere in `DeadTired/*.lua` but `UI.lua`
   (from the `luac5.1` listing, as `taint_scan.lua` does, so comments and strings can't fool it),
   or if a `DT.viewport` call passes a number as `footer`. It includes a fixture with a raw call
   that must be caught.
7. **Tooltips (defect 4).** Remove the `DT.realmLabel` line from the tips in `Played.lua` and
   `Crypt.lua`. The graveyard keeps its date line. Gank's and Who's stay (R-F4-10).
8. **Nudge (R-F4-6), `Recruit.lua`.** In the `PLAYER_ENTERING_WORLD` handler, when the event's
   second argument is exactly `true` (a UI reload), call the existing `rearm()`. Nothing else
   changes. Amend the nudge line in `CLAUDE.md` as R-F4-6 says.
9. **Hint, switches, skin.**
   - `Played.lua`: R-F4-7's line when `/dt played` runs with `played.share` off; still nothing
     recorded for sharing and nothing sent.
   - `optional = true` on `gank`, `played`, `stash`, `events`, `logs`, with R-F4-5's behaviour:
     each `DT.on` handler and each timer callback of theirs returns at once when
     `DT.enabled(id)` is false; each of their verbs prints `<id>.enabled = off` and returns.
     Logs off shows no prompt and no login offer and never touches a client log.
   - `Skins.lua`: skin `clean` (title `Dead Tired`; `deadtired`'s colours, textures and spacing;
     no `fonts` table, so the base's apply); `deadtired`'s title becomes `Dead Tired Gothic`.
     `Settings.lua`: choices `clean`, `deadtired`, `forever`; default `clean`; verb usage and
     description per R-F4-3 and R-F4-8.
   - `Migrate.lua`: once per account (`DeadTiredDB.migrated.skin031 = true`), a saved skin of
     `deadtired` or none becomes `clean`; `forever` is left; nothing is printed.
10. **Guard proofs** (`tools/guard_proofs.lua`; remove once, a named check red, restore):
    `fitLine` cuts to the width; the UTF-8 boundary; the cut row's tooltip text; fixed columns
    measured from the widest value; exactly one flex column; the footer insets the body by its
    measured height; the static suite's `CreateFontString` rule and its numeric-footer rule;
    `/dt debug fit` restores and never saves the skin; the realm line absent from both tooltips;
    re-arm on reload; no re-arm on a first login; no re-arm once the cooldown has ended; the hint
    only when sharing is off; for each of the five modules: off ignores inbound, off sends
    nothing, off verbs do nothing else; the skin move runs once; `forever` left alone. Plus every
    guard 0.3.0 proved (75), still proved.
11. **Docs.** `CLAUDE.md`: add the section *What every module must do* with the fourteen points of
    the design note's *Module template*, worded as rules, with this sentence above them: "New
    modules meet all of these; an existing module is brought into line only where a brief says
    so." `docs/FEATURES.md`: the shell table's viewport row now says Escape closes it (R-P2-2);
    add *Ruled 12 Nov (for `dt_fixes4`)* listing R-F4-1 to R-F4-10 as ratified.
    `docs/RELEASE_0.3.0.md`: the graveyard line under *Fixed* becomes "The graveyard's dates are
    short (`10 Nov`), the full date in the tooltip. Some still wrapped: fixed in 0.3.1."
    New `docs/RELEASE_0.3.1.md` (draft, DT's voice, short, with the install steps and a line that
    the look has changed and how to get the gothic titles back).
12. **Version and zip.** `.toc` and `DT.VERSION` to `0.3.1`; `sh tools/package.sh` →
    `dist/DeadTired-0.3.1.zip`, `diff -r` clean. Leave the older zips in `dist/`.
13. **Report** `docs/COWORK_REPORT_dt_fixes4.md`.

## Out of scope
Profiles and the built-in sets (Restless, Wide Awake, Lights Out); the sharing panel and the gank
sharing toggle (card 4 R2 stands); the gank rework (one-press add, typed add, own lists, expiry);
grouping the Who list by version; the waypointer; talent or legacy point reminders and the
trainer list; gambling; cutting or rewording any 0.3.0 line; skinning the log dialogs; resizable
windows; a font setting separate from the skin; 48-byte holder names; accents in names; publishing
the release (Tim's).

## The one deliberate widening
R-F4-2 departs from the design note's "check the client has the truncation calls": the round
relies on none of them. Bounded by: only `GetStringWidth`, `SetWidth`, `SetWordWrap` (guarded) and
`GetStringHeight` are used on text, all already in 0.3.0.

## Stop conditions
- Baseline not `ALL GREEN`, or `lua5.1`/`luac5.1` can't be installed → stop.
- A text site can't go through `DT.text` without changing a window's size, a column's order or a
  0.3.0 line → stop.
- Sizing a log dialog from its text needs a secure button moved or re-anchored after creation, or
  anything done in combat → stop.
- A master switch can't silence a module without changing a framework contract other than adding
  the `fit` field and the `footer` text form → stop.
- The static suite can't tell a call from a comment or a string → stop.
- The skin move would have to write anything but `core.skin` and its own flag → stop.
- A guard removal turns nothing red: strengthen the test (test files only, as `CLAUDE.md`
  allows); if that needs addon code → stop.

## UAT: acceptance checks
`docs/UAT_dt_fixes4.md`, written with this brief: 11 `[G]`, 9 `[H]`.

## Reporting
`docs/COWORK_REPORT_dt_fixes4.md`: branch, old and new heads; baseline and final counts per suite;
every text site in 0.3.0 (file and line) and the kind it became; each list's columns with their
measured widths under the test harness; `DT.fitLine`'s checks; `/dt debug fit` output from the
harness for each skin; guard proofs (removal → the check that went red); each master switch's
checks; the skin move on a fixture (saved `deadtired`, saved `forever`, none); every doc line
changed; every player-facing line added; zip name, size and file list; anything in this brief
that turned out wrong, and questions for Tim. Never write a `_results.md` file.
