# Dead Tired 0.3.2: two lines, no more cut names

Zip: `dist/DeadTired-0.3.2.zip`.

The guild addon for <DEAD TIRED>. Still optional, still quiet, still useless outside the guild.

## Changed
- **Two-line rows** in Events, Who has it and Glacial Progress: the name on top, the details
  underneath. Names and times are no longer cut to fit one line. The other lists are as they were.
- **Glacial Progress's tooltip** shows the name once, not twice.

## Known scruffiness
- **Switching skin** still doesn't repaint a window that's already open. Close it and open it
  again. We tried a fix; the walk said no. It's on the list.
- The game draws the cut mark as three dots. That is the font's doing, and we are leaving it.

## Install
1. Quit WoW. Back up `WTF\Account\<you>\SavedVariables\DeadTired.lua`.
2. Delete the old `Interface\AddOns\DeadTired` folder.
3. Unzip `DeadTired-0.3.2.zip` into `Interface\AddOns\` (you get `Interface\AddOns\DeadTired\DeadTired.toc`).
4. Log in. Everything from 0.3.1 comes with you.
