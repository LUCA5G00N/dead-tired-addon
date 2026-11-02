# UAT walk-sheet: dt_professions

Brief: `docs/COWORK_BRIEF_dt_professions.md`. Extracted from its acceptance section.
**Checks: 11. `[H]` count: 1** (whether people ask `/dt craft` instead of guild chat).
Results go to `docs/UAT_dt_professions_results.md`, written by Tim after walking.

**Before this sheet: the launch-night probe** in the brief (*Launch-night probe*), written to
`docs/PROBE_guild_recipes_results.md`. The card can't be ratified, built or walked without it.

**Offline (the build session runs these):**
- [ ] `[G]` G1: `DeadTired/tests/run_all.sh` exits 0 and runs eight suites (core, guild, comms,
  roster, alts, welcome, professions, crafts).
- [ ] `[G]` G2: the report lists all sixteen Task 10 guard removals, each with the check that
  went red.
- [ ] `[G]` G3:
  `grep -rnE "QueryGuildMembersForRecipe|QueryGuildMemberRecipes|GUILD_RECIPE|GetGuildRosterInfo|SendChatMessage|COMBAT_LOG|CombatLog|C_DeathRecap" DeadTired/ --include=*.lua | grep -v "/tests/"`
  finds nothing.
- [ ] `[G]` G4: `git diff card/dt_foundation --stat -- DeadTired/` lists only the two new files,
  the two new suites, `DeadTired.toc` (2 lines added) and `tests/run_all.sh` (1 line changed).
- [ ] `[G]` G5: the report gives the byte length of the longest CRAFT, PROF, CRAFTQ and PROFQ,
  each at most 250, and quotes P3's last line.

**In game (Tim, with one or two guildies, all on this branch):**
- [ ] `[G]` G6: `/reload` shows no Lua error, and the only line printed is card 1's welcome.
  Opening a profession window prints nothing.
- [ ] `[G]` G7: guildie A runs `/dt craft share on` and opens their Tailoring window, then their
  First Aid window, in quick succession. A's `/dt crafts` shows both professions with recipe
  counts that match what each window lists as learned. No Tailoring recipe counts under First
  Aid, or the other way round.
- [ ] `[G]` G8: guildie B leaves sharing off. Tim's `/dt craft linen`: after 10 s, A is listed with
  Linen recipes **by name**, and B isn't anywhere. A recipe A hasn't learned never appears.
- [ ] `[G]` G9: Tim's `/dt profs tailoring` lists A with A's real rank (as A's skill window shows
  it). `/dt profs tail` lists nobody.
- [ ] `[G]` G10: A runs `/dt craft share off`. Tim's next `/dt craft linen` (after 30 s): A isn't
  listed. A's `/dt crafts` says "Sharing off. Nothing offered."
- [ ] `[H]` H1: **the next time someone needed a crafter, did they ask `/dt craft`, or guild chat?**

**`[H]` count: 1.** Whether the directory replaces "anyone got tailoring?" in guild chat is the
only question that says it was worth building, and no machine can answer it. If H1 is "guild
chat", the directory's value rests on the native layer reaching people who don't run the addon,
and that is the case for `dt_professions_native` (if P3 allows it).
