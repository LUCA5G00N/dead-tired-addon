# Cowork report: the self-test stops crying font (0.3.6)

Brief `docs/COWORK_BRIEF_dt_fontinfo.md`; walk-sheet `docs/UAT_dt_fontinfo.md`. Built 22 Nov 2026 in a cloud
session on **`claude/dt-fontinfo`** from `main` at **`3d30308`** (the brief's merge, PR #30). R-F10-1 to
R-F10-4 ruled by Tim, 14:27: "we're going with your leans".

## Counts
| | Suites | Checks | Result |
|---|---|---|---|
| Baseline (`3d30308`, 0.3.5) | 28 + taint + textfit | 1,562 | ALL GREEN |
| This round | 28 + taint + textfit | 1,569 | ALL GREEN |

`test_selftest` 49 → 56. The version lines in `test_core`, `test_who` and `test_selftest` move from 0.3.5 to
0.3.6. No other suite changed. Libraries unmodified.

## What landed (`Selftest.lua` only, plus the version, docs and zip)
- **R-F10-1.** A `KNOWN` table holds `ui:font` and nothing else. S6 lists known ids after its verdict and
  never fails on them. Every other id fails S6 as before.
- **R-F10-2.** `DT.selftest` sets `session.running` for the length of a run. The `DT.fail` wrapper doesn't
  count errors recorded while it is set. `DT.fail` itself still saves them, so `/dt debug errors` is
  unchanged.
- **R-F10-3.** Nothing else changed: fonts, skins, S7 and every other check are as they were.

**The S6 line's new text, verbatim:**
- `S6 errors: pass - none this session; ui:font 1 (known, not counted)`
- With another id: `S6 errors: FAIL - bar 1; ui:font 1 (known, not counted)`
- With none: `S6 errors: pass - none this session`, as before.

## Tests (`test_selftest`, 7 new)
- `ui:font` refused at load (the harness refuses the gothic font at every touch, like Tim's client): S6
  passes, with the note `ui:font 1 (known, not counted)`.
- A second run in the same session: 10 passed again. The note still says 1, so S7's own refusals were
  not counted.
- The run's own refusals are still saved under `errors`.
- Another id alongside `ui:font`: S6 fails, naming the other id, and the note still shows the font.
- An error recorded during a run (any id): the next run's S6 passes. One recorded after the run fails S6
  as before.

## Guard proofs (`lua5.1 tools/guard_proofs.lua`)
**172 guards** turned red when removed, and every file was restored exactly as it was: 0.3.5's 169 and 3 new.
S6's own guard ("S6 errors can fail") is retargeted to its new line, and is still red.

| Guard | Change | Went red |
|---|---|---|
| R-F10-1: ui:font is information | `if KNOWN[id]` → `if false` | "ui:font refused at load: S6 passes, noting it", "a second run…: 10 passed again" (+2) |
| R-F10-1: other ids still fail | other ids moved into the note | "S6 fails on an error this session", "another id with ui:font: S6 fails…" (+2) |
| R-F10-2: a run's own errors don't count | `if not session.running` → `if true` | "the run's own refusals are not in the next run's note", "an error recorded during a run…" (+1) |

## Zip
`dist/DeadTired-0.3.6.zip`: 187,147 bytes, sha256
`639eeead7e690cadde609c866ffeb301e7fe7c2cb9a0cd490fc7b0b23525c07b`. `diff -r`: clean.

## What the brief got wrong, or left open
Nothing turned out wrong. For the skin-switch probe round:
- remove `ui:font` from `KNOWN` once the font is fixed (the brief's widening clause);
- start from the walk's evidence: refused on DT's own strings mid-session, accepted on a fresh `FontString`.
