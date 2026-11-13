# Dead Tired 0.3.0: grudges, sloth and other records

**Draft. Tim publishes it** (GitHub release + Discord). Zip: `dist/DeadTired-0.3.0.zip`.

The guild addon for <DEAD TIRED>. Still optional, still quiet, still useless outside the guild.
Every list below shows only guildies who run it.

## New since 0.2.0
- **The gank diary.** Target the Alliance thug who just flattened you and `/dt gank`. The guild
  hears about it, quietly. `/dt ganks` opens the grudge board, most frequent offenders first, and
  you can search it; `/dt ganks <name>` lists one villain's crimes. It reads your target only when
  you press it.
- **Glacial Progress.** `/dt slowest share on`, then `/dt played` whenever you want to update your
  entry. `/dt slowest` names the guild's slowest leveller and opens the board. A plain `/played` is
  your own business. Switch sharing off and you're taken off everyone's board.
- **The stash.** `/dt stash share on` and guildies' `/dt stash <item>` searches find your
  tradeable items (never bound ones), across your characters. Off until you say so; off again
  deletes the list.
- **Events.** `/dt events` shows what's coming, in server time. `/dt events remind on` and you get
  a line 30 minutes before, and one at the start.
- **The combat log.** Walk into a dungeon or raid with the combat log off and one prompt offers to
  switch it on (Warcraft Logs needs it). One click, your click. `/dt logs off` stops it; `/dt logs
  login on` asks about both logs at login.

## Fixed
- **Escape closes Dead Tired's windows** (Who, settings, the graveyard and the new boards).
- **The bar list shows names**, not whatever the button says this minute (BugSack, not `0`).
  A grab hand while you drag a row.
- **The recruit nudge** survives `/dt recruit nudge off` and `on`.
- The graveyard's dates are short (`10 Nov`), the full date in the tooltip. Some still wrapped: fixed in 0.3.1.

## Install
1. Quit WoW. Back up `WTF\Account\<you>\SavedVariables\DeadTired.lua`.
2. Delete the old `Interface\AddOns\DeadTired` folder.
3. Unzip `DeadTired-0.3.0.zip` into `Interface\AddOns\` (you get `Interface\AddOns\DeadTired\DeadTired.toc`).
4. Log in. Your 0.1.0 grudges, play-time board, stash setting and log settings come with you.
