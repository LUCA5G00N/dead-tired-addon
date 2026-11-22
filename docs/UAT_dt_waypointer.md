# Walk-sheet: the Waypointer (0.5.0)

Brief: `docs/COWORK_BRIEF_dt_waypointer.md`.
- **[G]** offline: the build session proves it in its report.
- **[G]** in game: Tim types, and what's on screen decides.
- **[H]**: Tim's judgement.

**5 [G] offline, 4 [G] in game, 2 [H].** Back up first, into `_dt_backups\<date>_before_0.5.0`. Walk outdoors,
not in a dungeon.

## Offline [G]
- [ ] G1 `run_all.sh` is ALL GREEN, with counts. The zip is `diff -r` clean. `.toc` and `DT.VERSION` read 0.5.0.
- [ ] G2 Setting a waypoint:
      - coordinates are parsed and range-checked;
      - zone names match (unique, prefix), and ambiguous or unknown names are refused with a line;
      - the pin is set and tracked only where `CanSetUserWaypointOnMap` allows, and cleared only while it's DT's.
- [ ] G3 The arrow:
      - four worked examples are right to 1 degree and 1 yard;
      - another continent is said;
      - a secret read hides the needle without an error;
      - no `OnUpdate` work while hidden;
      - arrival clears at 5 yards, not 6.
- [ ] G4 The waypoint is kept over a `/reload` and replaced by a new one. The list has 39 books, search works, a
      click sets one, and the empty-state and closing lines are present. The text fits under every skin.
- [ ] G5 Every Task 7 guard was removed once, turned a named check red, and was restored. `/dt selftest` in the
      harness reads 10 passed.

## In game [G]
- [ ] G6 `/dt way 50 50`: Blizzard's pin appears on the map (OpenMap's too) and the arrow appears. Turn on the
      spot: the arrow turns with you and keeps pointing the same way on the ground. The yards go down as you ride
      toward it.
- [ ] G7 `/dt way list`, search `potatoes`, click "Undead Potatoes": the pin moves to Western Plaguelands, and
      the arrow says `another continent` (or the distance, if you're in the Eastern Kingdoms).
- [ ] G8 `/dt way clear`: the arrow is gone, and so is the pin. `/reload` with a waypoint set: it's still there
      afterwards.
- [ ] G9 `/dt selftest`: 10 passed.

## In game [H]
- [ ] H1 Does the arrow read at a glance while riding (size, place, the yards line)? Take a screenshot.
- [ ] H2 Did you follow the arrow to a real spot (a book you need) and find it where the arrow said?
