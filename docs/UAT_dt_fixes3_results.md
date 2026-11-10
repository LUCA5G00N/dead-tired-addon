<!-- walked=2026-11-10 commit=45c972a (release/0.1.0-rc3, installed zip) host=lucasgoonpc (Windows, WoW Forever 1.60.1) dirty=n/a: walked the installed dist/DeadTired-0.1.0-rc3.zip, not a checkout; all 19 installed files checked identical to that zip, per file, by md5 on 2026-11-10 by=Tim (Stromham) closer=Claude session. No stamp convention exists in this repo; these fields are the ones that apply. -->
# Results: DEAD TIRED fix round 3 (dt_fixes3), walked 2026-11-10

Walked by **Tim** in game on Stromham (level 30, Guild Master, Undercity) with a second player,
**Liliac** (Lilbit High, level 19), on rc3. Against `docs/COWORK_REPORT_dt_fixes3.md` on
`release/0.1.0-rc3` (45c972a); walk-sheet `docs/UAT_dt_fixes3.md` (on `main`). The closing
session verified the `[G]` checks and recorded the `[H]` answers; it answered none of them.

**Outcome:** 3 of 7 `[H]` passed (H1, H2, H3), **1 failed (H4)**, 3 deferred (H5-H7). The round's
main purpose, DeadTired talking on Forever (R-1), is shown working between two players. The walk
found three defects, all deferred by Tim to the rebuild.

## [G] checks (verified by the closing session)

| Check | Evidence | Result |
|---|---|---|
| G1 Baseline | Report, Task 1: rc2 15 suites, 766 checks green; `test_realm_spelling.lua` red 2/2 before. Not re-run by the closer | from the report |
| G2 R-1 | Report, Task 2 (old restricted checks rewritten to lockdown; new R-1 checks). Closer re-ran rc3 `run_all.sh` on 2026-11-09: exit 0, 860 checks, ALL GREEN | pass |
| G3 Held line | Report, Task 2 (9 held-line checks); in the closer's re-run | pass |
| G4 AUD-10 | Report, Task 3; in the closer's re-run. Closer read the diff: `succeeded()` treats 0/`true`/`nil` as success, requeue at the front, drop on the 3rd refusal | pass |
| G5 AUD-06 | Report, Tasks 4-5; in the closer's re-run. Closer read `DT.realmKey`/`keyOf`/`normKey`/`migrateKeys` and the `keysV` once-flag. On Tim's PC the saved file shows `keysV = 2` after first login | pass (realm part only: see Defects 1) |
| G6 Nudge | Report, Task 6 (recruit suite 74); in the closer's re-run. Closer read `schedule()`: posted-since, switched-off and officer checks | pass |
| G7 Probe `registered` | Report, Task 7 (probe 153 → 164 checks). Not re-run by the closer | from the report |
| G8 Guards | Report, Task 8: 10 brief guards + 5 extra, each removed once → a named check red → restored. Not re-run by the closer | from the report |
| G9 Audit test after | Report, Task 9: 2/2 green. Not re-run by the closer | from the report |
| G10 Zips | Report, Task 10: `diff -r` clean, rc2 zip removed. Closer, 2026-11-10: the 19 installed files on Tim's PC are identical (md5, per file) to `dist/DeadTired-0.1.0-rc3.zip` | pass |

## [H] checks (Tim's words)

| Check | Tim said | Evidence on screen | Result |
|---|---|---|---|
| **H1** Install rc3 over rc2. Log in: the welcome line as before; BugSack quiet. | *"ok logged into Stromham - welcome message screenshot"*; *"H1 - yes been quiet today I think"* | 10:56:49 `Dead Tired Rest in Pieces, Stromham. The crypt's open. /dt for the rest.` | **pass** |
| **H2** `/dt recruit` once (as an officer, in a city): posts; 15 min later exactly one line "The crypt door creaks open: you can recruit again (/dt recruit)." Nothing else posted. | *"tested from my side"*; *"H2- yes confirmed"* | 10:57:13 `Posted line 1 of 5 to General.`; 11:12:13 `The crypt door creaks open: you can recruit again (/dt recruit).` (15 min 0 s) | **pass** |
| **H3** With a guildie running rc3: `/dt who` lists them within a minute of both logging in (proves R-1: messages now go out). | *"I think we've got a successful test of the network!"* | Lilbit High online 11:18:12; Tim's `/dt who` 11:18:45: `this session (2): Lilbit High 0.1.0, Stromham Hamson (alt of Stromham) 0.1.0`. Liliac's `/dt who` (11:19) lists Lilbit High and Stromham Hamson | **pass** |
| **H4** `/dt alts` shows your main and alts once each, no realm doubled (AUD-06 on our spaced realm). | *"H4 - that needs fixing - 1 to align in the rebuild."* | 11:17:34 after `/dt main`: `Stromham's lot: main Stromham; alts (5): Gizzardthe, Jobbi, Marvella, St, Stromham Hamson.` (the main listed again as an alt) | **fail** |
| H5 Boss-fight held line | *"We'll defer the rest for now."* | | **not walked** (deferred) |
| H6 Nudge off / on | as H5 | | **not walked** (deferred) |
| H7 One logs prompt on dungeon entry | as H5 | | **not walked** (deferred) |

## Defects the walk found

### In the addon (deferred by Tim to the rebuild: *"we can hunt that down when we build it properly (thinking a proper rebuild approach with the framework idea in mind for robustness)"*)
1. **Two-part names: keys disagree about who you are.** On Forever a character has a first name
   and a surname. Tim's `/dump` (11:15:35): `UnitName("player")` = `"Stromham"`,
   `UnitFullName("player")` = `"Stromham"`, `GetUnitName("player", true)` = `"Stromham Hamson"`.
   Addon-message senders arrive as the full form (`heard hi GUILD Stromham Hamson`, 7 Nov).
   `DT.charKey()` uses the short form, so the player's own HELLO is keyed as someone else:
   `/dt who` lists yourself, `/dt alts` lists the main as its own alt (H4), and every "addressed to
   me" check (prep and stash `to`) would miss. Likely also "St" / "St Ham". Fix direction: one key
   built from the full name (`GetUnitName(unit, true)`, minus any `-Realm`), with short-name entries
   merged; `/dt gank` the same for targets.
2. **Realm shown as foreign on another client.** On Liliac's client the same line reads
   `Stromham Hamson (alt of Stromham-CAMWOWEU4Realm2PvP)`: `DT.display` judged Tim's realm not to
   be Liliac's own. Unexplained: Liliac's `GetRealmName()` / `GetNormalizedRealmName()` were not
   read (his `/dump` was blocked: defect 3).
3. **Taint: DeadTired blocks the "allow scripts" confirmation.** Liliac's first `/dump` gave *"DeadTired
   has been blocked from an action only available to the Blizzard UI"*; it stayed blocked after
   **Ignore**, from a macro, and with every other addon disabled (Liliac: *"yea even tried running
   the cmd in a macro and with all other addons diabled"*). So with DeadTired loaded a player can
   never accept `/run`//`dump`. Same pattern as Tim's older BugGrabber entry blaming WizardryLedger
   for `SetAllowDangerousScripts()`. Not confirmed by a stack (no BugSack on Liliac's side).
   Workaround: disable DeadTired, run one `/dump`, accept, re-enable.

### In the brief, the walk-sheet or the probe
- **The brief's AUD-06 assumed a name is one token.** It normalised the realm only; neither the brief,
  the audit test nor the harness has a two-part name, so G5 passed and H4 failed. Carry to the
  rebuild's requirements (`FEATURES.md`).
- **The probe never read `GetUnitName(unit, true)`**, so the surname went unnoticed from launch.
  Any future probe should record every name function for player, target and a guild sender.
- **Evidence route:** addon output never reaches `WoWChatLog.txt` (found 7 Nov); every `[H]` here
  rests on screenshots. Future walk-sheets should say "screenshot it".
- The build report's open choices (held line for typed commands only; `nudge off|on` print
  nothing; the probe ping still waits on the flag) were not walked (H5, H6 deferred).

## Not answered
H5, H6 and H7 were deferred by Tim (*"We'll defer the rest for now."*). Nothing else is open.
