# Report: the realm the game stopped giving (hotfix 0.3.4)

Brief: `docs/COWORK_BRIEF_dt_realmless.md` (ratified by Tim's merge of PR #23, 21 Nov 23:03).
Walk-sheet: `docs/UAT_dt_realmless.md`. Built in this Claude session on branch `claude/dt-realmless`, from
`main` `cafe1a4`. Not merged: Tim walks, then merges, and the merge publishes v0.3.4.

## Counts
Baseline `run_all.sh` at `cafe1a4`: ALL GREEN, 26 suites, 1421 checks. Final: ALL GREEN, 26 suites,
**1466 checks**. Changed suites: keys 29 -> 48, migrate 63 -> 71, crypt 119 -> 126, who 38 -> 43,
debug 39 -> 45 (core and who also had their version strings moved to 0.3.4).

## What landed
- **`Keys.lua`** (R-F7-1, R-F7-2): `DT.realmKey()` with no argument now runs the chain: the game → the character's
  remembered realm → the server ID's remembered realm → `S<server ID>` (saved). `DT.serverId()` parses
  `UnitGUID("player")` as `^Player%-(%d+)%-`. `DT.realmSource()` names the step. The store is
  `DeadTiredDB.realms = { byChar, byServer }`, capped at 200 entries each, untouched before `DT.loaded`.
  `DT.realmKey("<realm>")` is the same normalisation as before (now a local `norm`).
  - Ordering detail: a saved `S<id>` counts as worse than the server's remembered realm. Step (2) skips it, and
    step (3) replaces it.
- **`Migrate.lua`** (R-F7-3): `DT.migrateRealms(store)`, once per account (`migrated.realm034`). It is called from
  the store's first use, not from the module's `init`, so it runs **before any fallback can save a stand-in**.
  **The brief said Task 3 lands in `Migrate.lua`; it does, but the call site moved for that reason.** It also
  replaces an `S<id>` saved before it ran, never a real realm.
- **`Crypt.lua`** (R-F7-4): `repair()` once per login, at init, on `greeted`, and before each graveyard build:
  `who == "?"` with `mine == true` → the key. An own death now saves the key (it already did; the key exists again).
- **`Who.lua`** (R-F7-5): `realmName()` sends `rn` only when the game's name has a non-blank character; `record`
  ignores a blank `rn`.
- **`Debug.lua`** (R-F7-6): `/dt debug names` ends `, realm from game|character|server|server-id|nowhere`.

## Each R-F7-1 step and the check that proves it (`test_keys`)
| Step | Check |
|---|---|
| (1) the game, remembered | "R-F7-1 (1): the game's realm when it gives one"; "R-F7-2: remembered for the character and the server" |
| (2) the character's | "R-F7-1 (2): the game gives \"\": the character's realm"; "... and when the game gives nil" |
| (3) the server's | "R-F7-1 (3): a new character on a known server ..."; "R-F7-1 (3) beats a saved S<id>, and replaces it" |
| (4) `S<id>`, saved | "R-F7-1 (4): unknown server: S<server ID>"; "... saved as the character's"; "... stable across a reload" |
| the game comes back | "R-F7-2: the game's realm replaces S<id>" |
| no key at all | "GUID pattern: anything but Player-<n>- gives no server: no key"; "and DT.send still refuses" |

## The seed on a fixture like Tim's (`test_migrate`)
Alts roster with `CAMWOWEU4Realm2PvP-Stromham Hamson` and `CAMWOWEU4Realm2PvP-Marvella Swineson` (mine), `Twin
Name` on Realm 2 and Realm 4 (mine), `Echo Nightclaw` (not mine). On a client giving `""`, result:
`stromham hamson` and `marvella swineson` → `CAMWOWEU4Realm2PvP`; `twin name` left out; `echo nightclaw` ignored;
`myKey()` = `CAMWOWEU4Realm2PvP-Stromham Hamson`, `realm from character`. Runs once.

## G4: two clients on `""`
`test_who`: both see each other in Who (`whoCount() == 1` each); HELLO carries no `rn`. `test_crypt`: Echo's death
is heard by Tim word for word as in 0.3.3 and filed under Echo's real key (Echo's own saved data seeded Echo).

## Guard proofs (13 new; `lua5.1 tools/guard_proofs.lua`)
| Guard | File | Change | Suite | Went red |
|---|---|---|---|---|
| R-F7-1 (2): the character's realm | `Keys.lua` | line removed | test_keys | **red**: R-F7-1 (2): the game gives "": the character's realm; R-F7-2: the character's realm beats the server's, and isn't overwritten |
| R-F7-1 (2): a saved S<id> is worse than the server's realm | `Keys.lua` | `if c then source = "character" return c end` | test_keys | **red**: R-F7-1 (4): unknown server: S<server ID>; R-F7-1 (3) beats a saved S<id>, and replaces it |
| R-F7-1 (3): the server's realm | `Keys.lua` | `if false then` | test_keys | **red**: R-F7-1 (3): a new character on a known server: the server's realm (then kept as the character's); R-F7-1 (3): and it becomes that character's; R-F7-1 (3) beats a saved S<id>, and replaces it |
| R-F7-1 (4): S<id> saved, so it stays | `Keys.lua` | line removed | test_keys | **red**: R-F7-1 (4): unknown server: S<server ID>; R-F7-1 (4): saved as the character's; R-F7-1 (4): stable across a reload |
| R-F7-2: the game's realm remembered | `Keys.lua` | line removed | test_keys | **red**: R-F7-2: remembered for the character and the server; R-F7-1 (2): the game gives "": the character's realm; R-F7-2: the game's realm replaces S<id> |
| realms store cap | `Keys.lua` | line removed | test_keys | **red**: realms store capped: a full byChar takes no new entry (no key then) |
| GUID pattern | `Keys.lua` | `return g:match("%-(%d+)%-")` | test_keys | **red**: GUID pattern: anything but Player-<n>- gives no server: no key; and DT.send still refuses; no GUID at all: no key |
| R-F7-3: own characters only | `Migrate.lua` | `if type(e) == "table" then` | test_migrate | **red**: R-F7-3: a guildie's key (not mine) is ignored |
| R-F7-3: a name on two realms left out | `Migrate.lua` | `if (cur == nil or tostring(cur):match("^S%d+$")) then` | test_migrate | **red**: R-F7-3: a name on two realms is left out |
| R-F7-3: the seed runs once | `Migrate.lua` | line removed | test_migrate | **red**: R-F7-3: runs once (a later own key isn't seeded) |
| R-F7-4: the repair touches mine only | `Crypt.lua` | `if type(e) == "table" and e.who == "?" then e.who = me end` | test_crypt | **red**: R-F7-4: a ? that isn't mine is left |
| R-F7-5: empty rn not sent | `Who.lua` | `if type(rn) ~= "string" then return nil end` | test_who | **red**: R-F7-5: no realm name from the game: HELLO carries no rn |
| R-F7-5: empty rn not stored | `Who.lua` | `local rn = type(d.rn) == "string" and DT.safe(d.rn, 40) or nil` | test_who | **red**: R-F7-5: an empty (or blank) rn received is never stored |

All **142** guards (0.3.3's 129 and these 13) went red when removed and were restored: "every guard proved;
every file restored". One existing guard ("full name for my key") now also turns this round's checks red,
as expected: no name, no key.

## Player-facing text added
Only `, realm from <source>` on `/dt debug names`, and the release notes. Nothing prints unasked.

## Zip
`dist/DeadTired-0.3.4.zip`, 179225 bytes, sha256 `766b2ffc3aebe33a708b17982ed344204887c2c6d0ec1752da77a0687bc4a208`,
41 files, `diff -r` clean.

## What the brief got wrong, or left open
- **A finding about guildies with no saved key.** A guildie who installed DT after the patch (so DT never saw
  their realm) gets `S<server ID>`. Their *other* keys from before (for example in your graveyard) stay
  `CAMWOWEU4Realm…`, so R-P5 shows the two apart: "Echo Nightclaw (S6842)". The test
  "a fresh install with no saved key" records the stand-in. Everyone in the guild today installed before the
  patch, so their own saved data seeds them and this shouldn't appear. If it does, a later round could match
  `S<id>` to a realm through the server IDs seen in GUIDs. That would change other players' keys, which this
  brief kept out of scope.
- The brief's step order made "never overwrites with a worse source" true by construction, except for the
  `S<id>` case, which needed the explicit rule above.

## Questions for Tim
None beyond the walk. Never write a `_results.md` file.
