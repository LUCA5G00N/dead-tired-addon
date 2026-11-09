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
| **Viewport frame** | One standard frame every module draws into: title, close, body, optional search | Visibility rules from the Wizardry marks bar: placed and kept, survives `/reload`, Escape doesn't close it, works in combat (insecure frames only) |
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
| **Raid prep** (`/dt prep`) | card 5 | no | Overlaps Naowh's Consumable Bar/AuraBuffs: keep only if it's guild-shaped (the guild's raid list) |
| **Recruit rotator** + **ready nudge** | card 5 | public post | *Tim:* nudge wanted. One click per post, never a timer |
| **Logs prompt** | card 7 | no | Retire `WizardryLogPrompt` (proposal) so there's one prompt |
| Play time, stash, event reminders | card 6 | opt-in | As ruled. Stash only unbound items |

### Card 2, ratify
**Profession directory** ("who in the guild can make X?"): works as drafted once R-1 lands.
Native guild lookup is off (`PROBE_guild_recipes_results.md`). Naowh's Professions window covers
your own recipes; ours is the guild angle only.

### New
| Module | What | Shared? | Notes |
|---|---|---|---|
| **Guild armory** | Naowh's Group Inspect "levelled up" for the guild: every member running DT, their gear, talents, level, professions and alts, **cached**, so you can look someone up when they're offline. Shows "as of" | yes, **opt-in** | *Tim's* idea. The biggest new module: needs chunking (above) and a clear opt-in. Ties in the roster (card 1) and alts. Not a BiS tool: no scores, no lists |
| **DT achievements** | A curated list of guild achievements, checked off as you go (Naowh's Discovery idea). E.g. died in RFC, ganked by the same rogue twice, obeyed bedtime | yes | *Tim's* idea. Built on what cards 3 and 4 already record. Gives Liliac her leaderboard |
| **Travel quiz** | A quiz during flights | no | *Tim:* our own questions. Gothic, Forsaken lore, guild in-jokes; the questions are content the guild can write |
| **Travel timer** | How long the flight has left | could be | Needs flight times. Proposal: record our own flights and share them through the guild, so the table builds itself |
| **Level-up card** | "Level 20": talent point to spend, and what's waiting at the trainer | no | *Tim* liked Naowh's. The spell list needs class data: **What's Training's is MIT** (Naowh credits it), so it could be used with credit; or show the talent point and a "visit your trainer" line only |
| **Guild builds** | Officers publish a recommended talent build per class or role; members see it | yes | Proposal, in place of our own talent calculator (Naowh and What's Training do that) |

### Left to others (not building)
Dungeon journal and dungeon quests (ForeverDungeonJournal, Naowh), BiS lists (Naowh), training
planner and talent calculator (Naowh, What's Training), the profession window (Naowh), quest
help (Naowh, Questie-style addons), threat, swing, macros, action bars, auto-repair.

### Stays in Wizardry (Tim's)
Session, Money, Rep, Quests and Professions panes; marks and the kill counter; every recorder;
the hub. Skills pane: drop (duplicated twice).

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

## Ruled 9 Nov (for `dt_fixes3`)
R-1 lockdown only (flag recorded, never gates); AUD-10 retry then drop (3 tries); AUD-06 one
normalised realm key with a one-time migration; held line "The dead are gagged for this fight.
Your message goes when it's over."; recruit nudge once after a post (`/dt recruit nudge off`);
WizardryLogPrompt retired. Brief: `docs/COWORK_BRIEF_dt_fixes3.md`.

## Rulings needed (draft as questions; Tim decides)
1. **R-1:** the restricted-flag rule (above). First, because every shared module waits on it.
2. AUD-10 (send results as the enum; fix the probe's `registered` read) and AUD-06 (realm key).
3. **Recruit nudge:** wording, and exactly when it prints (once when the 15 min is up, only if
   you've posted this session?).
4. **Armory opt-in:** off by default? What's shared at each level (gear only / gear + talents /
   everything)? How long a cached entry is kept.
5. **Shell:** the launcher bar is a new "shows unasked" element: on by default or opt-in?
6. **Skins:** the Dead Tired skin's look (colours, textures). Who curates.
7. **WizardryLogPrompt:** retire (proposal) or keep.
8. **Libraries:** the proposed set above, and the `CLAUDE.md` bundling rule.
9. **What's Training's data:** use it (MIT, with credit) for the level-up card, or keep the card
   to the talent point.

## Proposed order (rounds kept few: every round costs plan usage)
1. **Rulings round** (no code): R-1, AUD-06/10, held wording, nudge.
2. **`dt_fixes3`** on `card/dt_foundation`: R-1, AUD-06/10, held wording, the nudge; merge into
   each card branch; **rc3**. Tim walks card 1, then 3-7 (ROADMAP rule 3), merging what passes.
   Release 0.1.0. *Proves the logic before any of it moves into a window.*
3. **Shell round:** launcher bar, viewport frame, skins (Forever + Dead Tired), settings cards,
   searchable list. Existing modules get a viewport each.
4. **Card 2** (ratify, build, walk).
5. **Guild armory.**
6. **Achievements** (+ leaderboard).
7. **Travel** (timer + quiz) and the **level-up card**.
8. Guild builds, and the parked ideas (bounty board, crafting board, Raid-Helper events,
   guild gambling) as the guild asks for them.
