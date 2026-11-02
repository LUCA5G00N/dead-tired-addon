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
