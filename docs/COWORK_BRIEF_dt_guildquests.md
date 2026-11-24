# Cowork brief: guild quests, the first two arcs (0.8.0)

You are in `LUCA5G00N/dead-tired-addon`, building in a cloud session; Tim walks the result in game.
Read first, in order:
1. `CLAUDE.md` on `main`, and `docs/DECISIONS.md` 0001 and 0002.
2. This brief and its walk-sheet, `docs/UAT_dt_guildquests.md`.
3. `DeadTired/WayBooks.lua` (`DT.WAY_BOOKS`: the 39 books with their quest IDs) and `DeadTired/Way.lua`
   (`DT.waySet`, `DT.wayZone`, `DT.wayReading`, `DT.wayRows`): the data this round reads and the Waypointer it
   hands off to.
4. `DeadTired/DeathBoard.lua` (0.4.0): the shared-board pattern (`TALLY`, `TALLY {off=1}`, validation, the cap,
   the viewport, the footer).
5. `DeadTired/Comms.lua` (`DT.send`, `DT.on`), `DeadTired/UI.lua` (`DT.viewport`, `DT.list`, `DT.text`),
   `DeadTired/Ghost.lua`, `DeadTired/Selftest.lua` (`DT.REQUIRED`, `CAPS`, the samples).
6. `reference/SPEC_forever_namespaces.md`: `C_QuestLog` (`IsQuestFlaggedCompleted`, `IsOnQuest`).

**Draft status: written 23 Nov 2026, 20:40, against `main` at `afbf0d6` (0.5.0 released; the `dt_gamble` brief
merged, not built).** This round builds **after** `dt_gamble` (0.6.0) and `dt_gamble2` (0.7.0) are merged (Tim, 24 Nov 22:26: the
order is gamble2, then guild quests, then the ledger); the version moved from 0.7.0 to 0.8.0 with that, and nothing
else changed. Every name above is re-read against the tree as Task 1's first act.

## Origin
- Tim, 22 Nov 18:56, "The Sweaty SoD Achievement": the first guild quests borrow two quest lines that came to
  Forever from Season of Discovery (`claude/37_…`).
- Both arcs researched 22 Nov 20:25, with quest IDs from Wowhead and Warcraft Tavern (`claude/39_…`).
- **Probe, Tim, 22 Nov 20:24–20:25** (`WoWScrnShot_112226_202509.jpg`): `C_QuestLog.IsQuestFlaggedCompleted`
  works on Forever. 79976 (This Must Be The Place) and 79007 (the Horde start) read **true** on Stromham; 78150
  (Friend of the Library) reads false, as expected. **No book's own ID is confirmed yet** (see the stop
  conditions).
- The roadmap's *Restless Dead Pilgrimage* (`FEATURES.md`): guild adventures. This is its first round.
- **Tim, 23 Nov 20:21:** one quest for the whole sleeping-bag arc; a book-by-book tracker for the library; anyone
  running the addon sees progress, with an opt-out; and a hand-off to the Waypointer.

## Precondition
`main` carrying `dt_gamble2` merged (0.7.0) and this brief and its walk-sheet; `run_all.sh` `ALL GREEN`.

## Rulings in force (cited, not restated)
- `CLAUDE.md`: module rules 1–14 (rule 5 is widened, below); guarded reads; no combat data; no hooks.
- W1–W6 (`dt_waypointer`): how a waypoint is set, and that there is only one.
- L3 (`dt_deathboard`): the weekly reset read (used here only for "this week" in the footer).
- R-F4-1 (text through `DT.text`). R-F5-1 (two-line rows). R-P2-2 (Escape closes). `dt_selftest` R-F8-3 (the
  ghost).

## Rulings for this round (Q1–Q9; proposed, ratified by Tim's merge of this brief)
- **Q1 Progress is the game's own.** A step or a book is done when `C_QuestLog.IsQuestFlaggedCompleted(<ID>)`
  returns true, read guarded. Nothing is typed in or ticked by hand, so nothing can be faked. A secret or failed
  read counts as not done, and the window shows `…` for that row.
- **Q2 The Sleeping Bag Pilgrimage: one quest, seven steps.** Its steps, in order, from `claude/39_…`:

  | # | Step | ID | Waypoint (zone, x, y) |
  |---|---|---|---|
  | 1 | …and that note you found | 79007 (Horde) or 79008 (Alliance), by the player's faction | not on it: The Barrens 46, 74 (the burned tower). On it (`IsOnQuest`): Westfall 37, 50 (Alexston Farmstead) |
  | 2 | Stepping Stones | 79192 | Stonetalon Mountains 40.6, 52.4 |
  | 3 | Rekindle (optional) | 80001 | Stonetalon Mountains 40.6, 52.4 |
  | 4 | Scramble | 79980 | Stonetalon Mountains 39.6, 49.8 |
  | 5 | Wet Job | 79974 | Loch Modan 49.4, 12.9 |
  | 6 | Eagle's Fist | 79975 | Hillsbrad Foothills 87.3, 49.6 |
  | 7 | This Must Be The Place | 79976 | Hillsbrad Foothills 87.3, 49.6 |

  - The arc is **finished** when step 7 is done. Rekindle is shown, marked optional, and never counted against
    finishing.
  - The window lists the steps with done or not, and a **Next step** button that sets a waypoint (Q5) to the
    first step not done (skipping Rekindle). Step 5's row carries the note `Dwarf country. Bring a friend.`
  - Data lives in a new data file, `QuestArcs.lua`, with the source cited at the top, like `WayBooks.lua`.
- **Q3 Friends of the Library: book by book.** The 39 books are `DT.WAY_BOOKS`; their quest IDs are already
  there. No second list is made.
  - Each book row shows done or not, its zone and level band, and (tooltip) the guildies who have handed it in.
  - A header shows your count and the next reward tier: 10 (78150), 20 (79536), 25 (82208), 35 (84394). For
    example `14 books. 6 more to Greater Friend of the Library (20).` A tier's reward quest done shows its tier as
    claimed.
  - Sort: not done first, then by level band, then name. A search box, as in `/dt way list`.
  - Antonidas (Ironforge) and the Alliance-hub books keep the notes `WayBooks.lua` already has; nothing is hidden.
- **Q4 Shared by default, with an opt-out.** Every guildie running the addon sends their progress, and sees
  everyone's.
  - `QUESTS { bag = <steps done, as a string of the step numbers, e.g. "1247">, lib = <book quest IDs done,
    comma-separated> }`, sent once 15 s after login and after each `QUEST_TURNED_IN` whose ID is one of ours.
  - `/dt quests share off` sends `QUESTS {off=1}`; receivers delete you; nothing more is sent until
    `/dt quests share on`. The setting is on by default and has a card in `/dt settings`.
  - Inbound `QUESTS` is validated: `bag` only digits 1–7, `lib` only IDs that are in `DT.WAY_BOOKS`; anything else
    is counted as bad and dropped. Entries drop after 30 days unseen; the board caps at 200.
- **Q5 The Waypointer hand-off.** Clicking a book row, or **Next step**, calls `DT.waySet` for that place, exactly
  as a click in `/dt way list` does (W1–W6 apply: one waypoint, the pin, the arrow). **Nearest book** sets the
  closest book not done on your current continent, by `DT.wayReading`'s yards; with none on this continent it
  says `No unread books on this continent.` `Way.lua` is not changed.
- **Q6 The guild view.** Below your own progress, one board: guildies who share, with `Bag: 5/7` (or `Bag: done`
  with a sleeping-bag icon) and `Books: 14`. Sorted by books, then bag, then name. Footer: `First to the bag:
  <name>.` (the earliest finisher DT has heard of, kept once seen), left out with none; and the closing line
  `Only guildies running the addon who share their quests.`
- **Q7 The window.** `/dt quests` opens one window with two tabs, **The Sleeping Bag** and **The Library**, each
  with its own part of the board (Q6). Draggable, place remembered, Escape closes. Empty state on the board:
  `Nobody's sharing yet. Be the first fool on the road.`
- **Q8 Quiet.** Nothing prints unasked. Finishing the bag arc or a book tier prints nothing; the window shows it.
- **Q9 Version.** 0.8.0, a new feature.

## Deliverable
On `claude/dt-guildquests` from `main`, DeadTired **0.8.0**. A new module, `quests` (`Quests.lua`, data in
`QuestArcs.lua`), with:
- the verbs `/dt quests`, `/dt quests share on|off`, and the window's **Next step** and **Nearest book** buttons;
- the window (two tabs, your progress and the guild board).

In the harness, with `IsQuestFlaggedCompleted`, `IsOnQuest` and the player's faction stubbed:
- the bag arc reads 0–7 steps right, skips Rekindle for Next step and for finishing, and picks step 1's waypoint
  by `IsOnQuest`;
- the library counts books, names the next tier, and sorts as Q3 says;
- `QUESTS` round-trips between two fake guildies, and `off` withdraws;
- Next step and Nearest book call `DT.waySet` with the right place.

The round is done when:
- `run_all.sh` is `ALL GREEN`;
- every Task 7 guard has been removed once and turned a named check red;
- `dist/DeadTired-0.8.0.zip` passes `diff -r`.

## Working rules
- No module but `quests` changes, apart from:
  - `Selftest.lua`: new APIs in `DT.REQUIRED`, the new store in `CAPS`, a ghost sample;
  - `Ghost.lua`: the ghost's `QUESTS` entry (Task 5);
  - `.toc`; `Core.lua` (`DT.VERSION`); test version lines.

  `Way.lua`, `WayBooks.lua` and `Comms.lua` are not changed. No library is added. Nothing is borrowed from
  ForeverBooks or ForeverSecrets.
- Every `C_QuestLog`, `UnitFactionGroup` and global call goes through `try`/`clean`.
- Quest flags are read at login (after 15 s), on `QUEST_TURNED_IN` for one of our IDs, and when the window opens.
  Never on a timer.
- Store: `DeadTiredDB.quests = { board = { [key] = { bag, lib, seen, done } }, first = { key, at } }`, the board
  capped at 200 entries. Your own progress is never stored: it is read from the game each time.

## Tasks
1. **Baseline:** suites and counts; re-verify "Read first", `C_QuestLog.IsQuestFlaggedCompleted` and
   `C_QuestLog.IsOnQuest` in the SPEC, and that `DT.WAY_BOOKS` still holds 39 books with quest IDs.
2. **`QuestArcs.lua`:** the bag arc's table (Q2), with its source cited.
3. **`Quests.lua`:** the module; the reads (Q1); the bag arc (Q2) and the library (Q3); sharing (Q4); the
   hand-off (Q5); the board and footer (Q6); the window and its tabs (Q7); the `fit`.
4. **Settings:** the `quests.share` card (default on), with `/dt quests share on|off` as its typed form.
5. **The ghost:** `/dt debug ghost quests` makes the Restless Ghost send `QUESTS { bag = "123", lib = <three book
   IDs> }`, so the board can be walked alone.
6. **`Selftest.lua`, `.toc`, `Core.lua`:** `C_QuestLog.IsQuestFlaggedCompleted`, `C_QuestLog.IsOnQuest` and
   `UnitFactionGroup` in `DT.REQUIRED`; `quests.board` (cap 200) in `CAPS`; the two files after `Gamble.lua`;
   0.8.0.
7. **Tests and guard proofs** (`tests/test_quests.lua`; additions to `test_selftest`).
   - **Tests:**
     - the bag: 0, 3 and 7 steps done; Rekindle done or not changes neither Next step nor finished; Horde and
       Alliance step 1; step 1's waypoint on and off the quest; a failed read shows `…`;
     - the library: 0, 9, 10, 14 and 39 books; each tier's line; a claimed tier; sort; search; the empty search;
     - the hand-off: Next step, a book row click and Nearest book each call `DT.waySet` with the table's place;
       Nearest with nothing on the continent;
     - sharing: send at login and on a matching turn-in only; `off` withdraws, even with the module off; inbound
       validation (bad `bag`, an unknown ID, junk); the 200 cap; the 30-day drop;
     - the board: sort, the bag icon, the first-finisher footer kept once seen, the closing line, the empty state;
     - fit under every skin; nothing outside the guild; the module off does nothing; nothing prints unasked.
   - **Guards** (remove once, a named check red, restore):
     - the faction pick; the Rekindle skip; the failed-read-is-not-done; the tier thresholds;
     - the turn-in ID filter; withdraw on `off`; inbound validation; the board cap; the 30-day drop;
     - the Nearest continent check; the guild gate; the module switch;
     - every guard 0.7.0 proved.
8. **Docs:** `FEATURES.md` *Ruled 23 Nov (for `dt_guildquests`, 0.8.0)*, and `CLAUDE.md`'s *Ruled exceptions*
   gains the line for Q4 (the widening below); `docs/RELEASE_0.8.0.md` (DT's voice, a few lines).
9. **Version and zip:** `dist/DeadTired-0.8.0.zip`, `diff -r` clean.
10. **Report** `docs/COWORK_REPORT_dt_guildquests.md`; PR to `main`, not stacked.

## Out of scope
- Any arc beyond these two (dungeon quests, class quests, the initiation route).
- Guild rewards, achievements, or anything that prints a celebration.
- Telling guildies when someone finishes (a death-notice-style line): it would need a *prints unasked* ruling.
- Routes of several waypoints, or "the next three books".
- Reading quest objectives or the quest log beyond `IsOnQuest` for step 1.
- The account-wide flag (`IsQuestFlaggedCompletedOnAccount`): progress is per character.
- Posting anything to chat or Discord (the bot's obituary-style bridge is parked).

## The one deliberate widening
**Q4 shares by default.** `CLAUDE.md` rule 5 says anything personal is opt-in and off by default; Tim ruled on
23 Nov 20:21 that quest progress is shared with an opt-out instead. It is bounded:
- only which of *these* quest IDs (the 8 bag steps and the 39 books) are done, never the rest of the quest log,
  the player's position, or when;
- only to guildies running the addon;
- one switch withdraws it from every board at once, even with the module off;
- it joins `CLAUDE.md`'s *Ruled exceptions* under "Shares without a separate opt-in", so nobody "fixes" it.

## Stop conditions
- Baseline not `ALL GREEN`, or `lua5.1` can't be installed → stop.
- `C_QuestLog.IsQuestFlaggedCompleted` or `C_QuestLog.IsOnQuest` is absent from the SPEC → stop.
- `DT.WAY_BOOKS` no longer holds 39 books with quest IDs → stop and report.
- The hand-off needs a change to `Way.lua` → stop and report (Tim decides whether `Way.lua` opens).
- A guard removal turns nothing red: strengthen the test (test files only); if that needs addon code → stop.
- **At the walk, not the build:** a book Tim has handed in reads not done (G9 of the walk-sheet). Then the book
  IDs are wrong: stop the merge and report which.

## UAT: acceptance checks
`docs/UAT_dt_guildquests.md`: **5 [G] offline, 5 [G] in game, 2 [H].** G9 needs one book handed in by the walking
character.

## Reporting
`docs/COWORK_REPORT_dt_guildquests.md`:
- branch and heads; counts per suite;
- the bag table and the tier lines as built;
- each guard proof;
- the player-facing text, verbatim;
- zip name, size, sha256;
- what the brief got wrong; questions.

Never write a `_results.md` file.
