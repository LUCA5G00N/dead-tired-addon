# Cowork brief: DEAD TIRED Port 2 (cards 4, 6, 7; Port 1 fixes; release 0.3.0)

Read first, in order:
1. `CLAUDE.md` on `main` (two lines amended with this brief: *Played* and *Escape*, below).
2. This brief and its walk-sheet, `docs/UAT_dt_port2.md`.
3. `docs/FEATURES.md` (*General requirements*, *Versions and releases*, the port rule on
   `UnitFullName`) and `docs/UAT_dt_port1_results.md` (*Defects and requests*: all in this round).
4. The addon on `main` (0.2.0): build on its modules, settings cards, verbs, viewports, lists, bar
   objects and comms. Don't change a framework contract except where a task says so.
5. For the features being ported (logic and rulings, read-only): on `release/0.1.0-rc3`,
   `DeadTired/Gank.lua`, `Played.lua`, `Stash.lua`, `Events.lua`, `EventsList.lua`, `Logs.lua` and
   their tests; the ratified briefs `docs/COWORK_BRIEF_dt_pvp.md` (card 4), `COWORK_BRIEF_dt_stretch.md`
   (card 6), `COWORK_BRIEF_dt_logs.md` (card 7), `COWORK_BRIEF_dt_rulings.md`, `COWORK_BRIEF_dt_fixes3.md`.

**Draft-status: ratified by Tim 2026-11-11** (scope: all of cards 4, 6 and 7 stay in; card 4 as
ruled, no bounty groundwork; `/dt played`; Escape via UISpecialFrames; chosen in the 11 Nov session).
`main` head when written: `c760793`.

## Origin
0.2.0 (Port 1) shipped on 11 Nov. Port 2 moves the rest of rc3's cards onto the framework, fixes
what the Port 1 walk found, and ships **0.3.0**.

## Rulings in force
Carried unchanged from the ratified card briefs (see `CLAUDE.md` *Ruled exceptions*): card 4 reads
the target's name, realm, class and level only on `/dt gank`, and a gank log shares without a
separate opt-in; card 6's stash shares only items known to be unbound, opt-in; play time shared
only when the player asks, withdrawn when sharing is off (entries dropped after 30 days); event
reminders print once switched on; card 7's logs prompt on entering a party/raid instance with the
combat log off, switched only by the player's click on a secure button running `/combatlog` or
`/chatlog`, never switched off, never `LoggingCombat(arg)`, one prompt at a time; `/dt logs login on`
offers both logs at login.
New, 11 Nov:
- **R-P2-1 `/dt played`:** play time is recorded and (with `/dt slowest share on`) shared only after
  the player types `/dt played`, which calls `RequestTimePlayed()` (guarded) and takes the next
  `TIME_PLAYED_MSG` within 10 s. A plain `/played`, or any other `TIME_PLAYED_MSG`, is ignored. **No
  hook on any Blizzard function** (replaces rc3's `hooksecurefunc` on `SlashCmdList.PLAYED`).
- **R-P2-2 Escape closes panes:** every DT viewport (Who, settings, graveyard, gank board, stash,
  slowest board, events, prep) closes on Escape by `table.insert(UISpecialFrames, <DT frame name>)`
  at creation. DT inserts only its own frame names; never removes, reorders or replaces anything in
  that table. A pane may opt out (`sticky = true`); none do in this round. The taint scan allows
  exactly this call and nothing else on Blizzard tables.
- **Card 4 exactly as ruled** (no bounty-board groundwork; that round extends it).

## Deliverable
On a branch from `main` (the session's own branch is fine), DeadTired **0.3.0** with:

| Module | What |
|---|---|
| **Gank** (card 4) | `/dt gank` with an enemy player targeted logs name, realm, class, level, zone, time, and shares it; a gank board viewport (searchable; most frequent gankers first); rc3's verbs and lines |
| **Played** (card 6) | R-P2-1; the slowest-leveller board (hours per level, from guildies who share); `/dt slowest`, `/dt slowest share on|off` |
| **Stash** (card 6) | Opt-in sharing of unbound items; `/dt stash <item>` asks who has it; rc3's rules (unbound only, opt-in, withdrawn when off) |
| **Events** (card 6) | Reminders once switched on; `/dt events`, `/dt events remind on|off`; `EventsList.lua` as rc3 |
| **Logs** (card 7) | The dungeon/raid prompt and `/dt logs login on|off`, `/dt logs now`, `/dt logs off` as rc3; secure buttons are DT's own frames |
| **Legacy migration** | Cards 4 and 6 data from `DeadTiredDB.legacy` (gank log, stash opt-in, played/slowest board, event settings, logs settings), once (`migrated.port2 = true`), keys by Port 1's rule; `legacy` untouched |
| **Port 1 fixes** | (1) `/dt recruit nudge off` then `on` keeps or re-arms a pending nudge (if a post's cooldown is still running, the nudge still comes once); (2) the bar list shows each object's **name** (its registered name or label), not its live text; (3) a grab-hand cursor while dragging a bar-list row (optional: skip with a note if the client lacks the cursor); (4) the graveyard date column fits on one line (`11-10` or `10 Nov`, full date in the tooltip); (5) R-P2-2 |
| **Version** | `0.3.0`; `dist/DeadTired-0.3.0.zip`; draft `docs/RELEASE_0.3.0.md` |

## Tasks
1. **Baseline:** `main`'s suites green; record counts.
2. **Port 1 fixes** with tests (nudge re-arm, bar labels from names, date format, Escape registration
   model; the taint scan updated for R-P2-2 with a check that any other `UISpecialFrames` use, or any
   removal from it, goes red).
3. **Gank**, **Played (R-P2-1)**, **Stash**, **Events**, **Logs**: port each from rc3 onto
   `DT.module`, settings as cards with typed paths (or `noVerb`), rc3's checks carried over and
   re-pointed to full-name keys; every rc3 player-facing line unchanged.
4. **Legacy migration** for these cards, with a fixture from rc3's shapes.
5. **Guard proofs** (remove once, a check goes red, restore): gank reads the target only on the
   verb; stash shares only unbound items; stash opt-in; played shares only after `/dt played` (a plain
   `TIME_PLAYED_MSG` is ignored); played withdrawn when sharing off; the 30-day drop; events print only
   once switched on; logs never switch a log off; logs one prompt at a time; logs never in a
   battleground/arena/open world; the nudge re-arm; UISpecialFrames insert-only; migration run-once;
   plus every Port 1 guard still proved.
6. **Package** `dist/DeadTired-0.3.0.zip`; `diff -r`; `run_all.sh` green.
7. **Release notes** `docs/RELEASE_0.3.0.md` (draft, DT's voice, short; what's new since 0.2.0).
8. **Report** `docs/COWORK_REPORT_dt_port2.md`.

## Working rules
- rc3's ratified lines for ported features, unchanged; new lines only where this brief gives them;
  any other line you need goes in the report as a question.
- Never read a realm from `UnitFullName`. `reference/` and rc3 are read-only.

## Out of scope
The bounty board, armory and every later round in FEATURES.md; card 2; publishing; CurseForge/Wago.

## Stop conditions
- A ported feature's ratified behaviour can't be kept on the framework without changing a framework
  contract → stop and report the conflict.
- Logs' secure buttons can't be built without touching a Blizzard frame or table other than via the
  client's own `/combatlog`/`/chatlog` macro text → stop.
- The migration would delete or overwrite data it can't merge → stop.
- A guard removal turns nothing red: strengthen the test (test files only); if that needs addon code → stop.

## Reporting
Old/new heads; per module: what was ported (and what changed), checks and counts; guard proofs;
migration on the fixture; every player-facing line added or carried; zip name, size, file list.
Never write a `_results.md` file.
