# Cowork brief: DEAD TIRED PvP (the gank diary and its shared board)

**Where you are:** repo `dead-tired-addon`, a cloud session. Work on branch **`card/dt_pvp`**,
created from **`card/dt_foundation`** (ROADMAP rule 1), never from `main`, `card/dt_crypt` or
another card. No game client is available; everything is proved offline with stubbed tests, then
Tim walks it in game. If the harness assigns you a different branch name, create that branch from
`card/dt_foundation` and say so in the report.

**Amended 2026-11-02 (fix round 1, F7 and F6b in `docs/COWORK_BRIEF_dt_fixes1.md`, audit AUD-04
and AUD-07):** the double-press window lives in memory, and a stored `t` is the epoch; a received
GANK is kept at most once per sender and enemy per 300 s. Marked *(amended, fix round 1)*.

**Amended 2026-11-09 (fix round 3, AUD-06 in `docs/COWORK_BRIEF_dt_fixes3.md`):** `/dt gank`
builds `who` with card 1's `DT.keyOf(name, realm)`, so the realm is spelt without spaces or
hyphens; a received `who` is stored in that spelling; stored logs' `who` and `by` are rewritten
once per account (`DeadTiredDB.gank.keysV = 2`). Changed lines are marked *(amended, fix round 3)*.

**Read before Task 1, in order:**
1. `CLAUDE.md` (house rules; they bind throughout this round).
2. This brief, then `docs/UAT_dt_pvp.md`.
3. `docs/COWORK_REPORT_dt_foundation.md` (what card 1 actually landed, and how its tests work).
4. `DeadTired/Core.lua`, `Comms.lua`, `Roster.lua`, `tests/harness.lua`, `tests/test_roster.lua`.
5. `reference/SPEC_forever_namespaces.md`: search it, don't read it top to bottom.

Do **not** read or copy from `card/dt_crypt`. The two cards are siblings, and each merges into
`main` on its own.

**Draft-status:** **ratified by Tim 2026-11-02 (R1-R3 as proposed).** Written 2026-11-02, after card 1 was reported (card 1
head `61fe2d3` on `claude/loving-meitner-yzdxtn`) and **before card 1 has been walked in game**.
Every "already exists" claim is about that commit, and Task 1 re-verifies each against the
branch you start from. Card 1 may get fixes on launch night (4 Nov). The live Forever client may
differ from the beta build the API reference describes. Two things in particular are unknown:
whether retail's secret-value rules hide an **enemy player's** name, class or level from addons,
and when.

## Origin

Tim's idea list (`L5GN/_desk/dead-tired_addon_ideas.md`, 2026-11-02), carded as card 4 in
`docs/ROADMAP.md`: **gank diary: target an Alliance player, log name/class/level/zone, shared
board.** The roadmap's design note: *the gank diary is a button press on a target, not a kill
detector. It's the no-combat-log route to names for the PvP tally and bounty board later.* The
guild is PvP first; this is the card the guild is most likely to use.

## Precondition

- P1: `card/dt_foundation` exists on origin and holds card 1 (`DeadTired/` 0.1.0, the six suites
  green). Check it with `git ls-remote origin card/dt_foundation` and
  `sh DeadTired/tests/run_all.sh` → exit 0.
- P2: Tim has ratified R1-R3 below (each marked `ratified` in this file, or ruled otherwise).

## Depends on: rulings

This repo has no numbered rulings. The binding rules are `CLAUDE.md` and `docs/ROADMAP.md`'s
"Branching and testing rule" (rules 1, 2 and 5 bind here). Carried over from card 1's brief:
- **WoWWizardry 0012 clause 4** (as applied in card 1): every guard listed in Task 9 is removed
  once to prove a check goes red, then restored.
- **WoWWizardry 0003 / 0017**: characters are keyed `Realm-Name`. An enemy's key is built the same
  way.

## Ratify before code

The round may not be built while any of these is `proposed`. All three are ratified.

- **R1 (ratified 2026-11-02, as proposed): your target's unit frame is not "another player's game state".** CLAUDE.md
  forbids "reading other players' bags or professions except what they choose to send". Card 3
  stops on any design that reads another player's game state directly. This card reads an enemy's
  **name, realm, class and level from your target**, the same things the target frame shows.
  Proposal: allowed, limited to those four plus your own zone, and only at the moment you press
  the button. Never their gear, auras, health, guild or anything from inspect.
- **R2 (ratified 2026-11-02, as proposed): a log is shared when you make it.** Pressing `/dt gank` records the log and
  sends it to the guild in the same act, with no separate opt-in. The data is about an enemy, not
  you, and the press itself is the choice. Receivers record logs silently: **nothing prints on
  receipt**, so card 1's "quiet by default" holds unchanged.
- **R3 (ratified 2026-11-02, as proposed): what this card may change in card 1's files.** Two lines, nothing else:
  `Gank.lua` appended to `DeadTired.toc` after `Welcome.lua`, and `gank:Gank` appended to the
  module list in `tests/run_all.sh`. `DT.VERSION` and `## Version:` stay `0.1.0`. Card 3 appends
  to the same two lines, so the merge conflicts there. That is expected: at merge, keep both
  (Crypt first, then Gank). Anything more in a card 1 file is ROADMAP rule 5, and it stops the
  round.

## Builds on (card 1, commit `61fe2d3`; Task 1 re-verifies each)

`DT.module{}`, `DT.verb(prefix, fn, usage)`, `DT.send(kind, fields)`, `DT.on(kind, fn)`,
`DT.isMember()`, `DT.guildKey()`, `DT.charKey()`, `DT.display(key)`, `DT.nameOf(key)`,
`DT.safe(s, max)`, `DT.stamp()`, `DT.now()`, `DT.try`, `DT.clean`, `DT.out`, `DT.db()`,
`DT.errors()`, and Core's router (`DT.raw`, whole-word verbs, longest verb wins). Test side:
`tests/harness.lua` (`H.world()`, `world:client{...}` with `files`/`db`, `client.env` for extra
stubs, `:slash()`, `:said()`, `:fire()`, `world:advance()`).

## Deliverable

One new file, **`DeadTired/Gank.lua`** (a module registered through `DT.module{}`), and
**`DeadTired/tests/test_gank.lua`**, plus R3's two lines:

- **`/dt gank`** logs your current target, if it is an enemy-faction player: their name, realm,
  class and level, your zone, and the time. You get one confirmation line, and the log goes to
  the guild as `GANK`. Put it in a macro on your bar and it is a button press.
- **`/dt ganks`** prints the board: the most-logged enemies, from your logs and every guildie's
  log your client has received.
- **`/dt ganks <name>`** prints one enemy's entries.

**Testable end:** `DeadTired/tests/run_all.sh` exits 0 with seven suites; and in game, Tim
targets an Alliance player and presses a `/dt gank` macro. A guildie running the branch then
sees that player at the top of `/dt ganks` with the right class, level and zone, and nothing was
printed on the guildie's side until they asked.

### Gank.lua: specification

**Store.** `DeadTiredDB.gank` is created by Gank.lua itself (not by `DT.db()` in Core; R3):
`gank = { badGank = 0, [<guildKey>] = { logs = { ... } } }`. A log is
`{ who = <enemy Realm-Name>, cls = <classFile>, lvl = <number>, zone = <string>,
by = <logger Realm-Name>, at = <DT.stamp()>, t = <time() (epoch) for the local log, nil when
received> }` *(amended, fix round 1: was `DT.now()`, the machine's uptime; a stored `t` below
1,000,000,000 is of unknown age, and nothing reads it)*. Newest is appended last, capped at **500**, oldest dropped first.

**`/dt gank`** (members only; the router already refuses non-members):
1. The target must exist and be a player: `try(UnitExists, "target") == true` and
   `try(UnitIsPlayer, "target") == true`. Otherwise print *"Target a player first. Preferably
   one who deserves it."* and stop.
2. It must be the **other faction**: `clean(try(UnitFactionGroup, "target"))` and
   `clean(try(UnitFactionGroup, "player"))` are both non-empty strings, and they differ.
   Otherwise print *"That's one of ours. Put the pen down."* and stop.
3. Read `name, realm = clean(try(UnitName, "target"))` (realm nil or empty means your own realm;
   `who = DT.keyOf(name, realm)`, the one key spelling *(amended, fix round 3)*), `cls = select(2, try(UnitClass, "target"))` (the
   upper-case class file, e.g. `ROGUE`), `lvl = clean(try(UnitLevel, "target"))`. **If the name is
   nil, secret or empty,** print *"The game won't say who that is right now. Try again out of
   combat."* and stop: nothing is recorded or sent. If `cls` is unreadable, store `"UNKNOWN"`; if
   `lvl` is unreadable, or is `-1` (a skull), store `-1`. Validation is under *Inbound*.
4. Zone: `clean(try(GetRealZoneText))`, a non-empty string truncated to 48 bytes, otherwise
   `"somewhere"`.
5. **Double press:** if you pressed on the same `who` under **300 seconds** ago **this session**
   (a session table `lastPress[who] = DT.now()`, never stored), print *"Already noted. Grudges
   don't need two copies."* and stop. *(amended, fix round 1)*
6. Record it, `DT.send("GANK", { who = who, cls = cls, lvl = lvl, zone = zone })`, and print
   *"Noted: <Name> (<Class> <lvl>), <zone>. The crypt remembers."* Use the class in title case
   from the class file, `??` for level -1, and names through `DT.display`.

**Inbound `GANK`** (via `DT.on`, so card 1's member gate, own-message ignore and malformed
handling apply). Validate:
- `who` is `Realm-Name` (1-64 bytes, a `-` with a non-empty name after the last one);
- `cls` is 1-12 upper-case letters;
- `lvl` is `-1` or a decimal integer 1-100;
- `zone` is 1-48 bytes.

An invalid GANK is ignored and counted in `DeadTiredDB.gank.badGank`. A valid one is recorded
with `by = <sender>`, at most once per sender and `who` per 300 s (in memory); another inside the
window is counted in `DeadTiredDB.gank.dropped` *(amended, fix round 1)*. **Nothing is printed, nothing is replied, nothing is re-sent.**

**The board, `/dt ganks`.** Group every log by `who`. For each enemy: the count, the number of
distinct loggers (`by`), and the newest log's class, level, zone and date. Sort by count
(highest first), then newest, then name. Print at most 10 lines:
`<n>. <Name> (<Class> <lvl>) x<count> by <loggers> guildie(s), last <zone> <YYYY-MM-DD>`.
If there are no logs: *"No grudges yet. Go and make some."* Then always: *"Only logs from guildies
running the addon, seen while you were online."*

**`/dt ganks <name>`**: match case-insensitively on the enemy's name, realm optional (`Name`,
`Name-Realm` or `Realm-Name`, as card 1's `/dt alts` matches). Print that enemy's newest 10 logs,
`<YYYY-MM-DD> <zone> (<Class> <lvl>), by <logger>`, then the same closing line. If there is no
match: *"Never heard of them. Yet."* If the name matches more than one realm, ask for the realm,
as `/dt alts` does.

**Wire.** `GANK` is a card 1 message: `1^GANK^cls~ROGUE^lvl~60^who~Nethergarde-Backstabz^zone~Stranglethorn Vale`.
The longest (a 64-byte `who`, 12-letter class, `lvl` 100, a 48-byte zone of `^`, which escapes to
3 bytes each) must be at most 250 bytes (see *Stop conditions*).
Worked at drafting: 6 + 17 + 8 + 69 + 150 = **exactly 250**. That's legal, but there is no slack:
don't widen any field limit in this card.

## Working rules

- **No combat data, ever.** No `COMBAT_LOG` event, no `CombatLog*`, no `C_DeathRecap`, no
  `UNIT_DIED`/`PARTY_KILL`, no event that fires on a kill. A log exists only because a player
  typed or clicked `/dt gank`. **No automatic logging of any kind**, not even "log whoever you
  were targeting when you died".
- **Only the four target fields** from R1: name with realm, class, level, and faction (checked,
  never stored). No `NotifyInspect`, `GetInventoryItem*`, `UnitAura`/`C_UnitAuras`,
  `UnitHealth`, `GetGuildInfo("target")`, `UnitGUID` stored, or `UnitRace`.
- **Nothing public.** No `SendChatMessage`. GANK goes out only through `DT.send`.
- **Every API call guarded.** `UnitExists`, `UnitIsPlayer`, `UnitFactionGroup`, `UnitName`,
  `UnitClass`, `UnitLevel` and `GetRealZoneText` go through `DT.try` / `DT.clean`. These globals
  aren't in the API reference (it lists `C_*` only), so the tests prove the absent and secret
  cases for each.
- **Card 1 is read-only** except for R3's two lines. If Gank.lua seems to need a change in Core,
  Comms, Roster or the harness, **stop** (ROADMAP rule 5). Target stubs go in `test_gank.lua`,
  set on `client.env`.
- **Inbound data is data:** stored, and printed through `DT.safe` / `DT.display`, never used to
  call a game function or target anything.
- **Quiet:** Gank prints nothing at login, and nothing on receipt (R2).

## Tasks

1. **Re-verify.** Check P1. Check that every name under *Builds on* exists on your starting
   branch, including `/dt alts`' matching in `Alts.lua`, whose rules `/dt ganks <name>` copies.
   Record each in the report.
2. Append R3's two lines. Create `DeadTired/Gank.lua` with the store and the verbs `gank` and
   `ganks` (usage strings, no bar characters). Add `tests/test_gank.lua` with the target stubs
   (`UnitExists`, `UnitIsPlayer`, `UnitFactionGroup`, `UnitName`, `UnitClass`, `UnitLevel`,
   `GetRealZoneText`, all settable per client), covering store creation. `run_all.sh` green.
3. **Logging:** `/dt gank`, steps 1-6, and its tests. Cover: no target; an NPC; a same-faction
   player; a player with no faction readable; an enemy on your realm and on another realm; the
   name secret, nil or empty (nothing recorded, nothing sent); class unreadable; level -1 and
   unreadable; zone unreadable; the double press at 299 s and a second log at 301 s; the
   confirmation line exactly as specified; a non-member (router line, nothing recorded or sent).
   Green.
4. **Inbound:** the `DT.on("GANK")` handler, two clients. Cover: a valid log is stored with `by`;
   each invalid field is counted in `badGank`; nothing prints on the receiver; nothing is
   replied; a non-member sender's log never arrives (card 1's gate). Green.
5. **The board:** `/dt ganks` and its tests. Cover: the empty text; grouping and count; distinct
   loggers; the sort order including both tie-breaks; at most 10 lines; the closing line every
   time; the cap of 500. Green.
6. **One enemy:** `/dt ganks <name>` and its tests: by name, `Name-Realm`, `Realm-Name`, any
   case; unknown names; two realms asking for the realm; newest first, at most 10. Green.
7. **Byte budget:** a test encoding the longest GANK and asserting it is at most 250 bytes.
8. **Full-addon check:** `test_gank.lua` loads all eight files (card 1's seven plus Gank.lua)
   on two members and a non-member. A log on one appears on the other's board, the non-member
   receives and prints nothing, and a login prints nothing from Gank.
9. **Guard proofs.** Remove once, confirm a check goes red, restore: the player check (NPC
   refused); the faction check; the unreadable-name refusal; the 300-second double-press window;
   the inbound field validation; the silent receipt (put in a print, see a check go red); the
   board's 10-line limit; the 500 cap.
10. Write the report and push the branch.

## Explicitly out of scope

- **Kill detection or any automatic log.** Not from combat events (there are none), not from
  `PLAYER_DEAD`, not from target-changed events. The press is the whole design.
- **"Who killed me"**: no link from card 3's death notices to the board, and no reading of
  `C_DeathRecap`.
- **The PvP tally, leaderboard and bounty board** (ROADMAP "long poles"). This card collects the
  names. Scoring, rewards and bounties come later, briefed against what this card lands.
- **Syncing the board** (catching up on logs made while you were offline) or sending the board to
  anyone. Each client keeps what it saw.
- **Undo or delete across the guild.** A wrong log stays on everyone's board. Local delete, a
  remote retraction message, or officer moderation is a later card if the board fills with
  mistakes.
- **A key binding (`Bindings.xml`), a button, a panel, a minimap icon, a sound, or a target-frame
  menu entry.** The macro is the button in 0.1.0.
- **Notes or free text on a log** ("camped me at the flight path"). Free text from other players
  is a moderation problem this card doesn't take on.
- **Posting to guild chat or any public channel**, even with a click.
- **Race, guild, gear, PvP rank or GUID** of the target (R1).
- **Other cards:** death notices (card 3), raid-prep (card 5), professions (card 2).
- **Any change to card 1's files** beyond R3 (ROADMAP rule 5: stop and report instead).

## The one deliberate widening, named

**The addon now reads another player.** Cards 1 and 3 read only the player's own character and
what guildies chose to send. This card reads an enemy's name, realm, class and level from your
target. R1 rules it allowed. What still bounds it:
- only at the moment you press `/dt gank`, never on a timer or an event;
- only an other-faction player;
- only the four unit-frame fields, never inspect, gear, auras, health or guild;
- nothing recorded when the game hides the name;
- what is shared goes only to the guild's addon channel;
- receivers stay silent until they ask.

## Stop conditions

- P1 fails (`card/dt_foundation` missing, or its suites not green) → stop.
- Any of R1-R3 still `proposed` → stop.
- Task 1 finds a *Builds on* name missing or changed on the starting branch → stop and report
  the delta. Don't adapt card 1 to fit.
- Gank.lua needs a change to a card 1 file beyond R3 → stop (ROADMAP rule 5).
- The longest GANK exceeds 250 bytes → stop. The field limits are wrong.
- A guard removal in Task 9 leaves every check green → stop.
- Any design choice needs combat data, automatic logging, inspect, or public chat → stop.
- In game (Tim): any Lua error at load; a log made of a Horde player or an NPC; a line printed on
  the guildie's side on receipt; or `/dt gank` recording a name in combat that the game showed as
  hidden → stop, and remove `Gank.lua` from the `.toc`.

## UAT: acceptance checks

Extracted verbatim to `docs/UAT_dt_pvp.md`.

**Offline (the build session runs these):**
- [ ] `[G]` G1: `DeadTired/tests/run_all.sh` exits 0 and runs seven suites (core, guild, comms,
  roster, alts, welcome, gank).
- [ ] `[G]` G2: the report lists all eight Task 9 guard removals, each with the check that went
  red.
- [ ] `[G]` G3: `grep -rE "COMBAT_LOG|CombatLog|SendChatMessage|C_DeathRecap|UNIT_DIED|PARTY_KILL|NotifyInspect|UnitAura|C_UnitAuras|UnitRace|UnitHealth" DeadTired/`
  finds nothing.
- [ ] `[G]` G4: `git diff card/dt_foundation --stat -- DeadTired/` lists only `Gank.lua`,
  `tests/test_gank.lua`, `DeadTired.toc` (1 line added) and `tests/run_all.sh` (1 line changed).
- [ ] `[G]` G5: the report gives the byte length of the longest GANK, and it is at most 250.

**In game (Tim, with one guildie, both on this branch):**
- [ ] `[G]` G6: `/reload` shows no Lua error, and the only line printed is card 1's welcome.
- [ ] `[G]` G7: Tim makes a macro `/dt gank` and presses it on: no target; an NPC; a Horde player.
  Each gets its refusal line and nothing is recorded (`/dt ganks` still says "No grudges yet").
- [ ] `[G]` G8: Tim presses it on an Alliance player: one "Noted: …" line with the right name,
  class, level and zone. A second press within 5 minutes: "Already noted."
- [ ] `[G]` G9: on the guildie's side nothing was printed. Their `/dt ganks` lists that player
  first, with the class, level, zone and "by 1 guildie", and ends with "Only logs from guildies
  running the addon, seen while you were online."
- [ ] `[G]` G10: the guildie runs `/dt ganks <that name>` and gets the entry, logged by Tim's
  character.
- [ ] `[G]` G11: Tim presses the macro on an Alliance player **in combat**. Either a "Noted"
  line with the right name, or the "won't say who that is" line with nothing recorded. Write down
  which: it answers the secret-value question for the next card.
- [ ] `[H]` H1: **mid-fight, did you actually press it, or did you forget it existed until
  afterwards?**

**`[H]` count: 1.** Whether a button press fits how the guild really fights is a judgement only a
fight answers. If H1 is "forgot it existed", the board stays thin whatever the code does. Note it
before card 6 or the bounty board is briefed.

## Reporting

Report: `docs/COWORK_REPORT_dt_pvp.md`. Walk-sheet: `docs/UAT_dt_pvp.md` (Tim fills in
`docs/UAT_dt_pvp_results.md` after walking it; the build session never writes that file). The
report records:
- the starting branch and commit, and Task 1's lookups, each found or not;
- R1-R3 as ratified, and any place the build had to read them;
- the exact player-facing lines as built, so H1 and the tone can be judged from the report;
- one encoded GANK and the longest GANK with its byte length;
- each Task 9 removal and the check that went red;
- the `git diff card/dt_foundation --stat -- DeadTired/` output;
- the output of `run_all.sh`;
- anything left undone, and every stop condition that tripped.
