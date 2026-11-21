# Cowork brief: the realm the game stopped giving (hotfix 0.3.4)

You are in `LUCA5G00N/dead-tired-addon`, building in a cloud session; Tim walks the result in game.
Read first, in order:
1. `CLAUDE.md` on `main`.
2. This brief and its walk-sheet, `docs/UAT_dt_realmless.md`.
3. `DeadTired/Keys.lua` (`DT.realmKey`, `DT.keyOf`, `DT.myKey`, `DT.realmLabel`), `DeadTired/Comms.lua`
   (`DT.send`: it sends nothing without `DT.myKey()`; `keyMatchesSender` compares names only),
   `DeadTired/Alts.lua` (the roster; own characters carry `mine = true`), `DeadTired/Crypt.lua` (the own
   death record, `who = DT.myKey() or "?"`), `DeadTired/Who.lua` (`rn` in HELLO/WHO; `DT.realmNames`),
   `DeadTired/Debug.lua` (`/dt debug names`), `DeadTired/Migrate.lua` (the once-per-account pattern).

**Draft-status: written 21 Nov 2026, 23:05, against `main` at `bf45742` (0.3.3, released), for a build on
22 Nov.** Re-read every function named here against the tree as Task 1's first act.

## Origin
DEAD TIRED project note `claude/30_realm_blank_incident_2026-11-21.md`. In short:
- **Client build 71037** ("Nov 18 2026"), first seen 21 Nov 18:40, returns **`""` from both
  `GetRealmName` and `GetNormalizedRealmName`**. Tim's `DeadTiredProbe` SavedVariables show every session to
  21 Nov 01:15 on build 70959 with `CAMWOWEU4Realm2PvP`, and every session from 18:40 on 71037 with `""`.
  `/dt debug names` at 22:06: `realm: GetRealmName "", GetNormalizedRealmName "", key nil`.
- So `DT.myKey()` is nil, and **`DT.send` refuses everything: every guildie on the new client has a silent
  addon** (no HELLO, deaths, stash, played, gank). Tim's comms `senders`: nothing received since 21 Nov
  01:15. His own death in Uldaman on 21 Nov was saved with `who = "?"`.
- **Probe, 21 Nov 22:58** (Tim, in a party; screenshot `WoWScrnShot_112126_225809.jpg`).
  `UnitGUID` still carries the server ID, and `UnitFullName` returns the name with no realm:
  ```
  Player-6842-001FEF8D Stromham Hamson
  party1 Player-6950-001CCFF0 Vespera Grimm
  party2 Player-6946-001E7502 Lunafreya Blaze
  party3 Player-6842-001FDB3B Echo Nightclaw
  party4 Player-6942-00C5A83B Sap Hapi
  ```
Design agreed with Tim 21 Nov 22:58 (K1 to K4 in the note; "agreed on with your leans").

## Precondition
`main` at `bf45742` or later, carrying this brief and its walk-sheet; `run_all.sh` `ALL GREEN`.

## Rulings in force (cited, not restated)
`CLAUDE.md` (character keys, guarded reads, no Blizzard global written, messages carry the sender's own
key). R-P5 (names without realm; realm only on a collision). R-F6-3 (class colours match on the name).

## Rulings for this round (to ratify)
- **R-F7-1 My realm, in order.** `DT.realmKey()` with no argument (the player's own realm) tries:
  (1) the game (`GetNormalizedRealmName`, then `GetRealmName`), as now; (2) **the realm DT last saw for this
  character**; (3) **the realm DT remembers for this server ID** (the middle number of
  `UnitGUID("player")`, e.g. `6842`); (4) last resort, **`S<server ID>`** (e.g. `S6842`), saved as this
  character's realm so the key stays the same from then on. `DT.realmKey(realm)` for anyone else's realm is
  unchanged.
- **R-F7-2 Remembering.** Whenever (1) gives a realm, DT saves it for this character (lower full name) and
  for this server ID, in `DeadTiredDB.realms` (`byChar`, `byServer`; capped 200 each). (2) and (3) never
  overwrite with a worse source.
- **R-F7-3 Seeding.** Once per account (`migrated.realm034`), `byChar` is seeded from the keys DT already
  saved for the account's own characters: alts-roster keys marked `mine`. A full name found on two realms
  is left out (ambiguous) and falls through to (3)/(4).
- **R-F7-4 Repair.** Once a key is known, own graveyard entries saved as `who = "?"` (with `mine`) become
  this character's key, once per login. Nothing else is rewritten.
- **R-F7-5 Empty realm names are not news.** HELLO/WHO send `rn` only when the game gives a non-empty name;
  an empty `rn` received is ignored (never stored in `DT.realmNames`).
- **R-F7-6 Saying where it came from.** `/dt debug names` adds `, realm from game|character|server|server-id`.
  Nothing is printed unasked.
- **R-F7-7 Version.** 0.3.4: a fix.

## Deliverable
On a branch from `main`, DeadTired **0.3.4**. On a client whose realm calls return `""`, DT finds the
player's realm by R-F7-1, so `DT.myKey()` is a key, `DT.send` sends again, and the own `?` deaths are
repaired. A client that returns the realm behaves exactly as 0.3.3 did, apart from remembering it. Done when
`run_all.sh` is `ALL GREEN` with the new checks, every Task 7 guard has been removed once and turned a named
check red, and `dist/DeadTired-0.3.4.zip` passes `diff -r`.

## Working rules
- Every read guarded (`try`, `clean`). `UnitGUID` parsed only as `^Player%-(%d+)%-`; anything else is no server ID.
- No new player-facing text except R-F7-6's suffix. No new event; no new message kind or field.
- `DT.realmKey(x)` with an argument behaves byte for byte as now (keys for other players can't change).

## Tasks
1. **Baseline** at the branch point; record suites and checks.
2. **`Keys.lua`**: the R-F7-1 chain and R-F7-2 remembering, with `DT.realmSource()` returning
   `game|character|server|server-id|nil` for the last own lookup. The store is read through `DT.db()` and
   is a no-op before the saved variables load.
3. **`Migrate.lua`**: R-F7-3's seed, once per account.
4. **`Crypt.lua`**: R-F7-4's repair, once per login, after the first non-nil `DT.myKey()`.
5. **`Who.lua`**: R-F7-5.
6. **`Debug.lua`**: R-F7-6.
7. **Tests and guard proofs.** With a harness client whose realm calls return `""` (and one returning nil):
   each step of R-F7-1 in turn; remembering from (1), and no overwrite from (2)/(3); the seed (one realm;
   two realms → left out; not `mine` → ignored; runs once); `S<id>` saved and stable across a reload; a GUID
   that doesn't parse → no key (and `DT.send` still refuses); `DT.send` sends again with a fallback key;
   two clients on `""` exchange a HELLO and see each other in Who; the `?` repair (and nothing else
   rewritten); empty `rn` neither sent nor stored; `debug names` shows the source; `DT.realmKey("Some
   Realm")` unchanged. Guards (remove once, a named check red, restore): each R-F7-1 step; no overwrite
   from a worse source; the seed's ambiguity rule; the seed's once flag; the GUID pattern; the repair's
   `mine` check; the empty-`rn` filter both ways. Plus every guard 0.3.3 proved.
8. **Docs**: `FEATURES.md` *Ruled 22 Nov (for `dt_realmless`)*; `docs/RELEASE_0.3.4.md` (DT's voice; say plainly
   that since the game patch of 21 Nov every 0.3.x has been silent, and this brings it back; everyone should
   update).
9. **Version and zip**: 0.3.4; `dist/DeadTired-0.3.4.zip`, `diff -r` clean. Merging publishes the release.
10. **Report** `docs/COWORK_REPORT_dt_realmless.md`.

## Out of scope
Changing how other players' keys are formed or matched; re-keying any saved data other than R-F7-4's
deaths (gank `by = "?"`, played, stash); a realm name shown anywhere new; the skin-switch repaint; U1/U2.

## The one deliberate widening
R-F7-1 (4) invents a realm key (`S6842`) that isn't a realm's name. Bounded by: own character only, only
when the game, the character's memory and the server's memory all fail, saved so it never changes for
that character, and replaced by the real realm the first time the game gives one (R-F7-2).

## Stop conditions
- Baseline not `ALL GREEN`, or `lua5.1`/`luac5.1` can't be installed → stop.
- Any change needed to `DT.realmKey(x)` with an argument, or to `keyMatchesSender` → stop.
- The fallback needs a new event, a new message field, or a read outside the guarded helpers → stop.
- The seed or repair would touch anything not named in R-F7-3/R-F7-4 → stop.
- A guard removal turns nothing red: strengthen the test (test files only); if that needs addon code → stop.

## UAT: acceptance checks
`docs/UAT_dt_realmless.md`: 5 `[G]`, 3 `[H]`, plus one check after release (P1) that needs a guildie.

## Reporting
`docs/COWORK_REPORT_dt_realmless.md`: branch and heads; counts per suite; each R-F7-1 step and the check
that proves it; the seed's result on a fixture like Tim's (own keys on `CAMWOWEU4Realm2PvP`); guard proofs;
player-facing text added; zip name, size, sha256; anything in this brief that turned out wrong; questions.
Never write a `_results.md` file.
