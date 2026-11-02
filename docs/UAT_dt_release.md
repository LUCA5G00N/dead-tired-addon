# UAT walk-sheet: dt_release (0.1.0-rc1)

Brief: `docs/COWORK_BRIEF_dt_release.md`. **Checks: 9. `[H]` count: 1.**

**Offline (the build session runs these):**
- [ ] `[G]` G1: on `release/0.1.0-rc1`, `DeadTired/tests/run_all.sh` exits 0 and runs every card's
  suites plus `together`.
- [ ] `[G]` G2: the `.lua` lines in `DeadTired/DeadTired.toc` name every module once, card 1's first,
  then the Q2 order.
- [ ] `[G]` G3: the report lists the verbs, DB keys and message kinds with no duplicates.
- [ ] `[G]` G4: each zip unzipped and `diff -r` against its source folder minus `tests/` shows no
  differences; neither zip contains `tests/`.
- [ ] `[G]` G5: `git diff main --stat -- DeadTired/` on the release branch equals the union of the
  card branches' diffs plus `tests/test_together.lua` (no module code changed by the merge).
- [ ] `[G]` G6: every command named in `docs/GUIDE_guildies.md` and `docs/GUIDE_officers.md`
  appears in the code (`grep` each), and `docs/ANNOUNCE_discord.md` is at most 1,500 characters.

**Tim:**
- [ ] `[G]` G7: download `dist/DeadTired-0.1.0-rc1.zip` from GitHub, unzip into
  `_forever_\Interface\AddOns`: the AddOns list shows **Dead Tired** (and, from the other zip,
  **Dead Tired Probe**).
- [ ] `[G]` G8: on launch night, after card 1's own walk passes, walk cards 3-7's sheets on this
  build. A card that fails is noted; the others still count.
- [ ] `[H]` H1: **reading the guildie guide as a new member would: is it clear what's shared and
  how to turn it off, and would you post the announcement as it is?**
