# Dead Tired 0.5.0: the Waypointer

Zip: `dist/DeadTired-0.5.0.zip`.

The guild addon for <DEAD TIRED>. Still optional, still quiet.

## New
- **`/dt way 45.2 61.8`**: an arrow on your screen pointing the way, with the yards to go, and the game's own map pin on the spot. Add a zone to point somewhere else: `/dt way 38 54 Western Plaguelands` (the start of the name will do).
- **`/dt way list`**: every library book in Azeroth, where it lies and roughly what level it's safe to fetch. Click one and off you go. Hand them to Owen Thadd in the Undercity for a necklace, a ring and more.
- Get there and it clears itself. `/dt way clear` gives up early. Drag the arrow wherever suits you; `/dt way arrow off` or `/dt way pin off` if you only want one of them.
- Your waypoint survives a `/reload`. Nobody else sees it.

## Install
1. Quit WoW. Back up `WTF\Account\<you>\SavedVariables\DeadTired.lua`.
2. Delete the old `Interface\AddOns\DeadTired` folder.
3. Unzip `DeadTired-0.5.0.zip` into `Interface\AddOns\` (you get `Interface\AddOns\DeadTired\DeadTired.toc`).
4. Log in. Everything comes with you.
