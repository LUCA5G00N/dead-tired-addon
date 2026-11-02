# dead-tired-addon: house rules for build sessions

An optional World of Warcraft addon for the guild **<DEAD TIRED>** (Horde, WoW Forever, PvP first).
Owner: Tim (in game: Stromham). Built from briefs in `docs/` by cloud sessions; walked in game by Tim.

## Start here, every session
1. Read the brief you were given (`docs/COWORK_BRIEF_<slug>.md`) and its walk-sheet
   (`docs/UAT_<slug>.md`). The brief is the authority for the round. Follow its task order,
   stop conditions and reporting exactly.
2. Read `docs/ROADMAP.md` only for context. Never build a later card inside the current one.
3. Work on the branch the brief names. Do not merge to `main`; Tim merges after his walk.

## The client, and what that rules out
- **WoW Forever** is classic content on **retail's addon API** (interface **16001** on the beta,
  build 1.60.1). `reference/SPEC_forever_namespaces.md` lists every `C_*` function the beta client
  exposed. **Ask it before you call anything:** if a function is not in that file, do not assume
  it exists. Globals (non-`C_*` functions like `GetGuildInfo`) are not in it; guard every call.
- **No combat data, ever.** The client gives addons no combat log
  (`CombatLogGetCurrentEventInfo` is absent; `C_CombatText.GetCurrentEventInfo` returns nothing).
  Nothing in this addon reads, infers or records combat events. If a feature needs them, it is
  out of scope.
- **Secret values.** Retail can hand addons "secret" values. Every read of game state goes through
  the guarded-read helpers (`try`, `clean`, `secret`): copy the pattern in
  `reference/wizardry/Forever/Core.lua`.
- **Addon messages can be restricted** (`C_ChatInfo.AreOutgoingAddonChatMessagesRestricted`).
  Anything sent while restricted is queued, not dropped and not forced.
- **Blizzard rules:** no automatic posting to public chat channels (a human click per message),
  no network access, no reading other players' bags or professions except what they choose to send.

## The guild's rules for the addon
- **Optional for members, never required.** Nothing in the addon may assume every guildie runs it.
  Shared lists show only people who run it; the addon must say so where it matters.
- **Quiet by default.** It prints a short welcome once per login (toggleable) and nothing else
  unless asked.
- **Does nothing outside the guild.** If the player is not in the guild named in `Config.lua`,
  the addon loads, says nothing, and sends nothing.
- **Opt-in for anything personal.** Bag contents, play time and the like are shared only after
  the player switches them on.
- **Tone:** dry, self-deprecating, a bit gothic. "Rest in Pieces", "Crypt Keeper", "Restless Dead".
  Keep player-facing text short.

## Ruled exceptions to the rules above
Tim has ruled these, each in a card's brief. They are deliberate, not drift: do not "fix" them,
and do not widen them. A new exception needs its own ruling in a brief.
- **Prints unasked:** guildies' death notices (card 3, `dt_crypt` R1), the bedtime nag once the
  player sets a time (card 3), one line on a hardcore character's first login pointing at
  `/dt rip share on` (card 3, rulings round), event reminders once switched on (card 6 R4).
- **Reads another player:** your target's name, realm, class and level, only when you press
  `/dt gank` (card 4, `dt_pvp` R1).
- **Posts to a public channel:** `/dt recruit`, one line per typed command or click, guild
  officers only, to General (card 5, `dt_prep` R1-R2 as amended by the rulings round).
- **Shares without a separate opt-in:** a gank log, when you make it (card 4 R2).

## Code rules
- Lua 5.1 (what WoW runs). One SavedVariables table: `DeadTiredDB` (account-wide). Character keys
  are `Realm-Name`.
- Each feature is a module registered through `ns.DT.module{...}` (the pattern in
  `reference/wizardry/Forever/Core.lua`): its own frame, its own error key, handler failures
  recorded and re-raised.
- Slash commands go through one router: `/dt <verb>`. `/deadtired` is an alias.
- `reference/` is **read-only reference**. Never load it from the `.toc`, never edit it.
  Copy patterns from it into `DeadTired/` and say in the report what you copied.

## Tests
- Every module has an offline test in `DeadTired/tests/test_<module>.lua`, run with
  `lua5.1 DeadTired/tests/test_<module>.lua` from the repo root. Tests stub the WoW API in the
  style of `reference/wizardry/tests/test_forever_core.lua`: plain Lua, a `check(name, cond)`
  counter, exit non-zero on any failure, no test framework.
- `DeadTired/tests/run_all.sh` runs every suite and exits non-zero if any fail.
- If `lua5.1` is not installed, install it (`apt-get install -y lua5.1`). If that is not possible,
  **stop and report**: do not substitute another Lua version silently.
- **Guards are proved, not assumed:** for every guard the brief lists, remove it once, confirm a
  check goes red, and put it back. The report lists each removal and which check failed.

- **Stop conditions mean stop, with one exception:** if a guard removal fails to turn a check red
  because the round's own test is weak, you may strengthen that test (test files only, never
  addon code), prove the guard again, and carry on. The report shows the test diff and says why.
  Every other stop condition halts the round and is reported.

## Reporting
Write `docs/COWORK_REPORT_<slug>.md` as the brief asks. Never write `docs/UAT_<slug>_results.md`:
walking the sheet is Tim's job, in game.
