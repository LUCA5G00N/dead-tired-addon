<!-- walked=2026-11-11 commit=0b71fff (claude/serene-meitner-dvzd67; installed dist/DeadTired-0.2.0.zip, sha256 659acce6f300d5f20bcf7659863ce88fd40990b9a500e6a3dbefc1a655ba2272, matched the branch's zip byte for byte; libraries passed SHA256SUMS on the PC) host=lucasgoonpc (Windows, WoW Forever 1.60.1, interface 16001) dirty=n/a: walked the installed zip, not a checkout by=Tim (Stromham) with EchoOfMany (Echo Nightclaw) closer=Claude session. No stamp convention exists in this repo; these fields are the ones that apply. -->
# Results: DEAD TIRED Port 1 (dt_port1, 0.2.0), walked 11 Nov 2026

Walked by **Tim** on Stromham Hamson (Realm 2), with **Echo Nightclaw** on 0.2.0 for the shared
checks. Against `docs/COWORK_REPORT_dt_port1.md` on `claude/serene-meitner-dvzd67`; walk-sheet
`docs/UAT_dt_port1.md`. The closing session verified the `[G]` checks and recorded the `[H]`
answers; it answered none of them. Evidence: Tim's screenshots and marks (WizardryLedger), the
`DeadTired.lua` saved data, Echo's screenshot.

**Outcome:** 6 of 8 `[H]` pass (H1, H3, H4, H6, H7, H8); **2 deferred by Tim** (H2, H5) to the next
round's walk for evidence. Defects below go to the next build round.

## [G] checks (verified by the closing session)

| Check | Evidence | Result |
|---|---|---|
| G1 Suites, zip | Closer re-ran `run_all.sh` on 11 Nov: 19 suites, 690 checks, ALL GREEN; libs unmodified. Zip on Tim's PC hashed identical to the branch's | pass |
| G2-G8 | In the closer's re-run (keys, ui, settingsview, bar, who, alts, crypt, recruit, recruitlines, prep, session, migrate). Closer read `Recruit.lua`: `post()` runs only from the typed verb or the button's `OnClick` (`clicking` flag); the only `SendChatMessage` path is there. No realm read from `UnitFullName` outside `Debug.lua` | pass |
| G9 Guards | Report: 44 removals, each a named check red, restored; one test strengthened (migration run-once). Not re-run by the closer | from the report |

## [H] checks (Tim's words)

| Check | Tim said | Evidence | Result |
|---|---|---|---|
| **H1** Alts once each, no short/full doubles; BugSack quiet | *"H1 - confirmed clean - it's a pass."* | 18:18:06 `main Stromham Hamson; alts (4): Gizzardthe Lizardwizard, Jobbi Thehamvil, Marvella Swineson, St Ham.`; saved `migrated.merged = 5`, `unmatched = 0` | **pass** |
| **H2** `/dt who` with a guildie | *"I'm deferring those last two for the next round of testing - think we covered it off but haven't got the evidence for it."* | Echo's screenshot (`Echo Nightclaw (you)` first; `Stromham Hamson` without realm) exists but Tim deferred the verdict | **not walked** (deferred) |
| **H3** Recruit button, cooldown, nudge, nudge replies | *"yes works and shows the cooldown itwas the nudge that failed."*; later *"just had the nudge work."* | Button counts down (`Recruit 10:39`); second click: *"Too soon. Next post in 13 min. Even necromancers pace themselves."*; 18:17 *"Nudge off. The crypt keeps its own counsel."* / *"Nudge on. The crypt will knock."*; 18:28 mark *"recruitment nudge failed."* (after the off/on at 18:17); 20:22:20 *"The crypt door creaks open: you can recruit again (/dt recruit)."*, then 20:22:23 *"Posted line 4 of 5 to General."* | **pass**, with defect 1 |
| **H4** Bar list: unticked default, tick, drag, order kept after /reload, Session | *"pass - the grips worked and saved their order - hand could change as gripping as an optional addition"* | Settings shots 18:19-18:23; mark *"post reload check for order"*; mark *"the labels in the addon setting list are a bit scuffed - bug grabber showing 0 and the custom ones for DT showing timers"* | **pass**, with defects 2-3 |
| **H5** Settings: no overlap or cut-off; first setting readable | as H2 | | **not walked** (deferred) |
| **H6** Graveyard, bedtime replies, shared death notice | *"H6 - pass checked the graveyard and bedtime messages fired (but didn't confirm that it actually prompted at bedtime)"* | `Rest in Pieces` viewport with search; *"bedtime set for 23:59. You'll be told."*, *"bedtime off. Stay up forever; you're dead anyway."*; 18:49:06 *"Echo Nightclaw died at level 34 in Arathi Highlands. Again."* | **pass** (the nag at bedtime itself not observed) |
| **H7** Officer sets the raid list; a guildie sees it and checks | *"H7 - pass and confirmed with echo he saw the list."* | 18:34:07 *"prep.list: Iron Grenade x10 (1 on the list)"* | **pass** |
| **H8** `/run print("risen")` with DT loaded | *"H8 - I ran that and it returned "risen""* | 20:19:26 `risen`. The Wizardry marks bar was on screen (WizardryLedger loaded) | **pass** |

## Defects and requests (for the next build round)
1. **Nudge off then on drops the pending nudge** (18:17 toggle → no nudge at 18:28; normal at 20:22).
2. **Bar list labels show live text, not the addon's name** (BugSack as `0`, Recruit as `Recruit 8:23`).
3. Tim: *"hand could change as gripping as an optional addition"*: a grab-hand cursor while dragging a row.
4. **Graveyard date column wraps** (`2026-11-` / `10`), doubling row height.
5. **Escape closes panes by default** (Tim, 11 Nov): Who, settings and the graveyard should close on
   Escape; staying open through Escape is the marks bar's exception, not the rule.
6. Carried from the framework walk, still open: DT info on the bar beyond Session (Tim's
   *"current session stats"*) was built as the Session object; confirm it covers what he meant.

## In the brief, the walk-sheet or the probe
- The walk-sheet's H3 didn't say not to toggle the nudge mid-test; the toggle exposed defect 1.
- H6 can't observe the bedtime nag itself unless the walk runs past the set time; the sheet should
  say to set a bedtime a few minutes ahead.
- **WizardryLedger loaded and `/run` still worked (H8):** either its taint line is fixed or it
  doesn't trigger every session. Worth confirming before the next walk asks for Wizardry off.
- The brief's FEATURES.md sections were on an unmerged branch at build time (PR #9, merged since).

## Not answered
**H2 and H5: deferred by Tim** to the next round's walk, for evidence. Recorded as not walked.
