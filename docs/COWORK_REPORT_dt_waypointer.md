# Cowork report: the Waypointer (0.5.0)

Brief `docs/COWORK_BRIEF_dt_waypointer.md`; walk-sheet `docs/UAT_dt_waypointer.md`. Built 22 Nov 2026 in a cloud
session on **`claude/dt-waypointer`** from `main` at **`d82e283`** (the brief's merge, PR #36). W1–W7 ratified by
that merge (Tim, 20:37).

## Counts
| | Suites | Checks | Result |
|---|---|---|---|
| Baseline (`d82e283`, 0.4.0) | 29 + taint + textfit | 1,673 | ALL GREEN |
| This round | 31 + taint + textfit | 1,757 | ALL GREEN |

New and changed suites:
- `test_way` 75, new;
- `test_waybooks` 5, new (the data file's shape);
- `test_selftest` 60 → 62 (the new APIs in S4, the cap in S9).

The version lines in `test_core`, `test_who` and `test_selftest` move to 0.5.0, and `test_core`'s module order
gains `way`. `harness.lua` is unchanged: the fake map world lives in `test_way.lua`. Libraries unmodified.

## What landed
- **`WayBooks.lua`** (new; data only): the 39 books, with name, zone, coordinates, quest ID, level and note. The
  source is named at the top and in the list's closing line.
- **`Way.lua`** (new): the module `way`, with:
  - its store `DeadTiredDB.way.current[charKey]` (capped at 50);
  - the zone lookup (`C_Map.GetMapChildrenInfo` under Azeroth, Kalimdor and the Eastern Kingdoms; exact name,
    then a unique prefix);
  - the parser;
  - the pin (W2), the arrow (W3), arrival (W5);
  - the list window ("Where to?", with search);
  - the verbs: `/dt way <x> <y> [zone]`, `/dt way list`, `/dt way clear`, `/dt way arrow|pin on|off`, and
    `/dt way` alone, which says what's set;
  - the `fit`.
- **`Selftest.lua`:** 12 APIs added to `DT.REQUIRED`; `way.current` (50) added to `CAPS`.
- **`.toc`** (both files after `DeathBoard.lua`; 0.5.0) and **`Core.lua`** (`DT.VERSION`).
- **Docs:** `FEATURES.md` *Ruled 22 Nov (for `dt_waypointer`, 0.5.0)*, and `docs/RELEASE_0.5.0.md`. The Voice
  posts the latter in #dt-crypt-workshop by itself after the release.
- No other module touched. Nothing copied from `reference/` or from OpenMap.

## The arrow's worked examples (`test_way`, the fake Tanaris: 1,000 × 1,000 yards)
The player stands at 50, 50. The world runs north along X and west along Y; the bearing is
`atan2(dWest, dNorth) − facing`, counter-clockwise.

| Waypoint | Facing | dNorth, dWest (yd) | Bearing | Distance | Check |
|---|---|---|---|---|---|
| 50, 40 (north) | 0 (north) | 100, 0 | 0° (straight ahead) | 100 yd | ✓ |
| 50, 60 (south) | 0 | −100, 0 | 180° (behind) | 100 yd | ✓ |
| 40, 50 (west) | 0 | 0, 100 | 90° (left) | 100 yd | ✓ |
| 50, 40 (north) | π/2 (west) | 100, 0 | 270° (right) | 100 yd | ✓ |
| 80, 90 | 0 | −400, −300 | (not checked) | 500 yd | ✓ |

Arrival: a waypoint 5 yards off (3 east, 4 north) clears at once. One 6 yards off stays ("6 yd"), then clears
when the player walks up to it.

## The texture
`Interface\Minimap\MinimapArrow`: the client's own minimap player arrow, rotated with `Texture:SetRotation`. It
can't be seen offline. **Walk G6 is where it is checked.** If it doesn't show, or doesn't turn, that is the
brief's stop condition, met in game: Tim picks a text-only compass line or a shipped texture under a new ruling.

## Guard proofs
`lua5.1 tools/guard_proofs.lua`: **208 guards, every one red, every file restored**. That is the 196 already
proved (0.4.0's and earlier) plus the 12 below.

| Guard | File | Change | Suite | Result |
|---|---|---|---|---|
| way: coordinate range (W1) | `Way.lua` | line removed | test_way | **red**: parse: out of range refused; /dt way out of range: the usage line, nothing set |
| way: ambiguous zone refused (W1) | `Way.lua` | line removed | test_way | **red**: zone: an ambiguous prefix is refused; /dt way with an ambiguous zone: one line, nothing set |
| way: CanSetUserWaypointOnMap (W2) | `Way.lua` | line removed | test_way | **red**: a map that takes no pin: the line, the arrow still on; ...and the old pin (DT's own) was cleared, not left behind |
| way: clear only DT's own pin (W2) | `Way.lua` | line removed | test_way | **red**: clear: a pin the player has moved since is left alone |
| way: a secret or missing read hides the needle (W3) | `Way.lua` | line removed | test_way | **red**: a secret position: the needle hides, no error |
| way: arrival radius (W5) | `Way.lua` | `if dist <= ARRIVE + 2 then` | test_way | **red**: arrival: 6 yards away it stays |
| way: OnUpdate throttle (W3) | `Way.lua` | line removed | test_way | **red**: throttle: 100 frames in a second make about 10 updates |
| way: hidden does nothing (W3) | `Way.lua` | line removed | test_way | **red**: hidden: OnUpdate reads nothing |
| way: store cap (W6) | `Way.lua` | `while false do` | test_way | **red**: the store keeps 50 characters, yours always among them |
| way: guild gate (set) | `Way.lua` | `if not DT.enabled("way") then return false end` | test_way | **red**: outside the guild: setting directly refuses too |
| way: module switch (set) | `Way.lua` | `if not DT.isMember() then return false end` | test_way | **red**: off: setting directly refuses |
| way: off verbs do nothing else | `Way.lua` | line removed | test_way | **red**: off: /dt way 50 50 says so and does nothing else; off: /dt way list says so and does nothing else; off: /dt way clear says so and does nothing else (+2 more) |

**Test strengthened (CLAUDE.md's one exception).** The first run had one guard NOT RED: the `OnUpdate`
throttle. The harness steps time in 0.1-second ticks, exactly the throttle's interval, so removing the throttle
changed nothing. `test_way` gained a check that calls the arrow's `OnUpdate` 100 times with 0.01 seconds each, as a
real frame rate would (test file only):

```diff
+  local arrow = DT._way.arrow()
+  r0 = a.reads
+  for _ = 1, 100 do arrow.scripts.OnUpdate(arrow, 0.01) end
+  check("throttle: 100 frames in a second make about 10 updates", a.reads - r0 >= 9 and a.reads - r0 <= 11)
```

Proved again: with the throttle removed it reads 100 times and goes red; restored, it's green.

## Player-facing text, verbatim
- Set: `Waypoint: <zone> <x>, <y>.`, or `Waypoint: <book>, <zone> <x>, <y>.` from the list
- `/dt way` alone: `Waypoint: <label>.`, or `No waypoint set. /dt way <x> <y> [zone], /dt way list, /dt way clear, /dt way arrow|pin on|off`
- Bad input: the same usage line
- Zones: `More than one zone starts "<text>". Type more of it.`, `No zone called "<text>".`
- `No map pin there; the arrow will do.`
- `Arrow and pin are both off.`
- `You're there.`, `Waypoint cleared.`, `No waypoint set.`
- `Can't tell where you are. Try again outdoors.`
- Switches: `the arrow is on.` / `the arrow is off.` / `the pin is on.` / `the pin is off.`
- Arrow: `<n> yd` (thousands with a comma), `another continent`, or `…` (no reading); the place under it
- List: title `Where to?`; columns book, zone, x, y, level; empty state `No books match.`; closing line
  `Coordinates from Warcraft Tavern's Forever book guide.`; tooltip: the book, its note,
  `Click to set the waypoint.`; a book whose zone isn't found is greyed, shows `<zone> (zone not found)`, and a
  click says `<zone>: zone not found.`
- Switched off: `way.enabled = off`
- Cards:
  - On: `The Waypointer: /dt way. Off, no arrow, no pin, no list.`
  - Arrow: `Shows Dead Tired's arrow toward your waypoint, with the distance in yards. Drag it where you like.`
  - Map pin: `Puts the game's own map pin on your waypoint (where the game allows one). Dead Tired only clears a pin it set.`

## The zip
`dist/DeadTired-0.5.0.zip`: 203,130 bytes, sha256 `80d39acc9ca9b207076f54e75aaf64caa83b4fcf56ab811d4588676ec17e2a00`.
`diff -r` against the checkout (tests excluded) is clean.

## What the brief got wrong, or left open
1. **The arrow's text is two lines, not one.** W3 said `<place>: <n> yd` on one line. At 180 px a long place
   ("The Hinterlands 50.0, 50.0") cut the yards off, the part that matters while riding. Now the yards sit on top
   and are never cut (checked); the place is under it, in the small font, cut with "…" when long.
2. **The pin after a relog.** The brief didn't say. On entering the world with a saved waypoint, DT puts the pin
   back **only if the game has no pin at all**. It never covers a pin the player set since.
3. **Setting a new waypoint clears DT's old pin first** (only while it's still DT's). Otherwise a waypoint on a
   map that refuses pins would leave the previous pin up.
4. **`/dt way` alone** says what's set. The brief didn't name it; it's the natural "where was I going?".
5. **Blackrock Mountain's two books** ("Stonewrought Design", "Magma or Lava?") carry the guide's coordinates,
   Burning Steppes 31, 30, for both. The guide gives the same spot for two different places, so treat them as
   approximate until someone stands there.
6. **Zone names come from the client.** A book whose zone name doesn't match the client's list shows greyed. In
   game this also catches any spelling of ours that differs from Forever's. Watch for grey rows in G7.

## Questions for Tim
1. Is the arrow's default place right: top centre, 140 px down? It's draggable either way.
2. Are trainers, flight masters and the Fishing Extravaganza wanted in the next round? They need coordinates
   from a source we trust, or from you standing there with `/dt way` (a "save this spot" verb would be one
   small addition).
