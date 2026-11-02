# Roadmap: the DEAD TIRED guild addon

Source: Tim's idea list, `L5GN/_desk/dead-tired_addon_ideas.md` (2026-11-02). Which features
made the cut is Tim's ruling; **the order of cards below is a proposal** and is settled when
each brief is ratified. Only card 1 has a brief. Later briefs are written against the code
card 1 actually lands, not against this page.

Budget: promotional cloud credit, **$74 remaining, expiring 2026-11-04**. Cards 1-5 are the
target; the stretch card only if credit is left after card 5 is reported.

| Card | Slug | Features | Size | Depends on |
|---|---|---|---|---|
| 1 | `dt_foundation` | Rebrand / new addon shell, guild-only gate, comms layer, who-runs-it roster, **alt registry** | M | - |
| 2 | `dt_professions` | **Profession directory** ("who can make X?") | M | 1 (comms, alt registry) |
| 3 | `dt_crypt` | **"Rest in Pieces" death notices**, **graveyard memorial**, **bedtime nag** | S-M | 1 |
| 4 | `dt_pvp` | **Gank diary** (target an Alliance player, log name/class/level/zone, shared board) | S-M | 1 |
| 5 | `dt_prep` | **Raid-prep bag check**, **recruitment rotator** | S-M | 1 |
| 6 | `dt_stretch` | Stretch, budget permitting: crafting request board, guild stash search (opt-in), slowest-leveller award, event tracker (STV Fishing Extravaganza) | M-L | 2 (requests), 1 |

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

## Plan of action (proposed 2026-11-02)

| When | What |
|---|---|
| Now | Build card 1 (`dt_foundation`). |
| After card 1 is reported, while credit lasts | Cards 3, 4, 5, each on its own branch off card 1, in that order. A brief is written and ratified for each before it is built. |
| Launch night (Wed 4 Nov) | Walk card 1. If it passes, merge it to `main`, then walk 3, 4, 5 and merge each that passes. Do the one-login recipe probe for card 2. |
| After launch | Card 2, briefed against the probe result. Card 6 only if there is budget. |

Cost of this plan, accepted: a launch-night surprise in card 1 means fixing four branches, not
one. Benefit: credit that would otherwise expire is spent on the cards least likely to be thrown
away.

## Design notes carried forward

- **Card 2: check the native guild recipe lookup first.** The beta client exposes
  `C_GuildInfo.QueryGuildMembersForRecipe` and `C_GuildInfo.QueryGuildMemberRecipes`
  (`reference/SPEC_forever_namespaces.md`). If they answer on the live client, the directory may
  only need to *present* what the game already knows, plus cover people who don't run the addon.
  A one-login probe by Tim settles it before card 2's brief is written.
- **Card 3:** a death notice carries name, level and zone only. Killer needs combat data, which
  the client doesn't give addons. Hardcore deaths are the point; normal-realm deaths are off by
  default.
- **Card 4:** the gank diary is a *button press on a target*, not a kill detector. It's the
  no-combat-log route to names for the PvP tally and bounty board later.
- **Card 5:** the recruitment rotator posts one line per click (Blizzard rule). The five lines
  live in `L5GN/_desk/dead-tired_recruitment_2026-11-01.md`.

## Not carded yet

- **Long poles:** PvP tally / leaderboard, bounty board, Raid-Helper events into the in-game
  calendar (needs a `C_Calendar` probe first).
- **Parked:** "Rise!" roll call (could be spammy).
- **Long, long pole:** Discord bridge, with the bot reading the addon's saved files and posting
  to Discord.
- **Not doing:** anything combat-based; auto-posting to public channels; talking to Discord from
  inside the game.
