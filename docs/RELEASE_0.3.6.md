# Dead Tired 0.3.6: one less thing to worry about

Zip: `dist/DeadTired-0.3.6.zip`.

The guild addon for <DEAD TIRED>. Still optional, still quiet.

## Fixed
- **`/dt selftest` no longer reports a failure that wasn't one.** The game turns away the gothic title
  font the first time it's asked for at login, then hands it over a moment later. Dead Tired now asks
  twice before it complains. The self-test should now read 10 passed, 0 failed.

Nothing else changes.

## Known scruffiness
- **Switching skin** still doesn't repaint a window that's already open. Close it and open it again.

## Install
1. Quit WoW. Back up `WTF\Account\<you>\SavedVariables\DeadTired.lua`.
2. Delete the old `Interface\AddOns\DeadTired` folder.
3. Unzip `DeadTired-0.3.6.zip` into `Interface\AddOns\` (you get `Interface\AddOns\DeadTired\DeadTired.toc`).
4. Log in. Everything comes with you.
