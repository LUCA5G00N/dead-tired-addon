# Cowork report: dt_rulings (amend cards 3, 5 and 6 before launch)

Brief: `docs/COWORK_BRIEF_dt_rulings.md` (A1-A4 ratified by Tim 2026-11-02). Walk-sheet:
`docs/UAT_dt_rulings.md`. Built 2026-11-02 in a cloud session, offline only.

**Result:** all three card branches are amended and **pushed to their own `card/*` branches**
(no fallback `claude/rulings-*` branches were needed). Every `run_all.sh` exits 0. All seven Task 6
guards were proved red on the first try; no test had to be strengthened after a failed proof.
**No stop condition tripped.** Nothing was merged to `main` or between cards.

This report lives on the session branch `claude/quirky-rubin-43vh9k` (cut from `main` at `2043202`).

## Preconditions

- P1: `main` (`2043202`) has the *Ruled exceptions* section in `CLAUDE.md`. Yes.
- P2: branch heads matched the brief exactly (`card/dt_crypt` `f73817b`, `card/dt_prep` `1132d64`,
  `card/dt_stretch` `8115dd3`), and each `run_all.sh` exited 0 before any change
  (crypt 72, recruit 33, played 23 checks, all green).
- `lua5.1` was not installed; installed with `apt-get install -y lua5.1` (Lua 5.1.5).

## Task 1: API lookups (`reference/SPEC_forever_namespaces.md`)

| Function | Line | Section header |
|---|---|---|
| `C_GuildInfo.IsGuildOfficer` | 1511 (`Invite, IsDiscordStreamSeparate, IsEncounterGuildNewsEnabled, IsGuildOfficer`) | 1504, `` ### `C_GuildInfo` — 39 `` |
| `C_Item.IsBound` | 1822 (`IsBound, IsBoundToAccountUntilEquip, IsConsumableItem, IsCorruptedItem`) | 1796, `` ### `C_Item` — 121 `` |

Both present. Not in the reference (globals, guarded): `GetChannelList`, `GetChannelName`,
`MAX_WOW_CHAT_CHANNELS`, `hooksecurefunc`, `SlashCmdList`, `ItemLocation`.

## Branches

Each branch started by merging `main`. That merge brought `CLAUDE.md`, `docs/COWORK_BRIEF_dt_rulings.md`
and `docs/UAT_dt_rulings.md` and **changed no card 1 file** on any branch.

### `card/dt_crypt` (A2): `f73817b` → `6d15835`

Commits: `759877e` (merge `main`), `6d15835` (A2).

```
 DeadTired/Crypt.lua            | 28 +++++++-
 DeadTired/tests/test_crypt.lua | 92 ++++++++++++++++++---
 docs/COWORK_BRIEF_dt_crypt.md  | 52 +++++++-----
 docs/COWORK_REPORT_dt_crypt.md | 38 +++++++++
 docs/UAT_dt_crypt.md           | 12 ++-
```
(plus the merge's `CLAUDE.md`, `docs/COWORK_BRIEF_dt_rulings.md`, `docs/UAT_dt_rulings.md`)

### `card/dt_prep` (A1): `1132d64` → `02d199f`

Commits: merge `main`, `02d199f` (A1).

```
 DeadTired/Recruit.lua            |  45 ++++++++++-
 DeadTired/RecruitLines.lua       |   2 +-
 DeadTired/tests/test_recruit.lua | 116 +++++++++++++++++++++++---
 docs/COWORK_BRIEF_dt_prep.md     |  37 ++++++---
 docs/COWORK_REPORT_dt_prep.md    |  48 +++++++++++
 docs/UAT_dt_prep.md              |  13 +--
```
(plus the merge's three files)

### `card/dt_stretch` (A3, A4): `8115dd3` → `1114f90`

Commits: merge `main`, `1114f90` (A3, A4).

```
 DeadTired/Played.lua             |  26 +++++-
 DeadTired/Stash.lua              |  20 ++++-
 DeadTired/tests/test_played.lua  | 101 ++++++++++++++++++++---
 DeadTired/tests/test_stash.lua   |  69 +++++++++++++++-
 docs/COWORK_BRIEF_dt_stretch.md  |  38 +++++++--
 docs/COWORK_REPORT_dt_stretch.md |  67 +++++++++++++++
 docs/UAT_dt_stretch.md           |   9 ++-
```
(plus the merge's three files)

Only the files the brief names for each branch were touched. Each card's brief carries an
*Amended 2026-11-02 (rulings round)* note with changed lines marked *(amended)*; each card's report
has its *Rulings round* section with the detail.

## Task 5: re-run

| Branch | `run_all.sh` | Suite counts changed |
|---|---|---|
| `card/dt_crypt` | exit 0, ALL GREEN | crypt 72 → 88 |
| `card/dt_prep` | exit 0, ALL GREEN | recruit 33 → 55 |
| `card/dt_stretch` | exit 0, ALL GREEN | played 23 → 47, stash 48 → 74 |

## Task 6: guard proofs

Each removed once, its suite run, red confirmed, restored, suite green again.

| # | Guard | Removal | Checks that went red |
|---|---|---|---|
| 1 | A2 send condition (`share == true`) | `if c.share == true` → `if true` | 13, incl. *A2: hardcore, share unset: nothing sent, the guildie hears and records nothing* |
| 1b | (same, put back to the old R2 rule) | `share == true or (share == nil and hc)` | 6, incl. *A2: share unset, a hardcore death is recorded but not sent* |
| 2 | A2 once-per-character store | `c.hcTold[me]` check removed | *A2: not after a /reload*, *A2: not on the second login* |
| 3 | A1 officer gate | `if not isOfficer()` → `if false` | all 7 *A1: IsGuildOfficer … refused, nothing posted* (false, nil, string, erroring, `C_GuildInfo` absent, function absent, secret) |
| 3b | (gate loosened to truthy) | `== true` dropped | *A1: IsGuildOfficer a string, not true* |
| 4 | A1 General name match | `" - "` prefix → bare `General` prefix | *General - <zone> is matched*, *Generalists is not General*, *no near misses*, *the match rule* |
| 4b | (match exact only) | prefix branch dropped | *a post: line 1 … General - Orgrimmar's number* and 5 more; suite then errors out (non-zero) |
| 4c | (match removed) | `return true` | 7, incl. *not in General: refused* |
| 5 | A3 typed-`/played` window | whole condition → `if false` | 10, incl. *the event with no typed /played sends nothing*, *a report someone else asked for: ignored*, *hook absent: nothing is ever sent* |
| 5b | (age check only) | `DT.now() - at >= 10` dropped | *the event 11 s after the typed /played: nothing* and 3 more |
| 6 | A3 stamp cleared after a send | `typedAt = nil` removed | *A3: the stamp is cleared after the send*, *and that stale stamp is gone too* |
| 7 | A4 bound status unknown → not listed | `bound == false` → `bound ~= true` | 13, incl. *isBound nil, C_Item.IsBound nil: skipped* (bags, bank, bank bag) and *a secret IsBound answer* |

**No test was strengthened after a failed proof.** Two notes on how proofs were made:
- **Guard 6** is shadowed in behaviour by card 6's existing 60 s send window (a stamp lives 10 s,
  so a second report it could let through is always inside 60 s of the send). So its check reads
  the stamp through a test hook (`DT._played.stamp()`), written that way from the start.
- One guard I first wrote could **not** be proved: a `hooked` flag check inside the A3 event
  handler. It was redundant (no hook means no stamp, and guard 5 refuses). I removed it from
  `Played.lua` rather than keep an unproved guard; guard 5 now carries "no hook, nothing sent",
  and its removal turns the three *hook … nothing is ever sent* checks red.

## Offline walk-sheet checks (`docs/UAT_dt_rulings.md`)

- R1: all three `run_all.sh` exit 0 (above).
- R2: the seven guards are in the table above, each with what went red.
- R3: `git diff card/dt_foundation --stat -- DeadTired/` on each branch names only that card's own
  files plus the `.toc` and `run_all.sh` lines it already had (crypt: `DeadTired.toc | 1 +`,
  `run_all.sh | 2 +-`; prep and stretch: `DeadTired.toc | 4 +`, `run_all.sh | 2 +-`).
- R4: `card/dt_prep`: `DeadTired/Recruit.lua:101:  local say = C_ChatInfo and C_ChatInfo.SendChatMessage`
  (one line).
- R5: `card/dt_stretch`: `RequestTimePlayed` grep finds nothing (exit 1).
- R6: each amended brief has the note (one each).

## Player-facing lines, new or changed (verbatim)

- **New (A2, given by the brief):** `This one's hardcore. If it falls, the guild won't hear unless you /dt rip share on.`
- **New (A1):** `Officers only. The rest of us just haunt the place.`
- **New (A3):** `sharing your /played, but this client hides when you type it. Nothing will be sent.`
- **Changed (A4):** `stash sharing on. Guildies' searches see your tradeable items, four at a time, and which character holds them.`
  (was `… can see your tradeable items, four at a time.`)
- **Changed value only, wording unchanged:**
  - `/dt rip` → `notices on; sharing your deaths off.` while `share` was never set (was
    `default (hardcore only)`).
  - `Posted line <i> of 5 to General.` and `You're not in General. /join General first.` (the
    channel name was `LookingForGroup`).

## What the brief didn't cover, and what I chose

1. **`/dt rip`'s status for `share == nil`.** It printed `default (hardcore only)`, which A2 makes
   false. I show `off`. This changes a value shown, not the line's wording.
2. **`/dt recruit next` is not officer-gated.** It posts nothing; A1 gates the post. A non-officer
   can still see which line is next.
3. **The officer refusal comes first**, before the lines, cooldown, lockdown and channel checks, so
   a non-officer only ever sees that line.
4. **General lookup order:** `GetChannelList()` id/name triples first, then `GetChannelName(n)` for
   n = 1 to `MAX_WOW_CHAT_CHANNELS` (20 if that global is missing or odd). The first id above 0
   with a matching name wins. Case matters: `general - orgrimmar` is not matched.
5. **`C_Item.IsBound`'s argument.** On retail it takes an item location, not a bag and slot. The
   location is built with the client's `ItemLocation:CreateFromBagAndSlot(bag, slot)`, guarded; if
   that global is missing or errors, the bound status is unknown and the item is not listed.
6. **A3: the stamp is cleared on every `TIME_PLAYED_MSG`**, not only after a send. This is stricter
   than the brief: one typed `/played` vouches for one report at most.
7. **A2: the hardcore line also fires on card 1's `member` signal**, so a login before the guild
   info arrives still gets it once membership is known. If the character key can't be read yet,
   nothing prints and nothing is stored, so the line waits.

## Not provable offline (for Tim's walk)

- Whether Forever's chat caches slash handlers before addons load (`hash_SlashCmdList`). If it
  does, the `/played` hook never fires and nothing is sent even when typed. That fails safe, and
  the new card 6 check (typed `/played` reaches the guildie's board) will show it.
- General's real channel name on Forever, and whether `GetChannelList` is there.
- Whether `C_GuildInfo.IsGuildOfficer` answers `true` for Tim's rank.
- Whether container info on Forever fills `isBound`, and whether `ItemLocation` exists.
- Whether Forever has hardcore realms (card 3's G11).

`docs/UAT_dt_rulings_results.md` and the cards' `_results.md` files were not written; those are Tim's.
