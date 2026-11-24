# Cowork report: the Crypt's Table, guild gambling (0.6.0)

Brief: `docs/COWORK_BRIEF_dt_gamble.md` (D1–D10, ratified by Tim's merge of PR #38). Walk-sheet: `docs/UAT_dt_gamble.md`.
Built 24 Nov 2026, 18:15–18:40, in a cloud session while Tim was out. **Not walked.** The walk is Tim's.

## Branch and heads
- Branch `claude/dt-gamble`, from `main` at `ea656dd` (PR #39 merged: the guild-quests brief).
- PR to `main`, not stacked.

## Task 1: baseline
- `run_all.sh` on `ea656dd`: **ALL GREEN** (31 suites plus libs). `lua5.1` installed with apt.
- "Read first" re-read against the tree. Every name in it exists as the brief says: `TALLY` and its pattern in
  `DeathBoard.lua`, `DT.waySet` and the window pattern in `Way.lua`, `DT.send`/`DT.on` (GUILD only), `DT.viewport`,
  `DT.list`, `DT.text`, the ghost, and `DT.REQUIRED`/`CAPS`/`samples` in `Selftest.lua`.
- `RandomRoll` and `RANDOM_ROLL_RESULT` are as the probe found. `C_DateAndTime.GetSecondsUntilWeeklyReset` is in
  the SPEC (already in `DT.REQUIRED` since 0.4.0).

## Counts per suite (after)
alts 28 · bar 82 · comms 46 · core 37 · crypt 126 · deathboard 67 · debug 45 · events 45 · eventslist 4 ·
**gamble 141 (new)** · gank 82 · ghost 52 · guild 39 · keys 48 · logs 140 · migrate 71 · played 91 · prep 47 ·
recruit 104 · recruitlines 7 · **selftest 66 (was 62)** · session 9 · settings 33 · settingsview 31 · skins 39 ·
stash 105 · ui 144 · way 75 · waybooks 5 · who 43 · taint 40 · textfit 11 · libs unmodified. **ALL GREEN.**

## What landed
- `DeadTired/Gamble.lua` (new): the `gamble` module, with D1–D9.
- `DeadTired/tests/test_gamble.lua` (new, 141 checks).
- `DeadTired.toc`: `Gamble.lua` after `Way.lua` (the brief said "after `WayBooks.lua`". `Way.lua` already follows it,
  so the new file goes straight after that). Version 0.6.0.
- `Core.lua`: `DT.VERSION = "0.6.0"`.
- `Selftest.lua`: `RandomRoll`, `GetNumGroupMembers` and `IsInRaid` added to `DT.REQUIRED`; `gamble.board` (200) and
  `gamble.wallet` (50) added to `CAPS`; samples added for `GAME`, `JOIN`, `CALL`, `RESULT`, `FOLD` and `CHIPS`.
- `Ghost.lua`: `/dt debug ghost chips` (1,250 chips, +250 this week, biggest loss 40). `all` now says 6 things.
- Test version lines: `test_core` (0.6.0; the module order now includes `gamble`), `test_who`, `test_selftest`
  (0.6.0, 17 sample kinds, a new 0.6.0 block), `test_ghost` (six things).
- `docs/FEATURES.md`: a new section, *Ruled 23 Nov (for `dt_gamble`, 0.6.0)*. `docs/RELEASE_0.6.0.md`.
- `Comms.lua`, `Way.lua` and every other module are unchanged. No library added. Nothing borrowed from
  CrossGambling.

## The roll reader
`DT.rollPattern(RANDOM_ROLL_RESULT)` compiles the client's own format. It turns each `%s` into `(.-)` and each
`%d` into `(%-?%d+)`, escapes Lua's magic characters, and honours positional forms (`%2$d`), with `order` mapping
each capture to its argument. For the probe's `%s rolls %d (%d-%d)` the pattern is `^(.-) rolls (%-?%d+) %((%-?%d+)%-(%-?%d+)%)$`.
It was tested against:
- `Stromham Hamson rolls 32 (1-100)`, `Sap Hapi rolls 60 (1-100)` and `Stromham Hamson rolls 57 (1-57)` (the
  probe's lines);
- `Echo Nightclaw-OtherRealm rolls 5 (1-10)` (the realm is dropped);
- a client whose format is `%3$d-%4$d: %1$s würfelt %2$d` reading `1-100: Sap Hapi würfelt 42` (and refusing the
  English line);
- junk, an empty string, nil, and a secret line (skipped, never parsed).

## Worked games (from the harness)
**Deathroll, Stromham v Sap, stake 100.** Stromham challenges and Sap joins (Join accepts).
| Roll | Player | Range | Result |
|---|---|---|---|
| 1 | Stromham Hamson | 1-100 | 60 |
| 2 | Sap Hapi | 1-60 | 20 |
| 3 | Stromham Hamson | 1-20 | 7 |
| 4 | Sap Hapi | 1-7 | **1** |

Sap goes from 1,000 to 900 and Stromham from 1,000 to 1,100. Both clients hold the same rolls. Stromham's chat line:
`Deathroll: Stromham Hamson beat Sap Hapi. 100 chips.` Sap sends `CHIPS {b=900, w=-100, bb=100}`.

**High-low, stake 100, three players.** Stromham rolls 80, Sap 30, Liliac 55. Sap pays Stromham 80 − 30 = **50**:
Stromham goes to 1,050 and Sap to 950. Liliac stays at 1,000 but is marked as played, so she's on the board.
Line: `High-low: Sap Hapi pays Stromham Hamson 50 chips.`

**Ties.**
- A tie at the top (90, 90, 10): only the two 90s roll again (20, 70). Sap wins, and Liliac pays 90 − 10 = 80
  from the first round.
- A tie at the bottom (90, 5, 5): only the 5s roll again (40, 3), and Liliac pays 85.
- Two players with the same roll: both roll again.

## Guard proofs (Task 8)
Each guard was removed once and the gamble suite re-run, then restored. All 30 went red. A script made each
replacement on a copy of the source and restored it afterwards. Before each removal the guard's line is unique, and it
is marked `-- guard:` in the source.
| Guard | Red check(s) |
|---|---|
| party check | D2: a game from outside your party isn't listed; a join from outside the party is ignored |
| party check (join) | D2: a join from outside the party is ignored |
| turn check (deathroll) | D7: out of turn: ignored, with the line |
| turn check (high-low) | D5: the untied player rolling then is out of turn |
| range check (deathroll) | D7: wrong range: ignored, with the line |
| range check (high-low) | D7: high-low, the wrong range: ignored, with the line |
| stake cap | D6: a stake of 1 is refused; 501 is refused |
| hold-enough check | D6: more than you hold is refused |
| dispute moves nothing | D7: nothing moved on that client |
| a missed roll disputes | D7: a client that missed a roll: disputed |
| own balance only | D5: the middle moves nothing |
| secret message skipped | reader: a secret line is skipped, never parsed |
| top-up threshold | D3: 1,500 at the reset stays 1,500; a week ending while the reset can't be read: no top-up |
| CHIPS validation | D8: bad CHIPS are counted and dropped |
| GAME validation | GAME validation: five bad, five counted, no game |
| CALL validation | CALL validation: no players, or more than a table holds: counted |
| board cap | D8: the board caps at 200 |
| wallet cap | wallet cap: a 51st character keeps the store at 50 |
| withdraw on board off | D8: board off withdraws you from everyone's board |
| board switch (send) | D8: board off: nothing sent at login; nothing sent after a game either |
| listener unregister | D4: the listener is gone once it's settled |
| time-out | time-out: two minutes with nobody rolling folds it |
| debug time-out never saved | time-out: the debug setting is never saved |
| tie for high rolled off | D5: a tie at the top: only the tied roll again |
| tie for low rolled off | D5: a tie at the bottom: only the tied roll again |
| status fits its room | fit: under a big font the status still keeps to its room |
| module switch (inbound) | off: no game heard |
| module switch (rolls) | off: a roll line reaching the module is not read |
| off verbs do nothing else | off: a typed game starts nothing |
| module switch and guild gate (send) | D8: withdraw is sent even with the module off |

**Tests strengthened during the proofs** (test files only, per CLAUDE.md). Seven guards first stayed green. In each
case the test was weak, not the guard:
1. A high-low wrong-range check was added.
2. CALL with no players, and CALL with more than 40, were added.
3. The board-off login check read the old client after `/reload`; it now reads the new one, and a check that nothing
   is sent after a game was added.
4. The "never saved" check had an operator-precedence bug; it now scans the store.
5. A big-font fit check was added for the status block.
6. A check was added that a roll line doesn't reach a switched-off module.
7. A check was added that a typed game while off starts nothing.

**Not re-proved this round:** the guards 0.5.0 and earlier rounds proved. Their suites are unchanged and green, but I
didn't remove each of them again.

## Player-facing text, verbatim
- **Window titles:** `The Crypt's Table`, `The Crypt's Ledger`.
- **Empty states:** `No games in your party. Start one.` and `Nobody has played yet. The table is cold.`
- **Footers:**
  - `Chips only. No gold changes hands.`
  - `Biggest beat-down this week: <name>, <n> chips.`
  - `The weekly reset can't be read, so nobody is topped up.`
  - `Only guildies running the addon who have played.`
- **Rolls:** `<name> rolled out of turn.` · `<name> rolled the wrong range.` · `<name> rolls <n> (1-<max>).` (deathroll) ·
  `<name> rolls <n>.` (high-low) · `<name> to roll, 1-<n>.` · `Waiting on <names>.`
- **Table events:**
  - `You challenge <name> to a deathroll for <s>. Waiting for them to join.`
  - `<host> challenges you to a deathroll for <s>. Join to accept.`
  - `<host> challenges <name> to a deathroll for <s>.`
  - `You open a high-low table at <s>. Final call when they're in.`
  - `<host> opens a high-low table at <s>. Join if you dare.`
  - `<name> joins.` · `You join. Waiting for the call.` · `The table closed without you.`
  - `<name> rolls first, 1-<s>.` · `Everyone rolls 1-<s>.`
  - `All square. Everyone rolls again.`
  - `A tie at the top: <names> roll again.` · `A tie at the bottom: <names> roll again.`
- **Results:**
  - `Deathroll: <winner> beat <loser>. <n> chips.`
  - `High-low: <loser> pays <winner> <n> chips.`
  - `Disputed. Nothing moved.` · `The table folds. Nothing moved.`
  - `Nobody rolled for too long. The table folds. Nothing moved.`
- **Refusals:**
  - `A stake is a whole number from 2 to 500.` · `You hold <n> chips. Not enough for that stake.`
  - `You need a party. The dead don't gamble alone.`
  - `<name> isn't in your party.` · `More than one <name> in your party. Use the full name.`
  - `You can't deathroll yourself. You'd lose.`
  - `No open game to join in your party.` · `<host> isn't in your party any more.`
  - `Not your roll.` · `No table of yours to call.`
- **The board switch:** `You're on the board.` · `You're off the board. Your chips are your own business.`
- **Debug:** `A quiet table folds after 10 s this session.` · `A quiet table folds after 2 minutes.`
- **Usage:** `/dt gamble [join|deathroll <name> <stake>|highlow <stake>|call|roll|board [on|off]]` ·
  `/dt debug gamble fast|slow` · `gamble.enabled = off`
- **Buttons:** `Join`, `Roll`, `Final call`. **Settings card:** `On the board`.

## The zip
`dist/DeadTired-0.6.0.zip`: 215,765 bytes, sha256 `7fb6e26443da56f60240eda6592a7907e42f33f726dd2f3d0cd4ef46726851fd`
(rebuilt after the walk fix below; the walked build was `9617b880…2fd`).
Unzipped, `diff -r -x tests` against `DeadTired/` is clean.

## What the brief got wrong, and where I departed from it
1. **The party check uses `GetNumGroupMembers`, `IsInRaid` and `GetUnitName("partyN"/"raidN", true)`, not
   `UnitInParty`/`UnitInRaid` by name.** Forever's names have spaces, and I couldn't confirm that `UnitInParty("Sap Hapi")`
   accepts a two-part name. Walking the group's units and comparing full names (realm dropped) doesn't depend on
   that. `DT.REQUIRED` lists the three functions actually called.
2. **No `ROLL` message, and a `FOLD` message was added.** Each client reads the rolls itself (D7), so a `ROLL` message
   would only repeat what everyone saw. `FOLD` tells the party when a host's table folds with fewer than two players.
3. **A bystander's roll gets no window line.** The brief's line for "not in the party" would print every time a party
   member who isn't at the table rolls for loot. Out-of-turn and wrong-range lines are shown for players at the table
   only.
4. **The deathroll opponent accepts by joining** (`Join`, or `/dt gamble join`). The brief didn't say how a challenge
   is accepted.
5. **Typed forms of the buttons** were added: `/dt gamble join`, `/dt gamble roll`, `/dt gamble call` (module rule 6
   for actions, and the tests drive them).
6. **The status block keeps to its room.** With a big font the oldest log lines are dropped; the balance line and
   whose turn it is are kept.
7. **A host's `RESULT` can arrive before your own last roll line.** A client waits up to 5 s for it, then disputes.
8. **`RandomRoll` from a button click can't be checked offline.** Walk check G7 uses the **Roll** button. If the
   client refuses it there, that's the stop condition the brief names, found at the walk. Typing `/roll` with the
   range shown still works.

## Questions for Tim
- **Should a party member not at the table see the game listed?** They do now, marked "rolling", so they can watch.
  Say if it should be hidden.
- **Join and Final call can't be undone.** There's no Leave button. A player who joins and walks away gets the 2-minute
  time-out (nothing moves). Is that enough?

## After the walk (24 Nov, 19:21–21:04)
Tim's G6 screenshot showed the table's empty line twice, once in the list and once in the status block. Fix: with no
game, the status block shows only `You hold <n> chips.`. The window test was changed to check for this. The change
is one function, `statusText`, and nothing else; the suite is still ALL GREEN. The walk results are on PR #40.

Never wrote a `_results.md` file.
