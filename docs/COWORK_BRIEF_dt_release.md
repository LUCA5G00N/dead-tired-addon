# Cowork brief: DEAD TIRED release candidate (combined build, zip, guides)

Read first, in order:
1. `CLAUDE.md`.
2. This brief and its walk-sheet, `docs/UAT_dt_release.md`.
3. `docs/ROADMAP.md` on `claude/loving-meitner-yzdxtn`, section *Merging, when the walks pass*
   (the known conflicts and the order).
4. Each card's report on its branch, for its commands and player-facing lines.

**Draft-status: ratified by Tim 2026-11-02.** Launch is Wed 2026-11-04, 11pm UK; no card has been
walked. This build is **for walking**, not for members yet.

## Origin

The game loads one copy of an addon. Walking seven cards one branch at a time means swapping the
addon folder for Tim and his guildie, late at night. Agreed 2026-11-02: walk card 1 alone, then
walk the rest together on one combined build that is not `main`, and merge each card to `main`
only when its own walk-sheet passes. Guildies will also need to know how to install it and what
it does.

## Precondition

- P1: each branch below exists and its `run_all.sh` exits 0.
- P2: no card branch has moved past the heads you record at the start; if one moves during the
  round, finish on the recorded heads and say so.

## Ratified for this round

- **Q1: the combined branch is `release/0.1.0-rc1`,** cut from `card/dt_foundation`, with card
  branches merged in card order: `card/dt_crypt`, `card/dt_pvp`, `card/dt_prep`,
  `card/dt_stretch`, `card/dt_logs`. It is never merged to `main`; cards reach `main` one by one
  after their walks (ROADMAP rule 2). A later re-cut (after audit fixes) is `-rc2`, and so on.
- **Q2: conflicts are resolved, not designed.** `DeadTired.toc` and `tests/run_all.sh` keep every
  card's lines, in card order (Crypt; Gank; PrepList, Prep, RecruitLines, Recruit; Stash, Played,
  EventsList, Events; Logs). Docs conflicts (`ROADMAP.md`, `CLAUDE.md`) take `main`'s version.
  Any conflict inside a module's code → stop.
- **Q3: the version stays `0.1.0`** in the `.toc` and `DT.VERSION`. The zip name carries `-rc1`.
- **Q4: two zips, built by a script.** `tools/package.sh` (new) builds:
  - `dist/DeadTired-0.1.0-rc1.zip`: the `DeadTired/` folder without `tests/`, so unzipping into
    `Interface\AddOns` gives `Interface\AddOns\DeadTired\DeadTired.toc`;
  - `dist/DeadTiredProbe-0.1.0.zip`: `DeadTiredProbe/` from `card/dt_probe`, without `tests/`.
  Both zips are committed on `release/0.1.0-rc1` so Tim can download them from GitHub.
- **Q5: the guides are written from the combined code,** not from the briefs: every command and
  every quoted line is copied from the code as merged.

## Deliverable

`release/0.1.0-rc1` holds every card merged, a new cross-card suite that passes alongside every
card's own suite, the two zips, and three docs: the guildie guide, the officer guide and a Discord
announcement draft. `run_all.sh` on the branch exits 0, and the zips' contents match the branch.

## Working rules

- Merge, don't rebase. One merge commit per card, in order; run `run_all.sh` after each.
- No module code changes, except what Q2's conflict rule needs (none expected). A test needing a
  code change to pass → stop.
- Guides: short, plain, in the house tone. No promises the code doesn't keep. Each feature says
  **what it shares, with whom, and how to switch it off**. Say plainly the addon is optional and
  that shared lists only show guildies running it.

## Tasks

1. **Record heads** of every card branch and `card/dt_probe`; run each suite (P1).
2. **Cut and merge** per Q1-Q2. Run `run_all.sh` after each merge; record the counts.
3. **Cross-card suite** `DeadTired/tests/test_together.lua`, added to `run_all.sh` last. It loads
   every module in `.toc` order into one client (and into two clients sharing a fake guild
   channel) and checks at least:
   - every module loads, with no error recorded in `DeadTiredDB.errors`;
   - `/dt` and `/dt help` list every verb exactly once; no two modules register the same verb;
   - no two modules use the same top-level `DeadTiredDB` key or comms message kind (list them);
   - a login: exactly one welcome line and nothing else printed (with every opt-in at default);
   - a login with every opt-in switched on: list what prints and what is sent, and check each
     item is one a ruling allows (`CLAUDE.md` *Ruled exceptions*);
   - outside the guild with every opt-in on: nothing printed, nothing sent;
   - every card's commands still answer when all are loaded together.
4. **`tools/package.sh`** and the two zips (Q4). The script runs from the repo root, needs only
   `zip`, and prints each zip's file list. Check: unzip each into a scratch folder and `diff -r`
   against the source folder minus `tests/`.
5. **`docs/GUIDE_guildies.md`:** what DEAD TIRED (the addon) is, that it's optional, how to
   install (download, unzip into `_forever_\Interface\AddOns`, "Load out of date AddOns" if
   needed), then one short section per feature with its commands, what it shares and with whom,
   how to switch it off. End with: how to report a bug (BugSack screenshot to #dt-chat).
6. **`docs/GUIDE_officers.md`:** officer-only things (`/dt recruit`, General channel, cooldown),
   the things officers will be asked about, and the Discord bot's commands from #dt-officers'
   pinned cheat-sheet (copy them from the pin's text in this brief's appendix).
7. **`docs/ANNOUNCE_discord.md`:** a Discord post for #dt-announcements, at most 1,500
   characters: what it is, optional, the three best features, where to download, where the guide
   is. No @everyone.
8. **Push** `release/0.1.0-rc1` (or the session branch, said at the top of the report).
9. **Report** `docs/COWORK_REPORT_dt_release.md` on the release branch.

## Explicitly out of scope

- Merging to `main`, or changing any card branch.
- Fixing anything found while merging (record it; the audit round and its fix round handle fixes).
- A CurseForge, Wago or GitHub Releases listing; an auto-updater.
- Posting the announcement anywhere. It is a draft for Tim.
- Card 2.

## Stop conditions

- A suite fails at baseline (P1) → stop.
- A conflict inside module code, or any merge needing a judgement beyond Q2 → stop.
- The cross-card suite finds a collision (verb, DB key, message kind) → stop and report it; don't
  rename anything.
- Any login prints or sends something no ruling allows → stop.

## UAT: acceptance checks

In `docs/UAT_dt_release.md`.

## Reporting

`docs/COWORK_REPORT_dt_release.md`: the heads merged; each merge's conflicts and how Q2 resolved
them; test counts after each merge; the cross-card suite's lists (verbs, DB keys, message kinds,
what an all-opt-in login prints and sends); each zip's file list and size; anything noticed but
not fixed. Never write a `_results.md` file.

## Appendix: the #dt-officers pin (Discord bot commands), as posted 2026-11-01

```
/promote @member - accepts an applicant. Gives Restless Dead, removes Freshly Risen, and posts a
welcome in #dt-chat. Run it once per person (running it again posts a second welcome).
/decline @member - removes Freshly Risen and DMs them a polite no (they keep PUG access).
/roster - who's in the guild by class and Tank/Healer/DPS, plus anyone who hasn't picked a class.
/create (Raid-Helper) - make a raid or PvP event; use it in #dt-raids. It carries on in your DMs.
Command replies are only visible to you. Making someone a Crypt Keeper is done by hand in Server
Settings > Members (they need Restless Dead too). The bot also posts a reset reminder in #dt-chat
on Tuesday mornings. All replies vanish if the bot's PC is off.
```
