# Walk-sheet: DEAD TIRED Port 2 (0.3.0)

For `docs/COWORK_BRIEF_dt_port2.md`. **[G]** = the session proves it offline; **[H]** = Tim in game
with `dist/DeadTired-0.3.0.zip` over 0.2.0. Screenshot every [H] (addon lines don't reach the chat
log). Back up `SavedVariables\DeadTired.lua` first. Wizardry can stay on (its taint fix is in, 0.39.0).

## Offline [G]
- [ ] G1 Baseline counts; final `run_all.sh` green; zip `diff -r` clean.
- [ ] G2 Port 1 fixes: nudge re-arm; bar labels are names; date on one line; Escape registration.
- [ ] G3 Taint scan: only `table.insert(UISpecialFrames, <DT frame>)`; anything else on it goes red;
      no hook on any Blizzard function.
- [ ] G4 Gank, Played, Stash, Events, Logs: rc3 checks carried and green on full-name keys.
- [ ] G5 Played: shared only after `/dt played`; a plain `TIME_PLAYED_MSG` ignored.
- [ ] G6 Migration for cards 4 and 6: once; `legacy` untouched.
- [ ] G7 Every guard in Task 5 removed once → a named check red → restored.

## In game [H]
- [ ] H1 Log in: welcome; BugSack quiet; `/run print("risen")` prints (Wizardry on).
- [ ] H2 Escape closes Who, settings and the graveyard; the Wizardry marks bar stays.
- [ ] H3 Bar list shows addon names (BugSack, Recruit), not their live text; a hand cursor while
      dragging (if built).
- [ ] H4 `/dt recruit`, then `/dt recruit nudge off` and `on`: the nudge still comes once 15 min after
      the post.
- [ ] H5 Graveyard dates on one line; full date in the tooltip.
- [ ] H6 Gank: target an Alliance player, `/dt gank`; the board shows them; a guildie on 0.3.0 sees it.
- [ ] H7 Played: `/dt slowest share on`, then `/dt played`: played lines print; the slowest board shows
      you. A plain `/played` changes nothing.
- [ ] H8 Stash: `/dt stash share on`; a guildie asks `/dt stash <an unbound item you carry>`: you're
      named. A bound item never shows.
- [ ] H9 Events: `/dt events` lists upcoming; `/dt events remind on` (note when a reminder is due).
- [ ] H10 Logs: enter a dungeon with the combat log off: one prompt; clicking switches it on.
- [ ] **Carried from Port 1:** P1-H2 `/dt who` with a guildie (you first `(you)`, names without
      realm); P1-H5 settings: no overlap or cut-off, first setting readable; P1-H6 the bedtime nag
      fires (set `/dt bedtime` a few minutes ahead and wait).
