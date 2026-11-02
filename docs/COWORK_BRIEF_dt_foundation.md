# Cowork brief: DEAD TIRED foundation (the addon shell, guild comms, who runs it, alt registry)

**Where you are:** repo `timpsmith28-hash/dead-tired-addon`, a cloud session. Work on branch
**`card/dt_foundation`**, created from `main`. No game client is available; everything is proved
offline with stubbed tests, then Tim walks it in game.

**Read before Task 1, in order:**
1. `CLAUDE.md` (house rules; they bind throughout this round).
2. This brief, then `docs/UAT_dt_foundation.md`.
3. `reference/wizardry/Forever/Core.lua` and `reference/wizardry/tests/test_forever_core.lua`
   (the patterns to copy).
4. `reference/SPEC_forever_namespaces.md`: search it, don't read it top to bottom.

**Draft-status:** written 2026-11-02 at about 01:00 UK, the night the repo was created and before
any addon code exists. The only "already exists" claims are about `reference/` and the API
reference; Task 1 re-verifies them. The live Forever client launches 2026-11-04 and may differ
from the beta build the API reference describes.

## Origin

Tim, 2026-11-02, after setting up the guild's Discord the same evening: turn the Wizardry addon
idea into an optional **guild addon** for <DEAD TIRED>, "not mandatory for members, only
advised", using the remaining cloud credit before it expires on 4 November. The feature list and
which ideas made the cut are in `docs/ROADMAP.md`. This card is the foundation every other card
builds on, plus the first small feature that proves the guild comms work end to end: the
**alt registry**.

## Precondition

- P1: `main` holds `CLAUDE.md`, `docs/ROADMAP.md`, this brief, its walk-sheet and `reference/`,
  and no `DeadTired/` folder.
- P2: **Interface number:** `16001`, the beta's value. The live client can't be checked until
  launch (2026-11-04 evening). Build against 16001. If the live client reports a different number
  (`/dump select(4, GetBuildInfo())`), Tim changes the one `## Interface:` line before walking;
  nothing else in the round depends on it.

## Depends on: rulings

This repo has no rulings yet. The binding rules are in `CLAUDE.md`. Two disciplines are adopted
from Tim's `WoWWizardry` repo and restated here because that repo isn't available to this session:
- **WoWWizardry 0012 clause 4** (as applied there): every guard is removed once during the build
  to prove a check goes red, then restored.
- **WoWWizardry 0003 / 0017**: characters are keyed `Realm-Name`.

**Ratify before code:** nothing. Tim ratifies this brief as a whole.

## Deliverable

A new addon, **`DeadTired/` version 0.1.0**, loading on the Forever client:

- **`DeadTired.toc`**: `## Interface:` set to the number in P2. Title `Dead Tired`,
  `## SavedVariables: DeadTiredDB`, files listed in the order below.
- **`Config.lua`**: `GUILD_NAME = "DEAD TIRED"` (the in-game guild name; matched
  case-insensitively, surrounding spaces ignored), `PREFIX = "DEADTIRED"`, `PROTOCOL = 1`.
- **`Core.lua`**: `ns.DT` with the guarded-read helpers copied from the reference (`try`, `clean`,
  `secret`, `now`, `stamp`, `after`, `charKey`, `build`), `out()` printing with the prefix
  `|cff7fa650Dead Tired|r`, `module(def)` with the reference's semantics, and one slash router
  for `/dt` and `/deadtired`. `/dt` with no verb lists the verbs.
- **`Guild.lua`**: `DT.isMember()`: true only when `GetGuildInfo("player")` names the guild in
  `Config.lua`. Re-checked on `PLAYER_GUILD_UPDATE`.
- **`Comms.lua`**: guild addon messaging, specified under *Wire format* below.
- **`Roster.lua`**: who runs the addon (HELLO handshake), `/dt who`.
- **`Alts.lua`**: the alt registry, `/dt main`, `/dt main clear`, `/dt alts [name]`.
- **`Welcome.lua`**: the rebrand's visible face: one welcome line per login for members, toggled
  by `/dt welcome on|off`.
- **`tests/`**: one suite per module plus `run_all.sh`.

**Testable end:** `DeadTired/tests/run_all.sh` exits 0; and in game, two guildies running 0.1.0
each see the other in `/dt who` within 30 seconds of logging in, and `/dt alts <name>` on one
shows the other's main and alts.

### Wire format (Comms.lua)

- Prefix `DEADTIRED`, registered with `C_ChatInfo.RegisterAddonMessagePrefix` at load. Sent with
  `C_ChatInfo.SendAddonMessage(PREFIX, text, "GUILD")`. Only `GUILD` is used, in and out.
- A message is `<PROTOCOL>^<KIND>^<key>~<value>^<key>~<value>...`, e.g. `1^HELLO^v~0.1.0^main~Realm-Stromham`.
  `KIND` is upper-case letters only. Keys and values are escaped: `%`, `^`, `~`, `|` and every
  byte below 32 become `%XX` (upper-case hex). Decoding reverses it.
- **Chunking:** an encoded message longer than **250 bytes** is sent as chunks
  `<PROTOCOL>^+^<msgid>^<i>^<n>^<slice>`, where `slice` is the next part of the full encoded
  message (at most 200 bytes), `msgid` a per-session counter, `i` 1-based. The receiver
  reassembles per sender and `msgid` and discards an incomplete set after 30 seconds.
- **Throttle:** a token bucket, capacity 5, refilling 1 token per second. Sends beyond it wait in
  a FIFO queue.
- **Restricted:** while `C_ChatInfo.AreOutgoingAddonChatMessagesRestricted()` returns true, the
  queue holds and is retried every 5 seconds. Queue cap 50: the oldest is dropped and
  `DeadTiredDB.comms.dropped` counts it.
- **Inbound:** `CHAT_MSG_ADDON` with the prefix and channel `GUILD` only. The sender is
  normalised to `Realm-Name` (a bare `Name` takes the player's own realm). Messages from the
  player themself are ignored. A message with an unknown `PROTOCOL` is counted in
  `DeadTiredDB.comms.unknownVersion` and ignored. A malformed message is counted in
  `DeadTiredDB.comms.malformed` and ignored; it never raises.
- **API:** `DT.send(kind, fields)` and `DT.on(kind, fn(senderKey, fields))`.
- **Gate:** if `DT.isMember()` is false, `DT.send` sends nothing and inbound messages are ignored.

### Roster.lua

- 10 seconds after the first `PLAYER_ENTERING_WORLD` of a login, a member sends
  `HELLO {v=<version>, main=<main charKey or "">}` once.
- On receiving a HELLO from a sender not yet heard this session, reply with one HELLO after a
  random 2-8 second delay. **At most one reply per sender per session**, so two clients settle
  after one exchange.
- Store `DeadTiredDB.roster[<guild>][<senderKey>] = { v, main, seen = <stamp()> }`.
- `/dt who` lists everyone heard **this session**, then "seen before" names from the store, and
  always ends with: *"Only guildies running the addon show up here."*

### Alts.lua

- `/dt main` makes the current character the account's main: `DeadTiredDB.account.main = charKey`
  (SavedVariables are account-wide, so every character on the account reports the same main).
  `/dt main clear` removes it. Both send a fresh HELLO.
- `/dt alts <name>`: find the roster entry whose character name matches (case-insensitive,
  realm optional), then print its main and every roster entry sharing that main. With no name,
  print the player's own group.
- Honour system: no attempt to verify that alts belong to the same person.

## Working rules

- **Copy, then adapt.** Helpers come from `reference/wizardry/Forever/Core.lua` with bodies kept;
  name the copied functions in the report.
- **Nothing combat, nothing public.** No `COMBAT_LOG` event, no `CombatLog*` call, no
  `SendChatMessage` anywhere in `DeadTired/`. Only `GUILD` addon messages.
- **Every API call guarded.** Any function not listed in `reference/SPEC_forever_namespaces.md`
  (or a well-known global like `GetGuildInfo`) is called through `try` and its absence handled.
- **Two-client tests.** Roster and Alts are tested with two addon instances (separate `ns` and
  stub state) joined by a fake GUILD bus that delivers each `SendAddonMessage` to the other
  instance's `CHAT_MSG_ADDON` handler.
- **One module at a time.** After each module lands, `run_all.sh` runs green before the next.

## Tasks

1. **Re-verify** against `reference/SPEC_forever_namespaces.md` that `C_ChatInfo` has
   `RegisterAddonMessagePrefix`, `SendAddonMessage` and `AreOutgoingAddonChatMessagesRestricted`,
   and `C_Timer` has `After`. Record the result in the report.
2. Create `DeadTired/DeadTired.toc`, `Config.lua`, `Core.lua`; `tests/test_core.lua`; and
   `tests/run_all.sh`.
3. `Guild.lua` and `tests/test_guild.lua` (member, non-member, no guild, case and spacing).
4. `Comms.lua` and `tests/test_comms.lua`: escaping round-trip (including every escaped
   character), chunking and reassembly (including a 3-chunk message and a stale incomplete set),
   throttle, restricted queue, queue cap, own-message ignore, unknown version, malformed input,
   non-member gate.
5. `Roster.lua` and `tests/test_roster.lua` (two clients: one exchange settles; `/dt who` text
   including the closing line).
6. `Alts.lua` and `tests/test_alts.lua` (two clients: set main, alt reports it, `/dt alts` from
   the other side; `clear`).
7. `Welcome.lua` and `tests/test_welcome.lua` (once per login, member only, toggle persists).
8. **Guard proofs.** Remove once, confirm a check goes red, restore: the member gate in `send`;
   the member gate on inbound; the restricted hold; the throttle; the reply-once rule; the
   own-message ignore; the malformed-input `pcall`/check.
9. Write the report and push the branch.

## Explicitly out of scope

- **Any other card's features**: profession directory, death notices, gank diary, raid-prep,
  recruitment rotator, anything in the stretch list. Even "just the data structure".
- **A graphical panel or minimap button.** Slash commands only in 0.1.0. The hub pane comes later.
- **Guild rank display or rank sync with Discord.** Ranks are set in game by the GM.
- **Porting Wizardry modules** (Ledger, Angler, Probe). `reference/` is for patterns only.
- **Whisper or party channels, cross-guild messaging, or encryption.**
- **A version-update nag.** Version is carried in HELLO; nothing acts on it yet.

## The one deliberate widening, named

**The addon talks to other players' clients.** Wizardry only ever read the player's own game.
This round sends data to guildies and accepts data from them. What still bounds it: guild channel
only; members only; nothing sent but version and main; inbound messages are data that is stored
and printed, never executed or used to call game functions; malformed input is counted and dropped.

## Stop conditions

- `lua5.1` can't be installed → stop and report.
- Task 1 finds any of the four functions missing from the reference → stop and report before
  writing `Comms.lua`.
- An encoded HELLO, with a 40-character main, exceeds 250 bytes → stop. The wire format is wrong
  for its first message.
- A guard removal in Task 8 leaves every check green → stop.
- Any design choice would need combat events, public chat, or reading another player's game
  state directly → stop.
- In game (Tim): any Lua error at load, or the welcome showing for a character outside the guild
  → stop, and remove the folder.

## UAT: acceptance checks

Extracted verbatim to `docs/UAT_dt_foundation.md`.

**Offline (the build session runs these):**
- [ ] `[G]` G1: `DeadTired/tests/run_all.sh` exits 0, and runs one suite per module (core, guild,
  comms, roster, alts, welcome).
- [ ] `[G]` G2: the report lists all seven Task 8 guard removals, each with the check that went
  red.
- [ ] `[G]` G3: `grep -rE "COMBAT_LOG|CombatLog|SendChatMessage" DeadTired/` finds nothing.
- [ ] `[G]` G4: `grep -r "reference/" DeadTired/*.toc DeadTired/*.lua` finds nothing.

**In game (Tim, with one guildie, both on 0.1.0):**
- [ ] `[G]` G5: `/reload` shows no Lua error, and exactly one welcome line.
- [ ] `[G]` G6: within 30 seconds of both being online, `/dt who` on each lists the other under
  "this session", and ends with "Only guildies running the addon show up here."
- [ ] `[G]` G7: Tim runs `/dt main` on Stromham, then logs an alt. The guildie's
  `/dt alts <alt name>` prints Stromham as main and the alt in the group.
- [ ] `[G]` G8: a character not in the guild logs in with the addon enabled: no welcome, and the
  guildie's `/dt who` does not list that character.
- [ ] `[G]` G9: `/dt welcome off`, `/reload`: no welcome line. `/dt welcome on` restores it.
- [ ] `[H]` H1: **does it feel like *our* addon (the tone, the welcome line, `/dt`), or like a
  generic tool with our name on it?**

**`[H]` count: 1.** Tone is Tim's call.

## Reporting

Report: `docs/COWORK_REPORT_dt_foundation.md`. Walk-sheet: `docs/UAT_dt_foundation.md` (Tim
fills in `docs/UAT_dt_foundation_results.md` after walking it; the build session never writes
that file). The report records:
- Task 1's four lookups, each found or not;
- every function copied from `reference/`, by name and source file, and any body changed;
- the final wire format as built, with one encoded HELLO and one chunked message as examples,
  noting any difference from this brief;
- each Task 8 removal and the check that went red;
- the length in bytes of the longest message the addon sends in 0.1.0;
- the output of `run_all.sh`;
- anything left undone, and every stop condition that tripped.
