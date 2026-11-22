# Cowork report: the font the game refuses once (hotfix 0.3.6)

Brief `docs/COWORK_BRIEF_dt_fontload.md`; walk-sheet `docs/UAT_dt_fontload.md`. Built 22 Nov 2026 in a cloud
session on **`claude/dt-fontload`** from `main` at **`e195a00`** (the brief's merge, PR #28). R-F9-1 to R-F9-4
ruled by Tim, 13:14: "all as leaned".

## Counts
| | Suites | Checks | Result |
|---|---|---|---|
| Baseline (`e195a00`, 0.3.5) | 28 + taint + textfit | 1,562 | ALL GREEN |
| This round | 28 + taint + textfit | 1,567 | ALL GREEN |

`test_skins` 39 → 43, `test_selftest` 49 → 50. The version lines in `test_core`, `test_who` and
`test_selftest` move from 0.3.5 to 0.3.6. Libraries unmodified.

## What landed
- **`UI.lua`, `DT.preloadFonts`** (R-F9-1). A `SetFont` that answers `false` is tried once more on the same
  hidden string, `RETRY_FONT` (1 s) later through `DT.after`. Only a second `false` is counted under
  `ui:font`, with the same text as before. Nothing else in the file changed.
- **Unchanged (R-F9-2):**
  - `DT.fontTo`, which still counts a refusal at once;
  - font paths and how LibSharedMedia is asked;
  - `DT.preloaded`.
- **Version 0.3.6:** `.toc` and `DT.VERSION`.
- **Docs:** `FEATURES.md` *Ruled 22 Nov (for `dt_fontload`, hotfix 0.3.6)*; `docs/RELEASE_0.3.6.md`.

## The test diff in `test_skins.lua`, and why
- **Removed:** R-F5-5's *"a false from SetFont at load (the preload's one gothic font) is counted under
  ui:font"*. R-F9-1 deliberately reverses it: a single false at load is no longer counted.
- **Added (five checks):**
  - refused at load: not counted yet;
  - refused at load, then accepted on the retry: counted 0;
  - the gothic font asked for twice at load (once, plus the one retry);
  - refused at load and again on the retry: counted once;
  - one retry only: never a third try.
- **Kept:** R-F5-5's other checks. That covers fonts set at load for every skin, a false from `fontTo`
  counted at once, and a SetFont that answers nothing not counted.

`test_selftest` gains one check. A client whose first gothic `SetFont` answers `false` reads "10 passed, 0
failed" after the retry, with S6 passing.

## Guard proofs (`lua5.1 tools/guard_proofs.lua`)
**172 guards** turned red when removed, and every file was restored exactly as it was:
- **169 from 0.3.5.** The preload's counting guard is retargeted to the amended line, *"a second false from
  SetFont at load is counted"*.
- **3 new:**

| Guard | Change | Went red |
|---|---|---|
| the retry | count the first refusal before retrying | "refused at load: not counted yet", "…accepted on the retry: counted 0", "…counted once" |
| only a second false is counted | count after the retry whatever it answers | "refused at load, accepted on the retry: counted 0" |
| one retry only | a third `SetFont` added | "asked for twice at load", "one retry only: never a third try" |

The brief's fourth guard, *`fontTo` still counts at once*, is 0.3.5's existing "a false from SetFont is
counted (fontTo) (R-F5-5)", re-proved red.

## Zip
`dist/DeadTired-0.3.6.zip`: 187,012 bytes, sha256
`936785bdcf9083857ae980ea42e6cdce8910f11251241e612a461f88f357f676`. `diff -r`: clean.

## What the brief got wrong, or left open
Nothing turned out wrong. One thing to watch: the fix rests on a single probe. If a second touch were ever
refused in the live client, the count would come back, and S6 would say so. That is the point of S6.
