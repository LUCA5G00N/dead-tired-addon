# Cowork brief: DEAD TIRED framework (the rebuild's first round)

Read first, in order:
1. `CLAUDE.md` on `main` (house rules; the *Libraries* and *Character keys* lines are new with this
   brief).
2. This brief and its walk-sheet, `docs/UAT_dt_framework.md`.
3. `docs/FEATURES.md`: *General requirements*, *The framework*, *The shell* and *The hybrid*.
4. `docs/UAT_dt_fixes3_results.md` (the three defects this round designs out) and
   `docs/PROBE_launch_results.md` (*Update*).
5. For patterns only, read-only: `release/0.1.0-rc3`'s `DeadTired/Core.lua`, `Comms.lua`,
   `Roster.lua` and their tests; `reference/wizardry/Forever/Core.lua`;
   `reference/SPEC_forever_namespaces.md` (search it).

**Draft-status: ratified by Tim 2026-11-10** (rebuild rulings 1-4, chosen in the 10 Nov session).
**Amended 2026-11-11** after the first run stopped at Task 2 on LibDataBroker's licence (report on
`claude/hopeful-thompson-4rpsrp`): libraries, the bar, branches. **Resume from Task 2**: Task 1 is done
(taint cause confirmed; carry its finding into the new report by quoting the first run's).
`main` head when written: `a250072` (plus PR #6, docs only).

## Origin

rc3 proved DeadTired can talk on Forever (two-player walk, 10 Nov) but carries three defects (two-part
names, connected-realm keys, a taint that blocks Blizzard's own slash commands). Tim ruled a rebuild:
*"a proper rebuild approach with the framework idea in mind for robustness"*. This round builds the
framework everything else sits on, with one small module to walk it end to end. The cards are ported
onto it in the next round.

## The rulings (ratified 2026-11-10)

- **Scope:** a **fresh `DeadTired`** on a new branch. rc3's logic and tests may be copied where sound
  (say what in the report); its structure is not kept. Cards 1, 3, 4, 6, 7 and recruit are **not**
  ported in this round.
- **Libraries (amended 2026-11-11):** bundle, inside `DeadTired/Libs/`, LibStub, CallbackHandler-1.0,
  LibSharedMedia-3.0 (its file's LGPL 2.1 header is the explicit licence: ship it unmodified with the
  LGPL text), AceComm-3.0 + ChatThrottleLib, LibSerialize, LibDeflate. **LibDataBroker-1.1: borrowed,
  never bundled** (no licence in its source): DT uses it only if another addon loaded it
  (`LibStub("LibDataBroker-1.1", true)`). **LibDBIcon: not used** (no minimap button). DT keeps its own
  module core. No AceDB, no AceAddon/AceConfig. Sources and versions: as the first run's report table.
- **Launcher bar:** **on by default**, with one intro line on the first login only:
  `DeadTired's bar has risen. /dt bar off to bury it.` (proposed wording: Tim rules on it at H2).
  Position remembered. If an LDB display addon is loaded (Titan Panel, ChocolateBar, Bazooka, or any
  that registers as one), DT's data objects go there and **DT's bar stays off** unless `/dt bar on`.
- **Skins:** two ship: **Forever** (the game's stone and metal) and **Dead Tired** (gothic: deep
  green-black, bone, a sickly green accent). The session builds a first Dead Tired palette; Tim
  curates it from screenshot marks. `/dt skin forever|deadtired`.

## Requirements carried from the rc3 walk (design them out)

1. **One character key from the full name.** Forever names have a surname (`UnitName` "Stromham",
   `GetUnitName("player", true)` "Stromham Hamson"; Liliac: "Lilbit" / "Lilbit High"). Keys are
   `RealmKey-Full Name` (full name with its space; realm normalised as AUD-06). Built in one place.
2. **Connected realms are real.** Tim is on `CAMWOW EU4 Realm 2 PvP`, Liliac on `... Realm 4 PvP`.
   Tim's rc3 `/dt who` showed Lilbit **without** a realm, so the sender string from another realm
   isn't the shape rc3 expected. Therefore: **every DT message carries the sender's own key in its
   payload**; the receiver accepts it when the payload key's name part matches the sender string's
   name part (case-insensitive, with or without any `-Realm` suffix), and records a mismatch instead
   of guessing. The raw sender string of every distinct sender is recorded for diagnostics
   (`/dt debug senders`, capped at 50).
3. **No taint on Blizzard's paths.** Probable cause in rc3: `Core.lua:305`
   `SlashCmdList = SlashCmdList or {}`, which reassigns Blizzard's global from addon code and so taints
   every slash command Blizzard runs afterwards (`/run`'s allow-scripts prompt, `/invite`). The new
   router only sets `SLASH_DEADTIRED1`, `SLASH_DEADTIRED2` and `SlashCmdList["DEADTIRED"]`. **No
   assignment to any Blizzard global, no hook (`hooksecurefunc` included) on chat, slash, StaticPopup
   or edit-box functions, no change to a frame DT didn't create** (Get*/Is* reads only). A static test
   enforces it (Task 9).
4. **Probe the name functions** for player, target and guild senders: `/dt debug names` prints
   `UnitName`, `UnitFullName`, `GetUnitName(unit, true)`, `GetRealmName`, `GetNormalizedRealmName`
   for player and target.

## Deliverable

Branch **`card/dt_framework`** from `main`, carrying a fresh `DeadTired/` addon, version
**0.2.0-fw1**, interface 16001, with:

| Piece | What |
|---|---|
| **Module core** | `DT.module{ id, title, settings, verbs, events, ldb }`: own frame, own error key (failures counted and re-raised, as rc3), own on/off switch (saved), registered verbs, declared settings. Disabled modules register no events |
| **Guild gate + welcome** | House rules: outside the guild named in `Config.lua`, load, say nothing, send nothing. One welcome line per login (toggleable), as rc3 |
| **Router** | `/dt <verb>`, `/deadtired` alias; `/dt help` lists verbs from the registry; `/dt set <module> <key> <value>` and `/dt get <module> [key]` for every setting |
| **Keys** | `DT.keyOf(fullName, realm)`, `DT.myKey()`, `DT.realmKey(realm)`, `DT.display(key)` (name only on your own realm, else `Name (Realm)`). Requirement 1 |
| **Comms** | AceComm + ChatThrottleLib for chunking and pacing; DT's gate on top: R-1 (hold only while `InChatMessagingLockdown()`), the held line (`The dead are gagged for this fight. Your message goes when it's over.`, once per hold, for typed commands only), AUD-10 (refused sends retried 3 times, then dropped and counted), protocol version in every message (`v = 2`; unknown versions ignored and counted), payload key (requirement 2), LibSerialize + LibDeflate for tables |
| **Settings as cards** | Each module declares settings `{ key, label, desc, type, default, verb }`; a settings viewport builds itself. Every setting has a `/dt set` path; one declared without a typed path must carry `noVerb = "<reason>"` (the *General requirements* rule) |
| **Viewport frame** | One standard frame (title, close, body, optional search box), placed and kept (position saved, survives `/reload`), not closed by Escape, insecure (shown and used in combat). Copy the marks bar's visibility rules (Wizardry), not its code if it isn't in `reference/` |
| **Skins** | One style table (colours, fonts, textures, spacing) every frame draws through; LibSharedMedia for fonts/textures; Forever + Dead Tired |
| **List widget** | Scrollable rows with a search box, filtering as you type (case-insensitive) |
| **Launcher bar** | One row; drag to move; left-click opens, right-click its menu. DT's own buttons are DT objects with an LDB-shaped interface (`text`, `icon`, `OnClick`, `OnTooltipShow`). **When LibDataBroker-1.1 is loaded by another addon**, DT registers its objects there too and the bar also hosts every other addon's LDB launcher/data source. **When it isn't**, the bar shows DT's own buttons only, drawn natively. The stand-back rule above. **It never hides or moves another addon's minimap button** (that would write their settings; a later ruling) |
| **Toasts** | One toast style; nothing toasts unless a module's setting is on (`/dt toast test` shows one) |
| **Addon detection** | `DT.addonLoaded(name)` via `C_AddOns.IsAddOnLoaded` (guarded); used for the bar's stand-back |
| **Entry points** | The game's Settings → AddOns page (a stub that opens DT's settings viewport) and the addon compartment line in the `.toc` |
| **Walk module: Who** | The one module this round: who in the guild runs DT. HELLO on login and on request (`/dt who` asks once, rate-limited); a viewport list (searchable) of keys shown with `DT.display`, version and "this session / seen before"; your own key never listed as someone else; an LDB data object `DT: <n> online`. This is how the framework is walked with a second player |
| **Saved data** | `DeadTiredDB` with `schema = 3`. If an rc3 `DeadTiredDB` is present, move its tables untouched under `DeadTiredDB.legacy` (for the port round) and say so once in chat: `Your old crypt records are kept for the move.` (proposed: Tim rules at H1) |

## Tasks

1. **Baseline.** Branch from `main`; no addon code there. Install `lua5.1` if missing (see
   `CLAUDE.md`). Read rc3's `Core.lua`/`Comms.lua` and confirm or correct the taint cause above;
   record what you found.
2. **Vendor the libraries** into `DeadTired/Libs/<Lib>/`, each with its upstream licence file and a
   line in `DeadTired/Libs/README.md` (name, version or commit, source URL, licence). Sources: the
   Ace3 repository (`github.com/WoWUIDev/Ace3`) for LibStub, CallbackHandler, AceComm and
   ChatThrottleLib; `github.com/rossnichols/LibSerialize`; `github.com/SafeteeWoW/LibDeflate`;
   `repos.wowace.com/wow/libsharedmedia-3-0/trunk` for LibSharedMedia (the versions the first run
   recorded, or newer with the change noted). **Do not vendor LibDataBroker-1.1 or LibDBIcon-1.0.**
   Unmodified files only. Load order in the `.toc`. Use the `dead-tired-addon` environment (it can
   reach WowAce).
3. **Module core, router, gate, welcome** with tests (registry, verbs, `help` built from the registry,
   disabled module registers nothing, guild gate silent outside the guild, error counting).
4. **Keys** with tests: two-part names, own realm vs connected realm, display, case and spacing.
5. **Comms** with tests: R-1, held line, AUD-10 (stub `SendAddonMessage`/ChatThrottleLib to return
   chosen results), protocol version, payload key accepted / mismatch recorded, sender with and
   without `-Realm`, `/dt debug senders`. If the vendored ChatThrottleLib already retries non-success
   results, say so and test DT's behaviour on top; if meeting AUD-10 would need changing
   ChatThrottleLib → stop.
6. **Settings cards + `/dt set|get`** with tests: every declared setting reachable by verb or carrying
   `noVerb`; values typed and validated; saved.
7. **Viewport, skins, list widget, toasts** (build under stubs; test the models: style resolution per
   skin, list filtering, toast gating by setting, viewport position save/restore).
8. **Launcher bar + addon detection** with tests: **with** a stub LibDataBroker loaded by "another
   addon", DT's objects registered there and a stub third-party object shown; **without** it, DT's own
   buttons shown and nothing errors; no copy of LibDataBroker anywhere in `DeadTired/`; stand-back when
   a known display addon is loaded; intro line once only; `/dt bar on|off`.
9. **Taint guard (static test):** scan every `DeadTired/*.lua` (not `Libs/`) for an assignment to a
   global that isn't DT's own (`DeadTired*`, `DT`, `SLASH_DEADTIRED*`, `SlashCmdList["DEADTIRED"]`),
   for `hooksecurefunc`, and for any `Set*`, `Show`, `Hide`, `SetScript`, `SetParent` call on a
   global frame DT didn't create. Fails on any hit.
10. **Who module** with tests (HELLO both ways, self never listed as other, rate limit, LDB count).
11. **Guard proofs** (remove once, a check goes red, restore): the guild gate; the lockdown hold; the
    AUD-10 success test; the 3-refusal limit; the payload-key name match; the self-exclusion in Who;
    the settings verb-or-`noVerb` rule; the bar's stand-back; the borrow-only LibDataBroker check (with no LDB loaded, DT must not create it); the intro's once-only; the taint scan
    (insert `SlashCmdList = SlashCmdList or {}` into a DT file: the scan goes red).
12. **Package:** `tools/package.sh` (copy rc3's) builds `dist/DeadTired-0.2.0-fw1.zip`; `diff -r`
    against the branch; `run_all.sh` green. Push.
13. **Report** `docs/COWORK_REPORT_dt_framework.md` on the branch.

## Working rules
- Lua 5.1; one SavedVariables table; every game read guarded (`try`, `clean`, `secret`).
- Player-facing lines: only those given in this brief and `/dt help`'s verb list.
- `reference/` stays read-only. rc3 is read for patterns, never edited.

## Out of scope
Porting cards 1, 3, 4, 6, 7, recruit or card 2; the waypoint service; every module in FEATURES.md
beyond Who; hiding or moving other addons' minimap buttons; merging to `main`; publishing.

## Stop conditions
- A bundled library can't be obtained from a source you can name, or its licence doesn't allow bundling → stop.
- Building the bar without bundling LibDataBroker turns out to need LibDataBroker's code copied into DT → stop.
- Meeting AUD-10 or R-1 needs a change inside a vendored library → stop.
- The taint scan can't be written without false positives in DT's own code → stop and report the cases.
- A function the brief relies on isn't in `reference/SPEC_forever_namespaces.md` and has no guarded
  fallback → stop.
- A guard removal turns nothing red: strengthen the test (test files only); if that needs addon code → stop.

## Reporting
Libraries (version, source, licence, LibDataBroker's quoted); the rc3 taint finding; each piece with
its checks and counts; guard proofs (removal → the check that went red); zip name, size, file list;
every player-facing line added. Never write a `_results.md` file.
