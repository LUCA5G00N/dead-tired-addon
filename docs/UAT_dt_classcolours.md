# Walk-sheet: class-coloured names in death notices (0.3.3)

Brief: `docs/COWORK_BRIEF_dt_classcolours.md`. **[G]** = the build session proves it, with
evidence in its report; **[H]** = Tim in game with `dist/DeadTired-0.3.3.zip` over 0.3.2.
**5 [G], 3 [H].** Screenshot every [H]. Back up `SavedVariables\DeadTired.lua` first. Tick in the
results log, never in this file.

## Offline [G]
- [ ] G1 Baseline and final `run_all.sh` `ALL GREEN` with counts; `dist/DeadTired-0.3.3.zip`
      `diff -r` clean; `.toc` and `DT.VERSION` read `0.3.3`.
- [ ] G2 Both notice lines wrap a placed guildie's name in their class's `|c…|r` code (the probe's
      five classes); everything else on the line is byte-for-byte 0.3.2's.
- [ ] G3 Plain fallback: not on the roster, no token, unknown token, bad `colorStr`, r/g/b out of
      range, a different `-Realm`: the name is exactly 0.3.2's, and nothing is counted or printed.
- [ ] G4 Graveyard: placed rows' name cells take the class colour, others the column's own; a reused
      row frame is reset; the colour holds after a skin change; one roster walk per build.
- [ ] G5 `/dt debug rip <name>` prints two lines and records and sends nothing; a stranger gets
      `not on the roster.`; every Task 7 guard removed once → a named check red → restored.

## In game [H]
- [ ] H1 `/dt debug rip Echo Wagyu`, then `/dt debug rip Stromham Hamson`: both lines each time, the
      name in its class colour (shaman, paladin), the rest of the line as before.
- [ ] H2 `/dt graveyard`: every name you can see is in its class colour, including Echo Nightclaw and
      Stromham Hamson; anyone no longer in the guild is plain. Scroll and search once: colours stay
      with their names.
- [ ] H3 Your judgement: readable on the window's dark rows, every class? Shamans blue: keep the
      game's colours, or do you want classic pink after all? Anything else you had to squint at?
