# Walk-sheet: the Crypt's Table, round 2 (0.7.0)

Brief: `docs/COWORK_BRIEF_dt_gamble2.md`.
- **[G]** offline: the build session proves it in its report.
- **[G]** in game: Tim types, and what's on screen decides.
- **[H]**: Tim's judgement.

**5 [G] offline, 7 [G] in game, 3 [H].** Back up first, into `_dt_backups\<date>_before_0.7.0`. Every in-game
check except G6 needs a guildie on 0.7.0 in your party. G12 needs a third guildie still on 0.6.0, if one is around.

## Offline [G]
- [ ] G1 `run_all.sh` is ALL GREEN, with counts. The zip is `diff -r` clean. `.toc` and `DT.VERSION` read 0.7.0.
- [ ] G2 Every panel button starts the same game as its typed command. Decline, Cancel and Leave behave as T2 and
      T3 say. Rematch and Double or nothing need Accept. Same again opens a table at the same stake.
- [ ] G3 The target challenge works with a party target, and refuses a non-party target, an NPC and no target.
      `GetUnitName("target"` appears in exactly one function of `Gamble.lua`.
- [ ] G4 The sound is off by default and never plays when off. The glow follows the turn.
- [ ] G5 A 0.6.0-shaped client settles a deathroll and a high-low with a 0.7.0 one. Every Task 7 guard, and every
      0.6.0 guard, was removed once, turned a named check red, and was restored.

## In game [G]
- [ ] G6 Alone: the Table button is on the DT bar. Left-click opens the table, right-click opens the ledger, and
      the tooltip shows your chips.
- [ ] G7 **New game**: press the guildie's name, then **50**, then **Deathroll**. They see `Accept` and `Decline`,
      and press Accept. Play to the end. Both of you then see **Rematch** and **Double or nothing**.
- [ ] G8 Press **Double or nothing**. They see `<you> says double or nothing: 100.` and press **Decline**. Your
      window shows `<name> declined.` and nothing moves.
- [ ] G9 Target the guildie, then `/dt gamble deathroll 20`. The challenge goes to them. Target an NPC and try
      again: `Target a party member first.`
- [ ] G10 Open a high-low table; the guildie joins, then presses **Leave**: they're gone from your table. Then
       **Cancel** your table: they see `<you> cancelled.`
- [ ] G11 Play a high-low to the end. **Same again** opens a new table at the same stake.
- [ ] G12 (If a 0.6.0 guildie is around.) Deathroll them from 0.7.0. They Join with the 0.6.0 button, you play,
       and it settles on both sides.

## In game [H]
- [ ] H1 Is starting a game now quicker than typing? Screenshot the New game panel.
- [ ] H2 With `/dt gamble sound on`, is the your-turn sound useful, or annoying? (That decides whether it stays.)
- [ ] H3 Did Lilbit get the re-bet they asked for?
