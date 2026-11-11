# Cowork report: DEAD TIRED framework (0.2.0-fw1)

**Branch: `claude/hopeful-thompson-4rpsrp`, not `card/dt_framework`.** This cloud session can push only
to its own branch (CLAUDE.md, ruled 2026-11-11). It is rebased on `main` `61df7d9` (the amended brief).

Brief: `docs/COWORK_BRIEF_dt_framework.md`, amended 2026-11-11 (LibDataBroker borrowed, LibDBIcon
dropped). The first run stopped at Task 2 on LibDataBroker's licence. This run resumed from Task 2
and finished the round. No stop condition was hit. Walk-sheet: `docs/UAT_dt_framework.md` (not
ticked; the [H] walk is Tim's).

**Result: `sh DeadTired/tests/run_all.sh` is ALL GREEN: 12 suites, 320 checks, libraries unmodified.
All 27 guards proved (the 11 Task 11 names plus 16 more marked in the code). `dist/DeadTired-0.2.0-fw1.zip`
(111,809 bytes) unzips to a clean `diff -r` against the branch.**

## Task 1: baseline (first run; finding quoted)

First run, 2026-11-10 (commit `11f162d` on this branch):

> `release/0.1.0-rc3` (`6754f20`), `DeadTired/Core.lua:303-306`:
> ```lua
> SLASH_DEADTIRED1 = "/dt"
> SLASH_DEADTIRED2 = "/deadtired"
> SlashCmdList = SlashCmdList or {}          -- line 305
> SlashCmdList["DEADTIRED"] = function(msg) return DT.dispatch(msg) end
> ```
> `SlashCmdList` always exists when an addon loads, so line 305 is in effect `SlashCmdList = SlashCmdList`:
> it writes Blizzard's global from addon code. The value doesn't change, but the variable is now
> tainted. Every secure Blizzard path that reads `SlashCmdList` afterwards (the chat edit box's
> slash parsing, which runs `/run` and `/invite`) runs tainted, and protected actions inside it fail.
> The allow-scripts confirmation for `/run` is one of them. **Confirmed.**
> Also: rc3 `Played.lua:66-68` hooks `/played` with `hooksecurefunc` (by design that hook doesn't
> taint; the rebuild has no hooks at all), and `reference/wizardry/Forever/Core.lua` carries the
> same `SlashCmdList = SlashCmdList or {}` line, so WizardryLedger taints `/run` by itself (now in the
> walk-sheet's H5 note).

`lua5.1` 5.1.5 was installed with apt in the first run. This run used the `dead-tired-addon`
environment, which can reach WowAce.

## Task 2: libraries (G1)

Vendored unmodified into `DeadTired/Libs/<Lib>/`, each with its licence file. Each has a line in
`Libs/README.md`. `Libs/SHA256SUMS` holds every file's hash, and `run_all.sh` checks it
(`sha256sum -c`).

| Library | Version | Source | Licence |
|---|---|---|---|
| LibStub | minor 2 | `github.com/WoWUIDev/Ace3` @ `ac3d122` | Public domain (file header) + Ace3 `LICENSE.txt` |
| CallbackHandler-1.0 | minor 8 | Ace3 @ `ac3d122` | Ace3 BSD-style |
| ChatThrottleLib | v32 | Ace3 @ `ac3d122` (`AceComm-3.0/ChatThrottleLib.lua`) | Public domain (file header) |
| AceComm-3.0 | minor 14 | Ace3 @ `ac3d122` | Ace3 BSD-style |
| LibSerialize | v1.2.3 (minor 7), `aa6e50d` | `github.com/rossnichols/LibSerialize` | MIT |
| LibDeflate | 1.0.2-release (minor 3), `6831edc` | `github.com/SafeteeWoW/LibDeflate` | zlib |
| LibSharedMedia-3.0 | r186 (minor 12000005, 9 Nov 2026) | `repos.wowace.com/wow/libsharedmedia-3-0/trunk` | LGPL v2.1 (file header); `LGPL-2.1.txt` is the FSF text (upstream ships none) |

These are the versions the first run recorded. Ace3 `ac3d122` is 21 commits past `Release-r1403`, and
the four Ace3 files are byte-identical at both (`git diff --stat` empty). Only the `.lua` files ship.

- **LibDataBroker-1.1: not vendored** (borrowed). **LibDBIcon-1.0: not vendored** (not used).
  `test_bar` checks that no file in `DeadTired/` (outside `tests/`) is named after either one or
  creates either one.
- **ChatThrottleLib's hooks.** At load it places `hooksecurefunc` hooks on
  `C_ChatInfo.SendChatMessage`, `SendAddonMessage`, `SendAddonMessageLogged` and
  `C_BattleNet.SendGameData`, to measure traffic it doesn't send. That is library code, outside the
  brief's scan of `DeadTired/*.lua`. It is ChatThrottleLib's normal behaviour, already present when
  any other Ace addon is loaded, and a copy of v32 or newer loaded by another addon makes DT's copy
  do nothing. Recorded here and in `Libs/README.md` so it is a known fact, not a surprise. DT's own
  code has no hooks.
- **LibSharedMedia r186 calls `C_UIFileAsset.IsKnownFile` unguarded** at load. It is in the beta
  SPEC (`C_UIFileAsset`: GetFileID, IsKnownFile, IsLooseFile). If the live client lacked it, the
  library would error at load (H1's BugSack check would show it).

## The pieces, with their checks

| Piece | Files | Suite: checks | What the checks cover |
|---|---|---|---|
| Module core, router, gate, welcome (G3) | `Core.lua`, `Guild.lua`, `Settings.lua` | core 37, guild 20 | Registry in `.toc` order; own frame per module; help built from the registry; longest verb wins, args keep case; optional switch saved; a module saved off registers no events, and toggling registers/unregisters; init and handler failures counted under the module key and re-raised; a failing init doesn't stop later modules; outside the guild: no print, no send, no inbound, no bar/viewport/toast, `/dt` silent, `DT.out` silent; guild info arriving late; welcome once per login (reload counts), toggleable; store schema 3; rc3 store moved under `legacy` (same table, untouched), old-records line once; DT writes only DT globals; `SlashCmdList` never reassigned |
| Keys (G4) | `Keys.lua` | keys 21 | Realm normalised (AUD-06); own realm from `GetNormalizedRealmName` or `GetRealmName`; two-part names; spacing tidied; `-Realm` dropped from a name; `myKey` from `GetUnitName("player", true)`, falling back to `UnitName`; nil while Unknown or secret; display: name only on own realm (any case), `Name (Realm)` otherwise, the realm's own spelling once a HELLO has given it; UI escapes made safe; `sameKey` ignores case and spacing |
| Comms (G5) | `Comms.lua` | comms 46 | On the real AceComm + ChatThrottleLib: end to end across connected realms, sender with `-Realm`, without it (Tim's rc3 case) and same-realm; payload key accepted (case-insensitive), mismatch counted and kept (last 10), short name ≠ full name; protocol version up front, unknown counted and not decoded; rc3 messages and junk counted malformed, never raise; GUILD and our prefix only; chunking ≤255 and reassembly; R-1: the restricted flag recorded, never gates, lockdown holds, rechecked every 5 s; held line once per hold, typed commands only; AUD-10: 3 tries ≥1 s apart then dropped and counted; refused-then-sent delivered once; a throttle result kept by ChatThrottleLib (not a DT refusal); a lockdown refusal held, not a try; a refused chunk resends the whole message; raw senders capped at 50; queue cap 50 |
| Settings as cards (G6) | `Core.lua` (registry), `Settings.lua`, `SettingsView.lua` | settings 33, settingsview 17 | Every declared setting typed-reachable or carrying `noVerb`; registration refuses one with neither, a blank `noVerb`, or no plain words; bool/number/choice/string parse and validate; position refused by typing, with where it lives; saved and surviving a reload; `/dt get`; the view builds a row per setting with its `/dt` line or "Not typed: <where>"; a change in the view shows in `/dt get` and the reverse; search; Settings → AddOns page registered; compartment function; outside the guild nothing opens |
| Viewport, skins, list, toasts (G7) | `UI.lua`, `Skins.lua` | ui 32, skins 22 | List: case-insensitive, as you type, plain (not a pattern), trimmed; view scrolls and resets on a new query; viewport hidden at start, close button, drag saves the place, restored after `/reload`, a broken place ignored, not in `UISpecialFrames`, no secure templates; toast only while its bool is on, gone after 4 s, `/dt toast test`, none outside the guild; two skins resolve, base fallback, Morpheus vs Friz through LibSharedMedia, raw path behind a missing key, `/dt skin` repaints every frame, a failing painter counted |
| Launcher bar + addon detection (G8) | `Bar.lua`, `Core.lua` (`DT.addonLoaded`) | bar 40 | Without LDB: DT's own buttons, nothing errors, LDB never created; with a stand-in LDB loaded first: DT's objects registered there, other launchers and data sources hosted, other types skipped, no duplicates, DT text changes reach LDB, later objects join, third-party text changes redraw, clicks pass the mouse button; LDB arriving after DT; stand-back for Titan, ChocolateBar, Bazooka; not for ordinary addons; `/dt bar on|off|auto`; intro once only (not while standing back, not after reload, not on re-show); drag and keep; outside the guild no bar; no LibDataBroker/LibDBIcon in `DeadTired/` |
| Taint guard (G9) | `tests/taint_scan.lua` | taint 16 | Scanner reads `luac5.1 -l` bytecode (comments and strings can't fool it). Proved on a 19-line sample: flags exactly lines 1, 4, 5, 6, 7, 10, 11, 12, 13, 16 (global writes, `_G.X`, `ChatFrame1.x`, `SlashCmdList.PLAYED`, `hooksecurefunc`, `rawset`, Set*/Show/Hide on Blizzard frames, also through a local and inside a function). Lets through `SlashCmdList["DEADTIRED"]`, `SLASH_DEADTIRED3`, `DeadTiredDB`, reads, our own frames, `DEFAULT_CHAT_FRAME:AddMessage`. **Green on all 12 DT files with no false positives.** Red on a copy of `Core.lua` with rc3's line inserted |
| Who (G10) | `Who.lua` | who 26 | HELLO both ways across realms; each lists the other once with realm and version; `DT: 1 online`; no reply storm; self never listed (from the saved list, in another case, heard directly, or as the GUILD echo); `/dt who` asks once per 30 s and opens the list; answers at most once per 10 s; "seen before" after a reload; list searchable and says only DT runners show; `who.hello off` sends no hello and no answer but still hears; `who` off: no events, nothing sent or heard, `/dt who` says so; switched on, it says hello |
| Diagnostics | `Debug.lua` | debug 10 | `/dt debug names` (player and target: `UnitName`, `UnitFullName`, `GetUnitName(unit, true)`; `GetRealmName`, `GetNormalizedRealmName`, the key); no target gives nil; secrets not printed; `/dt debug senders`; `/dt debug errors` |

Total: **320 checks in 12 suites**, plus the library hash check. `run_all.sh` fails on any
`DeadTired/<File>.lua` without a `tests/test_<file>.lua`.

### How it hangs together (for the port round)
- `DT.module{ id, title, optional, settings, verbs, events, init, onEnable, onDisable, ldb }`.
  One loader frame runs every `init` at DT's `ADDON_LOADED`, then registers each module's events
  if its switch is on. `DT.apply(id)` switches them live.
- Settings registry: `DT.get` / `DT.set(id, key, raw, fromTyping)` / `DT.parse`. The `setting`
  signal tells the views.
- Signals: `member`, `greeted` (after the welcome, once per login), `loaded`, `setting`.
- Comms: `DT.send(KIND, table)` and `DT.on(KIND, fn(fromKey, data, rawSender))`. The wire is
  `"2:" .. EncodeForWoWAddonChannel(CompressDeflate(Serialize{k, f, d}))`.
- UI: `DT.viewport{}`, `DT.listModel()` + `DT.list()`, `DT.toast(id, key, text)`, `DT.tooltip()`,
  `DT.skin(painter)`, `DT.object(name, ldbShaped)` / `DT.update(name, field, value)`.

### Copied from rc3 and `reference/` (read only; nothing there edited)
- From Wizardry `Forever/Core.lua` (via rc3): `try`, `clean`, `secret` and `stamp`, verbatim. The
  module-wiring idea (own frame, error key, failures re-raised) was reworked into one loader.
- From rc3 `Core.lua`: `after`, `safe`, the `DT.inCommand` flag, the longest-prefix router idea, the
  guild gate (`Guild.lua`), the welcome wording and pattern.
- From rc3 `Comms.lua`: R-1 and the flag recording, the held line and its once-per-hold rule, the
  AUD-10 counters (re-built on AceComm's callback), the queue cap.
- From rc3 `tests/harness.lua`: the world, client, reload and fire shape, with frames, OnUpdate,
  libraries, surnames and sender shapes added. `tools/package.sh` is reworked from rc3's.
- Not copied: rc3's wire format, chunking, token bucket, the roster and every card.

## Guard proofs (G11)

`lua5.1 tools/guard_proofs.lua` makes each change once, runs the suite, records the checks that went
red, restores the file and confirms it byte-identical. The first 11 rows are Task 11's list.

| Guard | File | Change | Suite | Went red |
|---|---|---|---|---|
| guild gate | `Guild.lua` | `return want ~= nil` | test_guild | **red**: another guild is not the guild; no guild is not the guild; outside: login prints nothing (no welcome, no bar intro) (+8 more) |
| lockdown hold (R-1) | `Comms.lua` | `if false then` | test_comms | **red**: in lockdown: held, nothing sent; a hold is counted; a typed command's message: the held line (+4 more) |
| AUD-10 success test | `Comms.lua` | `if false then item.failed = true end` | test_comms | **red**: refused every time: tried 3 times, then dropped and counted; and not tried again; refused once, then sent: delivered once (+3 more) |
| 3-refusal limit (AUD-10) | `Comms.lua` | `if false then` | test_comms | **red**: refused every time: tried 3 times, then dropped and counted; and not tried again |
| payload-key name match | `Comms.lua` | `return true` | test_comms | **red**: a payload key naming someone else is not taken; the mismatch is counted and kept, not guessed; a short name is not the full name (+2 more) |
| self-exclusion in Who | `Who.lua` | line removed | test_who | **red**: self in the saved list is never shown; own GUILD echo: not listed |
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
| realm normalise (AUD-06) | `Keys.lua` | `realm = realm` | test_keys | **red**: realmKey: spaces and hyphens go; realmKey(): GetRealmName when the normalised name is missing; keyOf: two-part name, realm normalised (+2 more) |
| full name for my key | `Keys.lua` | `return DT.fullName(str((try(UnitName, "player"))))` | test_keys | **red**: myKey: the full name (GetUnitName("player", true)), not UnitName |
| list filter | `UI.lua` | `out[#out + 1] = r` | test_ui | **red**: filter: case-insensitive; filter: as you type, letter by letter; filter: plain text, not a pattern (+5 more) |
| toast gate | `UI.lua` | line removed | test_ui | **red**: toast: off by default, nothing shown; toast: a setting that isn't a bool on is not on; toast: switched off, nothing (+1 more) |
| skin base fallback | `Skins.lua` | line removed | test_skins | **red**: loads and logs in under the default skin without an error |
| Who ask rate limit | `Who.lua` | `if true then` | test_who | **red**: /dt who asks once; not again within 30 s; again after 30 s |
| Who hello rate limit | `Who.lua` | line removed | test_who | **red**: the other answers the ask; again after 30 s; two asks within 10 s: one answer each |

every guard proved; every file restored

**Tests strengthened (test files only, as CLAUDE.md allows).** On the first proof run three
removals turned no named check red:
- **`DT.out` gate:** every caller of `DT.out` is also gated, so removing it changed nothing visible.
  `test_guild` gained `outside: DT.out itself prints nothing`.
- **Borrow-only LibDataBroker and skin base fallback:** each removal crashed the client at load, so
  the suite died before a named check. `test_bar` and `test_skins` now load under `pcall` and check
  `loads and logs in ... without an error`.

```diff
--- test_guild.lua
   check("outside: a /dt set does nothing either", out:db().settings.guild == nil)
+  out.printed = {}
+  check("outside: DT.out itself prints nothing", out.DT.out("Rest in Pieces") == false and #out.printed == 0)
--- test_bar.lua
-  local c = w:client({ guild = G })
-  local okLogin, errLogin = pcall(c.login, c)
-  check("no LDB: login runs without an error", okLogin)
-  if not okLogin then print("  " .. tostring(errLogin)) end
+  local c
+  local okLogin, errLogin = pcall(function() c = w:client({ guild = G }); c:login() end)
+  check("no LDB: loads and logs in without an error", okLogin)
+  if not okLogin then print("  " .. tostring(errLogin)); H.finish("bar") end
--- test_skins.lua
-local c = w:client({ guild = G })
-c:login()
+local c
+local okLoad, errLoad = pcall(function() c = w:client({ guild = G }); c:login() end)
+check("loads and logs in under the default skin without an error", okLoad)
+if not okLoad then print("  " .. tostring(errLoad)); H.finish("skins") end
```
No addon code changed for these. All 27 then proved (table above).

## Package (G12)

`sh tools/package.sh` builds **`dist/DeadTired-0.2.0-fw1.zip`, 111,809 bytes**. It unzips the zip
again and `diff -r`s it against `DeadTired/` (tests excluded): **clean**. Files:

```
DeadTired/DeadTired.toc  Config.lua  Core.lua  Keys.lua  Guild.lua  Comms.lua  Settings.lua  Skins.lua
UI.lua  SettingsView.lua  Bar.lua  Debug.lua  Who.lua
Libs/README.md  Libs/SHA256SUMS
Libs/LibStub/{LibStub.lua, LICENSE.txt}
Libs/CallbackHandler-1.0/{CallbackHandler-1.0.lua, LICENSE.txt}
Libs/AceComm-3.0/{ChatThrottleLib.lua, AceComm-3.0.lua, LICENSE.txt}
Libs/LibSerialize/{LibSerialize.lua, LICENSE}
Libs/LibDeflate/{LibDeflate.lua, LICENSE.txt}
Libs/LibSharedMedia-3.0/{LibSharedMedia-3.0.lua, LGPL-2.1.txt}
```
`.toc`: `## Interface: 16001`, `## Version: 0.2.0-fw1`, `## SavedVariables: DeadTiredDB`,
`## IconTexture`, `## AddonCompartmentFunc: DeadTired_OnAddonCompartmentClick`, libraries first.
DT's own MIT `LICENSE` sits at the repo root and isn't in the zip; publishing is out of scope.

## Every player-facing line added

**From the brief (proposed wording, Tim rules at H1/H2):**
- `DeadTired's bar has risen. /dt bar off to bury it.` (first time the bar shows, ever)
- `Your old crypt records are kept for the move.` (once, if an rc3 store was moved)
- `The dead are gagged for this fight. Your message goes when it's over.` (ruled 9 Nov)
- `Rest in Pieces, <name>. The crypt's open. /dt for the rest.` (rc3's welcome)

**Answers to what was typed** (data, no new prose):
- `/dt help` and unknown verbs: `Dead Tired 0.2.0-fw1: /dt bar on|off|auto | debug errors | debug names | debug senders | get <module> [key] | help | set <module> <key> <value> | settings | skin forever|deadtired | toast test | who`
- `/dt set` / `/dt get`:
  - `<module>.<key> = <value>`
  - `/dt set <module> <key> <value>. Modules: ...` and `/dt get <module> [key]. Modules: ...`
  - `/dt set: <reason>` and `/dt get: <reason>`. The reasons: `no module called x`,
    `no setting x.y`, `expects on or off`, `expects a number from a to b`, `expects a number`,
    `expects one of: ...`, `expects text`, `expects at most n characters`,
    `can't be typed: <noVerb>`.
- `/dt bar`: `bar.mode = <mode>`, and `bar.mode = <mode>. /dt bar on|off|auto` for a word it doesn't know.
- `/dt who` while Who is off: `who.enabled = off`.
- `/dt debug names | senders | errors`: the values, labelled with the function names (see `Debug.lua`).

**In windows** (no chat):
- Titles: `Dead Tired settings`, `Who runs Dead Tired`.
- Who window note, and its tooltip: `Only guildies running Dead Tired show here.`
- Bar: the `Dead Tired` button, whose tooltip reads `Dead Tired` and `/dt help`; Who's object reads `DT: <n> online`.
- Toast test: `Dead Tired toasts look like this.`
- Settings page in the game's AddOns list: `Dead Tired`, and the button `Open Dead Tired settings`.
- Settings rows: each setting's label and description, plus `/dt set <m> <k> <value>` (and
  `or /dt <verb>`) or `Not typed: <where>`. The settings, in plain words:
  - **guild.welcome:** "One line in chat when you log in or reload. Nothing else is printed unless you ask."
  - **core.skin:** "How every Dead Tired window and the bar look: Dead Tired (the guild's) or Forever (the game's stone and metal)."
  - **core.windows** (`noVerb`: drag a window by its title to move it): "Each Dead Tired window stays where you drag it, through reloads."
  - **bar.mode:** "The Dead Tired bar: Dead Tired's buttons, and other addons' when their library is loaded. Auto hides it while Titan Panel or another bar addon is loaded."
  - **bar.place** (`noVerb`: drag the bar to move it): "Where the bar sits. Kept through reloads."
  - **who.enabled:** "Who in the guild runs Dead Tired. Off, Dead Tired neither says hello nor answers."
  - **who.hello:** "When you log in, and when a guildie asks, tells guildies running Dead Tired that you run it too. Shares your name, realm and Dead Tired version."

## Decisions made in the build (for Tim to overrule)
1. **Default skin is `deadtired`.** The brief didn't say. `/dt skin forever` switches.
2. **`/dt bar auto`** joins `on|off`. `auto` (the default) is the stand-back rule; `on` forces the
   bar to show. The stand-back list is in `Config.lua` (`DISPLAY_ADDONS`: Titan, ChocolateBar,
   Bazooka, ButtonBin, Fortress, DockingStation, StatBlockCore, NinjaPanel, Broker2FuBar,
   Carbonite). "Any that registers as one" is met by that list only. DT doesn't read other
   libraries' internals to guess.
3. **"DT: n online" counts guildies heard from this session.** The addon has no logout signal from
   others, so someone who logged off stays counted until your next login or reload.
4. **AUD-10 counts tries per message, 3 tries in all** (as rc3 and the 9 Nov ruling: "3 tries").
   ChatThrottleLib keeps a chunk refused for throttling (result 3) and retries it itself; DT's
   count covers every other refusal. A refusal during lockdown is held and doesn't count as a try.
5. **Outside the guild, `/dt` prints nothing** (rc3 said "only stirs inside <DEAD TIRED>"). The
   brief allows no new lines, and the house rule is "says nothing".
6. **Who answers are rate-limited per answerer (10 s).** A guildie who said hello within the last
   10 s doesn't answer again.
7. Viewport windows don't reopen after `/reload`: only their place is kept.

## Not proved offline (for the walk)
Layout, fonts and textures are built under stubs: the tests check the models and the calls, not
how the frames look. H2-H4 are where frame sizes, overlaps (the Who note sits close to the last
row), the Dead Tired palette and the Settings page get seen. The cross-realm sender shape is
unknown until H7. Comms takes the sender with or without `-Realm`.
