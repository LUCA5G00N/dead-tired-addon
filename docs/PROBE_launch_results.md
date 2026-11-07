# Probe results: launch (WoW Forever, 5-7 Nov 2026)

What `DeadTiredProbe` 0.1.0 (`card/dt_probe` a25b538) recorded on the live client. Drafted by a
session from the saved files; **Tim checks it**. This is the results doc the probe brief points
at. It is not a walk result: `UAT_dt_probe.md` is still Tim's to walk.

**Verdict: fork A: addon messages work.** Superseded on 7 Nov 12:56-13:20 UK (see *Update* below).
The probe found the restricted flag true on every login and held its ping, so the first draft of
this doc (and Tim's 11:00 ruling) said fork B. Two hand tests then showed messages get through
while the flag still says restricted: the flag is misleading on Forever (reason 4 in the restart
note). Tim's account type was checked as well: not trial, not Veteran.

## Update, 7 Nov 12:40-13:20 UK (hand tests, Tim's screenshots)

| Time | Test | Result |
|---|---|---|
| 12:40 | `/dump IsTrialAccount(), IsVeteranTrialAccount()` | `false`, `false` (Tim's account is subscribed) |
| 12:56:25 | `SendAddonMessage("DTT","hi","GUILD")` typed by Tim (two macros), flag still restricted | returned **0** (Success) |
| 12:56:26 | `CHAT_MSG_ADDON` listener for prefix DTT | **`heard hi GUILD Stromham Hamson`**: the server took it and delivered it back |
| ~13:20 | Naowh Forever's Group Inspect, in a party with Echo Nightclaw (also running Naowh) | "Everyone inspected": Echo's gear, talents and stats arrived by addon message, both ways |

Why the probe never saw this: it obeys the house rule (`CLAUDE.md`: anything sent while
restricted is queued), so it never sent. Naowh Forever 1.2.14 sends to GUILD, PARTY and WHISPER
checking only `InChatMessagingLockdown` and the send result, never the restricted flag.

**Consequence for DeadTired (a ruling for Tim, not applied here):** as built, DeadTired would hold
every message for ever. The house rule needs changing to: hold while `InChatMessagingLockdown` is
true; otherwise send and record the `SendAddonMessage` result (AUD-10's enum). Until then, every
shared feature on rc2 is silent.

## Sources
- `_forever_\WTF\Account\LUCASGOON\SavedVariables\DeadTiredProbe.lua` after the 7 Nov 10:51
  logout, and Tim's backups of it and its `.bak` in `Documents\DeadTired\probe_backups\`
  (2026-11-06_2256, 2026-11-07_0357, _1045, _1051). Runs were merged by character and login time;
  where a run appears in several files, the latest save is used.
- Tim's screenshots of the chat frame, 7 Nov 10:31-10:50 (the probe's one-line replies).
- `!BugGrabber.lua` for one silent `/run` error (card 2's step 3, see the recipes results).
- The probe keeps 5 runs per character. **Two early Stromham runs (5 Nov, before the guild was
  formed) dropped out before the first backup.** They are known only from the 6 Nov restart note
  and one session read: 5 Nov 18:17 UTC, not in a guild, restricted true, register 0.

All times UTC. Server time is UTC+1 (`GetGameTime` 11:27 at 10:27 UTC).

## Every run

22 logins on 6 characters; 20 still in the files.

| # | Login | Character | Lvl | Guild (rank) | Restricted | Typed steps | Notes |
|---:|---|---|---:|---|---|---|---|
| - | 5 Nov (early) | Stromham | ? | no | true | - | dropped; restart note only |
| - | 5 Nov 18:17 | Stromham | ? | no | true | - | dropped; one session read |
| 1 | 5 Nov 11:52 | Moomoo | 1 | no | true | - | |
| 2 | 5 Nov 19:58 | Marvella | 1 | no | true | - | |
| 3 | 5 Nov 20:13 | Stromham | 12 | Guild Master | true | - | first run in the guild still on file |
| 4 | 5 Nov 22:22 | Moomoo | 1 | no | true | - | bank opened |
| 5 | 5 Nov 22:22 | Moomoo | 1 | no | true | - | (a `/reload`) |
| 6 | 5 Nov 22:24 | Stromham | 13 | Guild Master | true | - | died in Ragefire Chasm |
| 7 | 6 Nov 12:16 | Stromham | 15 | Guild Master | true | - | died in Silverpine Forest |
| 8 | 6 Nov 19:05 | Gizzardthe | 1 | no | true | - | |
| 9 | 6 Nov 19:09 | Stromham | 15 | Guild Master | true | - | |
| 10 | 6 Nov 19:23 | Marvella | 3 | no | true | - | |
| 11 | 6 Nov 19:39 | Stromham | 15 | Guild Master | true | - | died in Ragefire Chasm |
| 12 | 6 Nov 21:39 | Moomoo | 1 | no | true | - | |
| 13 | 6 Nov 21:39 | Moomoo | 1 | no | true | - | (a `/reload`) |
| 14 | 6 Nov 21:40 | Stromham | 16 | Guild Master | true | - | |
| 15 | 7 Nov 00:00 | Marvella | 4 | **Initiate** | true | - | the non-officer reading |
| 16 | 7 Nov 00:03 | Jobbi | 1 | no | true | - | died on Zephras Isle |
| 17 | 7 Nov 01:00 | Stromham | 16 | Guild Master | true | - | died twice in The Barrens |
| 18 | 7 Nov 10:26 | Stromham | 18 | Guild Master | true | ping, channels, items, bags, bank, `/played`, calendar, recipes ×3 | **the G6 run** |
| 19 | 7 Nov 10:48 | Stromham | 18 | Guild Master | true | recipes ×2, calendar | |
| 20 | 7 Nov 10:51 | Stromham | 18 | Guild Master | true | - | |

`InChatMessagingLockdown` was false on every run. No run recorded an error, a blocked action, or
an addon message heard.

## By section

| Section (card question) | Forever says | What it means |
|---|---|---|
| **comms: restricted** (card 1, all shared features) | `AreOutgoingAddonChatMessagesRestricted` **true on 22 of 22 logins**: in and out of the guild, levels 1-18, six characters, fresh logins and reloads, out of combat, never in lockdown | The flag is **misleading**: messages go through anyway (*Update*). Under the current house rule DeadTired would hold for ever |
| **comms: ping** (card 1 G-checks) | Run 18, 10:33:22: `held on GUILD: addon messages restricted`. Retried 13 times; saved as `<gave up: still restricted after 60 s>`. Nothing was sent (house rule: held, not forced) | The flag doesn't lift within a minute. The probe never sent; the hand tests (*Update*) did, and got through |
| **comms: prefix** (AUD-10) | First registration returns **0** every login. In run 18 the ping registered again and got **1** | It's an enum: 0 = Success, 1 = DuplicatePrefix. **The probe's `registered = false` is the probe misreading**; registration works. Card 1's `Comms.lua` ignores the return, so it isn't affected |
| **guild** (cards 1, 5) | Stromham: `DEAD TIRED`, Guild Master, rank 0, officer true, can speak true. Marvella (run 15): Initiate, officer **false**, can speak true. Before guild data loads, `GetGuildInfo` answers nil for about a second after login, then fills in | The guild gate and the officer check have real values both ways. Step 9's "officer flag seen both ways" is met by an alt, not a guildie |
| **build** (card 1 P2) | 1.60.1 **70790** (3 Nov) until 7 Nov 01:00; **70862** (6 Nov) from 7 Nov 10:26. Interface **16001** throughout. `WOW_PROJECT_ID` 18. Game mode 1 | A client patch overnight on 6-7 Nov. No `.toc` change needed |
| **realm** (AUD-06) | `CAMWOW EU4 Realm 2 PvP`, normalised `CAMWOWEU4Realm2PvP` | The AUD-06 ruling picks one of these for `Realm-Name` keys |
| **hardcore / self-found** (card 3 G11) | Hardcore false, self-found not allowed, on every run | "No hardcore realm" for G11 |
| **channels** (card 5) | General is channel **1** (local ID 1) in every zone recorded (Orgrimmar, Undercity, Tirisfal, Silverpine, Zephras Isle). 5 active channels (6 on Zephras Isle) | Card 5's recruit post can find General |
| **bags** (card 6 stash) | All bags read: 20 + 8 + 6 + 6 + 6. With the bank open, `CharacterBankTab_1` (index 6) has 48 slots; other bank and account tabs 0. **`isBound` is a real true/false on every slot**, and agrees with `C_Item.IsBound` by location on every slot of every snapshot (170 slot reads, 0 disagreements). E.g. 6948 (Hearthstone) bound, 2862 unbound | Card 6 can share only unbound items, as ruled. The bank is retail-style tabs: card 6's bank read should use the `Enum.BagIndex` tab indices |
| **items** (card 5 prep) | 8 of 8 names arrive within 30 s of asking (0 named at once, all received) | Normal item cache. `/dt prep` should wait for item data, as built |
| **played** (card 6) | Hook placed every login; 2 automatic `TIME_PLAYED_MSG` per login. Run 18: typed `/played` counted (`typed` 1, stamp 0.11 s old); `RequestTimePlayed()` arrived without a stamp | Card 6 can tell a typed `/played` from one it didn't ask for, as ruled |
| **calendar** (parked: Raid-Helper into the calendar) | `OpenCalendar` answers by event. 14 days read; holidays have titles, types and start times (Call to Arms: AB/WSG/Darkspear Islands, Darkmoon Faire from 9 Nov, Stranglethorn Fishing Extravaganza). No guild events exist yet | Reading the calendar works. Guild events are untested |
| **instances** (card 7) | Ragefire Chasm reads as instanced, type `party`; open world reads `none` | Card 7's dungeon detection has what it needs |
| **death** (card 3) | Each death recorded with zone, level and instance (RFC as `party`; Silverpine, The Barrens and Zephras Isle as open world) | Card 3's graveyard has the fields it uses |
| **logging** (card 7) | At login, combat and chat logging always read the **same** (both on or both off), varying login to login. Combat logging was on inside RFC. Log files are written to `_forever_\Logs` | Logs work on Forever. Something switches both together; `WizardryLogPrompt` is still installed and is the likely one. Move it out before walking card 7 |
| **recipes** (card 2) | See `PROBE_guild_recipes_results.md`. **Native: doesn't work** | |
| **target** (card 4) | Not run | Tim will run it when Alliance are about |
| **logging try** (card 7) | Not run | Optional |

## Gaps
- **No guildie run of the probe.** Not needed now: the cross-player test was Naowh's Group Inspect
  with Echo. A guildie's restricted flag is still unread (it doesn't matter if the rule changes).
- **The probe's own ping** never sent (house rule). It would need the rule change to test.
- **Target** and **logging try** not run yet.


## For the rulings round
- **AUD-10:** record `SendAddonMessage` and `RegisterAddonMessagePrefix` results as the enum
  (0 = Success). Fix the probe's `registered` read at the same time.
- **AUD-06:** pick the `Realm-Name` key form (spaced or normalised).
- **The restricted-flag rule** (above): the first ruling, because every shared card depends on it.
- **Held-queue wording:** for lockdown only (boss fights, M+, PvP matches): say plainly it's held.
- **Card 2:** its directory can work as drafted once the rule changes; native lookup is still off.
