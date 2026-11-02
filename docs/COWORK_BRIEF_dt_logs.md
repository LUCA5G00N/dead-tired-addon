# Cowork brief: DEAD TIRED logs (ask to switch the combat log on in dungeons and raids)

**Amended 2026-11-02 (fix round 1, F10 and F11 in `docs/COWORK_BRIEF_dt_fixes1.md`, audit AUD-11
and AUD-14):** a log whose state can't be read is never armed; the instance dialog hides when the
visit ends. Marked *(amended, fix round 1)*.

Read first, in order:
1. `CLAUDE.md`.
2. This brief and its walk-sheet, `docs/UAT_dt_logs.md`.
3. On `card/dt_foundation`: `DeadTired/Core.lua` (`DT.module`, `DT.verb`, `DT.db`, `DT.out`,
   `DT.try`, `DT.clean`, `DT.after`), `DeadTired/Guild.lua` (`DT.isMember`), `DeadTired.toc`,
   `DeadTired/tests/run_all.sh`, and one existing suite for the stub style.
4. `reference/wizardry/LogPrompt/` (Tim's beta reminder): the pattern this card copies.
5. `reference/SPEC_forever_namespaces.md`: search it, don't read it top to bottom.

**Draft-status: ratified by Tim 2026-11-02 (R1, R4-R6 as proposed; R2-R3 as amended by Tim).** Written 2026-11-02, before launch and before any card
has been walked. Card 1 is at `61fe2d3`; Task 1 re-verifies every name below against
`card/dt_foundation` as it stands when you start. Two things only the live client can answer,
and the launch-night probe (`dt_probe`, amendment 2) records both: whether addon code may switch
the combat log itself, and what `IsInInstance` / `GetInstanceInfo` report on Forever.

## Origin

Warcraft Logs needs a combat log, and WoW switches logging off at every logout, so it gets
forgotten. The Archon app archives and deletes old logs but can't switch logging on (its FAQ says
addons can). Tim's beta addon `WizardryLogPrompt` asked at every login. Tim asked (2026-11-02)
for the guild addon to ask when you **enter a dungeon or raid**, with an option to turn the
asking off.

## Precondition

- P1: `card/dt_foundation` exists and its `run_all.sh` exits 0.
- P2: Tim has ratified R1-R6 below (each marked `ratified`, or ruled otherwise).

## Depends on: rulings

- `CLAUDE.md` *Quiet by default*: this card prints (shows a dialog) unasked. R1 rules it.
- `CLAUDE.md` *No combat data, ever*: this card **switches the log file on** and never reads it,
  nor any combat event. R4 bounds it.
- ROADMAP rule 1 (branch off card 1), rule 5 (card 1 files change only as R6 allows).

## Ratify before code

The round may not be built while any of these is `proposed`. All six are ratified.

- **R1 (ratified 2026-11-02, as proposed): ask on entering a dungeon or raid, on by default.** When a member enters an
  instance whose type is `"party"` or `"raid"`, and the combat log is **off**, a small dialog asks
  whether to switch it on: **Log it** / **Not now**. On for every member by default, because the
  point is that nobody has to remember. `/dt logs off` stops the asking for the whole account;
  `/dt logs on` brings it back. Battlegrounds and arenas (`"pvp"`, `"arena"`) never ask.
- **R2 (ratified 2026-11-02, amended by Tim): the login prompt is opt-in, and covers both logs.**
  The beta addon asked at every login, which suits Tim's research but would be noise for the guild.
  Off by default; `/dt logs login on` asks at login (once per login or `/reload`, not on loading
  screens), `/dt logs login off` stops it. **The login prompt offers the combat log and the chat
  log**, as the beta addon did: buttons `Combat log`, `Chat log`, `Both`, `Neither`, each armed
  only for a log that is off. If both are on, nothing shows.
- **R3 (ratified 2026-11-02, amended by Tim): the dungeon and raid prompt is combat log only.**
  The chat log is offered only by the opt-in login prompt (R2).
- **R4 (ratified 2026-11-02, as proposed): switched by the player's click, through the client's own command.** The
  **Log it** button is a secure button running `/combatlog` as macro text, as `LogPrompt.lua`
  does. That works whether or not addon code may call `LoggingCombat` on this client, and it means
  every switch is a human click. The chat log is switched the same way, with `/chatlog` (R2).
  A button is armed only while its log is off, because both commands toggle. The addon never
  calls `LoggingCombat` or `LoggingChat` with an argument (no-argument reads are allowed), never reads
  the log file, and never switches logging **off**.
- **R5 (ratified 2026-11-02, as proposed): ask once per visit.** **Not now** means no more asking until you leave that
  instance and enter one again (a corpse run back in, a `/reload` or a loading screen inside the
  same instance doesn't ask again). If logging is already on, nothing shows. In combat, the dialog
  waits until combat ends (secure buttons can't be set up in combat), and is dropped if you've left
  the instance by then.
- **R6 (ratified 2026-11-02, as proposed): what this card may change in card 1's files.** Two lines, nothing else:
  `Logs.lua` appended to `DeadTired.toc` after `Welcome.lua`, and `logs:Logs` appended to the
  module list in `tests/run_all.sh`. `DT.VERSION` stays `0.1.0`. Merging with cards 3-6 conflicts
  on these lines as theirs do; at merge keep all, in card order, this card last.

## Builds on (card 1, commit `61fe2d3`; Task 1 re-verifies each)

`DT.module{}` (own frame, own error key), `DT.verb(prefix, fn, usage)` for `/dt logs`,
`DT.db()` (this card keeps `DeadTiredDB.logs = { ask = <bool|nil>, login = <bool|nil> }`, where
`nil` means the default), `DT.isMember()`, `DT.out`, `DT.try`, `DT.clean`, `DT.after`.

## Deliverable

`DeadTired/Logs.lua`: a member entering a dungeon or raid with the combat log off sees one dialog,
and one click on **Log it** switches the log on through `/combatlog`; nothing appears in a
battleground, outside an instance, with logging already on, after **Not now** in the same visit,
for a non-member, or after `/dt logs off`. The offline suite proves each of those, and that no
code path calls `LoggingCombat`, `LoggingChat` or reads a combat event.

### Logs.lua: specification

- **State:** `C_ChatInfo.IsLoggingCombat()` and `C_ChatInfo.IsLoggingChat()` through
  `DT.try`/`DT.clean`; if absent, the globals `LoggingCombat` / `LoggingChat` **called with no
  argument** (a read). ~~Unknown is treated as off~~ *(amended, fix round 1, F10)* Unknown is
  **never armed** (both commands toggle, so arming one could switch a running log off), and the
  dialog shows `?` for it, as `LogPrompt.lua` does.
  - Instance dialog, combat log unknown: no dialog; one line, once per visit (none after
    `/dt logs off`): `Can't tell if the combat log is on. Type /combatlog if it isn't.`
  - Login dialog: the unknown log's button and **Both** are not armed. If no button can be armed,
    the dialog doesn't show and the line prints instead, for each unknown log (the chat log's:
    `Can't tell if the chat log is on. Type /chatlog if it isn't.`).
- **Instance:** `IsInInstance()` (both returns) on `PLAYER_ENTERING_WORLD` and
  `ZONE_CHANGED_NEW_AREA`. A visit starts when the type becomes `"party"` or `"raid"` from
  anything else, and ends when it becomes anything else. *(amended, fix round 1, F11)* When the
  visit ends, the instance dialog hides (after combat ends, if in combat, and only if no visit has
  begun again by then). Escape is not added. The visit key is the instance type plus
  `GetInstanceInfo()`'s instance ID (8th return) when readable, else the zone text.
- **Login dialog (R2):** `LogPrompt.lua`'s four-button dialog, near enough as it is. Title:
  `The dead keep records. Turn them on?`. Status line as the beta's (`combat log ON/OFF/?    chat
  log ON/OFF/?`). Buttons `Combat log`, `Chat log`, `Both`, `Neither`. After a click, the beta's
  re-read and one line: `combat log <state>, chat log <state>.`
- **Instance dialog (R1, R3):** copy `LogPrompt.lua`'s frame, secure button, `clickRan` and combat
  deferral, with two buttons. Title: `Log this one?`. Line under it: `Combat log is off. Warcraft Logs needs it on.`
  Buttons `Log it` and `Not now`. After a click on **Log it**, re-read the state 0.5 s later and
  print one line: `Logging. Try not to die on the record.` if on, or
  `The log didn't start. Type /combatlog yourself.` if not.
- **Commands** (`/dt logs …`):
  - `/dt logs`: one line with the log's state, whether asking is on, and whether login asking is
    on;
  - `/dt logs on` / `off`: dungeon and raid asking (R1);
  - `/dt logs login on` / `off` (R2);
  - `/dt logs now`: shows the login dialog now if either log is off, wherever you are (a manual
    way in; prints `Already logging both.` if both are on).
- **Member gate:** nothing shows and nothing is stored for a non-member (`DT.isMember()` false).
  `/dt` outside the guild behaves as card 1 already does.

## Working rules

- Lua 5.1; one module, `DeadTired/Logs.lua`, registered with `DT.module{}`.
- Copy from `reference/wizardry/LogPrompt/LogPrompt.lua`, keeping bodies where you can; the report
  says what was copied and what changed.
- Guarded reads everywhere. The dialog code must survive `CreateFrame` returning frames without
  `SetBackdrop` (the beta file already handles this).
- Player-facing text is what this brief gives, plus usage lines. List every line in the report.

## Tasks

1. **Branch and verify.** `card/dt_logs` off `card/dt_foundation`. Re-verify *Builds on*. In the
   reference, record lines for `C_ChatInfo.IsLoggingCombat`. Missing → stop.
2. **`DeadTired/Logs.lua`** per the specification.
3. **`DeadTired/tests/test_logs.lua`.** Stub `IsInInstance`, `GetInstanceInfo`,
   `C_ChatInfo.IsLoggingCombat`, `InCombatLockdown`, frames and secure buttons in the house
   style. Checks at least:
   - entering a dungeon or a raid with logging off shows the dialog once; with logging on, never;
   - battleground, arena and open world never;
   - **Not now**, then a `/reload` or loading screen inside the same instance: no second dialog;
     leaving and entering again: one dialog;
   - entering in combat: shown when combat ends if still inside; dropped if not;
   - `/dt logs off`: never; `/dt logs on`: back; the setting survives a reload (it's in
     `DeadTiredDB`);
   - login asking off by default; `/dt logs login on` asks once at login, not on zone changes;
   - the login dialog arms `/combatlog`, `/chatlog` and both only for logs that are off, and
     doesn't show when both are on;
   - the instance dialog never offers the chat log;
   - **Log it** is armed with `/combatlog` only while the log is off;
   - non-member: no dialog, nothing stored;
   - over a scripted session of logins, zones, instances, combat and clicks, a stub counter shows
     **zero** calls to `LoggingCombat` or `LoggingChat` with an argument, and no combat event
     registered;
   - the after-click line matches the state read 0.5 s later.
4. **Card 1 lines** per R6.
5. **Run** `DeadTired/tests/run_all.sh`: exits 0.
6. **Guard proofs.** Remove each once, confirm red, restore:
   1. the member gate;
   2. the `"party"`/`"raid"` type check;
   3. logging-already-on skip;
   4. the once-per-visit memory;
   5. the `ask` setting;
   6. the combat deferral;
   7. arming only while off.
7. **Push** `card/dt_logs` (or the session branch, said at the top of the report).
8. **Report.**

## Explicitly out of scope

- Switching logging **off**, ever, including on leaving an instance.
- The chat log anywhere but the opt-in login prompt (R2, R3).
- Reading, parsing, uploading, archiving or deleting log files. The Archon app does archiving;
  Tim's F: backup does the rest.
- Asking in battlegrounds or arenas, or any per-instance list of which dungeons to ask in.
- Sharing anything about logging with the guild (who logs, who doesn't).
- Any change to card 1 beyond R6, or to cards 3-6.

## The one deliberate widening, named

**A dialog appears unasked when you enter a dungeon or raid.** R1 rules it. What still bounds it:
- only members, only `"party"`/`"raid"` instances, only while the log is off;
- once per visit; **Not now** holds until you leave;
- one command turns it off for the account;
- the switch is the player's click on the client's own command; the addon itself never switches
  anything.

This is listed in `CLAUDE.md`'s *Ruled exceptions*.

## Stop conditions

- `C_ChatInfo.IsLoggingCombat` missing from the reference → stop.
- The design needs the addon to call `LoggingCombat`/`LoggingChat` to switch, or to read the log
  or a combat event → stop.
- A card 1 file needs more than R6's two lines → stop (ROADMAP rule 5).
- A guard removal turns nothing red and the fix needs addon code → stop (`CLAUDE.md`'s one
  exception applies to test-only fixes).

## UAT: acceptance checks

In `docs/UAT_dt_logs.md`.

## Reporting

`docs/COWORK_REPORT_dt_logs.md` on `card/dt_logs`, recording: Task 1's lookups; what was copied
from `reference/wizardry/LogPrompt/` and what changed; R1-R6 as built; every guard removal and the
check that went red; every player-facing line verbatim; anything the brief didn't cover and what
you chose. Never write `docs/UAT_dt_logs_results.md`.
