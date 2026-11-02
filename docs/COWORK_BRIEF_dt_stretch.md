# Cowork brief: DEAD TIRED stretch (guild stash search, slowest-leveller award, event tracker)

**Where you are:** repo `dead-tired-addon`, a cloud session. Work on branch **`card/dt_stretch`**,
created from **`card/dt_foundation`** (ROADMAP rule 1), never from `main` or another card
(`card/dt_crypt`, `card/dt_pvp` and `card/dt_prep` are siblings: don't read or copy from them).
No game client is available; everything is proved offline with stubbed tests, then Tim walks it
in game. If the harness assigns you a different branch name, create that branch from
`card/dt_foundation` and say so in the report.

**Read before Task 1, in order:**
1. `CLAUDE.md` (house rules; they bind throughout this round).
2. This brief, then `docs/UAT_dt_stretch.md`.
3. `docs/COWORK_REPORT_dt_foundation.md` (what card 1 landed, and how its tests work).
4. `DeadTired/Core.lua`, `Comms.lua`, `Roster.lua`, `Alts.lua`, `tests/harness.lua`,
   `tests/test_roster.lua`.
5. `reference/SPEC_forever_namespaces.md`: search it, don't read it top to bottom.

**Amended 2026-11-02 by Tim, after the build:** stash answers carry **at most 4 hits** (was 5), and a
holder name may be **up to 24 bytes** (was 12), so a 12-letter accented name fits. Longest STASH:
245 bytes. The places below that changed are marked *(amended)*.

**Amended 2026-11-02 (rulings round, A3 and A4 in `docs/COWORK_BRIEF_dt_rulings.md`):** play time is
sent only after a **typed** `/played`, proved by hooking the `/played` command (A3); the stash lists
an item only when it is **known not to be bound** (A4), and the share-on line says answers name the
character holding the item. The places below that changed are marked *(amended)*.

**Draft-status:** **ratified by Tim 2026-11-02 (R1-R6 as proposed; R6: build now).** Written 2026-11-02, after cards 1, 3, 4 and 5 were
built and **before any of them has been walked in game**. Card 1 is at `61fe2d3` on
`card/dt_foundation`; Task 1 re-verifies every "already exists" claim against the branch you
start from. The roadmap's plan puts card 6 *after launch, only if there is budget*. Tim asked for
the brief now; whether to build it before launch is his call (R6). Three things can't be known
until the live client is up:
- the bank's container numbers on this client;
- what `C_DateAndTime.GetServerTimeLocal` returns;
- the Fishing Extravaganza's day and hours on Forever.

## Origin

Tim's idea list (`L5GN/_desk/dead-tired_addon_ideas.md`, 2026-11-02), carded as card 6 in
`docs/ROADMAP.md`: *"Stretch, budget permitting: crafting request board, guild stash search
(opt-in), slowest-leveller award, event tracker (STV Fishing Extravaganza)"*. The roadmap gives
it a dependency on card 2 "(requests)": the crafting request board needs card 2's profession
directory, which isn't built and waits on a launch-night probe (ROADMAP rule 4). This brief
therefore covers the other three, and moves the request board out (R1).

## Precondition

- P1: `card/dt_foundation` exists on origin and holds card 1 (six suites green). Check it with
  `git ls-remote origin card/dt_foundation` and `sh DeadTired/tests/run_all.sh` → exit 0.
- P2: Tim has ratified R1-R6 below (each marked `ratified`, or ruled otherwise).

## Depends on: rulings

This repo has no numbered rulings. The binding rules are `CLAUDE.md` (in particular *"Opt-in for
anything personal. Bag contents, play time and the like are shared only after the player
switches them on"* and *"Quiet by default"*) and `docs/ROADMAP.md`'s "Branching and testing rule"
(rules 1, 2, 4 and 5). Carried over from card 1's brief:
- **WoWWizardry 0012 clause 4** (as applied in card 1): every guard in Task 10 is removed once to
  prove a check goes red, then restored.
- **WoWWizardry 0003 / 0017**: characters are keyed `Realm-Name`.

## Ratify before code

The round may not be built while any of these is `proposed`. All six are ratified.

- **R1 (ratified 2026-11-02, as proposed): the crafting request board leaves card 6.** It depends on card 2, which can't
  be briefed until the launch-night recipe probe. It becomes its own card after card 2, written
  against card 2's code. Card 6 is the other three features.
- **R2 (ratified 2026-11-02, as proposed): stash sharing is opt-in, answers searches only, and covers the whole
  account.**
  - With `/dt stash share on`, your client keeps a local list of your **tradeable** items (an item
    is listed only when it is known not to be bound *(amended, A4)*): bags at every login and bag change, the bank whenever you open it.
  - The list covers every character on the account that has run with sharing on. A guildie's
    search can therefore be answered by whichever of your characters is online, naming the
    character that holds the item.
  - Nothing is sent except answers to a guildie's search, and an answer carries only the items
    matching that search, at most 4 *(amended; was 5)*.
  - Answers travel on the guild addon channel, so other members' clients receive them too. Only
    the asker prints them.
  - Off by default.
- **R3 (ratified 2026-11-02, as proposed): play time is shared only when you type `/played`.** With
  `/dt slowest share on`, each time *you* run `/played` your level and total hours played are
  sent to the guild. The addon **never calls `RequestTimePlayed` itself**, because that prints
  the played lines to your chat unasked. Off by default. *(amended, A3)* "You typed it" is proved:
  `SlashCmdList.PLAYED` is hooked (`hooksecurefunc`, guarded) to stamp when `/played` ran, and a
  play-time report is sent only within 10 s of that stamp. A report anything else asked for is
  ignored. No hook at load: nothing is ever sent, and `/dt slowest share on` says so.
- **R4 (ratified 2026-11-02, as proposed): events are data, with opt-in reminders.** The event list ships as
  `EventsList.lua`, holding one event, *"Stranglethorn Fishing Extravaganza, Sunday 14:00-16:00
  server time"*, the classic schedule as remembered. Tim confirms Forever's schedule at G9 and
  edits the data if it's wrong. With `/dt events remind on`, one line prints 30 minutes before
  each event and one at its start. Off by default.
- **R5 (ratified 2026-11-02, as proposed): what this card may change in card 1's files.** Four lines appended to
  `DeadTired.toc` after `Welcome.lua`, in order: `Stash.lua`, `Played.lua`, `EventsList.lua`,
  `Events.lua`. One line in `tests/run_all.sh`: `stash:Stash played:Played events:Events` appended to
  the module list. Nothing else. `DT.VERSION` stays `0.1.0`. At merge, keep every card's lines,
  in card order (Crypt, Gank, Prep's four, then this card's).
- **R6 (ratified 2026-11-02, as proposed): build before launch, or wait.** The roadmap says after launch. Proposal: build
  it now, while the credit lasts. It merges only after card 1's walk passes (ROADMAP rule 2), so
  building early risks only the credit, not the guild.

## Builds on (card 1, commit `61fe2d3`; Task 1 re-verifies each)

`DT.module{}`, `DT.verb(prefix, fn, usage)`, `DT.send(kind, fields)`, `DT.on(kind, fn)`,
`DT.isMember()`, `DT.guildKey()`, `DT.charKey()`, `DT.display(key)`, `DT.nameOf(key)`,
`DT.safe(s, max)`, `DT.stamp()`, `DT.now()`, `DT.after(d, fn)`, `DT.try`, `DT.clean`, `DT.out`,
`DT.db()`, `DT.errors()`, and Core's router (whole-word verbs, longest wins, non-members refused).
Test side: `tests/harness.lua` (`H.world()`, `world:client{...}` with `files`/`db`/`random`,
`client.env` for extra stubs, `:login()`, `:logout()`, `:slash()`, `:said()`, `:fire()`,
`world:advance()`).

API lookups in `reference/SPEC_forever_namespaces.md` at drafting (Task 1 re-checks):
`C_Container.GetContainerNumSlots`, `C_Container.GetContainerItemInfo`, `C_Item.GetItemNameByID`,
`C_Item.RequestLoadItemDataByID`, `C_DateAndTime.GetServerTimeLocal`. Globals and constants (not
in the reference, guarded): `Enum.BagIndex` (its `Backpack`, `Bag_1`…`Bag_4`, `Bank`,
`BankBag_1`…), `UnitLevel`, `date`. Events: `BAG_UPDATE_DELAYED`, `BANKFRAME_OPENED`,
`TIME_PLAYED_MSG`, `PLAYER_ENTERING_WORLD`, `PLAYER_LEVEL_UP`.

## Deliverable

New files `DeadTired/Stash.lua`, `Played.lua`, `EventsList.lua` and `Events.lua` (three modules
registered through `DT.module{}`), plus `tests/test_stash.lua`, `tests/test_played.lua`,
`tests/test_events.lua` and R5's edits:

- **`/dt stash <item>`** asks the guild's sharing members who has it, and prints the answers 10
  seconds later. **`/dt stash share on/off`** sets whether you answer; **`/dt stash`** alone
  shows what your account would offer.
- **`/dt slowest`** prints the *Crypt Keeper's Award for Glacial Progress*: the sharing members
  with the most hours played per level. **`/dt slowest share on/off`** sets whether your `/played`
  is shared.
- **`/dt events`** prints the next occurrence of each event, with a countdown.
  **`/dt events remind on/off`** sets the reminders.

**Testable end:** `DeadTired/tests/run_all.sh` exits 0 with nine suites; and in game, a guildie
with stash sharing on answers Tim's `/dt stash linen` with the right character and count, one
with sharing off doesn't, and `/dt events` names the next Fishing Extravaganza at the right time.

### Stash.lua: specification

**Store.** `DeadTiredDB.stash = { share = false, badStash = 0, chars = { [<Realm-Name>] = {
at = <DT.stamp()>, bags = { [<itemID>] = <count> }, bank = { [<itemID>] = <count> },
bankAt = <DT.stamp()> or nil } } }`. A character's offer is `bags` plus `bank`, summed per item. It is
account-wide, so every character's list is there. Only characters that have run with `share` on
have an entry.

**Scanning** (only while `share` is on and a member):
- **Bags:** at the first `PLAYER_ENTERING_WORLD`, and on `BAG_UPDATE_DELAYED` (at most once per
  5 seconds; a later one inside the window schedules a single rescan at its end). Containers are
  `Enum.BagIndex.Backpack` and `Bag_1`…`Bag_4`. If `Enum.BagIndex` is absent, use 0-4.
- **Bank:** on `BANKFRAME_OPENED`, containers `Enum.BagIndex.Bank` and every `BankBag_n` the
  enum defines. **If `Enum.BagIndex.Bank` is absent, the bank is never scanned**, and `/dt stash`
  says *"(bank not read on this client)"*.
- A bag scan replaces this character's `bags` and `at`; a bank scan replaces `bank` and
  `bankAt`.
- Per slot: `info = clean(try(C_Container.GetContainerItemInfo, bag, slot))`, a table. Skip it
  unless `info.itemID` is a number, `info.stackCount` is a number of 1 or more, and the item is
  known not to be bound *(amended, A4)*: `info.isBound == false`, or, when `info.isBound` is
  `nil`, `C_Item.IsBound(ItemLocation:CreateFromBagAndSlot(bag, slot))` returns `false` (each call
  guarded). Unknown (absent, erroring, secret, not a boolean) means not listed. The share-on line:
  *"stash sharing on. Guildies' searches see your tradeable items, four at a time, and which
  character holds them."* *(amended)*
- Turning `share` off deletes this character's entry. `/dt stash share off` says so.

**Searching, `/dt stash <term>`:** `term` is the text after `stash`, trimmed, 3-32 bytes (else
usage).
- At most one search per **30 seconds** per client (*"One search at a time. The crypt echoes."*).
- Sends `STASHQ {q=<n>, term=<term>}`, prints *"Asking the guild. Answers in 10 seconds."*, and
  after 10 seconds prints the summary.
- **The summary:**
  - one line per answer, in order of arrival: `<holder Name>: <item name> x<count>, …`, with
    item names from `C_Item.GetItemNameByID` (`item <id>` when not loaded, after requesting the
    load);
  - *"Nobody's got it. Or nobody's sharing."* when there are none;
  - then always *"Only guildies running the addon with stash sharing on answer."*

**Answering (receiving `STASHQ`):**
- Only with `share` on, at most once per asker and `q`, after a random 1-5 s delay.
- Match `term` against `C_Item.GetItemNameByID(id)` for every item in every character entry on
  the account, case-insensitive, **plain substring, never a Lua pattern** (`string.find` with
  `plain = true`). Items whose name isn't loaded don't match.
- At most **4** hits, largest count first *(amended; was 5)*.
- Send `STASH {q, to=<asker>, hits=<id>:<count>:<holder name>,…}`, where the holder is the
  character name without its realm. With no hits, send nothing.

**Receiving `STASH`:** only the client whose `charKey()` equals `to` and whose open search is `q`
keeps it, once per sender.
- Validate: `q` 1-6 digits; `to` is `Realm-Name`, 1-64 bytes; `hits` holds 1-4 entries, each
  `^%d+:%d+:[^:,]+$`, with the id at most 7 digits, the count 1-99999 and the holder 1-24 bytes
  *(amended; was 1-5 entries and 1-12 bytes)*.
- Invalid counts in `stash.badStash`. Nothing prints on receipt.

**`/dt stash`** alone: the number of characters and distinct items on this account's list, and
whether the bank is read: *"Your account offers <n> items across <c> characters (bank read
<date> / not read yet / not read on this client). Sharing on."* Or, with sharing off: *"Sharing
off. Nothing offered."*

### Played.lua: specification

**Store.** `DeadTiredDB.played = { share = false, badPlayed = 0, [<guildKey>] = { [<Realm-Name>] =
{ lvl, hours, at } } }`.

- **On `TIME_PLAYED_MSG(total, thisLevel)`**, with `share` on and a member: `lvl` is
  `clean(try(UnitLevel, "player"))`, an integer 1-100; `hours` is `floor(total / 360) / 10` (one
  decimal place). Record your own entry, and send `PLAYED {lvl, h=<hours>}`. If `lvl` or `total`
  is unreadable, nothing. At most one send per 60 s. *(amended, A3)* And only when the `/played`
  stamp is under 10 s old; every `TIME_PLAYED_MSG` clears the stamp.
- **The `/played` hook** *(amended, A3)*: at `ADDON_LOADED`, if `SlashCmdList.PLAYED` is a function,
  `pcall(hooksecurefunc, SlashCmdList, "PLAYED", stamp)`. Not placed: `/dt slowest share on`
  prints *"sharing your /played, but this client hides when you type it. Nothing will be sent."*
- **The addon never calls `RequestTimePlayed`.** The event fires only because the player typed
  `/played`.
- **Receiving `PLAYED`:** validate `lvl` (1-100) and `h` (`^%d+%.?%d?$`, at most 100000). Invalid
  counts in `badPlayed`. Valid entries are stored; nothing prints.
- **`/dt slowest`:** rank every stored entry with `lvl >= 2` by `hours / lvl`, highest first,
  then name. Print at most 5:
  - first: *"The Crypt Keeper's Award for Glacial Progress goes to <Name>: <x.x> hours a level
    (level <lvl>, <hours> h played)."*;
  - then `2. <Name>: <x.x> h/level (level <lvl>)` and so on;
  - empty: *"No contenders. Everyone's either fast or shy."*;
  - then always *"Only guildies running the addon who share their /played. Type /played to
    update yours."*

### EventsList.lua and Events.lua: specification

```lua
ns.EventsList = {
  -- { name, weekday = 1 (Sunday) .. 7 (Saturday), start = "HH:MM", minutes = <length> }, server time
  { name = "Stranglethorn Fishing Extravaganza", weekday = 1, start = "14:00", minutes = 120 },
}
```

- **Server time:** `t = clean(try(C_DateAndTime.GetServerTimeLocal))`, a number, read as
  seconds whose `date("!*t", t)` fields are the server's wall clock. **If it is absent or not a
  number, every events verb says *"Can't read the server clock."* and reminders never fire.**
  Task 1 records the function's presence. G9 records whether its hours match the realm clock.
- **`/dt events`:** for each event, the next start at or after now (or *"on now, <m> min left"*
  while it runs): `<name>: <Weekday> <HH:MM> server time, in <d>d <h>h <m>m.` (dropping zero
  leading units). Then *"Times are server time."*
- **Reminders** (with `remind` on, a member): a 60-second ticker started at the first
  `PLAYER_ENTERING_WORLD`. At most one *"<name> in 30 minutes. Bring a rod, or a grudge."*, when
  the start is 30 minutes away or less (and more than 0). At most one *"<name> has started."* in
  the event's first 10 minutes. Each fires at most once per occurrence, keyed by event and start
  time, in memory only.

## Working rules

- **Opt-in, all three.** Stash, played and reminders are all off until switched on. With each
  off, its module sends nothing, prints nothing unasked, and (for stash) keeps no list.
- **What leaves the client:** stash answers to a search (matching items only, at most 4 *(amended)*), and
  PLAYED (`lvl`, `h`). Nothing else from this card. No full inventory, ever.
- **No combat data.** No `COMBAT_LOG`, `CombatLog*`, `C_DeathRecap`, `UNIT_DIED`, `PARTY_KILL`.
- **Nothing public.** No `SendChatMessage` in this card's files. **No `RequestTimePlayed`**
  anywhere.
- **Plain matching.** A search term from another player is passed to `string.find` with
  `plain = true`, never used as a pattern.
- **Every API call guarded**, with absence handled as specified.
- **Card 1 is read-only** except for R5. If a module needs a change to Core, Comms, Roster,
  Config or the harness, **stop** (ROADMAP rule 5). Stubs go in the new test files, on
  `client.env`.
- **Inbound data is data**, printed through `DT.safe` / `DT.display`.
- **Quiet:** nothing prints at login or on receipt. The only unasked output is an opted-in
  reminder, or the summary of a search the player started.

## Tasks

1. **Re-verify.** Check P1. Check every *Builds on* name and API lookup. Record in the report
   that `Enum.BagIndex` isn't in the reference (it lists `C_*` functions only), so the bank code
   runs only behind the `Enum.BagIndex.Bank` guard.
2. Apply R5. Create the data file and the three modules with their stores and verbs (usage
   strings, no bars). Add the three suites, covering store creation. `run_all.sh` green.
3. **Stash scanning** and its tests: bags at login and on `BAG_UPDATE_DELAYED` with the 5 s
   window; bound items skipped, and bound status unknown skipped *(amended, A4)*; bad slot info skipped; the bank on `BANKFRAME_OPENED`; the bank
   never read when `Enum.BagIndex.Bank` is absent; bags and bank summed; sharing off means no
   scan; turning it off deletes the entry; an alt on the same account adds its own entry. Green.
4. **Stash search and answers**, three clients (sharing, sharing off, asker). Cover:
   - the 30 s window; the term length limits; a sharing member answers once, after 1-5 s;
   - an alt's items answer under the alt's name;
   - at most 4 hits, largest first *(amended)*; no hits means no answer;
   - a term like `%a+` or `[` matches literally and never errors;
   - a non-sharing member sends nothing;
   - the summary text and order; late answers ignored; answers to others ignored;
   - each invalid field counts in `badStash`; nothing prints on receipt;
   - `/dt stash` alone, in each state. Green.
5. **Played** and its tests: `TIME_PLAYED_MSG` with sharing on records and sends; sharing off
   sends nothing; the 60 s window; only after a typed `/played`, inside 10 s *(amended, A3)*;
   unreadable level or total; validation; ranking and its
   tie-break; level 1 excluded; the award line and the list lines exactly; the empty text; the
   closing line. A test asserts `RequestTimePlayed` is never called (stub it to count calls,
   then run a full login and a day of ticks). Green.
6. **Events** and its tests, with the server clock stubbed: the next occurrence later this week,
   later today, and next week; "on now"; the countdown format; the clock absent; reminders off by
   default; on: the 30-minute line once, the start line once, nothing outside the window, nothing
   for a non-member, and none twice for one occurrence. Green.
7. **Byte budget:** the longest `STASH` (4 hits of a 7-digit id, count 99999 and a 24-byte *(amended)*
   holder; `q` 999999; a 64-byte `to`), the longest `STASHQ` (a 32-byte term of `^`), and the
   longest `PLAYED` are each at most 250 bytes. Worked at drafting: STASH 224, STASHQ 119; after the amendment, STASH 245.
8. **Full-addon check:** all eleven files (card 1's seven plus four) on two members and a
   non-member. A login prints only card 1's welcome; a stash search works end to end; the
   non-member sends and prints nothing.
9. **Grep checks:** `RequestTimePlayed` and `SendChatMessage` don't appear in this card's
   non-test files (G3).
10. **Guard proofs.** Remove once, confirm a check goes red, restore:
    - stash: the `share` gate on scanning; the `share` gate on answering; the bound-item skip;
      the bank-constant guard; plain matching (change it to pattern matching, and see the `%a+`
      check go red); the 4-hit cap *(amended)*; one answer per asker and search; `STASH` addressed to
      someone else ignored; `STASH` validation; the 30 s search window;
    - played: the `share` gate on sending; the 60 s window; `PLAYED` validation; the level-1
      exclusion;
    - events: the reminder `remind` gate; the once-per-occurrence rule; the 30-minute window.
11. Write the report and push the branch.

## Explicitly out of scope

- **The crafting request board** (R1): no request messages, no "who can make X" (card 2).
- **Sending a full inventory, a bag snapshot, or a stash "sync".** Searches only.
- **The guild bank** (classic has none), mail, auction listings, equipped gear, or another
  account's bags.
- **Calling `RequestTimePlayed`**, reading `/played` at login, or estimating play time from
  session length.
- **Other awards** (fastest leveller, most deaths, most ganks) and announcing any award in guild
  chat. `/dt slowest` prints to the asker only.
- **The in-game calendar (`C_Calendar`)**, Raid-Helper events, Darkmoon Faire or holiday
  schedules, and events that move. The roadmap says calendar work needs its own probe first.
- **Converting server time to local time** in the output. Server time only, labelled.
- **Sound, a toast, a panel, or a minimap icon** for reminders.
- **Other cards:** death notices (3), gank diary (4), raid-prep and recruitment (5),
  professions (2).
- **Any change to card 1's files** beyond R5 (ROADMAP rule 5: stop and report instead).

## The one deliberate widening, named

**Other players can ask about your bags.** Card 5 shared a yes/no verdict about your bags; this
card answers *what* you hold, and *which of your characters* holds it, when a guildie searches.
R2 rules it. What still bounds it:
- off until you switch it on;
- tradeable items only;
- only items matching the search, at most 4 per answer *(amended)*;
- nothing sent unless asked;
- the term matched as plain text;
- your list deleted when you switch sharing off.

(Play time is also new, but it is CLAUDE.md's own example of opt-in personal data. R3 adds that
the addon never asks the game for it.)

## Stop conditions

- P1 fails (no `card/dt_foundation`, or its suites red) → stop.
- Any of R1-R6 still `proposed`, or R6 ruled "wait" → stop.
- Task 1 finds a *Builds on* name, or any of the five `C_*` lookups, missing → stop and report.
  Don't substitute another function.
- A module needs a change to a card 1 file beyond R5 → stop (ROADMAP rule 5).
- Any design choice needs `RequestTimePlayed`, a full-inventory send, public chat or combat data
  → stop.
- Any of Task 7's messages exceeds 250 bytes → stop.
- A guard removal in Task 10 leaves every check green → stop.
- In game (Tim): any Lua error at load; a stash answer naming a bound item; anything sent with
  sharing off; the played lines appearing in chat without you typing `/played`; a reminder with
  reminders off → stop, and remove the offending file from the `.toc`.

## UAT: acceptance checks

Extracted verbatim to `docs/UAT_dt_stretch.md`.

**Offline (the build session runs these):**
- [ ] `[G]` G1: `DeadTired/tests/run_all.sh` exits 0 and runs nine suites (core, guild, comms,
  roster, alts, welcome, stash, played, events).
- [ ] `[G]` G2: the report lists all seventeen Task 10 guard removals, each with the check that
  went red.
- [ ] `[G]` G3:
  `grep -rnE "RequestTimePlayed|SendChatMessage|COMBAT_LOG|CombatLog|C_DeathRecap|C_Calendar" DeadTired/ --include=*.lua | grep -v "/tests/"`
  finds nothing.
- [ ] `[G]` G4: `git diff card/dt_foundation --stat -- DeadTired/` lists only the four new files,
  the three new suites, `DeadTired.toc` (4 lines added) and `tests/run_all.sh` (1 line changed).
- [ ] `[G]` G5: the report gives the byte length of the longest STASH, STASHQ and PLAYED, each
  at most 250.

**In game (Tim, with one or two guildies, all on this branch):**
- [ ] `[G]` G6: `/reload` shows no Lua error, and the only line printed is card 1's welcome.
- [ ] `[G]` G7: guildie A runs `/dt stash share on`, then opens their bank once; guildie B leaves
  sharing off. Tim's `/dt stash linen`: after 10 s, A's character and the right count are listed
  (bank included), and B isn't. A soulbound item searched by name never appears.
- [ ] `[G]` G8: Tim runs `/dt slowest share on` and then types `/played`. A guildie's
  `/dt slowest` lists Tim's character with hours per level matching `/played ÷ level` to one
  decimal place. No `/played` lines ever appeared in Tim's chat except when he typed it.
- [ ] `[G]` G9: `/dt events` names the next Fishing Extravaganza. Its day and time match
  Forever's real schedule and the realm clock. If they don't, write down the real schedule (it
  goes in `EventsList.lua`) and the clock's offset.
- [ ] `[G]` G10: `/dt events remind on` with an event 35 minutes away (edit `EventsList.lua`
  locally to make one): one line 30 minutes before, one at the start, nothing else. Then
  `/dt events remind off`: nothing.
- [ ] `[G]` G11 *(amended: new, A3)*: with `/dt slowest share on`, Tim types `/played`: the guildie's board
  gets Tim's line. Then `/script RequestTimePlayed()`: nothing new is sent (the guildie's board is
  unchanged).
- [ ] `[G]` G12 *(amended: new, A4)*: with stash sharing on and a soulbound item in Tim's bags, the guildie
  searches for it: no answer names it.
- [ ] `[H]` H1: **would the slowest leveller laugh at the award, or feel singled out?**

**`[H]` count: 1.** Whether a joke award lands on the person it names is the guild's call, and
only a person can make it. If H1 is "singled out", `/dt slowest` is removed from the `.toc`
before merge; nothing else depends on it.

## Reporting

Report: `docs/COWORK_REPORT_dt_stretch.md`. Walk-sheet: `docs/UAT_dt_stretch.md` (Tim fills in
`docs/UAT_dt_stretch_results.md` after walking it; the build session never writes that file).
The report records:
- the starting branch and commit, and Task 1's lookups, each found or not, including what is
  known about `Enum.BagIndex`;
- R1-R6 as ratified, and any place the build had to read them;
- the exact player-facing lines as built, so H1 and the tone can be judged from the report;
- one encoded STASHQ, STASH and PLAYED, and the longest of each with its byte length;
- each Task 10 removal and the check that went red;
- the `git diff card/dt_foundation --stat -- DeadTired/` output;
- the output of `run_all.sh`;
- the merge order for the `.toc` and `run_all.sh` lines with cards 3, 4 and 5;
- anything left undone, and every stop condition that tripped.
