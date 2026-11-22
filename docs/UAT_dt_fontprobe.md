# Walk-sheet: the font probe (0.3.7)

Brief: `docs/COWORK_BRIEF_dt_fontprobe.md`. **[G]** offline = the build session proves it in its report;
**[G] in game** = Tim types, and the saved file or the printed lines decide; **[H]** = Tim's judgement.
**3 [G] offline, 2 [G] in game, 1 [H].** Back up first, into `_dt_backups\2026-11-22_before_0.3.7`, and
install from the branch.

## Offline [G]
- [ ] G1 `run_all.sh` ALL GREEN with counts; zip `diff -r` clean; `.toc`/`DT.VERSION` 0.3.7.
- [ ] G2 Every `SetFont` in `DeadTired/` goes through `DT.fontCall`: the static check is green on the tree
      and red on its fixture.
- [ ] G3 Recorder: every field; `off` stops; capped at 300; never saved on. Matrix: 8 strings × 2 paths.
      Every Task 6 guard removed → a named check red → restored.

## In game [G] (after a full restart of WoW, skin **clean** to start: `/dt set core skin clean`)
- [ ] G4 `/dt debug fontprobe matrix`. Screenshot the eight lines.
- [ ] G5 The recording, in this order:
      1. `/dt debug fontprobe on`
      2. `/dt graveyard` (leave it open)
      3. `/dt set core skin deadtired`; wait 3 s
      4. `/dt debug fit`
      5. `/dt debug fontprobe`, and screenshot the summary
      6. `/dt debug fontprobe off`
      7. `/reload`

      Then attach `SavedVariables\DeadTired.lua` to the chat, or paste the `fontprobe` section.

## In game [H]
- [ ] H1 At step 3, did the open graveyard's title turn gothic? Screenshot it before step 4.
