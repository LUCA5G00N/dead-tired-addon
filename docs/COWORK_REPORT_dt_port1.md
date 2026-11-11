# Cowork report: DEAD TIRED Port 1 (cards 1 and 3, recruit; 0.2.0)

**Branch: `claude/serene-meitner-dvzd67`**, the session's own branch (this session can push only
there; `CLAUDE.md`, ruled 2026-11-11; the brief allows it). Not merged to `main`: Tim merges after
his walk. Brief: `docs/COWORK_BRIEF_dt_port1.md`; walk-sheet: `docs/UAT_dt_port1.md` (not ticked;
no `_results.md` written).

- **Old head:** `aa3bc80` (`main` at session start: the brief's `ce4b767` plus the merge of the
  brief itself, #11). **New head:** `5fea1e9` (the build), then this report's commit.
- **Outcome:** every deliverable built, R-P3 included (not the fallback). **19 suites, 690 checks,
  ALL GREEN** (baseline 12 suites, 320). **44 guards proved**, every file restored byte for byte.
  `dist/DeadTired-0.2.0.zip`, `diff -r` clean. No stop condition was hit.
- **Environment note:** `lua5.1` was not installed and the container's apt sources were plain
  HTTP, which the session's proxy doesn't carry. I switched the container's Ubuntu sources to
  HTTPS (same mirror) and installed the real `lua5.1` 5.1.5 (no other Lua substituted).
- **Read first:** the brief cites `FEATURES.md` sections (*Ruled 11 Nov (for Port 1)*, *Versions and
  releases*, the *Port rule*) that are **not on `main`**; they are on the unmerged branch
  `docs/release-plan` (`edf5b79`). I read them there; they match the brief's rulings.

## Task 1: baseline
`main`'s suites at `aa3bc80`: 12 suites, **320 checks, all green** (bar 40, comms 46, core 37,
debug 10, guild 20, keys 21, settings 33, settingsview 17, skins 22, ui 32, who 26, taint 16), libs
unmodified (SHA256SUMS).

## Counts, per suite

| Suite | Before | After | What's new |
|---|---:|---:|---|
| alts | | 28 | new: rc3's checks re-pointed to full-name keys, main in HELLO, own short key folded |
| bar | 40 | 69 | R-P4 (unticked default, tick, typed verbs, move model, drag, new at bottom, saved), colour codes |
| comms | 46 | 46 | |
| core | 37 | 37 | module list and version updated |
| crypt | | 94 | new: rc3's checks carried (store, verbs, own death, received, F6a, graveyard, nag, A2), viewport, R-P5 |
| debug | 10 | 10 | |
| guild | 20 | 20 | |
| keys | 21 | 27 | R-P5 display and collision rule (two old "Name (Realm)" checks rewritten to the ruling) |
| migrate | | 31 | new: Tim's legacy shape |
| prep | | 47 | new: R-P3 and rc3's roll call |
| recruit | | 83 | new: rc3's checks carried, R-P1, R-P2, click-only post |
| recruitlines | | 7 | new: the five lines byte-identical to `docs/RECRUIT_lines.md` |
| session | | 9 | new |
| settings | 33 | 33 | |
| settingsview | 17 | 28 | rows sized to text, first setting clear, the scroll fix |
| skins | 22 | 22 | |
| ui | 32 | 40 | row heights, empty line, body gap |
| who | 26 | 36 | R-P6, R-P5 in the list and tooltip, collision, empty state, row heights (old checks moved off the realm suffix) |
| taint | 16 | 23 | same checks; it scans the seven new files too |
| **Total** | **320** | **690** | |

## Task 2: framework fixes (the fw1 walk's defects 1-8)
| Defect | Fix | Proof |
|---|---|---|
| 1 Settings rows fixed at 52 px | Each row is measured: label, description wrapped at its width, hint, each at its width (`DT.textHeight`: the font string's own `GetStringHeight`, else an estimate); `DT.settingsRowHeight` adds them. Descriptions and hints word-wrap | settingsview: every row at least as tall as its text, none overlaps, a long one taller than a short one |
| 2 First setting under the search box | **Cause found:** a search or a reopen set the scroll counter back to 0 but left the content anchored where the last scroll had put it, i.e. above the body's top, under the search box (and the wheel couldn't get it back, the counter already being 0). `layout()` now always re-anchors the content at the scroll (`place()`), and the body starts a clear gap below the search box (`DT.bodyTop`), the first card 4 px below that | settingsview: scroll, reopen → content at 0; scroll, search → at 0. Guard proved |
| 3 Colour codes escaped on the bar | `DT.barText` for other addons' text: keeps `\|cAARRGGBB`, `\|r`, textures `\|T..\|t`, hyperlinks `\|H..\|h..\|h`; escapes every other `\|`; strips control bytes; closes an open colour. DT's own text still goes through `DT.safe` | bar: Prat's `\|cff8080ff3.0\|r` shown as is; other escapes doubled |
| 4 Who rows overlap | The list widget sizes each row to its tallest wrapped cell and stacks rows from that (`DT.rowHeight`) | ui and who: a long name makes a taller row; no row starts inside the one above |
| 5 Empty Who window | `Just you so far. The rest are still in their coffins.` when only you are listed | who |
| 6 You in Who (R-P6) | Your row first, `Stromham Hamson (you)`, exactly once; saved copies of your own key (any case/spacing) never listed | who; guard proved |
| 7 Choose the bar's addons (R-P4); DT info on the bar | Task 3; the `Session` object (Task 5) | |
| 8 Names without realm (R-P5) | `DT.display`/`DT.namer`: full name only; `(Realm)` only when two **shown** keys share a full name on different realms (case/spacing ignored); the realm in each row's tooltip (`DT.realmLabel`). Single lines (death notices) test the collision among every key DT knows | keys, who, crypt, alts; guard proved |

**Framework contracts changed, as the tasks ask:** `DT.display` (R-P5); the list widget's rows
(variable heights, `tip`, `empty`); `DT.viewport` gains `footer`; the settings registry gains a
`list` type (rows with tick / drag grip / remove, never `/dt set`, its verbs named in `noVerb`) and
an optional `validate`; `DT.object` defs may carry `visible` and `offByDefault`; `Who.lua` gains
`DT.helloField` (other modules add HELLO fields) and `DT.sayHello`; `DT.keySource` feeds the
collision rule. Nothing existing was removed; fw1's 320 checks still pass apart from the eight that
asserted the old realm suffix or version string, rewritten to the rulings (listed in the table).

## Task 3: the bar list (R-P4)
`DeadTiredDB.bar = { order, on }`. DT's own (Dead Tired, DT: n online, Recruit for officers) ticked
from the start; `Session` declared `offByDefault`; every other addon's object unticked, a newly seen
one at the bottom. The bar draws the ticked ones in order. Settings card **On the bar**: a tick box
and a drag grip (`=`) per row; a drop lands on the row under the cursor (`DT.dropIndex`, using the
client's `GetCursorPosition` and the rows' `GetBottom`). Typed: `/dt bar add|remove <name>`,
`/dt bar move <name> <n>`, `/dt bar list` (name or plain label, case-insensitive). Saved through
`/reload` (checked with the other addons recreating their objects in another order).

## Task 4: the ported modules
Copied from rc3 (`release/0.1.0-rc3`, read-only): the logic and every player-facing line of
`Alts.lua`, `Crypt.lua`, `Recruit.lua`, `RecruitLines.lua` (byte-identical; also brought rc3's
`docs/RECRUIT_lines.md` over unchanged, which its test reads) and `Prep.lua`; the guarded-read
pattern is the framework's (`DT.try/clean`, from `reference/wizardry/Forever/Core.lua` via fw1).
Each is a `DT.module` with its own frame and error key; every setting is a card with a typed path.

| Module | Ported from rc3 | What changed |
|---|---|---|
| **Alts** | `/dt main`, `/dt main clear`, `/dt alts [name]`, all ten lines; name typed with or without realm, either order | Full-name keys; the main travels in HELLO (`main` field); store `DeadTiredDB.alts`; R-P5 in the lines; **plus** at login this character's own rc3 short-name entry (exactly `RealmKey-UnitName`, only if marked as the account's own) folds into its full key (see *Questions*, 6) |
| **Crypt** | Death notices (R1), share opt-in (A2), hardcore once-per-character line, battleground rule, death window, F6a per-sender limit, field validation, cap 100, bedtime nag (6 h window, 3 nags, 30 min apart), every line | Settings `crypt.rip`, `crypt.share`, `crypt.bedtime` (validated HH:MM) and a module switch; **`/dt rip` now also opens the graveyard viewport**, and `/dt graveyard` opens it instead of printing 10 lines (searchable, newest first, `(HC)`, the closing line under it, rc3's empty line in it); one deaths list instead of per-guild |
| **Recruit** | Officers only (A1), General / `General - <zone>` by scan, 15 min per account, lockdown refusal, failed post moves nothing, the nudge once, every line | R-P1 button; R-P2 replies; `post()` refuses unless a typed command or the button's click runs it (counted `recruit.refusedUnasked`); setting `recruit.nudge`; store `DeadTiredDB.recruit` |
| **Prep** | rc3's own-bags check (bags only), `/dt prep list`, the roll call verbatim in what it shares (F6c, F8a, verdict only), every line | **R-P3 built**: officers' list (`add`/`remove`/`clear` + the settings card), PREPLIST shared, last writer wins by time, accepted only from an officer; `/dt prep check` is now the bag check, so the roll call moved to **`/dt prep roll`** (*Questions*, 3); settings `prep.share` and a switch; `PrepList.lua` (rc3's built-in list) not shipped |

**Recruit button (R-P1).** Text `Recruit`, or `Recruit m:ss` while the cooldown runs (a 1 s ticker
that only redraws, and stops at 0); left-click runs the same `post()` as `/dt recruit`, so the
officer, cooldown, lockdown and General checks are the same code; right-click opens its settings;
tooltip: `Recruit`, `Next up: line N of 5. Cooldown: ...`, then the line itself. Drawn and listed
only while `IsGuildOfficer()` is true (re-read on guild updates). Checked: 24 h of logins, zoning,
guild updates, roll calls and the ticker post nothing; `post()` from a timer posts nothing.

**Raid prep (R-P3) details.** `<item>` is an item ID, a shift-clicked link, or a name
`C_Item.GetItemInfoInstant` knows. A change is stamped `ver = time()` (bumped past the last) and
sent. A receiver takes a PREPLIST only when the sender's guild rank (global `GetGuildRosterInfo`,
guarded; the roster name's `-Realm`, when present, must match the key's realm) is at most
`Config.OFFICER_MAX_RANK` (set to **1**, see *Questions*, 1), and only if newer. Every HELLO carries
the list version (`pl`); an officer who hears an older one resends, at most once a minute. Members
never resend. Max 30 items, counts 1-1000.

## Task 5: Session
`Session` data object: text `Session h:mm` (redrawn each minute and on each death); tooltip `This
session` / `Time` / `Your deaths` / `New in the graveyard` (Crypt counts both). Left-click opens the
graveyard, right-click the bar's settings. Off the bar until ticked; sends and saves nothing.

## Task 6: the legacy migration (`Migrate.lua`)
Once per account (`DeadTiredDB.migrated.port1 = true`, with `at`, `mapped`, `merged`,
`unmatched`, later `refiled`). Copies (deep copies: **`legacy` is never written**) the roster and
mains (`alts`), the graveyard, `hcTold` and crypt settings (`rip`, `share`, `bedtime`), recruit
state (`recruitNext`, `recruitAt`, `recruitNudge`) and prep `share`. A setting already set in the new
store is not overwritten. Keys: realm normalised; a short key merges into a full key of the same
realm only when **exactly one** full key (legacy keys plus those already known, own key included)
starts with the short name plus a space; else kept and counted. Newest `seen` wins on a merge. A
non-own legacy entry is marked `fromLegacy`; a HELLO from the same full name on another realm moves
it there (roster, deaths, `hcTold`, mains). Nothing is deleted except a merge's older side in the
**new** store (the legacy copy stays), so the stop condition was not met.

**On the fixture (Tim's shape, `test_migrate.lua`):** rc3 roster on Realm 2 with `Stromham`
(own), `Stromham Hamson` (heard echo), `Gizzardthe`, `Jobbi`, `Marvella`, `St` (own) and `Lilbit
High` filed under Realm 2 (really Realm 4); `account.main = Stromham`; three graveyard entries;
`hcTold`; recruit and prep state. Result: `Stromham` → `Stromham Hamson` (1 mapped, newest seen,
still the account's own), every main and the account's main re-pointed; `Gizzardthe`, `Jobbi`,
`Marvella`, `St` kept, **unmatched = 4**; `/dt alts` → `Stromham Hamson's lot: main Stromham Hamson;
alts (4): Gizzardthe, Jobbi, Marvella, St.`; crypt, recruit and prep state moved; Lilbit stays under
Realm 2 until his HELLO arrives from Realm 4, then refiled (deaths and `hcTold` follow); St Ham's
first 0.2.0 login folds `St` into `St Ham`; a second load migrates nothing again; `legacy` compares
equal to its snapshot throughout. Straight from rc3 (no fw1 between) works the same.

## Task 7: guard proofs (`lua5.1 tools/guard_proofs.lua`)
Every guard: the line changed once, its suite run, the named checks that went red, the file restored
and compared. The brief's list is rows 28-44 (the R-P6 guard is fw1's self-exclusion line, row 6,
which now also turns R-P6's "never doubled" red; the taint scan is row 11).

**One test strengthened** (allowed by `CLAUDE.md`): removing *migration runs once* first turned
nothing red, because the run-once check looked at a key a second run doesn't touch. Test-only diff
(`DeadTired/tests/test_migrate.lua`), then re-proved red:

```diff
--- Runs once.
+-- Runs once. After it, the player's own changes stand: a second load must not copy legacy again.
 roster[K2 .. "Stromham"] = { main = "", seen = "x" }
+roster[K2 .. "Gizzardthe"] = nil                       -- gone since (say, deleted)
+local nDeaths = #D.crypt.deaths
+D.settings.crypt.bedtime = "off"
 local again = mk(w, { name = "Stromham", full = "Stromham Hamson", db = D })
 again:login()
 check("runs once: a second load doesn't migrate again", roster[K2 .. "Stromham"] ~= nil and D.migrated.port1 == true
   and dump(D.legacy) == snap)
+check("runs once: nothing copied twice (no second set of legacy deaths, no entry brought back, no setting reset)",
+  #D.crypt.deaths == nDeaths and roster[K2 .. "Gizzardthe"] == nil and again.DT.get("crypt", "bedtime") == "off")
```

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
| realm normalise (AUD-06) | `Keys.lua` | `realm = realm` | test_keys | **red**: realmKey: spaces and hyphens go; realmKey(): GetRealmName when the normalised name is missing; keyOf: two-part name, realm normalised (+2 more) |
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
| bar: others unticked by default (R-P4) | `Bar.lua` | `b.on[name] = true` | test_bar | **red**: no LDB: the bar shows DT's own buttons, drawn natively; R-P4: other addons' objects are listed but unticked: the bar shows DT's own only; with LDB: ticked, the bar hosts other addons' launchers and data sources (+12 more) |
| bar: colour codes pass | `Bar.lua` | `if false then` | test_bar | **red**: colour codes: another addon's colour code is shown, not escaped; R-P4: /dt bar remove unticks it; R-P4 move: to position 1 (+4 more) |
| list rows fit their text | `UI.lua` | `local h = rh` | test_ui | **red**: rows: a long cell makes its row taller |
| settings content follows the scroll | `SettingsView.lua` | `if scroll > maxS then scroll = maxS end` | test_settingsview | **red**: defect 2: reopened, the content is back at the top (the first setting visible); defect 2: a search after a scroll starts at the top too |

## Task 8: the zip
`dist/DeadTired-0.2.0.zip`, **140794 bytes**, sha256
`659acce6f300d5f20bcf7659863ce88fd40990b9a500e6a3dbefc1a655ba2272`; 43 entries (452784 bytes
unpacked), unzips to `Interface\AddOns\DeadTired\DeadTired.toc`; `diff -r` against the checkout
(tests excluded): **clean**. `run_all.sh`: ALL GREEN. Version `0.2.0` in the `.toc` and `DT.VERSION`.
Files: `DeadTired.toc`, `Config.lua`, `Core.lua`, `Keys.lua`, `Guild.lua`, `Comms.lua`,
`Settings.lua`, `Skins.lua`, `UI.lua`, `SettingsView.lua`, `Bar.lua`, `Debug.lua`, `Who.lua`,
`Alts.lua`, `Crypt.lua`, `RecruitLines.lua`, `Recruit.lua`, `Prep.lua`, `Session.lua`,
`Migrate.lua`, and `Libs/` (LibStub, CallbackHandler-1.0, AceComm-3.0 + ChatThrottleLib,
LibSerialize, LibDeflate, LibSharedMedia-3.0, each with its licence; `README.md`, `SHA256SUMS`;
unmodified). `dist/DeadTired-0.2.0-fw1.zip` left in place.

## Task 9: release notes
`docs/RELEASE_0.2.0.md`, a draft for Tim to publish.

## Player-facing lines
**Carried from rc3, unchanged:** Alts (all ten: `you haven't named a main...`, `... is now your
main. The rest are just alts.`, `main cleared. Everyone's an alt now.`, `...'s lot: main ...; alts
(n): ...`, `... is a main with no known alts.`, `no ... in the crypt. Only guildies running the addon
are known.`, `more than one ...: .... Add the realm.`, `... hasn't named a main. Alone in the
dark.`, `/dt main makes this character your main; /dt main clear forgets it.`, `can't tell who you
are yet. Try again in a moment.`); Crypt (both notices, the three nags, the hardcore line, the
closing line, the empty graveyard, the four `/dt rip` replies and its status and usage lines, the
five bedtime replies); Recruit (the nudge, `Posted line n of 5 to General.`, the seven refusals,
`Next up: ...`, the usage line); Prep (`Ready. Bags packed, coffin optional.`, `Short: ...`,
`Nothing on the list for you. Travel light.`, the `/dt prep list` line, the three sharing lines,
`Roll call sent. Answers in 10 seconds.`, `Patience. The last roll call is still out.`, the summary,
its closing line). The welcome, legacy and bar-intro lines are fw1's.

**New, from the brief:** `Nudge off. The crypt keeps its own counsel.`, `Nudge on. The crypt will
knock.`, `Just you so far. The rest are still in their coffins.`, `(you)`, `Recruit` / `Recruit m:ss`.

**New, not in the brief** (each is needed by a ruled feature; Tim to keep, change or cut):
- Bar: card **On the bar** (*"What the bar shows, left to right as listed here. Dead Tired's own are
  ticked; other addons' wait unticked until you tick them. Drag a row by its grip to move it."*);
  replies `bar.<name> = on|off`, `bar.<name> at <n>`, `bar.list: 1 <label> (<name>) [on], ...`,
  `bar.list: no <x>. /dt bar list`, `/dt bar move <name> <position>. /dt bar list`.
- Prep: `prep.list: <item> x<n> (<n> on the list)`, `prep.list: <item> removed (<n> on the list)`,
  `prep.list: cleared`, `prep.list: full (30).`, `prep.list: no <x> on it. /dt prep list`,
  `/dt prep add <item> <count>: an item ID or a shift-clicked item, then how many.`, the longer usage
  line; cards **Raid prep** (switch), **Answer roll calls**, **Raid-night list** with plain-word
  descriptions; officers' refusal reuses rc3's `Officers only. The rest of us just haunt the place.`
- Crypt: viewport title **Rest in Pieces**; cards **Death notices**, **Share my deaths**,
  **Bedtime** and the switch, each with a description.
- Recruit: card **Nudge** with its description; tooltip header `Recruit`.
- Session: `Session h:mm`, `This session`, `Time: h:mm`, `Your deaths: n`, `New in the graveyard: n`.
- Who tooltip: the name, the realm, `Dead Tired <version>`. Settings list button: `Remove`.

## Questions for Tim
1. **`Config.OFFICER_MAX_RANK = 1`** (0 Guild Master, 1 the next rank): who counts as an officer
   when **receiving** the raid list. Set it to the guild's lowest officer rank. (Sending uses the
   game's own `IsGuildOfficer`, as recruit does.) Also unknown until H7: how Forever spells names in
   `GetGuildRosterInfo` (with or without `-Realm`, with the surname); both are handled, but a
   spelling I haven't seen would refuse every list (fail closed, counted in `prep.notOfficer`).
2. **R-P1's text:** the ruling says it shows "the next line number and the cooldown" and gives
   `Recruit` / `Recruit 4:12`. I followed the examples; the line number is in the tooltip. Say if you
   want `Recruit 3` / `Recruit 3 · 4:12`.
3. **`/dt prep roll`** for rc3's roll call: R-P3 gives `/dt prep check` to the bag check.
4. The new lines above.
5. rc3's built-in `PrepList.lua` (class reagents) is not shipped: the officers' list replaces it.
6. **The own short-key fold at login** (Alts) goes a step past the migration rule: it only ever folds
   `RealmKey-UnitName("player")` into this character's full key, and only an entry marked as the
   account's own. Without it, Gizzardthe, Jobbi, Marvella and St would each show twice (short and
   full) once they log in on 0.2.0. H1's "St Ham, Gizzardthe, Jobbi, Marvella" holds per character
   once each has logged in; before that they show by their short names.
7. With Titan Panel (LibDataBroker loaded), Titan shows DT's Recruit object to non-officers too (DT
   can't hide another addon's display); a non-officer's click is refused by the officer check.

## What H-checks need from Tim
H1-H8 as written. For H7, an officer and a guildie on 0.2.0; if the guildie never gets the list, see
question 1 (`/dt debug errors` shows nothing for it; `DeadTiredDB.prep.notOfficer` counts refusals).
