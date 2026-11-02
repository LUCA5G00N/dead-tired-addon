# UAT walk-sheet: dt_rulings (amendments to cards 3, 5 and 6)

Brief: `docs/COWORK_BRIEF_dt_rulings.md`. **Checks: 6 offline, plus in-game changes to three card
sheets. `[H]` count: 0** (each card's own H1 still stands).

**Offline (the build session runs these):**
- [ ] `[G]` R1: on each of `card/dt_crypt`, `card/dt_prep`, `card/dt_stretch`,
  `DeadTired/tests/run_all.sh` exits 0.
- [ ] `[G]` R2: the round report lists all seven Task 6 guard removals, each with the check that
  went red.
- [ ] `[G]` R3: on each branch, `git diff card/dt_foundation --stat -- DeadTired/` names no card 1
  file beyond the `.toc` and `run_all.sh` lines that card already had.
- [ ] `[G]` R4: on `card/dt_prep`, `grep -rn "SendChatMessage" DeadTired/ --include=*.lua | grep -v "/tests/"`
  finds exactly one line, in `Recruit.lua`.
- [ ] `[G]` R5: on `card/dt_stretch`, `grep -rn "RequestTimePlayed" DeadTired/ --include=*.lua | grep -v "/tests/"`
  finds nothing.
- [ ] `[G]` R6: each amended card's brief has an *Amended 2026-11-02 (rulings round)* note.

**In game: these replace or join checks on each card's own sheet.**

*Card 3 (`docs/UAT_dt_crypt.md`):*
- G6 (replaced): `/reload` on a normal character shows no Lua error, and the only line is card 1's
  welcome.
- G11 (replaced), *only if Forever has a hardcore realm:* a new hardcore character in the guild
  logs in: one line pointing at `/dt rip share on`. `/reload`: the line does not come back. It
  dies with `share` unset: the guildie sees nothing. After `/dt rip share on`, its next death
  shows the guildie the "Rest in Pieces … Hardcore. Gone for good." line. No hardcore realm:
  write "not walkable".

*Card 5 (`docs/UAT_dt_prep.md`):*
- G10 (replaced): Tim, an officer, in a city with General joined, presses `/dt recruit`: line 1
  appears in General, once. A second press inside 15 minutes is refused.
- G11 (replaced): Tim leaves General and presses: refused, nothing posted.
- G12 (new): a guildie who is not an officer presses `/dt recruit`: refused, nothing posted.

*Card 6 (`docs/UAT_dt_stretch.md`):*
- New: with `/dt slowest share on`, Tim types `/played`: the guildie's board gets Tim's line.
  Then `/script RequestTimePlayed()`: nothing new is sent (the guildie's board is unchanged).
- New: with stash sharing on and a soulbound item in Tim's bags, the guildie searches for it:
  no answer names it.
