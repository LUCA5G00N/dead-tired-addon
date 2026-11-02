# Cowork brief: DEAD TIRED rulings round (amend cards 3, 5 and 6 before launch)

Read first, in order:
1. `CLAUDE.md` on `main` (it now has a *Ruled exceptions* section and the stop-condition rule).
2. This brief and its walk-sheet, `docs/UAT_dt_rulings.md`.
3. On each branch you amend: that card's brief, walk-sheet and report
   (`docs/COWORK_BRIEF_dt_<slug>.md`, `docs/UAT_dt_<slug>.md`, `docs/COWORK_REPORT_dt_<slug>.md`).
4. `reference/SPEC_forever_namespaces.md`: search it, don't read it top to bottom.

**Draft-status: ratified by Tim 2026-11-02** (rulings A1-A4 below, chosen by Tim in the review
of 2026-11-02). Written against the branch heads below. No card has been walked in game; Forever
goes live Wed 2026-11-04, 11pm UK. If a head has moved, re-read that card's files before trusting
this brief's names.

| Branch | Head when written |
|---|---|
| `card/dt_crypt` | `f73817b` |
| `card/dt_prep` | `1132d64` |
| `card/dt_stretch` | `8115dd3` |

## Origin

A review of the overnight build (2026-11-02) pulled four ratifications out for another look.
Tim agreed with all of them and ruled on each. Nothing is merged yet, so the cards are amended
on their own branches rather than fixed after launch.

## Precondition

- P1: `main` has the *Ruled exceptions* section in `CLAUDE.md`.
- P2: each of the three branches exists and its `DeadTired/tests/run_all.sh` exits 0 before you
  change anything.

## The rulings (ratified)

- **A1 (card 5, `dt_prep`): recruitment is officers only, to General.**
  - `/dt recruit` works only when `C_GuildInfo.IsGuildOfficer()` returns `true`. Anything else
    (false, nil, absent, secret, an error) refuses with one line and posts nothing.
  - The channel is **General**. General's name carries the zone ("General - Orgrimmar"), so the
    addon must not assume a channel number or the bare name. It finds the channel by scanning
    the player's joined channels for one whose name is `General` or begins `General - `, using
    whichever of `GetChannelList` / `GetChannelName` exists (both are globals: guard every call).
    Not found: refuse with the existing "join first" style line, nothing posted.
  - `RECRUIT_CHANNEL` in `RecruitLines.lua` becomes `"General"`, and the matching rule above is
    applied to it. The 15-minute per-account cooldown stays.
- **A2 (card 3, `dt_crypt`): your own hardcore death is opt-in, mentioned once.**
  - A death is sent only when `crypt.share == true`, on any character. `nil` now means off.
  - On a hardcore character that is a member, with `share` never set, one line prints at login,
    once per character, ever (stored per character key):
    `This one's hardcore. If it falls, the guild won't hear unless you /dt rip share on.`
    It never prints again for that character, including after `/reload`, and never once `share`
    has been set either way.
- **A3 (card 6, `dt_stretch`): play time is sent only after a typed `/played`.**
  - Hook the `/played` slash command itself (`SlashCmdList.PLAYED`, via `hooksecurefunc`,
    guarded) to stamp the time it was used. On `TIME_PLAYED_MSG`, send only if sharing is on
    and that stamp is under 10 seconds old; then clear the stamp. A play-time report caused by
    anything else (another addon calling the request function) is ignored.
  - If the hook can't be placed at load (`SlashCmdList.PLAYED` not a function, or the hook
    fails), nothing is ever sent, and `/dt slowest share on` says so in one line.
- **A4 (card 6, `dt_stretch`): stash lists an item only when it is known not to be bound.**
  - Listed only if the container info says `isBound == false`, or, when that field is `nil`,
    `C_Item.IsBound` for that bag slot returns `false`. Unknown means not listed.
  - The share-on line also says that answers name the character holding the item. Keep the line
    short and in the house tone.

## Deliverable

Each of the three branches carries its card amended to its ruling, with its brief, walk-sheet and
report updated to match, and its `run_all.sh` exiting 0. Every new or changed guard listed in
Task 6 has been removed once and turned a check red.

## Working rules

- One branch at a time, in the order of the tasks. Each branch gets its own commit(s); nothing
  from one card is copied into another.
- **Start each branch by merging `main` into it** (it brings the new `CLAUDE.md`). Card 1's files
  must come out of that merge unchanged; if they don't → stop.
- Touch only the files named for that branch in its task. No card 1 file changes.
- Update the card's brief the way card 6's stash amendment did: an *Amended 2026-11-02 (rulings
  round)* note at the top, and each changed line marked *(amended)*.
- Player-facing text stays short and in the house tone. The A2 line is given; write nothing else
  new beyond what the tasks need, and list every new line in the report.
- Guarded reads (`try`, `clean`) for every game call, as each card already does.

## Tasks

1. **Check the API.** In `reference/SPEC_forever_namespaces.md` confirm `C_GuildInfo.IsGuildOfficer`
   and `C_Item.IsBound` are listed. Record each with its line. Missing → stop.
2. **`card/dt_crypt` (A2).** Files: `DeadTired/Crypt.lua`, `DeadTired/tests/test_crypt.lua`,
   `docs/COWORK_BRIEF_dt_crypt.md`, `docs/UAT_dt_crypt.md`, `docs/COWORK_REPORT_dt_crypt.md`.
   - Send condition becomes `share == true`. Add the once-per-character hardcore line.
   - Tests: a hardcore death with `share` unset sends nothing; with `share` on it sends; the
     line prints once on a hardcore member's first login, not on the second login or a
     `/reload`, not on a normal character, not for a non-member, not once `share` is set.
   - Walk-sheet: rewrite G6 and G11 to match (see `docs/UAT_dt_rulings.md`, *Card 3*).
   - Report: append a section *Rulings round (A2)*.
3. **`card/dt_prep` (A1).** Files: `DeadTired/Recruit.lua`, `DeadTired/RecruitLines.lua`,
   `DeadTired/tests/test_recruit.lua`, `docs/COWORK_BRIEF_dt_prep.md`, `docs/UAT_dt_prep.md`,
   `docs/COWORK_REPORT_dt_prep.md`.
   - Officer gate, General lookup, the one chat call site unchanged in number (still one).
   - Tests: a non-officer is refused and nothing is sent; `IsGuildOfficer` absent, nil or
     erroring is refused; an officer posts to the channel whose name begins `General - `;
     a joined channel named `Generalists` is **not** matched; no General joined is refused;
     the cooldown and the 24-game-hour no-automatic-post test still pass.
   - `RecruitLines.lua` is still generated from `docs/RECRUIT_lines.md` and still byte-identical
     for the five lines (G5 of card 5). Only `RECRUIT_CHANNEL` changes in its data block.
   - Walk-sheet: rewrite G10 and G11 and add the officer check (see `docs/UAT_dt_rulings.md`,
     *Card 5*).
   - Report: append *Rulings round (A1)*.
4. **`card/dt_stretch` (A3, A4).** Files: `DeadTired/Played.lua`, `DeadTired/Stash.lua`,
   `DeadTired/tests/test_played.lua`, `DeadTired/tests/test_stash.lua`,
   `docs/COWORK_BRIEF_dt_stretch.md`, `docs/UAT_dt_stretch.md`, `docs/COWORK_REPORT_dt_stretch.md`.
   - A3 tests: typed `/played` then the event within 10 s sends; the event with no typed
     `/played` sends nothing; the event 11 s after sends nothing; a second event after one
     send sends nothing (stamp cleared); hook unavailable means nothing is ever sent and the
     share-on line says so; the function that requests play time is still never called.
   - A4 tests: `isBound == false` listed; `isBound == true` skipped; `isBound == nil` with
     `C_Item.IsBound` false listed, true skipped, absent / erroring skipped. Same for a bank slot.
   - Walk-sheet: add the checks under *Card 6* in `docs/UAT_dt_rulings.md`.
   - Report: append *Rulings round (A3, A4)*.
5. **Re-run** every branch's `run_all.sh`; all exit 0.
6. **Guard proofs.** Remove each once, run the suite, confirm red, restore:
   1. A2 send condition (`share == true`);
   2. A2 once-per-character store;
   3. A1 officer gate;
   4. A1 General name match (exact `General` or `General - ` prefix);
   5. A3 typed-`/played` window;
   6. A3 stamp cleared after a send;
   7. A4 bound status unknown → not listed.
   The stop-condition rule in `CLAUDE.md` applies: a weak test may be strengthened, test-side
   only, and reported.
7. **Push** each branch. If this session can't push to `card/*` branches, push each to
   `claude/rulings-<slug>` and say so at the top of the report; Tim moves them.
8. **Report** (below).

## Explicitly out of scope

- Card 1 and card 4: no changes (card 4's rulings stood).
- Card 2 and anything about professions or the request board.
- Merging anything to `main`, or merging card branches into each other.
- A guild-wide recruitment cooldown, rank configuration, or an officer list in `Config.lua`.
  A1 uses the game's own officer flag only.
- Rewording the five recruitment lines, the death notice, or any existing player-facing line
  other than the stash share-on line (A4).
- Changing the bedtime nag, gank board, prep check, events or the stash wire format.

## Stop conditions

- A function in Task 1 is missing from the reference → stop.
- Merging `main` changes a card 1 file, or a task needs a card 1 file changed → stop.
- A branch's `run_all.sh` fails before you start (P2) → stop.
- A1 needs more than one chat call site → stop.
- A3 needs the addon to call the play-time request function → stop.
- A guard removal turns nothing red and the fix would need addon code, not test code → stop.

## UAT: acceptance checks

The offline checks and the in-game check changes are in `docs/UAT_dt_rulings.md`. The in-game
ones are walked on each card's own sheet, after card 1 passes (ROADMAP rule 3).

## Reporting

Write `docs/COWORK_REPORT_dt_rulings.md` on your session branch, and the per-card sections named
in Tasks 2-4 on each card branch. The round report records:
- each branch: its old head, new head, and the files changed (`git diff --stat`);
- Task 1's two lookups with line numbers;
- each guard in Task 6, the check that went red, and any test strengthened;
- every new or changed player-facing line, verbatim;
- anything the brief didn't cover and what you chose.

Never write a `_results.md` file: walking is Tim's.
