# Cowork report: the death leaderboard (0.4.0)

Brief `docs/COWORK_BRIEF_dt_deathboard.md`; walk-sheet `docs/UAT_dt_deathboard.md`. Built 22 Nov 2026 in a cloud
session on **`claude/dt-deathboard`** from `main` at **`5fb6d0a`** (the brief's merge, PR #34). L1–L6 agreed by
Tim, 18:56; built before the Waypointer (Tim, 19:24).

## Counts
| | Suites | Checks | Result |
|---|---|---|---|
| Baseline (`5fb6d0a`, 0.3.7) | 28 + taint + textfit | 1,594 | ALL GREEN |
| This round | 29 + taint + textfit | 1,673 | ALL GREEN |

New and changed checks:
- `test_deathboard` 67, new;
- `test_ghost` 45 → 52: `all` now says 5 things, and the ghost's tally (13 total, 2 this week, purged on off);
- `test_selftest` 56 → 60: the TALLY sample, the deathboard's cap in S9, the reset timer in S4.

The version lines in `test_core`, `test_who` and `test_selftest` move from 0.3.7 to 0.4.0. The module order
in `test_core` gains `deathboard` after `played`. `tests/harness.lua` now measures `|T…|t` as one icon
(two characters), `||` as one, and colour codes as nothing, the way the client draws them. No other suite
changed, and the libraries are unmodified.

## What landed
- **`DeathBoard.lua`** (new; in the `.toc` after `Played.lua`): the module `deathboard`, its saved key
  `DeadTiredDB.deathboard = { mine, board, badTally }`, and these parts:
  - the L2 seed;
  - the L3 week;
  - `TALLY` sends, receives and withdrawals;
  - the window, `/dt deaths` ("Body Count"), with its footer;
  - the `fit` for `/dt debug fit`.
- **`Crypt.lua`:** one line, `DT.signal("mydeath")`, the last line of `onDead`.
- **`UI.lua`:** two small additions the board needed (see "What the brief got wrong"):
  - a `raw = true` list column, used for the skull;
  - `vp:setFooter(text)`, for the deadliest-zone line.
- **`Ghost.lua`:** `/dt debug ghost tally`, which also joins `all`.
- **`Selftest.lua`:** a `TALLY` sample (used by S8 and S10), `deathboard.board` capped at 200 in S9's caps,
  and `C_DateAndTime.GetSecondsUntilWeeklyReset` in S4's list.
- **`Migrate.lua`:** unchanged. The seed is made the first time a character needs its tally, from the
  graveyard, so it needs no migration.
- **Version:** 0.4.0 (`.toc` and `DT.VERSION`).
- **Docs:** `FEATURES.md` *Ruled 22 Nov (for `dt_deathboard`, 0.4.0)*, and `docs/RELEASE_0.4.0.md`.
- Nothing was copied from `reference/`.

## The seed, on a harness character with planted deaths
The graveyard holds five deaths:
- three of Stromham's own: 9 days ago, 5 days ago and 1 day ago. The week started 4 days ago, so only the last
  is this week;
- one of another character on the same account;
- one heard from Echo.

The result is **n = 3, w = 1, we = this week's reset**. After a death was planted in the graveyard and the
character reloaded, the tally still reads 3, because it is seeded only once. One `PLAYER_DEAD` then gives 4
total and 2 this week. A brand-new character's first death seeds and is counted once (1), and the next makes it 2.

## Guard proofs
`lua5.1 tools/guard_proofs.lua`: **196 guards, every one red, every file restored**. That is the 176 already
proved (0.3.7's and earlier) plus the 20 below.

| Guard | File | Change | Suite | Result |
|---|---|---|---|---|
| deathboard: share gate on sending (L1) | `DeathBoard.lua` | line removed | test_deathboard | **red**: L2 seed: sharing off, nothing sent at login; a death with sharing off: nothing sent; share off: a death sends no TALLY (+5 more) |
| deathboard: share off withdraws (L1) | `DeathBoard.lua` | line removed | test_deathboard | **red**: share off: TALLY {off=1} sent; share off: receivers delete the entry, and your own is gone; module off: switching share off still withdraws (+2 more) |
| deathboard: the withdraw even while off (L1) | `DeathBoard.lua` | `if v == false then if DT.enabled("deathboard") then withdraw() end` | test_deathboard | **red**: module off: switching share off still withdraws |
| deathboard: receivers delete on off=1 | `DeathBoard.lua` | line removed | test_deathboard | **red**: share off: receivers delete the entry, and your own is gone; module off: switching share off still withdraws; share off removes you from every board (+1 more) |
| deathboard: TALLY validation | `DeathBoard.lua` | `v = v or { n = 1, w = 0, we = 0, hc = false }` | test_deathboard | **red**: validation: every bad TALLY counted under badTally, none kept |
| deathboard: w never over n | `DeathBoard.lua` | `if n > MAXN then return nil end` | test_deathboard | **red**: validation: every bad TALLY counted under badTally, none kept |
| deathboard: board cap 200 | `DeathBoard.lua` | line removed | test_deathboard | **red**: cap: the board keeps 200; cap: the ones heard longest ago went; the newest is kept |
| deathboard: 30-day drop | `DeathBoard.lua` | line removed | test_deathboard | **red**: 30 days: entries not heard for 30 days drop off; a fresh one stays; 30 days: dropped at load too, and an entry with no time |
| deathboard: week zeroing, own (L3) | `DeathBoard.lua` | `if false then` | test_deathboard | **red**: L3 own: past the reset, this week reads 0; the total stays; L3: a death in the new week counts 1; a week rolling over zeroes this week everywhere |
| deathboard: week zeroing, received (L3) | `DeathBoard.lua` | line removed | test_deathboard | **red**: L3 received: past its we, the guildie's row reads 0 this week; a week rolling over zeroes this week everywhere |
| deathboard: we 0 is never zeroed (L3) | `DeathBoard.lua` | `if type(e.we) == "number" and now and now >= e.we then return 0 end` | test_deathboard | **red**: L3 received with we 0: never zeroed (20 days on) |
| deathboard: seed once per character (L2) | `DeathBoard.lua` | `m[me] = seed(me)` | test_deathboard | **red**: L2 seed once: a reload doesn't count the graveyard again; a death adds 1 to the total and the week; L3 no reset readable: this week is never zeroed |
| deathboard: seed counts own deaths only (L2) | `DeathBoard.lua` | `if type(e) == "table" then` | test_deathboard | **red**: L2 seed: the character's own graveyard deaths (3), not another character's or heard ones; L2 seed: this week counts those since the last reset (1); L2 seed once: a reload doesn't count the graveyard again (+1 more) |
| deathboard: off ignores inbound | `DeathBoard.lua` | line removed | test_deathboard | **red**: module off: inbound ignored; module off: a bad one isn't even counted |
| deathboard: off sends nothing | `DeathBoard.lua` | line removed | test_deathboard | **red**: module off: a death sends nothing; module off: switching share off still withdraws |
| deathboard: off verb does nothing else | `DeathBoard.lua` | line removed | test_deathboard | **red**: module off: /dt deaths says so and shows nothing |
| deathboard: guild gate, send | `DeathBoard.lua` | line removed | test_deathboard | **red**: outside the guild: the send refuses before Comms, keeping no entry of its own; outside the guild: nothing received |
| deathboard: guild gate, inbound | `Comms.lua` | line removed | test_deathboard | **red**: outside the guild: nothing received |
| deathboard: Crypt's mydeath signal | `Crypt.lua` | line removed | test_deathboard | **red**: a death adds 1 to the total and the week; L2: a first-ever death seeds from the graveyard and is counted once; ...and the next adds one (+12 more) |
| deathboard: the raw column only where declared (UI) | `UI.lua` | line removed | test_deathboard | **red**: L5 the skull is drawn as the icon, not escaped text; fit: nothing over in the deaths window under any skin |

**Test strengthened (CLAUDE.md's one exception).** The first run had one guard that went NOT RED:
removing Comms' send gate. The deathboard checks the guild itself before it reaches Comms, so removing the
Comms gate alone changes nothing. That Comms gate is still proved by `test_guild`. The proof here now targets
the deathboard's own gate, and `test_deathboard` gained one check that can see it (test files only):

```diff
   check("outside the guild: no TALLY sent", #x.sent == 0)
+  check("outside the guild: the send refuses before Comms, keeping no entry of its own",
+    x.DT._deathboard.sendTally() == false and x.DT.deathBoard()[x:key()] == nil)
```

## Player-facing text, verbatim
- Window title: `Body Count`
- Rows: the skull (`|TInterface\TargetingFrame\UI-RaidTargetingIcon_8:0|t`, hardcore only), then the name,
  `<n> total` and `<w> this week`. The tooltip shows the name, plus `Hardcore` where it applies.
- Empty state: `No deaths shared yet. /dt rip share on to join the board.`
- Footer: `<zone> claimed <n> this week. Older deaths may not be counted. Only guildies running the addon who share their deaths.`
  With no deaths this week, it starts at `Older deaths may not be counted.`
- Switched off: `deathboard.enabled = off`
- The On card: `The death leaderboard, /dt deaths. Off, it shows nothing and hears no tallies. Sharing your own count follows /dt rip share.`
- The ghost: `/dt debug ghost tally` says `The Restless Ghost: tally.` `all` now says `The Restless Ghost said 5 things.`

## The zip
`dist/DeadTired-0.4.0.zip`: 194,103 bytes, sha256 `7bc1d81c178c0207239581cca0b59710b32dae404d62feac13099e6eac525d38`.
`diff -r` against the checkout (tests excluded) is clean.

## What the brief got wrong, or left open
1. **The signal line.** The brief has `DT.signal("mydeath", e)`, but `onDead` has no `e`: the death record is
   built inline in the `record(...)` call. It landed as `DT.signal("mydeath")`, still exactly one line, at the
   end of `onDead`, after the `DEATH` send. An error in the board can't stop your death being shared. The
   board needs nothing from the record.
2. **The skull.** DT's list escapes every `|` in a cell, so a texture escape shows as text. `UI.lua` gains
   `raw = true` for a column whose values the module sets from a constant (guarded, proved). `/dt debug fit`
   measures that column the same way. In the harness, escapes are measured as the client draws them.
3. **The footer changes.** Viewport footers were fixed when the window was built. `vp:setFooter` sets new
   text and moves the body up or down to fit. The skins re-inset it as before.
4. **Sending when sharing goes on.** L1 names two sends: after a death, and 10 s after login. Walk-sheet G6
   (`/dt rip share on`, then `/dt deaths`, "you're listed") needs a third: switching sharing on sends your tally
   at once. Otherwise guildies wouldn't see you until your next death or login.
5. **Crypt off.** Crypt's On card says that off, DT "neither hears nor shares deaths". So the tally is sent
   only while both the board and Crypt are on. The withdrawal, as ruled, is sent whatever the switches.
6. **S4.** L3 says S4 would show an unreadable reset, but the timer wasn't in S4's list. It is now.

## Questions for Tim
1. **Your count while the board is off.** Your own deaths still add to your own tally while the board is off.
   Nothing is sent or printed then, so the count is right when you switch it back on. If "off handles nothing"
   should cover that too, it's one line to change.
2. **Late joiners.** Like the slowest board, a guildie who installs 0.4.0 sees each sharer only after that
   sharer's next login or death. Fine for a guild that logs in daily. A "send me your tallies" ask would be its
   own small round, if it ever matters.
