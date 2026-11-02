# Cowork report: DEAD TIRED fix round 2 (dt_fixes2)

Brief: `docs/COWORK_BRIEF_dt_fixes2.md` (on `main` at `a7821f8`). Walk-sheet: `docs/UAT_dt_fixes2.md`.
This report is on `release/0.1.0-rc2`.

**Result:** F12 and F13 are on `card/dt_logs`. With them, two logs prompts are never up together,
and "Combat log, then Log it" runs `/combatlog` once, so it can no longer switch the log off.
`release/0.1.0-rc2` is re-cut from rc1 with the fixed card merged. Every suite passes (15, 766
checks). `dist/` holds the rc2, card-1 and probe zips and no rc1 zip, and each matches its
source. No stop condition tripped. Nothing outside `Logs.lua` and its tests changed in addon code.

## Heads

| Branch | Old head | New head |
|---|---|---|
| `card/dt_logs` | `a871c2b` | `2558f4c` |
| `release/0.1.0-rc1` | `76861bc` | `76861bc` (untouched) |
| `release/0.1.0-rc2` | (new, from rc1 `76861bc`) | the commit adding this report (merge `d3d951b`, rc2 changes `579072f`) |

No other branch changed. `card/dt_foundation`, `dt_crypt`, `dt_pvp`, `dt_prep`, `dt_stretch` and
`dt_probe` are where fix round 1 and the release round left them.

## Baseline (Task 1)

`card/dt_logs` at `a871c2b`: `run_all.sh` exit 0 (logs 106). `release/0.1.0-rc1` at `76861bc`:
exit 0 (15 suites, together 27).

## The fix (Task 2), `card/dt_logs`, `DeadTired/Logs.lua` only

- **F12, one prompt at a time.**
  - `L.askInstance` returns `"covered"` and shows nothing while the login prompt is on screen,
    or is waiting for combat to end (a pending login show). The visit is already recorded when
    this runs, so it counts as asked: no prompt later in that visit; the next visit asks as usual.
  - `L.showLogin`, about to show the login prompt, first hides an instance prompt that is up. It
    only gets that far out of combat: in combat the show is deferred (as before), and the hide
    happens when the deferred show runs at combat end.
- **F13, a click hides the others.** `finish()`, which every logs button's click runs, hides the
  clicked prompt and, out of combat, every other open logs prompt. In combat the existing
  `pendingHide` already hides every logs prompt when combat ends.
- No player-facing line changed.

**New checks (16; logs 106 → 122):**
- F12: login prompt up, then a dungeon: one prompt, no instance prompt shown; the visit counts as
  asked (no prompt after a zone change or loading screen inside); a new visit asks.
- F12: login prompt deferred by combat, a dungeon entered meanwhile: after combat, one prompt
  (the login one).
- F12: instance prompt up, then `/dt logs now`: only the login prompt. The same in combat: no
  error, nothing moves until combat ends, then the instance prompt is hidden and the login prompt
  shown.
- F13 (both prompts forced up, since F12 prevents it): a click on the login prompt hides the
  instance prompt, so **Log it** can't be pressed afterwards (one `/combatlog` run, the log on).
  In combat: the hides wait; after combat both are hidden.
- The release round's sequence, both ways round (login prompt, walk in, **Combat log** then
  **Log it**; instance prompt, `/dt logs now`, then both buttons): **one `/combatlog` run, the
  log stays on.** The test's `press()` counts `/combatlog` runs and refuses a button on a prompt
  that isn't on screen, as the game does.

Card 7's brief has an *Amended (fix round 2)* note and a marked paragraph; its report has *Fix
round 2*; its walk-sheet gains **G9b** (this round's in-game G5), so it now has 11 checks.

## Guard proofs (Task 3)

Each was removed once, `run_all.sh` run on `card/dt_logs`, and the file restored. The suite was
green again afterwards.

| Guard | Removed as | Red |
|---|---|---|
| F12 rule 1: an open or pending login prompt covers the visit | `if false then` | 4: *F12: walking into a dungeon with the login prompt up: no second prompt*, *F12: the visit counts as asked: no prompt later in the same visit*, *F12: a new visit asks as usual*, *F12: a deferred login prompt covers a dungeon entered meanwhile: one prompt* |
| F12 rule 2: the login prompt hides an instance prompt first | the hide removed | 2: *F12: /dt logs now with the instance prompt up: only the login prompt*, *F12: combat over: the instance prompt hidden, then the login prompt shown* |
| F13: a click hides the others | the loop removed | 2: *F13: a click on the login prompt hides the instance prompt too*, *F13: ... so Log it can't be pressed after Combat log: one /combatlog run, the log on* |

With only F12 rule 1 removed, the end-to-end "Combat log then Log it" check stays green, because
F13 alone also stops the second click: each layer holds by itself, and each has its own red check.

## Re-cut: `release/0.1.0-rc2` (Task 4)

- Branched from `release/0.1.0-rc1` (`76861bc`); merged `card/dt_logs` (`2558f4c`): **clean**,
  touching `Logs.lua`, `test_logs.lua` and card 7's three docs only.
- `run_all.sh`: core 47, guild 13, comms 54, roster 41, alts 21, welcome 17, crypt 93, gank 58,
  prep 50, recruit 55, stash 81, played 61, events 26, logs 122, together 27: exit 0 (766).
- `test_together.lua`: the check that stated both prompts showing now reads *"all opt-ins on:
  entering a dungeon with the login prompt still up: still only that one prompt"* and asserts
  exactly one (`DeadTiredLogsLogin`). Its all-opt-in listing now prints *after entering a
  dungeon: DeadTiredLogsLogin*.
- Version unchanged (`0.1.0` in the `.toc` and `DT.VERSION`); only the zip name changed.

### Zips

`tools/package.sh` now builds `dist/DeadTired-0.1.0-rc2.zip`. The rc1 zip was removed from this
branch (it stays on `release/0.1.0-rc1`). All three were rebuilt and committed, then checked from
the commit: unzipped and `diff -r` against their sources minus `tests/` showed no differences,
and none contains `tests/`.

| Zip | Source | Size | Files |
|---|---|---|---|
| `dist/DeadTired-0.1.0-rc2.zip` | this branch's `DeadTired/` | 42,096 bytes | 19: `DeadTired.toc`, `Config`, `Core`, `Guild`, `Comms`, `Roster`, `Alts`, `Welcome`, `Crypt`, `Gank`, `PrepList`, `Prep`, `RecruitLines`, `Recruit`, `Stash`, `Played`, `EventsList`, `Events`, `Logs` (`.lua`) |
| `dist/DeadTired-0.1.0-card1.zip` | `card/dt_foundation` `696dd87` | 13,185 bytes | 8: `DeadTired.toc`, `Config`, `Core`, `Guild`, `Comms`, `Roster`, `Alts`, `Welcome` (`.lua`) |
| `dist/DeadTiredProbe-0.1.0.zip` | `card/dt_probe` `a25b538` | 13,087 bytes | 2: `DeadTiredProbe.toc`, `Probe.lua` |

The card-1 and probe zips have the same content and size as on rc1; only their timestamps differ.

## Every doc line changed on rc2 (besides card 7's own docs, above)

- `tools/package.sh`: the header comment and the build line name `DeadTired-0.1.0-rc2.zip`.
- `docs/LAUNCH_NIGHT.md`:
  - `release/0.1.0-rc1` → `release/0.1.0-rc2` (opening line);
  - step 3's zip `dist/DeadTired-0.1.0-rc1.zip` → `dist/DeadTired-0.1.0-rc2.zip`, and "Swap to the
    `-rc1` zip" → "`-rc2` zip";
  - logs' row `10 (G5-G9, H1)` → `11 (G5-G9 with **G9b**, H1)`;
  - the dungeon-entrance batch adds G9b: *"logs G6, G7, G9 and G9b (fix round 2: log in at the
    entrance with `/dt logs login on`, leave the login prompt, walk in: one prompt)"*.
- `docs/GUIDE_guildies.md`: "release candidate **0.1.0-rc1**" → "**0.1.0-rc2**"; "Download
  `DeadTired-0.1.0-rc1.zip`" → "`DeadTired-0.1.0-rc2.zip`".
- `docs/ANNOUNCE_discord.md`: `<link to DeadTired-0.1.0-rc1.zip>` → `<link to DeadTired-0.1.0-rc2.zip>`.
  The post is still 1,205 characters (the file 1,354), with no @everyone.
- **G4:** `grep -rn "rc1" docs/LAUNCH_NIGHT.md docs/GUIDE_guildies.md docs/ANNOUNCE_discord.md`
  finds nothing.
- **The two slips (release report items 3 and 4), on this branch only:**
  - `docs/COWORK_BRIEF_dt_release.md` was not on the release branches. It is added here as
    `main`'s already-corrected copy (`a7821f8`: *Deliverable* names three zips).
  - `docs/UAT_dt_probe.md`'s header: "Checks: 5 offline, 1 in-game run." → "Checks: 5 offline,
    1 in-game run (6 boxes).", matching `main`'s wording.

`docs/COWORK_REPORT_dt_release.md` on this branch is left as the release round wrote it (it
describes rc1).

## Choices the brief didn't cover

- **A pending login prompt counts as up.** A login prompt deferred by combat is not on screen yet,
  but it will show when combat ends; treating it as covering the visit keeps "one at a time"
  across the deferral (a check covers it).
- **The release brief on rc2.** The brief asked for its *Deliverable* line to be fixed on the rc2
  branch, but the file only lived on `main`, where it was already fixed. Copying `main`'s copy gave
  the same text on both.

`docs/UAT_dt_fixes2_results.md` was not written; walking is Tim's.
