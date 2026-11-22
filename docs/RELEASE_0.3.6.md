# Dead Tired 0.3.6: the self-test learns some manners

Zip: `dist/DeadTired-0.3.6.zip`.

The guild addon for <DEAD TIRED>. Still optional, still quiet.

## Fixed
- **`/dt selftest` no longer fails over the gothic font.** The game keeps turning away Dead Tired's gothic
  title font. It does no harm, but the self-test used to count it as a failure. Now it lists it as known,
  and the crypt's finest minds are looking into why. You should see 10 passed, 0 failed.
- **Running the self-test twice in one session** no longer fails the second time because of the first.

Nothing else changes.

## Known scruffiness
- **Switching skin** still doesn't repaint a window that's already open. Close it and open it again.

## Install
1. Quit WoW. Back up `WTF\Account\<you>\SavedVariables\DeadTired.lua`.
2. Delete the old `Interface\AddOns\DeadTired` folder.
3. Unzip `DeadTired-0.3.6.zip` into `Interface\AddOns\` (you get `Interface\AddOns\DeadTired\DeadTired.toc`).
4. Log in. Everything comes with you.
