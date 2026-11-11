# Walk-sheet: DEAD TIRED Port 1 (0.2.0)

For `docs/COWORK_BRIEF_dt_port1.md`. **[G]** = the session proves it offline; **[H]** = Tim in game
with `dist/DeadTired-0.2.0.zip` (installed over fw1). Screenshot every [H]; addon lines don't reach
the chat log. Never tick this file. **Before:** back up `SavedVariables\DeadTired.lua`.

## Offline [G]
- [ ] G1 Baseline counts; final `run_all.sh` green; zip `diff -r` clean.
- [ ] G2 Settings rows fit their text; first setting clear of search; colour codes pass through.
- [ ] G3 Names: full name only; realm on collision; Who lists you first `(you)`, never doubled;
      empty-state line.
- [ ] G4 Bar list: others unticked by default; tick, drag order, typed verbs, new at bottom, saved.
- [ ] G5 Alts, Crypt, Recruit, Prep: rc3 checks carried and green on full-name keys.
- [ ] G6 Recruit: button posts only on click, officers only, cooldown and General kept; nudge replies.
- [ ] G7 Prep: R-P3 (officers set, shared, members check, verdict-only roll call) or the fallback.
- [ ] G8 Migration on Tim's legacy shape: merges, unmatched count, once, `legacy` untouched.
- [ ] G9 Every guard in Task 7 removed once → a named check red → restored.

## In game [H]
- [ ] H1 Log in on Stromham (fw1's data present): welcome; BugSack quiet; `/dt alts` shows the main
      once and each alt once (St Ham, Gizzardthe, Jobbi, Marvella), no short/full doubles.
- [ ] H2 `/dt who` with a guildie: you first `(you)`; others by full name only, realm in the tooltip;
      long names don't overlap.
- [ ] H3 The `Recruit` button (as an officer, in a city): shows the cooldown; a click posts the next
      line to General; a second click inside 15 min doesn't post; the nudge comes once 15 min later.
      `/dt recruit nudge off` / `on` print their two lines.
- [ ] H4 Bar list: in settings, other addons are unticked; tick two, drag one above the other;
      `/reload`: order kept. `Session` can be ticked on.
- [ ] H5 Settings: no overlapping or cut-off text; the first setting is readable.
- [ ] H6 Crypt: `/dt rip` shows the graveyard (searchable); `/dt bedtime 23:59` then `off` replies;
      with a guildie on 0.2.0 and `/dt rip share on`, dying prints one notice on their side.
- [ ] H7 Prep: as an officer `/dt prep add` an item; a guildie on 0.2.0 sees the list and
      `/dt prep check` checks their bags (or, if the fallback shipped, `check` against the built-in list).
- [ ] H8 Taint stays gone: `/run print("risen")` with DT loaded (Wizardry off if its fix isn't in).
