# Walk-sheet: guild quests, the first two arcs (0.8.0)

Brief: `docs/COWORK_BRIEF_dt_guildquests.md`.
- **[G]** offline: the build session proves it in its report.
- **[G]** in game: Tim types, and what's on screen decides.
- **[H]**: Tim's judgement.

**5 [G] offline, 5 [G] in game, 2 [H].** Back up first, into `_dt_backups\<date>_before_0.8.0`. Walk on Stromham
(bag arc finished 22 Nov). G9 needs one library book handed in to Owen Thadd beforehand.

## Offline [G]
- [ ] G1 `run_all.sh` is ALL GREEN, with counts. The zip is `diff -r` clean. `.toc` and `DT.VERSION` read 0.8.0.
- [ ] G2 The bag arc:
      - 0, 3 and 7 steps read right; Rekindle never changes Next step or finished;
      - step 1 follows the faction, and its waypoint follows `IsOnQuest`;
      - a failed read shows `…` and counts as not done.
- [ ] G3 The library:
      - 0, 9, 10, 14 and 39 books give the right count and tier line; a claimed tier shows as claimed;
      - sort and search as Q3 says.
- [ ] G4 Sharing and the board:
      - `QUESTS` sent at login and on one of our turn-ins only; `off` withdraws, even with the module off;
      - inbound validation, the 200 cap and the 30-day drop;
      - the board's sort, the first-finisher footer, the closing and empty-state lines; text fits under every skin;
      - Next step, a row click and Nearest book each call `DT.waySet` with the table's place.
- [ ] G5 Every Task 7 guard was removed once, turned a named check red, and was restored. `/dt selftest` in the
      harness reads all passed.

## In game [G]
- [ ] G6 `/dt quests`, The Sleeping Bag tab: Stromham shows 7/7 (done), with Rekindle marked optional.
- [ ] G7 The Library tab: press **Nearest book**. The arrow and pin go to an unread book on your continent, and
      the arrow's place line names that book.
- [ ] G8 `/dt debug ghost on`, `/dt debug ghost quests`: the Restless Ghost is on the board with `Bag: 3/7` and
      `Books: 3`. `/dt debug ghost off`.
- [ ] G9 The book you handed in shows as done, and your count includes it. **If it reads not done, stop: the book
      IDs are wrong.**
- [ ] G10 `/dt quests share off`: you're gone from your own board. `/dt quests share on`: you're back.

## In game [H]
- [ ] H1 Does the window make you want to go and fetch the next book? Screenshot the Library tab.
- [ ] H2 Is anything shared that a guildie might not want shared? (If yes, that reopens Q4's default.)
