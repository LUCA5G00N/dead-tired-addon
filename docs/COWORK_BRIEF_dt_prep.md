# Cowork brief: DEAD TIRED prep (raid-prep bag check, recruitment rotator)

**Where you are:** repo `dead-tired-addon`, a cloud session. Work on branch **`card/dt_prep`**,
created from **`card/dt_foundation`** (ROADMAP rule 1), never from `main` or another card
(`card/dt_crypt` and `card/dt_pvp` are siblings: don't read or copy from them). No game client is
available; everything is proved offline with stubbed tests, then Tim walks it in game. If the
harness assigns you a different branch name, create that branch from `card/dt_foundation` and say
so in the report.

**Read before Task 1, in order:**
1. `CLAUDE.md` (house rules; they bind throughout this round).
2. This brief, then `docs/UAT_dt_prep.md`.
3. `docs/COWORK_REPORT_dt_foundation.md` (what card 1 landed, and how its tests work).
4. `DeadTired/Core.lua`, `Comms.lua`, `Roster.lua`, `tests/harness.lua`, `tests/test_roster.lua`.
5. `reference/SPEC_forever_namespaces.md`: search it, don't read it top to bottom.

**Draft-status:** **proposed, not ratified.** Written 2026-11-02, after cards 1, 3 and 4 were built
and **before any of them has been walked in game**. Card 1 is at `61fe2d3` on
`card/dt_foundation`. Every "already exists" claim is about that commit, and Task 1 re-verifies
each against the branch you start from. Card 1 may get fixes on launch night (4 Nov). Three things
can't be known until the live client is up:
- the item IDs in the starter prep list (written from memory: see R3 and G7);
- which public channels Forever has;
- whether `C_ChatInfo.SendChatMessage` to a channel needs a hardware event, as on retail.

## Origin

Tim's idea list (`L5GN/_desk/dead-tired_addon_ideas.md`, 2026-11-02), carded as card 5 in
`docs/ROADMAP.md`: **raid-prep bag check** and **recruitment rotator**. The roadmap's design note:
*the recruitment rotator posts one line per click (Blizzard rule). The five lines live in
`L5GN/_desk/dead-tired_recruitment_2026-11-01.md`.* That file is not in this repo.

## Precondition

- P1: `card/dt_foundation` exists on origin and holds card 1 (six suites green). Check it with
  `git ls-remote origin card/dt_foundation` and `sh DeadTired/tests/run_all.sh` → exit 0.
- P2: Tim has ratified R1-R5 below (each marked `ratified`, or ruled otherwise).
- P3: **Tim's five recruitment lines are in this repo**, in `docs/RECRUIT_lines.md`, one per
  line, numbered 1-5, exactly as they are to be posted. Check: the file exists and has exactly
  five numbered lines. The build copies them verbatim. It does not write, edit or "improve" them.

## Depends on: rulings

This repo has no numbered rulings. The binding rules are `CLAUDE.md` (in particular *"no
automatic posting to public chat channels (a human click per message)"* and *"no reading other
players' bags … except what they choose to send"*) and `docs/ROADMAP.md`'s "Branching and testing
rule" (rules 1, 2 and 5). Carried over from card 1's brief:
- **WoWWizardry 0012 clause 4** (as applied in card 1): every guard in Task 10 is removed once
  to prove a check goes red, then restored.
- **WoWWizardry 0003 / 0017**: characters are keyed `Realm-Name`.

## Ratify before code

The round may not be built while any of these is `proposed`.

- **R1 (proposed): the addon may post to one public channel.** This is a widening: every card so
  far has banned `SendChatMessage`, and the earlier walk-sheets grep for it. Proposal: exactly
  one call site, in `Recruit.lua`, reached only from the `/dt recruit` slash handler, synchronously.
  It is never called from a timer, a queue, an event, a received message, or a retry. One typed
  command or macro click, one line. **Any member** may post (not officers only); the cooldown in
  R2 is the brake.
- **R2 (proposed): channel and cooldown.** The channel is set in `Recruit.lua`'s data block,
  `RECRUIT_CHANNEL = "LookingForGroup"` (Tim may name another before ratifying). The cooldown is
  **15 minutes per account** (`DeadTiredDB.prep.recruitAt`, an epoch time, so it survives a
  relog and covers alts). Tim may change either number before ratifying.
- **R3 (proposed): the prep list ships as a starter, IDs unverified.** `PrepList.lua` holds the
  list below, written from memory. It is data, not logic. Tim edits it freely, and G7 checks every
  ID in game before anyone trusts the check.
- **R4 (proposed): sharing prep is opt-in, and shares a verdict, not bags.** With
  `/dt prep share on`, a member answers a guildie's prep check with **ready yes/no and how many
  list entries are short**. Never item names, never counts, never anything else from the bags.
  Off by default.
- **R5 (proposed): what this card may change in card 1's files.** Four lines appended to
  `DeadTired.toc` after `Welcome.lua`, in order: `PrepList.lua`, `Prep.lua`, `RecruitLines.lua`,
  `Recruit.lua`. Plus one line in `tests/run_all.sh`: `prep:Prep recruit:Recruit` appended to the
  module list. Nothing else. `DT.VERSION` stays `0.1.0`. The channel lives in
  `RecruitLines.lua`, not `Config.lua`. Merging with cards 3 and 4 will conflict on these lines;
  at merge keep all of them, in card order (Crypt, Gank, then this card's four).

## Builds on (card 1, commit `61fe2d3`; Task 1 re-verifies each)

`DT.module{}`, `DT.verb(prefix, fn, usage)`, `DT.send(kind, fields)`, `DT.on(kind, fn)`,
`DT.isMember()`, `DT.guildKey()`, `DT.charKey()`, `DT.display(key)`, `DT.safe(s, max)`,
`DT.stamp()`, `DT.now()`, `DT.after(d, fn)`, `DT.try`, `DT.clean`, `DT.out`, `DT.db()`,
`DT.errors()`, and Core's router (whole-word verbs, longest wins, non-members refused). Test side:
`tests/harness.lua` (`H.world()`, `world:client{...}` with `files`/`db`/`random`, `client.env`
for extra stubs, `:slash()`, `:said()`, `:fire()`, `world:advance()`).

API lookups this card relies on, found in `reference/SPEC_forever_namespaces.md` at drafting
(Task 1 re-checks): `C_Item.GetItemCount`, `C_Item.GetItemNameByID`,
`C_Item.RequestLoadItemDataByID`, `C_ChatInfo.SendChatMessage`,
`C_ChatInfo.InChatMessagingLockdown`. Globals (not in the reference, guarded): `GetChannelName`,
`UnitClass`, `time`.

## Deliverable

Four new files, `DeadTired/PrepList.lua`, `Prep.lua`, `RecruitLines.lua` and `Recruit.lua` (two
modules, `Prep` and `Recruit`, registered through `DT.module{}`), plus `tests/test_prep.lua`,
`tests/test_recruit.lua` and R5's two edits:

- **`/dt prep`** checks your own bags against the prep list for your class and prints one line:
  ready, or what's short.
- **`/dt prep list`** prints each list entry for your class with the name the client knows its ID
  by, so a wrong ID shows.
- **`/dt prep check`** asks the guild's sharing members whether they're ready and prints the
  answers 10 seconds later. **`/dt prep share on/off`** sets whether you answer.
- **`/dt recruit`** posts the next of Tim's five lines to the recruitment channel: one line per
  command, 15 minutes apart, rotating 1-5.

**Testable end:** `DeadTired/tests/run_all.sh` exits 0 with eight suites; and in game, Tim's
`/dt recruit` macro posts line 1 to the channel, refuses inside 15 minutes, and posts line 2
after. A guildie with sharing on answers Tim's `/dt prep check`, and one with sharing off does
not.

### PrepList.lua (data, R3)

```lua
ns.PrepList = {
  -- { id = <itemID>, name = "<as Tim calls it>", need = <count>, class = "<CLASSFILE>" or nil }
  { id = 13446, name = "Major Healing Potion", need = 5 },
  { id = 17029, name = "Sacred Candle",        need = 20, class = "PRIEST" },
  { id = 17020, name = "Arcane Powder",        need = 20, class = "MAGE" },
  { id = 17033, name = "Symbol of Divinity",   need = 5,  class = "PALADIN" },
  { id = 17026, name = "Wild Thornroot",       need = 20, class = "DRUID" },
  { id = 17030, name = "Ankh",                 need = 5,  class = "SHAMAN" },
  { id = 6265,  name = "Soul Shard",           need = 10, class = "WARLOCK" },
  { id = 5140,  name = "Flash Powder",         need = 10, class = "ROGUE" },
}
```

An entry with no `class` applies to everyone. The IDs are unverified (R3).

### Prep.lua: specification

**Store.** `DeadTiredDB.prep` is created by Prep.lua itself:
`prep = { share = false, badPrep = 0 }` (and `recruitAt`, `recruitNext`, owned by Recruit.lua).

**`/dt prep`** (members only; the router refuses others):
- My class is `clean(select(2, try(UnitClass, "player")))`. The entries that apply are those with
  no `class`, or `class` equal to mine. If the class is unreadable, only class-less entries apply.
- For each entry: `have = clean(try(C_Item.GetItemCount, id, false))`, bags only, never the bank.
  Not a number means 0.
- All met: *"Ready. Bags packed, coffin optional."*
- Otherwise: *"Short: <name> <have>/<need>, <name> <have>/<need>."*, in list order, names from
  the list (not the client).
- Nothing is sent.

**`/dt prep list`:** one line per applicable entry,
`<id> <list name> x<need> — client: <name>`, where `<name>` is
`clean(try(C_Item.GetItemNameByID, id))`, or `not loaded yet` when that isn't a non-empty string
(then call `try(C_Item.RequestLoadItemDataByID, id)` so a second `/dt prep list` can show it).
If the client's name differs from the list name (case-insensitive), the line ends `  <- check
this ID`.

**`/dt prep share on`, `off`:** set `share`. **`/dt prep share`** alone: prints the setting.

**`/dt prep check`:**
- At most one check per **60 seconds** per client. A second inside the window prints *"Patience.
  The last roll call is still out."* and sends nothing.
- Sends `PREPQ {q=<n>}`, where `n` is a per-session counter. Prints *"Roll call sent. Answers in
  10 seconds."*
- After 10 seconds, prints *"Ready (<k>): <names>. Short (<m>): <name> (<s> short), …"* (either
  part reads `none` when empty), then always: *"Only guildies running the addon with sharing on
  answer."* Answers that arrive later are ignored.
- The asker isn't in their own summary (card 1 ignores your own messages); `/dt prep` is how you
  check yourself.

**Answering (receiving `PREPQ`):**
- Only when `share` is true; with it off, nothing at all.
- At most **one answer per asker and question id**.
- After a random 1-5 second delay, run the same check as `/dt prep` (no print) and send
  `PREP {q=<n>, to=<asker key>, ok="1"|"0", short=<count of short entries>}`.

**Receiving `PREP`:** only the client whose `charKey()` equals `to` and whose open question is
`q` keeps it, once per sender. Everyone else ignores it. Validate: `q` a decimal integer; `to` is
`Realm-Name` (1-64 bytes); `ok` `"0"`/`"1"`; `short` a decimal integer 0-50, and 0 exactly when
`ok == "1"`. Invalid counts in `prep.badPrep`. Nothing prints on receipt; the 10-second summary
is the only output.

### RecruitLines.lua (data, R2 and P3)

```lua
ns.Recruit = {
  RECRUIT_CHANNEL = "LookingForGroup",
  COOLDOWN = 900,   -- seconds, per account
  LINES = {
    -- Tim's five lines from docs/RECRUIT_lines.md, verbatim, in order.
  },
}
```

### Recruit.lua: specification

**`/dt recruit`** (members only; the router refuses others). In this order, each failure printing
its line and sending nothing:
1. **Lines present:** exactly 5 non-empty strings, each at most 255 bytes, containing no `|` and
   no byte below 32 (checked once at load). Otherwise: *"No recruitment lines loaded. Tell an
   officer."*
2. **Cooldown:** `now = clean(try(time))`, a number. If `prep.recruitAt` is set and
   `now - recruitAt < COOLDOWN`: *"Too soon. Next post in <m> min. Even necromancers pace
   themselves."* (`m` rounded up). If `time` is unreadable: *"Can't read the clock. Not posting."*
3. **Lockdown:** if `try(C_ChatInfo.InChatMessagingLockdown) == true`: *"Chat's locked right now
   (an encounter?). Try after."*
4. **Channel:** `id = clean(try(GetChannelName, RECRUIT_CHANNEL))`. If not a number above 0:
   *"You're not in <channel>. /join <channel> first."*
5. **Post:** `ok = pcall(C_ChatInfo.SendChatMessage, LINES[i], "CHANNEL", nil, id)` with
   `i = prep.recruitNext or 1`. On success: `recruitAt = now`, `recruitNext = i % 5 + 1`, and
   print *"Posted line <i> of 5 to <channel>."* On failure: *"The channel didn't take it. Nothing
   posted."* The cooldown and the rotation don't move.

**`/dt recruit next`:** prints which line goes next and the time left on the cooldown. Nothing is
posted. The rotation can't be skipped from the command line.

## Working rules

- **One public call site.** `SendChatMessage` appears in exactly one line of `DeadTired/`, in
  `Recruit.lua`, inside the function the `recruit` verb calls. Not wrapped in `DT.after`, not
  queued, not retried. A test proves no world tick ever produces a post.
- **Nothing combat.** No `COMBAT_LOG`, `CombatLog*`, `C_DeathRecap`, `UNIT_DIED`, `PARTY_KILL`.
- **Own bags only, through `C_Item.GetItemCount`.** No `C_Container` scans, no bank, no other
  player's bags. What leaves the client is R4's verdict, and only with sharing on.
- **Every API call guarded**, with absence handled as specified.
- **Card 1 is read-only** except for R5. If either module needs a change to Core, Comms, Roster,
  Config or the harness, **stop** (ROADMAP rule 5). Stubs go in the new test files, on
  `client.env`.
- **Inbound data is data**, printed through `DT.safe` / `DT.display`.
- **Quiet:** neither module prints at login or on receipt. Prep's only unasked output is the
  summary of a check the player started.

## Tasks

1. **Re-verify.** Check P1 and P3. Check every *Builds on* name and API lookup. Record each,
   found or not, in the report.
2. Apply R5. Create `PrepList.lua` (as above) and `RecruitLines.lua`, with P3's lines copied
   verbatim. Create empty `Prep.lua` and `Recruit.lua` modules with their stores and verbs (usage
   strings, no bars). Add `tests/test_prep.lua` and `tests/test_recruit.lua`, covering store
   creation. A test in `test_recruit.lua` asserts the five lines are byte-identical to
   `docs/RECRUIT_lines.md` (stripping the numbering). `run_all.sh` green.
3. **`/dt prep` and `/dt prep list`** and their tests. Cover: the class filter; class unreadable;
   counts from the stub; bags only (`includeBank` passed as false); ready and short lines exactly
   as specified; `GetItemCount` absent or erroring means 0; a client name that matches; one that
   differs; one not loaded (and that it requests the load). Green.
4. **Sharing and answering**, two clients plus a third with sharing off. Cover: share off by
   default; `/dt prep check` sends `PREPQ`; sharing members answer once, after 1-5 s, with `ok`
   and `short` only; non-sharing members send nothing; a duplicate `PREPQ` gets no second answer;
   the 60 s check window. Green.
5. **The summary:** names in order of arrival; the `none` forms; answers after 10 s are ignored;
   a `PREP` addressed to someone else is ignored; each invalid field counts in `badPrep`; the
   closing line every time. Green.
6. **`/dt recruit`** and its tests, with `C_ChatInfo.SendChatMessage`, `InChatMessagingLockdown`,
   `GetChannelName` and `time` stubbed per client. Cover each refusal in order (lines invalid:
   empty, 4 lines, a `|`, over 255 bytes; cooldown with minutes rounded up; clock unreadable;
   lockdown; not in the channel); a post with its exact arguments; the rotation 1 → 5 → 1; the
   cooldown shared by two characters on one account (one `DeadTiredDB`); a send failure moving
   nothing; `/dt recruit next`. Green.
7. **No post without a command:** load all files on a member, set every condition for a post,
   advance the world 24 hours through logins, `PLAYER_ENTERING_WORLD`, guild updates and received
   messages. Assert `SendChatMessage` was never called. Green.
8. **Byte budget:** the longest `PREP` (a 64-byte `to`, `q` 99999, `short` 50) is at most 250 bytes.
9. **Full-addon check:** all eleven files (card 1's seven plus four) on two members and a
   non-member. A login prints only card 1's welcome; a prep check works end to end; the
   non-member sends and prints nothing.
10. **Guard proofs.** Remove once, confirm a check goes red, restore: the `share` gate on
    answering; one answer per asker and question; the 60 s check window; late answers ignored;
    `PREP` addressed to someone else ignored; `PREP` validation; the class filter; the lines
    check; the recruit cooldown; the lockdown refusal; the channel refusal; the rotation not
    moving on a failed send.
11. Write the report and push the branch.

## Explicitly out of scope

- **Automatic or timed posting of any kind**: no "post every 15 minutes", no "post when I enter a
  city", no queued post that fires later. R1's line is the whole design.
- **Writing, editing or rewording the recruitment lines.** They're Tim's (P3). A line that fails
  the lines check is reported, not fixed.
- **More channels, per-zone channels, `/dt recruit <n>` to pick a line, or whispering
  applicants.**
- **Officer-only gating or a rank check** (R1: any member). `C_GuildInfo.IsGuildOfficer` is not
  called this round.
- **Sharing bag contents**: item names, counts, the list itself, or anything beyond R4's verdict.
  No "who has the most potions".
- **Bank, mail, or alts' bags.** `GetItemCount`'s bank flag stays false.
- **Buffs, enchants, gear, resistances or attendance** as part of "prep": bags only.
- **A raid-lead UI, ready-check integration (`READY_CHECK`), or posting the summary to raid or
  guild chat.**
- **Other cards:** death notices (3), gank diary (4), professions (2).
- **Any change to card 1's files** beyond R5 (ROADMAP rule 5: stop and report instead).

## The one deliberate widening, named

**The addon speaks in public.** Until now it only talked on the guild's addon channel, which
players never see. `/dt recruit` puts a line of text in a public channel, under the player's name.
R1 and R2 rule it. What still bounds it:
- one call site, reached only by a typed command or macro click, one line per press;
- never from a timer, an event, a queue or a retry, proved by Task 7;
- 15 minutes between posts per account, alts included;
- only Tim's five lines, verbatim, checked for chat escapes and length;
- refused in chat lockdown and when not in the channel;
- members only.

(The prep check's sharing is also new, but it is the opt-in verdict CLAUDE.md already allows:
"what they choose to send".)

## Stop conditions

- P1 or P3 fails (no `card/dt_foundation`, its suites red, or `docs/RECRUIT_lines.md` missing or
  not exactly five lines) → stop.
- Any of R1-R5 still `proposed` → stop.
- Task 1 finds a *Builds on* name or an API lookup missing → stop and report. Don't adapt card 1
  or substitute another function.
- Either module needs a change to a card 1 file beyond R5 → stop (ROADMAP rule 5).
- One of Tim's lines fails the lines check (over 255 bytes, a `|`, a control byte) → stop and
  report which. Don't edit it.
- `SendChatMessage` would need to be called from anywhere but the `recruit` verb's handler → stop.
- The longest `PREP` exceeds 250 bytes → stop.
- A guard removal in Task 10 leaves every check green → stop.
- Any design choice needs combat data, another player's bags, the bank, or automatic posting →
  stop.
- In game (Tim): any Lua error at load; a post you didn't press for; two posts from one press; a
  post inside the cooldown; a member with sharing off answering a check → stop, and remove
  `Recruit.lua` (or `Prep.lua`) from the `.toc`.

## UAT: acceptance checks

Extracted verbatim to `docs/UAT_dt_prep.md`.

**Offline (the build session runs these):**
- [ ] `[G]` G1: `DeadTired/tests/run_all.sh` exits 0 and runs eight suites (core, guild, comms,
  roster, alts, welcome, prep, recruit).
- [ ] `[G]` G2: the report lists all twelve Task 10 guard removals, each with the check that went
  red.
- [ ] `[G]` G3: `grep -rn "SendChatMessage" DeadTired/ --include=*.lua | grep -v "/tests/"` finds
  exactly one line, in `Recruit.lua`; and
  `grep -rE "COMBAT_LOG|CombatLog|C_DeathRecap|UNIT_DIED|PARTY_KILL|C_Container|READY_CHECK" DeadTired/`
  finds nothing.
- [ ] `[G]` G4: `git diff card/dt_foundation --stat -- DeadTired/` lists only the four new files,
  the two new suites, `DeadTired.toc` (4 lines added) and `tests/run_all.sh` (1 line changed).
- [ ] `[G]` G5: the five lines in `RecruitLines.lua` are byte-identical to `docs/RECRUIT_lines.md`
  (Task 2's test), and the report gives each line's length in bytes.

**In game (Tim, with one or two guildies, all on this branch):**
- [ ] `[G]` G6: `/reload` shows no Lua error, and the only line printed is card 1's welcome.
- [ ] `[G]` G7: `/dt prep list` on a priest, a mage and one other class: every line's client name
  matches its list name, or is marked `<- check this ID`. Write down every marked ID.
- [ ] `[G]` G8: with known bags, `/dt prep` says "Ready." or names exactly the short items with
  the right counts.
- [ ] `[G]` G9: guildie A runs `/dt prep share on`, guildie B leaves it off. Tim's
  `/dt prep check`: after 10 s, A is listed (ready or short) and B is not anywhere.
- [ ] `[G]` G10: Tim joins the channel and presses `/dt recruit`: line 1 appears in the channel
  once. A second press within 15 minutes is refused with the minutes left. After 15 minutes, a
  press posts line 2. An alt on the same account inside the 15 minutes is refused too.
- [ ] `[G]` G11: Tim leaves the channel and presses: refused with "/join … first", nothing posted.
- [ ] `[H]` H1: **reading the posts in the channel as a stranger would: do they read as a guild
  you'd want to join, or as an addon spamming?**

**`[H]` count: 1.** How public text lands on strangers is the only judgement here; everything
else is a count or a match. If H1 is "spam", the fix is the lines or the cooldown, both Tim's.

## Reporting

Report: `docs/COWORK_REPORT_dt_prep.md`. Walk-sheet: `docs/UAT_dt_prep.md` (Tim fills in
`docs/UAT_dt_prep_results.md` after walking it; the build session never writes that file). The
report records:
- the starting branch and commit, and Task 1's lookups, each found or not;
- R1-R5 as ratified, and any place the build had to read them;
- the exact player-facing lines as built, and each recruitment line's byte length;
- one encoded `PREPQ` and `PREP`, and the longest `PREP` with its byte length;
- each Task 10 removal and the check that went red;
- the `git diff card/dt_foundation --stat -- DeadTired/` output;
- the output of `run_all.sh`;
- **a merge note:** cards 1, 3 and 4's G3 greps forbid `SendChatMessage` across all of
  `DeadTired/`, so once this card is merged to `main` those checks need this card's one line
  excepted. Say so, and don't edit the other cards' walk-sheets;
- anything left undone, and every stop condition that tripped.
