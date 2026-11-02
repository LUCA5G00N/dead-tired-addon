# Cowork report: dt_probe (launch-night probe)

Brief: `docs/COWORK_BRIEF_dt_probe.md`. Walk-sheet: `docs/UAT_dt_probe.md`.
Built 2026-11-02 in a cloud session, on branch **`card/dt_probe`** off `main` (`dcec729`). No
game client was used: everything below was proved offline with stubs. The launch-night run
(G6) is Tim's.

**Result:** `DeadTiredProbe/` 0.1.0 is built (`DeadTiredProbe.toc`, `Probe.lua`). The offline suite
passes (124 checks), all 17 guard removals went red, the greps find nothing, and no stop
condition tripped. One test was strengthened under the house-rule exception (Guard 5c, below).

## Preconditions

- **P1** holds: `main`'s `CLAUDE.md` has the *Ruled exceptions* section.
- **P2** holds, with one gap: every `C_*` function named in *Sections* is in the reference except
  `C_GameRules.IsSelfFoundActive` (below). The brief says a gap is not a stop: the probe records
  `"<absent>"` for it. Everything else named is a global, and guarded.

## Task 1: API lookups (`reference/SPEC_forever_namespaces.md`)

| Function | Line | Namespace header |
|---|---:|---:|
| `C_GameRules.GetActiveGameMode` | 1359 | 1355 |
| `C_GameRules.IsHardcoreActive` | 1365 | 1355 |
| `C_GameRules.IsSelfFoundActive` | **not found** | 1355 |
| `C_GuildInfo.CanSpeakInGuildChat` | 1507 | 1504 |
| `C_GuildInfo.IsGuildOfficer` | 1511 | 1504 |
| `C_GuildInfo.QueryGuildMemberRecipes` | 1513 | 1504 |
| `C_GuildInfo.QueryGuildMembersForRecipe` | 1514 | 1504 |
| `C_ChatInfo.AreOutgoingAddonChatMessagesRestricted` | 757 | 754 |
| `C_ChatInfo.GetGeneralChannelID` | 762 | 754 |
| `C_ChatInfo.GetGeneralChannelLocalID` | 762 | 754 |
| `C_ChatInfo.GetNumActiveChannels` | 763 | 754 |
| `C_ChatInfo.InChatMessagingLockdown` | 764 | 754 |
| `C_ChatInfo.RegisterAddonMessagePrefix` | 769 | 754 |
| `C_ChatInfo.SendAddonMessage` | 770 | 754 |
| `C_Container.GetContainerItemInfo` | 990 | 982 |
| `C_Container.GetContainerNumSlots` | 993 | 982 |
| `C_Item.GetItemCount` | 1809 | 1796 |
| `C_Item.GetItemInfo` | 1812 | 1796 |
| `C_Item.GetItemInfoInstant` | 1812 | 1796 |
| `C_Item.IsBound` | 1822 | 1796 |
| `C_Item.RequestLoadItemDataByID` | 1832 | 1796 |
| `C_DateAndTime.GetCurrentCalendarTime` | 1133 | 1129 |
| `C_DateAndTime.GetServerTimeLocal` | 1134 | 1129 |
| `C_Calendar.GetDayEvent` | 674 | 652 |
| `C_Calendar.GetNumDayEvents` | 677 | 652 |
| `C_Calendar.OpenCalendar` | 679 | 652 |
| `C_TradeSkillUI.GetAllRecipeIDs` | 3002 | 2990 |
| `C_TradeSkillUI.GetTradeSkillLineForRecipe` | 3029 | 2990 |
| `C_TradeSkillUI.IsTradeSkillReady` | 3039 | 2990 |
| `C_Timer.After` (the probe's timers) | 2922 | 2919 |

**Not found:** `C_GameRules.IsSelfFoundActive`. The namespace has `IsSelfFoundAllowed` (line 1363)
instead. I did not substitute it, because the brief names `IsSelfFoundActive`. On this build the
probe will record `build.selfFound = "<absent>"`, and that is the answer for that build. Swapping
in `IsSelfFoundAllowed` would need a ruling.

**Globals, all guarded** (looked up at call time through `ask`/`try`): `GetBuildInfo`, `WOW_PROJECT_ID`,
`GetRealmName`, `GetNormalizedRealmName`, `UnitLevel`, `UnitClass`, `UnitName`, `UnitExists`,
`UnitIsPlayer`, `UnitFactionGroup`, `UnitIsEnemy`, `InCombatLockdown`, `UnitAffectingCombat`,
`GetTime`, `time`, `date`, `IsInGuild`, `IsInGroup`, `GetGuildInfo`, `Ambiguate`, `GetChannelList`,
`EnumerateServerChannels`, `GetChannelName`, `GetRealZoneText`, `GetServerTime`, `GetGameTime`,
`IsInInstance`, `hooksecurefunc`, `SlashCmdList`, `hash_SlashCmdList`, `ItemLocation`, `Enum`,
`GetGuildRecipeInfoPostQuery`, `GetGuildRecipeMember`, `issecretvalue`, `CreateFrame`,
`DEFAULT_CHAT_FRAME`, `UNKNOWNOBJECT`.

## What was copied

- **From `reference/wizardry/Forever/Core.lua`:** `secret`, `try`, `clean`, with their bodies
  kept (as `P.secret`, `P.try`, `P.clean`). One addition: `try` and `clean` call a local `secret`
  that wraps `P.secret` in `pcall` and treats an `issecretvalue` that throws as secret
  (fail closed). Without it, a throwing client would make every read raise. `charKey` copies
  `W.charKey`'s pattern (Realm-Name, nil while `UnitName` says `"Unknown"`). `out` is styled on
  `W.out`, without the colour code.
- **From `reference/wizardry/tests/test_forever_core.lua`:** the test style: a `check` counter,
  the `CreateFrame`/`fire` stubs and the `DEFAULT_CHAT_FRAME` capture.
- **From `DeadTired/`** (pattern only; nothing loads at runtime): card 6's `Played.lua` hook
  pattern, `pcall(hooksecurefunc, SlashCmdList, "PLAYED", stamp)` with a stamp cleared on use.
  Card 6's `Stash.lua` way of reaching `C_Item.IsBound`, through
  `ItemLocation:CreateFromBagAndSlot`.

## Choices the brief left open (please check)

1. **A failing section keeps its partial data.** The brief's shape is
   `sections.<name> = { failed = "<message>" }`. The probe sets `failed` on the section's
   existing table instead of replacing it, so a section that collects over time (comms, login,
   played) keeps what it already had. A section that fails on its first run reads exactly as the
   brief's shape, plus whatever it had written before the error.
2. **A restricted ping is held, not forced** (house rule in `CLAUDE.md`). If
   `AreOutgoingAddonChatMessagesRestricted()` is true, the ping waits. It retries every 5 s and
   sends once the restriction lifts, or after a minute records
   `"<gave up: still restricted after 60 s>"`. The brief's "exactly one send per ping" holds once
   the restriction lifts. Tested.
3. **`/played` cache check.** `played.hook.cachedBeforeHook` records `type(hash_SlashCmdList["/PLAYED"])`
   at load. This is the in-game risk card 6's report named (a cached handler never reaches the
   hook). It is a read only.
4. **Trailing nils are kept.** `ask` counts results with `select("#")`, not `table.maxn`, so
   "both returns" of `UnitName("target")` records the realm as `"<nil>"` rather than dropping it.
   The suite caught this on its first run.
5. **Bank containers** are every `Enum.BagIndex` value whose key contains "bank" (any case), other
   than 0-4. Without `Enum.BagIndex` they fall back to `-1, 5-11`.
6. **Calendar days** across a month end are worked out by the probe (leap years included):
   offset 0 or 1, and the day of that month. `C_Calendar.GetMonthInfo` was not needed.
7. **Recipes query line:** the third return of `GetTradeSkillLineForRecipe` (the parent line, as
   card 2's step 4 uses), or the first return if the third isn't a number. The query is still
   sent when there's no guild (it is harmless), and the attempt records `noGuild = true`.
8. **Character key:** a run is filed under `Realm-Name` once `UnitName` is ready (at
   `PLAYER_LOGIN` or `PLAYER_ENTERING_WORLD`). If it never is, the run goes under `"?-?"` at
   PEW + 15 s or at the first command. A `/reload` counts as a login and starts a new run.
9. **`/dtprobe reset`** clears this character's runs and starts a fresh one. The fresh run keeps
   the hook's state, because the hook is placed once per load.
10. **The "every function absent" test keeps `CreateFrame`:** without a frame there are no events
    to drive. A separate check loads the probe with `CreateFrame = nil` and shows `/dtprobe` still
    answers.

## Tests: `lua5.1 DeadTiredProbe/tests/test_probe.lua`

```
probe: 124 passed, 0 failed
```

The suite covers every check Task 5 lists:
- rec and ask helpers;
- a scripted session in a guild: login, every command, 20 addon messages, 7 deaths, a typed
  `/played` and an untyped one, bank open;
- every cap;
- secrets never stored raw (a deep scan of `DeadTiredProbeDB`);
- zero calls to the five forbidden functions;
- one `SendAddonMessage` per ping in a guild;
- every printed line starts `Dead Tired probe: ` and has no `|`;
- section isolation;
- every game function absent, then every game function throwing: all 13 sections exist, none
  failed, no error reached a handler, and reads are `<absent>` / `<error: …>`;
- no guild: solo sends nothing, a party gets `PARTY`;
- a second login adds a run and the first is byte-identical; runs capped at 5;
- restricted ping held;
- no `/played` handler.

It is not added to `DeadTired/tests/run_all.sh` (Q2).

## Task 6: guard proofs

Each guard was removed in a **copy** of `Probe.lua` in the session scratchpad, and the suite was run
against it (`PROBE_FILE=<copy> lua5.1 DeadTiredProbe/tests/test_probe.lua`). `Probe.lua` itself
was never edited for a proof, so nothing had to be restored.

| # | Guard removed | Checks that went red |
|---|---|---|
| 1 | per-section `pcall` in `run()` (`f(sec, ...)` called bare) | isolation: a throwing section records failed; the next sections still run; a failing command still replies one line |
| 2 | `ask`'s absent branch (`type(f) ~= "function"`, in `askRaw`) | ask: an absent function reads `<absent>`; build: IsSelfFoundActive missing reads `<absent>`; absent: reads are `<absent>` |
| 3 | `ask`'s error branch (`if not r[1]` → `if false`) | ask: an erroring function reads `<error: ...>`; the error message is cut to 120 bytes; throw: reads are `<error: ` |
| 4 | `rec`'s secret branch | rec: a secret value is recorded as `<secret>`; table values go through rec; ask: all results, each through rec; a throwing issecretvalue counts as secret; target: a secret name is recorded `<secret>` |
| 5a | channel choice → always `GUILD` | absent / throw: ping sends nothing and says so; no guild, solo: ping sends nothing; no guild, in a party: PARTY |
| 5b | channel choice → no party fallback | no guild, in a party: ping goes to PARTY, once |
| 5c | channel choice → party before guild | ping: in a guild and a group, the guild wins *(after the test was strengthened, below)* |
| 6a | cap: 200 bag slots | bags: 200 slots at most |
| 6b | cap: 10 addon messages | comms: 10 messages kept, the rest counted |
| 6c | cap: 10 targets | target: 10 snapshots at most |
| 6d | cap: 5 deaths | death: 5 kept, all counted |
| 6e | cap: 5 played events | played: 5 events kept |
| 6f | cap: 5 channel snapshots | channels: 5 snapshots at most |
| 6g | cap: 60 calendar events | calendar: read by the timer when no list comes; 60 events at most |
| 6h | cap: 40 recipe members | recipes: 40 members at most |
| 6i | cap: 5 recipe attempts | recipes: 5 attempts at most |
| 7 | the hook's own `pcall` at load (`hooksecurefunc` called bare) | throw: no section failed; throw: the hook is recorded as not placed, with why; hook: no PLAYED handler, recorded as not placed |

**Test strengthened (house-rule exception, test files only).** Variant 5c is not in the brief: I
added it, swapping the order to party before guild. At first it turned nothing red, because no
check pinged while in a guild *and* in a group. That is a weak test, not weak probe code, so I
added one check. With it, 5c went red. The diff:

```diff
@@ -467,6 +467,10 @@
 check("zero LeaveChannelByName", (S.calls.LeaveChannelByName or 0) == 0)
 slash("ping")
 check("exactly one SendAddonMessage per ping in a guild", S.calls.SendAddonMessage == 2)
+S.group = true
+slash("ping")
+check("ping: in a guild and a group, the guild wins", S.calls.SendAddonMessage == 3 and S.sent[3].chan == "GUILD")
+S.group = false
```

## Greps

The brief asks for "the five greps' output" but defines one (Task 7 = walk-sheet G3). I ran that
one and four others that check the brief's bounds:

1. **Task 7 / G3:**
   `grep -rnE "SendChatMessage|RequestTimePlayed|JoinChannel|LeaveChannel|COMBAT_LOG|CombatLog" DeadTiredProbe/ --include=*.lua | grep -v "/tests/"`
   → no output (exit 1).
2. **No inspect, auras, health or gear:**
   `grep -rnE "Inspect|UnitAura|AuraUtil|UnitHealth|GetInventoryItem" DeadTiredProbe/ --include=*.lua | grep -v "/tests/"`
   → no output (exit 1).
3. **One send site:** `grep -rn "SendAddonMessage" DeadTiredProbe/ --include=*.lua | grep -v "/tests/"` →
   ```
   DeadTiredProbe/Probe.lua:130:-- A game function by path ("GetTime", "C_ChatInfo.SendAddonMessage"), looked up at call time.
   DeadTiredProbe/Probe.lua:324:  p.result = A("C_ChatInfo.SendAddonMessage", PREFIX, "ping", p.channel)
   ```
   (one comment and one call).
4. **No `DeadTired` code at runtime:** `grep -rnE "ns\.DT|DeadTired/|DT\." DeadTiredProbe/ --include=*.lua | grep -v "/tests/"` →
   only the header comment `-- A throwaway diagnostic, separate from DeadTired/ ...`.
   The `.toc` loads `Probe.lua` only.
5. **G4:** `git diff main --stat` on `card/dt_probe` (local `main` reset to `origin/main`, `dcec729`):
   ```
    DeadTiredProbe/DeadTiredProbe.toc   |   8 +
    DeadTiredProbe/Probe.lua            | 978 ++++++++++++++++++++++++++++++++++++
    DeadTiredProbe/tests/test_probe.lua | 662 ++++++++++++++++++++++++
    docs/COWORK_REPORT_dt_probe.md      | 287 +++++++++++
    4 files changed, 1935 insertions(+)
   ```
   Only `DeadTiredProbe/` and `docs/`. (This report then grew by a few lines when this block was filled in.)

## Every line the probe can print

All start `Dead Tired probe: `. `<…>` marks a value filled in at run time.

- At load, once per login: `Dead Tired probe: recording. /dtprobe for commands.`
- `/dtprobe` alone, or an unknown verb:
  `Dead Tired probe: /dtprobe ping, channels, bags, items, target, calendar, recipes, report, reset.`
- `/dtprobe ping`, one of:
  - `Dead Tired probe: recorded ping: sent on GUILD`
  - `Dead Tired probe: recorded ping: sent on PARTY`
  - `Dead Tired probe: recorded ping: not sent: no guild and no group`
  - `Dead Tired probe: recorded ping: held on GUILD: addon messages restricted; it goes when they lift`
    (or `held on PARTY: …`)
- `/dtprobe channels`: `Dead Tired probe: recorded channels: <n> snapshot(s), general ID <id>, active <n>, zone <zone>`,
  then after 5: `Dead Tired probe: channels: already 5 snapshots`
- `/dtprobe bags`: `Dead Tired probe: recorded bags: <n> slots[ (capped)], isBound nil on <k>[; at the bank <n> slots[ (capped)], isBound nil on <k>]`
- `/dtprobe items`: `Dead Tired probe: recorded items: <k> of 8 named, <p> waiting for item data[; names fill in over 30 s]`
- `/dtprobe target`: `Dead Tired probe: recorded target: <name>, level <level>, in combat: yes|no, name secret: yes|no`,
  then after 10: `Dead Tired probe: target: already 10 snapshots`
- `/dtprobe calendar`: `Dead Tired probe: recorded calendar: asked; waiting for the event list (10 s at most)`.
  With no timer it reads at once instead:
  `Dead Tired probe: recorded calendar: <n> event(s) over 14 days[ (capped)], read by at once (no timer)`
  or `Dead Tired probe: recorded calendar: read at once (no timer): <no date: calendar time and date() both unavailable>`
- `/dtprobe recipes`: `Dead Tired probe: recorded recipes: attempt <n>[, no guild]: recipe <id>, line <line>, answers <k>, members <m>`
  or `Dead Tired probe: recorded recipes: attempt <n>[, no guild]: no recipe ID: <why>`,
  then after 5: `Dead Tired probe: recipes: already 5 attempts`
- Any command whose section throws: `Dead Tired probe: <verb>: failed: <message>`
- `/dtprobe reset`: `Dead Tired probe: this character's runs cleared. A fresh one is recording.`
- `/dtprobe report`: 13 lines, `Dead Tired probe: <section>: <headline>`, where the headline is
  `not run yet`, `failed: <message>`, `headline failed: <message>`, or one of:
  - `build: <version> (build <n>, interface <toc>), realm <realm>, hardcore: <yes|no|…>`
  - `login: guild name first seen at <t>; guild updates <n>, roster updates <n>` (or `no guild name seen; …`)
  - `guild: <guild>, rank <rank>, officer: <…>, can speak: <…>` or `guild: no guild (in guild: <…>)`
  - `comms: restricted: <…>, prefix registered: <…>, pings: <n>[ (last <channel>)], heard: <n>`
  - `channels: …` / `bags: …` / `items: …` / `target: …` / `recipes: …`: as the replies above (`no snapshot`, `no attempt` before one)
  - `time: time <n>, server <n>, server local <n>, date <date>`
  - `played: hook placed: <…>, typed <n>, events <n>[, last stamp age <age>]`
  - `death: <n> death(s)[, last in <zone>]`
  - `calendar: <n> event(s) over 14 days[ (capped)], read by <event|10 s timer|…>` or `calendar: asked; waiting for the event list (10 s at most)`

Nothing else prints. Events, timers, the hook and held pings print nothing (tested).

## Where to read each answer

Path: `DeadTiredProbeDB.chars["<Realm>-<Name>"].runs[<n>].sections.<section>.<field>`. Each run
also has `at`, `inGuild` and, if any, `errors` (handler errors caught outside a section; expected
empty) and `timer` (set only if `C_Timer.After` was missing).

| Section | Card question | Read |
|---|---|---|
| `build` | card 1 P2: the interface number; card 3: hardcore realms | `buildInfo[4]` (interface), `buildInfo[1]`/`[2]` (version, build); `hardcore`, `gameMode`, `selfFound` (`<absent>` expected), `WOW_PROJECT_ID` |
| `login` | card 1: does `PLAYER_GUILD_UPDATE` fire when guild info arrives late? | `firstGuildName.t` against `world.t`; `guildUpdates[i].guild` / `.t`, `guildUpdatesCount`, `rosterUpdates[i]`; `loaded.guild`, `login.guild` (blank early?) |
| `guild` | card 5 A1: the officer gate | `officer` (yours and your guildie's, both ways), `canSpeak`, `guildInfo[2]`/`[3]` (rank name, index); `noGuild` |
| `comms` | card 1: the `CHAT_MSG_ADDON` sender format, and restriction | `messages[i].sender` (raw, exactly as given), `.ambiguated`, `.isMe`, `.channel`; `restricted`, `lockdown`, `register`; `pings[i].channel`, `.result` (the send's returns), `.held` |
| `channels` | card 5 A1: what General is called and numbered | `snapshots[i].byIndex[n]` (id, name such as "General - Orgrimmar"), `generalID`, `generalLocalID`, `channelList`, `serverChannels`, `zone` |
| `bags` | card 6 A4: does `GetContainerItemInfo` report `isBound`? card 6: `Enum.BagIndex` and the bank's numbers; card 5: `GetItemCount`'s second argument | `last.slots[i].isBound` against `.isBoundByLocation` (agree? `<nil>`?); `last.bagIndex`; `last.numSlotsByIndex`; `bank.bags[i].bag`/`.numSlots`; `last.counts[i].count` against `.withBank` |
| `items` | card 5 G7: the starter list's item IDs | `list[i].name` (after `received`), `list[i].instant` (a nil first value means a bad ID) |
| `time` | cards 3 and 6: what `GetServerTimeLocal` means | `serverTimeLocal - serverTime` (realm offset?), `time` (local clock), `calendarTime` (hour/minute), `gameTime`, `date` |
| `played` | card 6 A3: `TIME_PLAYED_MSG` argument order; does the hook see a typed `/played`? | `hook.placed`, `hook.why`, `hook.cachedBeforeHook`; `typed`; `events[i].args` (expect total, then this level); `events[i].stampAge` (a number after typed `/played`, `<no stamp>` after `RequestTimePlayed()` from a script) |
| `target` | card 4: is an enemy's name or level secret in combat? the realm format; faction at range | `snapshots[i].name[1]`/`[2]`, `level`, `factionTarget`, `isEnemy`, with `lockdown`/`affectingCombat` saying in or out of combat |
| `death` | card 3: does `PLAYER_DEAD` fire? does `IsInInstance` say `"pvp"` in a battleground? | `count`, `deaths[i].instance[1]`/`[2]`, `zone`, `hardcore` |
| `calendar` | card 6 G9: the Fishing Extravaganza's real schedule | `events[i].title`, `.startTime`, `.calendarType`, `.sequenceType`; `readBy` (`event` = the list arrived); `days[i].num` |
| `recipes` | card 2: does the native guild recipe lookup work? | `attempts[i].fns` (all four true?), `.recipeID`, `.line[3]` (parent), `.query`, `.events[j].info[3]` (member count), `.events[j].members` (the right guildies, including ones without the addon?). Compare attempt 1 (window open) with attempt 2 (window shut). "Native works" = functions present, an event arrives, the right names. |

## Stop conditions

None tripped:
- nothing in `DeadTired/` or any other card branch changed;
- no section needed the combat log, a combat event, inspect, a public post or the play-time
  request;
- the suite runs every section with every function absent, and with every function throwing,
  without an error;
- every guard removal went red. The one weak test was fixed in the test file only.

`docs/UAT_dt_probe_results.md` and `docs/PROBE_launch_results.md` were not written.

---

## Amendment 2 (self-found fix, logging, instances)

Built 2026-11-02 from the brief's *Amendment 2*, on `card/dt_probe` after merging `main`
(`cbf3477`) into it (merge commit `0cf5f7f`, no conflicts). The merge brought the amendment, card
7's brief and walk-sheet (`dt_logs`) and `reference/wizardry/LogPrompt/`. No file under
`DeadTiredProbe/` changed in the merge, and nothing in `DeadTired/` changed.

**Result:** 153 checks pass (124 before). All 21 guard removals went red: the 17 from the first
build, re-run, plus the 4 new ones. G3 still finds nothing. No stop condition tripped, and no test
needed strengthening this time.

### Lookups

| Function | Line | Namespace header |
|---|---:|---:|
| `C_GameRules.IsSelfFoundAllowed` | **1367** | 1355 |
| `C_PlayerInfo.IsSelfFoundActive` | 2336 | 2322 |
| `C_ChatInfo.IsLoggingChat` | 766 | 754 |
| `C_ChatInfo.IsLoggingCombat` | 767 | 754 |

**Correction:** the first report said `IsSelfFoundAllowed` is on line 1363, and the amendment
copied that. It is on **line 1367**: 1363 is the first line of that wrapped block, which is where I
misread it. Nothing else depends on the number.

**Globals, guarded:** `LoggingCombat` and `LoggingChat` (outside the `try` path only their
`type` is read), `GetInstanceInfo`. **Events:** `ADDON_ACTION_BLOCKED`, `ADDON_ACTION_FORBIDDEN`,
`ZONE_CHANGED_NEW_AREA`. Each is registered under `pcall` like the rest.

**Copied:** nothing new from `reference/` or `DeadTired/`. I read
`reference/wizardry/LogPrompt/LogPrompt.lua` for context only. Its header says the
`LoggingCombat`/`LoggingChat` globals are unobserved on this client. That is the question
`logging try` answers.

### What was built

- **B1, `build`:** `selfFound` is gone. In its place, `selfFoundAllowed` =
  `C_GameRules.IsSelfFoundAllowed()` and `selfFoundActive` = `C_PlayerInfo.IsSelfFoundActive()`,
  both through `ask`. The `build` headline gains `self-found: <selfFoundActive>`.
- **B2, `logging`:** an automatic read at PEW + 15 s, and another on each `/dtprobe logging`.
  Each read holds `IsLoggingCombat()`, `IsLoggingChat()`, and the `type` of the globals
  `LoggingCombat` and `LoggingChat`. Reads are capped at 5 (my choice: the amendment sets no
  cap), and every read is counted.
- **B2, `/dtprobe logging try`:**
  - It acts only when `IsLoggingCombat()` reads exactly `false`. "Already on", absent, error or
    secret all record why and call nothing.
  - Otherwise it calls `LoggingCombat(true)` through `ask`, which is `pcall`. That is the probe's
    one switching call.
  - It records the call's results or error, and `blockedByError` (the error text contains
    "blocked", "forbidden" or "protected").
  - `ADDON_ACTION_BLOCKED` and `ADDON_ACTION_FORBIDDEN` naming this addon are recorded within 1 s
    (up to 5 per attempt). The listener is set before the call, so an event fired during it
    counts. Events outside that window go to `strayBlocked` and `lastStray`. Other addons' events
    are ignored.
  - `IsLoggingCombat()` is read again 1 s later. If there's no timer it is read at once
    (`readAt`).
  - Up to 3 attempts. An attempt that called nothing still counts toward the 3; I read "up to 3
    attempts" that way.
  - Its one reply line is printed when the 1 s read is made, not when the command is typed.
- **B3, `instances`:** every `PLAYER_ENTERING_WORLD` (10 kept, `worldCount` counts all):
  - its two arguments;
  - `IsInInstance()` and `GetInstanceInfo()` (all returns);
  - zone, `InCombatLockdown()`, `IsLoggingCombat()`.

  Every `ZONE_CHANGED_NEW_AREA` (10 kept, `zoneCount`): `IsInInstance()` and the zone.
- `/dtprobe report` now has **15** lines: `logging` and `instances` come after `recipes`.

### Tests (new and changed)

- The old check `build: IsSelfFoundActive missing reads <absent>` is replaced by one for the two
  new self-found reads.
- **Absent and throwing:** both new sections exist and none failed. Their reads, and B1's, read
  `<absent>` / `<error: …>`. `logging try` calls nothing when the state can't be read.
- **`LoggingCombat` counts:**
  - off → called exactly once, with `true`;
  - on → never;
  - `IsLoggingCombat` absent → never;
  - `LoggingCombat` itself absent → recorded as `<absent>`.
- **No calls over the whole scripted session:** zero `LoggingCombat` or `LoggingChat` calls,
  across login, every command, 20 addon messages, deaths, `/played`, bank and the automatic
  `logging` read. `LoggingChat` is zero in every test.
- **Caps:** 3 try attempts; 10 world entries and 10 zone changes, with the counts going on.
- **Blocked:**
  - an `ADDON_ACTION_BLOCKED` for this addon fired during the call is recorded, and the line says
    blocked;
  - another addon's event is ignored;
  - a `FORBIDDEN` after the window is stray;
  - a "protected function" error sets `blockedByError`.
- **Replies:** the reply waits for the 1 s read (nothing at the command, one line at 1 s); with no
  timer it is read at once, still one line. `Logging   TRY` works in any case and spacing.
- A battleground entry records `"pvp"`. Entries and zone changes print nothing.

```
probe: 153 passed, 0 failed
```

### Guard proofs (added)

Same method as before: each guard removed in a scratchpad copy of `Probe.lua`.

| # | Guard removed | Checks that went red |
|---|---|---|
| A2-1 | `try`'s "only if off" (`if state ~= false` → `if false`) | absent: logging try calls nothing when the state can't be read; throw: the same; try, on: nothing called, says so; try: third attempt, any case and spacing; try: 3 attempts at most; try, state absent: LoggingCombat never called |
| A2-2 | `try`'s attempt cap (3) | try: 3 attempts at most; try: nothing else printed afterwards |
| A2-3a | instance cap: world entries (10) | instances: 10 world entries kept, all counted |
| A2-3b | instance cap: zone changes (10) | instances: 10 zone changes kept, all counted |

The first build's 17 removals were re-run against the amended file, and all are still red.
Guard 2 now turns 5 checks red (it was 3), because the A2 absent reads are added.

### Greps

- **G3** (unchanged): `grep -rnE "SendChatMessage|RequestTimePlayed|JoinChannel|LeaveChannel|COMBAT_LOG|CombatLog" DeadTiredProbe/ --include=*.lua | grep -v "/tests/"`
  → no output (exit 1).
- `grep -n "LoggingCombat\|LoggingChat" DeadTiredProbe/Probe.lua`:
  ```
  749:-- Amendment 2 B2. The globals LoggingCombat and LoggingChat SWITCH logging when given an argument.
  750:-- So outside S.loggingTry neither is ever called: only their type is read. LoggingChat is never
  764:    combat = A1("C_ChatInfo.IsLoggingCombat"), chat = A1("C_ChatInfo.IsLoggingChat"),
  765:    combatGlobal = type(fn("LoggingCombat")), chatGlobal = type(fn("LoggingChat")) }
  777:  local a = { t = A1("GetTime"), before = A1("C_ChatInfo.IsLoggingCombat"), blockedEvents = {} }
  779:  local state = T("C_ChatInfo.IsLoggingCombat")
  790:  a.result = A("LoggingCombat", true)
  794:    a.after1s = A1("C_ChatInfo.IsLoggingCombat")
  832:    lockdown = A1("InCombatLockdown"), loggingCombat = A1("C_ChatInfo.IsLoggingCombat") }
  940:  local base = r and string.format("combat log on: %s, chat log on: %s, LoggingCombat is a %s",
  ```
  Where they appear:
  - 749-750: comments.
  - 765: `type()` reads only, in the automatic read.
  - 777-794: inside `S.loggingTry`. **790 is the only call** to either global, and it is behind
    the "only if off" check on 779.
  - 832: an `IsLoggingCombat` read in `instances`.
  - 940: headline text.

  `LoggingChat` is never called.

### New and changed lines, verbatim

- The command list now reads:
  `Dead Tired probe: /dtprobe ping, channels, bags, items, target, calendar, recipes, logging, logging try, report, reset.`
- `/dtprobe logging`: `Dead Tired probe: recorded logging: combat log on: <yes|no|…>, chat log on: <yes|no|…>, LoggingCombat is a <function|nil>[; tries <n>, last <…>]`
- `/dtprobe logging try`, one of:
  - one second later: `Dead Tired probe: recorded logging try: combat logging is now on (it was off). /combatlog switches it off.`
  - one second later: `Dead Tired probe: recorded logging try: combat logging is still off.`
  - one second later: `Dead Tired probe: recorded logging try: combat logging is still off; the client blocked the call.`
  - one second later: `Dead Tired probe: recorded logging try: combat logging state unknown after the call (<value>).`
  - at once: `Dead Tired probe: recorded logging try: already on: nothing called`
  - at once: `Dead Tired probe: recorded logging try: state unknown (<absent|<error: …>|<secret>|…>): nothing called`
  - at once, after 3: `Dead Tired probe: logging try: already 3 attempts`
  - `Dead Tired probe: logging try: failed: <message>`
- Report lines:
  - `build: … hardcore: <…>, self-found: <…>` (gains the self-found field)
  - `logging: <as /dtprobe logging>`, or `logging: no read`
  - `instances: <n> world entr(y|ies), last <zone>, in instance: <yes|no> (<type>), <m> zone change(s)`,
    or `instances: no entry`

**Worth knowing before you type `logging try`:** if the call works, combat logging stays **on**
for the session, and the line says so. If the client blocks it, retail clients normally show
their own "action blocked" popup for the addon. That popup is the client's, not the probe's.

### Where to read each answer

Path as before: `DeadTiredProbeDB.chars["<Realm>-<Name>"].runs[<n>].sections.<section>.<field>`.

| Section | Question | Read |
|---|---|---|
| `build` (B1) | is this a self-found character? card 3 | `selfFoundActive` (this character), `selfFoundAllowed` (the realm's rule) |
| `logging` (B2) | combat-log prompt card (7): can the logs be read, and can addon code switch combat logging? | `reads[i].combat` / `.chat` (the log state; at login, `reads[1]`); `reads[i].combatGlobal` / `.chatGlobal` (do the globals exist?); `attempts[i].called`, `.result` (returns or `<error: …>`), `.blockedByError`, `.blockedEvents[j].event`/`.func`, `.blocked`, `.after1s` (**`true` = addon code can switch it on**); `strayBlocked` |
| `instances` (B3) | card 7: what entering an instance looks like; card 3: does `IsInInstance` say `"pvp"` in a battleground? | `worlds[i].isLogin`/`.isReload`, `.instance[1]`/`[2]` (in instance, type), `.info` (`GetInstanceInfo`: name, type, difficulty…, instance map ID at `[8]`), `.zone`, `.lockdown`, `.loggingCombat` (was logging already on at each entry?); `zones[i]`; `worldCount`, `zoneCount` |

### Stop conditions

None tripped:
- nothing in `DeadTired/` changed;
- the only call that switches anything is the single `LoggingCombat(true)` on the `try` path;
  `LoggingChat` is never called;
- every section runs with every function absent, and with every function throwing;
- every guard removal went red without a test fix.

`docs/UAT_dt_probe_results.md` and `docs/PROBE_launch_results.md` were not written.
