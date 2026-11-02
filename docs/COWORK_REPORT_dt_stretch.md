# Cowork report: dt_stretch (card 6)

Brief: `docs/COWORK_BRIEF_dt_stretch.md` (R1-R6 ratified 2026-11-02, as proposed; R6: build now).
Walk-sheet: `docs/UAT_dt_stretch.md`. Built 2026-11-02 in a cloud session, offline only. G6-G10
and H1 are Tim's to walk.

**Result:** stash search, the slowest-leveller award and the event tracker are built. All nine
suites are green (271 checks: 48 stash, 23 played, 26 events). All seventeen guards, plus two
extra checks, were proved red, and **no stop condition tripped**. The one finding (the 12-byte
holder limit dropped accented names, *Differences* 1) was **ruled by Tim: 4 hits, holders up to
24 bytes**, and is fixed on this branch (see *Amendment*).

## Branch and start

- Branch **`card/dt_stretch`**, created from `origin/card/dt_foundation` at **`61fe2d3`**. Nothing
  was read from the card 3, 4 or 5 branches. The brief and walk-sheet were brought over from
  `claude/loving-meitner-yzdxtn` and stamped ratified.
- P1: `card/dt_foundation` is on origin at `61fe2d3`, and `run_all.sh` → exit 0. P2: R1-R6 are
  ratified, and R6 says build now.

## Task 1: re-verification

- *Builds on*: every name found unchanged at `61fe2d3`.
- `reference/SPEC_forever_namespaces.md`: `C_Container.GetContainerNumSlots`,
  `C_Container.GetContainerItemInfo`, `C_Item.GetItemNameByID`, `C_Item.RequestLoadItemDataByID`,
  `C_DateAndTime.GetServerTimeLocal`: all found.
- **`Enum.BagIndex` is not in the reference** (it lists `C_*` functions only, not enums). Its
  names (`Backpack`, `Bag_1`…`Bag_4`, `Bank`, `BankBag_n`) are retail's. The bags fall back to
  0-4 if it is absent. **The bank is read only when `Enum.BagIndex.Bank` exists**; otherwise
  `/dt stash` says *"bank not read on this client"*.
- `UnitLevel`, `date` and the events `BAG_UPDATE_DELAYED`, `BANKFRAME_OPENED`,
  `TIME_PLAYED_MSG` and `PLAYER_ENTERING_WORLD` are guarded or registered under card 1's `pcall`.
  `PLAYER_LEVEL_UP` turned out not to be needed: nothing in this card reacts to a level-up.

## R1-R6 as built

- **R1:** no request board code; nothing about crafting.
- **R2:** stash sharing is off by default. Scans happen only with it on (and as a member). Bound
  items are skipped, bags are scanned at login and on bag changes, and the bank when it is
  opened. The list is account-wide, and answers name the holding character. An answer holds
  matching items only, at most 4 (after the amendment), and is sent only in reply to a search. Terms are matched with
  `string.find(…, 1, true)`.
- **R3:** PLAYED is sent only from `TIME_PLAYED_MSG`, which fires when the player types
  `/played`. Nothing in `DeadTired/` names the function that asks the game for play time (G3,
  and a test counts calls to a stub of it over a day: 0).
- **R4:** `EventsList.lua` holds the one event as specified. Reminders are off by default.
- **R5:** four `.toc` lines and one `run_all.sh` line (G4). The version is still `0.1.0`.
- **R6:** built now.

## Differences from the brief

1. **Finding (resolved, see *Amendment*): holder names over 12 bytes were left out of stash
   answers.** The brief caps a
   holder at 12 bytes on the wire, to keep the longest STASH under 250 bytes. But character
   names can be up to 12 *letters*, and accented letters are 2 bytes each in UTF-8. "Ståhlgéhéim"
   is 11 letters and 14 bytes. Such a character's items are silently missing from answers. Rather
   than widen the wire format (that would break the stop condition: 24-byte holders make the
   longest STASH 284 bytes), I kept the brief's limit and flagged it. Fixes for a later round,
   Tim's call:
   - send at most 4 hits (24-byte holders fit in 4);
   - or let a long STASH chunk (card 1 supports chunking);
   - or send the holder's position in the asker-visible roster instead of the name.
   The behaviour is tested ("a holder name over 12 bytes is left out of answers").
2. **Sharing off deletes the whole account's list**, not just this character's entry. The
   `share` setting is account-wide, and the widening section says "your list deleted when you
   switch sharing off". A leftover alt's list that nobody could see would still be bag data
   kept for no purpose.
3. **Sharing on scans the bags at once**, so a search a minute later can be answered without
   waiting for a bag change or a relog.
4. **The share gate is checked twice**, as in card 5: when a search arrives (the specified
   gate) and again when the 1-5 s delay ends. Both are proved.
5. **An invalid `STASHQ`** (bad `q`, or a term outside 3-32 bytes) also counts in `badStash`.
6. **`/dt stash share…` is reserved:** `share`, `share on` and `share off` are settings, so an
   item whose name starts "share " can't be searched for. No such item is known.
7. **`/dt events remind on/off` works without a server clock** (it is a setting); only the list
   and the reminders need the clock.
8. **An unloaded item in a summary** shows as `item <id>`, and its load is requested, as the brief
   says. A second search shows the name.
9. **Wording:** `/dt stash` alone says "1 item", "1 character" in the singular. The brief's
   template had only plurals.

## Player-facing lines, for H1

| When | Line (after `Dead Tired `) |
|---|---|
| `/dt stash <term>` | `Asking the guild. Answers in 10 seconds.`, then `Ghoulalt: Linen Cloth x60` / `Ghoul: Linen Cloth x20, Bolt of Linen Cloth x4`, then `Only guildies running the addon with stash sharing on answer.` |
| No answers | `Nobody's got it. Or nobody's sharing.` |
| A second search inside 30 s | `One search at a time. The crypt echoes.` |
| `/dt stash` | `Your account offers 4 items across 1 character (bank read 2026-11-04). Sharing on.` / `Sharing off. Nothing offered.` |
| `/dt stash share on` / `off` | `stash sharing on. Guildies' searches can see your tradeable items, four at a time.` / `stash sharing off. Your list is gone; your bags are your own again.` |
| `/dt slowest` | `The Crypt Keeper's Award for Glacial Progress goes to Turtle: 7.0 hours a level (level 30, 210.0 h played).`, then `2. Sloth: 5.0 h/level (level 10)` …, then `Only guildies running the addon who share their /played. Type /played to update yours.` |
| No contenders | `No contenders. Everyone's either fast or shy.` |
| `/dt slowest share on` / `off` | `sharing your /played. Type /played to put yourself on the board.` / `not sharing your /played. Your pace is your own.` |
| `/dt events` | `Stranglethorn Fishing Extravaganza: Sunday 14:00 server time, in 6d 3h 30m.` (or `on now, 120 min left.`), then `Times are server time.` |
| No clock | `Can't read the server clock.` |
| Reminders | `Stranglethorn Fishing Extravaganza in 30 minutes. Bring a rod, or a grudge.` / `Stranglethorn Fishing Extravaganza has started.` |
| `/dt events remind on` / `off` | `reminders on. You'll hear 30 minutes before, and at the start.` / `reminders off. Miss things in peace.` |

## Wire

```
1^STASHQ^q~1^term~Linen                                                              23 bytes
1^STASH^hits~2589:60:Ghoulalt,2589:20:Ghoul,2996:4:Ghoul^q~1^to~Classic Beta PvP-Stromham   89 bytes
1^PLAYED^h~100.5^lvl~30                                                              23 bytes
```

**Longest:** STASH **245** bytes after the amendment (4 hits of a 7-digit id, count 99999 and a
24-byte holder; `q`
999999; a 64-byte `to`), STASHQ **119** (a 32-byte term of `^`), PLAYED **27**. All are at most
250, as worked at drafting.

## Task 10: guard proofs

Each guard (marked `-- guard: …`) was broken by script, `run_all.sh` was run, and the file was
restored. The suites were green again afterwards.

| # | Guard | Broken by | Checks that went red (first few) |
|---|---|---|---|
| 1 | Stash: `share` gate on scanning | line deleted | "sharing off: no scan at login, no list", "sharing off: no scan on bag or bank events" |
| 2 | Stash: `share` gate on answering | line deleted | "a member with sharing off sends nothing and doesn't note the question" |
| 2b | Stash: `share` gate at answer time (extra) | line deleted | "sharing turned off before the delay ends: no answer" |
| 3 | Stash: bound-item skip | condition → `true` | "a bound item is never listed", plus 2 more |
| 4 | Stash: bank-constant guard | line deleted | "Enum.BagIndex.Bank absent: the bank is never read", "and /dt stash says so" |
| 5 | Stash: plain matching | `find(want, 1, true)` → `find(want)` | "a term like %a+ or [[[ matches literally and never errors" |
| 6 | Stash: 4-hit cap (amended from 5) | line deleted | "at most 4 hits, largest first" |
| 7 | Stash: one answer per asker and search | line deleted | "one answer per asker and search", plus 5 more |
| 8 | Stash: `STASH` to someone else ignored | line deleted | "an unloaded item shows as item <id>…", "an answer after the summary is ignored", plus 1 more |
| 9 | Stash: `STASH` validation | condition → `false` | "each invalid STASH / STASHQ field is counted in badStash, nothing printed" |
| 10 | Stash: 30 s search window | condition → `false` | "a second search inside 30 s is refused", "after 30 s a new search goes out" |
| 11 | Played: `share` gate on sending | line deleted | "sharing off: /played sends and records nothing", plus 3 more |
| 12 | Played: 60 s window | line deleted | "a second /played inside 60 s sends nothing", plus 5 more |
| 13 | Played: `PLAYED` validation | condition → `false` | "each invalid PLAYED is counted in badPlayed and not stored" |
| 14 | Played: level-1 exclusion | condition → `true` | "the award line, exactly", "at most 5, level 1 left out, then the closing line", plus 1 more |
| 15 | Events: `remind` gate | line deleted | "reminders off by default: nothing", "/dt events remind off: nothing" |
| 16 | Events: once per occurrence (30-minute line) | condition → `true` | "only once before the start", plus 3 more |
| 16b | Events: once per occurrence (start line, extra) | condition → `true` | "nothing else that day", "next week: one more pair, no more" |
| 17 | Events: 30-minute window | condition → `untilStart > 0` | "nothing more than 30 minutes before", "the 30-minute line, exactly", plus 4 more |

A note on 7: removing "one answer per search" also broke the later checks in the same test. Each
extra answer shifts the answer counts the following checks rely on, so the red is real but wide.

## Amendment: 4 hits, 24-byte holders (Tim, 2026-11-02)

Tim ruled on finding 1: **use 4 hits.** Changed on this branch, in one commit after the build:
- **`Stash.lua`:** `MAX_HITS = 4`, a new `HOLDER_MAX = 24` used both when answering (a holder
  over 24 bytes is still left out: no real name is) and when validating a received `STASH`; the
  share-on line now says "four at a time".
- **`tests/test_stash.lua`:**
  - the cap check now expects 4;
  - a 12-letter fully accented holder name (24 bytes) **is** answered, and a 25-byte one isn't;
  - a received answer with a 24-byte holder is kept and printed;
  - validation now rejects 25-byte holders and 5 entries;
  - the byte budget uses 4 hits with 24-byte holders: **245 bytes**.
- **The brief** carries an *Amended* note at the top, and each changed line is marked
  *(amended)*. The walk-sheet's checks don't mention the hit count and are unchanged.
- **Guard proofs re-run for all eleven stash guards** after the change: each still goes red,
  including the 4-hit cap ("at most 4 hits, largest first") and validation.

## Offline acceptance

- **G1:** `run_all.sh` exits 0 with nine suites:

```
core: 44 passed, 0 failed
guild: 13 passed, 0 failed
comms: 53 passed, 0 failed
roster: 26 passed, 0 failed
alts: 21 passed, 0 failed
welcome: 17 passed, 0 failed
stash: longest STASH is 245 bytes, longest STASHQ is 119 bytes
stash: 48 passed, 0 failed
played: longest PLAYED is 27 bytes
played: 23 passed, 0 failed
events: 26 passed, 0 failed
ALL GREEN
```

- **G2:** the table above lists all seventeen (and 2b, 16b).
- **G3:**
  `grep -rnE "RequestTimePlayed|SendChatMessage|COMBAT_LOG|CombatLog|C_DeathRecap|C_Calendar" DeadTired/ --include=*.lua | grep -v "/tests/"`
  finds nothing (exit 1). Neither function name appears anywhere in `DeadTired/`, tests included:
  `test_played.lua` builds its stub's name as `"Request" .. "TimePlayed"`.
- **G4:** `git diff card/dt_foundation --stat -- DeadTired/`:

```
 DeadTired/DeadTired.toc         |   4 +
 DeadTired/Events.lua            | 135 ++++++++++++++++++
 DeadTired/EventsList.lua        |  10 ++
 DeadTired/Played.lua            | 117 +++++++++++++++
 DeadTired/Stash.lua             | 305 ++++++++++++++++++++++++++++++++++++++++
 DeadTired/tests/run_all.sh      |   2 +-
 DeadTired/tests/test_events.lua | 142 +++++++++++++++++++
 DeadTired/tests/test_played.lua | 136 ++++++++++++++++++
 DeadTired/tests/test_stash.lua  | 266 +++++++++++++++++++++++++++++++++++
```

  (`run_all.sh`: one line changed, counted by git as one removed and one added.)
- **G5:** STASH 245 (224 before the amendment), STASHQ 119, PLAYED 27; all at most 250.

## Merge order with cards 3, 4 and 5

All four card branches append at the same two places. When merging into `main`, keep every line,
in card order:
- **`.toc`, after `Welcome.lua`:** `Crypt.lua`, `Gank.lua`, `PrepList.lua`, `Prep.lua`,
  `RecruitLines.lua`, `Recruit.lua`, `Stash.lua`, `Played.lua`, `EventsList.lua`, `Events.lua`;
- **`run_all.sh`:** `… welcome:Welcome crypt:Crypt gank:Gank prep:Prep recruit:Recruit stash:Stash played:Played events:Events; do`.

Card 5's report notes that the other cards' `SendChatMessage` greps need card 5's one line
excepted once it is on `main`. This card adds no new exception.

## For Tim's walk

- **G7:** the bank is read when the guildie *opens* it, so they must visit a banker once after
  `/dt stash share on`. If `/dt stash` says "bank not read on this client", the client lacks the
  bank constant, and G7's "bank included" part can't pass. Write that down.
- **G8:** the addon never triggers `/played`; Tim types it. The guildie's `/dt slowest` updates
  once the PLAYED message arrives (immediately; there's no 10-second wait as in the searches).
- **G9:** if the day or hour is wrong, the fix is one line in `EventsList.lua`. If the clock
  itself is off (the countdown doesn't match the realm clock), note the offset:
  `GetServerTimeLocal` may not mean what the brief assumes on this client.

## Not provable offline

- `Enum.BagIndex` and the bank's container numbers on Forever;
- whether `GetContainerItemInfo` reports `isBound` as retail does (if it doesn't, bound items
  would be listed: G7's soulbound check catches that, and it is a stop condition);
- `GetServerTimeLocal`'s meaning;
- the Fishing Extravaganza's real schedule;
- whether `TIME_PLAYED_MSG` passes `(total, thisLevel)` in that order.

## Left undone, stop conditions

- Nothing in Tasks 1-11 is left undone.
- Stop conditions: none tripped. P1/P2 hold; R6 is "build now"; nothing is missing from
  *Builds on* or the API lookups; no card 1 file changed beyond R5; nothing needs the play-time
  request, a full-inventory send, public chat or combat data; every message is at most 250 bytes;
  every guard removal went red.
- `docs/UAT_dt_stretch_results.md` was not written; that file is Tim's.

## Rulings round (A3, A4)

Built 2026-11-02 from `docs/COWORK_BRIEF_dt_rulings.md` (Task 4), on `card/dt_stretch` after merging
`main` (which brought only `CLAUDE.md` and the rulings brief and walk-sheet; no card 1 file changed).

**A3, `Played.lua`:**
- At `ADDON_LOADED` (the module's `init`): if `SlashCmdList.PLAYED` is a function and
  `hooksecurefunc` exists, `pcall(hooksecurefunc, SlashCmdList, "PLAYED", stamp)`; `stamp` records
  `DT.now()`. Otherwise, or if the hook errors, no stamp is ever made.
- On `TIME_PLAYED_MSG`: the stamp is read and **cleared on every event**, then the report is used
  only if the stamp existed and is under 10 s old; then the existing share gate, member check,
  readable level/total and 60 s window apply. No hook means no stamp, so nothing is ever sent.
  (I first also checked a `hooked` flag there; it could not be proved red, being redundant with
  the stamp, so I removed it.)
- `/dt slowest share on` with no hook prints one line saying nothing will be sent (below).
- `RequestTimePlayed` is still never called: R5's grep over `DeadTired/` (tests excluded) finds
  nothing.
- **In-game risk, not provable offline:** the chat system can cache slash handlers
  (`hash_SlashCmdList`). If Forever's client cached `/played` before our hook was placed, the hook
  never fires and nothing is sent even when typed. That fails safe; G11 will show it.

**A4, `Stash.lua`:**
- A slot is listed only if `clean(info.isBound) == false`, or, when that is `nil`,
  `C_Item.IsBound(loc) == false` where `loc = ItemLocation:CreateFromBagAndSlot(bag, slot)`.
  On retail `C_Item.IsBound` takes an item location, not a bag and slot, so the location is built
  through the client's `ItemLocation` global (guarded: absent or erroring means unknown). Any
  other answer (true, nil, an error, a secret, a non-boolean) means not listed. Bags and bank use
  the same `scan`.
- The share-on line now says answers name the holding character (below).

**Player-facing lines, new or changed:**
- Changed (A4): `stash sharing on. Guildies' searches see your tradeable items, four at a time, and which character holds them.`
  (was `stash sharing on. Guildies' searches can see your tradeable items, four at a time.`)
- New (A3): `sharing your /played, but this client hides when you type it. Nothing will be sent.`

**Tests:** `test_played.lua` 23 → 47; `test_stash.lua` 48 → 74.
- Played: the client stub now provides the game's `SlashCmdList.PLAYED` and `hooksecurefunc`
  before `ADDON_LOADED`; existing checks type `/played` before each report. New block *A3*:
  hook placed; event with no typed `/played` → nothing; typing still runs the game's command; typed
  then the event at 9.5 s → sent; stamp cleared after the send; a second event → nothing; the
  event 11 s after → nothing; a report another addon asked for → ignored; the addon's own request
  count stays 0 (the one call is the test playing the other addon); hook absent, no
  `hooksecurefunc`, or `hooksecurefunc` erroring → not placed, share-on says so in one line,
  nothing ever sent; a `/played` command appearing after load is not hooked → nothing sent.
- Stash: `C_Item.IsBound` and `ItemLocation.CreateFromBagAndSlot` stubbed per slot. For a bag, the
  bank, and a bank bag: `isBound` false listed, true skipped; nil with `IsBound` false listed, true,
  nil, erroring or non-boolean skipped. With `C_Item.IsBound` absent, `ItemLocation` absent,
  `CreateFromBagAndSlot` erroring, or the answer secret: `isBound == false` still listed, unknown
  skipped. The share-on line checked exactly.

**Guard proofs:**

| Guard removed | Checks that went red |
|---|---|
| A3 typed-`/played` window (whole condition → `if false`) | 10, incl. *the event with no typed /played sends nothing*, *a report someone else asked for: ignored*, *hook absent: nothing is ever sent* |
| A3 window age only (`DT.now() - at >= 10` dropped) | *the event 11 s after the typed /played: nothing* and 3 more |
| A3 stamp cleared (`typedAt = nil` removed) | *the stamp is cleared after the send*, *and that stale stamp is gone too* |
| A4 unknown → not listed (put back to `isBound ~= true`) | 13, incl. *isBound nil, C_Item.IsBound nil: skipped* (bags, bank, bank bag), *a secret IsBound answer* |
| A4 IsBound result ignored (`nil` treated as listed) | the same 13 |

**Note on the stamp-clear proof:** behaviourally the stamp clear is shadowed by the existing 60 s
send window (a stamp lives 10 s, so any second report it could let through is already inside 60 s
of the send). The proof therefore reads the stamp through the test hook `DT._played.stamp()`.
This is test-side only and is the check that goes red.

Each restored; `run_all.sh` exits 0 (stash 74, played 47, events 26; all suites green).

## Fix round 1 (F8b, F6d, F9)

Built 2026-11-02 from `docs/COWORK_BRIEF_dt_fixes1.md` (audit AUD-03, AUD-07, AUD-09). Round
report: `docs/COWORK_REPORT_dt_fixes1.md` on the session branch. `card/dt_foundation` (F1-F5) was
merged in first: clean, card 1's files identical to its branch, all suites green before these
fixes.

- **F8b, `Stash.lua`:** a search's id is `time() % 1000000` (guarded; the old counter only if the
  clock can't be read). Wire and validation unchanged.
- **F6d, `Stash.lua`:** a received STASHQ, with sharing on, is answered at most once per asker per
  30 s (memory only); the rest count in `stash.dropped`.
- **F9, `Played.lua`:**
  - `/dt slowest share off` removes this character's own entry, sends one `PLAYED {off=1}` via
    `DT.send` (member-gated, queued, held while restricted), and prints the new line below.
  - A received `PLAYED` with `off`: exactly `off~1` and no `lvl`/`h` deletes the sender's entry;
    anything else with `off` counts in `badPlayed`.
  - Every entry (own and received) stores `t = time()`. `prune()` drops entries older than 30
    days, or with no numeric `t` (only possible for entries from before this round; no member has
    any), at `ADDON_LOADED` and at the start of `/dt slowest`. If `time()` can't be read, nothing
    is dropped.
  - Guildies who are offline when you switch sharing off keep your entry until it ages out (30
    days). The message isn't stored for them.
- **Changed player-facing line** (share off), was *"not sharing your /played. Your pace is your
  own."*, now: *"not sharing your /played. Your entry is being withdrawn from guildies' boards."*
- **Tests:** stash: checks pinning `q~1` compute the id from the stub clock; STASHQ injections
  that came from one asker within 30 s now come from one asker each. New F8b (3) and F6d (4).
  played: *"/dt slowest share off: nothing sent"* became *"... no play time sent after it, only the
  one withdrawal (F9)"*; new F9 (14 checks: the withdrawal message and line, delete online, the
  award, malformed `off`, an offline guildie keeps it to 30 days, dropped after; at load: over 30
  days, no `t`, recent kept, no clock). stash 81, played 61, events 26.
- **Guard proofs:** F8b counter put back: 9 red, incl. *F8b: after the asker's /reload, the
  search is answered*. F6d removed: 4 red. F9 delete removed: *F9: a guildie online deletes B's
  entry on off~1*, *F9: and B is off A's award*. F9 30-day drop removed: *F9: past 30 days, /dt
  slowest drops it before printing*, *F9: at load, an entry over 30 days old is dropped*, *F9: at
  load, an entry with no time is dropped*.
- The audit's `test_stash_reload.lua` passes unchanged.
