# Cowork brief: the Waypointer (0.5.0)

You are in `LUCA5G00N/dead-tired-addon`, building in a cloud session; Tim walks the result in game.
Read first, in order:
1. `CLAUDE.md` on `main`, and `docs/DECISIONS.md` 0001 and 0002.
2. This brief and its walk-sheet, `docs/UAT_dt_waypointer.md`.
3. `DeadTired/UI.lua`: `DT.viewport`, `DT.list`, `DT.listModel`, `DT.restorePlace`, `DT.draggable`,
   `DT.closeOnEscape`, `DT.text`, `DT.fitCheck`.
4. `DeadTired/DeathBoard.lua` (0.4.0): the newest module, and the pattern this round copies (module, store,
   verbs, window, `fit`, offline-test shape).
5. `DeadTired/Selftest.lua` (`DT.REQUIRED`, `CAPS`) and `DeadTired/Core.lua` (`try`, `clean`, `DT.module`).
6. `reference/SPEC_forever_namespaces.md`: `C_Map` and `C_SuperTrack`.

**Draft status: written 22 Nov 2026, 20:40, against `main` at `28b49e3` (0.4.0, released).** Every name above
is re-read against the tree as Task 1's first act.

## Origin
- Design block F, settled 20 Nov at 18:52 (`claude/27_design_blocks_2026-11-20.md`): F1–F4. Planned since 12 Nov.
- F6 (study OpenMap) answered 22 Nov, 20:35 (`claude/40_waypointer_f6_openmap_2026-11-22.md`), from OpenMap's
  public repo (MIT, `6c2299f`).
- F5 probe, run by Tim 22 Nov 20:27–20:28 in Tanaris, with screenshots:
  - `C_Map.SetUserWaypoint` works (`1446 true true true`), and so does `C_SuperTrack.SetSuperTrackedUserWaypoint`
    (`true true`).
  - The pin shows on OpenMap's map (its "Waypoint, Tanaris 50.0, 50.0" tooltip), and a small arrow sits at the
    minimap's edge.
  - **The game draws no marker in the world view.**
  - `C_Map.GetWorldPosFromMapPos` gives continent and yards; `GetPlayerFacing` gives a facing (4.93).
  - `C_Map.ClearUserWaypoint` clears it.
- **Tim chose option (b), 20:29:** our own arrow **and** Blizzard's pin, as F2 said.

## Precondition
`main` at `28b49e3` or later, carrying this brief and its walk-sheet; `run_all.sh` `ALL GREEN`.

## Rulings in force (cited, not restated)
- `CLAUDE.md`: module rules 1–14; guarded reads; no combat data; no hooks; the `UISpecialFrames` exception.
- R-F4-1 (text through `DT.text`). R-P2-2 (Escape closes DT's own windows).
- F1–F4 (block F, 20 Nov), as amended by W1 below.

## Rulings for this round (W1–W7; proposed, ratified by Tim's merge of this brief)
- **W1 Where to.** Three ways to set a waypoint:
  - `/dt way <x> <y>`: coordinates in your current zone, 0–100 as the game shows them, decimals allowed.
  - `/dt way <x> <y> <zone>`: in a named zone. The name is matched, case-insensitive, against the zones the
    client lists (`C_Map.GetMapChildrenInfo`, guarded); a unique prefix is enough. No match, or more than one:
    one line saying so, and nothing set.
  - `/dt way list`: a window with the built-in list. Clicking a row sets it.

  **The round-one built-in list is the 39 library books**, data from `claude/39_guild_quests_arcs_2026-11-22.md`
  (Warcraft Tavern's Forever guide). Each row shows the book, zone, coordinates and level band. F1's trainers,
  flight masters and event spots wait: none of their coordinates are sourced yet. The book list makes the
  Waypointer useful at once, and it is the first step toward the guild quests.
- **W2 The pin (Blizzard's).** It is set with `C_Map.SetUserWaypoint`, then tracked
  (`C_SuperTrack.SetSuperTrackedUserWaypoint(true)`), only when `C_Map.CanSetUserWaypointOnMap(map)` says yes.
  - If it says no: the arrow still works, and one line explains: `No map pin there; the arrow will do.`
  - Clearing the waypoint clears the pin, but only while the pin is still the one DT set
    (`C_Map.GetUserWaypoint` matches). A pin the player has moved since is left alone.
- **W3 The arrow (ours).** A small window of DT's own:
  - a rotating arrow, and a line under it: `<place>: <n> yd` (or `<place>: another continent`);
  - draggable, its position remembered; hidden while no waypoint is set;
  - it updates at most 10 times a second.

  Distance and bearing come from `C_Map.GetPlayerMapPosition`, `C_Map.GetBestMapForUnit`,
  `C_Map.GetWorldPosFromMapPos` and `GetPlayerFacing`, every one guarded. Positions may be secret (OpenMap treats
  them so): a secret or missing read hides the arrow's needle for that update and shows `<place>: …`, never an
  error.
  - World X runs north and Y runs west. The bearing is `atan2(dWest, dNorth)` minus the facing,
    counter-clockwise, as `Texture:SetRotation` takes it.
  - The art is the client's own. The build tries `Interface\Minimap\MinimapArrow` and records in the report
    which texture it used.
- **W4 Both on (F2).** Two settings, both default on:
  - `way.arrow` (`/dt way arrow on|off`);
  - `way.pin` (`/dt way pin on|off`).

  With both off, `/dt way` still sets the waypoint and says `Arrow and pin are both off.`
- **W5 Arrived (F3).** Within 5 yards of the waypoint, it clears itself: arrow hidden, pin cleared (W2), and one
  line: `You're there.` `/dt way clear` clears it at any time.
- **W6 One waypoint, kept.** At most one waypoint, saved per character (`DeadTiredDB.way.current[charKey]`) so a
  `/reload` keeps it. A new one replaces the old. Nothing is shared: no messages, no ghost kind (F4 is later).
- **W7 Version.** 0.5.0, a new feature.

## Deliverable
On `claude/dt-waypointer` from `main`, DeadTired **0.5.0**. A new module, `way` (`Way.lua`, plus its data file
`WayBooks.lua`), with:
- the verbs `/dt way <x> <y> [zone]`, `/dt way list`, `/dt way clear`, `/dt way arrow on|off` and
  `/dt way pin on|off`;
- the arrow window and the list window.

In the harness:
- a waypoint set by each route gives Blizzard's pin (when allowed) and an arrow;
- the arrow's bearing and distance match worked examples to within 1 degree and 1 yard;
- walking within 5 yards clears it;
- a `/reload` keeps it.

The round is done when:
- `run_all.sh` is `ALL GREEN`;
- every Task 7 guard has been removed once and turned a named check red;
- `dist/DeadTired-0.5.0.zip` passes `diff -r`.

## Working rules
- No module but `way` changes, apart from:
  - `Selftest.lua`: new APIs in `DT.REQUIRED`;
  - `.toc`;
  - `Core.lua` (`DT.VERSION`);
  - test version lines.

  Nothing is borrowed from OpenMap, TomTom or HereBeDragons. No library is added.
- Every `C_Map`, `C_SuperTrack` and global call goes through `try`/`clean`, and every result is checked for type
  and range before use. No secret value reaches arithmetic.
- No hook. No `hooksecurefunc`. No write to any Blizzard frame or table (the `UISpecialFrames` insert aside).
- The arrow's `OnUpdate` runs only while a waypoint is set and the arrow is on; otherwise the frame is hidden
  and does nothing.
- Book rows are data only: name, zone name, x, y, quest ID (kept for the guild quests, not used yet), level text.
  Zone names are matched to map IDs at run time, the same way as W1; a book whose zone doesn't match is listed
  greyed, with `zone not found`.

## Tasks
1. **Baseline:** suites and counts; re-verify "Read first" and the `C_Map` and `C_SuperTrack` names in the SPEC.
2. **`WayBooks.lua`:** the 39 books from `claude/39`, with the source cited at the top.
3. **`Way.lua`:**
   - the module and its store (`DeadTiredDB.way = { current = { [charKey] = { map, x, y, label } } }`, capped at
     50 characters);
   - the zone lookup;
   - the verbs;
   - the pin (W2), the arrow (W3), arrival (W5);
   - the list window (a `DT.viewport` with search; the empty-state line `No books match.`);
   - the closing line `Coordinates from Warcraft Tavern's Forever book guide.`;
   - the `fit`.
4. **`Selftest.lua`:** add every new API used to `DT.REQUIRED` (at least `C_Map.SetUserWaypoint`,
   `C_Map.ClearUserWaypoint`, `C_Map.GetUserWaypoint`, `C_Map.CanSetUserWaypointOnMap`, `C_Map.GetBestMapForUnit`,
   `C_Map.GetPlayerMapPosition`, `C_Map.GetWorldPosFromMapPos`, `C_Map.GetMapChildrenInfo`, `C_Map.GetMapInfo`,
   `C_SuperTrack.SetSuperTrackedUserWaypoint`, `GetPlayerFacing`); `way.current` (cap 50) to `CAPS`.
5. **`.toc`:** the two new files after `DeathBoard.lua`; version 0.5.0. `Core.lua`: `DT.VERSION`.
6. **The harness:** stubs for the `C_Map` and `C_SuperTrack` calls, `GetPlayerFacing` and `UiMapPoint`, in
   `tests/test_way.lua` (or `harness.lua` if more than one suite needs them). The world is a small fake map table
   with known rectangles, so worked examples can be computed by hand.
7. **Tests and guard proofs** (`test_way.lua`; additions to `test_selftest`).
   - **Tests:**
     - parsing: good coordinates, out of range, missing, a comma, `45,2`;
     - the zone lookup: unique, a prefix, ambiguous, none;
     - the pin: set and tracked when allowed; not set, with the line, when refused; cleared on clear only while
       it's ours;
     - the arrow:
       - bearing and distance on four worked examples (ahead, behind, left, right);
       - another continent;
       - a secret read;
       - hidden with no waypoint;
       - no `OnUpdate` work while hidden;
     - arrival within 5 yards, and not at 6;
     - both settings off;
     - kept over a `/reload`; replaced by a new one;
     - the list: 39 rows, search, a click sets it, the empty state, the closing line;
     - fit under every skin;
     - nothing outside the guild;
     - the module off does nothing.
   - **Guards** (remove once, a named check red, restore):
     - the range check;
     - the ambiguous-zone refusal;
     - `CanSetUserWaypointOnMap`;
     - clear-only-ours;
     - the secret-read hide;
     - the arrival radius;
     - the `OnUpdate` throttle;
     - the hidden-does-nothing check;
     - the store cap;
     - the guild gate;
     - the module switch;
     - every guard 0.4.0 proved.
8. **Docs:** `FEATURES.md` *Ruled 22 Nov (for `dt_waypointer`, 0.5.0)*; `docs/RELEASE_0.5.0.md` (DT's voice, a
   few lines; the Voice posts it in #dt-crypt-workshop by itself).
9. **Version and zip:** `dist/DeadTired-0.5.0.zip`, `diff -r` clean.
10. **Report** `docs/COWORK_REPORT_dt_waypointer.md`; PR to `main`, not stacked.

## Out of scope
- Trainers, flight masters and event spots in the list (W1: their coordinates aren't sourced yet).
- Guildies' positions, sending or sharing waypoints (F4).
- Quest objectives (F1).
- Guild-quest progress (the book quest IDs are carried, not used).
- TomTom, HereBeDragons, OpenMap's API.
- A route of several waypoints.
- A minimap icon of our own: Blizzard's pin already puts one at the minimap's edge.

## The one deliberate widening
DT starts setting and clearing Blizzard's own map pin, the one pin a player has. It is bounded:
- only on a typed `/dt way` or a click in DT's list;
- cleared only while the pin is still the one DT set;
- switchable (`way.pin off`).

## Stop conditions
- Baseline not `ALL GREEN`, or `lua5.1` can't be installed → stop.
- Any `C_Map` or `C_SuperTrack` function this brief names is absent from the SPEC → stop and report.
- The arrow needs a hook, a library, or a write to a Blizzard frame → stop.
- No client texture can be found that rotates as an arrow → stop and report (Tim decides: a text-only compass
  line, or a shipped texture under a new ruling).
- A guard removal turns nothing red: strengthen the test (test files only); if that needs addon code → stop.

## UAT: acceptance checks
`docs/UAT_dt_waypointer.md`: **5 [G] offline, 4 [G] in game, 2 [H].**

## Reporting
`docs/COWORK_REPORT_dt_waypointer.md`:
- branch and heads; counts per suite;
- the four worked arrow examples, with their numbers;
- the texture used;
- each guard proof;
- the player-facing text, verbatim;
- zip name, size, sha256;
- what the brief got wrong; questions.

Never write a `_results.md` file.
