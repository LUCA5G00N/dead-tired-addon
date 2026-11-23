# Walk-sheet: the Crypt's Table, guild gambling (0.6.0)

Brief: `docs/COWORK_BRIEF_dt_gamble.md`.
- **[G]** offline: the build session proves it in its report.
- **[G]** in game: Tim types, and what's on screen decides.
- **[H]**: Tim's judgement.

**5 [G] offline, 5 [G] in game, 3 [H].** Back up first, into `_dt_backups\<date>_before_0.6.0`. G7–G9 and H1–H2
need a second guildie on 0.6.0 in your party; H2's tie needs a third if one turns up.

## Offline [G]
- [ ] G1 `run_all.sh` is ALL GREEN, with counts. The zip is `diff -r` clean. `.toc` and `DT.VERSION` read 0.6.0.
- [ ] G2 The roll reader:
      - parses the probe's exact strings, and a format with its fields in another order;
      - skips junk and secret messages without an error.
- [ ] G3 The games, in the harness:
      - a deathroll ends on a 1 and moves *S* chips;
      - a three-player high-low moves the difference from lowest to highest;
      - ties at either end are rolled off; one player at the close folds;
      - stakes outside 2–500, or more than you hold, are refused;
      - out-of-turn, wrong-range and outside-the-party rolls are ignored, with their window line.
- [ ] G4 Trust and money:
      - a client that saw a different roll, or missed one, marks the game disputed and moves nothing;
      - only a player's own client changes that player's balance;
      - the top-up lifts 400 to 1,000, leaves 1,500 alone, and does nothing when the reset can't be read;
      - the `CHAT_MSG_SYSTEM` listener exists only while a game you're in is open.
- [ ] G5 Every Task 8 guard was removed once, turned a named check red, and was restored. `/dt selftest` in the
      harness reads all passed.

## In game [G]
- [ ] G6 Alone: `/dt gamble` shows `No games in your party. Start one.` `/dt debug ghost on`,
      `/dt debug ghost chips`, `/dt gamble board`: the Restless Ghost is listed. `/dt debug ghost off`.
- [ ] G7 With a guildie in your party: `/dt gamble deathroll <their name> 100`. Both of you press **Roll** in turn
      until someone rolls 1. Both windows show the same rolls and the same result, and the loser's balance on
      `/dt gamble board` is 100 lower, the winner's 100 higher.
- [ ] G8 `/dt gamble highlow 50`; the guildie joins; press **Final call**; both roll. The difference moves from
      lowest to highest, the same in both windows.
- [ ] G9 Start a high-low, then type `/roll 30` instead of pressing Roll: the window shows
      `<name> rolled the wrong range.` and the game waits for a proper roll.
- [ ] G10 `/dt gamble board off`, then `/dt gamble board` on the guildie's screen: you're gone. Then
      `/dt gamble board on`.

## In game [H]
- [ ] H1 Did the table feel like a game you'd play again, not a form to fill in? Screenshot a game in progress.
- [ ] H2 Was anything unclear about whose turn it was, or why a roll didn't count?
- [ ] H3 After one evening of real play: did anyone want to post results to chat, or ask for gold stakes? (That
      decides the Announce button and the donation round.)
