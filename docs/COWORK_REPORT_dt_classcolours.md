# Report: class-coloured names in death notices (0.3.3)

Brief: `docs/COWORK_BRIEF_dt_classcolours.md` (ratified by Tim's merge of PR #21, 21 Nov; R-F6-4
answered 19:16: shamans stay blue). Walk-sheet: `docs/UAT_dt_classcolours.md`.

Built in this Claude session (the one that drafted the brief, under the 20 Nov release flow) on
branch `claude/dt-classcolours`. Old head `f46be81` (`main`); new head: the commit carrying this
report. Not merged; Tim merges after his walk, and the merge publishes the release
(`.github/workflows/release.yml`). `lua5.1` and `luac5.1` installed (apt).

## Counts
Baseline `run_all.sh` at `f46be81`: ALL GREEN, 26 suites, 1364 checks.
Final: ALL GREEN, 26 suites, **1417 checks**. Changed suites: guild 20 -> 39, crypt 103 -> 119,
debug 26 -> 35, ui 113 -> 122; core and who: version strings only (same counts).

## What landed, task by task
1. Baseline: as above.
2. `Guild.lua`: `DT.rosterClasses()` (one guarded walk, cap 1000; lower full name -> `{ name, token,
   realm }`) and `DT.classColour(key, roster)` -> `r, g, b, hex` or nil. **One addition the brief
   didn't ask for:** each roster entry also keeps `name`, the roster's own spelling, so the preview
   prints `Stromham Hamson` when you type `stromham hamson`. `DT.rosterWalks` counts walks (for the
   one-walk tests).
3. `Crypt.lua`: the two notice lines are built by one function, `DT.noticeLine(from, lvl, zone, hc,
   roster)`. The `DEATH` handler now prints `DT.noticeLine(...)`; wording unchanged. The colour wraps
   the name after `DT.display` (which escapes `|`), and only when `colorStr` passed the 8-hex check.
4. `UI.lua`: column option `rgb = "<row field>"`; on every `refresh` a cell takes `SetTextColor` from
   that field when it is a table, else its column's own colour. The list's skin callback ends with
   `refresh`, and the text painters run before it, so the colour is re-applied after a skin change.
   `Crypt.lua`: `DT.graveRows` walks the roster once and adds `nameRGB`; the name column declares it.
5. `Debug.lua`: `/dt debug rip <name>` -> `DT.noticeLine` twice (level 30, Duskwood; ordinary, then
   hardcore). Not on the roster -> `not on the roster.`; no name -> `/dt debug rip <name>`.
6. Tests: `test_guild` (lookup, fallbacks, never written), `test_crypt` (both notice lines, plain
   fallback, nothing new sent or saved, graveyard colours, reused row, skin change, one walk for 100
   deaths), `test_ui` (the `rgb` option on its own), `test_debug` (the preview).
7. Guard proofs: below.
8. Docs: `FEATURES.md` *Ruled 21 Nov (for `dt_classcolours`)*; `RELEASE_0.3.3.md`.
9. `.toc` and `DT.VERSION` 0.3.3; `dist/DeadTired-0.3.3.zip`.

## The probe's colours, as the tests expect them
| Class (token) | colorStr | r, g, b |
|---|---|---|
| Shaman (SHAMAN) | `ff0070dd` | 0, 0.44, 0.87 |
| Rogue (ROGUE) | `fffff468` | 1, 0.96, 0.41 |
| Mage (MAGE) | `ff3fc7eb` | 0.25, 0.78, 0.92 |
| Warlock (WARLOCK) | `ff8788ee` | 0.53, 0.53, 0.93 |
| Paladin (PALADIN) | `fff48cba` | 0.96, 0.55, 0.73 |
The `colorStr` values are the probe's (21 Nov 13:24). The r, g, b values are the stubs' own
approximations; the build reads both from the client, never from a table of its own.

## Guard proofs (this round's nine; `lua5.1 tools/guard_proofs.lua`)
| Guard | File | Change | Suite | Went red |
|---|---|---|---|---|
| colorStr is 8 hex digits (R-F6-5) | `Guild.lua` | `if type(hex) ~= "string" then return nil end` | test_guild | **red**: R-F6-5: a 7-digit colorStr: nil |
| r/g/b in range (R-F6-5) | `Guild.lua` | line removed | test_guild | **red**: R-F6-5: r out of range: nil |
| realm match (R-F6-3) | `Guild.lua` | line removed | test_guild | **red**: R-F6-3: a roster name with a different -Realm: nil |
| plain fallback: not on the roster (R-F6-5) | `Guild.lua` | `if not e then e = { token = "SHAMAN" } end` | test_crypt | **red**: R-F6-5: not on the roster: the 0.3.2 line exactly, nothing else printed; graveyard: placed rows carry nameRGB, others none; graveyard: an unplaced name cell has the column's own colour (+1 more) |
| a reused row's colour is reset (rgb) | `UI.lua` | `end` | test_ui | **red**: rgb: a reused row frame is reset; rgb: an empty row is reset too |
| the colour after a skin change (rgb) | `UI.lua` | `L:layout() ⏎     L:widths() ⏎   end)` | test_ui | **red**: rgb: the colour holds after a skin change |
| one roster walk per graveyard build | `Crypt.lua` | `local roster = nil` | test_crypt | **red**: graveyard: one roster walk per build; graveyard of 100: still one roster walk |
| debug rip records nothing (R-F6-6; a record inserted) | `Debug.lua` | `DT.out(DT.noticeLine(key, 30, "Duskwood", true, roster)) ⏎   local dd = DT.crypt().deaths; dd[#dd + 1] = { who = key, lvl = 30, zone = "Duskwood", hc = false, at = "x" }` | test_debug | **red**: debug rip: records nothing |
| debug rip sends nothing (R-F6-6; a send inserted) | `Debug.lua` | `DT.out(DT.noticeLine(key, 30, "Duskwood", true, roster)) ⏎   DT.send("DEATH", { lvl = "30", zone = "Duskwood", hc = "0" })` | test_debug | **red**: debug rip: sends nothing |

All 128 guards in `tools/guard_proofs.lua` (0.3.2's 119 and these nine) went red when removed and
were restored byte for byte: "every guard proved; every file restored".

## Player-facing lines added
- `not on the roster.` and `/dt debug rip <name>` (the preview's usage; also listed in `/dt help`).
- The release notes (`docs/RELEASE_0.3.3.md`).
No notice line's wording changed: the tests check both lines byte for byte against 0.3.2's.

## Zip
`dist/DeadTired-0.3.3.zip`, 177174 bytes, sha256
`0623cb5027c8381c87ca0138122dafa4135f7e62211299bc124637d537c5dced`, 41 files (the same set as
0.3.2), `diff -r` clean against `DeadTired/` (tests excluded).

## What the brief got wrong, or left open
- Not wrong, but worth knowing at the walk: R-F5-5's known issue (an open window keeps its old skin)
  is about fonts and titles. The name colours are re-applied by the list's own refresh, which the
  harness shows running on a skin change. In game, if the graveyard's titles stay stale after
  `/dt skin`, the colours may stay stale with them. That's the old issue, not this round's.
- H2 names Echo Nightclaw as an example. Whether Echo Nightclaw is still on the roster wasn't
  checked; if not, a plain name there is R-F6-5 working, not a fault.

## Questions for Tim
None beyond the walk.

Never write a `_results.md` file: the walk is Tim's.
