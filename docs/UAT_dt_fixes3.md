# Walk-sheet: DEAD TIRED fix round 3 (rc3)

For `docs/COWORK_BRIEF_dt_fixes3.md`. **[G]** = the session proves it offline and shows the
evidence in its report; **[H]** = Tim, in game, with `dist/DeadTired-0.1.0-rc3.zip` installed.
Tick in your own copy or the results log; never in this file.

## Offline [G]
- [ ] G1 Baseline: every suite green; `test_realm_spelling.lua` red 2 of 2 (before).
- [ ] G2 R-1: flag true + no lockdown → sent; lockdown → held, retried, sent after; lockdown
      function absent → sent; flag recorded at login, never gates the pump.
- [ ] G3 Held line prints once per hold, again for a new hold, never otherwise.
- [ ] G4 AUD-10: 0/true/nil = sent; other codes and errors = refused, requeued at the front,
      retried; 3 refusals → dropped and counted; the queue moves on.
- [ ] G5 AUD-06: one key form everywhere; sender and local spellings agree; display hides the own
      realm; migration rewrites, merges by newest, runs once; each card store migrated.
- [ ] G6 Nudge: one line 900 s after a post; none after a later post, when not an officer, when
      switched off, or without a post this session; never sends chat.
- [ ] G7 Probe `registered`: 0 and 1 and true → true; others → false.
- [ ] G8 Every guard in Task 8 removed once → a named check red → restored.
- [ ] G9 `test_realm_spelling.lua` green 2 of 2 (after).
- [ ] G10 rc3 zips built; `diff -r` against the branches clean; rc2 zip gone from the rc3 branch.

## In game [H] (Tim; a guildie with rc3 for H3-H5)
- [ ] H1 Install rc3 over rc2. Log in: the welcome line as before; BugSack quiet.
- [ ] H2 `/dt recruit` once (as an officer, in a city): posts; 15 min later exactly one line
      "The crypt door creaks open: you can recruit again (/dt recruit)." Nothing else posted.
- [ ] H3 With a guildie running rc3: `/dt who` lists them within a minute of both logging in
      (proves R-1: messages now go out).
- [ ] H4 `/dt alts` shows your main and alts once each, no realm doubled (AUD-06 on our spaced
      realm).
- [ ] H5 Optional, in a dungeon boss fight: a shared command prints "The dead are gagged for this
      fight. Your message goes when it's over." once; after the fight, the guildie gets it.
- [ ] H6 `/dt recruit nudge off`, post again: no nudge after 15 min. `/dt recruit nudge on`
      restores it.
- [ ] H7 Enter a dungeon with the combat log off: one logs prompt only (WizardryLogPrompt is
      retired).
