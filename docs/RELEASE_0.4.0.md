# Dead Tired 0.4.0: the body count

Zip: `dist/DeadTired-0.4.0.zip`.

The guild addon for <DEAD TIRED>. Still optional, still quiet.

## New
- **`/dt deaths`: who dies most.** A leaderboard of guildies' deaths: everyone's total, and how many this
  week (the week ends at the weekly reset). Hardcore characters wear a skull. Underneath, the zone that
  claimed the most of us this week.
- **To join it:** `/dt rip share on`, the same switch that shares your death notices. Your count starts
  from the deaths already in your graveyard. `/dt rip share off` takes you off everyone's board.
- **Only guildies running the addon who share their deaths appear.** No killers are named: the game
  doesn't tell addons who did it, and we wouldn't want to embarrass the Barrens.

## Known scruffiness
- **Switching skin** still doesn't repaint a window that's already open. Close it and open it again.

## Install
1. Quit WoW. Back up `WTF\Account\<you>\SavedVariables\DeadTired.lua`.
2. Delete the old `Interface\AddOns\DeadTired` folder.
3. Unzip `DeadTired-0.4.0.zip` into `Interface\AddOns\` (you get `Interface\AddOns\DeadTired\DeadTired.toc`).
4. Log in. Everything comes with you.
