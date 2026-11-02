# UAT walk-sheet: dt_probe (launch-night probe)

Brief: `docs/COWORK_BRIEF_dt_probe.md`. **Checks: 5 offline, 1 in-game run (6 boxes). `[H]` count: 0.**
The probe is a tool; its results go to `docs/PROBE_launch_results.md`, written from the saved
file by a session working with Tim, and checked by Tim.

**Offline (the build session runs these):**
- [ ] `[G]` G1: `lua5.1 DeadTiredProbe/tests/test_probe.lua` exits 0.
- [ ] `[G]` G2: the report lists every Task 6 guard removal with the check that went red.
- [ ] `[G]` G3: `grep -rnE "SendChatMessage|RequestTimePlayed|JoinChannel|LeaveChannel|COMBAT_LOG|CombatLog" DeadTiredProbe/ --include=*.lua | grep -v "/tests/"`
  finds nothing.
- [ ] `[G]` G4: `git diff main --stat` on `card/dt_probe` lists only files under
  `DeadTiredProbe/` and `docs/`.
- [ ] `[G]` G5: the report maps every section to the card question it answers.

**Launch night (Tim, about 15 minutes, before walking card 1):**

*No guild yet?* Run it anyway: everything except the guild, officer and recipe sections still
answers. Do step 3 with your guildie **in a party** instead. Run steps 1, 3, 7 and 9 again once
the guild exists; the second login is kept as its own run.

Set up: copy `DeadTiredProbe/` into `_forever_\Interface\AddOns`. Your guildie does the same.
On the character screen, tick **Load out of date AddOns** if the probe shows as out of date
(that itself is an answer: the interface number changed).

- [ ] `[G]` G6: run every step below; afterwards `/dtprobe report` shows no section as
  `not run yet` except the ones marked optional.
  1. Log in on Stromham, in Orgrimmar. Wait 30 seconds.
  2. `/dtprobe channels` (after joining General if you aren't in it).
  3. `/dtprobe ping`. Your guildie, also running the probe, does `/dtprobe ping` too.
  4. `/dtprobe items`, then `/dtprobe bags`. Open your bank: that's recorded by itself.
  5. Type `/played`. Then `/script RequestTimePlayed()`.
  6. `/dtprobe calendar`.
  7. Open a profession window, `/dtprobe recipes`. Close it, `/dtprobe recipes` again.
  8. *Optional, when the chance comes:* target an Alliance player, `/dtprobe target`; again
     while you're in combat with them. Die once (anywhere) for the death section.
  8b. `/dtprobe logging try` (with combat logging off: it tries to switch it on), then walk
     into any dungeon entrance and back out (the instance section records it).
  9. Your guildie (not an officer) also does steps 1 and 3, so the officer flag is seen both ways.
  10. `/dtprobe report`, then log out (this writes the saved file).

Then hand over the saved file:
`_forever_\WTF\Account\<ACCOUNT>\SavedVariables\DeadTiredProbe.lua` (yours, and your guildie's
if they'll send it). A session reads it and drafts `docs/PROBE_launch_results.md`; you check it.
Delete `DeadTiredProbe` from AddOns when done.
