# Cowork brief: the Crypt's Table, guild gambling (0.6.0)

You are in `LUCA5G00N/dead-tired-addon`, building in a cloud session; Tim walks the result in game.
Read first, in order:
1. `CLAUDE.md` on `main`, and `docs/DECISIONS.md` 0001 and 0002.
2. This brief and its walk-sheet, `docs/UAT_dt_gamble.md`.
3. `docs/FEATURES.md`, *Guild gambling (Tim, 11 Nov; Liliac's idea, 4 Nov)*: the 11 Nov ruling (addon messages,
   not chat) and the three questions it left open. D2, D6 and D9 below settle them.
4. `DeadTired/DeathBoard.lua` (0.4.0): the shared-board pattern this round copies (`TALLY`, `TALLY {off=1}`, the
   weekly reset read, validation, the cap, the viewport, the footer).
5. `DeadTired/Way.lua` (0.5.0): the newest module (store, verbs, window, `fit`, offline-test shape).
6. `DeadTired/Comms.lua` (`DT.send`, `DT.on`; GUILD only), `DeadTired/UI.lua` (`DT.viewport`, `DT.list`,
   `DT.text`), `DeadTired/Ghost.lua`, `DeadTired/Selftest.lua` (`DT.REQUIRED`, `CAPS`, the samples).

**Draft status: written 23 Nov 2026, 20:30, against `main` at `54587ae` (0.5.0, merged).** Every name above is
re-read against the tree as Task 1's first act.

## Origin
- Liliac, #dt-crypt-workshop, 4 Nov ("We'll need some guild gambling… leaderboard etc.") and 18 Nov ("higher
  priority"). On the roadmap post of 18 Nov as item 6.
- FEATURES.md, 11 Nov: CrossGambling's ideas, our own code; **the round runs over addon messages, not chat.**
- Tim's sketch, posted in #dt-crypt-workshop 22 Nov 19:31 (`claude/37_…`): no gold; play chips topped up weekly;
  deathroll and high-low; the game's own `/roll`, in a party; a Dead Tired window, no spam; a weekly leaderboard
  and small guild-bank prizes handed out by an officer.
- **Tim, 23 Nov 20:10:** the guild's verbal consensus is to build the sketch. His answers to the four open
  questions became D1, D3, D8 and D4/D5 below.
- **Roll probe, Tim, 23 Nov 20:14–20:16:** passed; see *The roll probe* below.

## The roll probe (Tim, 23 Nov 20:14–20:16, Gadgetzan, in a four-player party; `WoWScrnShot_112326_201603.jpg`)
- `RANDOM_ROLL_RESULT` reads `%s rolls %d (%d-%d)`. `type(RandomRoll)` is `function`.
- A `CHAT_MSG_SYSTEM` listener registered from `/run` received `/roll 100` as
  `Stromham Hamson rolls 32 (1-100)`; `issecretvalue(m)` was **false**.
- `/run RandomRoll(1,57)` rolled: `Stromham Hamson rolls 57 (1-57)`, not secret. So the call works from a typed
  command; whether a button's click can call it is Task 1's check (stop condition below).
- **Another player's roll is seen:** party member Sap Hapi's `/roll` arrived as `Sap Hapi rolls 60 (1-100)`, not
  secret.
- **Names arrive as the full two-part name with no realm** (`Stromham Hamson`, `Sap Hapi`). Matching a roll to a
  player compares this name with the realm-free part of their key (as `/dt who` shows names); two players in one
  game with the same full name on different realms → the game refuses to start, with a line.
- Not probed: rolls inside an instance or in combat (lockdown). Games are for towns; a secret message is skipped
  (Working rules).

## Precondition
`main` at `54587ae` or later, carrying this brief and its walk-sheet;
`run_all.sh` `ALL GREEN`.

## Rulings in force (cited, not restated)
- `CLAUDE.md`: module rules 1–14; guarded reads; no hooks; no automatic posting to public channels; quiet by
  default; optional for members.
- FEATURES.md 11 Nov: addon messages, not chat; DT reads the game's own `/roll`; no gold moves through the addon.
- R-F4-1 (text through `DT.text`). R-F5-1 (two-line rows where a board needs them). R-P2-2 (Escape closes).
- L3 (`dt_deathboard`): a week ends at the game's weekly reset, read the same way.
- `dt_selftest` R-F8-3 (the ghost).

## Rulings for this round (D1–D10; proposed, ratified by Tim's merge of this brief)
- **D1 Chips, not gold.** Every character starts with **1,000 chips**. Chips are play money: they can't be bought,
  sold, traded or turned into gold, and no gold ever moves through DT. Prizes from the guild bank are an
  officer's business, by hand.
- **D2 Party only.** A game needs everyone in it in one party or raid with you (`UnitInParty`/`UnitInRaid` by
  name, guarded). Game messages travel on the GUILD channel like every other DT message; a client ignores a game
  it isn't in. Comms is not changed.
- **D3 The broke are topped up.** At each weekly reset (L3's read), a character holding fewer than 1,000 chips is
  brought up to 1,000. Anyone above keeps what they have. If the reset can't be read, nobody is topped up and
  the window says so.
- **D4 Deathroll.** Two players. The challenger names a stake *S* (D6). The first roll is 1–*S*; each roll after
  is 1–(the last result), the players taking turns. Whoever rolls **1** loses *S* chips to the other.
- **D5 High-low.** A host opens a table with a stake *S*. Party members running DT join from the window. The host
  presses **Final call**, or 20 s after the last join it closes by itself. Everyone in rolls 1–*S*.
  - The lowest pays the highest the difference, in chips.
  - A tie for highest or for lowest: only the tied players roll again (1–*S*) to settle that end. Repeat until
    settled.
  - Fewer than two players at the close: the table folds and nothing moves.
- **D6 Stakes.** *S* is a whole number from 2 to 500. You can't start or join a game whose stake is more than you
  hold. (High-low's worst loss is *S* − 1.)
- **D7 Rolls are the game's, and each client checks them.** A roll is made only by the game's `RandomRoll`
  (the window's **Roll** button calls it with the right range; typing `/roll` with the same range also counts).
  Each client reads every roll from `CHAT_MSG_SYSTEM`, parsed with the client's own `RANDOM_ROLL_RESULT` pattern
  (never a hard-coded English string).
  - A roll counts only if it is from a player in the game, it is that player's turn, and its range is the one the
    game expects. Anything else is ignored, and the window shows `<name> rolled out of turn.` or
    `<name> rolled the wrong range.`
  - Each client settles a game from the rolls **it saw**. The host's (or the deathroll pair's) `RESULT` message
    carries the rolls. A client whose own rolls disagree, or who missed one, marks the game **disputed**, shows
    `Disputed. Nothing moved.`, and changes no balance.
  - Each player's own client is the only one that changes that player's balance.
- **D8 The board.** `/dt gamble board`: everyone who has played, in the death board's style.
  - Each player's client sends `CHIPS { b = balance, w = this week's net, bb = this week's biggest single loss,
    we = week end }` after every settled game and once 10 s after login.
  - Playing is the opt-in. `/dt gamble board off` sends `CHIPS {off=1}`, receivers delete you, and you are not
    sent again until `/dt gamble board on`.
  - Rows: name (class-coloured, realm-free), this week's net, balance. Sorted by this week's net, then balance,
    then name. A received entry whose `we` has passed reads 0 for the week.
  - Footer: `Biggest beat-down this week: <name>, <n> chips.` (the largest `bb`), left out when nobody has lost.
    And the closing line: `Only guildies running the addon who have played.`
- **D9 Nothing to chat.** No line goes to any chat channel, by timer or by click, in this round. The result shows
  in the window and one line in the player's own chat frame (`DT.out`), only for games you were in.
- **D10 Version.** 0.6.0, a new feature.

## Ratify before code
- **Chips are per character** (keys are `RealmKey-Full Name`, as everywhere). An alt is a second wallet. The
  lean is to accept it: chips are play money and D3 tops everyone up anyway. If Tim rules chips per main
  (`/dt main`), D1 changes before the build.

## Deliverable
On `claude/dt-gamble` from `main`, DeadTired **0.6.0**. A new module, `gamble` (`Gamble.lua`), with:
- the verbs `/dt gamble` (the table window), `/dt gamble deathroll <name> <stake>`, `/dt gamble highlow <stake>`,
  `/dt gamble board`, `/dt gamble board on|off`;
- the table window (open games in your party, join, Roll, Final call, the running rolls, the result) and the
  board window.

In the harness, with two and three fake players in a fake party whose `RandomRoll` and `CHAT_MSG_SYSTEM` are
scripted:
- a deathroll and a high-low each settle to the chip changes D4 and D5 give, on every client;
- a tie at either end is rolled off;
- a disagreeing or missing roll makes the game disputed and moves nothing;
- the weekly top-up lifts only those under 1,000.

The round is done when:
- `run_all.sh` is `ALL GREEN`;
- every Task 8 guard has been removed once and turned a named check red;
- `dist/DeadTired-0.6.0.zip` passes `diff -r`.

## Working rules
- No module but `gamble` changes, apart from:
  - `Selftest.lua`: new APIs in `DT.REQUIRED`, new stores in `CAPS`, a ghost sample if Task 6 adds one;
  - `Ghost.lua`: only if Task 6 adds the ghost's board entry;
  - `.toc`; `Core.lua` (`DT.VERSION`); test version lines.

  `Comms.lua` is not changed. No library is added. Nothing is borrowed from CrossGambling's code.
- Every global and `C_*` call goes through `try`/`clean`. A secret roll message is skipped, never parsed.
- The `CHAT_MSG_SYSTEM` listener is registered only while a game you are in is open, and unregistered when it
  settles, folds or is disputed. With no game open, `gamble` does no work at all.
- Every game message (`GAME`, `JOIN`, `ROLL`, `RESULT`, `CHIPS`) is validated (types, ranges, the stake cap, at
  most 40 players) and bad ones counted, like `TALLY`.
- Stores: `DeadTiredDB.gamble = { wallet = { [charKey] = { b, w, bb, we } }, board = { [key] = entry } }`.
  `wallet` capped at 50 characters, `board` at 200 entries, entries dropped after 30 days unseen.
- A game left open with nobody rolling times out after 2 minutes: it folds, nothing moves. A debug command
  shortens it for a walk (module rule 13), never saved.

## Tasks
1. **Baseline:** suites and counts; re-verify "Read first", and that `RandomRoll`, `RANDOM_ROLL_RESULT`,
   `UnitInParty`, `UnitInRaid` and `C_DateAndTime.GetSecondsUntilWeeklyReset` are what the probe and the SPEC
   say.
2. **The roll reader:** turn `RANDOM_ROLL_RESULT` into a pattern (name, roll, min, max), guarded; tested against
   the probe's exact strings and against a localised format with the fields in another order.
3. **`Gamble.lua`, the games:** the module and its store; deathroll (D4); high-low with Final call and the
   20 s close (D5); stakes (D6); the turn and range checks and settlement (D7); the time-out.
4. **`Gamble.lua`, the wallet and board:** start at 1,000 (D1); the weekly top-up (D3); `CHIPS` send, receive,
   withdraw and expiry (D8); the board window with its footer and closing line.
5. **The windows:** the table window (empty state: `No games in your party. Start one.`) and the board (empty
   state: `Nobody has played yet. The table is cold.`); both draggable, places remembered, Escape closes, `fit`.
6. **The ghost:** the Restless Ghost can send one `CHIPS` entry (`/dt debug ghost chips`), so the board can be
   walked alone (DECISIONS 0002).
7. **`Selftest.lua`, `.toc`, `Core.lua`:** every new API in `DT.REQUIRED` (at least `RandomRoll`, `UnitInParty`,
   `UnitInRaid`); `gamble.wallet` and `gamble.board` in `CAPS`; `Gamble.lua` after `WayBooks.lua`; 0.6.0.
8. **Tests and guard proofs** (`tests/test_gamble.lua`; additions to `test_selftest`).
   - **Tests:**
     - the roll reader: the probe strings, another word order, junk, a secret message;
     - deathroll: a full game to a 1; the stake cap; can't stake more than you hold;
     - high-low: three players settle; a tie for high; a tie for low; one player at the close folds;
       Final call and the 20 s close;
     - out of turn, wrong range, not in the party: ignored, with the window line;
     - disputed: a client that saw a different roll, and one that missed a roll, move nothing;
     - only your own client changes your balance;
     - the top-up: 400 → 1,000, 1,500 stays, no reset read → nobody;
     - the board: sort, footer, week rollover, `off` withdraws, inbound validation and the caps;
     - the listener exists only while a game you're in is open;
     - the time-out, and its debug shortening not saved;
     - fit under every skin; nothing outside the guild; the module off does nothing.
   - **Guards** (remove once, a named check red, restore):
     - the party check; the turn check; the range check; the stake cap; the hold-enough check;
     - dispute-moves-nothing; own-balance-only; the secret-message skip;
     - the top-up threshold; `CHIPS` validation; the board cap; the wallet cap; withdraw on `off`;
     - the listener unregister; the time-out; the guild gate; the module switch;
     - every guard 0.5.0 proved.
9. **Docs:** `FEATURES.md` *Ruled 23 Nov (for `dt_gamble`, 0.6.0)*; `docs/RELEASE_0.6.0.md` (DT's voice, a few
   lines; the Voice posts it in #dt-crypt-workshop by itself). Name Liliac.
10. **Version and zip:** `dist/DeadTired-0.6.0.zip`, `diff -r` clean.
11. **Report** `docs/COWORK_REPORT_dt_gamble.md`; PR to `main`, not stacked.

## Out of scope
- Gold, trades, or anything that buys chips: Liliac's donate-for-chips idea is a later round with its own ruling.
- Posting anything to chat, including a host's one-click Announce (FEATURES.md calls it a later nicety).
- Prizes in the addon: the board names the winners; officers hand out prizes by hand.
- Other games (CrossGambling's variants, poker, blackjack, coin flips).
- Achievements built on gambling, and an all-time board.
- Games across parties, guild-wide games, or players not running DT.
- Changing `Comms.lua` to use a PARTY or RAID channel.

## The one deliberate widening
DT starts listening to `CHAT_MSG_SYSTEM`: chat the player receives, which no module has read before. It is
bounded:
- only while a game the player is in is open;
- only to parse lines matching the client's own `RANDOM_ROLL_RESULT`, and only from players in that game;
- nothing read is stored except the rolls of that game, and nothing is sent that the other players didn't see
  themselves.

## Stop conditions
- Baseline not `ALL GREEN`, or `lua5.1` can't be installed → stop.
- The roll message turns out secret outside combat, or the client's `RANDOM_ROLL_RESULT` differs from the probe's →
  stop and report.
- `RandomRoll` can't be called from a button click (protected or absent) → stop and report (Tim decides: players
  type `/roll` themselves, or another design).
- Settling needs trust in another client's report, rather than each client's own reading → stop.
- The design needs a chat post, a hook, a library, a change to `Comms.lua`, or a write to a Blizzard frame → stop.
- A guard removal turns nothing red: strengthen the test (test files only); if that needs addon code → stop.

## UAT: acceptance checks
`docs/UAT_dt_gamble.md`: **5 [G] offline, 5 [G] in game, 3 [H].** The in-game deathroll and high-low need a
second player running 0.6.0 in Tim's party (a third for H2's tie, if one turns up).

## Reporting
`docs/COWORK_REPORT_dt_gamble.md`:
- branch and heads; counts per suite;
- the roll pattern built from the probe's `RANDOM_ROLL_RESULT`, and the strings it was tested against;
- one worked deathroll and one worked high-low from the harness, roll by roll, with the chip changes;
- each guard proof;
- the player-facing text, verbatim;
- zip name, size, sha256;
- what the brief got wrong; questions.

Never write a `_results.md` file.
