# Dead Tired 0.7.0: the Crypt's Table deals faster

Zip: `dist/DeadTired-0.7.0.zip`.

The guild addon for <DEAD TIRED>. Still optional, still quiet, still a bad influence. The table got buttons, because nobody wants to type "Bartholomew Longname-Grimshaw" with a drink in one hand.

## New
- **New game.** Press it in `/dt gamble`: pick a stake (10, 50, 100, 250, 500 or your own), then click a party member for a deathroll, or open a high-low table. No more typing two-word names.
- **Challenge your target.** Target a party member and press Challenge target, or type `/dt gamble deathroll 100`. Only their name is read, only when you press, and only for someone in your party.
- **Accept or Decline.** A challenge now asks. Declining tells the challenger straight away.
- **Cancel and Leave.** Hosts can cancel before the dice roll; joiners can leave before the call.
- **Rematch, Double or nothing, Same again.** Lilbit asked for a re-bet. After a deathroll either of you can offer the same stake again, or double it; the other has to accept. After a high-low, the host can run the same table again.
- **Your turn.** The Roll button glows when it's your roll. `/dt gamble sound on` adds a bell. It's off unless you switch it on.
- **A Table button for the bar:** `/dt bar add gamble`. Click for the table, right-click for the ledger.

Still play chips only, still nothing posted to chat. Players on 0.6.0 can still play with you; they just can't decline or leave, and the old time-out still tidies up.

## Install
1. Quit WoW. Back up `WTF\Account\<you>\SavedVariables\DeadTired.lua`.
2. Delete the old `Interface\AddOns\DeadTired` folder.
3. Unzip `DeadTired-0.7.0.zip` into `Interface\AddOns\`.
4. Log in. Everything comes with you.
