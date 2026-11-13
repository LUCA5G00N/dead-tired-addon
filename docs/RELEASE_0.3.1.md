# Dead Tired 0.3.1: the words stay in their boxes

**Draft. Tim publishes it** (GitHub release + Discord). Zip: `dist/DeadTired-0.3.1.zip`.

The guild addon for <DEAD TIRED>. Still optional, still quiet, still useless outside the guild.

## The look has changed
Dead Tired now uses the game's own lettering everywhere, titles included: same colours, easier on
the eyes. Miss the gothic titles? `/dt skin deadtired` brings them back, and it sticks. `/dt skin
forever` for the game's stone and metal, `/dt skin clean` to come back.

## Fixed
- **Text stays inside its window.** Long names and zones end in `…` and show in full in the
  tooltip; every row is one line; dates no longer wrap. Footers wrap inside their window, and the
  combat-log prompt's words sit inside its box.
- **Tooltips on Glacial Progress and the graveyard** show the name, not the realm's raw key.
- **The recruit nudge** survives a `/reload`.

## Small additions
(0.3.1 is meant to be fixes only; these two came along anyway. A one-off.)
- **Off switches** for the gank diary, Glacial Progress, the stash, events and logs, in
  `/dt settings`. Off, a module hears nothing and says nothing. Switching one off doesn't take you
  off guildies' boards; its sharing setting does that.
- `/dt played` with sharing off tells you how to switch it on.
- `/dt debug fit` reports any text that doesn't fit, if you'd like to help find the next one.

## Install
1. Quit WoW. Back up `WTF\Account\<you>\SavedVariables\DeadTired.lua`.
2. Delete the old `Interface\AddOns\DeadTired` folder.
3. Unzip `DeadTired-0.3.1.zip` into `Interface\AddOns\` (you get `Interface\AddOns\DeadTired\DeadTired.toc`).
4. Log in. Everything from 0.3.0 comes with you.
