# Dead Tired 0.6.0: the Crypt's Table

Zip: `dist/DeadTired-0.6.0.zip`.

The guild addon for <DEAD TIRED>. Still optional, still quiet, and now a bad influence. Liliac asked for gambling. Liliac got gambling.

## New
- **Play chips, not gold.** Everyone starts with 1,000. Nothing you win or lose here is real money, and no gold ever moves through the addon. Go broke and the crypt tops you back up to 1,000 at the Wednesday reset.
- **`/dt gamble deathroll <name> <stake>`**: challenge someone in your party. Take turns rolling, each roll capped by the last. Whoever rolls a 1 pays the stake.
- **`/dt gamble highlow <stake>`**: open a table for your party. Everyone joins, the host calls it (or it closes itself 20 seconds after the last join), everyone rolls, and the lowest pays the highest the difference. Ties roll again.
- **Honest dice.** Only the game's own `/roll` counts: press **Roll** in the window or type it yourself. Every copy of the addon reads the rolls with its own eyes. If they disagree, the game is called off and nothing moves.
- **`/dt gamble board`**: the week's winners and losers, with the week's biggest beat-down at the bottom for an officer to console. Playing puts you on it; `/dt gamble board off` takes you off.
- Stakes from 2 to 500 chips. Nothing is posted to chat.

## Install
1. Quit WoW. Back up `WTF\Account\<you>\SavedVariables\DeadTired.lua`.
2. Delete the old `Interface\AddOns\DeadTired` folder.
3. Unzip `DeadTired-0.6.0.zip` into `Interface\AddOns\` (you get `Interface\AddOns\DeadTired\DeadTired.toc`).
4. Log in. Everything comes with you.

Only guildies running the addon can play, and only with people in their party.
