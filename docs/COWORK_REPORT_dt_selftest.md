# Cowork report: the self-test and the pretend guildie (U1 + U2, 0.3.5)

Brief `docs/COWORK_BRIEF_dt_selftest.md`; walk-sheet `docs/UAT_dt_selftest.md`. Built 22 Nov 2026 in a cloud
session on branch **`claude/dt-selftest`** from `main` at **`6d448f4`** (the brief's merge, PR #26).
R-F8-1 to R-F8-7 ruled by Tim at 11:46: "happy to go with your leans". **This round rests on
`docs/DECISIONS.md` 0002, which is still `proposed`** (U1 and U2 were agreed in the thread on 20 Nov).

## Counts
| | Suites | Checks | Result |
|---|---|---|---|
| Baseline (`6d448f4`) | 26 + taint + textfit | 1,466 | ALL GREEN |
| This round | 28 + taint + textfit | 1,562 | ALL GREEN |

New: `test_ghost` 45, `test_selftest` 49; `test_taint` 34 → 36 (it scans the two new files). Changed lines
in older suites: `test_core` (module order gains `ghost,selftest`; the help line's version), `test_who`
(the version shown, two lines). Libraries unmodified (`SHA256SUMS`).

## What landed
- **`DeadTired/Selftest.lua`** (new module `selftest`, optional, On card): `/dt selftest`, S1–S11,
  `DT.REQUIRED`, the record (R-F8-2).
- **`DeadTired/Ghost.lua`** (new module `ghost`, optional, On card): `/dt debug ghost ...`,
  `DT.ghostDeliver`, `DT.ghostPurge`, the answers (R-F8-4), the purge at `PLAYER_LOGOUT`.
- **`Comms.lua`**: one line, `DT.signal("sent", kind, data)` after a successful enqueue. `encode`,
  `decode`, `keyMatchesSender` and `inbound` are untouched.
- **`Migrate.lua`**: its init calls `DT.ghostPurge()` at every load.
- **`.toc`**: `Ghost.lua`, `Selftest.lua` after `Migrate.lua`; `Version: 0.3.5`; `DT.VERSION = "0.3.5"`.
- **Docs:** `FEATURES.md` *Ruled 22 Nov (for `dt_selftest`, 0.3.5)*; `docs/RELEASE_0.3.5.md`.
- **`tools/guard_proofs.lua`**: this round's 27 guards added.

## Each S-check, and the harness case that makes it fail (`test_selftest`)
On a healthy harness client all ten pass and S2 is recorded as information: "10 passed, 0 failed".
| Check | Fails when | Check that proves it |
|---|---|---|
| S1 version | `GetAddOnMetadata` says 0.3.4 | "S1 fails when the .toc disagrees" |
| S3 key | realm `""`, no GUID, nothing remembered | "S3 fails on a \"\" realm with no fallback" (and passes once a server ID exists: source `server-id`) |
| S4 apis | `UnitLevel` removed | "S4 fails with one API removed, naming it" |
| S5 modules | a module not loaded; an init failure | "S5 fails on a module not loaded", "...on an init failure this session" |
| S6 errors | any `DT.fail` this session | "S6 fails on an error this session" |
| S7 windows | one text over its box | "S7 fails when a text doesn't fit" |
| S8 switches | a DEATH handler that prints, a GANK handler that sends, ignoring their switch | "S8 fails on a handler that prints / sends with its module off" |
| S9 saved | `migrated.skin031` missing; 101 deaths; schema 4 | three "S9 fails..." checks |
| S10 wire | a payload changed by decode | "S10 fails when a payload changes in transit" |
| S11 loopback | the ghost never reaches Who; the purge leaves it listed | two "S11 fails..." checks |

**`DT.REQUIRED`** (46 names) was built from the code:
- every `try(X)` of a global;
- every `C_*.Name` the code references (all present in `reference/SPEC_forever_namespaces.md`);
- plus `CreateFrame`, `GetBuildInfo`, `C_AddOns.GetAddOnMetadata` (S1), and the two `C_ChatInfo` functions
  AceComm calls (`SendAddonMessage`, `RegisterAddonMessagePrefix`).

## Each ghost kind and the handler it reached (`test_ghost`)
| `/dt debug ghost` | Kind | Reached |
|---|---|---|
| hello | HELLO (no `login`, `pl = "999999"`) | Who (listed, the bar counts it), Alts (roster), Prep (nothing to resend), Migrate (no refile) |
| death | DEATH | Crypt: the notice prints ("Restless Ghost died at level 13 in The Barrens. Again."), the record keeps the ghost's key |
| gank | GANK (enemy on `DTGHOST` too) | Gank: logged, `by` the ghost |
| played | PLAYED | Played: on the slowest board |
| stash | STASH, answering your open search | Stash: in the open search's answers |
| prep | PREP, answering your open roll call | Prep: in the summary, "Ready (1): Restless Ghost" |
With `ghost on`, your STASHQ, PREPQ and WHO each get the ghost's answer 1 s later. Your real questions
still go to the guild, and nothing on the wire carries the ghost's key.

## The purge's three call sites
- **`ghost off`:** "off: no DTGHOST anywhere in DeadTiredDB". A real guildie's death and gank are kept.
- **`PLAYER_LOGOUT`:** "logout: no DTGHOST anywhere in DeadTiredDB".
- **Every load (Migrate):** "load: no DTGHOST anywhere after loading planted entries".
- **Also:** the module's `onDisable`, and the self-test after S8 and S11.

The purge walks `DeadTiredDB` (depth 8):
- in lists, it removes a record any of whose own fields name `DTGHOST`;
- in maps, it removes an entry whose key or string value names `DTGHOST`;
- otherwise it recurses.

It also takes the ghost out of Who's session list and resets the bar count.

## Guard proofs (`lua5.1 tools/guard_proofs.lua`)
**169 guards** went red when removed, and every file was restored byte for byte:
- 0.3.4's 142, re-proved;
- this round's 27: each S-check's failing condition (S8, S9 and S11 two each), the switch restore, the
  last-run-only record, the self-test's guild gate, the purge's scope, its three call sites, the
  never-sends stub, inbound-only, the counters, the ghost's guild gate, `on` kept in memory, answers
  only while on, and the sent signal.

Two removals first turned nothing red:
1. **The self-test's guild gate.** The `/dt` router already refuses everything outside the guild, so a
   slash test can't reach the verb's own gate. **Test strengthened** (test file only): the verb is
   called directly outside the guild. Diff in `test_selftest.lua`, the "gates" block.
2. **"Answers only while on."** The early `if not on then return end` I marked as the guard is
   redundant: the delayed answer checks `on` again, so removing the early return changes nothing. The
   proof now targets the answer-time check (`if on and DT.enabled("ghost")`), and a new test, "off
   before the answer is due: no answer", turns it red. **No addon code was changed for this.** The
   `-- guard:` comment in `Ghost.lua` still sits on the redundant line; that's worth fixing next time
   the file is touched.

## Player-facing text added (verbatim)
- `Self-test: <p> passed, <f> failed. /reload to keep the record.`, then one line per failure,
  `S<n> <name>: FAIL - <detail>`.
- `selftest.enabled = off` / `ghost.enabled = off`.
- `The Restless Ghost is up. It answers your stash, prep and who until you say off.`
- `The Restless Ghost is laid to rest. Nothing of it was kept.`
- `The Restless Ghost said <n> things.` / `The Restless Ghost: <kind>.`
- `Ask first: /dt stash <item>.` / `Ask first: /dt prep roll.` / `The ghost couldn't say that.`
- `/dt debug ghost on|off|hello|death|gank|played|stash|prep|all`
- The ghost's name, **Restless Ghost**, in DT's existing lines (death notice, Who, the prep summary).

## Zip
`dist/DeadTired-0.3.5.zip`: 186,792 bytes, sha256
`11aba67c96d26e70260d6cb188f49848ac5a80f2ea6ba14f66ee6864942e056c`. `diff -r`: clean.

## What the brief got wrong, or left open
- **Placement.** The brief said to load `Selftest.lua` after `Debug.lua` and register the ghost verbs in
  `Debug.lua`. `Debug.lua` loads before every handler module, so both new files load last (after
  `Migrate.lua`), and the ghost registers its own `debug ghost` verb.
- **S5/S6, the "login snapshot".** This is done by wrapping `DT.fail` when `Selftest.lua` loads (before
  `ADDON_LOADED`), so failures this session, init failures included, are counted in memory. Core is
  not touched.
- **S8 turns every optional module off at once** (not one at a time) and delivers one ghost message of
  every kind, so a loud handler is found whichever module owns it. The failure line names the kind.
  Events and Logs have no inbound messages, so S8 can't test them.
- **S8 and S11 use `DT.ghostDeliver` whatever the ghost's own switch says;** that switch governs the
  verbs and the answers. **S11 forces Who on** for its run, so it passes for a player with Who off, and
  Who stays off afterwards.
- **A safeguard the brief didn't name.** While a ghost message is delivered, `DT.send` is swapped for a
  recorder that sends nothing, so no handler can make DT talk to the guild because of the ghost. The
  ghost only says answer kinds and a HELLO without `login`, so nothing is asked to reply anyway.
- **`keyMismatch` is restored too**, alongside the brief's `received` / `senders` / `mismatches`.
- **S9's schema check** can only fail for a store saved by a *newer* DT. An older store is moved aside by
  `DT.db()` before anything reads it.
- **Production code uses two accessors marked "for the offline tests only":** `DT._comms` (encode,
  decode, inbound) and `DT._who.session` (to drop the ghost from Who's list). The alternative was
  changing Comms or Who, which the brief kept closed.
- **Left for this session:** Crypt's in-memory `heard` count includes ghost deaths until a `/reload`.

## Questions for Tim
1. S4 checks the live client against names from the beta SPEC. If your client lacks one that DT only
   uses optionally (`C_GameRules`, say), S4 will say so on every run. Keep it as a failure, or mark such
   names as information?
2. Is `/dt debug ghost` in `/dt help` too visible for ordinary guildies? R-F8-6 kept it in because the
   house rules require every verb to be listed.
