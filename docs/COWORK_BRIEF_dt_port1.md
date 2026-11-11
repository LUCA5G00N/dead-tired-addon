# Cowork brief: DEAD TIRED Port 1 (cards 1 and 3, recruit; release 0.2.0)

Read first, in order:
1. `CLAUDE.md` on `main`.
2. This brief and its walk-sheet, `docs/UAT_dt_port1.md`.
3. `docs/FEATURES.md`: *General requirements*, *Ruled 11 Nov (for Port 1)*, *Versions and
   releases*, and the *Port rule* on `UnitFullName`.
4. `docs/UAT_dt_framework_results.md` (*Defects and requests*: every item is in this round).
5. The framework on `main` (`DeadTired/`): how modules, settings, verbs, viewports, lists, the bar
   (`DT.object`) and comms are used. **Build on it; don't change its contracts** except where a
   task below says so.
6. For the features being ported (logic and rulings only, read-only): on `release/0.1.0-rc3`,
   `DeadTired/Alts.lua`, `Crypt.lua`, `Recruit.lua`, `RecruitLines.lua`, `Prep.lua`, `PrepList.lua`
   and their tests; the ratified card briefs `docs/COWORK_BRIEF_dt_crypt.md` (on `card/dt_crypt`),
   `docs/COWORK_BRIEF_dt_prep.md` (on `card/dt_prep`), `docs/COWORK_BRIEF_dt_rulings.md` and
   `docs/COWORK_BRIEF_dt_fixes3.md` (on `main`).

**Draft-status: ratified by Tim 2026-11-11** (Port split, recruit bar button, raid prep as the
officers' list, nudge replies, bar list, names without realm; chosen in the 11 Nov session).
`main` head when written: `ce4b767`.

## Origin
The framework (0.2.0-fw1) walked 8 of 8 on 10-11 Nov with four players on three realms. Port 1
moves the first features onto it, fixes what the framework walk found, and ships **0.2.0** to the
guild (GitHub release + Discord). Port 2 (cards 4, 6, 7) follows.

## Rulings in force for this round
Carried unchanged from rc3's ratified briefs (do not reinterpret; `CLAUDE.md` *Ruled exceptions*
lists them): death notices print unasked (R1, `/dt rip off`); your own death is shared only after
`/dt rip share on`, hardcore included, with the one first-login line for a hardcore character;
bedtime nag once set (up to three nudges); recruit: officers only, General, one post per typed
command **or click**, 15 min per account, never from a timer; the recruit nudge once after a post.
New, 11 Nov:
- **R-P1 Recruit button:** a `Recruit` object on the bar (via `DT.object`): text shows the next
  line number and the cooldown (`Recruit` / `Recruit 4:12`), left-click posts (exactly as
  `/dt recruit`: same officer, cooldown and General checks), tooltip shows the next line. Shown only
  to officers. The click is the hardware event; nothing else posts.
- **R-P2 Nudge replies:** `/dt recruit nudge off` → `Nudge off. The crypt keeps its own counsel.`;
  `/dt recruit nudge on` → `Nudge on. The crypt will knock.`
- **R-P3 Raid prep, the officers' raid-night list:** officers set the list (`/dt prep add <item>
  <count>`, `remove`, `clear`, and a settings card list); it is shared to the guild by addon message
  (versioned, last writer wins by time, officers only accepted); members `/dt prep check` their own
  bags against it; the opt-in ready roll call stays as rc3 ruled (verdict only, never item names or
  counts). If R-P3 doesn't fit this round, build `/dt prep check` against rc3's built-in list, carry
  the list editing to Port 2, and say so in the report: not a stop.
- **R-P4 Bar list:** DT's own objects show from the start; every other addon's object is listed in
  the bar's settings card **unticked**; tick to add; rows **ordered by drag** (a grip on each row);
  the bar follows the order; saved. Typed: `/dt bar add <name>`, `/dt bar remove <name>`,
  `/dt bar move <name> <n>`, `/dt bar list`. A newly seen addon appears unticked at the bottom.
- **R-P5 Names without realm:** every list and line shows the full name only (`Vespera Grimm`);
  the realm is in the tooltip. If two shown entries share a full name, both get `(Realm)`. Keys keep
  the realm.
- **R-P6 Who shows you:** your own entry is listed first, marked `(you)`; still never listed as
  someone else.

## Deliverable
On a branch from `main` (the session's own branch is fine: `CLAUDE.md`), DeadTired **0.2.0** with:

| Module | What |
|---|---|
| **Alts** | `/dt main`, `/dt main clear`, `/dt alts [name]` as rc3, on full-name keys; the main travels in HELLO |
| **Crypt** (Rest in Pieces) | Death notices, graveyard viewport (searchable list), bedtime nag, `/dt rip`, `/dt rip share on|off`, `/dt rip on|off`, `/dt bedtime HH:MM|off`; hardcore line as ruled; battleground rule kept |
| **Recruit** | `/dt recruit`, `/dt recruit next`, the bar button (R-P1), the nudge with replies (R-P2), lines in `RecruitLines.lua` |
| **Prep** | R-P3 (or the fallback) |
| **Who** | R-P6; row heights fit wrapped names |
| **Legacy migration** | From `DeadTiredDB.legacy` (rc3), once (`DeadTiredDB.migrated.port1 = true`): roster/alts mains, crypt graveyard and settings (`share`, `rip`, `bedtime`, `hcTold`), recruit state (`recruitNext`, `recruitNudge`, last-post time), prep state. **Keys:** rc3 wrote short-name and full-name keys for the same character, and filed connected-realm guildies under the local realm. Rewrite each to `RealmKey-Full Name`: a short-name key merges into the full-name key of the same realm when exactly one full-name key starts with that short name plus a space; otherwise keep it and count it in `migrated.unmatched`. A connected-realm guildie's realm is corrected only when a current HELLO supplies it (never guessed). Newest `seen` wins on merge. `legacy` itself is left untouched |
| **Framework fixes** | Settings rows sized to their text (no overlap, nothing cut); the first setting clear of the search box; other addons' colour codes on the bar shown, not escaped (strip only unsafe escapes: textures and hyperlinks are fine to keep, anything else that isn't a colour code is escaped); empty-state line in Who: `Just you so far. The rest are still in their coffins.`; R-P4; R-P5 |
| **DT info on the bar** | A `Session` data object: this session's time, deaths and (if card 3 records it) graveyard count; tooltip lists them. Off the bar until ticked (R-P4) |
| **Version** | `0.2.0` in the `.toc` and `DT.VERSION`; `dist/DeadTired-0.2.0.zip` |

## Tasks
1. **Baseline:** `main`'s suites green; record counts.
2. **Framework fixes** (settings rows, search box, colour codes, Who rows and empty state, R-P5,
   R-P6) with tests on the models (row height from text, name display with/without collisions,
   colour-code passthrough, own entry first).
3. **Bar list (R-P4)** with tests: unticked by default, tick adds, drag order (model: move up/down
   and to position n), typed verbs, new addon at the bottom, order saved.
4. **Alts**, **Crypt**, **Recruit (+R-P1, R-P2)**, **Prep (R-P3 or fallback)**: port each from rc3's
   logic onto `DT.module`, every setting declared as a card with a typed path (or `noVerb`), with
   their rc3 checks carried over and re-pointed to full-name keys.
5. **Session object** with tests.
6. **Legacy migration** with tests: a fixture built from Tim's real legacy shape (short and full keys
   for the same character, a connected-realm guildie filed under Realm 2), merges, unmatched count,
   runs once, `legacy` untouched.
7. **Guard proofs** (remove once, a check goes red, restore): the recruit officer check; the
   cooldown; the click-only post (no post from a timer or event); General only; death share opt-in;
   the battleground rule; the hardcore once-only line; prep officers-only acceptance; prep verdict
   carries no item names or counts; migration run-once; the short→full merge rule's exactly-one
   condition; R-P5 collision rule; R-P6 own entry never doubled; bar unticked default; the taint scan.
8. **Package** `dist/DeadTired-0.2.0.zip`; `diff -r`; `run_all.sh` green.
9. **Release notes** `docs/RELEASE_0.2.0.md`: what's in it for a guildie, in DT's voice, short; how
   to install; what's coming in Port 2. Draft only: Tim publishes the GitHub release.
10. **Report** `docs/COWORK_REPORT_dt_port1.md`.

## Working rules
- Player-facing lines: rc3's ratified lines for ported features, unchanged; the new lines in this
  brief; nothing else new (list any you need in the report as questions).
- Never read a realm from `UnitFullName` (it returns the surname on Forever).
- `reference/` and rc3 are read-only.

## Out of scope
Cards 4, 6, 7; card 2; the waypointer and everything after Port 2 in FEATURES.md; publishing the
release; CurseForge/Wago; hiding other addons' minimap buttons.

## Stop conditions
- A ported feature's ratified behaviour can't be kept on the framework without changing a
  framework contract → stop and report the conflict.
- The migration would delete or overwrite data it can't merge by the rule above → stop.
- Any change would post to a public channel without a click or typed command → stop.
- A guard removal turns nothing red: strengthen the test (test files only); if that needs addon code → stop.

## Reporting
Old/new heads; per module: what was ported from rc3 (and what changed), checks and counts; guard
proofs; migration behaviour on the fixture; every player-facing line added or carried; zip name,
size, file list. Never write a `_results.md` file.
