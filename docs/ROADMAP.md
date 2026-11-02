# Roadmap: the DEAD TIRED guild addon

Source: Tim's idea list, `L5GN/_desk/dead-tired_addon_ideas.md` (2026-11-02). Which features
made the cut is Tim's ruling; **the order of cards below is a proposal** and is settled when
each brief is ratified. Every card from 1 to 7 now has a brief (card 2's is a draft waiting for
the launch-night probe). Later briefs were written against the code card 1 actually landed, not
against this page. **Where each card stands is the next section.**

*This copy merges the fuller roadmap from `claude/loving-meitner-yzdxtn` (`f1d8255`), which
never reached `main`, with card 7 (`dt_logs`), which only `main`'s shorter copy listed. Heads
and check counts are as of 2026-11-02 evening, after fix rounds 1 and 2.*

Budget: promotional cloud credit, **$74 at the start (2026-11-02), expiring 2026-11-04**. Cards
1-5 were the target, the stretch card only if credit was left after card 5; card 6 was built
too, on Tim's ruling (its R6). The build sessions can't see the remaining balance.

## Where every card stands (2026-11-02, evening)

Nothing is on `main` but docs. **No card has been walked in game**; Forever goes live Wed
2026-11-04, 11pm UK. Every built card was audited (`audit/2026-11-02`, `docs/AUDIT_2026-11-02.md`:
16 findings, 0 blockers) and fixed in two rounds (`dt_fixes1`, `dt_fixes2`). Each card branch
carries card 1's fixed head (`696dd87`). `claude/loving-meitner-yzdxtn` is where the briefs for
cards 1-6 were drafted. Card 2's draft brief is still only there.

| Card | Slug | Branch (head) | Brief | Build | Offline tests | In game | Waiting on |
|---|---|---|---|---|---|---|---|
| 1 | `dt_foundation` | `card/dt_foundation` (`696dd87`) | ratified | **built**, 0.1.0; fix round 1 (F1-F5) | 6 suites, 193 checks green | not walked | Tim's walk (`docs/UAT_dt_foundation.md`, incl. G6b), first, on launch night, from the `-card1` zip |
| 2 | `dt_professions` | none yet | **draft, not ratifiable**; R1-R5 proposed | not built | - | - | Tim's launch-night probe (in the brief) written to `docs/PROBE_guild_recipes_results.md`, then a ruling on R1-R5 |
| 3 | `dt_crypt` | `card/dt_crypt` (`f6f97c9`) | ratified (R1-R3), amended (rulings round A2) | **built**; fix round 1 (F6a) | 7 suites, 286 checks green | not walked | card 1 passing, then its walk. Its build report records one tripped stop condition (a weak test for the 3-nag cap), fixed test-side: **accepted by Tim 2026-11-02** (re-proved that evening on `f6f97c9` and rc2: the guard removed turns 2 checks red; with the old check it stays green) |
| 4 | `dt_pvp` | `card/dt_pvp` (`b57c6db`) | ratified (R1-R3) | **built**; fix round 1 (F6b, F7) | 7 suites, 251 checks green | not walked | card 1 passing, then its walk. G11 (an enemy's name in combat) answers a question later cards need |
| 5 | `dt_prep` | `card/dt_prep` (`6fb903b`) | ratified (R1-R5), amended (rulings round: recruit officers only, to General) | **built**; fix round 1 (F6c, F8a) | 8 suites, 298 checks green | not walked | card 1 passing, then its walk. The prep list's item IDs are unverified (G7) |
| 6 | `dt_stretch` | `card/dt_stretch` (`39e636f`) | ratified (R1-R6), amended (4 stash hits, 24-byte holders) | **built**; fix round 1 (F6d, F8b, F9) | 9 suites, 361 checks green | not walked | card 1 passing, then its walk. The Fishing Extravaganza schedule is from memory (G9) |
| 7 | `dt_logs` | `card/dt_logs` (`2558f4c`) | ratified (`main` `7c85aa9`) | **built**; fix rounds 1 and 2 (F12 one prompt at a time, F13) | 7 suites, 315 checks green | not walked | card 1 passing, then its walk (`docs/UAT_dt_logs.md`, incl. G9b), last of the five on launch night |
| - | probe | `card/dt_probe` (`a25b538`) | ratified, amended twice | **built**, separate addon, never merged | probe suite green | not run | launch night, before card 1 |
| - | release | `release/0.1.0-rc2` (`dcaaca4`) | `dt_release`, amended after each fix round | cards 1, 3-7 merged + cross-card suite; `dist/` zips; guides; `docs/LAUNCH_NIGHT.md` | 15 suites, 766 checks green | - | never merged to `main`: it is what gets installed. Cards merge to `main` one by one, from their own branches |
| - | `dt_professions_native` | - | not written | - | - | - | only if the probe says `Native: works` (card 2's R1); written after card 2 is built |
| - | crafting request board | - | not written | - | - | - | moved out of card 6 (its R1); written after card 2 is built |

**Deferred audit findings:** AUD-06 (connected-realm keys) and AUD-10 (`SendAddonMessage`'s
result) wait on the probe. AUD-08 (late answers) and AUD-13 (strict secret stub) wait until after launch.

Check counts are each branch's whole `run_all.sh`, card 1's suites included, re-run 2026-11-02 evening.

**Merging, when the walks pass.** Cards 3-7 each append at the same two places, so they conflict
there, as expected. Keep every line, in card order:
- **`DeadTired.toc`, after `Welcome.lua`:** `Crypt.lua`, `Gank.lua`, `PrepList.lua`, `Prep.lua`,
  `RecruitLines.lua`, `Recruit.lua`, `Stash.lua`, `Played.lua`, `EventsList.lua`, `Events.lua`,
  `Logs.lua` (then card 2's `Professions.lua`, `Crafts.lua`, when it exists);
- **`tests/run_all.sh`:** `… welcome:Welcome crypt:Crypt gank:Gank prep:Prep recruit:Recruit stash:Stash played:Played events:Events logs:Logs; do`.
  (`release/0.1.0-rc2` also runs `together:Together` last. That is the release's cross-card
  suite, and it does not come to `main` with any card.)

Once card 5 is on `main`, the `SendChatMessage` greps in cards 1, 3 and 4's walk-sheets will find
card 5's one ratified call site (`Recruit.lua`). Except that line when re-running them.

**Fixes to card 1** found on launch night go on `card/dt_foundation` first, then get merged into
each card branch (rule 1), before any of them is walked (rule 3).

| Card | Slug | Features | Size | Depends on |
|---|---|---|---|---|
| 1 | `dt_foundation` | Rebrand / new addon shell, guild-only gate, comms layer, who-runs-it roster, **alt registry** | M | - |
| 2 | `dt_professions` | **Profession directory** ("who can make X?") | M | 1 (comms, alt registry) |
| 3 | `dt_crypt` | **"Rest in Pieces" death notices**, **graveyard memorial**, **bedtime nag** | S-M | 1 |
| 4 | `dt_pvp` | **Gank diary** (target an Alliance player, log name/class/level/zone, shared board) | S-M | 1 |
| 5 | `dt_prep` | **Raid-prep bag check**, **recruitment rotator** | S-M | 1 |
| 7 | `dt_logs` | **Combat-log prompt**: offer to switch the combat log on when entering a dungeon or raid; opt-in login prompt for combat + chat log | S | 1 |
| 6 | `dt_stretch` | Stretch, budget permitting: ~~crafting request board~~ (moved out, see below), guild stash search (opt-in), slowest-leveller award, event tracker (STV Fishing Extravaganza) | M-L | 1 |

## Branching and testing rule

The promo credit expires (2026-11-04) before Forever goes live (Wed 2026-11-04, 3pm PT /
11pm UK), so cards are built before they can be walked in game. That is allowed, under these
rules:

1. **Every later card branches off `card/dt_foundation`, never off another card.** Card 3 is
   `card/dt_crypt` off `card/dt_foundation`, and so on. No chains: a fix to card 1 is made once,
   on card 1's branch, then merged into each card branch.
2. **Nothing merges to `main` until its walk-sheet passes in game.** The offline tests run at
   build time. The in-game checks wait until launch: postponed, never skipped.
3. **Walk card 1 first.** If card 1's sheet fails, stop: fix card 1 and merge the fix into the
   other card branches before walking any of them. A walk on a broken foundation proves nothing.
4. **A card that hangs on an unanswered question about the live client is not built until the
   question is answered.** Card 2 waits for the native guild recipe probe (below).
5. A build session that finds it needs to change card 1's code from a later card's branch
   **stops and reports** instead. Card 1 changes happen on card 1's branch only.

## Plan of action (proposed 2026-11-02; what happened is in the status table above)

| When | What |
|---|---|
| Now | Build card 1 (`dt_foundation`). |
| After card 1 is reported, while credit lasts | Cards 3, 4, 5, each on its own branch off card 1, in that order. A brief is written and ratified for each before it is built. |
| Launch night (Wed 4 Nov) | Walk card 1. If it passes, merge it to `main`, then walk 3, 4, 5 and merge each that passes. Do the one-login recipe probe for card 2. |
| After launch | Card 2, briefed against the probe result. Card 6 only if there is budget. |

**As it went:** cards 1, 3, 4, 5, 6 and 7 were built on 2026-11-02, card 6 ahead of plan on Tim's
ruling and card 7 added the same day. All were then audited, fixed in two rounds and cut into
`release/0.1.0-rc2`. Card 2's brief was drafted ahead of the probe, with the probe written into it.

**Launch night, now:**
1. Walk card 1. If it passes, merge it to `main`.
2. Walk 3, 4, 5, 6 and 7, merging each that passes, in that order (the merge note above).
   `docs/LAUNCH_NIGHT.md` on `release/0.1.0-rc2` has the running order.
3. Run card 2's probe, rule on its R1-R5, then build it.

Cost of this plan, accepted: a launch-night surprise in card 1 means fixing six branches, not
one. Benefit: credit that would otherwise expire is spent on the cards least likely to be thrown
away.

## Design notes carried forward

- **Card 2: check the native guild recipe lookup first.** The beta client exposes
  `C_GuildInfo.QueryGuildMembersForRecipe` and `C_GuildInfo.QueryGuildMemberRecipes`
  (`reference/SPEC_forever_namespaces.md`). If they answer on the live client, the directory may
  only need to *present* what the game already knows, plus cover people who don't run the addon.
  A one-login probe by Tim settles it. **Card 2's draft brief now holds the probe** (five
  commands) and proposes building the addon directory either way, with a native layer as its own
  card if the probe says it works.
- **Card 3:** a death notice carries name, level and zone only. Killer needs combat data, which
  the client doesn't give addons. Hardcore deaths are the point; normal-realm deaths are off by
  default.
- **Card 4:** the gank diary is a *button press on a target*, not a kill detector. It's the
  no-combat-log route to names for the PvP tally and bounty board later.
- **Card 5:** the recruitment rotator posts one line per click (Blizzard rule). The five lines
  came from `L5GN/_desk/dead-tired_recruitment_2026-11-01.md`. They are now in
  `docs/RECRUIT_lines.md` on `card/dt_prep`, without their leading `/1 `.
- **Card 6:** the crafting request board left it, because it depends on card 2. Stash answers
  carry at most 4 hits so that accented 12-letter names fit (Tim, 2026-11-02).

## Not carded yet

- **Long poles:** PvP tally / leaderboard, bounty board, Raid-Helper events into the in-game
  calendar (needs a `C_Calendar` probe first).
- **Parked:** "Rise!" roll call (could be spammy).
- **Long, long pole:** Discord bridge, with the bot reading the addon's saved files and posting
  to Discord.
- **Not doing:** anything combat-based; auto-posting to public channels; talking to Discord from
  inside the game.
