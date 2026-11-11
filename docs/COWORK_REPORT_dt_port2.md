# Cowork report: DEAD TIRED Port 2 (cards 4, 6, 7; Port 1 fixes; 0.3.0)

**Branch: `claude/sharp-gauss-84wft6`**, the session's own branch (this session can push only
there; `CLAUDE.md`, ruled 2026-11-11; the brief allows it). Not merged to `main`: Tim merges after
his walk. Brief: `docs/COWORK_BRIEF_dt_port2.md`; walk-sheet: `docs/UAT_dt_port2.md` (not ticked;
no `_results.md` written).

- **Old head:** `4a39973` (`main` at session start: the brief's `c760793` plus the merge of the
  brief itself, #14). **New head:** `717953c` (build, proofs, zip, notes), then this report's commit.
- **Outcome:** every deliverable built. **25 suites, 1136 checks, ALL GREEN** (baseline 19 suites,
  690). **75 guards proved** (Port 1's 44 again, 31 new), every file restored byte for byte; no test
  had to be strengthened. `dist/DeadTired-0.3.0.zip`, `diff -r` clean. **No stop condition was hit.**
- **Environment:** `lua5.1` was not installed; `apt-get install -y lua5.1` worked (5.1.5). No other
  Lua was used.

## Task 1: baseline
`main` at `4a39973`: 19 suites, **690 checks, all green**, libs unmodified (SHA256SUMS): alts 28,
bar 69, comms 46, core 37, crypt 94, debug 10, guild 20, keys 27, migrate 31, prep 47, recruit 83,
recruitlines 7, session 9, settings 33, settingsview 28, skins 22, ui 40, who 36, taint 23.

## Counts, per suite

| Suite | Before | After | What's new |
|---|---:|---:|---|
| bar | 69 | 78 | names not live text (card, `/dt bar list`, typed lookup), the grab hand, no-cursor client |
| core | 37 | 37 | module list and version updated |
| crypt | 94 | 98 | date column short, full date in the tooltip, one line at its width |
| events | | 31 | new: rc3's checks (list, countdowns, reminders), viewport, card |
| eventslist | | 4 | new: rc3's list byte for byte, shape, no globals |
| gank | | 71 | new: rc3's checks on full-name keys, R1 proved, the board viewport |
| keys | 27 | 29 | `DT.normKey` |
| logs | | 123 | new: rc3's 723-line suite carried whole, onto the new harness (settings now cards) |
| migrate | 31 | 53 | Port 2 fixture from rc3's shapes |
| played | | 62 | new: rc3's checks, R-P2-1 in place of A3's hook, the board viewport |
| recruit | 83 | 94 | the nudge re-arm (off/on, the card, a /reload, once only, officer still checked) |
| stash | | 86 | new: rc3's checks on full-name keys, answers in a viewport, own short key folded |
| taint | 23 | 34 | R-P2-2: the scanner proved on a sample, only `UI.lua` touches the table, three bad copies red |
| ui | 40 | 50 | R-P2-2 registration model, the short date |
| who | 36 | 36 | version string updated |
| alts, comms, debug, guild, prep, recruitlines, session, settings, settingsview, skins | 280 | 280 | unchanged |
| **Total** | **690** | **1136** | |

Old checks rewritten to this round's rulings (all named in the diff): `test_ui` "Escape doesn't
close it" (now: no `UISpecialFrames` on the client means nothing is made; R-P2-2 has its own
section), `test_bar` `/dt bar list` (`2 Who [on]`, was `2 DT: 0 online (who) [on]`), `test_crypt`
graveyard row date (`3 Nov`, was `2026-11-03`), and the three version strings.

## Task 2: Port 1 fixes

| Defect | Fix | Proof |
|---|---|---|
| 1 Nudge off then on drops the nudge | `/dt recruit nudge on` (typed, `/dt set` or the card: the setting's `onChange`) with a post's cooldown still running arms the nudge for the time left (`recruit.at` + 15 min); the newest arming replaces the older (the generation counter), and a nudge already said for a post is never said again. **What the walk actually hit:** in-session, off then on never lost the nudge (the old timer checked the setting only when it fired; the re-arm guard's removal leaves the in-session check green and turns only the after-`/reload` check red). The timeline in `UAT_dt_port1_results.md` has a `/reload` between the post (≈18:13) and 18:28 (H4's "post reload check for order", 18:19-18:23): the C_Timer died with the reload. Now off/on after a reload re-arms it; a reload alone still drops it (question 1) | recruit: 11 new checks; guards proved |
| 2 Bar list shows live text | The list (settings card, `/dt bar list`, `/dt bar add/remove/move` lookup) names an object by its `label`, else its registered name, never its `text`. DT's own objects carry their module's title as label (`Dead Tired`, `Who`, `Recruit`, `Session`); BugSack shows `BugSack`. The bar buttons still show the live text | bar; guard proved |
| 3 Grab hand while dragging | The grip's drag start calls the client's `SetCursor("Interface\CURSOR\openhand")`, the drop `ResetCursor()` (globals, guarded; not in the spec file, which lists `C_*` only). Without them the drag works as before. **Not verifiable offline:** whether Forever has that cursor file (H3) | bar |
| 4 Graveyard date wraps | `DT.shortDate`: `2026-11-10 21:00:00` → `10 Nov`, column 46 px (was 76; the name column got the rest); the full stamp in the row's tooltip; the search still finds the full date | crypt; guard proved |
| 5 Escape (R-P2-2) | `DT.viewport` calls `DT.closeOnEscape(<its frame name>)` at creation unless `sticky = true`: `table.insert(UISpecialFrames, name)`, only for a name starting `DeadTired`, once per name, only when the table exists; nothing read, moved or removed. Covers Who, settings, graveyard, gank board, slowest board, events and stash; **prep has no viewport** in 0.2.0 (its lines print), so there is nothing to register | ui, taint; guards proved |

**The taint scan (R-P2-2).** The bytecode scanner now follows `UISpecialFrames`: a read of it is
allowed only as the first argument of `table.insert(UISpecialFrames, <one value>)` with no result
taken, or as the argument of `type(UISpecialFrames)` (the guard before the insert). A removal, an
insert at a position, an assignment into it, a local copy, `#`, any other call, `_G["UISpecialFrames"]`
or replacing the table is a hit (sample: 15 lines, exactly the 10 bad ones flagged). A check also
asserts `UI.lua` is the only file that reads it (twice: the type check and the insert), and three
bad copies of `UI.lua` (a removal, an insert at the front, a replaced table) go red. `hooksecurefunc`
stays banned (no hook on any Blizzard function; ChatThrottleLib's own hooks are the bundled
library's, unchanged).

## Task 3: the ported modules
Copied from rc3 (`release/0.1.0-rc3`, read-only): the logic and the player-facing lines of
`Gank.lua`, `Played.lua`, `Stash.lua`, `Events.lua`, `Logs.lua`, and `EventsList.lua` byte for byte;
rc3's `Logs.lua` carries Tim's beta reminder's copied pieces (`reference/wizardry/LogPrompt/LogPrompt.lua`:
`readState`, `word`, `plan`, `finish`, `clickRan`, `makeButton`, the dialog build, `arm`, the combat
deferral), unchanged here. The guarded-read pattern is the framework's (`DT.try/clean`, from
`reference/wizardry/Forever/Core.lua` via fw1). Each is a `DT.module` with its own frame and error key;
every setting is a card with a typed path. None is a switchable (`optional`) module: each already has
its own opt-in or off switch, and a switch would need new lines and new semantics for the verbs.

| Module | Ported from rc3 | What changed |
|---|---|---|
| **Gank** (card 4) | `/dt gank` (player, other faction, readable name, class, level, zone, the 300 s double press in memory, epoch `t`), GANK sent at once and stored silently by receivers (R2), field validation, F6b, cap 500, `/dt ganks <name>` (10 lines, either name order, "Add the realm."), every line | Keys: the enemy's **full name** from `GetUnitName("target", true)` (surname kept); the realm only from that string's `-Realm`, else ours, **never** from `UnitName`'s or `UnitFullName`'s second value (the port rule). `DT.gank()` refuses unless a typed command runs it (R1 proved). `/dt ganks` opens the **grudge board** viewport (searchable; most frequent first, then newest; rc3's empty line in it, its closing line under it; the date short with the full date in the tooltip). One logs list instead of per guild. `/dt ganks <name>` also matches the first name alone |
| **Played** (card 6) | The board (hours per level, level 1 out, top by rate, ties by name), 60 s send window, PLAYED validation, F9 (withdrawal on share off, 30-day drop, no clock no drop), the award line | **R-P2-1:** `/dt played` calls `RequestTimePlayed()` (guarded) and takes the next `TIME_PLAYED_MSG` within 10 s, once; any other report is ignored; rc3's `hooksecurefunc` on `SlashCmdList.PLAYED` is gone. Setting `played.share` (card; `/dt slowest share on/off`); switching it off by any path withdraws (the setting's `onChange`). `/dt slowest` prints the award line and opens the board viewport (rows: rank, name, h/level, level, hours). One board instead of per guild |
| **Stash** (card 6) | A4 (known unbound only), bags + bank (when opened, when the client names it), all the account's characters, answers to a search only, 4 hits, plain matching, F8b, F6d, the 5 s scan gap, one answer per search, share gate at answer time, every line | Setting `stash.share` (card; off by any path deletes the list). The answers open in a **"Who has it"** viewport (one row per holder, rc3's no-answer line in it, the closing line under it) instead of printed lines. Holder names up to **48** bytes (rc3: 24, the old 255-byte wire budget; full names carry a surname and AceComm now splits long messages). This character's own rc3 short-name entry folds into its full key at login (as Alts does) |
| **Events** (card 6) | Next occurrence and countdown in server time, the week wrap, on-now, reminders 30 min before and at the start (up to 10 min late), once per occurrence, `EventsList.lua` | Setting `events.remind` (card). `/dt events` opens an **Events** viewport (rc3's lines as rows, "Times are server time." under them; "No events on the list." in it); "Can't read the server clock." still prints |
| **Logs** (card 7) | All of it: the instance prompt (party/raid, once per visit, reload/corpse-run aware), the login prompt (`/dt logs login on`), F10-F13, `/dt logs`, `logs on/off/login on/off/now`, every line | Settings `logs.ask` and `logs.login` as cards (were `DeadTiredDB.logs.ask/.login`); the visit in progress stays in `DeadTiredDB.logs.visit`. The secure buttons are DT's own frames (`DeadTiredLogsButton_*` inside `DeadTiredLogsLogin` / `DeadTiredLogsInstance`) running only `/combatlog` / `/chatlog` as macro text; no Blizzard frame or table is touched (the stop condition was not met). The dialogs are not on Escape (R-P2-2 names the viewports; a frame holding secure buttons can't hide in combat) |

New framework pieces (additive, no contract changed): `DT.normKey` (Keys), `DT.closeOnEscape`,
`DT.shortDate` and the viewport's `sticky` option (UI), `DT.barName` (Bar), `DT.grabCursor` (SettingsView).

## Task 4: the legacy migration (`Migrate.lua`, Port 2)
Once per account (`DeadTiredDB.migrated.port2 = true`, with `port2At`, `port2Mapped`,
`port2Merged`, `port2Unmatched`), after Port 1's in the same `init` (so a store straight from rc3
gets both in one load). Deep copies; **`legacy` is never written**. Keys by Port 1's rule
(`DT.migrationMap`: realm normalised; a short key merges into a full key of its realm only when
exactly one full key, among the legacy keys and every key DT knows, starts with it plus a space;
otherwise kept and counted).

| From (rc3) | To (0.3.0) | On a clash |
|---|---|---|
| `gank[<guild>].logs` (`who`, `by` re-keyed) | `gank.logs`, before any log made since; newest 500 | none: appended |
| `played[<guild>][key]` | `played.board` | the newer `t` wins |
| `played.share` | `settings.played.share` | a setting already set stays |
| `stash.chars[key]` | `stash.chars` | the new lists stay; the legacy bank list fills an empty one only |
| `stash.share` | `settings.stash.share` | as above |
| `events.remind` | `settings.events.remind` | as above |
| `logs.ask`, `logs.login` | `settings.logs.ask`, `.login` | as above (`logs.visit` is a session's, not carried) |

Nothing is deleted or overwritten that can't be merged (the stop condition was not met).

**On the fixture** (`test_migrate.lua`, rc3's shapes on Tim's 0.2.0 store: Port 1 done, roster with
`Stromham Hamson`, `Gizzardthe`, `Jobbi`): three gank logs (by `Stromham`, `Lilbit High`, `Jobbi`;
enemies `Nethergarde-Backstabz` twice and `Paladork`), a played board (`Stromham`, `Echo Nightclaw`)
with `share = true`, stash lists for `Stromham` (bags and bank) and `Gizzardthe` with `share = true`,
`events.remind = true`, `logs = { ask = false, login = true, visit = "party:389" }`. Result:
`by Stromham` → `Stromham Hamson` (1 mapped), `Jobbi`, `Lilbit High` and the enemies' short names
kept as they are (counted); the board shows `Backstabz x2 by 2 guildies`; the played entry and the
stash lists under `Stromham Hamson` (bank kept), `Gizzardthe`'s list under its short key until it
logs in; all four settings moved; the old visit not carried; Port 1's work untouched. A setting
already set (`played.share = false`) stays; logs made since stay after the old ones; on a key both
boards hold the newer `t` wins. A second load copies nothing again and the player's changes since
stand (the run-once guard's removal went red at once). Straight from rc3: both migrations, one load.
A fresh account: marked done, nothing moved.

## Task 5: guard proofs (`lua5.1 tools/guard_proofs.lua`)
Every guard: the line changed once, its suite run, the named checks that went red, the file restored
and compared. Rows 1-44 are Port 1's (all still red; none of their guarded lines changed); rows
45-75 are this round's (Task 5's list: R1, A4 and the opt-in, R-P2-1, the withdrawal, the 30-day
drop, R4, the log never switched off, one prompt at a time, never in a battleground, arena or the
open world, the nudge re-arm, `UISpecialFrames` insert-only, the Port 2 run-once; plus the Port 1
fixes). No removal failed to turn a check red, so no test was strengthened.

| Guard | File | Change | Suite | Went red |
|---|---|---|---|---|
| guild gate | `Guild.lua` | `return want ~= nil` | test_guild | **red**: another guild is not the guild; no guild is not the guild; outside: login prints nothing (no welcome, no bar intro) (+8 more) |
| lockdown hold (R-1) | `Comms.lua` | `if false then` | test_comms | **red**: in lockdown: held, nothing sent; a hold is counted; a typed command's message: the held line (+4 more) |
| AUD-10 success test | `Comms.lua` | `if false then item.failed = true end` | test_comms | **red**: refused every time: tried 3 times, then dropped and counted; and not tried again; refused once, then sent: delivered once (+3 more) |
| 3-refusal limit (AUD-10) | `Comms.lua` | `if false then` | test_comms | **red**: refused every time: tried 3 times, then dropped and counted; and not tried again |
| payload-key name match | `Comms.lua` | `return true` | test_comms | **red**: a payload key naming someone else is not taken; the mismatch is counted and kept, not guessed; a short name is not the full name (+2 more) |
| self-exclusion in Who (R-P6: own entry never doubled) | `Who.lua` | line removed | test_who | **red**: self in the saved list is never shown; own GUILD echo: not listed; R-P6: your own entry exactly once, saved copies of you never doubled (+2 more) |
| settings verb-or-noVerb rule | `Core.lua` | `if false then` | test_settings | **red**: a setting with no typed path and no noVerb is refused at registration; a blank noVerb is no reason |
| bar stand-back | `Bar.lua` | `return true` | test_bar | **red**: Titan Panel loaded: DT's bar stands back; standing back: no intro; and the intro then, once (+3 more) |
| borrow-only LibDataBroker | `Bar.lua` | line removed | test_bar | **red**: no LDB: loads and logs in without an error |
| bar intro once only | `Bar.lua` | `if not (bar and bar:IsShown()) then return end` | test_bar | **red**: after /reload: no intro again; on again: no second intro |
| taint scan (rc3's line inserted) | `Core.lua` | `SLASH_DEADTIRED2 = "/deadtired" ⏎ SlashCmdList = SlashCmdList or {}` | test_taint | **red**: taint scan: no hits in DeadTired/*.lua; rc3's SlashCmdList = SlashCmdList or {} in a copy of Core.lua: the scan goes red |
| guild gate: DT.out | `Core.lua` | line removed | test_guild | **red**: outside: DT.out itself prints nothing |
| guild gate: DT.send | `Comms.lua` | line removed | test_guild | **red**: outside: DT.send refuses; outside: nothing on the wire, ever |
| guild gate: inbound | `Comms.lua` | line removed | test_guild | **red**: outside: inbound ignored |
| disabled module registers nothing | `Core.lua` | `if true then` | test_core | **red**: /dt set t enabled off: events unregistered, onDisable ran; off: its handler never runs; on again: registered and running (+1 more) |
| handler error count | `Core.lua` | line removed | test_core | **red**: and counted under the module's own error key; each failure counts; a verb failure is counted and re-raised |
| legacy move | `Core.lua` | `if false then` | test_core | **red**: an rc3 store is moved under legacy, the same table, untouched; the old-records line, once, on the first login; not again after a reload (+1 more) |
| protocol version | `Comms.lua` | line removed | test_comms | **red**: an unknown version is counted and ignored, not decoded; junk never raises, counted malformed; only GUILD and only our prefix are read |
| held line once per hold | `Comms.lua` | `if holding and DT.inCommand then` | test_comms | **red**: once per hold |
| held line for typed commands only | `Comms.lua` | `if holding and not heldSaid then` | test_comms | **red**: a send the addon makes itself: no held line; a typed command's message: the held line |
| realm normalise (AUD-06) | `Keys.lua` | `realm = realm` | test_keys | **red**: realmKey: spaces and hyphens go; realmKey(): GetRealmName when the normalised name is missing; keyOf: two-part name, realm normalised (+3 more) |
| full name for my key | `Keys.lua` | `return DT.fullName(str((try(UnitName, "player"))))` | test_keys | **red**: myKey: the full name (GetUnitName("player", true)), not UnitName |
| list filter | `UI.lua` | `out[#out + 1] = r` | test_ui | **red**: filter: case-insensitive; filter: as you type, letter by letter; filter: plain text, not a pattern (+5 more) |
| toast gate | `UI.lua` | line removed | test_ui | **red**: toast: off by default, nothing shown; toast: a setting that isn't a bool on is not on; toast: switched off, nothing (+1 more) |
| skin base fallback | `Skins.lua` | line removed | test_skins | **red**: loads and logs in under the default skin without an error |
| Who ask rate limit | `Who.lua` | `if true then` | test_who | **red**: /dt who asks once; not again within 30 s; again after 30 s |
| Who hello rate limit | `Who.lua` | line removed | test_who | **red**: the other answers the ask; again after 30 s; two asks within 10 s: one answer each |
| recruit officer check (A1) | `Recruit.lua` | `if false then` | test_recruit | **red**: A1: IsGuildOfficer false: refused, nothing posted; A1: nil or an error is not an officer either; A1: /dt recruit next still answers a non-officer, posts nothing (+1 more) |
| recruit cooldown | `Recruit.lua` | `if false then` | test_recruit | **red**: inside the cooldown: refused, minutes rounded up; rounded up: 779 s left is 13 min; /dt recruit next shows the line and the wait (+18 more) |
| recruit click-only post (R1, R-P1) | `Recruit.lua` | `if false then` | test_recruit | **red**: R1: post() called from anywhere but a typed command or the click refuses, silently; R1: ...from a timer too |
| recruit General only (A1) | `Recruit.lua` | `return true` | test_recruit | **red**: not in General: refused; a failed post: refused, cooldown and rotation unmoved; the chat function absent: nothing posted, nothing moved (+10 more) |
| death share opt-in (A2) | `Crypt.lua` | `if true then` | test_crypt | **red**: a normal death is not sent by default; so the guildie hears nothing and records nothing; share on: a normal death is sent (+3 more) |
| battleground rule | `Crypt.lua` | line removed | test_crypt | **red**: a battleground on a hardcore character counts as normal: sent as hc 0, not HC; an arena likewise |
| hardcore line once only | `Crypt.lua` | `if not me then return end` | test_crypt | **red**: A2: not after a /reload; A2: not on the second login; A2: when membership arrives, the line, once (+1 more) |
| prep officers-only acceptance | `Prep.lua` | `if false then` | test_prep | **red**: a list from a member (rank 4) is refused, counted; a sender not on the guild roster is refused; the roster's realm must match the key's (Lilbit High is on Realm 4) (+3 more) |
| prep verdict only (no names or counts) | `Prep.lua` | `short = tostring(math.min(#short, MAX_SHORT)), items = short[1] and short[1].e.name or nil })` | test_prep | **red**: a sharing member answers once with the verdict only: ok and how many short, no names or counts; the summary at 10 s |
| prep officers set the list | `Prep.lua` | `local item` | test_prep | **red**: a member can't set the list |
| migration runs once | `Migrate.lua` | line removed | test_migrate | **red**: runs once: nothing copied twice (no second set of legacy deaths, no entry brought back, no setting reset) |
| short->full merge: exactly one | `Migrate.lua` | `if hits >= 1 then map[k] = hit` | test_migrate | **red**: exactly one: two full keys starting with the short name: kept, counted; exactly one: the unmatched count |
| R-P5 collision rule | `Keys.lua` | `if false then` | test_keys | **red**: R-P5 collision: two shown entries sharing a full name both get (Realm); R-P5 collision: case and spacing don't hide one; R-P5: display among a shown set |
| bar: others unticked by default (R-P4) | `Bar.lua` | `b.on[name] = true` | test_bar | **red**: no LDB: the bar shows DT's own buttons, drawn natively; R-P4: other addons' objects are listed but unticked: the bar shows DT's own only; with LDB: ticked, the bar hosts other addons' launchers and data sources (+13 more) |
| bar: colour codes pass | `Bar.lua` | `if false then` | test_bar | **red**: colour codes: another addon's colour code is shown, not escaped; R-P4: /dt bar remove unticks it; R-P4 move: to position 1 (+4 more) |
| list rows fit their text | `UI.lua` | `local h = rh` | test_ui | **red**: rows: a long cell makes its row taller |
| settings content follows the scroll | `SettingsView.lua` | `if scroll > maxS then scroll = maxS end` | test_settingsview | **red**: defect 2: reopened, the content is back at the top (the first setting visible); defect 2: a search after a scroll starts at the top too |
| gank reads the target only on the verb (R1) | `Gank.lua` | line removed | test_gank | **red**: R1: DT.gank() called from anywhere but the typed verb reads nothing, logs nothing; R1: ...from a timer too |
| stash shares only unbound items (A4) | `Stash.lua` | `if true then` | test_stash | **red**: a bound item is never listed; the bank is read when opened: bank and bank bags, bound skipped; /dt stash alone: items across characters, bank read (+19 more) |
| stash shares only known-unbound (unknown not listed) | `Stash.lua` | `if bound ~= true then` | test_stash | **red**: A4 bags: isBound nil, C_Item.IsBound nil: skipped; A4 bags: isBound nil, C_Item.IsBound erroring: skipped; A4 bags: isBound nil, C_Item.IsBound not a boolean: skipped (+10 more) |
| stash opt-in: answering | `Stash.lua` | line removed | test_stash | **red**: a member with sharing off sends nothing and doesn't note the question |
| stash opt-in: scanning | `Stash.lua` | line removed | test_stash | **red**: store: DeadTiredDB.stash, sharing off, badStash 0, no characters; sharing off: no scan at login, no list; sharing off: no scan on bag or bank events (+1 more) |
| stash list deleted when sharing off | `Stash.lua` | `end` | test_stash | **red**: sharing off deletes the account's list; sharing off from the card (or /dt set) deletes it too |
| played shares only after /dt played (R-P2-1) | `Played.lua` | line removed | test_played | **red**: R-P2-1: a TIME_PLAYED_MSG nobody asked for sends nothing; R-P2-1: a plain /played is ignored: nothing recorded or sent; R-P2-1: the report 11 s after /dt played: nothing (+6 more) |
| played: one report per /dt played (R-P2-1) | `Played.lua` | line removed | test_played | **red**: R-P2-1: the request is used up by that report; R-P2-1: and that stale request is gone too |
| played: share gate on sending | `Played.lua` | line removed | test_played | **red**: sharing off: /dt played records and sends nothing; sharing on: /dt played records and sends lvl and hours to one decimal; the guildie stores it, printing nothing (+1 more) |
| played withdrawn when sharing off (F9) | `Played.lua` | line removed | test_played | **red**: /dt slowest share off: no play time sent after it, only the one withdrawal (F9); F9: share off sends one PLAYED with off=1 and nothing else; F9: a guildie online deletes B's entry on off=1 (+2 more) |
| played: the 30-day drop (F9) | `Played.lua` | `if type(e) ~= "table" then b[key] = nil end` | test_played | **red**: F9: past 30 days, /dt slowest drops it before showing; F9: at load, an entry over 30 days old is dropped; F9: at load, an entry with no time is dropped |
| played: no hook (a hooksecurefunc on /played inserted) | `Played.lua` | `local SEND_WINDOW = 60 ⏎ hooksecurefunc(SlashCmdList, "PLAYED", function() end)` | test_taint | **red**: taint scan: no hits in DeadTired/*.lua |
| events print only once switched on (R4) | `Events.lua` | line removed | test_events | **red**: R4: reminders off by default: nothing; /dt events remind off: nothing |
| logs never switch a log off: combat (only an OFF log armed) | `Logs.lua` | `local c = (combatOn ~= nil) and "/combatlog" or nil` | test_logs | **red**: combat on: only the chat log offered; F10: chat unknown, combat on: the line names /chatlog |
| logs never switch a log off: chat | `Logs.lua` | `local h = "/chatlog"` | test_logs | **red**: chat on: only the combat log offered; F10: nothing armable: no login dialog, the combat line instead; F10: chat unknown, combat on: the line names /chatlog (+2 more) |
| logs only read the state (no argument to LoggingCombat/LoggingChat) | `Logs.lua` | `if v == nil then v = clean((try(_G[legacyName], true))) end` | test_logs | **red**: scripted session: zero calls to the logging switches with an argument |
| logs one prompt at a time: login covers a dungeon (F12) | `Logs.lua` | `if false then` | test_logs | **red**: F12: walking into a dungeon with the login prompt up: no second prompt; F12: the visit counts as asked: no prompt later in the same visit; F12: a new visit asks as usual (+1 more) |
| logs one prompt at a time: instance hidden for login (F12) | `Logs.lua` | line removed | test_logs | **red**: F12: /dt logs now with the instance prompt up: only the login prompt; F12: combat over: the instance prompt hidden, then the login prompt shown |
| logs one prompt at a time: a click hides the others (F13) | `Logs.lua` | line removed | test_logs | **red**: F13: a click on the login prompt hides the instance prompt too; F13: ... so Log it can't be pressed after Combat log: one /combatlog run, the log on |
| logs never in a battleground or arena | `Logs.lua` | `if kind == "none" then return kind, nil end` | test_logs | **red**: battleground, arena and open world: never |
| logs never in the open world | `Logs.lua` | `if kind == "pvp" or kind == "arena" then return kind, nil end` | test_logs | **red**: open world at login: no dialog; raid, combat log off: the dialog; battleground, arena and open world: never (+16 more) |
| nudge re-armed on 'nudge on' (Port 1 defect 1) | `Recruit.lua` | line removed | test_recruit | **red**: Port 2: ...and it comes once at 15 min |
| nudge once per post | `Recruit.lua` | `if store().at ~= at then return end` | test_recruit | **red**: Port 2: on just after it, with the clock 1 s behind: no second nudge for that post |
| UISpecialFrames insert only (R-P2-2) | `UI.lua` | `table.insert(UISpecialFrames, 1, name)` | test_taint | **red**: taint scan: no hits in DeadTired/*.lua |
| UISpecialFrames: never a removal (R-P2-2) | `UI.lua` | `escaped[name] = true ⏎   table.remove(UISpecialFrames, 1) ⏎   return true` | test_taint | **red**: taint scan: no hits in DeadTired/*.lua; R-P2-2: only UI.lua reads UISpecialFrames (once to check it, once to insert) |
| UISpecialFrames: DT's own names, once each (R-P2-2) | `UI.lua` | `if type(name) ~= "string" then return false end` | test_ui | **red**: R-P2-2: a name that isn't DT's is refused; R-P2-2: inserting the same name twice is refused |
| Escape registration at creation (R-P2-2) | `UI.lua` | line removed | test_ui | **red**: R-P2-2: each DT viewport adds its own frame name once, at the end, at creation (Who, settings, graveyard, gank board, slowest board, events); R-P2-2: a name that isn't DT's is refused; R-P2-2: inserting the same name twice is refused (+1 more) |
| bar list shows names, not live text (Port 1 defect 2) | `Bar.lua` | `local l = DT.trim(plain(e.obj.label or e.obj.text or "")) or ""` | test_bar | **red**: Port 2: the list names each object, never its live text (BugSack, not 0; Recruit, not Recruit 8:23); Port 2: /dt bar list shows the names; Port 2: not by its text |
| graveyard date on one line (Port 1 defect 4) | `Crypt.lua` | `rows[#rows + 1] = { key = e.who, day = DT.safe(day, 20),` | test_crypt | **red**: newest first, date, name, level, zone, (HC) on hardcore; Port 2: the date column is short ("3 Nov"), the full date kept for the tooltip; Port 2: the date cell is one line at its width ("10 Nov" fits) |
| Port 2 migration runs once | `Migrate.lua` | line removed | test_migrate | **red**: Port 2 runs once: no second set of logs, no setting reset |

every guard proved; every file restored

## Task 6: the zip
`dist/DeadTired-0.3.0.zip`, **166517 bytes**, sha256
`8b30956b602366be815bdfe3c40f125bd51d5a0ecda3ff1a64883bd342a6bca8`; 49 entries (526241 bytes
unpacked), unzips to `Interface\AddOns\DeadTired\DeadTired.toc`; `diff -r` against the checkout
(tests excluded): **clean**. `run_all.sh`: ALL GREEN. Version `0.3.0` in the `.toc` and `DT.VERSION`.
Files: `DeadTired.toc`, `Config.lua`, `Core.lua`, `Keys.lua`, `Guild.lua`, `Comms.lua`,
`Settings.lua`, `Skins.lua`, `UI.lua`, `SettingsView.lua`, `Bar.lua`, `Debug.lua`, `Who.lua`,
`Alts.lua`, `Crypt.lua`, `RecruitLines.lua`, `Recruit.lua`, `Prep.lua`, `Session.lua`, **`Gank.lua`,
`Played.lua`, `Stash.lua`, `EventsList.lua`, `Events.lua`, `Logs.lua`**, `Migrate.lua`, and `Libs/`
(unchanged from 0.2.0: LibStub, CallbackHandler-1.0, AceComm-3.0 + ChatThrottleLib, LibSerialize,
LibDeflate, LibSharedMedia-3.0, each with its licence; `README.md`, `SHA256SUMS`). The 0.2.0 zips are
left in place.

## Task 7: release notes
`docs/RELEASE_0.3.0.md`, a draft for Tim to publish.

## Player-facing lines
**Carried from rc3, unchanged** (checked by script: every rc3 string literal of these files is in
the port, except the four below):
- Gank: `Target a player first. Preferably one who deserves it.`, `That's one of ours. Put the pen
  down.`, `The game won't say who that is right now. Try again out of combat.`, `Already noted.
  Grudges don't need two copies.`, `Noted: <name> (<Class> <lvl>), <zone>. The crypt remembers.`,
  `No grudges yet. Go and make some.`, `Only logs from guildies running the addon, seen while you
  were online.`, `Never heard of them. Yet.`, `more than one <x>: <names>. Add the realm.`, the
  per-log line `<date> <zone> (<Class> <lvl>), by <name>`; the board's row pieces (`(<Class> <lvl>)`,
  `x<n> by <n> guildie(s)`, `last <zone>`) as columns.
- Played: the award line, `No contenders. Everyone's either fast or shy.`, `not sharing your /played.
  Your entry is being withdrawn from guildies' boards.`, `sharing your /played is on|off. /dt slowest
  share on/off`, the usage line; the board's `<rate> h/level`, `level <n>` as columns.
- Stash: all of them (the share replies, the overview, `Asking the guild. Answers in 10 seconds.`,
  `One search at a time. The crypt echoes.`, `Nobody's got it. Or nobody's sharing.`, the closing
  line, the term refusal, `<holder>: <item> x<n>, ...` as rows).
- Events: the list lines (as rows), `Times are server time.`, `No events on the list.`, `Can't read
  the server clock.`, both reminders, the four `/dt events remind` replies and usage.
- Logs: all of them (both dialog titles, the status line, the button labels, the after-click lines,
  the two F10 lines, the `/dt logs` replies and usage).

**Changed rc3 lines** (R-P2-1 made them wrong; my edit, **for Tim to rule**, question 2):
- `sharing your /played. Type /played to put yourself on the board.` → `... Type /dt played to put
  yourself on the board.`
- `Only guildies running the addon who share their /played. Type /played to update yours.` → `...
  Type /dt played to update yours.`
- Dropped with the hook: `sharing your /played, but this client hides when you type it. Nothing will
  be sent.`

**New, not in the brief** (each needed by a ruled feature; Tim to keep, change or cut):
- Played: `The client won't say how long you've played. Nothing recorded.` (`/dt played` when
  `RequestTimePlayed` is absent or errors).
- Viewport titles: **Grudges** (gank board), **Glacial Progress** (slowest board), **Who has it**
  (stash answers), **Events**.
- Cards, with descriptions: **Share my play time** (played), **Share my stash**, **Reminders**
  (events), **Ask in dungeons and raids** and **Ask at login** (logs); module titles **Gank diary**,
  **Glacial Progress**, **Stash**, **Events**, **Logs**.
- Bar list labels: `Dead Tired`, `Who`, `Recruit`, `Session` (the module titles).
- The verb `/dt played` (from the brief) in `/dt help`.

## Questions for Tim
1. **The nudge after a `/reload`.** The Port 1 walk's lost nudge was most likely the `/reload` at
   18:19-18:23, not the off/on (see Task 2). Off/on now re-arms it, reload or not, so H4 passes as
   written. A plain `/reload` with no toggle still drops it: the ruling says "after a post this
   session". Should a reload (same login) re-arm it from the saved post time? A two-line change.
2. **The two `/played` lines** above: keep my `/dt played` wording, or give the lines.
3. **`/dt played` with sharing off** prints nothing of DT's (the client prints its own played lines).
   Want a hint (`Sharing's off. /dt slowest share on`)?
4. **No module switches** for the five ported modules (each keeps its own opt-in/off); say if you
   want the per-module `On` card on them, as Rest in Pieces and Raid prep have.
5. **Target realm on Forever.** The enemy's realm comes only from a `-Realm` suffix on
   `GetUnitName("target", true)`. If Forever never adds one for a cross-realm Alliance player, they
   are filed under our realm (same as rc3's "no realm means ours"). H6 with a cross-realm target and
   `/dt debug names` would settle it.
6. **The grab-hand cursor path** (`Interface\CURSOR\openhand`) is the classic client's file; if H3
   shows the normal arrow, the client lacks it and the drag still works (the brief allows skipping it).
7. **Holder names up to 48 bytes** in stash answers (rc3: 24); any objection.
8. **`FEATURES.md`** still says viewports are not closed by Escape (the shell table); R-P2-2
   supersedes it. I left the doc alone (not this round's deliverable).

## What H-checks need from Tim
H1-H10 and the carried Port 1 checks as written. For H6, a guildie on 0.3.0 sees the log on their
`/dt ganks` board (receipt is silent: nothing prints). For H7, `/dt played` prints the client's own
played lines; `/dt slowest` then names you and opens the board. For H8, the guildie's answer opens
the **Who has it** window about 10 s after asking. For H4, either order of off/on works; a `/reload`
alone still drops a pending nudge (question 1).
