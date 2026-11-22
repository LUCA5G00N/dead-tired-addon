# Walk-sheet: the self-test and the pretend guildie (0.3.5)

Brief: `docs/COWORK_BRIEF_dt_selftest.md`. **[G]** offline = the build session proves it in its report;
**[G] in game** = Tim types the command and `/reload`s, and the result is read from
`SavedVariables\DeadTired.lua` (no judgement); **[H]** = Tim's judgement. **6 [G] offline, 3 [G] in game,
2 [H].** Back up `SavedVariables\DeadTired.lua` first. Screenshot the [H] checks.

## Offline [G]
- [ ] G1 `run_all.sh` ALL GREEN with counts; zip `diff -r` clean; `.toc`/`DT.VERSION` 0.3.5.
- [ ] G2 Every S-check passes on a healthy harness client, and each has a harness case that makes it fail
      (named in the report).
- [ ] G3 On a harness client whose realm calls return `""` with no fallback, S3 fails.
- [ ] G4 Ghost HELLO, DEATH, GANK, PLAYED, STASH and PREP each reach their handler through `inbound`; the
      ghost answers STASHQ, PREPQ and WHO; nothing reaches AceComm.
- [ ] G5 No `DTGHOST` in `DeadTiredDB` after `ghost off`, after `PLAYER_LOGOUT`, and after a load with ghost
      entries planted; comms `received`/`senders`/`mismatches` unchanged by ghost messages.
- [ ] G6 Every Task 7 guard removed → a named check red → restored.

## In game [G] (Tim types; the saved file decides)
- [ ] G7 `/dt selftest`, then `/reload`: `DeadTiredDB.selftest` has `fail = 0`, `version = "0.3.5"`, and a
      `key` on your realm.
- [ ] G8 `/dt debug ghost on`, `/dt debug ghost all`, `/dt stash <anything>`, then `/dt debug ghost off`
      and `/reload`: no `DTGHOST` anywhere in the saved file.
- [ ] G9 After G8, `/dt debug errors`: no module error count above its pre-walk value.

## In game [H]
- [ ] H1 With the ghost on: `/dt who`, the ghost's death notice, `/dt graveyard`, `/dt stash <term>`. Does
      each read plainly as the ghost (you'd never mistake it for a real guildie), and does it look right?
- [ ] H2 With the ghost answering, would you now count the stash check (the old H4) and the "DT: N online"
      check (P1) as walked, without waiting for a second guildie? If not, say what's still missing.
