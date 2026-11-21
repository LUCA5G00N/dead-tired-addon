# Cowork brief: class-coloured names in death notices (0.3.3)

You are in `LUCA5G00N/dead-tired-addon`, building in a cloud session; Tim walks the result in game.
Read first, in order:
1. `CLAUDE.md` on `main` (including *What every module must do*).
2. This brief and its walk-sheet, `docs/UAT_dt_classcolours.md`.
3. `DeadTired/Crypt.lua` (the `DEATH` handler's two notice lines; `DT.graveRows`; `build`),
   `DeadTired/Prep.lua` (`DT.rankOf`: the roster walk this round copies), `DeadTired/Keys.lua`
   (`DT.splitKey`, `DT.fullName`, `DT.realmKey`, `DT.display`), `DeadTired/UI.lua` (`DT.list`,
   `L:refresh`, the `DT.skin` callback), `DeadTired/Debug.lua`.

**Draft-status: written 21 Nov 2026 against `main` at `0cb73a7` (0.3.2, released), to be built the
same weekend.** Little should have moved, but re-reading every file and function named here against
the tree is Task 1's first act, not a formality. The drafting session ran `run_all.sh` at `0cb73a7`:
ALL GREEN, 26 suites.

## Origin
EchoOfMany, #dt-crypt-workshop, 14 Nov: "class coloured names in the message when someone dies would
be nice". Put on the public roadmap 18 Nov. Designed with Tim on 20 Nov (DEAD TIRED project note
`claude/27_design_blocks_2026-11-20.md`, block E: E1, E2 and E4 agreed 18:49) and given its own patch
release, 0.3.3 (block D2, 18:47).

**Probe, 21 Nov 13:24** (Tim, in game; screenshot `WoWScrnShot_112126_132446.jpg`, his mark "good: 5
clean lines"). `/run` over the first five roster entries printed, for each: the name **without
`-Realm`**, level, class, the upper-case class token as `GetGuildRosterInfo`'s **11th** value
(`SHAMAN`, `ROGUE`, `MAGE`, `WARLOCK`, `PALADIN`), and `RAID_CLASS_COLORS[token].colorStr`
(`ff0070dd`, `fffff468`, `ff3fc7eb`, `ff8788ee`, `fff48cba`). The colours printed as text, not
colour, because the chat box doubles a typed `|`; in the addon's own Lua the codes work. **So the
colours have not yet been seen in game: H1 and H2 are the first time.**

## Precondition
`main` at `0cb73a7` or later, carrying this brief and its walk-sheet, with
`sh DeadTired/tests/run_all.sh` printing `ALL GREEN`.

## Rulings in force (cited, not restated)
`CLAUDE.md`, all of it: in particular the guarded reads (`try`, `clean`), *never assign a Blizzard
global*, card 3 R1 (death notices print unasked; `/dt rip off` silences them), R-P5 (names without
realm, realm only on a collision). `docs/FEATURES.md`: R-F4-1 (text fit; all text through `DT.text`),
R-F5-1 to R-F5-3 (two-line rows; the graveyard stays one-line), R-F5-5 and its 21 Nov walk note
(the skin switch doesn't repaint an open window: a known issue, not this round's).

## Rulings for this round (to ratify)
- **R-F6-1 Whose name.** Only the dead guildie's name is coloured, by their class. Nothing else on
  the line changes colour. (Death notices name no killer: the client gives no combat data.)
- **R-F6-2 Where.** Two places and no others: the chat notice (both the ordinary line and the
  hardcore *Rest in Pieces* line) and the graveyard's name column.
- **R-F6-3 Where the class comes from.** The guild roster: `GetGuildRosterInfo`'s 11th value (the
  class token), matched to the death's key on the full name, and on the realm too when the roster
  name carries `-Realm` (the rule `DT.rankOf` already uses). Nothing new is sent or saved: the death
  message and `DeadTiredDB.crypt` are unchanged.
- **R-F6-4 Which colours.** The client's own `RAID_CLASS_COLORS`, as it is. On Forever that makes
  **shamans blue** (`0070dd`), not classic pink. No colour table of DT's own. **Tim to confirm.**
- **R-F6-5 When it can't.** Not on the roster (left the guild, roster not loaded yet), no token, an
  unknown token, or a colour that isn't 8 hex digits: the name is plain, exactly as in 0.3.2, and
  nothing is printed or counted as an error.
- **R-F6-6 A preview for the walk.** `/dt debug rip <name>` prints the two notice lines (ordinary and
  hardcore) as they would look if that roster member died, at a made-up level and zone. It records
  nothing, sends nothing, and needs the name to be on the roster (`not on the roster.` otherwise).
  Like every `/dt debug` verb, it is listed under debug in `/dt help`.
- **R-F6-7 Version.** 0.3.3. FEATURES.md's PATCH rule says fixes only; this adds a small feature
  (Tim, 20 Nov 18:47: "a follow up 0.3.3"). Say so in the release notes, as R-F4-9 did.

## Ratify before code
R-F6-1 to R-F6-7 are `proposed` until Tim merges this brief. **R-F6-4 needs his explicit answer**
(game colours, shamans blue). If he wants classic pink, this brief is re-cut before the build: a
colour table of DT's own is a different round's design.

## Deliverable
On a branch from `main`, DeadTired **0.3.3**: a guildie's death notice in chat shows their name in
their class colour; the graveyard's name column does the same, row by row; anyone the roster can't
place stays plain; `/dt debug rip <name>` previews both notice lines. Done when `run_all.sh` prints
`ALL GREEN` with the new checks, every guard in Task 7 has been removed once and turned a named
check red, and `dist/DeadTired-0.3.3.zip` passes `diff -r` against `DeadTired/` (tests excluded).

## Working rules
- New player-facing text: only R-F6-6's `not on the roster.` and its usage line. The notice lines'
  wording is unchanged.
- Every game read through `try`/`clean`. `RAID_CLASS_COLORS` is read, never written. No new library,
  hook or global (`test_taint.lua` stays green).
- All text through `DT.text` (`test_textfit.lua` stays green). Colour goes on the cell with
  `SetTextColor`, never as `|c` codes inside list text: list text is measured and cut, and a cut
  could split a code.
- The roster is walked at most once per graveyard build and once per notice; never once per row.

## Tasks
1. **Baseline.** `run_all.sh` at the branch point: `ALL GREEN`; record suites and checks.
2. **The class lookup (`Guild.lua`).**
   - `DT.rosterClasses()` → a table: lower-case full name → `{ token = <string>, realm = <realm key
     or nil> }`, from one guarded walk of `GetNumGuildMembers`/`GetGuildRosterInfo` (cap 1000, as
     `DT.rankOf`). Entries without a string token are left out.
   - `DT.classColour(key, roster)` → `r, g, b, hex` for the key's class, or `nil`. `roster` is
     optional (one is built when absent). Matches on the full name; when the roster entry has a
     realm, it must equal the key's realm. Reads `RAID_CLASS_COLORS[token]` guarded; returns `nil`
     unless `r`, `g`, `b` are numbers in 0–1 and `colorStr` is exactly 8 hex digits (R-F6-5).
3. **The notice (`Crypt.lua`).** In the `DEATH` handler, after `who` is built by `DT.display` (which
   escapes `|`), wrap it as `"|c" .. hex .. who .. "|r"` when `DT.classColour(from)` gives a hex; the
   rest of both lines unchanged. Own deaths still print nothing.
4. **The graveyard (`Crypt.lua`, `UI.lua`).**
   - `DT.list` column option `rgb = "<row field>"`: on every `refresh`, a cell whose row has that
     field as `{ r, g, b }` gets `SetTextColor(r, g, b)`; any other row (including a reused row frame
     and an empty one) gets the column's own colour back. It must hold after a skin change (the
     `DT.skin` callback's `refresh` re-applies it).
   - `DT.graveRows()` builds the roster once and adds `nameRGB = { r, g, b }` to each row it can
     place; the name column declares `rgb = "nameRGB"`. Search text unchanged.
5. **The preview (`Debug.lua`).** `/dt debug rip <name>`: find the name on the roster (case- and
   space-insensitive full name); print the ordinary line at level 30 in `Duskwood`, then the hardcore
   line, both built by the same code as Task 3 (factor the line-building out of the handler so the
   preview can't drift from it). Not on the roster → `not on the roster.`
6. **Tests.** In `test_crypt.lua` (or a new `test_classcolours.lua` added to `run_all.sh`), with a
   stub roster and a stub `RAID_CLASS_COLORS` (the probe's five tokens and colours): each notice
   line wraps the name in that class's code; a name not on the roster is plain; a bad token, a
   missing `colorStr`, a 7-digit `colorStr`, an r/g/b out of range are plain; a roster name with a
   different `-Realm` is plain; graveyard rows carry `nameRGB` for placed names only; the name
   cell's colour is set per row and reset on a reused row; it survives a skin change; the roster is
   walked once for a graveyard of 100 deaths; the preview prints two lines and records and sends
   nothing; `not on the roster.` for a stranger.
7. **Guard proofs** (`tools/guard_proofs.lua`; remove once, a named check red, restore): the
   colorStr check; the r/g/b range check; the realm match; the plain fallback; the reset of a reused
   row's colour; the colour after a skin change; one roster walk per graveyard build; the preview
   records nothing; the preview sends nothing. Plus every guard 0.3.2 proved, still proved.
8. **Docs.** `docs/FEATURES.md`: *Ruled 21 Nov (for `dt_classcolours`)* with R-F6-1 to R-F6-7 as
   ratified. New `docs/RELEASE_0.3.3.md` (DT's voice, short; first line `# Dead Tired 0.3.3: <title>`,
   a `Zip:` line, install steps as 0.3.2's; say shamans are blue if R-F6-4 stands, and that 0.3.3 is
   a small feature in a patch number).
9. **Version and zip.** `.toc` and `DT.VERSION` to `0.3.3`; `sh tools/package.sh` →
   `dist/DeadTired-0.3.3.zip`, `diff -r` clean. Leave the older zips. (Merging to `main` publishes the
   release: `.github/workflows/release.yml`. Don't make one by hand.)
10. **Report** `docs/COWORK_REPORT_dt_classcolours.md`.

## Out of scope
Colours anywhere else: Who, Grudges, Glacial Progress, Who has it, Prep, tooltips, the bar, the
Voice's posts. A colour table of DT's own, or a setting to turn colours off. Sending class in the
`DEATH` message or saving it in the graveyard. A killer's name. The skin-switch repaint (R-F5-5's
known issue). The self-test and pretend guildie (agreed 20 Nov as U1/U2; their own round). The
death leaderboard. Making the release by hand.

## The one deliberate widening
R-F6-6 adds a debug verb that prints death-notice lines nobody died for. Bounded by: debug only,
roster names only, prints the two lines once per use, records nothing, sends nothing.

## Stop conditions
- Baseline not `ALL GREEN`, or `lua5.1`/`luac5.1` can't be installed → stop.
- Colouring the name cell needs anything but `SetTextColor` on DT's own text (a `|c` code in list
  text, a new font object, a layout change) → stop.
- The colour doesn't survive a skin change in the harness without touching `Skins.lua` or the
  restyle path → stop (that is R-F5-5's territory).
- The roster can't be read without a per-row walk, or without a new event registration other than
  reading on demand → stop.
- Any change to a notice line's wording, or to what `DEATH` sends or the graveyard saves → stop.
- A guard removal turns nothing red: strengthen the test (test files only); if that needs addon
  code → stop.

## UAT: acceptance checks
`docs/UAT_dt_classcolours.md`, written with this brief: 5 `[G]`, 3 `[H]`. **H1 and H2 are the first
time the colours are seen in game** (the probe could only print the codes).

## Reporting
`docs/COWORK_REPORT_dt_classcolours.md`: branch, old and new heads; baseline and final counts per
suite; the five probe tokens and the colour each test expects; every guard proof (removal → the check
that went red); the line-building function the preview shares with the handler; every player-facing
line added; zip name, size, sha256; anything in this brief that turned out wrong; questions for Tim.
Never write a `_results.md` file.
