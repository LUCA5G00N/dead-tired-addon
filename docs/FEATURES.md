# DeadTired: the feature list (draft, 7 Nov 2026)

One list of what DeadTired is going to be, drawn from cards 1-7, the probe results, the Wizardry
panes and the Naowh Forever trial. **Draft for Tim.** Nothing here is ratified: rows marked
*Tim* are his calls from the 7 Nov session, the rest are proposals. Build rounds are planned
from this page once Tim has been through it. `ROADMAP.md` stays the card history.

## The tests every feature passes
1. **Would a guildie want it?** If not, it stays in Wizardry (Tim's research kit). *Tim*
2. **Is it guild-shaped, or already done well elsewhere?** Big data that has to be kept current
   (dungeons, BiS, talent trees, recipe sources) is left to the addons that keep it: we don't
   take on the maintenance. *Tim*
3. **Ideas, never code.** Naowh Forever is "all rights reserved": we take ideas from it, and
   write our own code and our own content. *Tim*
4. The house rules in `CLAUDE.md` still hold: optional, quiet, guild-only, opt-in for anything
   personal, one click per public post.

## What changed on 7 Nov
- **Addon messages work** (`PROBE_launch_results.md`, *Update*). Fork A: the shared design comes
  back. It needs one ruling first: the restricted-flag rule (R-1 below).
- **Naowh Forever** covers a lot of what we'd pencilled in, and showed the shape to copy: a
  module framework with a launcher bar, one window style, skins, settings and search.

## The shell (new): one clear UI
*Tim:* "one clear ui - with the task bar style entrance bar and then containing each module to
its own viewport (but built on a standard frame so the skin maintenance stays easy)".

| Piece | What it is | Notes |
|---|---|---|
| **Launcher bar** | A small bar of module buttons (Naowh's Top Bar idea). Placed where you want, kept | Only enabled modules show. `/dt` keeps working for everything |
| **Viewport frame** | One standard frame every module draws into: title, close, body, optional search | Visibility rules from the Wizardry marks bar: placed and kept, survives `/reload`, Escape closes it (R-P2-2, walked 12 Nov), works in combat (insecure frames only) |
| **Skins** | Every frame draws through one style table, so a skin is a palette and a few textures | Start with two: **Forever** (the game's stone and metal) and **Dead Tired** (the guild's, curated). More later. Must be in the first shell round: retrofitting a style is the expensive part |
| **Settings as cards** | Each module declares its settings; the settings view builds itself. Per-module on/off | Includes the existing toggles (welcome, sharing opt-ins, logs prompt off) |
| **Search on every list** | The list widget comes with a search box | *Tim:* standard for any list view |
| **One addon** | Modules inside DeadTired, not separate addons | Naowh splits into 13 because of 190 MB of data; we won't have that |

This replaces the 7 Nov "single viewport that follows the last window" idea: each module gets
its own viewport instead. Nothing docks on Blizzard windows (the Wizardry dock stays Wizardry's).

### The hybrid: mesh other addons in, don't rebuild them (Tim, 7 Nov 16:08)
*Tim:* Naowh's "one addon to rule them all" mostly recreates good addons. Softer: our bar
replaces minimap buttons, an info bar you place where you like (the old Titan Panel idea), and
gives the popular addons a place to live. We still build our own modules, but don't take on the
maintenance weight of full addons like the dungeon journal.

How (proposal):
- **The standard, not scraping.** Most addons publish a **LibDataBroker (LDB)** object (a launcher
  or a line of text) and draw their minimap button with **LibDBIcon**. Titan Panel, ChocolateBar
  and Bazooka are LDB hosts: that's how they "support" hundreds of addons without code for each.
  Our bar is an LDB host too. Reparenting other addons' minimap buttons (the Minimap Button Bag
  way) is the fragile fallback: it touches frames we didn't make. Later, if ever.
- **Our modules publish LDB objects as well** (deaths today, who's on, recruit cooldown, quiz
  streak), so they work in **any** bar, not only ours.
- **Already on Forever:** Titan Panel and MinimapButtonButton (both in mein-mmo's top Forever
  addons). So the honest order is: (1) DT publishes LDB objects, which costs little and works
  with Titan today; (2) our own bar, only for what Titan doesn't give us: the Dead Tired skin,
  one look with our viewports, and the launcher. If a guildie already runs Titan, they don't need
  our bar.
- The test applies to the bar itself: guildies who want an info bar already have one. Ours earns
  its place by being the way into DT, and by looking like it.

## Comms (card 1, revised)
- **R-1, the restricted-flag rule (needs Tim's ruling):** hold messages only while
  `C_ChatInfo.InChatMessagingLockdown()` is true (boss fights, M+, PvP matches); otherwise send,
  and record each `SendAddonMessage` result as its enum (AUD-10: 0 = Success). This is what Naowh
  does. Changes `CLAUDE.md`'s "queued while restricted" line.
- **Chunking and pacing** for bigger payloads (the armory): messages are 255 bytes; the GUILD
  channel is throttled (about 10 a burst, then 1 a second, per prefix). Send changes, not
  everything, and answer on request.
- AUD-06 (`Realm-Name` key form) and the held-queue wording (lockdown only) in the same round.

## Modules

### Keep (built on cards 1, 3-7; walk them, then move them into the shell)
| Module | From | Shared? | Notes |
|---|---|---|---|
| Foundation: guild gate, welcome, `/dt` router, who-runs-it roster, alt registry | card 1 | yes | R-1 first. The roster feeds the armory |
| **Rest in Pieces**: death notices, graveyard, bedtime nag | card 3 | yes (notices) | Feeds achievements |
| **Gank diary** | card 4 | yes | Feeds achievements and the bounty board idea |
| **Raid prep** (`/dt prep`) | card 5 | no | **Trim candidate (10 Nov):** overlaps Naowh's Consumable Bar/AuraBuffs. Keep only if it becomes guild-shaped (the officers' raid-night list); otherwise drop |
| **Recruit rotator** + **ready nudge** | card 5 | public post | *Tim:* nudge wanted. One click per post, never a timer |
| **Logs prompt** | card 7 | no | `WizardryLogPrompt` retired 9 Nov: card 7's is the only prompt. `/dt logs login on` offers both logs at login |
| Play time, stash, event reminders | card 6 | opt-in | As ruled. Stash only unbound items |

### Card 2, ratify
**Profession directory** ("who in the guild can make X?"): works as drafted once R-1 lands.
Native guild lookup is off (`PROBE_guild_recipes_results.md`). Naowh's Professions window covers
your own recipes; ours is the guild angle only.

### New
| Module | What | Shared? | Notes |
|---|---|---|---|
| **Guild armory** | Naowh's Group Inspect "levelled up" for the guild: every member running DT, their gear, talents, level, professions and alts, **cached**, so you can look someone up when they're offline. Shows "as of" | yes, **opt-in** | *Tim's* idea. The biggest new module: needs chunking (above) and a clear opt-in. Ties in the roster (card 1) and alts. Not a BiS tool. **Blizzard's armory covers Forever** (Tim, 9 Nov: `worldofwarcraft.blizzard.com/en-us/forever/eu/armory/...`): ours is in game, cached offline, guild-only, with DT's own data (deaths, ganks, achievements, DT score), and can link to the official page |
| **DT achievements** | A curated list of guild achievements, checked off as you go (Naowh's Discovery idea). E.g. died in RFC, ganked by the same rogue twice, obeyed bedtime | yes | *Tim's* idea. Built on what cards 3 and 4 already record. Gives Liliac her leaderboard |
| **Travel quiz** | A quiz during flights | no | *Tim:* our own questions. Gothic, Forsaken lore, guild in-jokes; the questions are content the guild can write |
| **Travel timer** | How long the flight has left | could be | Needs flight times. Proposal: record our own flights and share them through the guild, so the table builds itself |
| **Level-up card** | "Level 20": talent point to spend, and what's waiting at the trainer | no | *Tim* liked Naowh's. The spell list needs class data: **What's Training's is MIT** (Naowh credits it), so it could be used with credit; or show the talent point and a "visit your trainer" line only |
| **Guild builds** | Officers publish a recommended talent build per class or role; members see it | yes | Proposal, in place of our own talent calculator (Naowh and What's Training do that) |
| **DT score** | A gear score "with some fun with it" (Tim, 10 Nov): gothic tiers, e.g. *Freshly Buried* → *Ancient Lich* | in the armory | From the Naowh review. Shown in the armory and on achievements; not a BiS tool |
| **The Restless Dead Pilgrimage** (guild adventures) | Curated quest lines the addon tracks: reach a place (subzone, or a radius around map coordinates), enter a dungeon, `/emote` at a spot, carry an item, target a named NPC, reach a level. Clues unlock step by step; progress shared; leaderboard and badges | yes | *Tim's* idea (10 Nov). Two routes to start: an **initiation** (short, safe, from Undercity, teaches DT; finishing earns "Risen") and a **veterans'** route (long, through Alliance zones: the PvP risk is the point; deaths go to the graveyard). Authored by walking the route and dropping `/wiz mark` at each stop (marks already save map/x/y/zone). Uses the waypointer. Can't use kills (no combat log); inside dungeons, steps go by "in this dungeon", not exact spots. Map functions on the beta spec: `C_Map.GetBestMapForUnit`, `GetPlayerMapPosition`, `SetUserWaypoint` |
| **Recipe tracking + shopping list** | Pick a recipe and a quantity (or a raw material); DT works out the reagents still needed (minus bags, later bank) and tracks them, with an optional loot toast ("Light Leather 14/20 for Light Armor Kits") | can be | *Tim* (10 Nov), "a bit like retail". On the beta spec: `C_TradeSkillUI.SetRecipeTracked`, `GetRecipesTracked`, `GetRecipeSchematic`, `C_Item.GetItemCount`. **Probe first:** whether `GetRecipeSchematic` needs the recipe known or the window opened. Naowh has a shopping list too: ours earns its place through the crafting board |
| **Crafting request board** | Post your shopping list to the guild ("10 Light Armor Kits, who can make them?"); crafters answer | yes | Joins the shopping list to card 2's directory |
| **Bounty board** (+ PvP tally) | Card 4's gank logs become shared bounties: "Rogue X ganked 3 of us this week"; revenge claims them; a PvP tally | yes | Proposal (10 Nov). The most "us" feature: built on what card 4 already records |
| **"Rise!" roll call** | One click asks "who's up for something?"; everyone running DT answers with one button | yes | Proposal (10 Nov). Cheap, social, exercises guild messaging |
| **Loot toast** | A slim toast for loot ("Light Leather x2 … 30c") | no | From the Naowh review: "nice - want to see the options though". Off by default, with options |
| **Auto junk-sell and repair** | Sell grey items and repair at a vendor | no | From the Naowh review: "good options to retain". **Off by default**, described where it's switched on; stands back if Leatrix Plus (or another installed addon) already does it |

### Left to others (not building)
Dungeon journal and dungeon quests (ForeverDungeonJournal, Naowh), BiS lists (Naowh), training
planner and talent calculator (Naowh, What's Training), the profession window (Naowh), quest
help (Naowh, Questie-style addons), threat, swing, macros, action bars. "Grrrr" (an aura: ForeverAuras can do it, no addon code).

### Stays in Wizardry (Tim's)
Session, Money, Rep, Quests and Professions panes; marks and the kill counter; every recorder;
the hub. Skills pane: drop (duplicated twice).

## Naowh review, 10 Nov (Tim's marks + screenshots)
Captured with WizardryLedger 0.39 screenshot marks (Gizzardthe, Durotar/Orgrimmar, 13:24-14:11);
the session paired each mark with its shot. Ideas only: Naowh is all rights reserved.

| Verdict | Tim's note | The shot | For DT |
|---|---|---|---|
| Good | *"Configurable task bar at the top for icons and info."* | Naowh's small top icon bar | The LDB-host launcher bar; keep it that small |
| **Bad** | *"Restock messaage appearing without me having turned it on"* | A large "Restock / Junk to sell 4" banner mid-screen | Nothing shows unless switched on; say where it comes from |
| Noted | *"auto junk and repair are good options to retain"* | | Auto junk-sell and repair module (off by default) |
| Noted | *"how much of another addons settings can we detect?"* / *"thinking questie for example or leatrix plus - both cover their areas well"* | | **Detect, then stand back** (below) |
| Noted | *"training planner view is slick."* | Naowh's planner: headline cost, a dotted road to 60, searchable lists | A look for our viewports. The planner itself stays Naowh's |
| Noted | *"like the idea of a gear scoring system but I'd like to have some fun with it,"* | Naowh Score 0.6 on the character panel | DT score |
| Noted | *"the loot notification is nice - want to see the options though"* | A slim loot toast | Loot toast (off by default) |
| Noted | *"Level up message is good"* | "Level 10: 3 spells to train, 9s in all. You can afford every one." with Open Planner / Waypoint / Dismiss | The level-up card: one clear action, dismissable |
| Noted | *"adding a lightweight waypointer seems a good idea as a core feature tbh - a lot of things can run off it."* | A waypoint bar ("Ormok, Training run · 1 of 3, 284 yd") and an arrow | **Waypoint service in the framework** (below) |
| Noted | *"The main menu working fully modular is good"* | Naowh settings: modules on the left, tabs per module, a switch per section, a drag/x/+ bar editor | Settings as cards; the bar editor is the model for ours |

**Detect, then stand back.** DT can tell whether another addon is installed and loaded
(`C_AddOns.IsAddOnLoaded`, its `.toc` version), and can often read its saved settings once
loaded, so it can say "Leatrix Plus already repairs: we won't". Reading another addon's settings
is a best guess (undocumented, changes between versions) with a safe fallback; **DT never writes
another addon's settings.**

**Pairing note for Wizardry:** a mark can be stamped a second after its file
(`…134328` vs `…134327.jpg`): pair with a second or two of slack. *"2nd test not sure I saw it
first time"*: the note box may be easy to miss.

## Licences and publishing (7-9 Nov)
- **DeadTired is MIT** (*Tim*, 9 Nov). `LICENSE` at the repo root; copyright line reads
  `LUCA5G00N` (change to a real name if wanted).
- **Bundled libraries** (all fine when shipped inside DT, each with its own licence/notice kept):
  LibStub and ChatThrottleLib (public domain), CallbackHandler (BSD 2-clause), Ace3 incl.
  AceComm/AceDB (BSD-style; never redistribute it standalone), LibDBIcon (Ace3-style BSD),
  LibSharedMedia (LGPL 2.1: keep it as its own unmodified file), LibSerialize (MIT), LibDeflate
  (zlib). **LibDataBroker-1.1: licence unclear: confirm before the first release.**
- **Proposed library set** (ruling): LibStub, CallbackHandler, LibDataBroker, LibDBIcon,
  LibSharedMedia, AceComm + ChatThrottleLib, LibSerialize, LibDeflate; maybe AceDB. DT keeps its
  own module core. Needs a `CLAUDE.md` line on bundling third-party libraries.
- **Publishing:** CurseForge has no upload fee; authors must be of age, grant Overwolf a
  distribution licence, include bundled licences, and may not copy code/text/design from other
  mods. Also Wago and GitHub releases; the BigWigs packager uploads to all three. Check the name
  "Dead Tired" is free on each. Blizzard's add-on policy (free, not obfuscated, no in-game
  solicitation): confirm against the current page before release.
- **Lesson from Naowh (Tim, 9 Nov):** a lot of undescribed automation. DT stays quiet, and every
  automatic action it takes is described where the player switches it on.

## General requirements (apply to every module)
- **Configurable from our UI, clearly, and from the terminal too** (Tim, 10 Nov). Every setting a
  module has appears in its settings card in plain words (what it does, what it shares, what it
  switches on automatically), and the same setting has a `/dt` command for people who prefer
  typing. Where a setting is too fiddly for a command (long lists, colours, positions), the brief
  says so and names the one place it lives: no setting exists only in one of the two by accident.
- **Every automatic action is described where it's switched on** (Naowh lesson, 9 Nov), and
  **nothing shows unless the player switched it on** (the Restock banner, 10 Nov).
- **Detect, then stand back:** where another installed addon already does a job, DT says so and
  doesn't duplicate it. Never write another addon's settings.
- **Search on every list**, and every viewport on the one standard frame (skins stay cheap).
- **The rebuild (Tim, 10 Nov):** *"thinking a proper rebuild approach with the framework idea in
  mind for robustness"*. The rc3 walk's defects are its first requirements:
  1. **One character key from the full name.** Forever names have a surname: `UnitName` =
     `"Stromham"`, `GetUnitName("player", true)` = `"Stromham Hamson"`, addon senders arrive as the
     full form. Build every key (own, senders, targets) from the full form; merge old short-name
     entries. (rc3: you appear as your own alt.)
  2. **Connected realms are real on Forever.** Liliac's reading (10 Nov): `UnitName` "Lilbit",
     `GetUnitName("player", true)` "Lilbit High", `GetRealmName` "CAMWOW EU4 Realm 4 PvP",
     `GetNormalizedRealmName` "CAMWOWEU4Realm4PvP"; Tim is on **Realm 2**. So the guild spans
     realms, Liliac's client was right to show Tim's realm, and the realm half of every key matters.
     **Asymmetry to probe:** Tim's `/dt who` showed "Lilbit High" with no realm, though Lilbit is on
     another realm. Record the raw `CHAT_MSG_ADDON` sender string for a cross-realm guildie before
     building keys. Two-part names confirmed for a second player.
  3. **No taint on the chat path.** rc3 blocks the "allow scripts" confirmation for anyone running
     it (Liliac). The command router must not touch Blizzard's chat edit box or slash tables
     beyond registering `/dt`.
  4. **Probe every name function** (player, target, guild sender) on day one of any new client.
  Source: `docs/UAT_dt_fixes3_results.md`.

### The framework (built first, everything sits on it)
Module core (each module its own switch, settings card, `/dt` verbs, error key) · comms (R-1,
AUD-10, chunking and pacing, protocol version) · one character key (full name) and realm rule ·
the standard viewport frame + skins (LibSharedMedia) · settings as cards · searchable list widget
· the LDB-host launcher bar (and DT's own LDB objects) · **the waypoint service** (point to a
place or an NPC, distance, arrow; Blizzard's `SetUserWaypoint` pin where it serves) · addon
detection ("stand back") · toasts (one style, all off by default).

## Ruled 9 Nov (for `dt_fixes3`)
R-1 lockdown only (flag recorded, never gates); AUD-10 retry then drop (3 tries); AUD-06 one
normalised realm key with a one-time migration; held line "The dead are gagged for this fight.
Your message goes when it's over."; recruit nudge once after a post (`/dt recruit nudge off`);
WizardryLogPrompt retired. Brief: `docs/COWORK_BRIEF_dt_fixes3.md`.

## Ruled 10 Nov (rebuild)
Fresh addon on the framework, cards ported next round; the small library set with DT's own core;
launcher bar on by default with a one-line intro, standing back for Titan-style hosts; two skins
(Forever + Dead Tired), Tim curates. Brief: `docs/COWORK_BRIEF_dt_framework.md`. Taint cause found:
rc3 `Core.lua:305` `SlashCmdList = SlashCmdList or {}`.

## Ruled 11 Nov (libraries)
LibDataBroker-1.1 borrowed, never bundled (no licence in its source); LibDBIcon dropped (no
minimap button); LibSharedMedia bundled (its file's LGPL 2.1 header). A session that can only push
its own branch uses it and says so. WizardryLedger has the same taint line as rc3: fix it in
Wizardry.

## Rulings needed (draft as questions; Tim decides)
Ruled already: R-1, AUD-06, AUD-10, held wording, recruit nudge, WizardryLogPrompt (9 Nov), MIT
(9 Nov). Still open, each asked when its round comes:
1. **Rebuild scope:** a fresh `DeadTired` on the framework, porting cards 1, 3-7 into it, rather
   than fixing rc3 further. (Tim leans this way, 10 Nov.) What of rc3 is kept as-is.
2. **Libraries:** the proposed set above, and the `CLAUDE.md` bundling rule.
3. **Launcher bar:** on by default or opt-in? (It shows unasked.)
4. **Skins:** the Dead Tired skin's look; who curates.
5. **Armory opt-in:** off by default? What's shared at each level? How long a cached entry lasts.
6. **Waypointer:** our own arrow, Blizzard's pin, or both.
7. **What's Training's data** (MIT, with credit) for the level-up card, or the talent point only.
8. **Raid prep:** guild-shaped, or drop.
9. **Pilgrimage:** who writes routes (Tim only, or officers too); whether routes are shared by
   addon message or shipped with the addon.
10. **Auto junk/repair, loot toast:** in the first pass, or later.
11. **Nudge `on`/`off` confirmation** wording (rc3 prints nothing).

## First pass (Tim, 10 Nov: *"a good list of features I think for a first pass"*)
Framework (above) · cards 1, 3, 4, 6, 7 ported · recruit + nudge · card 2's directory · guild
armory + DT score · achievements + leaderboard · the Restless Dead Pilgrimage · travel quiz +
timer · level-up card · recipe tracking + crafting board · bounty board · Rise! roll call.
Optional in the first pass: loot toast, auto junk/repair. Guild gambling moves into the plan (below). Parked: Raid-Helper into the calendar (the bot's job), Discord
bridge (the bot's job), guild builds.

## Ruled 11 Nov (for Port 1)
1. **Raid prep: rebuilt as the officers' raid-night list** (card 5's `/dt prep` reshaped:
   officers set the list; members check their own bags against it). Port 1 or Port 2 by size:
   the brief decides, Port 1 at least keeps its data in the legacy move.
2. **Nudge switch replies:** `/dt recruit nudge off` → *"Nudge off. The crypt keeps its own
   counsel."*; `/dt recruit nudge on` → *"Nudge on. The crypt will knock."*
3. **Bar contents: other addons off by default, an ordered list you curate.** DT's own buttons
   (Dead Tired, DT: n online, recruit) show from the start. Every other addon the bar finds is
   listed in the bar's settings card, **unticked**; tick to add it. The list is **ordered by
   drag**: each row has a grip on its side to slide it up or down, and the bar follows that
   order (DT's own buttons included). Order and ticks saved; `/dt bar add|remove <name>` and
   `/dt bar move <name> <position>` as the typed path. A newly installed addon appears
   unticked at the bottom.
4. **Names shown without the realm** (Tim, 11 Nov: *"the actual realm these days shouldn't make a
   difference to us playing on the same rule set"*). Lists show the full name only (`Vespera
   Grimm`); the realm goes in the row's tooltip. Proposal: only if two people share a full name is
   the realm added to tell them apart. **Keys keep the realm** (it's what keeps two same-named
   players apart and what made the cross-realm walk work).

## Ruled 12 Nov (for `dt_fixes4`)
Ratified by Tim, 12 Nov 14:26 (`docs/COWORK_BRIEF_dt_fixes4.md`).
- **R-F4-1 Text fit.** Rows are one line, cut with "…", the full text in the row's tooltip.
  Footers, descriptions, empty-state lines, dialogs and toasts are bounded both sides and wrapped,
  their box sized from the measured height. Date, level, count and version columns are measured
  from their widest value at the current font; each list has exactly one flexible column. No
  shrink-to-fit. Modules never create raw text.
- **R-F4-2 DT cuts the text itself.** None of the client's truncation calls (`IsTruncated`,
  `SetMaxLines`); DT measures with `GetStringWidth` on a hidden string and trims to fit.
- **R-F4-3 The clean skin.** A third skin, id `clean`, shown as **Dead Tired**: the Dead Tired
  colours and edges with the game's own lettering (Friz Quadrata) throughout. The gothic skin keeps
  id `deadtired`, shown as **Dead Tired Gothic**. `clean` is the default. `/dt skin clean|deadtired|forever`.
- **R-F4-4 Who is switched.** Once per account, anyone on `deadtired` (or with no saved choice) is
  moved to `clean`; `forever` is left alone. Silent (the release notes say it). `/dt skin deadtired`
  afterwards sticks.
- **R-F4-5 Master switches** on Gank, Played, Stash, Events, Logs: the framework's `On` card,
  default on. Off: no events, inbound ignored, nothing sent, nothing printed unasked; a typed verb
  answers `<id>.enabled = off` and does nothing else. Off is not a withdrawal.
  **Ruled (Tim, 12 Nov): the sharing toggle always withdraws.** Switching Played's sharing off
  (the card or `/dt set`) sends the PLAYED withdrawal and removes your own entry even while Played
  is switched off: the only send allowed while the module is off.
- **R-F4-6 The nudge and `/reload`.** A `/reload` while a post's cooldown runs re-arms the nudge
  for the time left. A fresh login never does. No late line if the cooldown ended during the reload.
- **R-F4-7 The hint.** `/dt played` with sharing off prints, after asking the client:
  `Sharing's off. /dt slowest share on`
- **R-F4-8 The skin card's description:** `How every Dead Tired window and the bar look: Dead
  Tired (the guild's colours, plain lettering), Dead Tired Gothic (the same, with gothic titles) or
  Forever (the game's stone and metal).`
- **R-F4-9 Version.** 0.3.1, though PATCH is fixes only and this round adds a skin and five
  switches: a one-off, noted in the release notes.
- **R-F4-10 Other tooltips.** The Who list's and the Grudges board's tooltips keep their realm line.

## Versions and releases (Tim, 11 Nov)
Semantic versioning, MAJOR.MINOR.PATCH: MINOR for new features, PATCH for fixes only, MAJOR when
saved data or the protocol breaks compatibility (and **1.0.0** when the first pass is done). A
leading 0 means early. Test builds carry a suffix (`-fw1`, `-p1rc1`). Option A: the framework line
continues, so **Port 1 ships as 0.2.0**, Port 2 as 0.3.0, later rounds 0.4.0, 0.5.0...; rc3's
0.1.0 was never released.
**Distribution:** Port 1 as a **GitHub release + the zip in Discord** (guild only). Port 2 the
same unless Tim decides otherwise; CurseForge/Wago later, with the BigWigs packager set up in that
round so each release after is one tag.

### Guild gambling (Tim, 11 Nov; Liliac's idea, 4 Nov)
Modelled on **CrossGambling** (ideas only; our own code): a host starts a round, announced in chat;
everyone in it `/roll`s to the stake (e.g. `/roll 100`); **lowest pays highest the difference**; a
**Final call** button closes entries after ~20 s and the result is announced. DT reads the game's own
`/roll` results from the system messages; no gold moves through the addon (players trade by hand).
Plus a guild leaderboard (won/lost over time), which is where the achievements round can hook in.
**Ruled (Tim, 11 Nov): runs over addon messages, not chat.** CrossGambling ran everything through
party chat and got spammy; DT keeps the round in its own window: start, join, rolls, Final call and
the result travel by addon message to everyone running DT in the round. Nothing is posted to chat
by default (an optional one-click "Announce" for the host is a later nicety, not required).
**Honesty of rolls (to settle in the round's brief):** an addon can't make a trusted random number,
so the roll is still the game's own `/roll` (RandomRoll); DT reads the result from the system
message. The game shows a `/roll` result only to the roller's party/raid (or people nearby), so
either everyone in a round joins one party/raid (each client then sees every roll itself), or each
client reports its own roll by addon message (simpler, but trust-based). Proposal: a round needs a
party/raid, and each client checks the rolls it saw against those reported.
**Still to rule when its round comes:**
1. **Scope of a round** (guild-wide by addon message, or party/raid only, which the roll check needs).
2. *(Settled by the ruling above: no timed chat post.)* **The timed announcement.** Starting a round and pressing Final call are clicks; announcing the
   result *after* the 20 s timer would be a post from a timer. Options: the result is shown to
   everyone running DT by addon message (no chat post), and the host gets an **Announce** button
   (one click) to post it to chat; or a ruled exception for one result line per round in guild/party
   chat (never a public channel).
3. Stakes cap and whether the leaderboard is opt-in.

## Proposed order (rounds kept few: every round costs plan usage)
Done: rulings, `dt_fixes3` (rc3, walked 10 Nov), rebuild rulings (10-11 Nov), **framework round**
(0.2.0-fw1, walked 10-11 Nov with four players on three realms: **8 of 8 pass**,
`docs/UAT_dt_framework_results.md` on `claude/hopeful-thompson-4rpsrp`).
1. **Port 1 → 0.2.0:** card 1 (guild gate, roster/who, alts), card 3 (Rest in Pieces: deaths,
   graveyard, bedtime), **recruit with a button on the bar** (`/dt recruit` as backup) + nudge, the
   `DeadTiredDB.legacy` migration for those cards (merge short/full-name duplicates; refile
   connected-realm keys), and the fw1 walk's fixes (settings rows sized to their text; first
   setting not under the search box; colour codes on the bar shown, not escaped; Who shows you,
   marked as you, and an empty-state line; choose which addons show on the bar; DT info on the bar,
   e.g. session stats), the bar list as ruled above, raid prep as the officers' list (if it fits;
   else Port 2). Two-player walk. GitHub release + Discord.
2. **Port 2 → 0.3.0:** card 4 (gank diary), card 6 (play time, stash, events), card 7 (logs
   prompt), with their legacy data. Release as Port 1 (or CurseForge/Wago, Tim's call then).
3. **Waypoint service + level-up card** (0.4.0).
4. **Card 2 + recipe tracking + crafting board** (probe `GetRecipeSchematic` first).
5. **Guild armory + DT score.**
6. **Achievements + leaderboard + bounty board + Rise!**
7. **The Pilgrimage** (initiation route first).
8. **Guild gambling** (+ its leaderboard), after achievements.
9. **Travel window:** flight timer + next stop + the quiz (Tim's mark, 10 Nov 15:16).
Ideas waiting for a round: a dungeon-quest tracker built over ForeverDungeonJournal (Tim's mark,
10 Nov 21:09).
**Login reminders: talent points and legacy points** (Tim, 11 Nov). One line at login when either
is unspent, e.g. *"1 talent point and 2 legacy points lie unspent. The ancestors are restless."*
New *prints unasked* exception (needs a ruling); switchable; once per login. Round 3, beside the
level-up card. Probed 11 Nov:
- **Talent points: readable.** `C_Traits.GetConfigsByType(4)` gives the class config (rogue: config
  4027355, tree 1111); `C_Traits.GetTreeCurrencyInfo(config, tree, false)` → currency 3820,
  quantity 1, spent 0 (matched the 1 unspent point). `GetUnspentTalentPoints` is absent. Types 0-4
  valid; 5 errors.
- **Legacy points: not found yet.** Forever's own UI, `LegacySystemFrame` (part
  `Blizzard_LegacySystem`; children `TreePage`, `ChallengesPage`, `RewardTrackPage`, tabs); window
  shows "Legacy Points 3 / 65" (earned, account-wide) and "Available points: 2". No `C_*Legacy*`
  namespace; no `C_*` function with "Legacy" in its name tied to it; `TreePage` holds no
  config/tree value and has no `GetConfigID`/`GetTalentTreeID`. Type-3 config (rogue 4027358,
  mage 5819305, both tree 1118) returns **no** currency. **The round's brief starts with a proper
  probe** (e.g. export the interface code, or trace what `TreePage` calls); fallback: read the
  "Available points" text, which works only after the window has been opened that session.

**Port rule (11 Nov):** on Forever `UnitFullName` returns the **surname** as its second value
(`"Stromham", "Hamson"`; target `"John", "Do"`), not the realm. Never read a realm from it.
