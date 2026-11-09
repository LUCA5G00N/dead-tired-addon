# Cowork brief: DEAD TIRED fix round 3 (let it talk on Forever; one realm key; recruit nudge; rc3)

Read first, in order:
1. `CLAUDE.md` on `main` (the *Addon messages* line changed on 9 Nov: see R-1).
2. This brief and its walk-sheet, `docs/UAT_dt_fixes3.md`.
3. `docs/PROBE_launch_results.md` (*Update* and the comms rows) and `docs/FEATURES.md` § Comms.
4. On `card/dt_foundation`: `DeadTired/Comms.lua`, `Core.lua`, `Roster.lua`, `Alts.lua` and their
   tests. On `audit/2026-11-02`: `docs/AUDIT_2026-11-02.md` (AUD-06, AUD-10) and
   `audit/tests/test_realm_spelling.lua` (and `lib.lua`, `setup.sh`, as fix round 1 used them).
5. `reference/SPEC_forever_namespaces.md`: search it, don't read it top to bottom.

**Draft-status: ratified by Tim 2026-11-09** (rulings R-1, AUD-10, AUD-06, held wording, recruit
nudge and LogPrompt chosen by Tim in the 9 Nov session). Heads when written:

| Branch | Head |
|---|---|
| `card/dt_foundation` | `696dd87` |
| `card/dt_crypt` | `f6f97c9` |
| `card/dt_pvp` | `b57c6db` |
| `card/dt_prep` | `6fb903b` |
| `card/dt_stretch` | `39e636f` |
| `card/dt_logs` | `2558f4c` |
| `card/dt_probe` | `a25b538` |
| `release/0.1.0-rc2` | `dcaaca4` |

If a head has moved, re-read that branch's files before trusting this brief's line numbers.

## Origin

The launch probe found `AreOutgoingAddonChatMessagesRestricted()` true on all 22 logins, so card 1
holds every message for ever: every shared feature on rc2 is silent. On 7 Nov two hand tests
showed the flag is misleading on Forever: a typed `SendAddonMessage("DTT","hi","GUILD")` returned
0 and came back to the sender, and Naowh Forever's Group Inspect worked between two players
(`PROBE_launch_results.md`, *Update*). This round makes DeadTired talk, fixes the two audit
findings deferred until the probe (AUD-06, AUD-10), adds the recruit nudge Tim asked for, and
re-cuts the release.

## The rulings (ratified 2026-11-09)

- **R-1 (card 1): hold only in lockdown.** The outbound pump holds while
  `C_ChatInfo.InChatMessagingLockdown()` returns `true` (boss fights, M+, PvP matches), retrying
  every 5 s as now. It no longer holds on `AreOutgoingAddonChatMessagesRestricted()`. That flag is
  still read once per login and recorded for diagnostics (`comms.flagRestricted` = the last
  reading, `comms.flagReads` = how many times read); it never gates a send. If
  `InChatMessagingLockdown` is absent or errors, treat it as **not** in lockdown (the throttle and
  AUD-10 still protect the send). `CLAUDE.md` is amended to match (done with this brief).
- **AUD-10 (card 1): a refused send is retried, then dropped.** `C_ChatInfo.SendAddonMessage`
  returns a result. Success is `0` (`Enum.SendAddonMessageResult.Success` when that table exists),
  or `true`/`nil` on clients that return those. Anything else, or a raised error, is a refusal:
  count it (`comms.sendRefused`, plus `comms.lastRefusal` = the code as a string), put the message
  back at the **front** of the queue, and wait as for the throttle (at least 1 s). After **3**
  refusals of the same message, drop it and count the drop (`comms.refusedDropped`). The harness
  stub gains a settable return value so this can be tested.
- **AUD-10 (probe): fix the `registered` read.** `DeadTiredProbe`'s `registered` is true when the
  prefix registration returned `0` (Success) or `1` (DuplicatePrefix), or `true`. Keep the raw
  return as it is recorded now.
- **AUD-06 (cards 1, 4, 5, 6): one realm spelling everywhere.** Every character key is
  `NormalisedRealm-Name`, where the realm is `GetNormalizedRealmName()` when that returns a
  non-empty string, else `GetRealmName()` with spaces and hyphens removed
  (`CAMWOW EU4 Realm 2 PvP` → `CAMWOWEU4Realm2PvP`). One helper in `Core.lua`
  (`DT.realmKey(realm)` and `DT.keyOf(name, realm)`) is used by `DT.charKey()`, Comms'
  `senderKey()`, `DT.display()` (own-realm test), and `/dt gank`'s `who` (card 4). Stored keys are
  rewritten once at load (see Task 4). `DT.display` shows the name alone on your own realm, as
  now.
- **Held wording (card 1).** When a shared command queues something while the pump is holding for
  lockdown, print once (not again until the hold has ended and a new one begins):
  `The dead are gagged for this fight. Your message goes when it's over.`
  The roster's "Give the dead a minute to rise." line stays for an empty roster.
- **Recruit nudge (card 5).** After a successful `/dt recruit` post, one line prints when the
  15-minute cooldown ends, **once**, only in that session, only if the player is still a guild
  officer and member, and only if nothing has been posted since:
  `The crypt door creaks open: you can recruit again (/dt recruit).`
  `/dt recruit nudge off` stops it (account-wide, saved); `/dt recruit nudge on` restores it;
  default on. It never posts anything. This is a new *prints unasked* exception: add it to
  `CLAUDE.md`'s list (done with this brief).
- **WizardryLogPrompt: retired** (Tim, 9 Nov; already moved out of `AddOns` on Tim's PC). No code
  change here. Remove the "move it out before walking card 7" steps from the docs you touch, and
  say in `LAUNCH_NIGHT.md` that card 7's prompt is now the only logs prompt.

## Deliverable

`card/dt_foundation` carries R-1, AUD-10, AUD-06 and the held wording, with tests; it is merged
into every card branch, and the card-specific parts (AUD-06 in cards 4, 5, 6; the nudge in card
5) are done on their branches. `DeadTiredProbe` carries the `registered` fix. `release/0.1.0-rc3`
is cut with `dist/DeadTired-0.1.0-rc3.zip`, the card-1 zip and the probe zip rebuilt. Every
suite is green, the audit's `test_realm_spelling.lua` is green, and every guard below has been
removed once and turned a check red.

## Tasks

1. **Baseline.** Every card branch's and rc2's `run_all.sh` green; `test_realm_spelling.lua`
   red (2 of 2), as fix round 1 recorded. Anything else → stop.
2. **R-1 + held wording on `card/dt_foundation`.** Checks: with the flag `true` and lockdown
   false, a message is sent; with lockdown true, held and retried, sent when it lifts; lockdown
   function absent/erroring → sends; flag recorded at login (`flagReads` 1, `flagRestricted`
   true) and never consulted by the pump; the held line prints once per hold, not for the second
   queued message, and again for a new hold. Rewrite the existing "restricted: nothing sent"
   checks to the lockdown form (and say so in the report).
3. **AUD-10 on `card/dt_foundation`.** Checks: return 0 → sent; return 5 → refused, still at the
   head of the queue, retried after the wait; 3 refusals → dropped and counted, the next message
   then goes; a raised error counts as a refusal; `true` and `nil` returns count as success.
4. **AUD-06 on `card/dt_foundation`.** Add `DT.realmKey` / `DT.keyOf`; use them in `charKey`,
   `senderKey`, `display`. One-time migration at load, run once per account (flag
   `DeadTiredDB.keysV = 2`): every key in the roster, the alt registry (keys and each `main`)
   rewritten to the normalised form; where two old keys collapse into one, keep the entry with
   the newer `seen`. Export `DT.migrateKeys(tbl, fields)` so card branches can migrate their own
   stores. Checks: own key normalised; a sender `Name-ArgentDawn` and a local `Argent Dawn` realm
   give the same key; display hides the own realm; migration rewrites, merges, runs once.
   Push the foundation.
5. **Merge the foundation into each card branch** (`dt_crypt`, `dt_pvp`, `dt_prep`, `dt_stretch`,
   `dt_logs`); suites green after each merge. On the branches that store keys, migrate their own
   stores with `DT.migrateKeys` in the module's init: card 3 (the graveyard's `who`), card 4
   (gank log `who`; and `/dt gank` builds `who` with `DT.keyOf`), card 5 (prep answers' `to` and
   any stored keys), card 6 (stash `chars`, play-time keys). Checks on each: an old spaced key is
   rewritten once; the card's existing tests still pass.
6. **Recruit nudge on `card/dt_prep`.** Checks: post → after 900 s exactly one nudge line; no line
   if a second post happened (the second post's own nudge comes 900 s later); no line if not an
   officer at the time; no line after `/dt recruit nudge off` (saved); no nudge at login without a
   post this session; the nudge never calls `SendChatMessage`.
7. **Probe `registered` fix on `card/dt_probe`.** Checks: return 0 → true; 1 → true; true → true;
   2 → false; error → false.
8. **Guard proofs** (remove each once, confirm a check goes red, restore): the lockdown hold; the
   flag no longer gating (put the old flag check back: a check goes red); the success test in
   AUD-10; the 3-refusal limit; the front-of-queue requeue; the normalise step in `realmKey`; the
   migration's run-once flag; the nudge's officer check; the nudge's "posted since" check; the
   held line's once-per-hold rule.
9. **Audit test.** Run `audit/tests/test_realm_spelling.lua` against the merged `card/dt_prep`
   tree as fix round 1 did: 2 of 2 green.
10. **Re-cut `release/0.1.0-rc3`** from `release/0.1.0-rc2`, merging every updated card branch.
    `tools/package.sh` produces `dist/DeadTired-0.1.0-rc3.zip` (and the card-1 and probe zips,
    rebuilt); remove the rc2 zip from the rc3 branch. Update `LAUNCH_NIGHT.md`,
    `GUIDE_guildies.md` and `ANNOUNCE_discord.md` where they name the rc2 zip, drop the
    WizardryLogPrompt steps, and add one line to the guide for the nudge (`/dt recruit nudge off`).
    `run_all.sh` green; zips checked with `diff -r` as before. Push.
11. **Report** `docs/COWORK_REPORT_dt_fixes3.md` on the rc3 branch; update each touched card's
    brief with an *Amended 2026-11-09 (fix round 3)* note and *(amended)* marks.

## Working rules

- Foundation first; card branches only after the foundation is pushed (Task 5 merges it).
- Touch only the files named for each task, their tests, and the docs named in Tasks 10-11.
- Player-facing lines are given above. Write no other new player-facing text.
- `reference/` stays read-only. No new libraries in this round (the library ruling comes later).

## Out of scope

The shell (launcher bar, viewports, skins), the armory and every other new module in
`FEATURES.md`; card 2; merging to `main`; where zips are hosted; AUD-08 and AUD-13 (still
deferred); any change to what a card shares or when (only *how* the message gets out changes).

## Stop conditions

- A suite red at baseline, or `test_realm_spelling.lua` not red at baseline → stop.
- A foundation merge into a card branch conflicts in a file this brief doesn't name → stop.
- R-1 needs any change other than the pump's hold test and the flag recording → stop.
- The migration would delete an entry it can't merge → stop.
- A guard removal turns nothing red: strengthen the test (test files only, as `CLAUDE.md`
  allows); if that needs addon code → stop.

## Reporting

Old and new heads per branch; each ruling with its checks and counts; guard proofs (removal → the
check that went red); the audit test before/after; migration behaviour; zip names, sizes and file
lists; every doc line changed. Never write a `_results.md` file.
