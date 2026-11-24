# Walk-sheet: the Crypt's Ledger (0.9.0)

Brief: `docs/COWORK_BRIEF_dt_gamble_ledger.md`.
- **[G]** offline: the build session proves it in its report.
- **[G]** in game: Tim types, and what's on screen decides.
- **[H]**: Tim's judgement.

**4 [G] offline, 4 [G] in game, 2 [H].** Back up first, into `_dt_backups\<date>_before_0.9.0`. G6–G8 need a
guildie on 0.9.0 in your party.

## Offline [G]
- [ ] G1 `run_all.sh` is ALL GREEN, with counts. The zip is `diff -r` clean. `.toc` and `DT.VERSION` read 0.9.0.
- [ ] G2 In the harness:
      - scripted weeks give the right holder and count for Lucky Devil, Marathon and Hot Streak;
      - disputed and folded games count for nothing;
      - a 0.8.0 peer's `CHIPS` reads as zeros.
- [ ] G3 The record:
      - holds your own games only, capped at 200, and survives the weekly top-up;
      - the head-to-head sums are right;
      - forget clears only your own character's record.
- [ ] G4 `onlymine` hides exactly the games you're not in. Every guard was removed once, turned a named check red,
      and was restored.

## In game [G]
- [ ] G5 Alone: the ledger's **Your record** view shows `No games yet. The dice are waiting.` on a character that
      hasn't played since the update (or after `/dt gamble forget`).
- [ ] G6 Play three deathrolls with the guildie. **Your record** lists all three, newest first, and the head-to-head
      line for them shows the right wins, losses and net chips.
- [ ] G7 The ledger footer names a Marathon holder with the longest of those deathrolls' roll count (or the
      Titles tooltip does, if the report says they moved there).
- [ ] G8 `/dt gamble onlymine on`: a game between two other party members disappears from your table list.
      `/dt gamble onlymine off` brings it back.

## In game [H]
- [ ] H1 Do the titles give the officers something worth awarding? Screenshot the footer or the tooltip.
- [ ] H2 Is your record something you'd check after an evening of play?
