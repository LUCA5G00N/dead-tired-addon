# Cowork brief: DEAD TIRED fix round 2 (two log prompts at once; re-cut rc2)

Read first: `CLAUDE.md`; this brief and `docs/UAT_dt_fixes2.md`; on `release/0.1.0-rc1`,
`docs/COWORK_REPORT_dt_release.md` (*Noticed, not fixed*, item 1) and `tools/package.sh`; on
`card/dt_logs`, `DeadTired/Logs.lua`, its tests and its brief.

**Draft-status: ratified by Tim 2026-11-02.** Heads when written: `card/dt_logs` `a871c2b`,
`release/0.1.0-rc1` `76861bc`. Launch is Wed 2026-11-04, 11pm UK.

## Origin

The release round found that with `/dt logs login on`, an unanswered login prompt can still be
on screen when the player enters a dungeon, and the instance prompt then opens too. Both are armed
with `/combatlog` while the log is off, so clicking the combat log on one and **Log it** on the
other toggles the log back **off**: against `CLAUDE.md`'s "never switching a log off".

## The fix (ratified)

- **F12 (card 7): one logs prompt at a time.** If the login prompt is showing when a dungeon or
  raid visit begins, the instance prompt is not shown, and the visit counts as asked (the login
  prompt already offers the combat log). In the other order (instance prompt up, then a
  `/dt logs now` or a login prompt would show): the instance prompt is hidden first (deferred in
  combat, as the code already defers), so two are never up together.
- **F13 (card 7): re-read before acting.** When any logs button's click runs, every other logs
  dialog still open is hidden (deferred in combat). So even if two were ever up, a second click on
  a stale button can't happen.

## Then re-cut

- `release/0.1.0-rc2` from `release/0.1.0-rc1`, merging the fixed `card/dt_logs`. Bump nothing but
  the zip names: `tools/package.sh` produces `dist/DeadTired-0.1.0-rc2.zip` (and the card-1 and
  probe zips unchanged in content; rebuild them so `dist/` is complete on the new branch). Remove
  the rc1 zip from the rc2 branch.
- Update `docs/LAUNCH_NIGHT.md`, `docs/GUIDE_guildies.md` and `docs/ANNOUNCE_discord.md` where
  they name the rc1 zip. In `test_together.lua`, change the check that states "both prompts shown"
  to assert only one is.
- Tidy the two doc slips the release report noted (its items 3 and 4): the release brief's
  *Deliverable* says "two zips" (make it three), the probe walk-sheet header says "5 offline, 1
  in-game" (make it match its boxes). Do this on the rc2 branch only, and list them in the
  report; the `main` copies are fixed separately.

## Tasks

1. Baseline: `card/dt_logs` and `release/0.1.0-rc1` suites green.
2. F12, F13 on `card/dt_logs`, with checks: login prompt up then dungeon → one prompt, visit
   counted; instance prompt up then login/`now` → one prompt; a click on one hides the other; in
   combat, hides deferred to combat end; the "Combat log then Log it" sequence can no longer
   switch the log off (stub counts `/combatlog` runs: one). Update card 7's brief (amended note)
   and report (*Fix round 2*). Push.
3. Guard proofs: remove each of F12's two rules and F13's hide once; confirm red; restore.
4. Re-cut `release/0.1.0-rc2` as above; `run_all.sh` green; zips rebuilt and checked with
   `diff -r` as before. Push.
5. Report `docs/COWORK_REPORT_dt_fixes2.md` on the rc2 branch.

## Out of scope

Anything else in the logs card; other cards; merging to `main`; where the zip is hosted or the
announcement's links (Tim decides).

## Stop conditions

- A suite red at baseline → stop.
- The fix needs a change outside `Logs.lua` and its tests (bar the rc2 docs above) → stop.
- A guard removal turns nothing red and the fix needs addon code → stop.

## Reporting

Old and new heads; the fix and its checks; guard proofs; zip names, sizes and file lists; every
doc line changed. Never write a `_results.md` file.
