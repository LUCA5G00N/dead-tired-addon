# Cowork brief: DEAD TIRED crypt (Rest in Pieces death notices, graveyard memorial, bedtime nag)

**Where you are:** repo `dead-tired-addon`, a cloud session. Work on branch **`card/dt_crypt`**,
created from **`card/dt_foundation`** (ROADMAP rule 1), never from `main` or another card. No
game client is available; everything is proved offline with stubbed tests, then Tim walks it in
game. If the harness assigns you a different branch name, create that branch from
`card/dt_foundation` and say so in the report.

**Read before Task 1, in order:**
1. `CLAUDE.md` (house rules; they bind throughout this round).
2. This brief, then `docs/UAT_dt_crypt.md`.
3. `docs/COWORK_REPORT_dt_foundation.md` (what card 1 actually landed, and how its tests work).
4. `DeadTired/Core.lua`, `Comms.lua`, `Roster.lua`, `tests/harness.lua`, `tests/test_roster.lua`
   (the code and test patterns to build on).
5. `reference/SPEC_forever_namespaces.md`: search it, don't read it top to bottom.

**Draft-status:** **proposed, not ratified.** Written 2026-11-02, after card 1 was reported (card 1
head `61fe2d3` on `claude/loving-meitner-yzdxtn`) and **before card 1 has been walked in game**.
Every "already exists" claim below is about that commit, and Task 1 re-verifies each against the
branch you actually start from. Card 1 may get fixes on launch night (4 Nov). If
`card/dt_foundation` has moved past `61fe2d3`, re-read the files above before trusting this
brief's names. The live Forever client may differ from the beta build the API reference
describes, and **it is not known whether Forever has hardcore realms at launch.**

## Origin

Tim's idea list (`L5GN/_desk/dead-tired_addon_ideas.md`, 2026-11-02), carded as card 3 in
`docs/ROADMAP.md`: **"Rest in Pieces" death notices, graveyard memorial, bedtime nag**. The
roadmap's design note for this card: *a death notice carries name, level and zone only. Killer
needs combat data, which the client doesn't give addons. Hardcore deaths are the point;
normal-realm deaths are off by default.* The roadmap's plan builds cards 3, 4 and 5 before launch,
while the cloud credit lasts, and walks them after card 1.

## Precondition

- P1: `card/dt_foundation` exists on origin and holds card 1 (`DeadTired/` 0.1.0, the six suites
  green, `docs/COWORK_REPORT_dt_foundation.md`). Check it with
  `git ls-remote origin card/dt_foundation` and `sh DeadTired/tests/run_all.sh` → exit 0.
- P2: Tim has ratified R1-R3 below (each marked `ratified` in this file, or ruled otherwise).

## Depends on: rulings

This repo has no numbered rulings. The binding rules are `CLAUDE.md` and `docs/ROADMAP.md`'s
"Branching and testing rule" (rules 1, 2 and 5 bind here). Card 1's brief adopted two disciplines
from Tim's `WoWWizardry` repo, and they carry over unchanged:
- **WoWWizardry 0012 clause 4** (as applied in card 1): every guard listed in Task 9 is removed
  once to prove a check goes red, then restored.
- **WoWWizardry 0003 / 0017**: characters are keyed `Realm-Name`.

## Ratify before code

The round may not be built while any of these is `proposed`.

- **R1 (proposed): guildies' death notices print unasked.** This is a widening of CLAUDE.md's
  "quiet by default"; see *The one deliberate widening*. Proposal: received notices print by
  default, one line each; `/dt rip off` silences them per account.
- **R2 (proposed): your own hardcore death is shared by default.** CLAUDE.md says anything
  personal is opt-in. Proposal: on a hardcore character, your death (name, level, zone) is sent
  unless you've run `/dt rip share off`. The roadmap calls hardcore deaths "the point", and an
  opt-in nobody turns on would leave the feature empty. On a normal character nothing is sent
  until `/dt rip share on`, as the roadmap says.
- **R3 (proposed): what this card may change in card 1's files.** Two lines, nothing else:
  `Crypt.lua` appended to `DeadTired.toc` after `Welcome.lua`, and `crypt:Crypt` appended to the
  module list in `tests/run_all.sh`. `DT.VERSION` and `## Version:` stay `0.1.0`; Tim sets the
  version when he merges. Anything more in a card 1 file is ROADMAP rule 5, and it stops the round.

## Builds on (card 1, commit `61fe2d3`; Task 1 re-verifies each)

`DT.module{}`, `DT.verb(prefix, fn, usage)`, `DT.send(kind, fields)`, `DT.on(kind, fn)`,
`DT.isMember()`, `DT.listen("member", fn)`, `DT.guildKey()`, `DT.charKey()`, `DT.display(key)`,
`DT.safe(s, max)`, `DT.stamp()`, `DT.now()`, `DT.after(d, fn)`, `DT.try`, `DT.clean`, `DT.out`,
`DT.db()`, `DT.errors()` (Core, Guild, Comms, Roster). Test side: `tests/harness.lua` with
`H.world()`, `world:client{...}` (its `files`, `db`, `random`), `client:login()`, `:logout()`,
`:slash()`, `:said()`, `:fire()`, `world:advance()`.

## Deliverable

One new file, **`DeadTired/Crypt.lua`** (a module registered through `DT.module{}`), and
**`DeadTired/tests/test_crypt.lua`**, plus the two lines from R3:

- **Death notice.** On `PLAYER_DEAD`, a member records the death and, when R2 allows, sends
  `DEATH {lvl=<level>, zone=<zone>, hc="1"|"0"}` once. Every other member running the addon
  records it, and prints one line if `/dt rip` is on.
- **Graveyard memorial.** `/dt graveyard` prints the newest 10 recorded deaths, then always the
  line *"Only guildies running the addon, and only deaths seen while you were online."*
- **Bedtime nag.** Off by default. `/dt bedtime HH:MM` sets a local time; from then on, a member
  gets one dry line at that time and then every 30 minutes, at most 3 a night. Nothing is sent.

**Testable end:** `DeadTired/tests/run_all.sh` exits 0 with seven suites; and in game, when
Tim's character dies with sharing on, a guildie on 0.1.0 + crypt sees one notice naming the
character, level and zone, and `/dt graveyard` on both lists it.

### Crypt.lua: specification

**Store.** `DeadTiredDB.crypt` is created by Crypt.lua itself (not by `DT.db()` in Core; R3):
`crypt = { rip = true, share = nil, bedtime = nil, [<guildKey>] = { deaths = { ... } } }`.
- `rip`: show received notices (default `true`, R1).
- `share`: `nil` means "by default" (R2): hardcore on, normal off. `true` or `false` once set by
  `/dt rip share on/off`; then it applies to both.
- `bedtime`: `nil` (off) or `"HH:MM"`, 24-hour, zero-padded.
- A death record: `{ who = <Realm-Name>, lvl = <number>, zone = <string>, hc = <bool>,
  at = <DT.stamp()>, mine = <bool> }`. Newest is appended last. The list is capped at **100**;
  the oldest goes first.

**Hardcore.** `isHardcore()` = `DT.try(C_GameRules and C_GameRules.IsHardcoreActive) == true`.
Absent, erroring or secret means not hardcore.

**On `PLAYER_DEAD`** (member only; a non-member does nothing, not even record):
1. Read `lvl = clean(try(UnitLevel, "player"))` (a number from 1 to 100, otherwise 0) and
   `zone = clean(try(GetRealZoneText))` (a non-empty string, otherwise `"somewhere"`; truncated
   to 48 bytes).
2. `hc = isHardcore()`. **Battlegrounds and arenas never count as hardcore:** if
   `select(2, try(IsInInstance))` is `"pvp"` or `"arena"`, `hc = false`.
3. **At most one death per 60 seconds** (by `DT.now()`) is handled; another `PLAYER_DEAD` inside
   the window is ignored entirely.
4. Record it locally with `mine = true`, whatever the sharing setting.
5. Send `DEATH` when `share == true`, or `share == nil and hc`.

**On receiving `DEATH`** (via `DT.on`, so card 1's member gate, own-message ignore and malformed
handling already apply):
- Validate: `lvl` is a decimal integer 1-100; `zone` is 1-48 bytes; `hc` is `"0"` or `"1"`.
  Anything else is ignored and counted in `DeadTiredDB.crypt.badDeath`.
- Record it (`mine = false`). If `rip` is on, print one line:
  - hardcore: *"Rest in Pieces: <Name>, level <lvl>, <zone>. Hardcore. Gone for good."*
  - normal: *"<Name> died at level <lvl> in <zone>. Again."*
  Names go through `DT.display`, the zone through `DT.safe`.
- **Nothing replies to a DEATH**, and nothing is re-sent.

**`/dt graveyard`:** newest first, at most 10 lines, each
`<stamp date part YYYY-MM-DD> <Name> <lvl> <zone>` with ` (HC)` on hardcore deaths. If the list is
empty: *"The graveyard's empty. Give it time."* Then always the closing line above.

**`/dt rip on`, `/dt rip off`:** set `rip`. **`/dt rip share on`, `/dt rip share off`:** set
`share`. **`/dt rip`** alone: prints both settings in one line, with `share` shown as
`default (hardcore only)` while it is `nil`.

**Bedtime.**
- `/dt bedtime HH:MM` accepts `H:MM` or `HH:MM`, 00:00 to 23:59, and stores it zero-padded.
  Anything else prints the usage and changes nothing. `/dt bedtime off` clears it.
  `/dt bedtime` alone prints the setting.
- The local clock is `clean(try(date, "*t"))` (fields `hour`, `min`). If it is absent or not a
  table, the nag never fires.
- A ticker: `DT.after(60, tick)`, re-armed each tick, started on the first `PLAYER_ENTERING_WORLD`.
  Each tick, if a member with `bedtime` set: minutes since bedtime, mod 1440 = `m`. If `m < 360`
  (the 6 hours after bedtime, across midnight), the nag fires when `shown < 3` and either
  `shown == 0` or `m - lastM >= 30`, where `shown` counts nags since this night's bedtime and
  `lastM` is `m` at the previous nag. Both live in memory only, so a `/reload` may nag again.
  When `m >= 360`, `shown` resets to 0. (So a login 2 h after bedtime nags at once, then 30 and
  60 minutes later, not on consecutive ticks.)
- Lines, in order: *"It's <HH:MM>. Even the dead sleep."*, *"Still here. The crypt has a bed
  with your name on it."*, *"Last call. Log off before the sun gets you."*

**Wire.** `DEATH` is a card 1 message: `1^DEATH^hc~1^lvl~23^zone~Stranglethorn Vale`. The
longest, with a 48-byte zone, must be at most 250 bytes (see *Stop conditions*).

## Working rules

- **No combat data, ever.** No `COMBAT_LOG` event, no `CombatLog*` call, **no `C_DeathRecap`**
  (it exists on the beta client and names the killer: that is combat data), no
  `UNIT_DIED`/`PARTY_KILL`. `PLAYER_DEAD` says only that you died; level and zone are read from
  game state after it.
- **Nothing public.** No `SendChatMessage`; DEATH goes out only through `DT.send` (GUILD addon
  messages).
- **Every API call guarded.** `UnitLevel`, `GetRealZoneText`, `IsInInstance`, `date` and
  `C_GameRules.IsHardcoreActive` go through `DT.try` / `DT.clean`, and their absence is handled
  as specified above.
- **Card 1 is read-only** except for R3's two lines. If Crypt.lua seems to need a change in Core,
  Comms, Roster or the harness, **stop** (ROADMAP rule 5). Test helpers this card needs go in
  `test_crypt.lua`.
- **Inbound data is data.** A DEATH's fields are stored and printed through `DT.safe` /
  `DT.display`. They are never used to call game functions.
- **Two-client tests** for notices and the graveyard: card 1's harness, two members on one bus,
  plus a non-member client.
- **Quiet otherwise.** Crypt prints nothing at login.

## Tasks

1. **Re-verify.** Check P1. Check that every name under *Builds on* exists on your starting branch.
   Check in `reference/SPEC_forever_namespaces.md` that `C_GameRules.IsHardcoreActive` is present
   and `C_DeathRecap` is the namespace this brief bans. Record each result in the report.
2. Append R3's two lines. Create `DeadTired/Crypt.lua` with the store, the verbs `rip`,
   `graveyard`, `bedtime` (registered with usage strings, slash with no bar characters), and an
   empty module. Add `tests/test_crypt.lua` covering store creation and the verbs' settings.
   `run_all.sh` green.
3. **Own death:** the `PLAYER_DEAD` handler, steps 1-5, and its tests. Cover: a member records
   it; a non-member records nothing and sends nothing; normal deaths are not sent by default;
   hardcore deaths are sent by default; `share` on and off override both; a battleground or arena
   on a hardcore character counts as normal; a second death inside 60 s is ignored and one at
   61 s is not; missing `UnitLevel` / `GetRealZoneText` / `C_GameRules` fall back as specified.
   Green.
4. **Received deaths:** the `DT.on("DEATH")` handler and its tests, two clients. Cover: hardcore
   and normal lines exactly as specified; `rip off` records but prints nothing; each invalid
   field is counted in `badDeath`; nothing replies; a `|` in a zone is printed safely. Green.
5. **Graveyard:** `/dt graveyard` and its tests: empty text; newest first; 10 lines at most;
   `(HC)` marking; the closing line every time; the cap of 100. Green.
6. **Bedtime:** the ticker and its tests, with the clock stubbed in `test_crypt.lua`. Cover: off
   by default (no line, ever); fires at the time; then at +30 and +60 minutes; never a fourth; a
   bedtime of 23:45 still nags at 00:15 (across midnight); a login at bedtime +2 h nags at once,
   then 30 min later; nothing for a non-member; `/dt bedtime 25:00`, `7`, `ab:cd` are refused.
   Green.
7. **Byte budget:** a test that encodes the longest DEATH (lvl 100, a 48-byte zone of `^`
   characters, which escape to 3 bytes each, hc 1) and asserts it is at most 250 bytes.
8. **Full-addon check:** `test_crypt.lua` loads all eight files (card 1's seven plus Crypt.lua)
   on two members and a non-member. A death on one prints exactly one line on the other and
   nothing on the non-member, and a login prints nothing from Crypt (the welcome is still
   card 1's one line).
9. **Guard proofs.** Remove once, confirm a check goes red, restore: the member check in the
   `PLAYER_DEAD` handler; the normal-realm "not sent by default" rule; the battleground/arena
   rule; the 60-second death window; the `rip` print toggle; the DEATH field validation; the
   memorial cap; the bedtime 3-nag cap; the bedtime 6-hour window.
10. Write the report and push the branch.

## Explicitly out of scope

- **The killer, damage, or anything from `C_DeathRecap` or the combat log.** Not "just the
  killer's name", not "if it's there".
- **Sending the memorial to guildies, or syncing it** (catching up on deaths that happened while
  you were offline). Each client keeps only what it saw. History sync is a later card if Tim
  wants it.
- **A graphical panel, a death toast, a sound, or a raid-warning-style banner.** Chat lines only.
- **Posting deaths to guild chat or any public channel**, even with a click. That needs its own
  ruling.
- **Bedtime anything sent to others**, or nagging other people ("tell Bob to go to bed").
- **Spirit healer, corpse run, or release tracking** (`C_DeathInfo`). The card is about the death,
  not what comes after it.
- **Other cards:** gank diary (card 4), raid-prep (card 5), professions (card 2). No
  "`/dt graveyard` shows who ganked you".
- **Any change to card 1's files** beyond R3, including "small" fixes to Core or the harness
  (ROADMAP rule 5: stop and report instead).

## The one deliberate widening, named

**The addon now prints without being asked.** Card 1 printed one welcome line per login and
nothing else unless asked. Card 3 prints a line when a guildie dies, and a bedtime nag. R1 and
the bedtime default are what make this a ruled widening and not a drift. What still bounds it:
- notices come only from guildies running the addon, and only from those sharing;
- one line per death, never repeated, never replied to;
- `/dt rip off` silences notices for the whole account;
- the nag is off until the player sets a time, and stops at 3 lines a night;
- nothing prints at login;
- nothing goes outside the guild's addon channel.

## Stop conditions

- P1 fails (`card/dt_foundation` missing, or its suites not green) → stop.
- Any of R1-R3 still `proposed` → stop.
- Task 1 finds a *Builds on* name missing or changed on the starting branch → stop and report
  the delta. Don't adapt card 1 to fit.
- `C_GameRules.IsHardcoreActive` missing from the reference → stop. Hardcore detection needs a
  ruling before it is built.
- Crypt.lua needs a change to a card 1 file beyond R3 → stop (ROADMAP rule 5).
- The longest DEATH exceeds 250 bytes → stop. The field limits are wrong.
- A guard removal in Task 9 leaves every check green → stop.
- Any design choice needs combat data, `C_DeathRecap`, public chat, or another player's game
  state read directly → stop.
- In game (Tim): any Lua error at load, a death notice for a character outside the guild, or a
  normal-realm death sent while `share` was never set → stop, and remove `Crypt.lua` from the
  `.toc`.

## UAT: acceptance checks

Extracted verbatim to `docs/UAT_dt_crypt.md`.

**Offline (the build session runs these):**
- [ ] `[G]` G1: `DeadTired/tests/run_all.sh` exits 0 and runs seven suites (core, guild, comms,
  roster, alts, welcome, crypt).
- [ ] `[G]` G2: the report lists all nine Task 9 guard removals, each with the check that went
  red.
- [ ] `[G]` G3: `grep -rE "COMBAT_LOG|CombatLog|SendChatMessage|C_DeathRecap|UNIT_DIED|PARTY_KILL" DeadTired/`
  finds nothing.
- [ ] `[G]` G4: `git diff card/dt_foundation --stat -- DeadTired/` lists only `Crypt.lua`,
  `tests/test_crypt.lua`, `DeadTired.toc` (1 line added) and `tests/run_all.sh` (1 line changed).
- [ ] `[G]` G5: the report gives the byte length of the longest DEATH, and it is at most 250.

**In game (Tim, with one guildie, both on this branch):**
- [ ] `[G]` G6: `/reload` shows no Lua error, and the only line printed is card 1's welcome.
- [ ] `[G]` G7: on a normal realm, Tim dies with `share` never set: the guildie sees no notice.
  Tim runs `/dt rip share on` and dies again: the guildie sees exactly one line naming Tim's
  character, level and zone.
- [ ] `[G]` G8: `/dt graveyard` on both sides lists that second death (and Tim's own list has the
  first too), and ends with "Only guildies running the addon, and only deaths seen while you were
  online."
- [ ] `[G]` G9: the guildie runs `/dt rip off`; Tim dies again: no line on the guildie's side,
  but their `/dt graveyard` has it.
- [ ] `[G]` G10: Tim runs `/dt bedtime` set to 2 minutes from now: one line at that minute, no
  second line inside 30 minutes. `/dt bedtime off` and `/reload`: no line.
- [ ] `[G]` G11: *only if Forever has a hardcore realm:* a hardcore character in the guild dies
  with `share` never set: the guildie sees the "Rest in Pieces … Hardcore. Gone for good." line.
  If there is no hardcore realm, write "not walkable" in the results.
- [ ] `[H]` H1: **after a raid night, did the notices feel like part of the guild, or like noise
  you'd turn off?**

**`[H]` count: 1.** Whether a death notice is welcome or noise is the guild's call, and R1 is a
bet on it. If H1 comes back "noise", the default for R1 flips to off before merge.

## Reporting

Report: `docs/COWORK_REPORT_dt_crypt.md`. Walk-sheet: `docs/UAT_dt_crypt.md` (Tim fills in
`docs/UAT_dt_crypt_results.md` after walking it; the build session never writes that file). The
report records:
- the starting branch and commit, and Task 1's lookups (each *Builds on* name, `IsHardcoreActive`,
  `C_DeathRecap`), each found or not;
- R1-R3 as ratified, and any place the build had to read them;
- the exact player-facing lines as built, so H1 can be judged from the report;
- one encoded DEATH (hardcore) and the longest DEATH with its byte length;
- each Task 9 removal and the check that went red;
- the `git diff card/dt_foundation --stat -- DeadTired/` output;
- the output of `run_all.sh`;
- anything left undone, and every stop condition that tripped.
