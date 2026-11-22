# Dead Tired 0.3.7: a stethoscope for the crypt

Zip: `dist/DeadTired-0.3.7.zip`.

The guild addon for <DEAD TIRED>. Still optional, still quiet. Nothing changes for you in this one.

## New, for the officers who test things
- **`/dt debug fontprobe`.** The game keeps turning away Dead Tired's gothic title font, and it may be why
  switching skin doesn't repaint an open window. This tool writes down every font Dead Tired asks for and
  what the game said back, so the next version can fix it properly. It's off unless you switch it on, and
  only for the session.

## Known scruffiness
- **Switching skin** still doesn't repaint a window that's already open. Close it and open it again.

## Install
1. Quit WoW. Back up `WTF\Account\<you>\SavedVariables\DeadTired.lua`.
2. Delete the old `Interface\AddOns\DeadTired` folder.
3. Unzip `DeadTired-0.3.7.zip` into `Interface\AddOns\` (you get `Interface\AddOns\DeadTired\DeadTired.toc`).
4. Log in. Everything comes with you.
