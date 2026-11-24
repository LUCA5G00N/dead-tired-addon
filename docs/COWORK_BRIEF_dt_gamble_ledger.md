# Cowork brief: the Crypt's Ledger: titles, your record, only my games (0.9.0)

You are in `LUCA5G00N/dead-tired-addon`, building in a cloud session; Tim walks the result in game.
Read first, in order:
1. `CLAUDE.md` on `main`, and `docs/DECISIONS.md` 0001 and 0002.
2. This brief and its walk-sheet, `docs/UAT_dt_gamble_ledger.md`.
3. `docs/COWORK_BRIEF_dt_gamble.md` (D1–D10) and `docs/COWORK_BRIEF_dt_gamble2.md` (T1–T12), with both reports.
4. `DeadTired/Gamble.lua` as 0.7.0 left it: the wallet (`wallet()`), `CHIPS` and its validation (`validChips`),
   the board (`DT.gambleRows`, `DT.gambleFooter`), and the table list (`DT.gambleGameRows`).

**Draft status: written 24 Nov 2026, 22:40, against `main` at `fba3cd7` (0.6.0).** It builds third, after
`dt_gamble2` (0.7.0) and `dt_guildquests` (0.8.0) (Tim, 22:26). By then `Gamble.lua` will have moved: every name
above is re-read against the tree as Task 1's first act. A name that no longer exists is a stop condition, not
something to guess at.

## Origin
- Claude's suggestions, 24 Nov 22:20; Tim, 22:22:
  - item 8, more weekly titles beside Biggest beat-down: "aye good ideas we can add those";
  - item 9, your record: "yes handy to see you own recents";
  - item 11, a "show only my games" switch: "yes good idea" (from his visibility review of 0.6.0).
- Tim didn't answer questions 4, 5 and 7 of 22:24. The answers Claude proposed are written in as K1, K3 and K5, and
  **Tim's merge of this brief ratifies them.**

## Precondition
`main` carrying `dt_guildquests` merged (0.8.0), and this brief and its walk-sheet; `run_all.sh` ALL GREEN.

## Rulings in force (cited, not restated)
- `dt_gamble` D1–D10 (D8 is the board this round extends), `dt_gamble2` T1–T12.
- `CLAUDE.md` module rules 1–14 (rule 5: anything personal is opt-in; the board's opt-in is playing, D8).

## Rulings for this round (K1–K7; proposed, ratified by Tim's merge of this brief)
- **K1 Three weekly titles**, beside Biggest beat-down, counted per character for the week that ends at the reset
  (L3):
  - **Lucky Devil:** the most rolls of the very top of the range (a roll equal to the max, e.g. 100 on 1-100), in
    settled games.
  - **Marathon:** the most rolls in a single settled deathroll (both players' rolls counted).
  - **Hot Streak:** the longest run of games won in a row this week. A high-low counts as a win for its highest
    roller only; a loss or the middle of a high-low breaks the run.

  Disputed, folded and timed-out games count for nothing.
- **K2 The board carries them.** `CHIPS` gains `lk` (Lucky Devil count), `mr` (Marathon best) and `hs` (Hot Streak
  best), each a whole number from 0 to 100,000, read as 0 when absent. Older clients ignore the new fields.
  - The ledger's footer names each title holder: `Lucky Devil: <name> (<n>).`, `Marathon: <name> (<n> rolls).`,
    `Hot Streak: <name> (<n> wins).`
  - Each line is left out when nobody holds the title. A tie goes to the alphabetically first name, as Biggest
    beat-down does.
  - The footer still ends with the closing line. If the footer no longer fits, the titles move into the ledger's
    tooltip on a **Titles** line, and the builder records which happened.
- **K3 Your record** (only on your machine, never sent):
  - `DeadTiredDB.gamble.history[<char key>]`: one entry per settled or disputed game you played, holding the time,
    the kind, the opponent(s), the stake, your chip change and the outcome. Capped at 200 per character, oldest
    first out.
  - A **Your record** view, as a tab or a button in the ledger window, shows your **last 10 games** and your
    **head-to-head** with each guildie you've played (wins, losses, net chips). The head-to-head is built from
    those up to 200 games.
  - Empty: `No games yet. The dice are waiting.`
- **K4 Lifetime of the record.** It is kept across weeks and never reset by the top-up (D3). `/dt gamble forget`
  clears your own record, after confirming in the window (a button, not a popup).
- **K5 Only my games.** `gamble.onlymine`, default **off** (everyone sees every game in the party, as now). On, the
  table's list shows only games you host, joined, or were challenged to. A card in `/dt settings`, typed as
  `/dt gamble onlymine on|off`.
- **K6 Nothing new is shared beyond K2's three numbers.** The record stays local. Titles come only from players who
  are on the board (D8).
- **K7 Version.** 0.9.0, a new feature.

## Deliverable
On `claude/dt-gamble-ledger` from `main`, DeadTired **0.9.0**. `Gamble.lua` gains:
- the title counters (K1), `CHIPS` `lk/mr/hs` (K2) and the footer lines;
- the record store and its view (K3, K4), and `/dt gamble forget`;
- the only-my-games switch (K5).

In the harness, it is done when each of these is shown:
- scripted weeks of games produce the right holder and count for each title;
- disputed and folded games count for nothing;
- the record holds the right entries, caps at 200 and survives a reset;
- the head-to-head sums the right wins, losses and net chips;
- `onlymine` hides exactly the games you're not in;
- a 0.8.0-shaped peer's `CHIPS`, without the new fields, reads as zeros.

The round closes with `run_all.sh` ALL GREEN, every guard proved red, and `dist/DeadTired-0.9.0.zip` `diff -r`
clean.

## Working rules
- Only `Gamble.lua` and its tests change, apart from `Selftest.lua` (`CAPS`: `gamble.history`, 200 per character;
  the `CHIPS` sample gains the new fields), `.toc`, `Core.lua`, the test version lines and the docs below.
- The record is written only by your own settled or disputed games, never from a message.
- Every new number from a message is validated and capped; a bad one counts as bad and drops the message.

## Tasks
1. **Baseline**, and re-verify "Read first" against 0.8.0's tree.
2. **Counters (K1):** Lucky Devil, Marathon and Hot Streak, reset at the weekly rollover with `w`/`bb`.
3. **`CHIPS` and the footer (K2)**, including the fit check and the tooltip fallback.
4. **The record and its view (K3, K4)**, and **the switch (K5)**.
5. **Selftest, `.toc`, `Core.lua`.**
6. **Tests and guard proofs.**
   - **Tests:** every K rule; week rollover; ties; old-peer `CHIPS`; the record cap and order; forget; `onlymine` on
     and off; `fit` under every skin.
   - **Guards:**
     - disputed and folded games count for nothing;
     - only a high-low's highest roller gets a win;
     - the counters reset at the rollover;
     - the `lk/mr/hs` validation and caps;
     - the record cap;
     - the record written only by your own games;
     - forget clears only your own character's record;
     - the `onlymine` filter;
     - every 0.8.0 gamble guard.
7. **Docs:** `FEATURES.md` *Ruled 24 Nov (for `dt_gamble_ledger`, 0.9.0)*; `docs/RELEASE_0.9.0.md`.
8. **Version and zip** `dist/DeadTired-0.9.0.zip`; **Report** `docs/COWORK_REPORT_dt_gamble_ledger.md`; PR to
   `main`, not stacked.

## Out of scope
- Sending your record, or any history, to anyone.
- An all-time board, achievements, or prizes in the addon.
- New games, and anything in `dt_gamble2`'s scope.

## Stop conditions
- Baseline not ALL GREEN, or a name in "Read first" missing from 0.8.0's tree → stop and report.
- A title needs a roll the client didn't see (anything beyond each client's own reading, D7) → stop.
- A guard removal turns nothing red: strengthen the test (test files only); if that needs addon code → stop.

## UAT: acceptance checks
`docs/UAT_dt_gamble_ledger.md`: **4 [G] offline, 4 [G] in game, 2 [H].** It needs a second guildie on 0.9.0 in Tim's
party.

## Reporting
`docs/COWORK_REPORT_dt_gamble_ledger.md`:
- branch and heads; counts per suite;
- a worked week of titles from the harness;
- whether the titles fit in the footer or moved to the tooltip;
- each guard proof;
- the new player-facing text, verbatim;
- zip name, size and sha256;
- what the brief got wrong; questions.

Never write a `_results.md` file.
