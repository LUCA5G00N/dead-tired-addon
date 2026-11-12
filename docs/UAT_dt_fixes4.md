# Walk-sheet: DEAD TIRED fix round 4 (0.3.1)

For `docs/COWORK_BRIEF_dt_fixes4.md`. **[G]** = the session proves it offline and shows the
evidence in its report; **[H]** = Tim in game with `dist/DeadTired-0.3.1.zip` over 0.3.0.
**11 [G], 9 [H].** Screenshot every [H] (addon lines don't reach the chat log). Back up
`SavedVariables\DeadTired.lua` first. Tick in the results log, never in this file.

## Offline [G]
- [ ] G1 Baseline `ALL GREEN` with counts; final `run_all.sh` `ALL GREEN`; `dist/DeadTired-0.3.1.zip`
      `diff -r` clean; `.toc` and `DT.VERSION` read `0.3.1`.
- [ ] G2 `DT.fitLine`: text that fits is returned unchanged; text that doesn't comes back no wider
      than the box and ending `…`; a two-byte character is never split.
- [ ] G3 Lists: a fixed column is as wide as its widest value (`12 Nov` and `9 Nov` in one model:
      both on one line); exactly one flex column, else `DT.list` raises; every row the same height.
- [ ] G4 A cut row's tooltip carries the full text of each cut cell; an uncut row adds nothing.
- [ ] G5 Footers: `DT.viewport{ footer = "<text>" }` insets the body by the text's measured
      height; the slowest board's footer wraps inside the window's width in the harness.
- [ ] G6 `test_textfit.lua`: green on the tree; red on its fixture with a raw `CreateFontString`;
      red on a numeric `footer`; `grep -n CreateFontString DeadTired/*.lua` shows `UI.lua` only.
- [ ] G7 `/dt debug fit` in the harness: 0 over on each of the three skins; a planted over-wide
      label is reported; the saved skin is the same before and after.
- [ ] G8 Tooltips: no realm line in the slowest board's or the graveyard's; the graveyard's date
      line still there.
- [ ] G9 Nudge: re-armed by `PLAYER_ENTERING_WORLD` with a reload flag while the cooldown runs;
      not on a first login; not once the cooldown has ended; still once per post.
- [ ] G10 Switches: for each of gank, played, stash, events, logs: default on; off registers no
      events, ignores inbound, sends nothing, and its verbs print `<id>.enabled = off` and nothing
      else; on again restores it. `/dt played` with sharing off prints the hint and sends nothing.
- [ ] G11 Skin: `clean` is the default; the move runs once (`migrated.skin031`), takes `deadtired`
      and none to `clean`, leaves `forever`; every Task 10 guard removed once → a named check red →
      restored.

## In game [H]
- [ ] H1 Install 0.3.1 over 0.3.0 and log in: the welcome line; BugSack quiet; the windows now use
      the plain lettering without you choosing it. `/dt skin deadtired` brings the gothic titles
      back, and they are still there after a `/reload`.
- [ ] H2 Graveyard and Grudges: every date on one line, every row the same height. A long zone
      (`Excavation Site: Wetlands`) ends in `…` and the tooltip shows it in full.
- [ ] H3 Glacial Progress: the footer stays inside the window; `h played` on one line; the tooltip
      is the name only. Graveyard tooltip: name and date, no `CAMWOWEU4Realm2PvP`.
- [ ] H4 Enter a dungeon with the combat log off: the prompt's words sit inside its box; one
      click still switches the log on.
- [ ] H5 `/dt debug fit` after opening Who, settings, the graveyard, Grudges, Glacial Progress,
      Who has it and Events: the last line reads `0 over` and `measure failures 0`. Screenshot the
      output whatever it says.
- [ ] H6 `/dt recruit` (as an officer, in a city), then `/reload` within the 15 minutes: the nudge
      still comes, once, 15 minutes after the post.
- [ ] H7 `/dt slowest share off`, then `/dt played`: `Sharing's off. /dt slowest share on`.
- [ ] H8 Settings: Gank diary, Glacial Progress, Stash, Events and Logs each have an
      `On` card, all on. Switch Gank off: `/dt gank` answers `gank.enabled = off` and logs nothing.
      Switch it on again: `/dt ganks` opens the board with your grudges intact. Settings still
      show no overlap or cut-off (P1-H5 again, after the text change).
- [ ] H9 Your judgement: is the plain lettering easier to read than the gothic, and would you
      keep it as everyone's default? Anything on any window you had to squint at?

Notes for the walk: H2 needs a death or a grudge with a long zone name on the board; if none is
there, say so and it stays open. H4 needs a dungeon. H6 needs 15 minutes. H7 takes you off guildies' slowest boards: afterwards
`/dt slowest share on` and `/dt played` put you back. Escape first cancels a
cast, then closes windows.
