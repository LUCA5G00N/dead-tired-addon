# Walk-sheet: DEAD TIRED fix round 5 (0.3.2)

For `docs/COWORK_BRIEF_dt_fixes5.md`. **[G]** = the session proves it offline and shows the
evidence in its report; **[H]** = Tim in game with `dist/DeadTired-0.3.2.zip` over 0.3.1.
**7 [G], 6 [H].** Screenshot every [H]. Back up `SavedVariables\DeadTired.lua` first. Tick in the
results log, never in this file.

**The round's falsifier is H1.** If it fails, the guessed cause of the skin defect is wrong and
the next round starts with an in-game probe.

## Offline [G]
- [ ] G1 Baseline `ALL GREEN` with counts; final `run_all.sh` `ALL GREEN`; `dist/DeadTired-0.3.2.zip`
      `diff -r` clean; `.toc` and `DT.VERSION` read `0.3.2`.
- [ ] G2 A list with `detail` draws two lines per row, every row one height, the last visible row
      inside the body; a list without it passes 0.3.1's list checks unchanged.
- [ ] G3 A detail line too long for the list is cut and its full text is in the row's tooltip.
- [ ] G4 `tipCovers`: a cut name is not added under a tooltip that already shows it; a cut cell not
      covered still is.
- [ ] G5 Events, Who has it and Glacial Progress declare `detail`; Glacial's reads
      `<rate> h/level, level <n>, <hours> h played`; the graveyard, Grudges and Who do not.
- [ ] G6 `/dt debug fit` in the harness: `0 over` on all three skins; the 0.3.1 fixture's
      `Stranglethorn Fishing Extravaganza` row is not cut.
- [ ] G7 Skin: every skin's fonts are set at load; a skin change repaints and schedules a second
      repaint; a `false` from `SetFont` is counted under `ui:font`; every Task 6 guard removed
      once → a named check red → restored.

## In game [H]
- [ ] H1 Log in on the plain skin without having used the gothic one this session. Open settings
      and the graveyard, then `/dt skin deadtired`: both windows' titles turn gothic at once,
      without closing them. `/dt skin clean`: both turn plain at once.
- [ ] H2 `/dt events`: each event is two lines, the name in full on the first and the day, time
      and countdown in full on the second.
- [ ] H3 `/dt slowest`: each entry is two lines, the name in full, then
      `h/level, level, h played` underneath. The tooltip shows the name once.
- [ ] H4 `/dt stash <an item a guildie shares>`: the holder on the first line, their items on
      the second. (Needs a guildie on 0.3.x sharing; if none is on, say so and it stays open.)
- [ ] H5 The graveyard, Grudges and `/dt who` look as they did in 0.3.1. `/dt debug fit` ends
      `0 over` and `measure failures 0`; screenshot the output whatever it says.
- [ ] H6 Your judgement: do the two-line rows read better than the cut ones, and would you keep
      them? Anything else you had to squint at?
