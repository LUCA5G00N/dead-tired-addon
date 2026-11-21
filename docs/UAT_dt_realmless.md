# Walk-sheet: the realm the game stopped giving (hotfix 0.3.4)

Brief: `docs/COWORK_BRIEF_dt_realmless.md`. **[G]** = the build session proves it in its report;
**[H]** = Tim in game, 0.3.4 over 0.3.3, on the client that returns no realm. **5 [G], 3 [H]**, plus P1
after release. Screenshot every [H]. Back up `SavedVariables\DeadTired.lua` first.

## Offline [G]
- [ ] G1 `run_all.sh` ALL GREEN with counts; zip `diff -r` clean; `.toc`/`DT.VERSION` 0.3.4.
- [ ] G2 Each R-F7-1 step proved on a client returning `""` (and nil); a client returning the realm behaves
      as 0.3.3 apart from remembering it; `DT.realmKey("<realm>")` unchanged.
- [ ] G3 Seed on a fixture like Tim's: `stromham hamson` → `CAMWOWEU4Realm2PvP`; two realms → left out;
      runs once.
- [ ] G4 Two harness clients on `""` see each other in Who and hear each other's deaths.
- [ ] G5 The `?` death repaired and nothing else rewritten; empty `rn` neither sent nor stored; every Task 7
      guard removed → a named check red → restored.

## In game [H]
- [ ] H1 `/dt debug names`: `key "CAMWOWEU4Realm2PvP-Stromham Hamson"` and `realm from character` (or
      `server`). Not `key nil`.
- [ ] H2 `/reload`, then `/dt debug errors`: the comms `sent` count goes up after the reload (DT is talking
      again).
- [ ] H3 `/dt graveyard`: the Uldaman level 45 death of 21 Nov shows **Stromham Hamson**, not `?`.

## After release (needs a guildie on 0.3.4)
- [ ] P1 The bar's "DT: N online" counts a guildie running 0.3.4, and `/dt who` lists them.
