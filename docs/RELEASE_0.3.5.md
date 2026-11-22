# Dead Tired 0.3.5: the corpse examines itself

Zip: `dist/DeadTired-0.3.5.zip`.

The guild addon for <DEAD TIRED>. Still optional, still quiet. Nothing it does for you has changed.

## New
- **`/dt selftest`.** Dead Tired checks itself from the inside: that it knows who you are, that the
  game still gives it what it needs, that its windows fit, that switched-off parts stay quiet, that
  your saved data is in order. One line back: how many checks passed and how many didn't. If something
  failed and you're asked about it, run it, `/reload`, and say so.
- **A pretend guildie, for the officers who test things.** `/dt debug ghost` raises the Restless
  Ghost, who says hello, dies, holds grudges and answers your stash searches, so a feature can be
  tested without a second person online. It never talks to the guild, and nothing of it is kept:
  `/dt debug ghost off`, a logout or a `/reload` lays it to rest.

## Known scruffiness
- **Switching skin** still doesn't repaint a window that's already open. Close it and open it again.

## Install
1. Quit WoW. Back up `WTF\Account\<you>\SavedVariables\DeadTired.lua`.
2. Delete the old `Interface\AddOns\DeadTired` folder.
3. Unzip `DeadTired-0.3.5.zip` into `Interface\AddOns\` (you get `Interface\AddOns\DeadTired\DeadTired.toc`).
4. Log in. Everything comes with you.
