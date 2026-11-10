# Walk-sheet: DEAD TIRED framework (0.2.0-fw1)

For `docs/COWORK_BRIEF_dt_framework.md`. **[G]** = the session proves it offline and shows the
evidence in its report; **[H]** = Tim, in game, with `dist/DeadTired-0.2.0-fw1.zip`. Screenshot every
[H]: addon lines don't reach the chat log. Never tick this file.

**Before the walk:** move rc3's `Interface\AddOns\DeadTired` to `Interface\AddOns_parked\DeadTired-rc3`,
install fw1 in its place, and back up `WTF\...\SavedVariables\DeadTired.lua`. Swap back after the walk.

## Offline [G]
- [ ] G1 Libraries vendored unmodified, each with licence and source; LibDataBroker's licence quoted.
- [ ] G2 rc3 taint cause confirmed or corrected, with the line.
- [ ] G3 Module core: registry, verbs, help, disabled module silent, errors counted; guild gate silent.
- [ ] G4 Keys: two-part names; own vs connected realm; display.
- [ ] G5 Comms: R-1, held line once per hold, AUD-10, protocol version, payload key match/mismatch,
      sender with and without `-Realm`.
- [ ] G6 Settings: every setting has a verb or a `noVerb` reason; `/dt set|get` validate and save.
- [ ] G7 Skins resolve for both; list filters; toasts only when switched on; viewport position saved.
- [ ] G8 Bar: DT and third-party LDB objects shown; stands back for a display addon; intro once.
- [ ] G9 Taint scan green on DT; red when `SlashCmdList = SlashCmdList or {}` is inserted.
- [ ] G10 Who: HELLO both ways; self never listed as other; rate limit; LDB count.
- [ ] G11 Every guard in Task 11 removed once → a named check red → restored.
- [ ] G12 Zip built, `diff -r` clean, `run_all.sh` green.

## In game [H]
- [ ] H1 Log in on Stromham: one welcome line; the old-records line once; BugSack quiet.
      Tim's ruling on the wording "Your old crypt records are kept for the move."
- [ ] H2 The bar appears with "DeadTired's bar has risen. /dt bar off to bury it." once; next login
      no intro. It shows DT's `DT: n online` and other addons' buttons (AtlasLoot, BugSack, DBM,
      Leatrix, Naowh...). Drag it; `/reload`: it stays. Tim's ruling on the intro wording.
- [ ] H3 `/dt skin deadtired` and `/dt skin forever`: both look like themselves. Screenshot-mark
      what to change in the Dead Tired skin.
- [ ] H4 `/dt settings` (and Settings → AddOns → Dead Tired, and the addon compartment): the settings
      viewport opens; every setting reads in plain words; one changed there shows in `/dt get`, one
      changed with `/dt set` shows there.
- [ ] H5 **Taint gone:** with fw1 loaded, `/run print("risen")` prints with no blocked-action
      pop-up; `/invite` (any name) gives no "blocked" error; BugSack quiet. Best of all, a guildie who
      has never accepted scripts accepts the prompt with fw1 loaded.
- [ ] H6 With Liliac on fw1 (Realm 4): `/dt who` on each side lists the other once, with the realm
      shown for the other realm, and **never yourself as someone else**.
- [ ] H7 `/dt debug senders` and `/dt debug names` on both sides: screenshot (records the raw
      cross-realm sender shape for the port round).
- [ ] H8 Optional, in a dungeon boss fight: `/dt who` prints the held line once; the answer comes
      after the fight.
