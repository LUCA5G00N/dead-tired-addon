# Cowork report: DEAD TIRED fix round 1 (dt_fixes1)

Brief: `docs/COWORK_BRIEF_dt_fixes1.md`. Walk-sheet: `docs/UAT_dt_fixes1.md`. This report is on
the session branch `claude/busy-allen-rqw4o5` (moved up to `main` at `5c4119a` first; it
carried nothing of its own). The fixes are pushed to each `card/*` branch, as the brief says.

**Result:** every fix F1-F11 is in, each card's `run_all.sh` exits 0, and the audit's tests,
unchanged, pass for AUD-01, 02, 03, 04 and 07. AUD-06 is still red (deferred), and the traffic
simulation is green. S1b (20 logins in 2 s) costs 40 messages, down from 400, and nothing is
dropped in any scenario. Every Task 6 guard went red when removed. No stop condition tripped.

## Branch heads

| Branch | Old head | New head | Commits this round |
|---|---|---|---|
| `card/dt_foundation` | `61fe2d3` | `696dd87` | F1-F5 |
| `card/dt_crypt` | `6d15835` | `f6f97c9` | merge of card 1, then F6a |
| `card/dt_pvp` | `be22a1d` | `b57c6db` | merge of card 1, then F7, F6b |
| `card/dt_prep` | `02d199f` | `6fb903b` | merge of card 1, then F8a, F6c |
| `card/dt_stretch` | `1114f90` | `39e636f` | merge of card 1, then F8b, F6d, F9 |
| `card/dt_logs` | `b413772` | `a871c2b` | merge of card 1, then F10, F11 |
| `card/dt_probe` | `a25b538` | `a25b538` | untouched |
| `audit/2026-11-02` | `33526cc` | `33526cc` | untouched (G6: `git diff origin/audit/2026-11-02 -- audit/` is empty) |

## Baseline (Task 1)

- P1: all six card branches' `run_all.sh` exited 0 at the heads above (core 44, guild 13,
  comms 53, roster 26, alts 21, welcome 17; plus crypt 88, gank 50, prep 42 + recruit 55,
  stash 74 + played 47 + events 26, logs 85).
- P2: `sh audit/tests/run_all.sh` from the `audit/2026-11-02` checkout showed AUD-01, 02, 03,
  04, 06 and 07 red and traffic green, as the audit says.

## Merges of card 1 (Task 3)

`card/dt_foundation` at `696dd87` merged into each of `card/dt_crypt`, `card/dt_pvp`,
`card/dt_prep`, `card/dt_stretch` and `card/dt_logs`: **all five clean** (no conflicts, not even on
`DeadTired.toc` or `tests/run_all.sh`, which card 1 didn't touch this round). After each merge,
card 1's seven module files, `tests/harness.lua` and its six suites were byte-identical to
`card/dt_foundation`, and the branch's `run_all.sh` exited 0 before its own fixes (G5: the
`git diff <old head> --stat` on each card branch lists card 1's files with exactly card 1's
changes: Comms +6, Core 18, Roster 50, harness 36, test_alts 4, test_comms 10, test_core +12,
test_roster +99, and card 1's three docs).

## The fixes, where they landed, and their checks

| Fix | Audit | Where | New / changed checks |
|---|---|---|---|
| F1 session token `s`; reply once per sender session | AUD-01 | `Roster.lua` | roster: reload, second reload, relog, same-session HELLO; token 1-6 digits; no token = 0 |
| F2 one pending reply covers later HELLOs; `comms.repliesSaved` | AUD-05 | `Roster.lua` | roster: wave of 5 within 1 s (at most 2 replies each, all list all); F1 and F2 together +15 |
| F3 `client:reload()`, `client:reboot(uptime)`, `time()` follows the clock, `opts.setup` | AUD-12 | `tests/harness.lua` | used by F1, F7, F8, F9 checks |
| F4 `pcall(def.init)`, counted, events still registered, re-raised | AUD-15 | `Core.lua` | core +3 |
| F5 `msgid` starts at `time() % 100000` | AUD-16 | `Comms.lua` | comms +1 (two chunk checks no longer pin id 1) |
| F6a one received DEATH per sender per 60 s; `crypt.dropped` | AUD-07 | `Crypt.lua` | crypt +5 |
| F7 double-press window in memory; stored `t` is `time()` | AUD-04 | `Gank.lua` | gank +4 (reboot, window, reload); first-log check asserts `t == time()` |
| F6b one received GANK per sender and enemy per 300 s; `gank.dropped` | AUD-07 | `Gank.lua` | gank +4 |
| F8a roll-call id `time() % 1000000` | AUD-02 | `Prep.lua` | prep +3 (reload, reboot) |
| F6c one PREPQ per asker per 60 s answered; `prep.dropped` | AUD-07 | `Prep.lua` | prep +5 |
| F8b search id `time() % 1000000` | AUD-03 | `Stash.lua` | stash +3 (reload, reboot) |
| F6d one STASHQ per asker per 30 s answered; `stash.dropped` | AUD-07 | `Stash.lua` | stash +4 |
| F9 `share off` sends `PLAYED {off=1}`; receivers delete; 30-day drop | AUD-09 | `Played.lua` | played +14; one check reversed (below) |
| F10 an unknown log state is never armed | AUD-11 | `Logs.lua` | logs: 15 new, one check reversed (below) |
| F11 the instance dialog hides when the visit ends | AUD-14 | `Logs.lua` | logs: 6 new |

Final suite counts: core 47, guild 13, comms 54, roster 41, alts 21, welcome 17; crypt 93;
gank 58; prep 50, recruit 55; stash 81, played 61, events 26; logs 106. Each card's own report has
a *Fix round 1* section with the detail; each brief has an *Amended (fix round 1)* note and
marked lines; card 1's wire section shows `s`, and card 1's walk-sheet has G6b (this round's
in-game G7).

**Existing checks changed** (test-side, to state the new behaviour, not to excuse it):
- Card 1: three HELLO text checks now include `s~<token>`; two chunk checks read the id instead
  of pinning `1` (F5).
- Card 3: received-death checks that injected several DEATHs from one sender back to back now use
  a sender each; the 100-cap loop spaces injections 61 s apart (F6a).
- Card 4: stubs moved into `opts.setup` so `reload`/`reboot` keep them; board tests that inject
  one enemy from one sender space injections 301 s apart; the `|`-in-zone check logs a different
  enemy (F6b).
- Card 5 and 6: checks that pinned `q~1`/`q~2` compute the id from the stub clock (F8);
  stash's STASHQ injections from one asker inside 30 s now come from one asker each (F6d).
- Card 6: *"/dt slowest share off: nothing sent"* became *"... no play time sent after it, only
  the one withdrawal (F9)"*. The brief reverses it.
- Card 7: *"unknown state is treated as off: the dialog"* became *"F10: unknown state: no
  dialog, the line instead"*. The brief reverses it.

## Audit tests, before and after (Task 5)

`sh audit/tests/run_all.sh` from the `audit/2026-11-02` checkout, tests unchanged:

| Test | Before (old heads) | After (new heads) |
|---|---|---|
| AUD-01 `test_roster_reload` | red, 3 of 5 fail | **green**, 5 of 5 |
| AUD-02 `test_prep_reload` | red, 1 of 2 fails | **green**, 2 of 2 |
| AUD-03 `test_stash_reload` | red, 1 of 2 fails | **green**, 2 of 2 |
| AUD-04 `test_gank_reboot` | red, 2 of 3 fail | **green**, 3 of 3 |
| AUD-06 `test_realm_spelling` | red, 2 of 2 fail | red, 2 of 2 fail (deferred, as ruled) |
| AUD-07 `test_death_flood` | red, 2 of 2 fail | **green**, 2 of 2 |
| traffic `test_traffic` | green | green |

## Traffic, before and after

| Scenario | Audit (old heads) | Now (new heads) |
|---|---|---|
| S1 20 log in over 2 min | 237 messages; 34, 148, 55 per min; peak queue 0; dropped 0 | **153**; 28, 85, 40 per min; peak queue 0; dropped 0 |
| S1b 20 log in within 2 s | **400** in minute 1; peak queue 10; max delay 9.7 s; dropped 0 | **40** in minute 1; peak queue 0; max delay 0 s; dropped 0 |
| S2 one hour, half sharing | 263 (mean 4.4/min, busiest 32); HELLO 70; dropped 0 | 333 (mean 5.5/min, busiest 32); HELLO 140; dropped 0 |
| S3 raid night, roll call at +90 s | 289; 19 of 19 answers; dropped 0 | **133**; 19 of 19 answers; dropped 0 |
| S4 ten restricted for 10 min | 320; peak queue 16; held 530 s; 9 of 19 answers per roll call; dropped 0 | 320; peak queue 16; held 530 s; 9 of 19; dropped 0 |
| S5 all 20 run `/dt prep check` at once | 400; peak queue 12; worst 10 of 19 | 400; peak queue 12; worst 9 of 19 |

- S1b: 20 login HELLOs plus 20 replies, one per client: each client's single pending reply covers
  the other 19 logins.
- S2's HELLO count rose from 70 to 140 because the hour's 4 `/reload`s are now answered (19 or so
  replies each). Under the old code they got none, which was AUD-01. This is the fix working,
  not new traffic.
- S4 and S5 are unchanged: late answers (AUD-08) are deferred. S5's worst case moved by one
  answer because Roster now takes its session token from the same seeded `math.random` at load,
  which shifts every later draw; it is the same finding.
- The test's S1 line still prints "bounds 190 to 380" for replies; that label describes the
  old reply rule. The test is unchanged by rule, so the label stays.

## Guard proofs (Task 6)

Each guard was removed once with a scripted text substitution, the branch's `run_all.sh` run,
and the file restored. Each suite was green again afterwards.

| # | Guard | Removed as | Red checks |
|---|---|---|---|
| 1 | F1 token in the `answered` key | `local who = from` | 8, incl. *F1: after B reloads, A replies once more*, *F1: after the relog, B's /dt who lists A* |
| 2 | F1 token validation | `or not validToken(f.s)` dropped | 3: *F1: a token that isn't 1-6 digits is refused and counted*, *F1: a HELLO with no token is answered (token 0)*, *F1: ... and is the same session as an explicit s~0* |
| 3 | F2 "one pending reply" | `if replyPending` → `if false` | 2: *F2: in a wave of 5, each client sends at most 2 replies (most 4)*, *F2: replies saved are counted (0)* |
| 4 | F4 `pcall` around `init` | `def.init()` called directly | 2: *F4: and counted under the module's own key*, *F4: its events are registered anyway, and run* |
| 5a | F6a DEATH per sender | `if false then` | 5, incl. *F6a: one sender's 10 DEATHs in 10 s: one notice, one record* |
| 5b | F6b GANK per sender and enemy | `if false then` | 4, incl. *F6b: one sender's 10 GANKs on one enemy inside 300 s keep one* |
| 5c | F6c PREPQ per asker | `if false then` | 5, incl. *F6c: ten roll calls from one asker in 10 s, each with a new id: one answer* |
| 5d | F6d STASHQ per asker | `if false then` | 4, incl. *F6d: ten searches from one asker in 10 s, each with a new id: one answer* |
| 6 | F7 in-memory window | the old loop comparing a stored `t = GetTime()` put back | 5, incl. *F7: after a restart, the same enemy a day later is noted, not 'already noted'* |
| 7a | F8a | `qid = qid + 1` put back | 7, incl. *F8a: after the asker's /reload, the roll call is answered*, *F8a: after a restart too* |
| 7b | F8b | `qid = qid + 1` put back | 9, incl. *F8b: after the asker's /reload, the search is answered*, *F8b: after a restart too* |
| 8a | F9 delete on `off~1` | the delete line removed | 2: *F9: a guildie online deletes B's entry on off~1*, *F9: and B is off A's award* |
| 8b | F9 30-day drop | `if false then b[key] = nil end` | 3: *F9: past 30 days, /dt slowest drops it before printing*, *F9: at load, an entry over 30 days old is dropped*, *F9: at load, an entry with no time is dropped* |
| 9a | F10 "don't arm when unknown", login dialog | `L.plan` back to `~= true` | 7, incl. *F10: ... the combat button is not armed*, *F10: clicking the unarmed combat button switches nothing* |
| 9b | F10 "don't arm when unknown", instance dialog | the unknown branch → `if false` | 6, incl. *F10: entering with the combat log unknown: no dialog, nothing armed* |
| 10 | F11 hide on visit end | the `L.hideInstance()` call removed | 2: *F11: leaving the instance hides it*, *F11: combat over: hidden* |

No guard needed a test strengthened.

## Player-facing lines, new or changed (verbatim)

- Card 6, `/dt slowest share off` (changed; was *"not sharing your /played. Your pace is your
  own."*): `not sharing your /played. Your entry is being withdrawn from guildies' boards.`
- Card 7 (new): `Can't tell if the combat log is on. Type /combatlog if it isn't.`
- Card 7 (new): `Can't tell if the chat log is on. Type /chatlog if it isn't.`

No other line changed.

## Not covered by the brief, and what I chose

1. **The harness clock (F3).** Card 1's harness had `time()` frozen at one value. With F8's
   `time() % 1000000`, two roll calls in one test world would get the same id, and the audit's
   AUD-02/03 tests, which must pass unchanged, would stay red. `reboot` also needs `time()` to
   carry on while `GetTime()` restarts. So `time()` now moves with the world clock
   (`1793833200` at world start, +1 per second). Every existing suite stayed green under it.
2. **The F1 token's fallback.** The harness's `random` option replaces `math.random` with a stub
   that ignores its arguments (it returns `0.5`). The token is accepted only as an integer in
   1..999999; anything else falls back to `time() % 999999 + 1`, so it is never `0` (`0` is the
   "no token" value).
3. **F4 re-raises.** The brief says "counted as handler failures are"; handlers re-raise, so a
   failing `init` is counted, its events registered, and then the error is re-raised. A module
   with no `errorKey` swallows it, as its handlers do.
4. **`reboot` is a login.** `client:reboot(uptime)` fires `PLAYER_ENTERING_WORLD(true, false)`
   (a restart means logging in again), where `reload` fires `(false, true)`. `uptime` defaults to
   600 s.
5. **F7 and `/reload`.** The window lives in memory, so a `/reload` inside 300 s forgets a press
   and a second log can be made. That follows from the ruling; a check states it.
6. **F6 ordering.** Each limit applies after validation (an invalid message is counted as bad and
   doesn't start a window). F6c and F6d apply after the share gate, so with sharing off nothing
   is noted or counted, as before.
7. **F9 details.** `share off` also removes your own entry from your own board. A withdrawal must
   be exactly `off~1` with no `lvl`/`h`; anything else with `off` counts in `badPlayed`. An entry
   with no `t` (only possible from before this round; nobody has any) is dropped at load. If
   `time()` can't be read, nothing is pruned. Guildies offline at the time keep the entry until
   it ages out.
8. **F10 details.** A login that printed the "can't tell" line counts as having covered the
   instance visit, so logging in inside a dungeon with the combat log unknown prints it once, not
   twice. With both logs unknown, both lines print. `/dt logs now` prints the lines and nothing
   more.
9. **F11 details.** A visit that ends in combat hides the dialog when combat ends, unless a visit
   has begun again by then (a corpse run back in), when it stays. A release inside the instance
   ends the visit too, so the unanswered dialog goes; coming back on the corpse run resumes the
   visit without asking, as R5 already had it.
10. **Card 1's walk-sheet.** This round's in-game G7 is added to `docs/UAT_dt_foundation.md` as
    G6b, after G6, so Tim walks it with card 1.

## Stop conditions

None tripped: the baseline held (P1, P2); every merge was clean; no fix needed a card 1 change
from a later branch; no audit test needed editing; every guard removal went red.

`docs/UAT_dt_fixes1_results.md` was not written; walking is Tim's.
