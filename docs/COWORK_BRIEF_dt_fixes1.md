# Cowork brief: DEAD TIRED fix round 1 (audit findings, before launch)

Read first, in order:
1. `CLAUDE.md`.
2. This brief and its walk-sheet, `docs/UAT_dt_fixes1.md`.
3. `docs/AUDIT_2026-11-02.md` and `audit/tests/` on branch `audit/2026-11-02`: the findings, the
   lines they cite, and the reproducing tests. Read the findings named below in full.
4. On each branch you change: that card's brief and report, and the files named.

**Draft-status: ratified by Tim 2026-11-02.** Tim chose the findings and the fixes below from the
audit. Launch is Wed 2026-11-04, 11pm UK. Heads when written: `card/dt_foundation` `61fe2d3`,
`card/dt_crypt` `6d15835`, `card/dt_pvp` `be22a1d`, `card/dt_prep` `02d199f`,
`card/dt_stretch` `1114f90`, `card/dt_logs` `b413772`. If any has moved, re-read before trusting
this brief's line numbers.

## Origin

The independent audit (2026-11-02) found 16 issues, none a rule break or a crash on a normal
path. Four highs share one blind spot: no test modelled another client losing its memory
(`/reload`, PC restart). Three would surface during the launch-night walk. Tim ruled to fix the
highs, the cheap fixes in the same files, and AUD-11, which conflicts with a house rule, now;
AUD-06 and AUD-10 after the probe; AUD-08 and AUD-13 after launch.

## Precondition

- P1: every card branch's `run_all.sh` exits 0 at the heads above.
- P2: `sh audit/tests/run_all.sh` (from a checkout of `audit/2026-11-02`) shows AUD-01, 02, 03,
  04 and 07's tests red, as the audit says.

## Order of work (ROADMAP rules 1 and 5)

1. Fix card 1 on `card/dt_foundation` (F1-F5).
2. Merge `card/dt_foundation` into each of `card/dt_crypt`, `card/dt_pvp`, `card/dt_prep`,
   `card/dt_stretch`, `card/dt_logs`. Each merge must be clean, or touch only `DeadTired.toc` /
   `tests/run_all.sh` lines resolved by keeping both sides. Run that branch's `run_all.sh`
   after the merge, before its own fixes.
3. Fix each card on its own branch (F6-F11).

## The fixes (ratified)

### Card 1 (`card/dt_foundation`)

- **F1 (AUD-01): reply once per sender session.** At load, each client picks a session token,
  `math.random(1, 999999)` (guarded; fall back to `time() % 1000000`). Every HELLO carries it as
  a new field `s`. `answered` is keyed by sender plus token. A HELLO with no `s` (none exist yet,
  but validate) counts as token 0. A HELLO from a known sender with a new token gets one reply,
  as a new sender would. The token is validated as 1-6 digits. `PROTOCOL` stays 1 (the field is
  additive). Update the wire section of card 1's brief and report.
- **F2 (AUD-05): coalesce replies.** A reply is already sent 2-8 s after a new HELLO. If another
  HELLO that needs a reply arrives while one is pending, **don't schedule a second**: the one
  pending reply goes out once, and covers every HELLO received before it is sent (it is a
  broadcast). Record in `comms`/`roster` stats how many replies were saved. **Not** the audit's
  "don't reply if you sent a HELLO in the last 30 s": a newcomer who came online just after your
  own HELLO would never hear you.
- **F3 (AUD-12): the harness learns to forget.** Add `client:reload()` (copy `L.reload` from
  `audit/tests/lib.lua`: old Lua state dropped, new instance on the same SavedVariables,
  `PLAYER_ENTERING_WORLD(false, true)`) and `client:reboot(uptime)` (as `reload`, with
  `GetTime()` restarting at `uptime`, `time()` carrying on) to card 1's `tests/harness.lua`.
  Add to `test_roster.lua`: after B reloads, A replies once and B's `/dt who` lists A; the same
  after a relog; a second reload gets one more reply, not zero and not two; F2's coalescing in a
  wave of 5 logins within 1 s (each client sends at most 2 replies, every client lists every
  other).
- **F4 (AUD-15):** `pcall(def.init)` in `DT.module`; a failure is counted under the module's
  `errorKey` / `lastKey` as handler failures are, and the module's events are registered anyway.
- **F5 (AUD-16):** `msgid` starts at `time() % 100000` (guarded) instead of 0.

### Card 3 (`card/dt_crypt`)

- **F6a (AUD-07):** received DEATH: at most one per sender per 60 s, counted in a new
  `crypt.dropped` when over. Silently: no print.

### Card 4 (`card/dt_pvp`)

- **F7 (AUD-04): the double-press window lives in memory.** A session table
  `lastPress[who] = GetTime()` decides "Already noted" (300 s). Any time stored in `DeadTiredDB`
  uses `time()` (epoch), so stored times survive a restart. Existing stored `t` values: no
  member has data yet, so no migration; a stored `t` that looks like uptime (smaller than
  1,000,000,000) is treated as unknown age where displayed.
- **F6b (AUD-07):** received GANK: at most one per sender and `who` per 300 s, counted in
  `gank.dropped`.

### Card 5 (`card/dt_prep`)

- **F8a (AUD-02):** the question id is `time() % 1000000` (guarded), not a per-session counter.
  Wire and validation unchanged (1-6 digits). The 60 s window already stops two in one second.
- **F6c (AUD-07):** received PREPQ: at most one per asker per 60 s, counted in `prep.dropped`.

### Card 6 (`card/dt_stretch`)

- **F8b (AUD-03):** as F8a for stash searches (`time() % 1000000`; the 30 s window keeps it
  unique).
- **F6d (AUD-07):** received STASHQ: at most one per asker per 30 s, counted in `stash.dropped`.
- **F9 (AUD-09): withdrawing play time.**
  - `/dt slowest share off` sends one `PLAYED` with `off~1` (and nothing else), through card 1's
    queue as usual (held if restricted, never forced).
  - A receiver deletes that sender's entry on `off~1`.
  - Entries record `time()` when received; entries older than 30 days are dropped at load and
    whenever `/dt slowest` prints.
  - The share-off line says the board entries are being withdrawn. Keep it short and in tone.

### Card 7 (`card/dt_logs`)

- **F10 (AUD-11): unknown means don't arm.** When the combat log's state can't be read:
  - the instance dialog does **not** show; instead one line, once per visit (and not after
    `/dt logs off`): `Can't tell if the combat log is on. Type /combatlog if it isn't.`;
  - the login dialog shows `?` for that log (as now) but **does not arm** its button, or **Both**;
    if no log can be armed, it doesn't show and prints the same line instead (with `/chatlog`
    named if it's the chat log that's unknown).
  - Update the card's *Ruled exceptions* line? No: `CLAUDE.md` already says "never switching a
    log off"; this makes the code keep it.
- **F11 (AUD-14): the dialog leaves with you.** When the visit ends, hide the instance dialog
  (deferred to combat end if in combat, as the code already defers). **Escape is not added**: the
  dialog parents secure buttons, so hiding it through `UISpecialFrames` in combat would be
  blocked. **Not now** stays the way to close it.

## Deliverable

Every branch above carries its fixes, each card's `run_all.sh` exits 0, and the audit's
reproducing tests for AUD-01, 02, 03, 04 and 07 pass **unchanged** against the new heads.
AUD-06's test stays red (deferred). The traffic simulation still drops nothing, and its S1b login
wave sends far fewer than 400 messages.

## Working rules

- Fixes only: no new features, no rewording beyond the lines named.
- Every fix gets offline checks in the card's own suite (using F3's `reload`/`reboot` where the
  finding is about forgetting) in addition to the audit's tests.
- Update each card's brief (an *Amended 2026-11-02 (fix round 1)* note, changed lines marked)
  and append *Fix round 1* to each card's report. Card 1's wire section shows the new `s` field.
- Guarded reads and the house helpers everywhere, as before.

## Tasks

1. **Baseline** (P1, P2). Check out `audit/2026-11-02` into a scratch worktree for its tests.
2. **Card 1:** F1-F5, tests, docs. Push `card/dt_foundation`.
3. **Merge** card 1 into the five card branches (order of work, step 2); run each suite.
4. **Cards 3-7:** F6-F11, tests, docs, in card order. Push each.
5. **Audit tests:** from the audit worktree, `sh audit/tests/run_all.sh` against the pushed heads.
   AUD-01, 02, 03, 04, 07 green; AUD-06 red; traffic green. Record S1b's message count and S1-S5
   in a table beside the audit's numbers.
6. **Guard proofs.** Remove once, confirm red, restore:
   1. F1's token in the `answered` key;
   2. F1's token validation;
   3. F2's "one pending reply" check;
   4. F4's `pcall` around `init`;
   5. F6a, F6b, F6c, F6d's per-sender limits (each);
   6. F7's in-memory window (put the stored-time comparison back: the reboot check goes red);
   7. F8a and F8b (put the counter back: the reload checks go red);
   8. F9's delete on `off~1`; F9's 30-day drop;
   9. F10's "don't arm when unknown" (both dialogs);
   10. F11's hide on visit end.
7. **Report:** `docs/COWORK_REPORT_dt_fixes1.md` on your session branch (below). Push.

## Explicitly out of scope

- AUD-06 (connected-realm keys), AUD-10 (send result), AUD-08 (late answers), AUD-13 (secret
  stub): deferred by Tim.
- Changing `PROTOCOL`, the throttle numbers, the queue cap, or any wire field other than F1's `s`
  and F9's `off`.
- The release build (`dt_release`): it runs after this round, from the fixed branches.
- Merging anything to `main`; changing `audit/2026-11-02` or `card/dt_probe`.

## Stop conditions

- A suite red at baseline, or an audit test not red at baseline (P1, P2) → stop.
- Merging card 1 into a card branch conflicts inside module code → stop.
- A fix needs a card 1 change from a later card's branch (ROADMAP rule 5) → stop.
- An audit test needs editing to pass → stop: the fix is wrong, or the test is, and Tim decides.
- A guard removal turns nothing red and the fix needs addon code → stop (`CLAUDE.md`'s test-only
  exception applies otherwise).

## UAT: acceptance checks

In `docs/UAT_dt_fixes1.md`. The in-game effect is walked on each card's own sheet; this round
adds one in-game step to card 1's (below).

## Reporting

`docs/COWORK_REPORT_dt_fixes1.md`: old and new head per branch; each fix, where it landed, and
its new checks; each merge of card 1 (clean or which lines); the audit tests before and after; the
traffic table before and after; every guard removal and its red check; every new or changed
player-facing line verbatim; anything the brief didn't cover and what you chose. Never write a
`_results.md` file.
