# Cowork report: DEAD TIRED release candidate 0.1.0-rc1 (dt_release)

Brief: `docs/COWORK_BRIEF_dt_release.md` (as amended after fix round 1, on `main` at `d8dbb10`).
Walk-sheet: `docs/UAT_dt_release.md`. Branch: **`release/0.1.0-rc1`**, pushed. It is for walking,
and is never merged to `main` (Q1).

**Result:** all five card branches are merged into a cut of `card/dt_foundation`, with conflicts
only in the places Q2 rules on. Every suite passes, plus the new cross-card suite `together`
(15 suites, 750 checks). The three zips are built by `tools/package.sh`, committed, and match
their sources. The guildie guide, the officer guide, the launch-night running order and the
Discord draft are written from the merged code. No collision was found (verb, DB key or message
kind), and no login prints or sends anything a ruling doesn't allow. No stop condition tripped.
One cross-card behaviour is noted below, not fixed (out of scope).

## Heads merged (P1, P2)

| Branch | Head | Suite at baseline |
|---|---|---|
| `card/dt_foundation` (the cut) | `696dd87` | exit 0 |
| `card/dt_crypt` | `f6f97c9` | exit 0 |
| `card/dt_pvp` | `b57c6db` | exit 0 |
| `card/dt_prep` | `6fb903b` | exit 0 |
| `card/dt_stretch` | `39e636f` | exit 0 |
| `card/dt_logs` | `a871c2b` | exit 0 |
| `card/dt_probe` (zip only, not merged) | `a25b538` | probe 153, exit 0 |

All were the brief's heads, and none moved during the round. No card branch was changed.

## Merges (Q1, Q2), one commit each, in card order

| Merge | Commit | Conflicts | Resolved as | `run_all.sh` after |
|---|---|---|---|---|
| `card/dt_crypt` | `5ab4de5` | none | - | 7 suites, exit 0 (core 47, guild 13, comms 54, roster 41, alts 21, welcome 17, crypt 93) |
| `card/dt_pvp` | `9611ea4` | `DeadTired.toc`, `tests/run_all.sh` | both sides kept, card order (Crypt, Gank) | 8 suites, exit 0 (+ gank 58) |
| `card/dt_prep` | `ec720c1` | `DeadTired.toc`, `tests/run_all.sh` | both kept (+ PrepList, Prep, RecruitLines, Recruit) | 10 suites, exit 0 (+ prep 50, recruit 55) |
| `card/dt_stretch` | `284a78c` | `DeadTired.toc`, `tests/run_all.sh` | both kept (+ Stash, Played, EventsList, Events) | 13 suites, exit 0 (+ stash 81, played 61, events 26) |
| `card/dt_logs` | `e955ce2` | `DeadTired.toc`, `tests/run_all.sh`, `CLAUDE.md` | toc/run_all: both kept (+ Logs); `CLAUDE.md`: `main`'s version | 14 suites, exit 0 (+ logs 106) |

- No conflict inside module code or a test harness. Every module file and every card suite is
  byte-identical to its own card branch, and card 1's files to `card/dt_foundation` (checked file
  by file).
- `CLAUDE.md` and `docs/ROADMAP.md` on the branch equal `main`'s. The only `CLAUDE.md` conflict
  (logs) took `main`'s; `card/dt_crypt` had brought the rulings-round copy earlier without a
  conflict, and the logs resolution replaced it with `main`'s. No other docs conflicted.
- **G2:** `DeadTired.toc` lists `Config, Core, Guild, Comms, Roster, Alts, Welcome, Crypt, Gank,
  PrepList, Prep, RecruitLines, Recruit, Stash, Played, EventsList, Events, Logs` (`.lua`), each
  once. `tests/run_all.sh`: `core guild comms roster alts welcome crypt gank prep recruit stash
  played events logs together`.
- **G5:** `git diff main --stat -- DeadTired/` lists 36 files, exactly the union of the six card
  branches' `DeadTired/` files plus `tests/test_together.lua` (no file on one side only).
- Version stays `0.1.0` in the `.toc` and `DT.VERSION` (Q3).

## Cross-card suite: `DeadTired/tests/test_together.lua` (Task 3), 27 checks

It reads the `.toc` and loads every module in that order into one client, and into two clients on
card 1's fake guild channel. It is last in `run_all.sh`. **Final `run_all.sh`:** core 47,
guild 13, comms 54, roster 41, alts 21, welcome 17, crypt 93, gank 58, prep 50, recruit 55,
stash 81, played 61, events 26, logs 106, together 27, all green.

It can fail: with a temporary second `DT.verb("who", …)` appended to `Logs.lua` (reverted at
once), 3 checks went red: *no two modules register the same verb (who)*, *every card's commands
still answer together (failed: who)*, *two clients: each lists the other*.

**Verbs (15, each registered by one module):** `alts`, `bedtime`, `events`, `gank`, `ganks`,
`graveyard`, `logs`, `main`, `prep`, `recruit`, `rip`, `slowest`, `stash`, `welcome`, `who`.
`/dt` and `/dt help` each print one line listing all 15 once:

```
0.1.0, still twitching. /dt alts [name] | bedtime HH:MM/off | events [remind on/off] | gank | ganks [name] | graveyard | logs on/off/login/now | main [clear] | prep [list/check/share on/off] | recruit [next] | rip [share] on/off | slowest [share on/off] | stash [item/share on/off] | welcome on/off | who
```

**Top-level `DeadTiredDB` keys (12, none shared across cards):** `account`, `comms`, `errors`,
`roster`, `welcome` (card 1); `crypt` (3); `gank` (4); `prep` (5; `Recruit.lua` keeps its cooldown
in it, same card); `stash`, `played`, `events` (6); `logs` (7).

**Message kinds (8, none shared across cards):** `HELLO` (1); `DEATH` (3); `GANK` (4); `PREPQ`,
`PREP` (5); `STASHQ`, `STASH`, `PLAYED` (6). Card 7 sends nothing.

**A login, every opt-in at default:** one line, *Rest in Pieces, Stromham. The crypt's open. /dt
for the rest.*; no dialog; one message sent, `HELLO`. No error in `DeadTiredDB.errors`.

**A login, every opt-in on** (welcome, `rip`, `rip share`, bedtime 23:00 with the clock at 23:00,
prep, stash and slowest sharing, event reminders with the server clock at Sunday 13:45, logs
asking and login asking), waiting 2 minutes, then entering a dungeon:

| What | Ruling |
|---|---|
| printed *Rest in Pieces, Stromham. The crypt's open. /dt for the rest.* | welcome (card 1, base rule) |
| printed *It's 23:00. Even the dead sleep.* | bedtime nag (card 3) |
| printed *Stranglethorn Fishing Extravaganza in 14 minutes. Bring a rod, or a grudge.* | event reminders (card 6 R4) |
| showed the login prompt (`DeadTiredLogsLogin`) | card 7 R2 (opt-in) |
| on entering the dungeon, showed the instance prompt (`DeadTiredLogsInstance`) | card 7 R1 |
| sent `HELLO`, nothing else | card 1 |

**Outside the guild, every opt-in on**, an hour, a dungeon, a death, a typed `/played`, a bag
update: nothing printed, nothing sent, no dialog.

**Two clients:** each lists the other in `/dt who`; a shared death prints one notice on the other;
a roll call is answered; no error recorded on either.

**Every card's commands answer together:** `who`, `main`, `alts`, `welcome`, `rip`,
`graveyard`, `bedtime`, `gank`, `ganks`, `prep`, `prep list`, `recruit`, `recruit next`, `stash`,
`slowest`, `events`, `logs`, each giving its own card's reply.

## Zips (Q4, Task 4): `tools/package.sh`

Run from the repo root: `sh tools/package.sh`. It needs `zip`, plus `git` to read the card-1 and
probe folders from their branches (`CARD1_REF` and `PROBE_REF` override the refs). It prints each
zip's file list. Each zip unzips to `Interface\AddOns\<Folder>\<Folder>.toc`.

| Zip | Source | Size | Files |
|---|---|---|---|
| `dist/DeadTired-0.1.0-rc1.zip` | this branch's `DeadTired/` | 41,681 bytes | 19: `DeadTired.toc` and the 18 `.lua` above |
| `dist/DeadTired-0.1.0-card1.zip` | `card/dt_foundation` `696dd87` | 13,185 bytes | 8: `DeadTired.toc`, `Config`, `Core`, `Guild`, `Comms`, `Roster`, `Alts`, `Welcome` (`.lua`) |
| `dist/DeadTiredProbe-0.1.0.zip` | `card/dt_probe` `a25b538` | 13,087 bytes | 2: `DeadTiredProbe.toc`, `Probe.lua` |

**G4:** each committed zip was unzipped into a scratch folder and `diff -r` against its source
folder (from `git archive` of its ref) minus `tests/`: no differences. None contains a `tests/`
entry.

## Docs (Tasks 5-8)

- `docs/GUIDE_guildies.md`: what it is, optional, install, a "what it shares" table, then one
  section per feature with commands, what it shares and with whom, and how to switch it off;
  what it prints unasked; bugs to #dt-chat via BugSack. Nothing about connected realms.
- `docs/GUIDE_officers.md`: `/dt recruit` (officer flag, General, 15-minute per-account cooldown,
  rotation, every refusal line, the five lines as posted), the questions members will ask, and the
  #dt-officers bot pin copied verbatim from the brief's appendix.
- `docs/LAUNCH_NIGHT.md`: the four steps, each naming its zip in `dist/` and its walk-sheet in
  `docs/` with its check count (probe 6, foundation 11, crypt 12, pvp 12, prep 13, stretch 13,
  logs 10), and the checks batched by what they need (solo, a guildie, two guildies, officer and
  General, an Alliance player, a dungeon, a battleground, a file edit, a hardcore realm). The
  guild-not-formed fallback is in the brief's words.
- `docs/ANNOUNCE_discord.md`: the post is 1,205 characters (the whole file 1,354), no
  @everyone, with two `<link>` placeholders for Tim (where the zip and the guide will live isn't
  known to this session).
- `docs/UAT_dt_probe.md`: copied from `card/dt_probe` (the probe isn't merged) so every
  walk-sheet the running order names is on this branch.
- **G6:** every `/dt` command named in the two guides, the announcement and the running order (44
  distinct commands, placeholders filled with a name or `linen`) was run through a member client
  on this build. Each gave its own reply; none fell through to the help line or a usage line.
  Every player-facing line the guides quote was copied from the merged code.

## Noticed, not fixed (out of scope; for a later round)

1. **Two logs prompts can be open at once.** With `/dt logs login on`, an unanswered login prompt
   is still on screen when the player enters a dungeon, and the instance prompt opens at the same
   position. Both were armed with `/combatlog` while the log was off. Clicking **Combat log** on
   one and then **Log it** on the other toggles the combat log back **off**, against `CLAUDE.md`'s
   "never switching a log off". Needs both prompts left open and both clicked. A fix: hide (or
   re-arm) the login prompt when the instance prompt shows, or don't show the instance prompt
   while the login prompt is up. `test_together.lua` states the current behaviour (both shown).
2. **Combined-build greps.** Cards 1, 3 and 4's walk-sheets grep `DeadTired/` for
   `SendChatMessage`; on this build they find card 5's one ruled call site in `Recruit.lua`, as
   ROADMAP says. `LAUNCH_NIGHT.md` says so. Those offline checks belong to each card branch.
3. **The brief says "the two zips"** under *Deliverable* and three under Q4; three were built (Q4).
4. **The probe walk-sheet's header** says "5 offline, 1 in-game" and has 6 boxes; the running
   order counts 6.
5. **The Fishing Extravaganza time** in the guide is the code's (Sunday 14:00-16:00 server time,
   the classic schedule); the guide says it's being checked on launch night (stretch G9).

## Choices the brief didn't cover

- `CLAUDE.md` and ROADMAP: Q2 rules on docs *conflicts*. The only conflict took `main`'s version,
  and both files ended equal to `main`, so no separate docs commit was needed.
- The cross-card suite's verb, key and kind lists come from reading each module's code (comments
  stripped) and from the live router, so an overwritten verb shows up as well as a duplicate.
- `tools/package.sh` reads the card-1 and probe folders from their branch refs, so it needs `git`
  as well as `zip`; the rc1 zip comes from the checkout.

`docs/UAT_dt_release_results.md` was not written; walking is Tim's.
