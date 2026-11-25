# Report: dt_guildquests (0.8.0, guild quests: the sleeping bag arc and the library books)

Built overnight 24–25 Nov from `docs/COWORK_BRIEF_dt_guildquests.md`. The walk-sheet is `docs/UAT_dt_guildquests.md`, and walking it is Tim's job.

## Branch and heads
- Branch: `claude/dt-guildquests`.
- **Departure: the branch is based on `claude/dt-gamble2` (13d35bb), not `main`.** PR #43 (0.7.0) is walked but not merged yet, and 0.8.0 builds on it (version line, selftest kinds, module order). **Merge #43 first.** Once #43 is in, this PR's diff against `main` shows only the 0.8.0 work. It is not stacked in GitHub's sense: the PR targets `main`.

## Counts per suite (`run_all.sh`: ALL GREEN)
alts 28, bar 82, comms 46, core 37, crypt 126, deathboard 67, debug 45, events 45, eventslist 4, gamble 228, gank 82, ghost 52, guild 39, keys 48, logs 140, migrate 71, played 91, prep 47, **questarcs 10 (new)**, **quests 77 (new)**, recruit 104, recruitlines 7, selftest 71, session 9, settings 33, settingsview 31, skins 39, stash 105, ui 144, way 75, waybooks 5, who 43, taint 42, textfit 11. None fail.

## The bag table as built (`QuestArcs.lua`)
| # | Step | Horde ID | Alliance ID | Zone | x, y | Note |
|---|---|---|---|---|---|---|
| 1 | ...and that note you found | 79007 | 79008 | The Barrens | 46.0, 74.0 | Hand-in: Alexston Farmstead, Westfall 37, 50 |
| 2 | Stepping Stones | 79192 | | Stonetalon Mountains | 40.6, 52.4 | |
| 3 | Rekindle (optional) | 80001 | | Stonetalon Mountains | 40.6, 52.4 | Skipped by "next step" |
| 4 | Scramble | 79980 | | Stonetalon Mountains | 39.6, 49.8 | |
| 5 | Wet Job | 79974 | | Loch Modan | 49.4, 12.9 | "Dwarf country. Bring a friend." |
| 6 | Eagle's Fist | 79975 | | Hillsbrad Foothills | 87.3, 49.6 | |
| 7 | This Must Be The Place | 79976 | | Hillsbrad Foothills | 87.3, 49.6 | The Cozy Sleeping Bag |

If you're already on step 1, the next-step waypoint points at the Westfall hand-in rather than the tower.

## The tier lines as built
The tiers are 10 (78150, Friend of the Library), 20 (79536), 25 (82208) and 35 (84394, all three Greater Friend of the Library). A claimed tier is one whose reward quest is flagged done. The line reads, for example: `14 books. 6 more to Greater Friend of the Library (20). Claimed: 10.` Once every tier is claimed, it reads `Every reward reached.`

The books are `DT.WAY_BOOKS` itself, with no second list. Book 79094 was proved in game on 25 Nov at 00:33: false before the hand-in, true after it.

## Guard proofs
Each guard was removed once, a check went red, and the guard was put back. The tree was clean afterwards.

| Guard | Check that went red |
|---|---|
| faction pick | Q2: an Alliance character's step 1 is 79008 |
| Rekindle skip | Q2: steps 1-2 done: next skips Rekindle to Scramble (4) |
| failed read is not done | Q1: a secret read counts as not done |
| tier thresholds | Q3: 10 books: next is 20 |
| turn-in ID filter | Q4: someone else's quest turned in: nothing sent |
| withdraw on share off | Q4: share off sends QUESTS {off=1} |
| share switch (send) | Q4: share off: nothing more sent |
| module switch and guild gate (send) | off: switching sharing on sends nothing while the module is off |
| module switch (inbound) | off: nothing heard |
| off verbs | off: a typed share on changes nothing |
| QUESTS validation | Q4: bad QUESTS are counted and dropped |
| only known book IDs | Q4: bad QUESTS are counted and dropped |
| board cap (200) | Q4: the board caps at 200 |
| 30-day drop | Q4: 31 days unseen: dropped |
| Nearest: this continent only | Q5: none left on this continent: says so |
| first finisher kept once seen | Q6: the first finisher is kept once seen |
| nothing done: nothing sent | Q4: nothing done yet: nothing sent |

The gamble guards were run again on this branch: 44 red, none green.

**Tests strengthened (test files only):** two module-off guards stayed green on the first removal because their checks reached the path by another route. I tightened `test_quests.lua` so that each check drives that path alone, then proved both guards again (they're in the table above). I also replaced a tooltip check that couldn't fail with a real OnEnter check.

## Player-facing text, verbatim
- **Window title:** `Guild quests`. The tabs are `The Sleeping Bag` and `The Library`.
- **Board empty:** `Nobody's sharing yet. Be the first fool on the road.`
- **Board closing line:** `Only guildies running the addon who share their quests.`
- **Board rows:** `Bag: x/7` or `[bag icon] Bag: done`, and `Books: n`. The first-finisher line is `First to the bag: <name>.`
- **Bag tab:**
  - `Next step` (button), `Next: step <n>, <name>`, and for step 1 `(hand it in at Westfall)`;
  - `Done. The Cozy Sleeping Bag is yours.` when the arc is finished;
  - `Handed in by: ` (the guildies who've finished);
  - each step's row carries ` (optional)` where it applies.
- **Library tab:**
  - `Nearest book` (button) and the tier line above;
  - `Click to set the waypoint.` as the row tooltip;
  - `No book by that name.` from the search;
  - the count, `n book.` or `n books.`
- **Chat lines:**
  - `Waypoint: <label>, <zone> x, y.`;
  - `<zone>: zone not found.`;
  - `The bag is yours. Nowhere left to go but to sleep.`;
  - `No unread books on this continent.`;
  - `Your quests are on the guild's board.` and `Your quests are your own again.`;
  - `quests.enabled = off`;
  - `/dt quests [share on|off]`.
- **On card:** `Guild quests: the sleeping bag arc and the library books, read from your own quest log. /dt quests. Off, it reads, sends and hears nothing.`
- A quest the client can't read shows `…`, never a tick.

## Zip
`dist/DeadTired-0.8.0.zip`, 229,850 bytes, sha256 `a1dd56a9d8631c432c82d20a63de6786bb1b2a3a420967a7c5bfff82fd16c625`. Running `diff -r` against `DeadTired/` (tests left out) shows no difference.

## What the brief got wrong, and other departures
1. **Base branch:** built on `claude/dt-gamble2`, as described above.
2. **Nothing to share, nothing sent.** The brief has a login send. A player with no bag steps and no books now sends nothing at all. Without this, every guildie running the addon would post an empty QUESTS at login, and other suites' message counts broke. The guard proof is "nothing done: nothing sent".
3. **The ghost's `quests` line** is in `Ghost.lua`'s SAY table, so `/dt ghost say quests` works, but I didn't add it to ORDER/`all`. That keeps `/dt ghost all` the same length as in 0.7.0. Adding it is one word if you want it.
4. **The tab buttons are home-made** from two DT buttons, because the framework has no tab widget. They behave like tabs, and the open tab is remembered with the window.
5. **The board's `Bag: x/7` counts the steps shared.** It shows "done" once step 7 is in the set, even if the optional Rekindle was skipped, so a finisher can read `done` having shared 6 steps.
6. Selftest gains `C_QuestLog.IsQuestFlaggedCompleted`, `C_QuestLog.IsOnQuest` and `UnitFactionGroup` in REQUIRED, the cap `quests board 200`, and a QUESTS sample (20 kinds).
7. CLAUDE.md gains the Q4 "shares without a separate opt-in" line, as the brief asked.

## Questions
- Do you want the ghost's `quests` line in `/dt ghost all` (departure 3)?
- For the bell: a 0.7.1 patch on gambling that swaps the READY_CHECK sound for the Undercity bell, once you've listened to it in wow.export and given me the FileDataID.
