# UAT walk-sheet: dt_prep

Brief: `docs/COWORK_BRIEF_dt_prep.md`. Extracted from its acceptance section.
**Checks: 13 *(amended; was 12)*. `[H]` count: 1** (how the public posts land on strangers).
Results go to `docs/UAT_dt_prep_results.md`, written by Tim after walking.
**Amended 2026-11-02 (rulings round, A1):** G10 and G11 rewritten, G12 added; see
`docs/COWORK_BRIEF_dt_rulings.md`.

**Offline (the build session runs these):**
- [ ] `[G]` G1: `DeadTired/tests/run_all.sh` exits 0 and runs eight suites (core, guild, comms,
  roster, alts, welcome, prep, recruit).
- [ ] `[G]` G2: the report lists all twelve Task 10 guard removals, each with the check that went
  red.
- [ ] `[G]` G3: `grep -rn "SendChatMessage" DeadTired/ --include=*.lua | grep -v "/tests/"` finds
  exactly one line, in `Recruit.lua`; and
  `grep -rE "COMBAT_LOG|CombatLog|C_DeathRecap|UNIT_DIED|PARTY_KILL|C_Container|READY_CHECK" DeadTired/`
  finds nothing.
- [ ] `[G]` G4: `git diff card/dt_foundation --stat -- DeadTired/` lists only the four new files,
  the two new suites, `DeadTired.toc` (4 lines added) and `tests/run_all.sh` (1 line changed).
- [ ] `[G]` G5: the five lines in `RecruitLines.lua` are byte-identical to `docs/RECRUIT_lines.md`
  (Task 2's test), and the report gives each line's length in bytes.

**In game (Tim, with one or two guildies, all on this branch):**
- [ ] `[G]` G6: `/reload` shows no Lua error, and the only line printed is card 1's welcome.
- [ ] `[G]` G7: `/dt prep list` on a priest, a mage and one other class: every line's client name
  matches its list name, or is marked `<- check this ID`. Write down every marked ID.
- [ ] `[G]` G8: with known bags, `/dt prep` says "Ready." or names exactly the short items with
  the right counts.
- [ ] `[G]` G9: guildie A runs `/dt prep share on`, guildie B leaves it off. Tim's
  `/dt prep check`: after 10 s, A is listed (ready or short) and B is not anywhere.
- [ ] `[G]` G10 *(amended)*: Tim, an officer, in a city with General joined, presses `/dt recruit`: line 1
  appears in General, once. A second press inside 15 minutes is refused.
- [ ] `[G]` G11 *(amended)*: Tim leaves General and presses: refused, nothing posted.
- [ ] `[G]` G12 *(amended: new)*: a guildie who is not an officer presses `/dt recruit`: refused, nothing
  posted.
- [ ] `[H]` H1: **reading the posts in the channel as a stranger would: do they read as a guild
  you'd want to join, or as an addon spamming?**

**`[H]` count: 1.** How public text lands on strangers is the only judgement here; everything
else is a count or a match. If H1 is "spam", the fix is the lines or the cooldown, both Tim's.
