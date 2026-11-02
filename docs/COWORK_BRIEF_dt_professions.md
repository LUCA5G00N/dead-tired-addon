# Cowork brief: DEAD TIRED professions (the profession directory: "who can make X?")

**Where you are:** repo `dead-tired-addon`, a cloud session. Work on branch
**`card/dt_professions`**, created from **`card/dt_foundation`** (ROADMAP rule 1), never from
`main` or another card (`card/dt_crypt`, `card/dt_pvp`, `card/dt_prep` and `card/dt_stretch` are
siblings: don't read or copy from them). No game client is available; everything is proved offline
with stubbed tests, then Tim walks it in game. If the harness assigns you a different branch name,
create that branch from `card/dt_foundation` and say so in the report.

**Read before Task 1, in order:**
1. `CLAUDE.md` (house rules; they bind throughout this round).
2. This brief, then `docs/UAT_dt_professions.md`, then **`docs/PROBE_guild_recipes_results.md`**
   (Tim's probe result, P3).
3. `docs/COWORK_REPORT_dt_foundation.md` (what card 1 landed, and how its tests work).
4. `DeadTired/Core.lua`, `Comms.lua`, `Roster.lua`, `Alts.lua`, `tests/harness.lua`.
5. `reference/wizardry/Forever/ProfessionRecorder.lua` and
   `reference/wizardry/tests/test_forever_professions.lua`: how this client's profession and
   recipe reads actually behave, with live captures. The patterns to copy are named in
   *Working rules*.
6. `reference/SPEC_forever_namespaces.md`: search it, don't read it top to bottom.

**Draft-status:** **proposed, not ratifiable yet.** Written 2026-11-02, before launch, after cards
1, 3, 4, 5 and 6 were built and **before any of them has been walked in game**. ROADMAP rule 4
says card 2 *"is not built until the question is answered"*, and the plan says it is *"briefed
against the probe result"*. This draft is written ahead of the probe so that launch night only
needs the probe and a ruling, not a fresh brief. **It may not be ratified until the probe below
has been walked and its result written down (P3), and R1 ruled against that result.** Card 1 is
at `61fe2d3` on `card/dt_foundation`; Task 1 re-verifies every "already exists" claim against the
branch you start from.

## Origin

Tim's idea list (`L5GN/_desk/dead-tired_addon_ideas.md`, 2026-11-02), carded as card 2 in
`docs/ROADMAP.md`: **profession directory ("who can make X?")**. The roadmap's design note:
*check the native guild recipe lookup first. The beta client exposes
`C_GuildInfo.QueryGuildMembersForRecipe` and `C_GuildInfo.QueryGuildMemberRecipes`. If they
answer on the live client, the directory may only need to present what the game already knows,
plus cover people who don't run the addon. A one-login probe by Tim settles it before card 2's
brief is written.* Card 6's brief moved the crafting request board out until this card exists.

## Launch-night probe (Tim, one login, before ratifying)

Run on the live client, in the guild, on a character with a profession. Paste each command into
chat as written. Write what each one prints (or "nothing", or the Lua error) in
`docs/PROBE_guild_recipes_results.md`, numbered as below.

1. `/dump C_GuildInfo.QueryGuildMembersForRecipe, C_GuildInfo.QueryGuildMemberRecipes`
   (function or nil, for each)
2. `/dump GetGuildRecipeInfoPostQuery, GetGuildRecipeMember`
   (the two globals that read the answer on retail; function or nil, for each)
3. Open your profession window, then:
   `/run local T=C_TradeSkillUI local id=T.GetAllRecipeIDs()[1] print(id, T.GetTradeSkillLineForRecipe(id))`
   (a recipe ID, then its profession's child line ID, name and parent line ID)
4. With the window still open, using the two numbers from step 3 (the recipe ID and the
   **parent** line ID):
   `/run DTP=CreateFrame("Frame") DTP:RegisterEvent("GUILD_RECIPE_KNOWN_BY_MEMBERS") DTP:SetScript("OnEvent",function() local s,r,n=GetGuildRecipeInfoPostQuery() print("event",s,r,n) for i=1,(n or 0) do print(i,GetGuildRecipeMember(i)) end end) C_GuildInfo.QueryGuildMembersForRecipe(PARENT, RECIPE)`
   (does "event" print, how many members, and are they the right people, including guildies
   who don't run the addon?)
5. Close the window and run step 4's last call again
   (`C_GuildInfo.QueryGuildMembersForRecipe(PARENT, RECIPE)`): does it still answer with no
   window open?

**What the result means:**
- **"Native works"** = steps 1, 2 and 4 all answer, and step 4 names the right guildies.
- **Anything else is "native doesn't work"**: a nil in step 1 or 2, no "event" in step 4, or
  wrong or empty names.

R1 is ruled on that.

## Precondition

- P1: `card/dt_foundation` exists on origin and holds card 1 (six suites green). Check it with
  `git ls-remote origin card/dt_foundation` and `sh DeadTired/tests/run_all.sh` → exit 0.
- P2: Tim has ratified R1-R5 below (each marked `ratified`, or ruled otherwise).
- P3: `docs/PROBE_guild_recipes_results.md` exists, answers steps 1-5, and ends with one line:
  `Native: works` or `Native: doesn't work`.

## Depends on: rulings

This repo has no numbered rulings. The binding rules are `CLAUDE.md` (in particular *"no reading
other players' bags or professions except what they choose to send"* and *"Opt-in for anything
personal"*) and `docs/ROADMAP.md`'s "Branching and testing rule" (rules 1, 2, 4 and 5). Carried
over from card 1's brief:
- **WoWWizardry 0012 clause 4** (as applied in card 1): every guard in Task 10 is removed once to
  prove a check goes red, then restored.
- **WoWWizardry 0003 / 0017**: characters are keyed `Realm-Name`.

## Ratify before code

The round may not be built while any of these is `proposed`, or while P3 is missing.

- **R1 (proposed): build the addon directory whatever the probe says; the native layer is its
  own card.**
  - **Why the addon directory is needed either way:** the game's lookup takes a recipe ID and
    answers for one recipe at a time, so it can't answer "who can make *something with linen in
    the name*". The asker has no recipe IDs unless they hold the profession. This card's answers
    carry recipe IDs.
  - **If P3 says `Native: works`:** a follow-up card (`dt_professions_native`) adds *"…and the game
    says these guildies know it too"* to `/dt craft`, using the IDs this card's answers supply.
    That covers guildies who don't run the addon.
  - **If P3 says `Native: doesn't work`:** there is no follow-up; this card is the whole directory.
  - **Either way, this card never calls `C_GuildInfo.QueryGuildMembersForRecipe` or
    `QueryGuildMemberRecipes`.**
  - Tim may instead rule "re-brief", in which case this draft is withdrawn.
- **R2 (proposed): sharing is opt-in and answers searches only, as card 6's stash does.**
  - With `/dt craft share on`, your client records your professions (name and rank) and your
    **learned** recipes (recipe ID and name), for every character on the account that runs with
    sharing on. Recipes are recorded when you open each profession window.
  - Nothing is sent except answers to a guildie's search, at most 4 hits each.
  - Off by default. Switching it off deletes the account's list.
- **R3 (proposed): no recipe names on the wire.** An answer carries recipe IDs, and the asker's
  client names them with `C_Spell.GetSpellName` (a recipe ID is the spell it casts, per the
  reference's captures). This keeps answers short and avoids sending free text.
- **R4 (proposed): two verbs, one pattern.**
  - `/dt craft <term>`: who can make something whose recipe name contains the term.
  - `/dt profs <profession>`: who has that profession, and at what rank.
  - `/dt crafts` alone shows what your account offers.
  - Both searches follow card 6's stash pattern: one per 30 s, answers after 1-5 s, a summary at
    10 s, 4 hits per answer, holders up to 24 bytes.
- **R5 (proposed): what this card may change in card 1's files.** Two lines appended to
  `DeadTired.toc` after `Welcome.lua`: `Professions.lua`, `Crafts.lua`. One line in
  `tests/run_all.sh`: `professions:Professions crafts:Crafts` appended to the module list.
  Nothing else. `DT.VERSION` stays `0.1.0`. At merge, keep every card's lines, in card order:
  Crypt (3), Gank (4), Prep's four (5), Stretch's four (6), then this card's two.

## Builds on (card 1, commit `61fe2d3`; Task 1 re-verifies each)

`DT.module{}`, `DT.verb(prefix, fn, usage)`, `DT.send(kind, fields)`, `DT.on(kind, fn)`,
`DT.isMember()`, `DT.guildKey()`, `DT.charKey()`, `DT.display(key)`, `DT.nameOf(key)`,
`DT.safe(s, max)`, `DT.stamp()`, `DT.now()`, `DT.after(d, fn)`, `DT.try`, `DT.clean`, `DT.out`,
`DT.db()`, `DT.errors()`, and Core's router (whole-word verbs, longest wins, non-members refused,
`DT.raw`). Test side: `tests/harness.lua` (`H.world()`, `world:client{...}` with
`files`/`db`/`random`, `client.env` for extra stubs, `:login()`, `:logout()`, `:slash()`,
`:said()`, `:fire()`, `world:advance()`).

API lookups in `reference/SPEC_forever_namespaces.md` at drafting (Task 1 re-checks):
- `C_SkillInfo.GetNumSkillLines`, `C_SkillInfo.GetSkillLineInfo`;
- `C_TradeSkillUI.IsTradeSkillReady`, `GetAllRecipeIDs`, `GetRecipeInfo`,
  `GetTradeSkillLineForRecipe`;
- `C_Spell.GetSpellName`.

Events: `PLAYER_ENTERING_WORLD`, `SKILL_LINES_CHANGED`, `TRADE_SKILL_SHOW`,
`TRADE_SKILL_LIST_UPDATE` (the last is unobserved on this client per the reference: registered
under card 1's `pcall`).

## Deliverable

Two new files, `DeadTired/Professions.lua` (recording) and `DeadTired/Crafts.lua` (searching and
answering), each a module registered through `DT.module{}`, plus `tests/test_professions.lua`,
`tests/test_crafts.lua` and R5's edits:

- **`/dt craft <term>`** asks the guild's sharing members who knows a recipe matching the term,
  and prints the answers 10 seconds later, with recipe names.
- **`/dt profs <profession>`** asks who has that profession, and prints names with ranks.
- **`/dt crafts`** shows what your account offers. **`/dt craft share on/off`** sets whether you
  answer.

**Testable end:** `DeadTired/tests/run_all.sh` exits 0 with eight suites; and in game, a guildie
with sharing on who has opened their Tailoring window answers Tim's `/dt craft linen` with the
right recipes by name, a guildie with sharing off doesn't, and `/dt profs tailoring` lists the
first guildie with their real rank.

### Professions.lua: recording (only while `share` is on, and a member)

**Store.** `DeadTiredDB.craft = { share = false, badCraft = 0, chars = { [<Realm-Name>] = {
at = <DT.stamp()>, profs = { [<name>] = { rank, max } }, recipes = { [<profession name>] = {
[<recipeID>] = <recipe name> } } } } }`. It is account-wide. Only characters that have run with
`share` on have an entry.

**Ranks** (at the first `PLAYER_ENTERING_WORLD`, on `SKILL_LINES_CHANGED`, and when `share` is
switched on). Copy the reference's `readSkills` reading:
- rows `1 .. min(GetNumSkillLines(), 80)` of `C_SkillInfo.GetSkillLineInfo(i)`;
- keep rows that aren't headers, with `skillLineCategoryID` 9 or 11, a non-empty `name`, and
  numeric `rank` and `maxRank`;
- the client lists each profession twice under one name, so rows are keyed by name, and the
  first row read wins.

A read replaces this character's `profs`.

**Recipes** (on `TRADE_SKILL_SHOW` and `TRADE_SKILL_LIST_UPDATE`). Copy the reference's `scan`
shape, without its catalogue:
- **Readiness:** poll `IsTradeSkillReady()` up to 20 times, 0.25 s apart, before reading. Give up
  quietly after that.
- **Reading:** read `GetAllRecipeIDs()`, sorted, 25 IDs per frame step (via `DT.after(0, …)`).
- **Filing:** file each ID under **the profession it reports itself**,
  `select(2, GetTradeSkillLineForRecipe(id))`, never under the window's base profession. The
  reference's 0.15.1 fix: the client can name the new profession while still listing the
  previous one's recipes.
- **Learned only:** keep an ID only if `GetRecipeInfo(id).learned == true`. Its stored name is
  `GetRecipeInfo(id).name`, truncated to 64 bytes.
- **Replacing:** a completed scan replaces this character's `recipes[<profession>]` for **each
  profession it saw**. Professions it didn't see are untouched.
- **A list never shrinks to nothing:** if a scan finds zero learned recipes for a profession that
  already has some, it is ignored and counted in `craft.emptyScans`. The reference's 0.18.2
  lesson: a window can briefly list one or no recipes.
- **Overlap:** a scan already running when another event arrives runs once more when it
  finishes, no more.

**Switching `share` off** deletes `chars` (the whole account's list), as card 6's stash does.

### Crafts.lua: searching and answering

**`/dt craft <term>`** (`term` is the text after `craft`, trimmed, 3-32 bytes, else usage;
`share`, `share on` and `share off` are settings, not searches):
- At most one search of either kind per **30 seconds** per client: *"One question at a time. The
  crypt echoes."*
- Sends `CRAFTQ {q=<n>, term=<term>}`, prints *"Asking the guild's crafters. Answers in 10
  seconds."*, and after 10 s prints the summary.
- **The summary:** one line per holder, in order of arrival,
  `<Holder>: <recipe name>, <recipe name>`. A name comes from `C_Spell.GetSpellName(id)`, or
  `recipe <id>` when that isn't a non-empty string. If there are none: *"Nobody knows it. Or
  nobody's sharing."* Then always *"Only guildies running the addon with craft sharing on
  answer. Open a profession window once to list its recipes."*

**`/dt profs <profession>`** (2-24 bytes):
- Sends `PROFQ {q, prof}`, with the same window, wait and summary pattern.
- **The summary:** *"<Profession>: <Holder> <rank>/<max>, …"*, highest rank first, then
  *"Nobody's admitted to it."* when there are none, then the same closing line.

**Answering `CRAFTQ`** (only with `share` on, at most once per asker and `q`, after a random 1-5 s
delay, with `share` checked again when the delay ends):
- Match `term` against every stored recipe name on the account, case-insensitive, **plain
  substring** (`string.find(…, 1, true)`).
- Holders over 24 bytes are skipped. At most **4** hits, sorted by holder then recipe ID.
- Send `CRAFT {q, to=<asker>, hits=<recipeID>:<holder>,…}`. No hits, no answer.

**Answering `PROFQ`:** the same rules. Match `prof` against stored profession names,
case-insensitive, **whole name** (`tailoring` matches `Tailoring`, not `Tail`). Send
`PROF {q, to, hits=<holder>:<rank>:<max>,…}`, at most 4, highest rank first.

**Receiving `CRAFT` / `PROF`:** only the client whose `charKey()` equals `to` and whose open
question is `q` (of the matching kind) keeps it, once per sender. Validate:
- `q` 1-6 digits; `to` is `Realm-Name`, 1-64 bytes; `hits` holds 1-4 entries;
- `CRAFT` entries match `^%d+:[^:,]+$`, with the ID at most 7 digits and the holder 1-24 bytes;
- `PROF` entries match `^[^:,]+:%d+:%d+$`, with the holder 1-24 bytes and both ranks 0-999;
- also counted in `craft.badCraft`: `CRAFTQ` with a term outside 3-32 bytes, and `PROFQ` with a
  `prof` outside 2-24 bytes.

Invalid counts in `craft.badCraft`. Nothing prints on receipt.

**`/dt crafts`:**
- with sharing on: *"Your account offers <r> recipes in <p> professions across <c>
  character(s). Sharing on."*, with singular forms where the count is 1;
- then one line per character: `<Name>: <Profession> <rank>/<max> (<n> recipes), …`, or
  `(window not opened yet)` for a profession with no recipes recorded;
- with sharing off: *"Sharing off. Nothing offered."*

**Wire.** The longest `CRAFT` (4 hits of a 7-digit ID and a 24-byte holder; `q` 999999; a 64-byte
`to`) works out at 221 bytes; the longest `PROF` (4 × 24-byte holder, 999, 999) at 220; `CRAFTQ`
with a 32-byte term of `^` at 119; `PROFQ` with a 24-byte `prof` of `^` at 94. Task 7 checks each
at most 250.

## Working rules

- **Opt-in.** With `share` off, nothing is recorded, nothing is sent, nothing is kept.
- **What leaves the client:** answers to a search only, at most 4 hits, as IDs, names of the
  account's own characters, and ranks. No recipe names, no full list, ever (R3).
- **Copy from `reference/`, then adapt:**
  - from `ProfessionRecorder.lua`: `readSkills`' row reading (categories 9/11, twin rows keyed by
    name), `scan`'s readiness poll, batching and filing by `GetTradeSkillLineForRecipe`, and
    `learnedOnly`;
  - from `test_forever_professions.lua`: the stub shapes for `C_SkillInfo` and `C_TradeSkillUI`,
    including the stale-window capture.

  Name every copied function in the report, and say what changed. No catalogue, no crafts, no
  skill-up rows: this card records only professions, ranks and learned recipes.
- **No native guild queries** (R1): `C_GuildInfo.QueryGuildMembersForRecipe` and
  `QueryGuildMemberRecipes` are not called.
- **No combat data, nothing public:** no `COMBAT_LOG`, `CombatLog*`, `C_DeathRecap`,
  `SendChatMessage`.
- **Plain matching** for every term from another player.
- **Every API call guarded**, with absence handled as specified.
- **Card 1 is read-only** except for R5 (ROADMAP rule 5). Stubs go in the new test files, on
  `client.env`.
- **Inbound data is data**, printed through `DT.safe` / `DT.display`.
- **Quiet:** nothing prints at login, on receipt, or when a window is scanned.

## Tasks

1. **Re-verify.** Check P1 and P3, and quote P3's last line in the report. Check every *Builds
   on* name and API lookup, and record each.
2. Apply R5. Create both modules with their stores and verbs (usage strings, no bars). Add both
   suites, covering store creation. `run_all.sh` green.
3. **Ranks** and their tests:
   - categories 9/11 kept, others and headers dropped;
   - twin rows keyed by name;
   - the 80-row cap;
   - `C_SkillInfo` absent;
   - sharing off: nothing read. Green.
4. **Recipe scans** and their tests, with `C_TradeSkillUI` stubbed from the reference's shapes:
   - the readiness poll and giving up;
   - batching across frame steps;
   - unlearned recipes never kept;
   - **the stale window** (the window names Mining while listing First Aid recipes, filed under
     First Aid);
   - two professions in one scan;
   - an empty scan ignored and counted;
   - an overlapping scan run once more;
   - names truncated;
   - sharing off: nothing scanned;
   - switching off deletes the list;
   - an alt adds its own entry. Green.
5. **`/dt craft`**, with three clients (sharing, sharing off, asker):
   - the window, the term limits and the reserved words;
   - answers once, after 1-5 s, and the answer-time `share` check;
   - an alt's recipes under the alt's name;
   - the 4-hit cap and its sort; no hits, no answer;
   - `%a+` and `[[[` matched literally;
   - the summary with names from `C_Spell.GetSpellName`, and `recipe <id>` when unknown;
   - late and misaddressed answers ignored; each invalid field counted. Green.
6. **`/dt profs`** and **`/dt crafts`**:
   - whole-name matching (`tail` doesn't match);
   - highest rank first;
   - the summary and empty texts;
   - `/dt crafts` in each state, including `(window not opened yet)`. Green.
7. **Byte budget:** the four longest messages above, each at most 250 bytes.
8. **Full-addon check:** all nine files (card 1's seven plus two) on two members and a non-member.
   A login prints only card 1's welcome; a craft search works end to end; the non-member sends
   and prints nothing.
9. **Grep checks** for G3.
10. **Guard proofs.** Remove once, confirm a check goes red, restore:
    - recording: the `share` gate on reading ranks; the `share` gate on scanning recipes; the
      learned-only rule; filing by the recipe's own line (file under the window's profession
      instead, and see the stale-window check go red); the empty-scan rule; the 80-row cap;
    - answering: the `share` gate on answering, and at answer time; one answer per asker and
      question; plain matching; whole-name profession matching; the 4-hit cap;
    - receiving: misaddressed answers ignored; `CRAFT` validation; `PROF` validation; the 30 s
      window.
11. Write the report and push the branch.

## Explicitly out of scope

- **The native guild recipe lookup** (R1): no `QueryGuildMembersForRecipe`, no
  `QueryGuildMemberRecipes`, no `GUILD_RECIPE_KNOWN_BY_MEMBERS`. That's `dt_professions_native`,
  if P3 says it works.
- **The crafting request board** (moved out of card 6): no requests, orders, "I'll pay", or
  queues.
- **Reagent lists, materials, costs, skill-up colours, crafting history, or a catalogue of
  unlearned recipes.** Wizardry's ledger records those; this card doesn't.
- **Sending a full recipe list or a profession "sync".** Searches only.
- **Reading another player's professions directly** (inspect, the guild roster's profession
  columns, `GetGuildRosterInfo`): only what they choose to send.
- **Tradeskill links** (`|Htrade:`) or clickable recipe links in the output.
- **Localised profession names:** names are matched as the client spells them.
- **A panel, a button, or a profession-window overlay.**
- **Other cards:** death notices (3), gank diary (4), prep and recruitment (5), stash, played and
  events (6).
- **Any change to card 1's files** beyond R5 (ROADMAP rule 5: stop and report instead).

## The one deliberate widening, named

**The addon reads profession windows, and answers questions about what you can make.** No earlier
card read tradeskill data. R2 rules it. What still bounds it:
- off until you switch it on;
- learned recipes and ranks only;
- recorded only when you open your own window;
- sent only as answers to a search, at most 4 hits, as IDs;
- no recipe text on the wire;
- your list deleted when you switch sharing off;
- no game-side query of other players' professions (R1).

## Stop conditions

- P1 fails, or **P3 is missing or doesn't end in `Native: works` / `Native: doesn't work`** →
  stop.
- Any of R1-R5 still `proposed`, or R1 ruled "re-brief" → stop.
- Task 1 finds a *Builds on* name or an API lookup missing → stop and report. Don't substitute
  another function.
- A module needs a change to a card 1 file beyond R5 → stop (ROADMAP rule 5).
- Any design choice needs a native guild recipe query, a full-list send, recipe text on the wire,
  public chat or combat data → stop.
- Any of Task 7's messages exceeds 250 bytes → stop.
- A guard removal in Task 10 leaves every check green → stop.
- In game (Tim): any Lua error at load or on opening a profession window; an unlearned recipe in
  an answer; a recipe filed under the wrong profession; anything sent with sharing off → stop, and
  remove `Professions.lua` and `Crafts.lua` from the `.toc`.

## UAT: acceptance checks

Extracted verbatim to `docs/UAT_dt_professions.md`.

**Offline (the build session runs these):**
- [ ] `[G]` G1: `DeadTired/tests/run_all.sh` exits 0 and runs eight suites (core, guild, comms,
  roster, alts, welcome, professions, crafts).
- [ ] `[G]` G2: the report lists all sixteen Task 10 guard removals, each with the check that
  went red.
- [ ] `[G]` G3:
  `grep -rnE "QueryGuildMembersForRecipe|QueryGuildMemberRecipes|GUILD_RECIPE|GetGuildRosterInfo|SendChatMessage|COMBAT_LOG|CombatLog|C_DeathRecap" DeadTired/ --include=*.lua | grep -v "/tests/"`
  finds nothing.
- [ ] `[G]` G4: `git diff card/dt_foundation --stat -- DeadTired/` lists only the two new files,
  the two new suites, `DeadTired.toc` (2 lines added) and `tests/run_all.sh` (1 line changed).
- [ ] `[G]` G5: the report gives the byte length of the longest CRAFT, PROF, CRAFTQ and PROFQ,
  each at most 250, and quotes P3's last line.

**In game (Tim, with one or two guildies, all on this branch):**
- [ ] `[G]` G6: `/reload` shows no Lua error, and the only line printed is card 1's welcome.
  Opening a profession window prints nothing.
- [ ] `[G]` G7: guildie A runs `/dt craft share on` and opens their Tailoring window, then their
  First Aid window, in quick succession. A's `/dt crafts` shows both professions with recipe
  counts that match what each window lists as learned. No Tailoring recipe counts under First
  Aid, or the other way round.
- [ ] `[G]` G8: guildie B leaves sharing off. Tim's `/dt craft linen`: after 10 s, A is listed with
  Linen recipes **by name**, and B isn't anywhere. A recipe A hasn't learned never appears.
- [ ] `[G]` G9: Tim's `/dt profs tailoring` lists A with A's real rank (as A's skill window shows
  it). `/dt profs tail` lists nobody.
- [ ] `[G]` G10: A runs `/dt craft share off`. Tim's next `/dt craft linen` (after 30 s): A isn't
  listed. A's `/dt crafts` says "Sharing off. Nothing offered."
- [ ] `[H]` H1: **the next time someone needed a crafter, did they ask `/dt craft`, or guild chat?**

**`[H]` count: 1.** Whether the directory replaces "anyone got tailoring?" in guild chat is the
only question that says it was worth building, and no machine can answer it. If H1 is "guild
chat", the directory's value rests on the native layer reaching people who don't run the addon,
and that is the case for `dt_professions_native` (if P3 allows it).

## Reporting

Report: `docs/COWORK_REPORT_dt_professions.md`. Walk-sheet: `docs/UAT_dt_professions.md` (Tim fills
in `docs/UAT_dt_professions_results.md` after walking it; the build session never writes that
file). The report records:
- the starting branch and commit, P3's last line, and Task 1's lookups, each found or not;
- R1-R5 as ratified, and any place the build had to read them;
- every function and test stub copied from `reference/`, by name and source file, and what changed;
- the exact player-facing lines as built, so H1 and the tone can be judged from the report;
- one encoded CRAFTQ, CRAFT, PROFQ and PROF, and the longest of each with its byte length;
- each Task 10 removal and the check that went red;
- the `git diff card/dt_foundation --stat -- DeadTired/` output;
- the output of `run_all.sh`;
- the merge order for the `.toc` and `run_all.sh` lines with cards 3-6;
- anything left undone, and every stop condition that tripped.
