# Walk-sheet: the death leaderboard (0.4.0)

Brief: `docs/COWORK_BRIEF_dt_deathboard.md`.
- **[G]** offline: the build session proves it in its report.
- **[G]** in game: Tim types, and the window or the saved file decides.
- **[H]**: Tim's judgement.

**5 [G] offline, 3 [G] in game, 2 [H].** Back up first, into `_dt_backups\<date>_before_0.4.0`.

## Offline [G]
- [ ] G1 `run_all.sh` is ALL GREEN, with counts. The zip is `diff -r` clean. `.toc` and `DT.VERSION` read 0.4.0.
- [ ] G2 The seed counts a character's own graveyard deaths once. A death adds 1 to both columns. The week
      rolls over at the reset, for your own tally and received ones.
- [ ] G3 Sharing:
      - sending happens only with `crypt.share` on;
      - share off withdraws you from every board, even with the module off;
      - inbound `TALLY` is validated, counted and capped at 200;
      - entries drop after 30 days.
- [ ] G4 The window:
      - sorted by this week, then total, then name;
      - the footer shows the deadliest zone, or no footer with none;
      - hardcore characters get the skull;
      - empty-state and closing lines present;
      - the text fits under every skin.
- [ ] G5 Every Task 7 guard was removed once, turned a named check red, and was restored. `/dt selftest` in the
      harness reads 10 passed.

## In game [G]
- [ ] G6 `/dt rip share on`, then `/dt deaths`: you're listed. Your total is at least the number of your own
      deaths in `/dt graveyard`.
- [ ] G7 `/dt debug ghost on`, `/dt debug ghost tally`, then `/dt deaths`: the Restless Ghost is listed, with
      13 total and 2 this week. Then `/dt debug ghost off`.
- [ ] G8 `/dt rip share off`, then `/dt deaths`: you're gone from your own board. Turn sharing back on
      afterwards if you want it.

## In game [H]
- [ ] H1 Does the board read well? Look at the columns, the skull and the footer line, and take a screenshot.
- [ ] H2 Would Liliac recognise this as the leaderboard she asked for, without the killer?
