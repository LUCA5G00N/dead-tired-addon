# Walk-sheet: dt_nudge (the version nudge)

On one character, in the guild, on the new build. `/dt debug on` first.

| # | Check | |
|---|---|---|
| N-G1 | `/dt ghost say hello 9.9.9 2`, wait 10 s: one line, "A newer Dead Tired (9.9.9) walks among us. Yours is <yours>. It's in #dt-crypt-workshop." | [G] |
| N-G2 | `/reload`, then `/dt ghost say hello 9.9.9 2` again: nothing prints. | [G] |
| N-G3 | `/dt ghost say hello 10.0.0 2`: one more line, for 10.0.0. | [G] |
| N-G4 | `/dt who nudge off`, relog, `/dt ghost say hello 11.0.0 2`: nothing prints. `/dt who` shows `(update)` on your row. | [G] |
| N-G5 | `/dt who nudge on`, relog, `/dt ghost say hello 12.0.0` (one key): nothing prints. | [G] |
| N-H1 | Would the line make you update, or would you tune it out? | [H] |
