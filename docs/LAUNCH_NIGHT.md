# Launch night running order (Wed 2026-11-04, from 11pm UK)

All zips are in `dist/` on `release/0.1.0-rc3`. Unzip into `_forever_\Interface\AddOns`; tick
**Load out of date AddOns** if asked. Only one `DeadTired` folder at a time: delete the old one
before unzipping the next. The offline checks (G1-G4/G5 on each sheet) were run by the build
sessions; tonight is the in-game ones.

| Step | Install | Walk-sheet | Sheet's checks (the ones for tonight) |
|---|---|---|---|
| 1. Probe | `dist/DeadTiredProbe-0.1.0.zip` (you and the guildie) | `docs/UAT_dt_probe.md` | 6 (G6, the 10-step run; G1-G5 are offline) |
| 2. Card 1 alone | `dist/DeadTired-0.1.0-card1.zip` | `docs/UAT_dt_foundation.md` | 11 (G5-G9 with **G6b**, H1) |
| 3. Cards 3-7 | swap to `dist/DeadTired-0.1.0-rc3.zip` | `docs/UAT_dt_crypt.md` | 12 (G6-G11, H1) |
| | | `docs/UAT_dt_pvp.md` | 12 (G6-G11, H1) |
| | | `docs/UAT_dt_prep.md` | 13 (G6-G12, H1) |
| | | `docs/UAT_dt_stretch.md` | 13 (G6-G12, H1) |
| | | `docs/UAT_dt_logs.md` | 11 (G5-G9 with **G9b**, H1) |
| 4. Hand over | nothing | | |

1. **Probe** (~15 min). Run steps 1-10 of its G6. *No guild yet?* Its no-guild route: step 3 in a
   party, and repeat steps 1, 3, 7 and 9 once the guild exists. Log out to write the saved file.
   Delete `DeadTiredProbe` afterwards.
2. **Card 1 alone**, from the `-card1` zip. Includes **G6b** (fix round 1): both online and
   listing each other, you `/reload`, then relog: `/dt who` lists the guildie again within 20 s.
   **If card 1 fails, stop here** (ROADMAP rule 3): nothing else is walked tonight.
3. **Swap to the `-rc3` zip** and walk the five sheets in order: crypt, pvp, prep, stretch, logs.
   A card that fails is noted; the others still count. Note: on the combined build,
   `SendChatMessage` greps find card 5's one ruled call site (`Recruit.lua`); that is expected.
   WizardryLogPrompt is retired (9 Nov): card 7's prompt is now the only logs prompt.
4. **Hand over** `_forever_\WTF\Account\<ACCOUNT>\SavedVariables\DeadTiredProbe.lua` (and the
   guildie's) to a session for `docs/PROBE_launch_results.md`, and note which cards passed, so
   each can be merged to `main` on its own.

## Batch by what each check needs

- **The guild must exist** for everything in steps 2 and 3 (the addon does nothing outside the
  guild) except card 1's G8, which needs a character **outside** the guild. *If the guild isn't
  formed yet, do steps 1 and the solo parts only.*
- **Solo, in a city:** card 1 G5, G9, H1; crypt G6, G10 (bedtime two minutes ahead); pvp G6, G7;
  prep G6, G7 (a priest, a mage and one other class), G8; stretch G6, G9; logs G5.
- **A guildie online** (running the same zip): card 1 G6, G6b, G7, G8; crypt G7-G9 (you die three
  times, 60 s apart); pvp G9, G10; stretch G8 and G11 (you type `/played`).
- **Two guildies online** (one sharing, one not): prep G9; stretch G7 (guildie A opens their bank
  once) and G12 (a soulbound item in your bags).
- **Officer rank, General joined, in a city:** prep G10, G11. **A non-officer guildie:** prep G12.
- **An Alliance player to target:** pvp G8, and G11 in combat. Probe step 8 (optional) at the same
  time.
- **A dungeon entrance:** logs G6, G7, G9 and G9b (fix round 2: log in at the entrance with
  `/dt logs login on`, leave the login prompt, walk in: one prompt); probe step 8b. **A battleground:** logs G8's last part.
- **Edit a file:** stretch G10 needs an event 35 minutes away (`EventsList.lua` in the AddOns copy).
- **Only if Forever has a hardcore realm:** crypt G11. Otherwise write "no hardcore realm".
- **After a raid night or a week** (not tonight): the `[H]` questions on crypt, pvp and logs.
