# Cowork report: the Crypt's Table, round 2 (0.7.0)

Brief: `docs/COWORK_BRIEF_dt_gamble2.md` (T1–T12, ratified by Tim's merge of PR #42, with his comment accepting the
proposals as written). Walk-sheet: `docs/UAT_dt_gamble2.md`. Built 24 Nov 2026, 22:35–23:20. **Not walked.**

## Branch and heads
`claude/dt-gamble2`, from `main` at `fba3cd7` (0.6.0 released, PR #42 merged). PR to `main`, not stacked.

## Task 1: baseline
- `run_all.sh` on the base: ALL GREEN.
- "Read first" re-read. `DT.whoRows()` gives this session's DT runners (`when == "this session"`). Modules get bar
  buttons through `ldb`. Gank reads the target through `GetUnitName("target", true)`.
- **0.6.0's `GAME` validation lets an unknown field through:** it checks `g`, `k`, `s` and `o` only. Proved in the
  harness (T9: a `GAME` with `re` is accepted as a challenge by the pre-T10 path).
- `PlaySound` is in the SPEC (a global, and in `C_Sound`). **`SOUNDKIT` isn't in the reference** (it's a FrameXML
  constants table, not an API). The sound uses `SOUNDKIT.READY_CHECK` when the table is there, and its ID, 8960,
  when it isn't. The walk (H2) tells us if it plays.

## Counts per suite (after)
alts 28 · **bar 82** (expectations updated, see below) · comms 46 · core 37 · crypt 126 · deathboard 67 · debug 45 ·
events 45 · eventslist 4 · **gamble 216 (was 141)** · gank 82 · ghost 52 · guild 39 · keys 48 · logs 140 ·
migrate 71 · played 91 · prep 47 · recruit 104 · recruitlines 7 · **selftest 68 (was 66)** · session 9 ·
settings 33 · settingsview 31 · skins 39 · stash 105 · ui 144 · way 75 · waybooks 5 · who 43 · taint 40 ·
textfit 11 · libs unmodified. **ALL GREEN.**

## What landed
- **`Gamble.lua`:**
  - the New game panel (T1);
  - Accept/Decline (T2), Cancel/Leave (T3);
  - Rematch, Double or nothing, Same again (T4);
  - `readTarget()` (T5);
  - the glow and the sound, with a `gamble.sound` card (T6);
  - an `ldb` launcher (T8);
  - `DECLINE`/`LEAVE` handlers, `FOLD why`, and `GAME re` (T10).
- **New verbs:** `decline`, `cancel`, `leave`, `rematch`, `double`, `again`, `sound on|off`, and
  `deathroll <stake>` (the target).
- **The action buttons are laid out by state**, left to right. At most three show at once, one of them always
  **New game**.
- `Selftest.lua`: `UnitIsPlayer` and `PlaySound` added to `DT.REQUIRED`; `DECLINE` and `LEAVE` samples added
  (19 kinds).
- `CLAUDE.md`: the T5 line under *Reads another player*. `FEATURES.md`: *Ruled 24 Nov (for `dt_gamble2`, 0.7.0)*.
  `docs/RELEASE_0.7.0.md` (names Lilbit).
- `.toc`, `Core.lua` 0.7.0; the test version lines (`test_core`, `test_who`, `test_selftest`).

## Compatibility (T9), from the harness
- A `GAME` carrying `re = "1"` is accepted as a challenge, as 0.6.0 accepts it.
- A deathroll between a 0.7.0 challenger and the old path settles: 1050 / 950.
- **A leaver named in an old host's `CALL` stays out.** The joiner's client marks the game `closed` because it
  left. The old host's table then times out after 2 minutes and nothing moves.

## Guard proofs (Task 7)
44 guards, each removed once and restored, every one red: the 30 from 0.6.0 again, and 14 new.
| New guard | Red check |
|---|---|
| `re` validation | T10: re other than 1 or 2, or on a high-low, is counted and dropped |
| DECLINE validation | T10: a bad DECLINE is counted |
| LEAVE validation | T10: a bad LEAVE is counted |
| decline only from the challenged | T2: a DECLINE from someone else is ignored |
| leave only before the call (host) | T3: a LEAVE reaching the host after the call changes nothing |
| leave only before the call (joiner) | T3: not even from a stale Leave button: no LEAVE sent once rolling |
| cancel only by the host, before rolling | T3: not even from a stale Cancel button: no FOLD sent once rolling |
| double respects the cap | T4: double over 500 is greyed with the reason |
| double respects what you hold | T4: double over what you hold is greyed, with the reason |
| target only a player | T5: an NPC target: refused |
| a named or targeted player must be in your party | T5: a player outside your party: refused (and every D2 party check) |
| sound only when switched on | T6: the sound is off by default: nothing played |
| glow follows your turn | T6: the glow is on for the player whose turn it is |
| a leaver stays out (CALL) | T9: a leaver named in an old host's CALL stays out |

**Tests strengthened during the proofs** (test files only). Five guards first stayed green:
- tests were added for a bad `LEAVE` and for a bad or misplaced `re`;
- stale-button checks were added for Leave and Cancel once rolling;
- a check that a host ignores a `LEAVE` after the call was added;
- a check that Double is greyed when you can't afford it was added.

**The party-member target guard was a duplicate.** `readTarget()` had its own "isn't in your party" check, but
every challenge passes through `startDeathroll`'s party match, which refuses with the same words. Removing the first
check could never turn anything red. So I removed it, and proved the shared check instead: replacing it with
"accept any name" turns T5 and the D2 checks red.

## Player-facing text, new, verbatim
- **Buttons:** `New game`, `Accept`, `Join`, `Decline`, `Roll`, `Final call`, `Cancel`, `Leave`, `Rematch`,
  `Double or nothing`, `Same again`, `Challenge target`, `Open high-low`, `Back`; the stake buttons `10` `50` `100`
  `250` `500`.
- **Panel:**
  - `New game: pick a stake, then a game.`
  - `Nobody else in your party.`
  - `Dead Tired` / `no addon`
  - `Click for a deathroll at the stake above.`
  - `Not running Dead Tired.`
  - `<name> isn't running Dead Tired.`
- **Button tooltips:**
  - Challenge target: `A deathroll with the party member you have targeted.`
  - Open high-low: `A high-low table for your party at the stake above.`
  - Rematch: `The same stake again. They must accept.`
  - Double or nothing: `Twice the stake. They must accept.`
  - Same again: `A new table at the same stake.`
- **Challenges:**
  - `<host> challenges you to a deathroll for <s>. Accept or decline.` (replaces "Join to accept.")
  - `<name> wants a rematch for <s>. Accept or decline.`
  - `<name> says double or nothing: <s>. Accept or decline.`
  - `You offer <name> a rematch for <s>. Waiting for them.`
  - `You say double or nothing to <name>: <s>. Waiting for them.`
- **Endings:** `<name> declined.` · `You declined.` · `<host> cancelled.` · `<name> left the table.` ·
  `You left the table.`
- **Refusals:**
  - `No challenge to decline.` · `No game of yours to cancel.` · `No table to leave.`
  - `No deathroll to replay.` · `Over the 500 cap.` · `No table of yours to run again.`
  - `Target a party member first.`
- **The bell:** `A bell when it's your roll.` · `No bell. You'll have to pay attention.`
- **Settings card:** `Your-turn bell`: "A short sound when it becomes your roll. The Roll button glows either way."
- **Bar tooltip:** `The Crypt's Table` / `You hold <n> chips.` / `Click: the table. Right-click: the ledger.`

## The zip
`dist/DeadTired-0.7.0.zip`: 220,912 bytes, sha256 `b8848cb2785123246db81623e83b73293056e2ab0ff24dc4fa2e854e2415ef94`
(rebuilt after the walk fixes below; earlier builds `fc0dd1a9…88ef`, `62ee3a40…dd14`).
Unzipped, `diff -r -x tests` is clean.

## What the brief got wrong, and where I departed from it
1. **The bar launcher is off until ticked** (`offByDefault`, like Session): `/dt bar add gamble`. Showing it by
   default would add a button to every guildie's bar unasked. It also changes `test_bar`'s fixed expectations
   (object counts and orders), so those were updated to include `gamble-`, test expectations only. G6 on the
   walk-sheet now starts with `/dt bar add gamble`. **Tim:** say if you'd rather it showed by default.
2. **`test_bar.lua` changed**, which wasn't in the working rules' list. It's expectations only, for the reason above.
3. **`SOUNDKIT`** isn't in the reference, so the code falls back to the numeric ID 8960 (see Task 1).
4. **The window now picks which game to show differently.** It shows a clicked game while that game is live, then
   the newest live game you're in or can join, then the clicked one, then the newest. A new challenge to you
   selects itself. Before this, a finished game you'd clicked could hide a new challenge.
5. **Party-member target guard:** the duplicate check was removed, as above.
6. **The challenged player's challenge line is printed** (one `DT.out`). It's the T11-style line for a game you're
   in. Before this the challenge only showed in the window.

## Questions for Tim
- **The bar button: shown by default, or off until ticked** (as built)?
- **Is the bell (READY_CHECK) the right sound?** H2 decides.

## Walk fix (24 Nov, 23:16)
Tim's first screenshot of the New game panel showed two problems:
- **"Challenge target" and "Open high-low" overran their fixed 92-pixel buttons** and ran into each other. "Double
  or nothing" would have done the same.
- The status line showed faintly through the panel.

Fixes:
- **Every button now sizes itself to its label:** its own font string's width plus 24, at least 70. Rows are laid
  out from those widths.
- **The status, the game list and the action buttons hide while the panel is open.** Back brings them back.

New checks:
- every label fits its button;
- the widest rows fit the window;
- the panel hides the status, the list and the buttons, and Back restores them.

Both new guards were proved red: "a button fits its label", and "nothing shows through the panel". The offline fit
check couldn't have caught the first problem, because button labels don't go through `DT.text`.

## Walk fix 2 (24 Nov, 23:52)
**The bug:** the joiner's window showed the wrong game's log after a high-low settled. Tim joined Lilbit's 250 table,
and after it settled his window showed the earlier deathroll's log. His balance was right: 710 − 40 = 670.
- **Cause:** a challenge to you pinned the window to that game (departure 4), and once no game was live, the window
  fell back to the pinned one.
- **Fix:** the window shows the most recently changed game you're in, were challenged to, or can join. A game you
  click stays shown until something newer happens in one of those.
- The check `window: after the high-low settles, the joiner sees the high-low's result` reproduces Tim's sequence.
  It failed before the fix and passes after.
- The "a click holds until something newer" guard was proved red.

Never wrote a `_results.md` file.
