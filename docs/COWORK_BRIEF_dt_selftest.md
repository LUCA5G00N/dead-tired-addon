# Cowork brief: the self-test and the pretend guildie (U1 + U2, 0.3.5)

You are in `LUCA5G00N/dead-tired-addon`, building in a cloud session; Tim walks the result in game.
Read first, in order:
1. `CLAUDE.md` on `main`, and `docs/DECISIONS.md` 0001 (the release flow) and 0002 (U1–U7).
2. This brief and its walk-sheet, `docs/UAT_dt_selftest.md`.
3. `DeadTired/Core.lua` (`DT.module`, `DT.modules`, `DT.enabled`, `DT.apply`, `DT.db`, `DT.out`, `DT.fail`,
   the loader), `DeadTired/Comms.lua` (`encode`, `decode`, `inbound`, `DT.send`, `DT.on`; `DT._comms`),
   `DeadTired/Debug.lua` (the `debug` verbs; `DT.fitCheck` in `UI.lua`), `DeadTired/Keys.lua`
   (`DT.myKey`, `DT.realmSource`, `DT.splitKey`), `DeadTired/Migrate.lua` (the `migrated.*` flags), and every
   `DT.on(...)` handler: `Alts`, `Crypt`, `Played`, `Gank`, `Migrate`, `Prep`, `Stash`, `Who`.

**Draft-status: written 22 Nov 2026, 11:40, against `main` at `588cb4d` (0.3.4, released).** Build is
expected the same day or the next, after Tim rules on R-F8-1 to R-F8-7. Re-read every function named here
against the tree as Task 1's first act; if any has moved, say so in the report and follow the tree.

## Origin
Release-process thread, 20 Nov 2026: U1 and U2, agreed at 19:21, recorded as `docs/DECISIONS.md` 0002
clauses 1, 2 and 8 (proposed). Order agreed with Tim 22 Nov 11:21: this round before the death
leaderboard, gambling and the Waypointer. Two things forced it: P1 and H4 have waited since 0.3.2 for a
second guildie online at the same time, and the realm-blank incident of 21 Nov (DT silent on client
71037) was found by a player, not by a check.

## Precondition
`main` at `588cb4d` or later, carrying this brief and its walk-sheet; `DeadTired/tests/run_all.sh`
`ALL GREEN`.

## Rulings in force (cited, not restated)
`CLAUDE.md`: guarded reads; no Blizzard global written, no hook; one SavedVariables table; every
module rule 1–14 (rule 13 is the debug-command pattern this round extends). R-1 (lockdown hold; never gate
on the restricted flag). AUD-10 (refused sends retried then dropped). R-F7-1 to R-F7-6 (`DT.realmSource`).

## Ratify before code
`docs/DECISIONS.md` 0002 is **proposed**. This round may be built while it is proposed only because
Tim agreed U1 and U2 in the thread on 20 Nov; the report says the round rests on a proposed entry.
**R-F8-1 to R-F8-7 below must be ruled before Task 2 starts.**

## Rulings for this round (to ratify)
- **R-F8-1 The self-test.** `/dt selftest` (listed in `/dt help`) runs these checks in the live client and
  prints **one** line: `Self-test: <p> passed, <f> failed. /reload to keep the record.` Each failure adds
  one line naming the check. Checks:
  - **S1 Version:** the `.toc` `Version` (guarded `C_AddOns.GetAddOnMetadata`) equals `DT.VERSION`.
  - **S2 Client:** `GetBuildInfo` build and interface, recorded. Information only, never a failure.
  - **S3 Key:** `DT.myKey()` is not nil; the realm source is recorded. **Fails on a client like 21 Nov's.**
  - **S4 APIs:** every global and `C_*` function DT calls (a list, `DT.REQUIRED`, built in Task 2 from the
    code) is present. One failure per missing name.
  - **S5 Modules:** every registered module has `loaded = true` and no `init` error this session.
  - **S6 Errors:** no module error count has risen since login (a login snapshot is kept in memory).
  - **S7 Windows:** `DT.fitCheck()` reports `0 over` and `measure failures 0`.
  - **S8 Switches:** for each optional module, switched off **in memory only**, a ghost message of each
    kind it handles (R-F8-3) produces no `DT.out` and no `DT.send`; then its switch is restored.
  - **S9 Saved data:** `DeadTiredDB.schema == DT.SCHEMA`; every `migrated.*` flag DT defines is true; each
    capped list is within its cap.
  - **S10 Wire:** for every message kind, `encode` then `decode` returns the same payload.
  - **S11 Loopback:** a ghost HELLO makes the ghost appear in `/dt who`'s list; the ghost is then purged.
- **R-F8-2 The record.** The last run only is kept as `DeadTiredDB.selftest = { at, version, build,
  interface, key, source, pass, fail, lines }`, `lines` capped at 100, overwritten each run. Nothing else
  is saved by the self-test. It runs only when typed: never at login, never on a timer.
- **R-F8-3 The ghost.** A pretend guildie, **`Restless Ghost`** on the reserved realm **`DTGHOST`** (key
  `DTGHOST-Restless Ghost`). Verbs: `/dt debug ghost on|off`, and `/dt debug ghost hello|death|gank|played|
  stash|prep|all` to have the ghost send one message of that kind (`all`: one of each). A ghost message is
  built with Comms' own `encode` and handed to Comms' own `inbound` with the sender string
  `Restless Ghost-DTGHOST`, so decoding, the key check and every handler run exactly as for a real message.
  It never reaches AceComm, ChatThrottleLib or `SendAddonMessage`.
- **R-F8-4 The ghost answers.** While `ghost on`, when DT sends a `STASHQ`, `PREPQ` or `WHO`, the ghost
  answers it about 1 second later through the same path (a `STASH` hit for any search term, a `PREP` verdict,
  a `HELLO`). The real message still goes to the guild as now. `ghost on` lasts for the session only and is
  never saved; `/reload` turns it off.
- **R-F8-5 Never saved.** Every saved entry whose key is on realm `DTGHOST` is removed on `ghost off`, at
  `PLAYER_LOGOUT`, and at every load (Migrate, every time, not once). Ghost messages leave
  `comms.received`, `comms.senders` and `comms.mismatches` unchanged.
- **R-F8-6 Gated.** Every ghost verb, and S8/S11, does nothing outside the guild. Nothing but the
  `debug ghost` verbs and the self-test can make the ghost speak. Both new modules are `optional` with the
  standard On card (`CLAUDE.md` module rule 2, default on); off, their verbs do nothing. The verbs appear in
  `/dt help` like every other verb (`DT.helpLine` lists all of them, `debug` ones included).
- **R-F8-7 Version.** 0.3.5: a diagnostics release; no player-facing feature changes.

## Deliverable
On `claude/dt-selftest` from `main`, DeadTired **0.3.5** with `/dt selftest` and the ghost. In a harness
client, the self-test passes every check, and **on a harness client whose realm calls return `""` with no
fallback, S3 fails** (the incident it exists to catch). The ghost's HELLO, DEATH, GANK, PLAYED, STASH and
PREP each reach their handler through `inbound`, and after `ghost off` or a simulated logout no string
`DTGHOST` remains anywhere in `DeadTiredDB`. Done when `run_all.sh` is `ALL GREEN` with the new checks,
every Task 7 guard has been removed once and turned a named check red, and `dist/DeadTired-0.3.5.zip`
passes `diff -r`.

## Working rules
- Every read of game state guarded (`try`, `clean`). No new event except `PLAYER_LOGOUT` for R-F8-5.
- **Comms' wire is untouched:** `encode`, `decode`, `keyMatchesSender` and `inbound` keep their code; the
  ghost calls them. `DT.send` may gain one `DT.signal("sent", kind, data)` after a successful enqueue, for
  R-F8-4, and nothing else.
- In-memory overrides only, in the pattern of `DT.fitSkin`: the self-test never calls `DT.set`, never writes
  a setting, and restores every switch it flips even when a check errors (pcall around each check).
- Player-facing text added: the R-F8-1 summary and failure lines, the ghost's name, and one `ghost on`/`ghost
  off` confirmation each. Dry, short, in DT's voice. Nothing else.

## Tasks
1. **Baseline** at the branch point: suites and check counts; re-verify every name in "Read first".
2. **`DeadTired/Selftest.lua`** (new module `selftest`, loaded after `Debug.lua` in the `.toc`): S1–S11,
   `DT.REQUIRED` (derived from the code; the report lists how), the login snapshot for S6, the record of
   R-F8-2, the verb.
3. **`DeadTired/Ghost.lua`** (new module `ghost`): R-F8-3's verbs, R-F8-4's answers via `DT.listen("sent")`,
   R-F8-5's purge (a function the self-test, `ghost off`, `PLAYER_LOGOUT` and Migrate all call).
4. **`Comms.lua`**: the one `DT.signal("sent", ...)` line. **`Migrate.lua`**: call the purge at every load.
5. **`Debug.lua`**: the `debug ghost` verbs registered (the code lives in `Ghost.lua`).
6. **`.toc`**: the two files, in order; `Version: 0.3.5`; `DT.VERSION = "0.3.5"`.
7. **Tests and guard proofs** in `test_selftest.lua` and `test_ghost.lua`. Tests: every S-check passes on a
   healthy harness client; each S-check fails on a harness client broken for it (S3 on `""` realm with no
   fallback; S4 with one API removed; S7 with a text that overflows; S8 with one handler that ignores its
   switch; S9 with a flag missing); the record is written, capped and overwritten; nothing else saved by a
   run. Ghost: each kind reaches its handler; the answers to STASHQ, PREPQ and WHO; no `DTGHOST` anywhere in
   `DeadTiredDB` after `ghost off`, after `PLAYER_LOGOUT`, and after a load with ghost entries planted;
   `comms.received`/`senders`/`mismatches` unchanged by ghost messages; nothing reaches AceComm; nothing
   outside the guild; `ghost on` not saved. **Guards** (remove once, a named check red, restore): each
   S-check's failing condition; the switch restore; the purge at each of its three call sites; the comms
   counters left alone; the not-to-AceComm path; the guild gate on the ghost; `ghost on` kept in memory.
   Plus every guard 0.3.4 proved.
8. **Docs**: `FEATURES.md` *Ruled 22 Nov (for `dt_selftest`)*; `docs/RELEASE_0.3.5.md` (DT's voice; short:
   a self-test anyone can run, and something for the officers to test with; no change to what DT does).
   Draft the #dt-crypt-workshop post in the PR body (`DECISIONS.md` 0001 clause 4).
9. **Version and zip**: `dist/DeadTired-0.3.5.zip`, `diff -r` clean.
10. **Report** `docs/COWORK_REPORT_dt_selftest.md`; PR to `main`, not stacked.

## Out of scope
- Any change to the wire, the protocol version, AceComm or ChatThrottleLib use, or what a real message does.
- Running the self-test at login or on a timer; printing anything unasked.
- Claude reading the WTF folder automatically (process, not addon code).
- A ghost visible to anyone else, or more than one ghost.
- Fixing anything the self-test finds: a failing check in the live client is reported, not fixed here.
- The death leaderboard, gambling, the Waypointer, the skin-switch probe, volunteer testers (U6).

## The one deliberate widening
`CLAUDE.md` says inbound data comes from other players running DT. The ghost feeds handlers data no
player sent. Bounded by: a typed `debug ghost` verb or `/dt selftest` only; a reserved realm no real
player can have; never through the network; purged at three points so it never outlives the session; and
inside the guild only.

## Stop conditions
- Baseline not `ALL GREEN`, or `lua5.1`/`luac5.1` can't be installed → stop.
- Any change needed to `encode`, `decode`, `keyMatchesSender` or `inbound`, or to `DT.send` beyond the one
  signal line → stop.
- A check in S1–S11 can't be made to fail in the harness (it would be decorative) → stop and report which.
- S8 finds a module whose handler ignores its switch in the **current** code → stop and report it; that is
  a bug in 0.3.4, not this round's to fix.
- The purge would need to rewrite any entry not keyed on `DTGHOST` → stop.
- A guard removal turns nothing red: strengthen the test (test files only); if that needs addon code → stop.

## UAT: acceptance checks
`docs/UAT_dt_selftest.md`: **6 [G] offline, 3 [G] in game (Tim types, the result is read), 2 [H].**

## Reporting
`docs/COWORK_REPORT_dt_selftest.md`: branch and heads; counts per suite; for each S-check, the harness
failure that proves it can fail; how `DT.REQUIRED` was built and its length; each ghost kind and the
handler it reached; the purge's three call sites and their checks; guard proofs; player-facing text
added, verbatim; zip name, size, sha256; anything in this brief that turned out wrong; questions.
Never write a `_results.md` file.
