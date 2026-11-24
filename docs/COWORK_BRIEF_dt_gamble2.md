# Cowork brief: the Crypt's Table, round 2: starting and finishing games (0.7.0)

You are in `LUCA5G00N/dead-tired-addon`, building in a cloud session; Tim walks the result in game.
Read first, in order:
1. `CLAUDE.md` on `main` (the merge gate, item 5), and `docs/DECISIONS.md` 0001 and 0002.
2. This brief and its walk-sheet, `docs/UAT_dt_gamble2.md`.
3. `docs/COWORK_BRIEF_dt_gamble.md` (D1–D10, in force) and `docs/COWORK_REPORT_dt_gamble.md` (what was built,
   and its departures from that brief: no `ROLL` message; `FOLD`; the opponent joins to accept; the party walk).
4. `DeadTired/Gamble.lua` (0.6.0) and `DeadTired/tests/test_gamble.lua`: the module this round extends.
5. `DeadTired/Gank.lua`: how `/dt gank` reads the target (`GetUnitName("target", true)`, guarded).
6. `DeadTired/Bar.lua` (`DT.object`; a module's `ldb` field): how a module gets a bar button.

**Draft status: written 24 Nov 2026, 22:35, against `main` at `fba3cd7` (0.6.0 released).** Every name above is
re-read against the tree as Task 1's first act. The roster of who runs DT is `DT.whoRows()` (`Who.lua`).

## Origin
- **The 0.6.0 walk** (24 Nov, Tim with Lilbit High): typing `/dt gamble deathroll <full name> <stake>` is clumsy
  with two-word names. Lilbit asked for a re-bet button.
- **Tim, 24 Nov 22:22, item by item:**
  - approved: the New game panel (1); challenging your target, with a ruling (2); Accept and Decline (4);
    Cancel and Leave (5); Rematch and Double or nothing, plus Lilbit's re-bet (6); a your-turn glow with a sound
    that's off by default (7); a Table button on the bar (10);
  - for a later round (`dt_gamble_ledger`): titles (8), your record (9), the "only my games" switch (11);
  - an idea only: the right-click party-portrait menu (3).
- **Tim, 22:26:** build order gamble2 → guild quests → ledger, with volunteers on hand tonight.
- Tim didn't answer questions 2, 3 and 6 of 22:24. The answers Claude proposed are written in as T5, T7 and T11,
  and **Tim's merge of this brief ratifies them.**

## Precondition
`main` at `fba3cd7` or later, carrying this brief and its walk-sheet; `run_all.sh` ALL GREEN.

## Rulings in force (cited, not restated)
- `dt_gamble` D1–D10, and the departures from them that the 0.6.0 report records.
- `CLAUDE.md` module rules 1–14, the ruled exceptions, guarded reads, no hooks.
- `dt_pvp` R1: how the target is read for `/dt gank`. T5 below is a second, separate exception.

## Rulings for this round (T1–T12; proposed, ratified by Tim's merge of this brief)
- **T1 The New game panel.** The table window gains a **New game** button, which opens a panel inside the window
  (not a second window):
  - **Stake:** buttons for 10, 50, 100, 250 and 500, plus an edit box for any whole number from 2 to 500. The
    last stake used is remembered for the session only.
  - **Deathroll:** one button per party member running DT. The addon knows who runs it from the `HELLO` /
    `/dt who` list, crossed with `party()`. Members not running DT are shown greyed, with the tooltip
    `Not running Dead Tired.`
  - **Challenge target** (T5).
  - **Open high-low table.**
  - Each button does exactly what the typed command does, with the same checks (D2, D6).
  - In a raid of more than 8, the member list scrolls.
- **T2 Accept and Decline.**
  - A challenge to you shows **Accept**, which is the 0.6.0 Join, and **Decline**.
  - Decline sends `DECLINE { h = <host key>, g = n }`. The challenger's game folds with
    `<name> declined.`, and nothing moves.
  - A high-low table keeps **Join**.
- **T3 Cancel and Leave.**
  - **Cancel:** the host of a challenge or an open table, before rolling starts. It sends the existing `FOLD`,
    which 0.6.0 clients already obey, and everyone sees `<host> cancelled.`
  - **Leave:** a joiner, before Final call. It sends `LEAVE { h, g }`. The host drops them from the table and
    re-arms the 20-second close.
  - Neither is possible once rolling has started. Rolling still ends only by settling, a dispute or the time-out.
- **T4 Rematch, Double or nothing, Same again.**
  - **After a deathroll settles**, both players see **Rematch** (same stake) and **Double or nothing** (twice
    the stake, if both 500 and what you hold allow it; otherwise the button is greyed with the reason).
  - Pressing either sends a fresh `GAME` challenge to the same opponent, which the opponent must **Accept**.
    Either player may offer. The `GAME` carries `re = "1"` (rematch) or `re = "2"` (double) so the challenge
    line can say so: `<name> wants a rematch for <s>.` / `<name> says double or nothing: <s>.`
  - **After a high-low table settles**, the host sees **Same again** (Lilbit's re-bet): a new table at the same
    stake.
- **T5 Challenge your target (a new "reads another player" exception).**
  - `/dt gamble deathroll <stake>` (no name), or the panel's **Challenge target** button, reads **only your
    target's name**, through `GetUnitName("target", true)` (guarded, realm dropped as `party()` does).
  - It reads it only at that press, and the target must be a player in your party. Otherwise it says
    `Target a party member first.` or `<name> isn't in your party.`
  - Nothing else about the target is read or stored. This line joins `CLAUDE.md`'s *Ruled exceptions*.
- **T6 Your turn.** When it becomes your turn, the **Roll** button glows (a pulsing highlight on the button),
  until you roll or the game ends.
  - `gamble.sound` (default **off**) also plays one short built-in game sound at that moment, through guarded
    `PlaySound`. The builder picks a `SOUNDKIT` entry that exists (`READY_CHECK` is the first choice) and records
    it in the report.
  - A card in `/dt settings`, typed as `/dt gamble sound on|off`.
- **T7 Who can offer a rematch.** Either player. It's always a new challenge that needs Accept, so nobody is
  locked into a bet. (This is Claude's proposal, ratified by the merge.)
- **T8 The bar.** The `gamble` module gets an `ldb` launcher, **The Crypt's Table** (icon: a die if a fitting
  built-in icon exists, else the coin). Left-click opens the table; right-click opens the ledger. Its tooltip shows
  `You hold <n> chips.`
- **T9 Compatibility with 0.6.0.**
  - New messages (`DECLINE`, `LEAVE`) and the new `GAME` field `re` are ignored by 0.6.0 clients. 0.6.0's `GAME`
    validation lets an unknown field through; Task 1 re-verifies that.
  - With a 0.6.0 player, Decline and Leave do nothing on their side, and the 2-minute time-out still covers it.
    No chips ever move from a misunderstanding.
  - 0.7.0 never needs a newer peer to settle a game. (This is Claude's proposal, ratified by the merge.)
- **T10 Inbound validation.**
  - `DECLINE` and `LEAVE`: `g` digits only, at most 9; `h` a key string of at most 80 characters; only from a
    player in that game.
  - `re` is only `"1"` or `"2"`; anything else is counted as bad and the `GAME` dropped.
- **T11 Text and quiet.** Nothing new prints unasked, except: `<name> declined.`, `<host> cancelled.` and
  `<name> left the table.`, printed only to players in that game, as the 0.6.0 result lines are.
- **T12 Version.** 0.7.0, a new feature. Guild quests (`dt_guildquests`) moves to 0.8.0. Its brief's version
  lines change in the PR that brings this brief; nothing else in it does.

## Deliverable
On `claude/dt-gamble2` from `main`, DeadTired **0.7.0**. `Gamble.lua` extended with T1–T11; new verbs
`/dt gamble decline`, `/dt gamble cancel`, `/dt gamble leave`, `/dt gamble rematch`, `/dt gamble double`,
`/dt gamble again`, `/dt gamble sound on|off`, and `/dt gamble deathroll <stake>` (the target). Every button has
its typed form.

In the harness, it is done when each of these is shown:
- every panel button starts the same game as its typed command;
- Decline folds the challenger's game;
- Cancel folds for everyone, including a 0.6.0-shaped client;
- Leave drops the joiner and re-arms the close;
- Rematch and Double or nothing raise a new challenge at the same or doubled stake, and need Accept;
- Same again opens a table at the same stake;
- the target challenge works with a party target, and refuses a non-party or missing target;
- the glow follows the turn, and the sound plays only when switched on;
- a 0.6.0 peer still settles a game with a 0.7.0 one.

The round closes with `run_all.sh` ALL GREEN, every Task 7 guard proved red, and `dist/DeadTired-0.7.0.zip`
`diff -r` clean.

## Working rules
- Only `Gamble.lua` and `test_gamble.lua` change, apart from:
  - `Selftest.lua`: new samples (`DECLINE`, `LEAVE`, `GAME` with `re`) and any new API in `DT.REQUIRED`
    (`PlaySound`);
  - `.toc`, `Core.lua` and the test version lines;
  - `CLAUDE.md` (the T5 exception line).
- The 0.6.0 guards stay proved: Task 7 re-runs the 0.6.0 guard script, extended.
- Every global goes through `try`/`clean`. The target is read in exactly one function, which the static test
  checks is the only caller of `GetUnitName("target"` in `Gamble.lua`.
- The sound is played only from the turn change, and only with `gamble.sound` on.

## Tasks
1. **Baseline:** the suites and their counts. Re-verify "Read first"; that 0.6.0's `GAME` validation accepts an
   unknown field; that `PlaySound` is in the SPEC; and that `SOUNDKIT.READY_CHECK` (or the chosen kit) exists, or
   pick one that does.
2. **The panel (T1)** and **the bar launcher (T8)**.
3. **Accept, Decline, Cancel, Leave (T2, T3)**, with their messages and validation (T10).
4. **Rematch, Double or nothing, Same again (T4, T7)**.
5. **The target (T5)**, the **glow and sound (T6)** and its settings card.
6. **Compatibility (T9):** a harness client shaped like 0.6.0 (the new handlers and buttons removed) plays a full
   deathroll and a full high-low with a 0.7.0 client.
7. **Tests and guard proofs.**
   - **Tests:** every T rule, every new verb and its button, the target cases (party, non-party, none, NPC), the
     sound off by default and never played when off, the glow on and off, `fit` for the panel under every skin,
     and the 0.6.0 compatibility runs.
   - **Guards:**
     - the target only on press, and only a party member;
     - Decline only from the challenged player; Leave only before the call; Cancel only by the host, before rolling;
     - Double or nothing respects the 500 cap and what you hold;
     - a rematch needs Accept;
     - the sound off by default;
     - the `DECLINE`/`LEAVE`/`re` validation;
     - every 0.6.0 guard, re-proved.
8. **Docs:**
   - `FEATURES.md`: a new section, *Ruled 24 Nov (for `dt_gamble2`, 0.7.0)*;
   - `CLAUDE.md`: the T5 exception line;
   - `docs/RELEASE_0.7.0.md` (DT's voice; name Lilbit for the re-bet).
9. **Version and zip:** `dist/DeadTired-0.7.0.zip`, `diff -r` clean.
10. **Report** `docs/COWORK_REPORT_dt_gamble2.md`; PR to `main`, not stacked.

## Out of scope
- Titles, your record and the "only my games" switch: `dt_gamble_ledger` (0.9.0).
- The right-click party-portrait menu, or any change to a Blizzard menu.
- Reading anything about the target beyond its name; challenging non-party players.
- Chat posts, gold, prizes in the addon (D1, D9 still hold).
- Changing D4–D7 (the games' rules and how rolls are trusted).

## The one deliberate widening
**T5 reads your target's name.** It is bounded:
- only at a press of Challenge target, or `deathroll <stake>` with no name;
- only the name, through one function;
- only to start a game with a player already in your party;
- it is never stored beyond the game, which holds that name just as a typed name does.

## Stop conditions
- Baseline not ALL GREEN, or `lua5.1` unavailable → stop.
- 0.6.0's `GAME` validation rejects an unknown field (so `re` would break 0.6.0 clients) → stop and report (Tim
  decides: a new message kind instead).
- No `PlaySound` in the SPEC, or no usable `SOUNDKIT` entry → stop the sound part only, build the rest, and report.
- A 0.6.0-shaped client can no longer settle a game with 0.7.0 → stop.
- The panel needs a second window, a hook, or a Blizzard frame → stop.
- A guard removal turns nothing red: strengthen the test (test files only); if that needs addon code → stop.

## UAT: acceptance checks
`docs/UAT_dt_gamble2.md`: **5 [G] offline, 7 [G] in game, 3 [H].** It needs a second guildie on 0.7.0 in Tim's
party, and a third on 0.6.0 for G12 if one is around.

## Reporting
`docs/COWORK_REPORT_dt_gamble2.md`:
- branch and heads; counts per suite;
- the sound kit chosen;
- the compatibility runs;
- each guard proof;
- the new player-facing text, verbatim;
- zip name, size and sha256;
- what the brief got wrong; questions.

Never write a `_results.md` file.
