# UAT walk-sheet: dt_foundation

Brief: `docs/COWORK_BRIEF_dt_foundation.md`. Extracted from its acceptance section.
**Checks: 11. `[H]` count: 1** (tone is Tim's call). *(amended, fix round 1: G6b added)*
Results go to `docs/UAT_dt_foundation_results.md`, written by Tim after walking.

**Offline (the build session runs these):**
- [ ] `[G]` G1: `DeadTired/tests/run_all.sh` exits 0, and runs one suite per module (core, guild,
  comms, roster, alts, welcome).
- [ ] `[G]` G2: the report lists all seven Task 8 guard removals, each with the check that went
  red.
- [ ] `[G]` G3: `grep -rE "COMBAT_LOG|CombatLog|SendChatMessage" DeadTired/` finds nothing.
- [ ] `[G]` G4: `grep -r "reference/" DeadTired/*.toc DeadTired/*.lua` finds nothing.

**In game (Tim, with one guildie, both on 0.1.0):**
- [ ] `[G]` G5: `/reload` shows no Lua error, and exactly one welcome line.
- [ ] `[G]` G6: within 30 seconds of both being online, `/dt who` on each lists the other under
  "this session", and ends with "Only guildies running the addon show up here."
- [ ] `[G]` G6b *(added, fix round 1, `docs/UAT_dt_fixes1.md` G7)*: with Tim and the guildie both
  online and listing each other, Tim `/reload`s: within 20 seconds `/dt who` on Tim lists the
  guildie again. Then Tim logs out and back in: the same.
- [ ] `[G]` G7: Tim runs `/dt main` on Stromham, then logs an alt. The guildie's
  `/dt alts <alt name>` prints Stromham as main and the alt in the group.
- [ ] `[G]` G8: a character not in the guild logs in with the addon enabled: no welcome, and the
  guildie's `/dt who` does not list that character.
- [ ] `[G]` G9: `/dt welcome off`, `/reload`: no welcome line. `/dt welcome on` restores it.
- [ ] `[H]` H1: **does it feel like *our* addon (the tone, the welcome line, `/dt`), or like a
  generic tool with our name on it?**
