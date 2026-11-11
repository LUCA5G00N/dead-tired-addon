# Dead Tired 0.2.0: the crypt reopens

**Draft. Tim publishes it** (GitHub release + Discord). Zip: `dist/DeadTired-0.2.0.zip`.

The guild addon for <DEAD TIRED>. Optional, quiet, and useless outside the guild. Only guildies
who run it show up in it, so the more of us rot in it, the better it gets.

## What's in it
- **Rest in Pieces.** When a guildie running Dead Tired dies, you hear about it, one line. Your
  own deaths stay yours until you `/dt rip share on` (hardcore included). `/dt rip` opens the
  graveyard, and you can search it. `/dt rip off` if you'd rather not know.
- **Bedtime.** `/dt bedtime 23:30` and it nags you, three times at most. `/dt bedtime off` when
  you've given up.
- **Mains and alts.** `/dt main` on your favourite; `/dt alts` shows the family; `/dt alts <name>`
  shows anyone else's.
- **Raid prep.** Officers set the raid-night list (`/dt prep add`). `/dt prep check` holds your bags
  against it. Nobody sees your bags. `/dt prep roll` asks who's ready, if they've switched it on.
- **Recruiting (officers).** A **Recruit** button on the bar posts the next line to General, one
  click per post, 15 minutes apart. `/dt recruit` does the same.
- **Who.** `/dt who`: who's running it. You're at the top now, in case you forget.
- **The bar.** Other addons' buttons now wait in the settings until you tick them; drag to order.
  Tick **Session** for this session's time and body count.
- **Names without realms.** `Vespera Grimm`, not `Vespera Grimm (CAMWOW EU5 Realm 8 PvP)`. The realm
  is in the tooltip. Your old records from 0.1.0 come with you.

## Install
1. Quit WoW. Back up `WTF\Account\<you>\SavedVariables\DeadTired.lua` if you're the careful sort.
2. Delete the old `Interface\AddOns\DeadTired` folder.
3. Unzip `DeadTired-0.2.0.zip` into `Interface\AddOns\` (you get `Interface\AddOns\DeadTired\DeadTired.toc`).
4. Log in. One line says hello. `/dt` lists the rest; `/dt settings` for the switches.

## Coming in 0.3.0
The gank diary, play time and the stash, guild event reminders, and the combat-log prompt.
