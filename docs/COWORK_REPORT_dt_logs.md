# Cowork report: dt_logs (card 7)

Brief: `docs/COWORK_BRIEF_dt_logs.md`. Walk-sheet: `docs/UAT_dt_logs.md`.
Built 2026-11-02 in a cloud session. No game client was used: everything below was proved
offline with stubbed tests. The in-game checks (G5-G9, H1) are Tim's to walk.

**Result:** `DeadTired/Logs.lua` is built. All seven suites are green (85 checks in the new
`logs` suite). All seven Task 6 guards were proved red. No stop condition tripped. The CLAUDE.md
test-only exception was used once, for guards 1 (login half) and 6 (see *Guard proofs*).

## Branch

The work is pushed to **`card/dt_logs`**, branched off `card/dt_foundation` at `61fe2d3`, as
the brief and Tim's request name it. It is not on this session's default branch
(`claude/vibrant-ptolemy-g3wvq9`). `main` is untouched.

The branch also carries these files, taken unchanged from `main` at `7c85aa9`. Card 1's branch
predates them, and the build needs them:
`CLAUDE.md`, `docs/ROADMAP.md`, `docs/COWORK_BRIEF_dt_logs.md`, `docs/UAT_dt_logs.md`,
`reference/README.md`, `reference/wizardry/LogPrompt/*`. None of them is in `DeadTired/`, so
G4 is unaffected.

## Preconditions

- P1: `card/dt_foundation` exists at `61fe2d3`, and its `run_all.sh` exited 0 before any change
  (six suites, 174 checks).
- P2: the brief marks R1-R6 ratified (2026-11-02).

## Task 1: lookups

`reference/SPEC_forever_namespaces.md`, `C_ChatInfo` block (45 functions):

| Function | Found |
|---|---|
| `C_ChatInfo.IsLoggingCombat` | yes, line 767 |
| `C_ChatInfo.IsLoggingChat` | yes, line 766 |

These are globals, which the spec does not list, so each is called through `DT.try` and is safe
when absent: `IsInInstance`, `GetInstanceInfo`, `GetRealZoneText`, `GetZoneText`,
`InCombatLockdown`, `UnitIsDeadOrGhost`, `GetCVarBool`, `CreateFrame`, plus `LoggingCombat` and
`LoggingChat`, read with no argument only. One spec match is not what the brief means: the
`GetInstanceInfo` at line 937 is `C_Commentator.GetInstanceInfo`. The global of that name is
unverified, as the brief says the probe will check.

**Builds on, re-verified on `card/dt_foundation` @ `61fe2d3`:** `DT.module{}` (its own frame,
`errorKey`/`lastKey`, re-raise), `DT.verb(prefix, fn, usage)`, `DT.db()`, `DT.isMember()`
(Guild.lua), `DT.out`, `DT.try`, `DT.clean` and `DT.after` are all present as the brief
describes. One more card 1 name is used: `DT.listen("member", …)` (Core.lua). Welcome.lua uses
it the same way, so a login whose guild info arrives late still gets its dialog.

## What was built

| File | Change |
|---|---|
| `DeadTired/Logs.lua` | new, the module (`id = "logs"`, `errorKey = "logs"`, `lastKey = "lastLogs"`) |
| `DeadTired/tests/test_logs.lua` | new, 85 checks |
| `DeadTired/DeadTired.toc` | `Logs.lua` appended after `Welcome.lua` (R6) |
| `DeadTired/tests/run_all.sh` | `logs:Logs` appended to the module list (R6) |

`DT.VERSION` stays `0.1.0`. No other card 1 file was touched. The harness is unchanged: the
suite builds each client with `load = false`, adds its own stubs, loads `Logs.lua` into the
same environment, and only then fires `ADDON_LOADED`.

## Copied from `reference/wizardry/LogPrompt/LogPrompt.lua`, and what changed

Copied with the bodies kept: `readState`, `state`, `word`, `plan`, `finish` (including
`pendingHide` for a click in combat), `clickRan`, `makeButton`, `build` (frame, backdrop guarded
by `if dlg.SetBackdrop`, title and status font strings), `arm`, `show` with its combat deferral
(`pendingShow`), and the `PLAYER_REGEN_ENABLED` handling.

Changed:
- **Guarded reads.** `readState` goes through `DT.try`/`DT.clean`. The legacy global fallback is
  `try(_G[legacyName])`, so it is still called with no argument. A reader that errors or answers
  with a secret counts as unknown and falls through. `InCombatLockdown`, `GetCVarBool` and the
  instance reads are guarded too.
- **Two dialogs from one builder.** `frame()` plus `buildLogin()` (the beta's four buttons) and
  `buildInstance()` (two buttons: `Log it` runs `/combatlog`, `Not now` runs nothing). The frame
  and button names became `DeadTiredLogsLogin`, `DeadTiredLogsInstance` and
  `DeadTiredLogsButton_<key>`.
- **`makeButton` takes an `onRan` callback** in place of the beta's fixed `finish(label)`, so each
  dialog chooses what to print afterwards.
- **After-click lines** follow the brief, not the beta's `label -> …` line. The re-read still
  happens 0.5 s later, through `DT.after`, or at once without `C_Timer`.
- **When it asks.** The beta asked at every login or /reload. Here the login dialog needs
  `/dt logs login on` (R2), and the instance dialog runs on entering a dungeon or raid (R1, R5).
- **`pendingShow`** now records which dialog is waiting and, for the instance dialog, the visit
  key. The instance dialog is dropped if that visit has ended by the time combat ends.
- **State is kept** (`DeadTiredDB.logs`), for members only. The beta kept none.
- **The `/logprompt` slash command** is replaced by `/dt logs now` through the router.

## R1-R6 as built

- **R1:** `zoneCheck` runs on `PLAYER_ENTERING_WORLD` and `ZONE_CHANGED_NEW_AREA`.
  `L.where()` returns a visit key only for `"party"`/`"raid"`. `"pvp"`, `"arena"`, `"none"` and
  anything else never ask. Asking is on unless `DeadTiredDB.logs.ask == false`. `/dt logs off`
  and `/dt logs on` set it, account-wide.
- **R2:** `loginCheck` runs only on a PLAYER_ENTERING_WORLD with `isLogin` or `isReload`, once
  per Lua session, and only when `DeadTiredDB.logs.login == true`. It shows the four-button
  dialog, with each button armed only for logs that are off (`plan`). Nothing shows if both are
  on.
- **R3:** the instance dialog has no chat-log button. Its only macro is `plan(c, true).combat`.
- **R4:** the only switch is the secure button's macro text (`/combatlog`, `/chatlog`). No line
  in `DeadTired/` calls `LoggingCombat`/`LoggingChat` with an argument (G3 grep is clean). No
  log file is read. No log is ever switched off, because a button is armed only while its log is
  off.
- **R5:** one dialog per visit. `Not now` closes it, and the visit is kept until you leave. See
  *Not covered by the brief* for how a /reload and a corpse run are handled. In combat the dialog
  waits for `PLAYER_REGEN_ENABLED`.
- **R6:** the two lines above. Nothing else in card 1's files changed.

## Task 5: `run_all.sh`

```
core: 44 passed, 0 failed
guild: 13 passed, 0 failed
comms: 53 passed, 0 failed
roster: 26 passed, 0 failed
alts: 21 passed, 0 failed
welcome: 17 passed, 0 failed
logs: 85 passed, 0 failed
ALL GREEN
```

G3: `grep -rnE "COMBAT_LOG|CombatLog|SendChatMessage|Logging(Combat|Chat)\([^)]" DeadTired/ --include=*.lua | grep -v "/tests/"` finds nothing.
G4: `git diff origin/card/dt_foundation --stat -- DeadTired/` (after the commit) is below.

## Task 6: guard proofs

A script took one guard out of `Logs.lua` at a time, ran `test_logs.lua`, then restored the file.
The restored file was confirmed byte-identical with `cmp`. The failing checks listed are from
the final suite (85 checks).

| # | Guard removed | Checks that went red |
|---|---|---|
| 1a | member gate in `zoneCheck` | `another guild: no dialog`, `another guild: nothing stored`, `no guild: no dialog, nothing stored`, `guild info late: no dialog yet`, `and nothing stored for it` (+1) |
| 1b | member gate in `loginCheck` | `login asking on, character outside the guild: no login dialog` |
| 2 | `"party"`/`"raid"` type check in `L.where` | `battleground, arena and open world: never`, `open world at login: no dialog` (+10) |
| 3 | logging-already-on skip in `askInstance` | `raid with logging on: no dialog`, `fallback read sees logging on: no dialog` (+1) |
| 4a | once-per-visit: `if visit then return end` | `zone change or loading screen inside: still one dialog`, `Not now, then a loading screen inside: no second dialog` (+5) |
| 4b | once-per-visit: resume after /reload | `Not now, then /reload inside the same instance: no dialog` (+3) |
| 4c | once-per-visit: corpse-run hold | `a corpse run back in: no dialog` (+1) |
| 5 | the `ask` setting in `askInstance` | `/dt logs off: never`, `off survives a reload`, `/dt logs on: back` |
| 6a | combat deferral in `askInstance` | `entering in combat: no secure change attempted (no error)`, `entering in combat: no dialog yet`, `no handler error from secure changes in combat`, `combat ends inside: shown` (the suite then aborts) |
| 6b | combat deferral in `showLogin` | `login in combat: no secure change attempted (no error)`, `login in combat: shown when combat ends` (the suite then aborts) |
| 7 | arming only while off (`plan`) | `chat on: only the combat log offered`, `combat on: only the chat log offered` |

### The one test-only strengthening (CLAUDE.md's exception)

On the first pass, two guards were weak:
- **1b turned nothing red.** No non-member in the suite had login asking on.
- **6a and 6b went red only by crashing the suite.** The stubbed secure `SetAttribute` raises in
  combat, the module re-raises, and the suite aborted before any named check reported.

The fix touched only `DeadTired/tests/test_logs.lua`. No addon code changed. Both guards were
then proved again and went red as the table shows.

```diff
@@ combat
   a.combat = true
-  go(a, RFC)
+  local okEnter = pcall(go, a, RFC)
+  check("entering in combat: no secure change attempted (no error)", okEnter)
@@ login prompt in combat
   a8.combat = true
-  a8:login()
+  local okLogin = pcall(a8.login, a8)
+  check("login in combat: no secure change attempted (no error)", okLogin)
@@ non-members
+  -- the account-wide setting is on (set by a guild character), played on an alt outside the guild
+  local adb = { logs = { login = true } }
+  local alt = newClient(w, { name = "Outsider", guild = "Alliance Spies", db = adb })
+  counter(alt)
+  alt:fire("PLAYER_ENTERING_WORLD", true, false)
+  alt:fire("PLAYER_ENTERING_WORLD", false, true)
+  check("login asking on, character outside the guild: no login dialog", alt.loginShows == 0
+    and not loginShown(alt) and #alt.printed == 0)
+  go(alt, RFC)
+  check("and nothing stored for it", adb.logs.visit == nil and alt.instShows == 0)
```

## Every player-facing line, verbatim

Given by the brief:
- Login dialog title: `The dead keep records. Turn them on?`
- Login dialog status: `combat log <ON|OFF|?>    chat log <ON|OFF|?>` (the beta's colours)
- Login buttons: `Combat log`, `Chat log`, `Both`, `Neither`
- After any login-dialog click (0.5 s later): `combat log <state>, chat log <state>.`
- Instance dialog title: `Log this one?`
- Instance dialog line: `Combat log is off. Warcraft Logs needs it on.`
- Instance buttons: `Log it`, `Not now`
- After `Log it` (0.5 s later): `Logging. Try not to die on the record.` or
  `The log didn't start. Type /combatlog yourself.`
- `/dt logs now` with both on: `Already logging both.`

Mine (command replies and usage, short, in house tone). All are prefixed by card 1's
`Dead Tired`:
- `/dt logs`: `combat log <state>, chat log <state>. Asking in dungeons and raids: <on|off>. At login: <on|off>.`
- `/dt logs on`: `I'll ask about the combat log in dungeons and raids.`
- `/dt logs off`: `No more asking in dungeons and raids. /dt logs on to undo.`
- `/dt logs login on`: `I'll ask about both logs at login.`
- `/dt logs login off`: `No more asking at login.`
- `/dt logs now` in combat: `In combat. The prompt waits until it's over.`
- `/dt logs <anything else>`: `/dt logs | logs on/off | logs login on/off | logs now`
- `/dt` help lists the verb as `logs on/off/login/now`.

`Not now` prints nothing.

## Not covered by the brief, and what I chose

1. **A /reload inside the same visit.** A reload wipes Lua memory, so the visit key is stored as
   `DeadTiredDB.logs.visit`, for members only. The brief's table named only `ask` and `login`;
   `visit` is the one addition. A PLAYER_ENTERING_WORLD with `isReload` and the same key resumes
   the visit with no dialog. Leaving clears the key.
2. **A fresh login inside an instance counts as a new visit**, so it asks again. The client
   switches the combat log off at logout, so asking again is the point.
3. **Corpse run (R5) against "a visit ends when the type becomes anything else" (spec).** If you
   leave an instance while dead or a ghost (`UnitIsDeadOrGhost`), the visit key is held. Coming
   back into the same key resumes the visit without asking. Any other exit ends the visit, so
   G7's "leave and re-enter: dialog again" still holds. The visit key uses `GetInstanceInfo`'s
   8th return, which is the instance's map ID, so the same dungeon gives the same key.
4. **Login dialog and instance dialog at once.** On a login or /reload inside a dungeon, with
   login asking on and the combat log off, only the login dialog shows. It already offers the
   combat log. The visit still counts as asked.
5. **A non-member alt on an account where login asking is on**: no dialog, nothing stored. The
   member gate covers both dialogs.
6. **Guild info late at login**: the `member` signal re-runs both checks, so the dialog appears
   when membership arrives, once.
7. **`Neither`** also prints the re-read line ("After a click" in the spec), as the beta did.
8. **Fallback for the instance type**: if `IsInInstance` gives no type, `GetInstanceInfo`'s 2nd
   return is used. With neither, the type is `"none"` and the addon never asks.
9. **Dialog sizes and positions** are the beta's: 428 wide for login, 224 for the instance
   dialog, both top-centre at −140.

## For Tim's walk

The two client facts flagged in the brief are untested offline:
- the global `GetInstanceInfo`'s 8th return on Forever, which falls back to the zone text if
  absent;
- whether the secure `/combatlog` macro starts the log on Forever. If it doesn't, the after-click
  line will say so.

The `dt_probe` amendment 2 records both.
