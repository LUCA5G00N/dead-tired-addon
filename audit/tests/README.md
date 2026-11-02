# Audit tests (dt_audit, 2026-11-02)

Offline tests for `docs/AUDIT_2026-11-02.md`. They load each card's **real files from a checkout
of its branch** with that card's own `tests/harness.lua` (card 1's stub style). Nothing here is
loaded by the addon, and no card branch is changed.

## Setup (once per session)

```bash
sh audit/tests/setup.sh
```

This puts a detached `git worktree` of every `card/*` branch in `/tmp/dt-audit-wt/<card>`
(override with `DT_AUDIT_WT=/some/dir`; the tests read the same variable). Re-running moves each
checkout to its branch's current head. Needs `lua5.1`.

## Run

All of them (runs setup first):

```bash
sh audit/tests/run_all.sh
```

One at a time, from the repo root:

| Test | Finding | Card branch loaded | Now |
|---|---|---|---|
| `lua5.1 audit/tests/test_roster_reload.lua` | AUD-01 | `card/dt_foundation` | red (3 checks fail) |
| `lua5.1 audit/tests/test_prep_reload.lua` | AUD-02 | `card/dt_prep` | red (1 fails) |
| `lua5.1 audit/tests/test_stash_reload.lua` | AUD-03 | `card/dt_stretch` | red (1 fails) |
| `lua5.1 audit/tests/test_gank_reboot.lua` | AUD-04 | `card/dt_pvp` | red (2 fail) |
| `lua5.1 audit/tests/test_realm_spelling.lua` | AUD-06 | `card/dt_prep` (card 1 files + Prep) | red (2 fail) |
| `lua5.1 audit/tests/test_death_flood.lua` | AUD-07 | `card/dt_crypt` | red (2 fail) |
| `lua5.1 audit/tests/test_traffic.lua` | traffic section | every card, modules merged in the test | green; prints the numbers |

A reproducing test asserts what the audit says *should* happen, so **red now is the finding
reproduced**, and the check's name says what the player would see. Where a test has a "baseline"
check (the same flow before the trigger), it passes, so the red checks are not the harness
failing.
After a fix round, each test should go green without changes.

`test_traffic.lua` merges the module lists of cards 1, 3, 4, 5, 6 and 7 into one client (18
files, in the order the merged `.toc` would load them), 20 clients on one bus, and runs five
scenarios (S1-S5). Its checks are "nothing dropped" and "the raid-night roll call gets every
answer"; the other numbers are printed for the audit. It is deterministic (seeded).

## Files

- `setup.sh`: the worktrees.
- `lib.lua`: loads a card's harness from its checkout; `L.reload()` models a `/reload` (the old
  Lua state dropped, a new instance on the same SavedVariables, `PLAYER_ENTERING_WORLD(false, true)`).
- `test_*.lua`: one per finding above, plus the traffic simulation.
