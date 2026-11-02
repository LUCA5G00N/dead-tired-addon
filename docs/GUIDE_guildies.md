# Dead Tired: the guild addon (guide for guildies)

**Dead Tired** is the addon for <DEAD TIRED>. It's **optional**. Nobody has to run it, and
nothing in the guild depends on it. It only stirs inside the guild: on a character outside
<DEAD TIRED> it loads, says nothing and sends nothing.

It talks only to guildies who run it, over the guild's hidden addon channel. **Every list it
shows (who's online with it, deaths, ganks, roll calls, stash answers, the slowest-leveller
award) only includes guildies running the addon**, and only what your client saw while you were
online. If someone's missing, they probably don't have it (or have that sharing switched off).

It's quiet: one welcome line when you log in, and otherwise nothing unless you ask, apart from
the few things listed under *What it prints on its own*.

This is release candidate **0.1.0-rc2**, for testing on launch night.

## Install

1. Download `DeadTired-0.1.0-rc2.zip`.
2. Unzip it into your WoW Forever AddOns folder, `_forever_\Interface\AddOns`, so you end up with
   `_forever_\Interface\AddOns\DeadTired\DeadTired.toc`. (Not `DeadTired\DeadTired\...`.)
3. At the character screen, click **AddOns**, make sure **Dead Tired** is ticked. If it says
   *out of date*, tick **Load out of date AddOns**.
4. Log in. You should see: *Rest in Pieces, \<your name\>. The crypt's open. /dt for the rest.*

`/dt` (or `/deadtired`) on its own lists every command.

## What it shares, at a glance

| Feature | Shared automatically? | What goes to guildies | Switch it off |
|---|---|---|---|
| Who runs it (`/dt who`) | yes, at login | addon version, and your main if you named one | can't, short of disabling the addon |
| Alts (`/dt main`) | only after `/dt main` | which character is your main | `/dt main clear` |
| Your deaths | **no** | level, zone, hardcore or not | `/dt rip share off` (it's off until you turn it on) |
| Gank diary | when you press `/dt gank` | the enemy's name, realm, class, level and your zone | don't press it |
| Raid prep roll call | **no** | ready yes/no and how many items short, never which items | `/dt prep share off` (off by default) |
| Guild stash | **no** | your tradeable items matching a guildie's search, up to 4, and which of your characters holds them | `/dt stash share off` (off by default) |
| Slowest leveller | **no** | your level and hours played, when you type `/played` | `/dt slowest share off` (off by default) |
| Bedtime, events, combat log | never | nothing | (see each section) |

## Who's here: `/dt who`

- `/dt who` lists guildies running the addon that you've heard from this session, then ones seen
  before. It always ends: *Only guildies running the addon show up here.*
- **Shares:** at login your client says hello to the guild with the addon's version and your
  main (if set). That's how others' `/dt who` finds you.

## Alts: `/dt main`, `/dt alts`

- `/dt main` makes the character you're on your main, for every character on your account.
- `/dt main clear` forgets it.
- `/dt alts <name>` shows that character's main and their known alts. `/dt alts` alone shows yours.
- **Shares:** your main's name, with your hello. Honour system: nobody checks.

## Rest in Pieces: deaths, graveyard, bedtime

- When a guildie who shares their deaths dies, you see one line, e.g. *\<Name\> died at level 23
  in Stranglethorn Vale. Again.* On a hardcore character: *Rest in Pieces: \<Name\>, level 23,
  Stranglethorn Vale. Hardcore. Gone for good.*
  - `/dt rip off` hides these notices; `/dt rip on` brings them back. `/dt rip` shows both settings.
- **Your own deaths are not shared** until you type `/dt rip share on`. `/dt rip share off`
  stops it. **Shares:** your level, zone and whether it was hardcore. Never what killed you:
  the game doesn't tell addons, and this one doesn't try.
- On a hardcore character that hasn't chosen yet, you get one reminder, once ever:
  *This one's hardcore. If it falls, the guild won't hear unless you /dt rip share on.*
- `/dt graveyard` lists the last 10 deaths you saw (yours, and guildies' while you were online).
- `/dt bedtime 23:30` sets a bedtime (24-hour, your clock). From then you get up to three dry
  reminders a night, 30 minutes apart. `/dt bedtime off` stops it. Nothing is shared.

## Gank diary: `/dt gank`, `/dt ganks`

- Target an enemy-faction player and type `/dt gank` (put it in a macro on your bar). You get
  *Noted: \<Name\> (\<Class\> \<level\>), \<zone\>. The crypt remembers.*
- **Shares:** pressing it sends that enemy's name, realm, class and level and your zone to
  guildies running the addon. It reads only what your target frame shows, and only when you
  press it. Guildies don't see anything until they ask.
- `/dt ganks` shows the most-logged enemies. `/dt ganks <name>` shows one enemy's entries.
- Off: just don't press it.

## Raid prep: `/dt prep`

- `/dt prep` checks your bags against the guild's prep list for your class (potions, reagents)
  and tells you what you're short. `/dt prep list` shows the list with the item names your client
  knows. Nothing is shared by either.
- `/dt prep check` asks the guild's sharing members if they're ready; answers print after 10
  seconds.
- `/dt prep share on` lets you answer roll calls. **Shares:** ready yes/no and how many list
  items you're short. Never which items, never your counts. `/dt prep share off` (the default)
  stops it.

## Guild stash: `/dt stash`

- `/dt stash linen` asks sharing guildies who has any; answers print after 10 seconds.
- `/dt stash share on` lets you answer. Your client keeps a list of your **tradeable** items
  (bound items are never listed): bags on every character you play with sharing on, and your bank
  when you open it. **Shares:** only when a guildie searches, the items matching their search, at
  most 4, with counts and which of your characters holds them. The answer goes over the guild
  addon channel, so other guildies' clients receive it too, but only the asker sees it.
- `/dt stash share off` stops it and deletes your list. `/dt stash` shows what you'd offer.

## Slowest leveller: `/dt slowest`

- `/dt slowest` shows the *Crypt Keeper's Award for Glacial Progress*: the sharing guildies with
  the most hours played per level.
- `/dt slowest share on`, then type `/played` yourself: **shares** your level and total hours
  played. Only a `/played` you typed counts; the addon never asks the game for it.
- `/dt slowest share off` stops it and asks guildies' boards to remove your entry (guildies
  offline at the time drop it after 30 days).

## Events: `/dt events`

- `/dt events` shows the next Stranglethorn Fishing Extravaganza (Sunday 14:00-16:00 server time,
  the classic schedule; being checked on launch night) with a countdown.
- `/dt events remind on` gives one line 30 minutes before and one at the start.
  `/dt events remind off` (the default) stops them. Nothing is shared.

## Combat log for Warcraft Logs: `/dt logs`

- Entering a dungeon or raid with the combat log off, a small window asks **Log this one?** with
  **Log it** / **Not now**. **Log it** runs the game's own `/combatlog` for you (your click).
  Once per visit; never in battlegrounds or arenas. Nothing is shared.
- `/dt logs off` stops the asking; `/dt logs on` brings it back.
- `/dt logs login on` also asks at login about the combat log and the chat log;
  `/dt logs login off` stops that. `/dt logs now` shows that window now. `/dt logs` shows the
  current state.

## What it prints on its own

The welcome line (`/dt welcome off` hides it, `/dt welcome on` brings it back); guildies' death
notices (`/dt rip off`); the hardcore reminder (once, ever, per character); your bedtime
reminders (only after `/dt bedtime`); event reminders (only after `/dt events remind on`); the
combat-log window or line in dungeons and raids (`/dt logs off`). Nothing else.

## Found a bug?

Install **BugSack** (with BugGrabber), reproduce it, and post a screenshot of the BugSack error in
**#dt-chat** with what you were doing.
