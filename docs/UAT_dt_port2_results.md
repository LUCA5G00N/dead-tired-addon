<!-- walked=2026-11-12 commit=ef2a768 (claude/sharp-gauss-84wft6; installed dist/DeadTired-0.3.0.zip, sha256 8b30956b602366be815bdfe3c40f125bd51d5a0ecda3ff1a64883bd342a6bca8, matched the branch's zip byte for byte; libraries passed SHA256SUMS on the PC) host=lucasgoonpc (Windows, WoW Forever, interface 16001) dirty=n/a: walked the installed zip, not a checkout by=Tim (Stromham) with Lilbit High closer=Claude session. No stamp convention exists in this repo; these fields are the ones that apply. -->
# Results: DEAD TIRED Port 2 (dt_port2, 0.3.0), walked 12 Nov 2026

Walked by **Tim** on Stromham Hamson (Realm 2), with **Lilbit High** (Realm 4) on 0.3.0 for the
shared checks. Against `docs/COWORK_REPORT_dt_port2.md` on `claude/sharp-gauss-84wft6` at `ef2a768`;
walk-sheet `docs/UAT_dt_port2.md`. The closing session verified the `[G]` checks and recorded the
`[H]` answers; it answered none of them. Evidence: Tim's screenshots (40 taken, 39 read by the closer) and his marks
(WizardryLedger, paired by the `shot` field), the `DeadTired.lua` saved data, three screenshots
from Lilbit. Wizardry stayed on throughout.

**Outcome:** all 10 `[H]` and the 3 carried Port 1 checks were walked. 11 pass; **H5 is partial**
(the date still wraps on some rows); **H6 is a pass "for now" by Tim's ruling**, walked mirrored
(the guildie logged, Tim's board showed it), with the cross-realm question still open. Defects and
requests below go to the next round.

## [G] checks (verified by the closing session)

| Check | Evidence | Result |
|---|---|---|
| G1 Baseline, final run, zip | Closer re-ran `run_all.sh` at `ef2a768` on 12 Nov: 25 suites, 1136 checks, ALL GREEN, libs unmodified. `dist/DeadTired-0.3.0.zip` unzipped and `diff -r` against `DeadTired/` (tests excluded): clean. The zip on Tim's PC hashed identical. Baseline counts (19 suites, 690) are the report's, not re-run | pass |
| G2 Port 1 fixes | In the closer's re-run: recruit 94, bar 78, crypt 98, ui 50, taint 34 | pass |
| G3 Taint scan | In the re-run (taint 34). Closer grepped the addon code: the only `UISpecialFrames` touch is `table.insert(UISpecialFrames, name)` in `UI.lua`; no `hooksecurefunc` call (one mention, in a comment); `LoggingCombat` only read, with no argument, in `Logs.lua` | pass |
| G4 Gank, Played, Stash, Events, Logs | In the re-run: gank 71, played 62, stash 86, events 31, eventslist 4, logs 123 | pass |
| G5 Played only after `/dt played` | In the re-run (played 62). Also seen in game: H7 | pass |
| G6 Migration for cards 4 and 6 | In the re-run (migrate 53). Tim's saved data: `migrated.port2 = true`, `port2Unmatched = 0`, `legacy` still present | pass |
| G7 Guards | Report: 75 removals, each a named check red, restored. Not re-run by the closer | from the report |

## [H] checks (Tim's words)

Marks are quoted as Tim typed them; a mark prefixed `good:` was made with the Good button.

| Check | Tim said | Evidence | Result |
|---|---|---|---|
| **H1** Log in: welcome; BugSack quiet; `/run print("risen")` | *"h1, H7 and H9 are all good they worked."* | 09:12:48 *"Rest in Pieces, Stromham Hamson. The crypt's open. /dt for the rest."*; 09:13:18 `risen`; BugSack count 0 on the bar, the one entry opened is dated 11 Nov 14:34 | **pass** |
| **H2** Escape closes Who, settings and the graveyard; marks bar stays | mark *"good: confirmed esc closed the who window"*; mark *"after worked (I escaped fishing first press then the windows closed second press"*; *"confirmed the rip window acts the same way which is good."* | Before/after shots 09:36:08 and 09:36:29 (Who and settings open, then gone); the marks bar on screen in every shot | **pass** |
| **H3** Bar list shows names; a hand cursor while dragging | marks *"Full addon list selected."*, *"open hand for grips works"* | List reads Dead Tired, AtlasLoot, Session, Who, Recruit, BugSack, Bagnon... while the bar shows live text (`Recruit 14:50`, `30/68`) | **pass** (by his marks; no separate verdict given) |
| **H4** Post, nudge off and on, nudge once 15 min after | marks *"recruit started"*, *"nudge off"*, *"nudge on"*, *"recruit reminder fired"* | 09:16:43 *"Posted line 1 of 5 to General."*; 09:17:10 off; 09:17:35 on; 09:31:43 *"The crypt door creaks open: you can recruit again (/dt recruit)."*: 15:00 after the post, once. No `/reload` in between | **pass** (by his marks; no separate verdict given) |
| **H5** Graveyard dates on one line; full date in the tooltip | on the wrap: *"I think the two lines are coming from the instance rows overflowing as well - would be good to standardise this to one line."*; on the tooltip: marks *"tooltip works for me"*, *"rip screenshot for tooltip - it works"* | `11 Nov` and `9 Nov` on one line; **`12 Nov` and `10 Nov` wrap onto two** in every shot, on rows whose zone fits on one line too. Tooltip at 09:42:53: `Echo Nightclaw` / `CAMWOWEU4Realm2PvP` / `2026-11-12 00:12:33` | **partial**: tooltip met; dates on one line not met for some rows (defect 1) |
| **H6** Gank: `/dt gank` on an Alliance player; board shows them; a guildie on 0.3.0 sees it | *"we're going to chalk up the gank as a pass for now - I'm struggling to find someone right now XD."* | Walked mirrored: Lilbit's screenshot *"That's one of ours. Put the pen down."* then *"Noted: Junesong Ikkin (Shaman 25), Ashenvale. The crypt remembers."*; Tim's `Grudges` board at 11:02:29 shows `Junesong Ikkin (Shaman 25) x1 by 1 guildie last Ashenvale 12 Nov`; saved log `by` Lilbit High, 11:02:09. Tim's own `/dt gank` was not done | **pass for now** (Tim's ruling); not walked as written |
| **H7** `/dt slowest share on`, `/dt played`; board shows you; plain `/played` changes nothing | *"h1, H7 and H9 are all good they worked."*; mark *"writing on slowest flows over the window"* | 09:20:49 *"sharing your /played. Type /dt played to put yourself on the board."*; `/dt played` at 09:21:22 saved the board entry (93.7 h, level 34); plain `/played` at 09:21:58 left its `at` unchanged; `Glacial Progress` shows `1. Stromham Hamson 2.8 h/level level 34 93.7 h played` and the award line printed | **pass**, with defect 2 |
| **H8** Stash: a guildie asks for an unbound item you carry; a bound item never shows | *"H8 the search was for hearthstone"*; *"H8 - pass"* | Lilbit's screenshots: `Who has it` reads `Stromham Hamson  Iron Grenade x54`; the Hearthstone search reads *"Nobody's got it. Or nobody's sharing."* | **pass** |
| **H9** `/dt events` lists upcoming; `/dt events remind on` | *"h1, H7 and H9 are all good they worked."* | `Events`: `Stranglethorn Fishing Extravaganza  Sunday 14:00 server time, in 3d 3h 39m.`; 09:22:39 *"reminders on. You'll hear 30 minutes before, and at the start."* The first reminder is due Sunday 15 Nov, 13:30 server time; not yet observed | **pass** |
| **H10** Enter a dungeon with the combat log off: one prompt; clicking switches it on | marks *"combat log off"*, *"good: log prompt appeared"*, *"words overlapped the box though"*, *"good: pressing once showed only one prompt there"* | 11:10:38 `Combat logging disabled.`; one `Log this one?` prompt on entering Scarlet Monastery; after the click `Combat being logged to Logs/WoWCombatLog` and *"Logging. Try not to die on the record."* | **pass**, with defect 3 |
| **P1-H2** `/dt who` with a guildie | *"P1-H2: Pass with the note I made"*; the note: mark *"dt who shot - maybe segregate out earlier versions so it's cleaner?"* | `Stromham Hamson (you)  0.3.0  you` first; `Lilbit High  0.3.0  this session`; no realm on any name | **pass**, with request 7 |
| **P1-H5** Settings: no overlap or cut-off, first setting readable | mark *"P1-H5 - confirmed ok"* | Settings shots 09:23:18 and 09:27:08 | **pass** |
| **P1-H6** The bedtime nag fires | marks *"bedtime set"*, *"bedtime reminder fired"* | 09:24:03 *"bedtime set for 09:25. You'll be told."*; 09:25:46 *"It's 09:25. Even the dead sleep."* | **pass** (by his marks; no separate verdict given) |

## Tim's rulings during the walk
- **The build's own new lines** (window titles, setting cards, module titles, bar labels; report,
  "New, not in the brief"): *"we're not cutting anything on this pass (I want to see what the others
  think as well."* Kept for now, pending the guild's views. `Who has it` and `Grudges` were seen
  on screen after that ruling; `Gank diary` (a settings heading) was not captured in any shot.
- **Tooltips:** *"slowest realm tooltip - we can switch to the character name only not full with
  realm."* Asked whether the graveyard tooltip gets the same change: *"yes same change"*.

## Defects and requests (for the next build round)
1. **Date column wraps on wider dates.** `12 Nov` and `10 Nov` take two lines where `11 Nov` and
   `9 Nov` take one (the column is 46 wide), in the graveyard and on the Grudges board. The
   graveyard's zone column (150) separately wraps `Excavation Site: Wetlands`. Tim: *"would be good
   to standardise this to one line."*
2. **Slowest board footer overflows the window** (Tim: *"writing on slowest flows over the
   window"*): the line ending "Type /dt played to update yours." runs past the right edge. In the
   same window `93.7 h played` wraps onto two lines.
3. **Log prompt text overflows its box** (Tim: *"words overlapped the box though"*): "Combat log is
   off. Warcraft Logs needs it on." is wider than the dialog.
4. **Tooltips show the raw realm key** (`CAMWOWEU4Realm2PvP`) on the slowest board and in the
   graveyard. Ruled: character name only (the graveyard keeps its date line).
5. **A `/reload` drops a pending nudge.** Already ruled (11 Nov): a reload should re-arm it.
6. **Gank is cumbersome** (Tim): *"Adding someone to the list from a target should be a single
   button press. but allowing a manually typed add of the players name as well should be allowed
   (for when the target has disappeared)"*. A typed name with no class, level or realm: *"It is ok
   but can we also then fill it in once a player matching that name has been targeted by someone
   running our addon?"* Open for the brief: where the button lives; and the fill-in reads a target
   outside `/dt gank`, which the standing ruling (card 4, `dt_pvp` R1) does not cover, so it needs
   its own ruling.
7. **Who list** (Tim, a suggestion): *"maybe segregate out earlier versions so it's cleaner?"*

## In the brief, the walk-sheet or the report
- **H6 needs an Alliance player to hand**, which the sheet doesn't plan for; none could be found, so
  it was walked from the guildie's side. The sheet could allow either side to log.
- **The cross-realm enemy question is still open** (report question 5). Junesong Ikkin is filed
  under Lilbit's realm (Realm 4); nothing shows whether the client gave a `-Realm` suffix or the
  "no suffix means ours" fallback applied. Lilbit's `/dt debug names` was run with no target
  (every target line `nil`). The post to the testers didn't ask for it with the enemy targeted.
- **The hand cursor exists on Forever** (report question 6): Tim's mark *"open hand for grips
  works"*.
- **H2 doesn't say Escape first cancels a cast**: Tim's first press stopped fishing, the second
  closed the windows. Expected, but worth a line on the sheet.
- **H9 can't observe a reminder** unless an event is within the walk; the sheet only asks for the
  due time to be noted.
- **`FEATURES.md` still says viewports are not closed by Escape** (report question 8); H2 confirms
  the new behaviour, so the doc is now wrong.
- The report's questions 3, 4 and 7 (a hint when sharing is off, module switches, 48-byte holder
  names) were not put to Tim in this walk.

## Not answered
None left unanswered. Three results rest on Tim's marks alone (H3, H4, P1-H6); H5 is partial; H6
is a pass "for now" on a mirrored walk, with Tim's own `/dt gank`, the guildie seeing it, and the
cross-realm suffix not walked.
