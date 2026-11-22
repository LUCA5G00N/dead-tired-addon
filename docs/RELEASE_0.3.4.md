# Dead Tired 0.3.4: back from the dead (again)

Zip: `dist/DeadTired-0.3.4.zip`.

The guild addon for <DEAD TIRED>. Still optional, still quiet, and now able to speak again.

## Fixed
- **Since the game's patch on 21 Nov, every copy of Dead Tired has been silent.** The game stopped
  telling addons which realm you're on, and Dead Tired won't talk without knowing who you are. No Who
  list, no death notices, no stash answers. Now it remembers your realm from before the patch (or works
  it out from your server), and talks again. **Everyone on 0.3.x should update.**
- Deaths saved as `?` during the silence get your name back.

Brand-new characters the addon has never seen with a realm get a stand-in realm until the game gives
the real one back.

## Known scruffiness
- **Switching skin** still doesn't repaint a window that's already open. Close it and open it again.

## Install
1. Quit WoW. Back up `WTF\Account\<you>\SavedVariables\DeadTired.lua`.
2. Delete the old `Interface\AddOns\DeadTired` folder.
3. Unzip `DeadTired-0.3.4.zip` into `Interface\AddOns\` (you get `Interface\AddOns\DeadTired\DeadTired.toc`).
4. Log in. Everything comes with you.
