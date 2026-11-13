<!-- walked=2026-11-13 commit=244eb34 (claude/sleepy-knuth-z4fo3c; installed dist/DeadTired-0.3.1.zip, sha256 2fb64504930a50768ad97723a502c77998f09dd860bb8dbaeafa2f119ad32aac, downloaded from that commit, installed over 0.3.0 and diffed identical to the zip; libraries passed SHA256SUMS on the PC) host=lucasgoonpc (Windows, WoW Forever, interface 16001) dirty=n/a: walked the installed zip, not a checkout by=Tim (Stromham) closer=Claude session. No stamp convention exists in this repo; these fields are the ones that apply. -->
# Results: DEAD TIRED fix round 4 (dt_fixes4, 0.3.1), walked 13 Nov 2026

Walked by **Tim** on Stromham Hamson (Realm 2), 12:00-12:45. Against
`docs/COWORK_REPORT_dt_fixes4.md` on `claude/sleepy-knuth-z4fo3c` at `244eb34`; walk-sheet
`docs/UAT_dt_fixes4.md`. The closing session checked the `[G]` evidence it could and recorded the
`[H]` answers; it answered none of them. Evidence: Tim's screenshots (22 taken, all read by the
closer), his marks (WizardryLedger, as shown in the chat frame and the mark box), the
`DeadTired.lua` saved data, `!BugGrabber.lua`. Backup taken before the install:
`probe_backups\2026-11-12_0.3.0-before-0.3.1`.

**Outcome:** all 9 `[H]` walked. 8 pass; **H1 is partial** (switching to the gothic skin doesn't
repaint a window that is already open). Two defects and one remark go to the next round. The
`[G]` checks were **not re-run by the closer** (no `lua5.1` in the closing session): they rest on
the build's report, apart from what is marked "closer" below.

## [G] checks

| Check | Evidence | Result |
|---|---|---|
| G1 Baseline, final run, zip, version | Report: baseline 25 suites, 1136 checks; final 26 suites, 1319 checks, ALL GREEN. Closer: `dist/DeadTired-0.3.1.zip` at `244eb34` unzipped and `diff -r` against `DeadTired/` (tests excluded): clean; the copy on Tim's PC hashed identical and its libraries passed `SHA256SUMS`; `.toc` reads `0.3.1`, `DT.VERSION = "0.3.1"` | from the report (suites); pass (zip, version: closer) |
| G2 `DT.fitLine` | Report: `test_ui` 92 checks; a strengthened check on the UTF-8 cut positions. In game: `Excavation Site: Wetla...`, `Stromham Hams...` | from the report |
| G3 Lists | Report: column widths under the harness for all six lists. In game: `12 Nov`, `10 Nov` and `9 Nov` each on one line, rows one height | from the report |
| G4 Cut row's tooltip | Report: `test_ui`. In game: the tooltip on a cut graveyard row reads `Excavation Site: Wetlands` | from the report |
| G5 Footers | Report: `test_ui`, `test_played`. In game: the slowest board's footer on two lines inside the window | from the report |
| G6 `test_textfit.lua` | Report: 8 checks, the fixture and the numeric footer red. Closer: `grep -n CreateFontString DeadTired/*.lua` at `244eb34` shows `UI.lua` only | from the report; pass (grep: closer) |
| G7 `/dt debug fit` in the harness | Report: `fit: 1407 checked, 0 over, 3 rows cut, measure failures 0`; a planted label reported; skin unchanged | from the report |
| G8 Tooltips | Report: `test_played`, `test_crypt`. Closer read the diff: the `DT.realmLabel` line is gone from both tips | from the report |
| G9 Nudge | Report: `test_recruit` 104. Closer read the diff: `rearm()` only when `PLAYER_ENTERING_WORLD`'s second argument is `true` | from the report |
| G10 Switches, the hint | Report: gank 82, played 86, stash 101, events 40, logs 140. Changed after the brief by Tim's ruling of 12 Nov: the sharing toggle withdraws even while Played is off; the report's check and guard say so | from the report |
| G11 Skin, guards | Report: `test_skins` 29, `test_migrate` 63; 109 guards, each removal a named check red, restored. Tim's saved data: `migrated.skin031 = true` | from the report |

To confirm the "from the report" rows: `sh DeadTired/tests/run_all.sh` at `244eb34` on a machine
with `lua5.1`.

## [H] checks (Tim's words)

Marks are quoted as Tim typed them; a mark prefixed `good:` or `bad:` was made with that button.
A mark ending or starting `...` was only partly visible in the mark box.

| Check | Tim said | Evidence | Result |
|---|---|---|---|
| **H1** Install over 0.3.0, log in: welcome; BugSack quiet; plain lettering without choosing it; `/dt skin deadtired` brings the gothic titles back, still there after a `/reload` | marks *"good: new skin applied"*, *"bad: switching to deadtired doesn't bring the gothic font back."*; then: *"confirmed for you on the skin switch - it comes it once you load a new window but not on first selection in the settings pane."* | 12:01:40 the Skin card reads `clean`, plain titles. 12:02:08 it reads `deadtired`, the open settings window still plain. 12:03:28 a newly opened `Rest in Pieces` has the gothic title. 12:05:37, after `/dt debug fit`, the open settings window is gothic. After the 12:06 `/reload` the settings titles are gothic. Welcome line at 12:06:21. `!BugGrabber.lua` holds no Dead Tired error | **partial**: the move and the reload pass; the switch doesn't repaint an open window (defect 1) |
| **H2** Graveyard and Grudges: dates on one line, rows one height; a long zone ends in `…`, tooltip shows it in full | marks *"good: rip dates on one line"*, *"good: same for grudges - one line dates"* | 12:03:28 and 12:03:47: every date on one line, rows one height, `Excavation Site: Wetla...`. 12:16:35: the tooltip on that row reads `Stromham Hamson`, `2026-11-10 21:19:56`, `Excavation Site: Wetlands` | **pass** |
| **H3** Glacial Progress: footer inside the window; `h played` on one line; tooltip the name only. Graveyard tooltip: name and date, no realm key | *"confirmed slowest stayed inside the window."*; mark *"mark: 3 tooltip shots taken"* | 12:04:25: footer on two lines inside the window; `108.6 h played` on one line; tooltip `Stromham Hamson` twice (the name cell is cut to `Stromham Hams...`, so the full text is added under the name). 12:04:29 graveyard tooltip: `Echo Nightclaw`, `2026-11-12 19:09:04`, no realm key | **pass**, with defect 2 |
| **H4** Dungeon with the combat log off: the prompt's words inside its box; one click switches the log on | marks *"mark: combat log off"*, *"good: log prompt appeared and turned on logs when clicked"* | 12:43:05 `Combat logging disabled.` 12:45:02, Scarlet Monastery: `Log this one?` / `Combat log is off. Warcraft Logs needs it on.` on two lines inside the box, `Log it` and `Not now` below. 12:44:04 `Combat being logged to Logs\WoWCombatLog`, then *"Logging. Try not to die on the record."* | **pass** |
| **H5** `/dt debug fit` after opening the windows: last line `0 over` and `measure failures 0` | marks *"mark: running dt debug fit"* (twice) | 12:05:34 `fit: 1485 checked, 0 over, 24 rows cut, measure failures 0`. Open at the time: settings, the graveyard, Grudges, Glacial Progress. Who, Who has it and Events were not seen open (the command builds them itself) | **pass** (by his shot; no separate verdict given) |
| **H6** `/dt recruit`, then `/reload` within the 15 minutes: the nudge still comes, once, 15 minutes after the post | marks *"mark: CD continued waiting for nudge"*, *"good: found the 12:20 nudge"*; *"shots done for H6"* | 12:05:49 *"Posted line 5 of 5 to General."*; `/reload` at 12:06:20; the client loaded once more at about 12:08:50 (see the note below); the bar counts down through a zone change (`Recruit 4:15` at 12:16:35 in Ashenvale); 12:20:47 *"The crypt door creaks open: you can recruit again (/dt recruit)."*, once in the scrollback | **pass** |
| **H7** `/dt slowest share off`, then `/dt played`: the hint | marks *"mark: sharing off dt played"*, *"mark: turned back on"* | 12:06:47 *"not sharing your /played. Your entry is being withdrawn from guildies' boards."*; 12:07:02 *"Sharing's off. /dt slowest share on"*; 12:07:22 *"sharing your /played. Type /dt played to put yourself on the board."* | **pass** (by his marks; no separate verdict given) |
| **H8** Settings: Gank diary, Glacial Progress, Stash, Events and Logs each have an `On` card, all on; Gank off: `/dt gank` answers `gank.enabled = off`; on again, `/dt ganks` intact; no overlap or cut-off | marks *"...g whilst switched off"*, *"good: event and logs On cards"*, *"...anks survived on and off"*; *"ok couple more shots covered those"* | 12:08:32: `On` cards under Gank diary (unticked, switched off for the check), Glacial Progress and Stash (ticked); 12:08:18 `gank.enabled = off`. 12:39:30: `On` cards under Events and Logs, ticked. 12:39:51: `Grudges` open with its four entries. No overlap in any settings shot | **pass** |
| **H9** Is the plain lettering easier to read, would you keep it as everyone's default? Anything you had to squint at? | *"Yes the new font is much cleaner to read"*; *"H9 - no nothing spotted so far but we can remain vigilant for these XD"* | | **answered**: easier to read; nothing to squint at so far. Keeping it as the default was not answered in so many words |

## Defects and requests (for the next build round)
1. **Switching skin doesn't repaint a window that is already open.** With settings open,
   `/dt skin deadtired` (or the Skin card) left its titles in the plain lettering; windows opened
   afterwards were gothic, and `/dt debug fit` (which repaints everything) put the open one right.
   Tim: *"it comes it once you load a new window but not on first selection in the settings pane."*
   Cause not established. The closer's guess, unproven: Morpheus is no longer the default, so it
   is first asked for at the switch and the client hasn't loaded it when the text is re-fonted.
2. **Glacial Progress cuts the name** (`Stromham Hams...`) although the row has room to spare: the
   name is the flexible column and gets only what four measured columns leave. Its tooltip then
   shows the name twice (the module's name line, then the cut cell's full text). Found by the
   closer in the 12:04:25 shot; Tim did not remark on it.
3. **The cut mark is drawn as three dots (`...`) in game**, where the brief and the sheet say `…`.
   Readable either way; noted so the sheet and the font agree.

## In the brief, the walk-sheet or the report
- **The sheet's H1 can't pass as one line**: it joins the one-off move, the switch back and the
  reload. They came out pass, fail, pass.
- **H5 asks for seven windows opened first**; four were. The command builds the rest itself, so
  the sheet asks for more than the check needs.
- **H8's "all on"** was walked with Gank already switched off for the second half of the check.
- **The report's questions 3 to 7** (the On cards' wording, Events' 190 px name column, the
  AddOns-page title, template button labels, the log prompt left up if Logs is switched off in
  combat) were not put to Tim in this walk. On Events' column: `/dt debug fit` reported nothing
  over; whether that row was among the 24 cut was not looked at.
- **One more load before the nudge, kind not established.** The saved file was written at 12:08
  and the 12:16 shot shows a session seven minutes old, so the client loaded again at about
  12:08:50, after the 12:06:20 `/reload` and before the 12:20:47 nudge. If that was a second
  `/reload`, the nudge is as ruled. If it was a logout and login, the nudge would contradict
  R-F4-6's "a fresh login never does". Not put to Tim before this log was written.
- **The brief said 75 guards for 0.3.0; it was 74** (the report's correction).
- **Left in Tim's settings by the walk:** the saved skin was `deadtired` at the 12:08 save (the
  12:16 shot shows plain titles again); Gank was off at that save and on again by 12:39; play-time
  sharing is on, and the board entry was empty at the 12:08 save until the next `/dt played`.

## Not answered
None left unanswered. H5 and H7 rest on Tim's shots and marks without a separate verdict. H1 is
partial. H9's "would you keep it as everyone's default" was not answered directly.
