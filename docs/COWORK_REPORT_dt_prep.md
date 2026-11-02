# Cowork report: dt_prep (card 5)

Brief: `docs/COWORK_BRIEF_dt_prep.md` (R1-R5 ratified 2026-11-02, as proposed). Walk-sheet:
`docs/UAT_dt_prep.md`. Built 2026-11-02 in a cloud session, offline only. G6-G11 and H1 are Tim's
to walk.

**Result:** the four files are built, all eight suites are green (249 checks: 42 prep, 33
recruit), all twelve guards were proved red on the first run (plus a thirteenth, see Task 10), and
**no stop condition tripped**. **One thing for Tim to rule on before walking:** the recruitment
lines were written for channel 1 (General), but R2 ratified `LookingForGroup` (see *P3*).

## Branch and start

- Branch **`card/dt_prep`**, created from `origin/card/dt_foundation` at **`61fe2d3`**. Nothing
  was read from `card/dt_crypt` or `card/dt_pvp`. The brief and walk-sheet were brought over from
  `claude/loving-meitner-yzdxtn` and stamped ratified.
- P1: `card/dt_foundation` is on origin at `61fe2d3`, and `run_all.sh` → exit 0. P2: R1-R5 are
  ratified.

## P3: the recruitment lines

Tim attached `dead-tired_recruitment_2026-11-01.md` to the session. Its section *"In-game
recruitment lines (from the 2026-11-01 session, 255-char safe)"* holds exactly five lines. They
were copied into **`docs/RECRUIT_lines.md`** (numbered 1-5) by script, not retyped. The Discord
post and checklist in the same file were left out; they aren't this card's.

**One change, made deliberately:** each line in Tim's file starts with `/1 `. That is the chat
command for channel 1, not part of the message: posting it would put a literal "/1" in front of
every line. It was dropped, and the rest of each line is byte-for-byte Tim's. The addon picks the
channel itself (R2).

**The channel question this raises:** `/1` is General. The lines were written to go there, while
R2 ratified `LookingForGroup`. The build follows the ratified R2. If Tim wants General, it's one
value in `RecruitLines.lua` (`RECRUIT_CHANNEL`), changed before the walk. Note that General is
per-zone and is named after the zone ("General - Orgrimmar"), so `GetChannelName("General")` may
not find it on this client. That would need a probe, so it's not a blind swap.

| Line | Bytes | Begins |
|---|---|---|
| 1 | 206 | `Adventurers, hear my call! ...is what we'd shout if we had the energy.` |
| 2 | 194 | `Do your knees click when you /sit? Is "one more pull" your bedtime story?` |
| 3 | 163 | `Forsaken Paladins: the Light has abandoned you, and so has your sleep schedule.` |
| 4 | 173 | `The Scourge offered us eternal unlife. We asked if it came with a lie-in.` |
| 5 | 158 | `<DEAD TIRED> LFM Tanks, Heals, DPS, and anyone who's mastered the 9pm power nap.` |

All five are plain ASCII, contain no `|` and no control bytes, and are at most 255 bytes, so the
lines check passes (no stop). `RecruitLines.lua` is generated from `docs/RECRUIT_lines.md`, and
`test_recruit.lua` checks the two are byte-identical (G5).

## Task 1: re-verification

- *Builds on*: every name found unchanged at `61fe2d3` (Core, Comms, Guild, Roster, harness; as
  for cards 3 and 4).
- API lookups in `reference/SPEC_forever_namespaces.md`: `C_Item.GetItemCount`,
  `C_Item.GetItemNameByID`, `C_Item.RequestLoadItemDataByID`, `C_ChatInfo.SendChatMessage`,
  `C_ChatInfo.InChatMessagingLockdown`: all found. `GetChannelName`, `UnitClass` and `time` are
  globals, guarded.

## R1-R5 as built

- **R1:** one line in `DeadTired/` (non-test) names the chat-send function: `Recruit.lua:64`,
  inside `post()`, which only the `recruit` verb calls. It is called through `pcall`, never
  from a timer, a queue or an event. Task 7's test runs 24 game hours of logins, zoning, guild
  updates, roll calls and received messages (including a crafted `RECRUIT` addon message): zero
  posts. Any member may post.
- **R2:** `RECRUIT_CHANNEL = "LookingForGroup"`, `COOLDOWN = 900`, kept in
  `DeadTiredDB.prep.recruitAt` (epoch seconds from `time()`), so alts share it (tested).
- **R3:** `PrepList.lua` holds the brief's starter list unchanged. The IDs are still unverified;
  G7 checks them.
- **R4:** an answer carries `q`, `to`, `ok` and `short` (a count), and nothing else. Sharing is
  off by default.
- **R5:** four `.toc` lines and one `run_all.sh` line (G4). `Config.lua` is untouched. The
  version is still `0.1.0`.

## Differences from the brief

1. **`/1 ` dropped from the lines**, as above.
2. **The share gate is checked twice:** when the question arrives (the specified gate) and again
   when the 1-5 s delay ends. So switching sharing off in that gap means no answer goes out.
   Both are proved (Task 10).
3. **An invalid `PREPQ`** (a `q` that isn't a 1-6 digit number) also counts in `prep.badPrep`. The
   brief only specified validation for `PREP`.
4. **Unspecified texts added:** `/dt prep list` with nothing applicable (*"Nothing on the list for
   you. Travel light."*), `/dt prep <other>` usage, `/dt recruit <other>` usage, and the
   `share on/off` confirmations (below).
5. **A missing chat function** (`C_ChatInfo.SendChatMessage` absent) is treated as a failed post:
   *"The channel didn't take it."*, with nothing moved.
6. Lines carry card 1's `Dead Tired ` prefix. The `/dt prep list` line uses the brief's em dash
   (`—`). WoW's chat renders it; it is the only non-ASCII byte the addon prints.

## Player-facing lines, for H1

| When | Line (after `Dead Tired `) |
|---|---|
| `/dt prep`, all met | `Ready. Bags packed, coffin optional.` |
| `/dt prep`, short | `Short: Major Healing Potion 0/5, Sacred Candle 19/20.` |
| `/dt prep list` | `17029 Sacred Candle x20 — client: Holy Candle  <- check this ID` (or `client: not loaded yet`) |
| `/dt prep share on` / `off` | `sharing on. You'll answer roll calls: ready or not, and how many short.` / `sharing off. Your bags are your own business.` |
| `/dt prep check` | `Roll call sent. Answers in 10 seconds.`, then `Ready (1): Ghoul. Short (1): Wight (2 short).` and `Only guildies running the addon with sharing on answer.` |
| A second check inside 60 s | `Patience. The last roll call is still out.` |
| `/dt recruit` | `Posted line 1 of 5 to LookingForGroup.` |
| Inside the cooldown | `Too soon. Next post in 14 min. Even necromancers pace themselves.` |
| Lockdown / not in channel | `Chat's locked right now (an encounter?). Try after.` / `You're not in LookingForGroup. /join LookingForGroup first.` |
| Clock / failure / no lines | `Can't read the clock. Not posting.` / `The channel didn't take it. Nothing posted.` / `No recruitment lines loaded. Tell an officer.` |
| `/dt recruit next` | `Next up: line 2 of 5. Cooldown: 13 min left.` |

What strangers see is only Tim's five lines, unchanged. H1 is about those.

## Wire

```
1^PREPQ^q~1                                              11 bytes
1^PREP^ok~0^q~1^short~2^to~Classic Beta PvP-Stromham     52 bytes
```

**Longest PREP: 97 bytes** (`q` 999999, a 64-byte `to`, `short` 50). That is at most 250, so the
stop condition was not tripped. The recruitment post isn't an addon message.

## Task 10: guard proofs

Each guard (marked `-- guard: …`) was broken by script, `run_all.sh` was run, and the file was
restored. The suites were green again afterwards.

| # | Guard | Broken by | Checks that went red |
|---|---|---|---|
| 1 | `share` gate on answering | line deleted | "a member with sharing off sends nothing at all, and doesn't even note the question" |
| 1b | `share` gate at answer time (extra, difference 2) | line deleted | "sharing turned off before the delay ends: no answer" |
| 2 | One answer per asker and question | line deleted | "a duplicate question gets no second answer", "a new question gets a new answer" |
| 3 | 60 s check window | condition → `false` | "a second roll call inside 60 s is refused, nothing sent", plus 3 more |
| 4 | Late answers ignored | line deleted | "once per sender; addressed elsewhere and old questions ignored", then a Lua error (indexing the closed question) |
| 5 | `PREP` to someone else ignored | line deleted | "once per sender; addressed elsewhere and old questions ignored" |
| 6 | `PREP` validation | condition → `false` | "each invalid PREP / PREPQ field is counted in badPrep" |
| 7 | Class filter | condition → `true` | 13, incl. "class filter: a rogue is checked for Flash Powder, not candles" |
| 8 | Lines check | condition → `false` | "no lines: refused, nothing posted" |
| 9 | Recruit cooldown | condition → `false` | 10, incl. "inside the cooldown: refused, minutes rounded up", "an alt on the same account shares the cooldown" |
| 10 | Lockdown refusal | condition → `false` | "chat lockdown: refused", plus 3 more |
| 11 | Channel refusal | condition → `false` | "not in the channel: refused", plus 2 more |
| 12 | Failed post moves nothing | condition → `false` | "a failed post: refused, cooldown and rotation unmoved", "the chat function absent: nothing posted, nothing moved" |

**Said up front:** guard 1 would have stayed green on its own, because 1b blocks the answer
anyway. I saw this before running the proofs and gave the test something visible to check (a
non-sharing member doesn't even note the question). So both share checks are proved, and no stop
condition tripped.

## Offline acceptance

- **G1:** `run_all.sh` exits 0 with eight suites:

```
core: 44 passed, 0 failed
guild: 13 passed, 0 failed
comms: 53 passed, 0 failed
roster: 26 passed, 0 failed
alts: 21 passed, 0 failed
welcome: 17 passed, 0 failed
prep: longest PREP is 97 bytes
prep: 42 passed, 0 failed
recruit: line 1 is 206 bytes
recruit: line 2 is 194 bytes
recruit: line 3 is 163 bytes
recruit: line 4 is 173 bytes
recruit: line 5 is 158 bytes
recruit: 33 passed, 0 failed
ALL GREEN
```

- **G2:** the table above lists all twelve (and 1b).
- **G3:** `grep -rn "SendChatMessage" DeadTired/ --include=*.lua | grep -v "/tests/"` finds
  exactly one line: `DeadTired/Recruit.lua:64:  local say = C_ChatInfo and C_ChatInfo.SendChatMessage`.
  The second grep (`COMBAT_LOG|CombatLog|C_DeathRecap|UNIT_DIED|PARTY_KILL|C_Container|READY_CHECK`)
  finds nothing. `test_recruit.lua` spells the name as `"Send" .. "ChatMessage"` to stub it, so the
  test files don't muddy the count either.
- **G4:** `git diff card/dt_foundation --stat -- DeadTired/`:

```
 DeadTired/DeadTired.toc          |   4 +
 DeadTired/Prep.lua               | 181 ++++++++++++++++++++++++++++++++
 DeadTired/PrepList.lua           |  17 +++
 DeadTired/Recruit.lua            |  95 +++++++++++++++++
 DeadTired/RecruitLines.lua       |  17 +++
 DeadTired/tests/run_all.sh       |   2 +-
 DeadTired/tests/test_prep.lua    | 217 +++++++++++++++++++++++++++++++++++++++
 DeadTired/tests/test_recruit.lua | 169 ++++++++++++++++++++++++++++++
```

  (`run_all.sh`: one line changed, counted by git as one removed and one added.)
- **G5:** byte-identical, tested; lengths in the table under *P3*.

## Merge note

Cards 1, 3 and 4's G3 checks grep all of `DeadTired/` for `SendChatMessage` and expect nothing.
Once this card is merged to `main`, those checks will find `Recruit.lua:64`. When re-running them
on `main`, except that one line (R1 ratified it). I haven't edited the other cards' walk-sheets.

At merge, the `.toc` and `run_all.sh` lines conflict with cards 3 and 4. Keep all of them, in card
order:
- `.toc`: `Crypt.lua`, `Gank.lua`, `PrepList.lua`, `Prep.lua`, `RecruitLines.lua`, `Recruit.lua`;
- `run_all.sh`: `... welcome:Welcome crypt:Crypt gank:Gank prep:Prep recruit:Recruit; do`.

## Not provable offline

- whether `C_ChatInfo.SendChatMessage` to a channel needs a hardware event on Forever (a typed
  `/dt recruit` or a macro click is one, so the design should hold);
- whether `LookingForGroup` exists on Forever, and its name;
- the starter list's item IDs (G7);
- `GetItemCount`'s second argument meaning "include bank" on this client, as on retail.

## Left undone, stop conditions

- Nothing in Tasks 1-11 is left undone.
- Stop conditions: none tripped. P1-P3 hold; nothing is missing from *Builds on* or the API
  lookups; no card 1 file changed beyond R5; every line passes the lines check; the chat call
  has one site; the longest PREP is 97 bytes; every guard removal went red; nothing needs combat
  data, another player's bags, the bank or automatic posting.
- `docs/UAT_dt_prep_results.md` was not written; that file is Tim's.
