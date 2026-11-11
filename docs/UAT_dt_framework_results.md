<!-- walked=2026-11-10..11 commit=e7521d6 (claude/hopeful-thompson-4rpsrp; installed dist/DeadTired-0.2.0-fw1.zip, sha256 c91d5d81a1021085162222b03b798ee36bd331d80bde542b69da9ef9e815a4c3, matched the branch's zip byte for byte; libraries passed SHA256SUMS on the PC) host=lucasgoonpc (Windows, WoW Forever 1.60.1, interface 16001) dirty=n/a: walked the installed zip, not a checkout by=Tim (Stromham) with EchoOfMany (Echo Nightclaw), Liliac (Lilbit High) and Vespera Grimm closer=Claude session. No stamp convention exists in this repo; these fields are the ones that apply. -->
# Results: DEAD TIRED framework round (dt_framework, 0.2.0-fw1), walked 10-11 Nov 2026

Walked by **Tim** in game on Stromham Hamson (CAMWOW EU4 Realm 2 PvP), with three guildies on fw1:
**Echo Nightclaw** (Realm 2), **Lilbit High** (Liliac, EU4 Realm 4) and **Vespera Grimm** (EU5
Realm 8). Against `docs/COWORK_REPORT_dt_framework.md` on `claude/hopeful-thompson-4rpsrp`;
walk-sheet `docs/UAT_dt_framework.md`. The closing session verified the `[G]` checks and recorded
the `[H]` answers; it answered none of them. Evidence: Tim's screenshots and screenshot marks,
`DeadTired.lua` saved data, BugGrabber, and #dt-crypt-workshop (11 Nov 15:38-15:45).

**Outcome: 8 of 8 `[H]` pass.** The framework does what the brief asked, the rc3 taint is gone,
and four players on three connected realms see each other with no key mismatches. Layout defects
were found and deferred by Tim to the next round (*"honestly minor imo - nothing breaking it"*).

## [G] checks (verified by the closing session)

| Check | Evidence | Result |
|---|---|---|
| G1 Libraries | Closer re-ran `run_all.sh` on 11 Nov: `libs: unmodified (SHA256SUMS)`. `DeadTired/Libs/` holds LibStub, CallbackHandler-1.0, AceComm-3.0 (+ ChatThrottleLib), LibSerialize, LibDeflate, LibSharedMedia-3.0; no LibDataBroker or LibDBIcon anywhere in `DeadTired/` (find) | pass |
| G2 Taint cause | Report, Task 1: rc3 `Core.lua:305` `SlashCmdList = SlashCmdList or {}`, copied from Wizardry's core. Closer read fw1 `Core.lua:412-415`: only `SLASH_DEADTIRED1/2` and `SlashCmdList["DEADTIRED"]` | pass |
| G3-G10 | Closer re-ran all 12 suites on 11 Nov: 320 checks, ALL GREEN (core, guild, keys, comms, settings, skins, ui, settings view, bar, debug, who, taint). Closer read `Keys.lua` (own key from `GetUnitName("player", true)`) and `Comms.lua` (hold on `InChatMessagingLockdown`; restricted flag recorded only) | pass |
| G11 Guards | Report, Task 11: 27 removals, each turned a named check red, files restored byte-identical (`tools/guard_proofs.lua`). Not re-run by the closer | from the report |
| G12 Zip | Report: `diff -r` clean. Closer: the zip downloaded to Tim's PC hashed identical to the branch's | pass |

## [H] checks (Tim's words)

| Check | Tim said | Evidence | Result |
|---|---|---|---|
| **H1** Log in: one welcome line; the old-records line once; BugSack quiet. Wording ruling. | *"tests for H5 H1 and H2 are done. They are passes so far"*; on wording: *"you can keep those text blocks as they are."* | `Dead Tired Rest in Pieces, Stromham Hamson. The crypt's open.`; saved data `legacySaid = true`, rc3 data under `legacy`; Liliac's first login showed *"Your old crypt records are kept for the move."* once | **pass**; wording kept |
| **H2** Bar with intro once; shows DT and other addons; drag; survives /reload. Wording ruling. | as H1 | Bar hosts Dead Tired, DT: n online, AtlasLoot, BugSack, DBM, ForeverAuras, Nova, PallyPower, DungeonJournal, Leatrix Plus, Prat; *"DeadTired's bar has risen. /dt bar off to bury it."* once (Liliac too); `bar.mode = off/on` 09:43; position saved; mark 01:26 *"bar moves"* | **pass**; wording kept |
| **H3** Both skins look like themselves. | *"the skins work. I've done a reload as well."* | Shots 09:53 (Dead Tired: gothic, green) and 09:55 (Forever: plain stone); mark 01:27 *"skin change worked"* | **pass** |
| **H4** Settings open 3 ways; plain words; UI ⇄ `/dt get|set` round trip. | *"dt settings command worked and also clicking on Dead Tired on the bar and from the mini map addon compartment."*; *"H4 tests in now as well that bit is working."* | Shot 09:58: addon compartment lists Dead Tired | **pass** (layout defects below) |
| **H5** Taint gone: `/run print("risen")`, `/invite`, BugSack quiet (Wizardry off). | as H1 | 09:42:12 `risen`, no pop-up; 09:42:17 *"You have invited Vespera Grimm to join your group"*; BugSack *"You have no bugs, yay!"* (its only error dated 9 Nov, Prat) | **pass** |
| **H6** Each side lists the other once, realm shown for other realms, never yourself as someone else. | *"yes it's a pass on both"* | Tim (Realm 2): `Echo Nightclaw`, `Vespera Grimm (CAMWOW EU5 Realm 8 PvP)`, "DT: 2 online". Liliac (Realm 4): `Echo Nightclaw (CAMWOW EU4 Realm 2 PvP)`, `Stromham Hamson (CAMWOW EU4 Realm 2 PvP)`, `Vespera Grimm (CAMWOW EU5 Realm 8 PvP)`; himself absent | **pass** |
| **H7** `/dt debug senders` and `/dt debug names` both sides. | *"yes it's a pass on both"* | Senders, **key mismatches 0** on Tim (7 senders), Echo (3) and Liliac (4). Every sender string arrives **without a realm** (`"Vespera Grimm"`, `"Lilbit High"`), cross-realm included; the payload key supplies it. Names: Tim and Echo (`"Echo"`, `"Echo" / "Nightclaw"`, `"Echo Nightclaw"`, key `CAMWOWEU4Realm2PvP-Echo Nightclaw`) | **pass** |
| **H8** (optional) Boss fight: held line once; answer after. | *"H8 tests done and I've reloaded - seems to be working correctly."* | 10:16:37 in Ragefire Chasm vs Oggleflint: *"The dead are gagged for this fight. Your message goes when it's over."* once; second shot 10:16:49 none; saved `comms.held = 1`, last send 10:17:12 (after the kill); `sendRefused 0`, `refusedDropped 0` | **pass** |

## Defects and requests the walk found (for Port 1; deferred by Tim)
1. **Settings rows are fixed height:** long descriptions overlap the next row; last line cut off
   (Tim's mark 01:27; Echo, 15:39 *"over lapping and cut off text"*).
2. **The first setting (guild welcome) is hidden under the search box.**
3. **Bar shows other addons' colour codes raw** (Prat: `|cff8080ff3.0|r`).
4. **Who rows overlap** when a name + realm wraps (Liliac's screenshot).
5. **Empty Who window** needs an empty-state line.
6. Tim, *bad:* *"Update the Who panel to include the current player"*.
7. Tim, *feat:* *"Being able to choose which addons are selected for the bar"* (since ruled: off by
   default, ordered by drag) and *"add info that we've captured to the bar (like the current
   session stats."*
8. Tim, 15:50: *"we maybe need to clean up the shown names (the actual realm these days shouldn't
   make a difference to us playing on the same rule set."* (A display ruling for Port 1; keys still
   carry the realm, since two players on different realms can share a name.)

## In the brief, the walk-sheet or the probe
- **Forever: `UnitFullName` returns the surname, not the realm** (`"Stromham", "Hamson"`; target
  `"John", "Do"`; `"Echo", "Nightclaw"`). The brief assumed retail's meaning. Port rule recorded in
  `FEATURES.md`.
- **Sender strings never carry a realm** on Forever, even cross-realm. The payload-key design (this
  brief's requirement 2) is what makes connected realms work.
- **A solo dungeon boss triggers chat lockdown**, so H8 was walkable solo.
- The walk-sheet's H6 assumed one other player; four took part, which was better evidence.
- **WizardryLedger still carries the rc3 taint line**; H5 needed Wizardry off. Fix pending in Wizardry.

## Not answered
Nothing. All eight `[H]` checks answered by Tim.
