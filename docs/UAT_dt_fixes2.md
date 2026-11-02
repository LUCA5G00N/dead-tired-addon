# UAT walk-sheet: dt_fixes2

Brief: `docs/COWORK_BRIEF_dt_fixes2.md`. **Checks: 5. `[H]` count: 0.**

- [ ] `[G]` G1: `card/dt_logs` and `release/0.1.0-rc2` `run_all.sh` exit 0.
- [ ] `[G]` G2: the report lists the three guard removals, each with its red check.
- [ ] `[G]` G3: `dist/` on `release/0.1.0-rc2` holds `DeadTired-0.1.0-rc2.zip`,
  `DeadTired-0.1.0-card1.zip` and `DeadTiredProbe-0.1.0.zip`, and no rc1 zip; each unzips equal to
  its source minus `tests/`.
- [ ] `[G]` G4: `grep -rn "rc1" docs/LAUNCH_NIGHT.md docs/GUIDE_guildies.md docs/ANNOUNCE_discord.md`
  on the rc2 branch finds nothing.
- [ ] `[G]` G5 (in game, added to card 7's walk): with `/dt logs login on` and the combat log off,
  log in at a dungeon entrance, leave the login prompt unanswered and walk in: still only one
  prompt on screen.
