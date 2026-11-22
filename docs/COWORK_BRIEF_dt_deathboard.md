# Cowork brief: the death leaderboard (0.4.0)

You are in `LUCA5G00N/dead-tired-addon`, building in a cloud session; Tim walks the result in game.
Read first, in order:
1. `CLAUDE.md` on `main`, and `docs/DECISIONS.md` 0001 and 0002.
2. This brief and its walk-sheet, `docs/UAT_dt_deathboard.md`.
3. `DeadTired/Crypt.lua`: `onDead`, `record`, `crypt()`, `isHardcore`, the `crypt.share` setting and
   `ripVerb`.
4. `DeadTired/Played.lua`: the slowest board, the pattern this copies. That means `PLAYED` and
   `PLAYED {off=1}`, `prune`, the 30-day drop, the viewport and its closing line, and the withdraw-on-share-off
   ruling of 12 Nov.
5. `DeadTired/Comms.lua` (`DT.send`, `DT.on`), `DeadTired/UI.lua` (`DT.viewport`, `DT.list`),
   `DeadTired/Ghost.lua` and `DeadTired/Selftest.lua` (the `samples` list).

**Draft-status: written 22 Nov 2026, 19:05, against `main` at `91c28de` (0.3.7, released).** Re-read every
name above against the tree as Task 1's first act.

## Origin
- Liliac's idea; design block G, settled 20 Nov at 19:01 (`claude/27_design_blocks_2026-11-20.md`).
- Rulings L1–L6 agreed by Tim on 22 Nov at 18:56 ("I agree with your leans on L1-6").
- **G2's "top killer" is not built.** No combat data, ever (`CLAUDE.md`). L4 replaces it with the deadliest zone.
- **Order:** block G4 places this after the Waypointer. Tim may build it first. That is settled at the merge
  of this brief and changes nothing in it.

## Precondition
`main` at `91c28de` or later, carrying this brief and its walk-sheet; `run_all.sh` `ALL GREEN`.

## Rulings in force (cited, not restated)
- `CLAUDE.md`: module rules 1–14; no combat data; opt-in for anything personal.
- Card 3 (`dt_crypt` R1, A2): `crypt.share` is the switch for sharing your deaths.
- R-P2-1 and the 12 Nov share-toggle ruling (Played): switching sharing off withdraws your entry.
- R-F4-1 (text through `DT.text`). R-F5-1 (two-line rows where a board needs them).
- `dt_selftest` R-F8-3 (the ghost).

## Rulings for this round (L1–L6, agreed 22 Nov 18:56)
- **L1 Tallies, not the graveyard.** Each guildie who shares their deaths (`crypt.share` on; there is no new
  switch) keeps their own tally. It is sent as a new message, `TALLY`, with these fields:
  - `n`, the total;
  - `w`, this week's count;
  - `we`, the epoch time when this week ends;
  - `hc`, "1" for a hardcore character, else "0".

  It is sent after each of your deaths, and once 10 s after login. Switching `crypt.share` off sends
  `TALLY {off=1}`, and receivers delete your entry. That send happens even while the module is off, as
  Played's does.
- **L2 Since they installed.** The first time this version loads for a character, its tally starts from that
  character's own deaths already in the graveyard (`mine = true`, `who` = the character's key). `w` counts
  those since the last weekly reset. Later deaths add to it. The window's footer says older deaths may not be
  counted.
- **L3 This week.** A week ends at the game's weekly reset (`C_DateAndTime.GetSecondsUntilWeeklyReset`,
  guarded; it is in the beta SPEC).
  - When now is past a tally's `we`, its `w` reads as 0, for your own tally and for every received one.
  - If the reset time can't be read, `we` is 0 and `w` is never zeroed; the self-test's S4 would show it.
- **L4 The deadliest zone.** One footer line naming this week's deadliest zone: `<zone> claimed <n> this
  week.` The count comes from the deaths in your own graveyard since the last reset (yours and the ones you
  heard). With none, the line is left out. The deadliest zone is the only "killer" the board names.
- **L5 The window.**
  - Opened with `/dt deaths`, in the slowest board's style.
  - Rows: name (class-coloured as in 0.3.3, realm-free), total, this week. A hardcore character's name
    carries the skull raid-target icon.
  - Sorted by this week (most first), then total, then name.
  - Entries not heard for 30 days drop off.
  - Empty-state line: `No deaths shared yet. /dt rip share on to join the board.`
  - Closing line: `Only guildies running the addon who share their deaths.`
  - Escape closes it, and its position is remembered.
- **L6 Version.** 0.4.0, a new feature.

## Deliverable
On `claude/dt-deathboard` from `main`, DeadTired **0.4.0**. A new module, `deathboard` (`DeathBoard.lua`),
keeps your tally, shares it under `crypt.share`, and shows `/dt deaths`. In the harness, three clients sharing
deaths see the same board, sorted as L5 says. A week rolling over zeroes `w` everywhere. Switching share off
removes you from every board. The ghost can send a `TALLY`. The round is done when:
- `run_all.sh` is `ALL GREEN`;
- every Task 7 guard has been removed once and turned a named check red;
- `dist/DeadTired-0.4.0.zip` passes `diff -r`.

## Working rules
- `Crypt.lua` gains exactly one line: `DT.signal("mydeath", e)` after `onDead` records your death. DeathBoard
  listens for it, so nothing detects deaths a second time.
- The module meets `CLAUDE.md` module rules 1–14. Its On card governs the window and receiving. Sending
  follows `crypt.share`.
- Inbound `TALLY` is validated:
  - integers with 0 ≤ `w` ≤ `n` ≤ 100000;
  - `we` a number;
  - `hc` "0" or "1".

  Bad ones are counted under `badTally`. The board is capped at 200 entries.
- Guarded reads for the reset timer and the clock.
- No combat event, no killer, no reading of other players beyond their own `TALLY`.

## Tasks
1. **Baseline:** suites and counts; re-verify "Read first".
2. **`DeathBoard.lua`** (loaded after `Crypt.lua` and `Played.lua`):
   - the module, its saved key `DeadTiredDB.deathboard = { mine = { [charKey] = { n, w, we } }, board = { [key] = { n, w, we, hc, at, t } }, badTally }`;
   - the L2 seed, marked once per character;
   - the L3 week;
   - sends, receives and withdraws;
   - the window, the footer and the verb;
   - the `fit` for `/dt debug fit`.
3. **`Crypt.lua`:** the one `mydeath` signal line. **`.toc`:** the new file; 0.4.0.
4. **`Ghost.lua`:** `/dt debug ghost tally`, where the ghost sends `TALLY` `n=13 w=2` with the current week's
   `we`, `hc=0`, and it joins `all`. The ghost's tally is purged with the rest of it (R-F8-5, unchanged).
5. **`Selftest.lua`:** a `TALLY` sample in `samples` (S8, S10). Add `deathboard.board` (cap 200) to `CAPS`.
6. **`Migrate.lua`:** nothing unless the seed needs it; if so, the report says why.
7. **Tests and guard proofs** (`test_deathboard.lua`, plus additions to `test_ghost` and `test_selftest`).
   - **Tests:**
     - the seed, counted once;
     - your death adds 1 to `n` and `w`;
     - the week rolls (own and received);
     - send gated on `crypt.share`, and the off-withdraw even while the module is off;
     - receive validated, counted and capped;
     - the 30-day drop;
     - the sort;
     - the footer (present, and absent);
     - the hardcore icon;
     - the empty state and the closing line;
     - the window fits under every skin;
     - three clients agree;
     - nothing outside the guild;
     - the module off neither receives nor shows.
   - **Guards** (remove once, a named check red, restore): the share gate; the withdraw; the off-withdraw
     while off; validation; the cap; the 30-day drop; the week zeroing; the seed-once marker; the guild gate;
     the module switch. Also every guard 0.3.7 proved.
8. **Docs:** `FEATURES.md` *Ruled 22 Nov (for `dt_deathboard`, 0.4.0)*; `docs/RELEASE_0.4.0.md` (DT's voice;
   a few lines: the board, how to join it, and that only sharers appear). Draft the #dt-crypt-workshop post in
   the PR.
9. **Version and zip:** `dist/DeadTired-0.4.0.zip`, `diff -r` clean.
10. **Report** `docs/COWORK_REPORT_dt_deathboard.md`; PR to `main`, not stacked.

## Out of scope
- A killer of any kind.
- A Discord bridge (G1: later).
- Achievements, the Pilgrimage, or guild quests.
- Changing what `DEATH` carries or how the graveyard keeps deaths.
- A new share switch.
- Back-filling other players' history.
- Gambling.

## The one deliberate widening
A new shared fact, your running death count, sent under the existing `crypt.share` switch. Players who
switched share on agreed to share each death; the count is the sum of those deaths. Bounded by:
- off by default (`crypt.share` defaults off);
- the off-switch withdraws it from every board;
- the message carries numbers only.

## Stop conditions
- Baseline not `ALL GREEN`, or `lua5.1` can't be installed → stop.
- `GetSecondsUntilWeeklyReset` absent in the harness's SPEC list or unusable for L3 → stop and report.
- The seed needs anything but the graveyard's own `mine` deaths → stop.
- Any change to `Crypt.lua` beyond the one signal line → stop.
- A guard removal turns nothing red: strengthen the test (test files only); if that needs addon code → stop.

## UAT: acceptance checks
`docs/UAT_dt_deathboard.md`: **5 [G] offline, 3 [G] in game, 2 [H].**

## Reporting
`docs/COWORK_REPORT_dt_deathboard.md`:
- branch and heads; counts per suite;
- the seed's numbers on a harness character with planted deaths;
- each guard proof;
- the player-facing text, verbatim;
- zip name, size, sha256;
- what the brief got wrong; questions.

Never write a `_results.md` file.
