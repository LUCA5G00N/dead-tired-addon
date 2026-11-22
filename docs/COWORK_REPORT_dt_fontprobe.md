# Cowork report: the font probe (0.3.7)

Brief `docs/COWORK_BRIEF_dt_fontprobe.md`; walk-sheet `docs/UAT_dt_fontprobe.md`. Built 22 Nov 2026 in a cloud
session on **`claude/dt-fontprobe`** from `main` at **`2214f4e`** (the brief's merge, PR #32). R-F11-1 to
R-F11-6 ruled by Tim, 18:04: "all as leaned".

## Counts
| | Suites | Checks | Result |
|---|---|---|---|
| Baseline (`2214f4e`, 0.3.6) | 28 + taint + textfit | 1,569 | ALL GREEN |
| This round | 28 + taint + textfit | 1,594 | ALL GREEN |

New checks:
- `test_ui` 123 → 144 (the probe's tests);
- `test_textfit` 8 → 11 (the `:SetFont(` rule, its fixture and the door count). One existing line changed:
  `UI.lua` now makes 3 kinds of text, not 2 (see "What the brief got wrong").

Version lines in `test_core`, `test_who` and `test_selftest` move from 0.3.6 to 0.3.7. `tests/harness.lua`
gains `Frame:GetFont` (returns what `SetFont` stored). No other suite changed. Libraries unmodified.

## Every `SetFont` site, and how it is routed (R-F11-1)
| Site | File | Now | `tpl` recorded |
|---|---|---|---|
| `preload` | `UI.lua`, `DT.preloadFonts` | `DT.fontCall(fs, p, size, flags, "preload", role)` | `GameFontHighlight` (the measuring string) |
| `measure` | `UI.lua`, `DT.measure` | `DT.fontCall(..., "measure", role)` | `GameFontHighlight` |
| `fontTo` | `Skins.lua`, `DT.fontTo` | `DT.fontCall(..., "fontTo", role)` | the template `DT.text` used (`GameFontHighlight` unless a caller names another) |
| `search` | `UI.lua`, the viewport's search box | `DT.fontCall(vp.search, ..., "search", "body", "editbox")` | `editbox` |
| `settings` | `SettingsView.lua`, the typed-setting box | `DT.fontCall(c, ..., "settings", "body", "editbox")` | `editbox` |

`DT.fontCall` returns what `SetFont` returned and does nothing else while the probe is off. Every site that
counted `ui:font` still does: `fontTo` and `preload`, both guards re-proved red.

## The static check (`test_textfit`)
The scanner reads `luac5.1`'s listing and tracks which function each instruction is in. It goes red on any
method call `:SetFont(` outside `DT.fontCall` and `DT.fontProbeMatrix`, which are found by their first lines
in `UI.lua`.
- **Fixture:** a raw call at the top level (line 2) and one inside a function (line 3) are caught. A look,
  `if fs.SetFont`, and a call through the door pass.
- **On the tree:** no raw `:SetFont(`. The door and the matrix make 4 calls, so the scan isn't blind.

## The probe (R-F11-2 to R-F11-4)
- **`/dt debug fontprobe on`:** `fontprobe: on, recording every font Dead Tired sets until you say off.` It
  clears `DeadTiredDB.fontprobe.calls` and records each call: `site`, `role`, `skin`, `path`, `size`,
  `flags`, `res` (`false`, `true`, or `"nil"` when `SetFont` answered nothing), `before` and `after`
  (`GetFont()`), `vis` and `tpl`. It keeps the last 300.
- **`/dt debug fontprobe off`:** `fontprobe: off. /reload to save what it saw.`
- **`/dt debug fontprobe matrix`:** eight new strings each run, one line each:
  `fontprobe <tpl> <shown|hidden> <fresh|friz>: CYR <res>, plain <res>`. Saved as `fontprobe.matrix`.
- **`/dt debug fontprobe`:** four lines.
  - `fontprobe: <on|off>, <n> calls, <r> refused`
  - `fontprobe refused by site: …`
  - `fontprobe refused by visibility: …; by template: …`
  - `fontprobe refused and the old font kept: <k> of <r>`

The harness run with the gothic file refused (the old font kept) showed:
- 6 refusals on a skin switch with the graveyard open: `fontTo` 3, `measure` 3;
- all six kept the old font.

So a refused `SetFont` on an open window does leave its title plain. That is consistent with 0.3.2's H1, but
it's only the harness. The real answer is Tim's walk.

## Tests (21 new in `test_ui`)
- Off: nothing recorded.
- On: it says so, and is kept in memory only.
- A `fontTo` title call recorded with every field.
- A refusal keeps the old font (Friz before and after).
- An accepted call records `"nil"`.
- `ui:font` is still counted while recording.
- The summary's four lines match the calls.
- Off: it says so and stops recording.
- On again: the last recording is overwritten.
- Capped at the last 300 (`p51`…`p350`), and a caller's `tpl` is kept.
- A `/reload` turns it off, and nothing more is recorded.
- Matrix: 8 rows in order, both paths with the font after each, and one printed line per string.
- `/dt help` lists `debug fontprobe`.

## Guard proofs (`lua5.1 tools/guard_proofs.lua`)
**176 guards** turned red when removed, and every file was restored exactly as it was: 0.3.6's 172 and 4 new.

| Guard | Change | Went red |
|---|---|---|
| records only while on | `if probe.on` → `if true` | "probe off: nothing recorded", "probe off: records nothing more" |
| keeps the last 300 | cap removed | "probe: capped at the last 300" (+1) |
| on kept in memory | `fp.on = true` added | "probe on: kept in memory only" |
| the static check | `fontTo` calls `fs:SetFont` directly | "R-F11-1: no :SetFont( outside DT.fontCall and the matrix" |

The brief's "each site still counting `ui:font`" is 0.3.6's two existing guards (`fontTo`, preload),
re-proved red.

## Zip
`dist/DeadTired-0.3.7.zip`: 189,027 bytes, sha256
`459b759920bf0e014ffd6f530aa9095d71aeb9ac3e08a2ce0faad950c13e5b4b`. `diff -r`: clean.

## What the brief got wrong, or left open
- **Five sites, not four.** `SettingsView.lua` re-fonts the typed-setting box. It's routed as `settings`.
- **The matrix's axes.** R-F11-3 says "eight control strings", but its axes (template, shown or hidden) give
  four, and "starting from Friz" applied to all of them. To make eight, and to test the third difference
  the brief named (a string that already holds a font), the third axis is **fresh or from Friz**. The
  strings are made anew each run, so "fresh" stays true. The brief said "once per session".
- **An existing suite changed beyond its version lines.** `test_textfit`'s "UI.lua does call it" count
  went from 2 to 3 for the matrix's strings, which R-F11-3 requires to be in `UI.lua`. Task 5 also edits
  that suite. I judged the change to follow from the brief's own design, so it doesn't trip the stop
  condition. Tim may disagree.
- **The harness gains `Frame:GetFont`** (test file).
- **Debug module, no new module.** The verbs went into `Debug.lua` beside `debug fit`. The code lives in
  `UI.lua`, because the matrix needs `CreateFontString`. No On card, like the other `debug` verbs.
