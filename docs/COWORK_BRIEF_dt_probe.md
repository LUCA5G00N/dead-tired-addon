# Cowork brief: DEAD TIRED launch-night probe (one login answers what the cards couldn't)

Read first, in order:
1. `CLAUDE.md`.
2. This brief and its walk-sheet, `docs/UAT_dt_probe.md`.
3. The "not provable offline" sections of the card reports, on their branches:
   `docs/COWORK_REPORT_dt_<slug>.md` on `card/dt_foundation`, `card/dt_crypt`, `card/dt_pvp`,
   `card/dt_prep`, `card/dt_stretch`. Read only; this round changes none of those branches.
4. `docs/COWORK_BRIEF_dt_professions.md` on `claude/loving-meitner-yzdxtn`, section
   *Launch-night probe* (this round automates it).
5. `reference/wizardry/Forever/Core.lua` (the `try`, `clean`, `secret` helpers) and
   `reference/SPEC_forever_namespaces.md` (search it, don't read it top to bottom).

**Draft-status: ratified by Tim 2026-11-02** (scope agreed in the review of that day). Written
before launch: Forever goes live Wed 2026-11-04, 11pm UK. Built now, run by Tim on launch night.

## Origin

Every card report ends with questions only the live client can answer. Left as they are, launch
night means finding them one by one in the middle of the walks. The review of 2026-11-02 proposed
one throwaway addon that records all of them in one login, so the walks start from known answers
and card 2 (professions) can be ratified the same night.

## Precondition

- P1: `main` carries `CLAUDE.md` with the *Ruled exceptions* section.
- P2: every function named in Task 1 is in the reference, or is a global (guarded).

## What this is, and what it isn't

- A **separate addon**, `DeadTiredProbe/`, at the repo root next to `DeadTired/`. It shares no
  code at runtime with `DeadTired` and is never shipped to members. Tim and one guildie run it
  on launch night, then delete it.
- It **records** into its own SavedVariables, `DeadTiredProbeDB`, and prints only when Tim types
  a `/dtprobe` command (plus one load line, below). It decides nothing and fixes nothing.

## Ratified for this round

- **Q1: the probe may read what the cards may not.** It is Tim's diagnostic tool, run on his own
  characters and one consenting guildie's, stored locally. So it may read: the native guild recipe
  answers (the game's own guild feature: card 2's question), every bag slot's bound flag and item
  ID (never sent anywhere), and a targeted enemy's unit fields in and out of combat (card 4's
  question). It still never reads the combat log or any combat event, never posts to a public
  channel, and never calls `RequestTimePlayed`.
- **Q2: tests live with the probe.** `DeadTiredProbe/tests/test_probe.lua`, same style as
  `DeadTired`'s tests, run with `lua5.1 DeadTiredProbe/tests/test_probe.lua`. It is not added to
  `DeadTired/tests/run_all.sh`.
- **Q3: branch `card/dt_probe` off `main`.** Not off card 1: it shares nothing with it. It is
  **never merged to `main`**; it is a tool, and its results are what matter.

## Deliverable

`DeadTiredProbe/` loads on the live client and, in one login plus the commands on the walk-sheet,
fills `DeadTiredProbeDB` with every section below. Each section holds either values or a
recorded reason it couldn't (absent, error text, secret). No section can stop another from
running. The offline suite proves that with every game function absent, and with every one
throwing, each command and event handler still completes and records a reason.

### Shape of the record

```
DeadTiredProbeDB = {
  version = 1,
  chars = {
    ["Realm-Name"] = {
      at = <time()>, sections = { build = {...}, login = {...}, ... },
    },
  },
}
```

Every recorded value goes through one helper, `rec(v)`:
- a secret value → the string `"<secret>"`;
- a function → `"<function>"`, a table → a shallow copy of up to 20 keys (values through `rec`);
- nil → the string `"<nil>"` (so an absent answer is visible in the saved file).

Every probe call goes through one helper, `ask(f, ...)`:
- `f` not a function → returns the string `"<absent>"`;
- `f` errors → returns `"<error: " .. message .. ">"` (message cut to 120 bytes);
- otherwise returns all results, each through `rec`, as a list.

Each section runs inside its own `pcall`; a section that throws records
`sections.<name> = { failed = "<message>" }` and the next section still runs.

### Sections

Each names the card question it answers. **Automatic** ones run without a command.

1. **`build`** (automatic, at `PLAYER_LOGIN`; card 1 P2, card 3): `GetBuildInfo()` (all
   returns), `WOW_PROJECT_ID`, `GetRealmName()`, `GetNormalizedRealmName()`,
   `C_GameRules.GetActiveGameMode()`, `C_GameRules.IsHardcoreActive()`,
   `C_GameRules.IsSelfFoundActive()`, `UnitLevel("player")`, `UnitClass("player")`.
2. **`login`** (automatic; card 1): `GetTime()` at `ADDON_LOADED` (this addon),
   `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, and each of the first 5 `PLAYER_GUILD_UPDATE` and
   `GUILD_ROSTER_UPDATE` events, with `GetGuildInfo("player")` at each. Plus the time
   `GetGuildInfo` first returned a name.
3. **`guild`** (automatic, at `PLAYER_ENTERING_WORLD` + 15 s; card 5 A1): `IsInGuild()`,
   `GetGuildInfo("player")` (all returns), `C_GuildInfo.IsGuildOfficer()`,
   `C_GuildInfo.CanSpeakInGuildChat()`.
4. **`comms`** (automatic at the same moment, plus `/dtprobe ping`; card 1):
   `C_ChatInfo.AreOutgoingAddonChatMessagesRestricted()`, `C_ChatInfo.InChatMessagingLockdown()`,
   the result of `C_ChatInfo.RegisterAddonMessagePrefix("DTPROBE")`. `/dtprobe ping` sends one
   addon message, `"ping"`, prefix `DTPROBE`, channel `GUILD`, only if `IsInGuild()`; records the
   send's return values. Every `CHAT_MSG_ADDON` with prefix `DTPROBE` records (up to 10): the raw
   sender string exactly as given, `Ambiguate(sender, "none")`, the channel, the text (cut to 20
   bytes), and whether the sender is this character.
5. **`channels`** (automatic at `PLAYER_ENTERING_WORLD` + 15 s, and again on
   `/dtprobe channels`, up to 5 snapshots; card 5 A1): `GetChannelList()` (all returns),
   `EnumerateServerChannels()`, `C_ChatInfo.GetNumActiveChannels()`,
   `C_ChatInfo.GetGeneralChannelID()`, `C_ChatInfo.GetGeneralChannelLocalID()`,
   `GetChannelName(i)` for `i` 1-20, and `GetRealZoneText()`. **Reads only: joins nothing,
   leaves nothing, posts nothing.**
6. **`bags`** (on `/dtprobe bags`, and once at `BANKFRAME_OPENED`; card 6 A4, card 5): for
   bags 0-4 (and the bank containers when the bank is open), every occupied slot, capped at 200
   slots in total per snapshot: bag, slot, item ID, the `isBound` field of
   `C_Container.GetContainerItemInfo` exactly as returned (true, false or `"<nil>"`), and
   `C_Item.IsBound` on `ItemLocation:CreateFromBagAndSlot(bag, slot)` (through `ask`). Also the
   whole `Enum.BagIndex` table through `rec`, and `C_Container.GetContainerNumSlots` for every
   value in it. For the first 5 item IDs: `C_Item.GetItemCount(id)` and
   `C_Item.GetItemCount(id, true)`. Stored locally, never sent.
7. **`items`** (on `/dtprobe items`; card 5 G7): for each ID in a copy of card 5's starter prep
   list (13446, 17029, 17020, 17033, 17026, 17030, 6265, 5140): `C_Item.GetItemInfoInstant(id)`,
   and `C_Item.GetItemInfo(id)`'s name. A nil name calls `C_Item.RequestLoadItemDataByID(id)` and
   is filled in on `GET_ITEM_INFO_RECEIVED`, for up to 30 s.
8. **`time`** (automatic at `PLAYER_ENTERING_WORLD` + 15 s; cards 3 and 6): `time()`,
   `GetServerTime()`, `C_DateAndTime.GetServerTimeLocal()`,
   `C_DateAndTime.GetCurrentCalendarTime()`, `GetGameTime()`, `date("%Y-%m-%d %H:%M:%S")`.
9. **`played`** (automatic hook at load, plus events; card 6 A3): at load,
   `hooksecurefunc(SlashCmdList, "PLAYED", f)` through `pcall`, recording whether it was placed
   (and why not); the hook stamps `GetTime()`. Every `TIME_PLAYED_MSG` (up to 5) records its
   arguments in order and the age of the stamp at that moment (or `"<no stamp>"`). The probe
   never calls `RequestTimePlayed`.
10. **`target`** (on `/dtprobe target`, up to 10 snapshots; card 4): `UnitExists`,
    `UnitIsPlayer`, `UnitFactionGroup` (target and player), `UnitName("target")` (both
    returns), `UnitClass("target")`, `UnitLevel("target")`, `UnitIsEnemy("player","target")`,
    `InCombatLockdown()`, `UnitAffectingCombat("player")`. Unit-frame fields only: never inspect,
    auras, health or gear.
11. **`death`** (automatic; card 3): on each `PLAYER_DEAD` (up to 5): `GetTime()`,
    `IsInInstance()` (both returns), `GetRealZoneText()`, `UnitLevel("player")`,
    `C_GameRules.IsHardcoreActive()`.
12. **`calendar`** (on `/dtprobe calendar`; card 6 G9): calls `C_Calendar.OpenCalendar()`; on
    the next `CALENDAR_UPDATE_EVENT_LIST` (or after 10 s, whichever is first), for today and the
    next 13 days: `C_Calendar.GetNumDayEvents(0, day)` and, for each event, `GetDayEvent`'s
    title, calendarType, sequenceType and start time. Up to 60 events.
13. **`recipes`** (on `/dtprobe recipes`; card 2): automates card 2's five-step probe.
    - Records whether `C_GuildInfo.QueryGuildMembersForRecipe`,
      `C_GuildInfo.QueryGuildMemberRecipes`, `GetGuildRecipeInfoPostQuery` and
      `GetGuildRecipeMember` are functions.
    - Records `C_TradeSkillUI.IsTradeSkillReady()`; takes the first of
      `C_TradeSkillUI.GetAllRecipeIDs()`, and `C_TradeSkillUI.GetTradeSkillLineForRecipe(id)`
      (all returns).
    - Calls `QueryGuildMembersForRecipe(parentLine, recipeID)`, and records each
      `GUILD_RECIPE_KNOWN_BY_MEMBERS` within 10 s: `GetGuildRecipeInfoPostQuery()` and up to 40
      `GetGuildRecipeMember(i)` results.
    - Each run is its own attempt, up to 5 (Tim runs it with the profession window open, then
      closed). With no recipe ID, records why and sends no query.

### Commands and output

- One load line, once per login: `Dead Tired probe: recording. /dtprobe for commands.`
- `/dtprobe` alone: the command list, one line.
- `/dtprobe ping | channels | bags | items | target | calendar | recipes`: run that section;
  print one line saying it was recorded, with its headline (for example
  `target: Nameless, level 60, in combat: yes, name secret: no`).
- `/dtprobe report`: one line per section with its headline, or `not run yet`.
- `/dtprobe reset`: clears this character's record.
- Nothing else prints. Lines use `|` only as chat escapes produced by the client, never in the
  addon's own text.

## Working rules

- Lua 5.1. Copy `try`, `clean`, `secret` from `reference/wizardry/Forever/Core.lua` into
  `DeadTiredProbe/Probe.lua` with their bodies kept, and say so in the report. `ask` and `rec`
  are built on them.
- **The probe must not fail.** Every handler, timer callback and slash command is wrapped; an
  error inside one is recorded in that section, never raised to the player's screen.
- One file of logic, `Probe.lua`, plus the `.toc`. `## Interface: 16001`.
  `## SavedVariables: DeadTiredProbeDB`. Title `Dead Tired Probe`.
- No code from `DeadTired/` at runtime. Copying a pattern from it is fine; say what in the report.

## Tasks

1. **Branch and API check.** Create `card/dt_probe` off `main`. In the reference, find every
   `C_*` function named under *Sections* and record its line. Globals are listed as "global,
   guarded". A missing `C_*` function is not a stop: the probe records `"<absent>"` for it; list
   them in the report.
2. **`Probe.lua`: helpers** (`try`, `clean`, `secret`, `rec`, `ask`, the record store keyed by
   `Realm-Name`, the per-section `pcall` runner).
3. **Automatic sections** 1, 2, 3, 4 (passive part), 5, 8, 9, 11.
4. **Command sections** 4 (ping), 5, 6, 7, 10, 12, 13, and `report`, `reset`.
5. **`DeadTiredProbe/tests/test_probe.lua`.** Stub the API in the house style. Checks at least:
   - with **every** game function absent (nil globals, empty namespaces), login plus every
     command completes, every section exists, and absent calls read `"<absent>"`;
   - with every game function **throwing**, the same, with `"<error: …>"` values;
   - a secret value is recorded as `"<secret>"`, never stored raw;
   - `nil` is recorded as `"<nil>"`;
   - a section that throws records `failed` and the next section still runs;
   - over a scripted session (login, all commands, 20 addon messages, deaths, `/played`,
     `TIME_PLAYED_MSG` with and without a typed `/played`), the stubs count **zero** calls to
     `SendChatMessage`, `C_ChatInfo.SendChatMessage`, `RequestTimePlayed`, `JoinChannelByName`,
     `LeaveChannelByName`, and exactly one `SendAddonMessage` per `/dtprobe ping` while in a guild
     and zero while not;
   - every cap holds: 10 addon messages, 10 targets, 5 deaths, 5 played events, 5 channel
     snapshots, 200 bag slots, 60 calendar events, 40 recipe members, 5 recipe attempts;
   - the `played` stamp's age is recorded, and `"<no stamp>"` when `/played` wasn't typed;
   - nothing prints except the load line and command replies.
6. **Guard proofs.** Remove each once, confirm a check goes red, restore:
   1. per-section `pcall` isolation;
   2. `ask`'s absent-function branch;
   3. `ask`'s error branch;
   4. `rec`'s secret branch;
   5. the in-guild check on ping;
   6. each cap (prove at least the bag-slot and addon-message caps);
   7. the hook's own `pcall` at load.
7. **Greps:** `grep -rnE "SendChatMessage|RequestTimePlayed|JoinChannel|LeaveChannel|COMBAT_LOG|CombatLog" DeadTiredProbe/ --include=*.lua | grep -v "/tests/"` finds nothing.
8. **Push** `card/dt_probe` (or `claude/<session>` if `card/*` is refused; say so in the report).
9. **Report.**

## Explicitly out of scope

- Any change to `DeadTired/` or to any `card/*` branch other than `card/dt_probe`.
- Fixing anything the probe might reveal: the probe records; the cards change after Tim reads it.
- Testing whether `SendChatMessage` to a channel needs a hardware event: card 5's in-game G10
  answers that with a real post. The probe never posts.
- A UI, a minimap button, or a results window. Chat lines and the saved file only.
- Parsing the saved file into a results doc: a later session does that with Tim.
- Updating card 2's brief to point at the probe (done when card 2 is ratified).

## The one deliberate widening, named

**The probe reads what the guild addon may not** (Q1): the game's guild recipe answers, every
bag slot's bound flag, and an enemy's unit fields in combat. What still bounds it:
- Tim's characters and one consenting guildie's, launch night only, then deleted;
- stored locally; the only thing it sends is `"ping"` on the guild addon channel, on command;
- no combat log or combat events, no inspect, no public chat, no channel joins, no play-time request.

## Stop conditions

- A task needs a change to `DeadTired/` or another card branch → stop.
- A section can't be written without the combat log, a combat event, inspect, a public post or
  `RequestTimePlayed` → stop (drop that section and report, rather than work around it).
- The offline suite can't run every section with every function absent without an error → stop.
- A guard removal turns nothing red and the fix would need probe code, not test code → stop.

## UAT: acceptance checks

In `docs/UAT_dt_probe.md`: 5 offline `[G]` checks, then Tim's launch-night run.

## Reporting

`docs/COWORK_REPORT_dt_probe.md` on `card/dt_probe`, recording:
- Task 1's lookups with line numbers, and every `C_*` function not found;
- what was copied from `reference/` and from `DeadTired/`;
- each guard removal and the check that went red;
- the five greps' output (Task 7 and walk-sheet G3);
- every line the probe can print, verbatim;
- for each section, which card question it answers, and the field Tim should read for the
  answer (so the results doc can be written from the saved file in one pass).

Never write `docs/UAT_dt_probe_results.md` or `docs/PROBE_launch_results.md`.
