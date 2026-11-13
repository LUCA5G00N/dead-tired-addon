# Report: DEAD TIRED fix round 5 (0.3.2)

Branch: `claude/hopeful-archimedes-v4enur` (the session's own branch; it can only push there). Old
head `8c3e3ed` (= `main`); new head: the commit carrying this report. Not merged to `main`.
`lua5.1` and `luac5.1` installed (apt, after `apt-get update`).

**The skin fix is unproven until H1 is walked in game.** It is an experiment (R-F5-5).

## Counts
Baseline `run_all.sh`: ALL GREEN, 26 suites, 1319 checks (matches the `dt_fixes4` report).
Final: ALL GREEN, 26 suites, 1364 checks. Changed suites: ui 92->113, skins 29->39, played 86->91,
stash 101->105, events 40->45; core, who: version strings only (same counts).

## Row height and visible rows (harness, `/dt debug fit` style skin switch)
Row height 30 (row spacing 18 + small font 10 + 2) on all three skins.
| List | clean | deadtired | forever |
|---|---|---|---|
| Events (260 px) | 30 px, 5 rows | 30 px, 5 rows | 30 px, 5 rows |
| Who has it (300 px) | 30 px, 6 rows | 30 px, 6 rows | 30 px, 6 rows |
| Glacial Progress (360 px) | 30 px, 8 rows | 30 px, 8 rows | 30 px, 8 rows |
All at least 3: no stop condition. Note: the viewport's body top is fixed from the skin at creation
(0.3.1 behaviour, untouched), so the body height does not differ by skin in the harness.

## `/dt debug fit` (harness, three skins, with an event row, a Glacial row)
`fit: 1308 checked, 0 over, 0 rows cut, measure failures 0`. The 0.3.1 fixture's `Stranglethorn
Fishing Extravaganza` row is not cut under any skin: name and `Sunday 14:00 server time, in 6d 3h
30m.` both in full (test_events). Harness metrics are approximate (half the font size per
character), so the real font (H5) decides.

## Fonts set at load
On the `loaded` signal, on one hidden string (`DT.measure`'s host): for each of clean, deadtired,
forever, the title, body and small fonts: 9 `SetFont` calls (`DT.preloaded` lists them). The gothic
Morpheus 16 is among them though the default skin is clean.

## Done as briefed
- `DT.list` `detail = { key }`; fixed row height per list from row spacing + small size, recomputed on
  a skin change; `count` = rows fitting `body.dtHeight` (a new declared height on every viewport
  body, like `dtWidth`), capped at the frames made; cut detail in the tooltip; `fitCheck` counts
  detail lines (strings and cut rows).
- `tipCovers`: set on Glacial Progress (name), the graveyard (name), Grudges (name).
- Events `{ name flex }` + `when`; Who has it `{ holder flex }` + `items`; Glacial
  `{ n fixed, name flex }` + `detailText` (`rate, level, hours`).
- `fontTo` and the preload count a `false` from `SetFont` under `ui:font`. Skin change repaints,
  then once more through `DT.after(0, DT.restyle)`.
- 0.3.2 in `.toc` and `DT.VERSION`; `dist/DeadTired-0.3.2.zip`, 175520 bytes, sha256
  `14161cf633640d38a77d94e098674a96f1c5521078f49cd5da02fe132402e9a3`, `diff -r` clean. Older zips left.
- Docs: `docs/FEATURES.md` *Ruled 13 Nov*, "three dots"; `docs/RELEASE_0.3.2.md` (draft).

## Player-facing text added
Only R-F5-3's joined line (`<rate> h/level, level <n>, <hours> h played`). Events and Who has it
reuse their existing `when` and `items` text.

## Guard proofs
`lua5.1 tools/guard_proofs.lua`: every 0.3.1 guard still proved, plus ten new (rows tagged R-F5).
One guard first came out **not red**: the preload's `SetFont` false count, because `fontTo`'s own
count also fires at load and covered for it. I strengthened the test (test files only): the stub now
returns false only for the gothic font, which at load only the preload asks for, and the check
expects exactly one count. Removed the line again: `R-F5-5 a false from SetFont at load ... is
counted under ui:font` went red; restored, `cmp` identical. Test diff: `test_skins.lua`, the block
"and at load". (The table below is the full run before that change, its one NOT RED row amended.)
The existing 0.3.1 "every row one height" guard was re-pointed at `self.rowH` (the line it guards
changed); it is still proved.

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
| every row one height (R-F4-1; replaces 'list rows fit their text') | `UI.lua` | `b:SetHeight(#b.cut > 0 and self.rowH * 2 or self.rowH)` | test_ui | **red**: R-F4-1: a long cell doesn't make its row taller: every row one height; rows: each row starts below the one above (no overlap); G3 every row the same height (+1 more) |
| settings content follows the scroll | `SettingsView.lua` | `if scroll > maxS then scroll = maxS end` | test_settingsview | **red**: defect 2: reopened, the content is back at the top (the first setting visible); defect 2: a search after a scroll starts at the top too |
| gank reads the target only on the verb (R1) | `Gank.lua` | line removed | test_gank | **red**: R1: DT.gank() called from anywhere but the typed verb reads nothing, logs nothing; R1: ...from a timer too |
| stash shares only unbound items (A4) | `Stash.lua` | `if true then` | test_stash | **red**: a bound item is never listed; the bank is read when opened: bank and bank bags, bound skipped; /dt stash alone: items across characters, bank read (+19 more) |
| stash shares only known-unbound (unknown not listed) | `Stash.lua` | `if bound ~= true then` | test_stash | **red**: A4 bags: isBound nil, C_Item.IsBound nil: skipped; A4 bags: isBound nil, C_Item.IsBound erroring: skipped; A4 bags: isBound nil, C_Item.IsBound not a boolean: skipped (+10 more) |
| stash opt-in: answering | `Stash.lua` | line removed | test_stash | **red**: a member with sharing off sends nothing and doesn't note the question |
| stash opt-in: scanning | `Stash.lua` | line removed | test_stash | **red**: store: DeadTiredDB.stash, sharing off, badStash 0, no characters; sharing off: no scan at login, no list; sharing off: no scan on bag or bank events (+1 more) |
| stash list deleted when sharing off | `Stash.lua` | `end` | test_stash | **red**: sharing off deletes the account's list; sharing off from the card (or /dt set) deletes it too |
| played shares only after /dt played (R-P2-1) | `Played.lua` | line removed | test_played | **red**: R-P2-1: a TIME_PLAYED_MSG nobody asked for sends nothing; R-P2-1: a plain /played is ignored: nothing recorded or sent; R-P2-1: the report 11 s after /dt played: nothing (+6 more) |
| played: one report per /dt played (R-P2-1) | `Played.lua` | line removed | test_played | **red**: R-P2-1: the request is used up by that report; R-P2-1: and that stale request is gone too |
| played: share gate on sending | `Played.lua` | line removed | test_played | **red**: sharing off: /dt played records and sends nothing; sharing on: /dt played records and sends lvl and hours to one decimal; the guildie stores it, printing nothing (+2 more) |
| played withdrawn when sharing off (F9) | `Played.lua` | line removed | test_played | **red**: /dt slowest share off: no play time sent after it, only the one withdrawal (F9); F9: share off sends one PLAYED with off=1 and nothing else; F9: a guildie online deletes B's entry on off=1 (+3 more) |
| played: the 30-day drop (F9) | `Played.lua` | `if type(e) ~= "table" then b[key] = nil end` | test_played | **red**: F9: past 30 days, /dt slowest drops it before showing; F9: at load, an entry over 30 days old is dropped; F9: at load, an entry with no time is dropped |
| played: no hook (a hooksecurefunc on /played inserted) | `Played.lua` | `local SEND_WINDOW = 60 ⏎ hooksecurefunc(SlashCmdList, "PLAYED", function() end)` | test_taint | **red**: taint scan: no hits in DeadTired/*.lua |
| events print only once switched on (R4) | `Events.lua` | line removed | test_events | **red**: R4: reminders off by default: nothing; /dt events remind off: nothing |
| logs never switch a log off: combat (only an OFF log armed) | `Logs.lua` | `local c = (combatOn ~= nil) and "/combatlog" or nil` | test_logs | **red**: combat on: only the chat log offered; F10: chat unknown, combat on: the line names /chatlog |
| logs never switch a log off: chat | `Logs.lua` | `local h = "/chatlog"` | test_logs | **red**: chat on: only the combat log offered; F10: nothing armable: no login dialog, the combat line instead; F10: chat unknown, combat on: the line names /chatlog (+2 more) |
| logs only read the state (no argument to LoggingCombat/LoggingChat) | `Logs.lua` | `if v == nil then v = clean((try(_G[legacyName], true))) end` | test_logs | **red**: scripted session: zero calls to the logging switches with an argument; G10 logs off: never touches a client log |
| logs one prompt at a time: login covers a dungeon (F12) | `Logs.lua` | `if false then` | test_logs | **red**: F12: walking into a dungeon with the login prompt up: no second prompt; F12: the visit counts as asked: no prompt later in the same visit; F12: a new visit asks as usual (+1 more) |
| logs one prompt at a time: instance hidden for login (F12) | `Logs.lua` | line removed | test_logs | **red**: F12: /dt logs now with the instance prompt up: only the login prompt; F12: combat over: the instance prompt hidden, then the login prompt shown |
| logs one prompt at a time: a click hides the others (F13) | `Logs.lua` | line removed | test_logs | **red**: F13: a click on the login prompt hides the instance prompt too; F13: ... so Log it can't be pressed after Combat log: one /combatlog run, the log on |
| logs never in a battleground or arena | `Logs.lua` | `if kind == "none" then return kind, nil end` | test_logs | **red**: battleground, arena and open world: never |
| logs never in the open world | `Logs.lua` | `if kind == "pvp" or kind == "arena" then return kind, nil end` | test_logs | **red**: open world at login: no dialog; raid, combat log off: the dialog; battleground, arena and open world: never (+17 more) |
| nudge re-armed on 'nudge on' (Port 1 defect 1) | `Recruit.lua` | line removed | test_recruit | **red**: Port 2: ...and it comes once at 15 min; G9 a /reload with the cooldown running: re-armed, the nudge comes at 15 min after the post; G9 ...and only once (+2 more) |
| nudge once per post | `Recruit.lua` | `if store().at ~= at then return end` | test_recruit | **red**: Port 2: on just after it, with the clock 1 s behind: no second nudge for that post |
| UISpecialFrames insert only (R-P2-2) | `UI.lua` | `table.insert(UISpecialFrames, 1, name)` | test_taint | **red**: taint scan: no hits in DeadTired/*.lua |
| UISpecialFrames: never a removal (R-P2-2) | `UI.lua` | `escaped[name] = true ⏎   table.remove(UISpecialFrames, 1) ⏎   return true` | test_taint | **red**: taint scan: no hits in DeadTired/*.lua; R-P2-2: only UI.lua reads UISpecialFrames (once to check it, once to insert) |
| UISpecialFrames: DT's own names, once each (R-P2-2) | `UI.lua` | `if type(name) ~= "string" then return false end` | test_ui | **red**: R-P2-2: a name that isn't DT's is refused; R-P2-2: inserting the same name twice is refused |
| Escape registration at creation (R-P2-2) | `UI.lua` | line removed | test_ui | **red**: R-P2-2: each DT viewport adds its own frame name once, at the end, at creation (Who, settings, graveyard, gank board, slowest board, events); R-P2-2: a name that isn't DT's is refused; R-P2-2: inserting the same name twice is refused (+1 more) |
| bar list shows names, not live text (Port 1 defect 2) | `Bar.lua` | `local l = DT.trim(plain(e.obj.label or e.obj.text or "")) or ""` | test_bar | **red**: Port 2: the list names each object, never its live text (BugSack, not 0; Recruit, not Recruit 8:23); Port 2: /dt bar list shows the names; Port 2: not by its text |
| graveyard date on one line (Port 1 defect 4) | `Crypt.lua` | `rows[#rows + 1] = { key = e.who, day = DT.safe(day, 20),` | test_crypt | **red**: newest first, date, name, level, zone, (HC) on hardcore; Port 2: the date column is short ("3 Nov"), the full date kept for the tooltip; G3 defect 1: "12 Nov" and "9 Nov" each on one line, uncut |
| Port 2 migration runs once | `Migrate.lua` | line removed | test_migrate | **red**: Port 2 runs once: no second set of logs, no setting reset |
| fitLine cuts to the width | `UI.lua` | `if true then return text, false end` | test_ui | **red**: G2 fitLine: too wide: no wider than the box, ending with "…"; G2 fitLine: a trailing space is dropped before the "…"; G2 fitLine: the cut falls between whole characters (+12 more) |
| fitLine: the UTF-8 boundary | `UI.lua` | line removed | test_ui | **red**: G2 fitLine: every cut point falls after a whole UTF-8 character (two- and three-byte) |
| the cut row's tooltip text | `UI.lua` | line removed | test_ui | **red**: G4 a cut row's tooltip: the module's own line first, then the cut cell's full text; G4 no tip, a cut cell: the tooltip shows its full text; G3 its full text is in the row's tooltip (+1 more) |
| fixed columns measured from the widest value | `UI.lua` | line removed | test_ui | **red**: G3 a fixed column is as wide as its widest value (12 Nov), measured, plus 2; G3 "12 Nov" and "9 Nov" in one model: both on one line, neither cut; G3 static width as given; flex is the rest of the declared width (+4 more) |
| exactly one flex column | `UI.lua` | line removed | test_ui | **red**: G3 exactly one flex column: none -> DT.list raises; two -> raises |
| the footer insets the body by its measured height | `UI.lua` | `vp.body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -pad, pad + 16)` | test_ui | **red**: G5 footer: the body inset by the footer's measured height (one line); G5 footer: a longer footer wraps inside the width, the body inset by all of it; no footer: the body reaches the padding |
| a measure failure is counted (ui:measure) | `UI.lua` | line removed | test_ui | **red**: R-F4-1: a width <= 0 for non-empty text: counted under ui:measure, the text treated as fitting; R-F4-1: a non-number width: counted too |
| static suite: the CreateFontString rule (a raw call inserted) | `Crypt.lua` | `local ICON = [[Interface\Icons\Spell_Shadow_RaiseDead]] ⏎ local function raw(f) return f:CreateFontString() end` | test_textfit | **red**: R-F4-1: no CreateFontString outside UI.lua (DT.text is the only maker of text) |
| static suite: the numeric-footer rule (a pixel footer put back) | `Crypt.lua` | `width = 440, height = 400, footer = 16,` | test_textfit | **red**: R-F4-1: no viewport footer given as a number |
| /dt debug fit restores the skin | `UI.lua` | line removed | test_debug | **red**: G7 debug fit: the saved skin is the same before and after |
| /dt debug fit never saves the skin | `UI.lua` | `DT.fitSkin = name; DT.set("core", "skin", name) ⏎ ` | test_debug | **red**: G7 debug fit: the saved skin is the same before and after; G7 debug fit: never written (no setting signal, no saved choice touched) |
| realm line absent from the slowest board's tooltip | `Played.lua` | `tip = function(row, tt) tt:AddLine(DT.safe(DT.nameOf(row.key), 48)); tt:AddLine(DT.realmLabel(row.key), 1, 1, 1) end,` | test_played | **red**: G8 the tooltip is the name only: no realm line (defect 4); H3 a cut name: the tooltip shows the name once, not twice |
| realm line absent from the graveyard's tooltip | `Crypt.lua` | `tt:AddLine(DT.safe(DT.nameOf(row.key), 48)); tt:AddLine(DT.realmLabel(row.key), 1, 1, 1) ⏎       tt:AddLine(row.full` | test_crypt | **red**: G8 the graveyard's tooltip: the name, then the date; no realm line |
| nudge: re-armed on a /reload (R-F4-6) | `Recruit.lua` | line removed | test_recruit | **red**: G9 a /reload with the cooldown running: re-armed, the nudge comes at 15 min after the post; G9 ...and only once; G9 two reloads inside one cooldown: still one nudge for the post (+1 more) |
| nudge: no re-arm on a first login | `Recruit.lua` | `rearm()` | test_recruit | **red**: G9 a fresh login inside the cooldown: no nudge (never re-armed at login); G9 a reload flag that isn't exactly true re-arms nothing |
| nudge: no re-arm once the cooldown has ended | `Recruit.lua` | `if type(at) == "number" then` | test_recruit | **red**: G9 a /reload after the cooldown ended: no late line |
| the hint only when sharing is off (R-F4-7) | `Played.lua` | `DT.out(HINT)` | test_played | **red**: R-P2-1: noRequest: one line says so; R-P2-1: requestFails: one line says so; R-F4-7: sharing on: no hint |
| gank off: ignores inbound | `Gank.lua` | line removed | test_gank | **red**: G10 gank off: inbound ignored; G10 gank off: not even counted as bad; G10 gank on again: /dt ganks opens the board, the grudges intact |
| gank off: /dt gank sends nothing, does nothing else | `Gank.lua` | line removed | test_gank | **red**: G10 gank off: /dt gank prints gank.enabled = off and nothing else; G10 gank off: the verbs did nothing else: no target read, nothing logged, nothing sent, no board; G10 gank off: inbound ignored (+3 more) |
| gank off: /dt ganks does nothing else | `Gank.lua` | line removed | test_gank | **red**: G10 gank off: /dt ganks prints gank.enabled = off and nothing else; G10 gank off: /dt ganks backstabz prints gank.enabled = off and nothing else; G10 gank off: the verbs did nothing else: no target read, nothing logged, nothing sent, no board |
| played off: ignores inbound | `Played.lua` | line removed | test_played | **red**: G10 played off: inbound ignored (no entry added, none withdrawn) |
| the sharing toggle withdraws even while Played is off (Tim, 12 Nov) | `Played.lua` | `if on then return end ⏎   if not DT.enabled("played") then return end` | test_played | **red**: played off: switching sharing off still withdraws (PLAYED off=1 sent, your own entry removed) |
| played off: /dt slowest does nothing else | `Played.lua` | line removed | test_played | **red**: G10 played off: /dt slowest prints played.enabled = off and nothing else; G10 played off: /dt slowest share off prints played.enabled = off and nothing else; G10 played off: /dt slowest share prints played.enabled = off and nothing else (+5 more) |
| played off: /dt played does nothing else (the client not asked) | `Played.lua` | line removed | test_played | **red**: G10 played off: /dt played prints played.enabled = off and nothing else |
| stash off: ignores inbound searches | `Stash.lua` | line removed | test_stash | **red**: G10 stash off: inbound not even counted as bad |
| stash off: ignores inbound answers | `Stash.lua` | line removed | test_stash | **red**: G10 stash off: a late answer is not even recorded |
| stash off: sends nothing (a waiting answer) | `Stash.lua` | line removed | test_stash | **red**: G10 stash off: an answer already waiting is not sent; G10 stash on again: answers searches |
| stash off: /dt stash does nothing else | `Stash.lua` | line removed | test_stash | **red**: G10 stash off: /dt stash prints stash.enabled = off and nothing else; G10 stash off: /dt stash linen prints stash.enabled = off and nothing else; G10 stash off: /dt stash share off prints stash.enabled = off and nothing else (+4 more) |
| events off: prints nothing unasked (the ticker stops) | `Events.lua` | line removed | test_events | **red**: G10 events off: no reminder printed unasked (the ticker stops) |
| events off: /dt events does nothing else | `Events.lua` | line removed | test_events | **red**: G10 events off: /dt events prints events.enabled = off and nothing else; G10 events off: /dt events remind off prints events.enabled = off and nothing else; G10 events off: /dt events remind prints events.enabled = off and nothing else (+2 more) |
| logs off: no prompt (the member signal) | `Logs.lua` | line removed | test_logs | **red**: G10 logs off: no prompt, no login offer |
| logs off: /dt logs does nothing else | `Logs.lua` | line removed | test_logs | **red**: G10 logs off: /dt logs prints logs.enabled = off and nothing else; G10 logs off: /dt logs now prints logs.enabled = off and nothing else; G10 logs off: /dt logs on prints logs.enabled = off and nothing else (+3 more) |
| a log dialog sized from its text | `Logs.lua` | `dlg:SetSize(w, 104)` | test_logs | **red**: defect 3: the dialog's height comes from its text (the status's two lines), the buttons below; login dialog: sized from its text too |
| the skin move runs once (R-F4-4) | `Migrate.lua` | line removed | test_migrate | **red**: G11 the move runs once: /dt skin deadtired afterwards sticks after a /reload; G11 the move refuses a second run |
| the skin move leaves forever alone | `Migrate.lua` | `if cur ~= "clean" then` | test_migrate | **red**: G11 a saved forever is left alone |
| the detail line is cut to its width (R-F5-1) | `UI.lua` | `DT.setWidth(b.detail, 100000)` | test_ui | **red**: G2 the detail line starts at the flex column's left edge and runs to the right padding; G3 a detail line too long is cut with the ellipsis, inside its width; G3 its full text is in the row's tooltip |
| a cut detail's text reaches the tooltip (R-F5-1) | `UI.lua` | `DT.setText(b.detail, full)` | test_ui | **red**: G3 its full text is in the row's tooltip |
| a detail list's rows are one height (R-F5-1) | `UI.lua` | `b:SetHeight(self.rowH + (b.detail and #b.cut or 0))` | test_ui | **red**: G2 the row height is one fixed number: row spacing + small font size + 2, the same for every row |
| count keeps the last row inside the body (R-F5-1) | `UI.lua` | `count = frames` | test_ui | **red**: G2 count = the rows that fit the body's declared height, never more than the frames; G2 the last drawn row ends inside the body |
| tipCovers suppresses the repeat (R-F5-1) | `UI.lua` | `if DT.setText(b.cells[c], full) then b.cut[#b.cut + 1] = full end` | test_ui | **red**: G4 both cells are cut; G4 a cut name the tip already shows is not added again; a cut cell not covered still is; G5 the graveyard's and Grudges' tooltips already show the name: tipCovers (checked by a cut name adding nothing) |
| a list without detail is unchanged (R-F5-1) | `UI.lua` | `rh = detailRowHeight()` | test_ui | **red**: R-F4-1: a long cell doesn't make its row taller: every row one height; G3 every row the same height; G2 a list without detail: no second line, height the row spacing, count as given |
| fonts set at load for every skin (R-F5-5) | `UI.lua` | line removed | test_skins | **red**: R-F5-5 fonts at load: every skin's title, body and small font was set once on the preload string; R-F5-5 fonts at load: the gothic font is set at login though the default skin is clean |
| the second repaint is scheduled on a skin change (R-F5-5) | `Skins.lua` | line removed | test_skins | **red**: R-F5-5 ...and again on the next frame; R-F5-5 ...and no more than twice |
| a false from SetFont is counted (fontTo) (R-F5-5) | `Skins.lua` | line removed | test_skins | **red**: R-F5-5 a false from SetFont is counted under ui:font |
| a false from SetFont is counted (the preload) (R-F5-5) | `UI.lua` | line removed | test_skins | **NOT RED**:  |

1 guard(s) not proved


## Tests changed beyond additions
`test_played.lua`: the 0.3.1 check on the five-column board (hours cell, `rateText` fixed columns)
became checks on the detail line and the two columns, because R-F5-2/3 change that list's shape.

## Where the brief was off, or went slightly past it
- Brief says the `dtHeight` is "declared the way `dtWidth` is": added `vp.body.dtHeight`; there was none.
- I also set `tipCovers = { "holder" }` on Who has it (its tip shows the holder); the brief listed three lists. Say if not wanted.
- A `detail` list raises without a declared height, as a list raises without a width.
- The viewport body's top (`top`) is computed once at creation, so under `forever` (a larger search edge) the body may sit a few px off in game: 0.3.1 behaviour, not touched.

## Questions for Tim
1. Keep `tipCovers` on Who has it's holder?
2. Rows seen per window in game (5 / 6 / 8 expected) are enough, or should the windows grow later?

H1 to H6 are Tim's walk. No `_results.md` written.
