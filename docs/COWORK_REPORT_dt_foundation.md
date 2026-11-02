# Cowork report: dt_foundation (card 1)

Brief: `docs/COWORK_BRIEF_dt_foundation.md`. Walk-sheet: `docs/UAT_dt_foundation.md`.
Built 2026-11-02 in a cloud session. No game client was used: everything below was proved
offline with stubbed tests. The in-game checks (G5-G9, H1) are Tim's to walk.

**Result:** `DeadTired/` 0.1.0 is built, all six suites are green (174 checks), all seven Task 8
guards were proved red, and no stop condition tripped.

## Branch: one difference from the brief

The brief says to work on **`card/dt_foundation`**. This session's harness only lets it push to
**`claude/loving-meitner-yzdxtn`**, so the work is there. `main` is untouched. Before card 2
branches off card 1 (ROADMAP rule 1), Tim should create `card/dt_foundation` from this branch:

```bash
git fetch origin claude/loving-meitner-yzdxtn
```

```bash
git push origin origin/claude/loving-meitner-yzdxtn:refs/heads/card/dt_foundation
```

## Task 1: API lookups in `reference/SPEC_forever_namespaces.md`

| Function | Found |
|---|---|
| `C_ChatInfo.RegisterAddonMessagePrefix` | yes (`C_ChatInfo` block, 45 functions) |
| `C_ChatInfo.SendAddonMessage` | yes |
| `C_ChatInfo.AreOutgoingAddonChatMessagesRestricted` | yes |
| `C_Timer.After` | yes (`C_Timer` block: After, NewTicker, NewTimedSignalMap, NewTimer) |

All four are present, so `Comms.lua` went ahead. Globals used, all called through `try` and safe
when absent: `GetGuildInfo`, `GetRealmName`, `UnitName`, `GetTime`, `date`, `time`,
`GetBuildInfo`, `issecretvalue`. `C_ChatInfo.*` is also looked up through a nil-safe path.

## What was built

| File | What it does |
|---|---|
| `DeadTired.toc` | Interface 16001, Title `Dead Tired`, Version 0.1.0, `SavedVariables: DeadTiredDB`, files in the brief's order |
| `Config.lua` | `GUILD_NAME = "DEAD TIRED"`, `PREFIX = "DEADTIRED"`, `PROTOCOL = 1` |
| `Core.lua` | `ns.DT`: the guarded-read helpers, `out()` (prefix `\|cff7fa650Dead Tired\|r`), `db()`, `module()`, internal `listen/signal`, the `/dt` + `/deadtired` router |
| `Guild.lua` | `DT.isMember()`, re-checked on `PLAYER_GUILD_UPDATE` (and `PLAYER_ENTERING_WORLD`) |
| `Comms.lua` | `DT.send`, `DT.on`: the wire format, chunking, throttle, restricted queue, inbound checks |
| `Roster.lua` | HELLO handshake, `DeadTiredDB.roster[<guild>]`, `/dt who` |
| `Alts.lua` | `/dt main`, `/dt main clear`, `/dt alts [name]` |
| `Welcome.lua` | One welcome line per login for members, `/dt welcome on/off` (a slash, not a bar: a bare bar is the chat escape character) |
| `tests/` | `harness.lua` (two-client world, fake GUILD bus), one suite per module, `run_all.sh` |

Player-facing lines, for H1: welcome *"Rest in Pieces, Stromham. The crypt's open. /dt for the
rest."*; `/dt` alone *"0.1.0, still twitching. /dt alts [name] | main [clear] | welcome on/off |
who"*; `/dt welcome off` *"welcome line buried. Silence, as the dead prefer."*; `on` *"welcome
line exhumed."*; `/dt main` *"Stromham is now your main. The rest are just alts."*; `clear`
*"main cleared. Everyone's an alt now."*; no one heard *"this session: nobody yet. Give the dead
a minute to rise."*; unknown name *"no X in the crypt. Only guildies running the addon are
known."*; no main *"X hasn't named a main. Alone in the dark."*; outside the guild *"only stirs
inside <DEAD TIRED>."*

## Copied from `reference/`

From `reference/wizardry/Forever/Core.lua`, bodies kept:
- `secret`, `try`, `clean`, `now`, `stamp`, `build`, `charKey`, `after`: bodies unchanged
  (only `W.` became `DT.`).
- `out`: body unchanged except the prefix (`|cffffcc00Ledger|r` became `|cff7fa650Dead Tired|r`).
- `module`: body unchanged except the `def.pane` line was dropped (no panes in 0.1.0).
- `verb`, `help`, `dispatch`: adapted. `verb` takes an optional usage string for the help line.
  `help` prints the version and verbs, with no panes and no "quests" default. `dispatch` changes:
  (1) a verb has to match a whole word (`main` takes `main clear` but not `mainx`); the reference
  matched any prefix; (2) outside the guild it prints one line and runs nothing; (3) an empty
  message is the help. `DT.raw` now holds the trimmed text with its case kept.
- Not copied: `round4`, `money`, `where`, `place`, `zoneText`, `pane` (nothing in this card
  needs them).

From `reference/wizardry/tests/test_forever_core.lua`: the test style (the `check` counter,
exit status, `CreateFrame`/`RegisterEvent`/`SetScript` stubs, `fire()`), and most of the helper
and module checks, rewritten for `ns.DT`.

New in Core, not in the reference: `DT.safe` (makes inbound text safe to print: `|` doubled,
control bytes stripped, length capped), `DT.nameOf`, `DT.db`, `DT.errors`, `DT.listen` /
`DT.signal`.

## Wire format as built

As the brief specifies, with these points made concrete:

- `<PROTOCOL>^<KIND>^<key>~<value>...`. Fields are written in **sorted key order**. `%`, `^`,
  `~`, `|` and bytes 0-31 are escaped as upper-case `%XX`. The decoder also accepts lower-case
  hex. Any other `%`, or a raw `^ ~ |` or control byte inside a segment, counts as malformed.
- **HELLO gains one field, `r~1`, on replies.** This is the one difference from the brief. A
  reply is never answered. Without the flag, a reply looks like a fresh HELLO to its receiver,
  which then answers it, so every exchange costs three messages. Worse, a client whose first
  message happened to be a reply would never be answered by third parties. With the flag, two
  clients settle after HELLO plus one reply. The login HELLO always goes out unflagged, even if a
  reply was sent first, so a third client still answers it (tested with three clients). `r`
  carries no data: the only data sent is still version and main.
- Chunks: `1^+^<msgid>^<i>^<n>^<slice>`, slices at most 200 bytes, `2 <= n <= 32` (a message
  needing more than 32 chunks is refused on send and counted malformed on receipt). A chunked
  message must reassemble to a whole message; a chunk of chunks is malformed. Incomplete sets are
  swept 30 s after their first chunk (`DeadTiredDB.comms.stale` counts them).
- Inbound order: prefix and `GUILD` → member gate → sender to `Realm-Name` → own-message
  ignore → `pcall(parse)` → unknown protocol counted (`comms.unknownVersion`) → malformed counted
  (`comms.malformed`). The sender's realm comes without spaces (`Stromham-ClassicBetaPvP`). If it
  matches the player's own realm once spaces and hyphens are stripped, it is spelt as
  `GetRealmName` spells it (`Classic Beta PvP-Stromham`), so keys match `charKey()`.
- HELLO fields are checked on receipt (`v`: 1-16 chars; `main`: empty or `Realm-Name`, up to 80
  chars). A bad HELLO is not stored and counts in `comms.badHello`.
- Extra counters, for diagnostics: `comms.sent`, `comms.received`, `comms.sendFailed` (a
  `SendAddonMessage` that errored), `comms.longest`.

Examples (captured from the code):

```
1^HELLO^main~Classic Beta PvP-Stromham^v~0.1.0          login HELLO, 46 bytes
1^HELLO^main~Classic Beta PvP-Stromham^r~1^v~0.1.0      reply, 50 bytes
```

A chunked message (a 259-byte `TEST` message, sent as 2 chunks):

```
1^+^1^1^2^1^TEST^note~Rest in Pieces. Rest in Pieces. ... Rest in Piec      (210 bytes)
1^+^1^2^2^es. Rest in Pieces. ... Rest in Pieces. %5E%7E%7C                  (87 bytes)
```

**Longest message the addon sends in 0.1.0:** a reply HELLO, `25 + len(main)` bytes. That is 50
bytes with `Classic Beta PvP-Stromham`, and **65 bytes with a 40-character main** (stop condition
not tripped). 0.1.0 never needs a chunk; chunking is there for later cards and is proved in
`test_comms`.

## Behaviour notes Tim should know before walking

- **Membership is read live** from `GetGuildInfo` every time it is needed. On a login where the
  guild info arrives late, nothing is wrong: the HELLO (normally at +10 s) and the welcome wait
  for the `PLAYER_GUILD_UPDATE` that names the guild, then go out once.
- **Reply delay** is 2-8 s, random. For G6, both sides should list each other within about 20 s
  of the second login (10 s HELLO, up to 8 s reply).
- **The account's own characters** are written into the roster with `mine = true` when they
  say HELLO, so `/dt alts` with no name shows your own group. `/dt who` leaves them out.
- **`/dt` outside the guild** answers one line (*"only stirs inside <DEAD TIRED>."*) and does
  nothing else. That is a reply to something typed, not unprompted output.
- **Inbound text is printed through `DT.safe`**, so a guildie can't push UI escape codes into
  your chat frame through a version string or a name.
- **A `/reload` counts as a login**: one welcome and one HELLO again (G5, G9 expect this).

## Task 8: guard proofs

Each guard was removed once (script: the line deleted, or for 7a the `pcall` replaced with a
direct call), `run_all.sh` was run, and the file was restored. `run_all.sh` was green again
afterwards.

| # | Guard (file) | Removed | Checks that went red |
|---|---|---|---|
| 1 | Member gate in `send` (Comms.lua) | `if not DT.isMember() then return false end` | comms: "non-member: send sends nothing and answers false", "no guild: send sends nothing" |
| 2 | Member gate on inbound (Comms.lua) | `if not DT.isMember() then return end` in `inbound` | comms: "non-member: inbound is ignored", "joining the guild opens the gate" |
| 3 | Restricted hold (Comms.lua) | `if restricted() then wake(RETRY) return end` | comms: "restricted: nothing sent, the message is held", "restricted: still held before the 5 s retry", "queue cap: 50 held, the 5 oldest dropped and counted", "queue cap: the survivors go out oldest first" |
| 4 | Throttle (Comms.lua) | `if tokens < 1 then wake(...) return end` | comms: "throttle: a burst of 8 sends 5 at once", "throttle: nothing more inside the first second", "throttle: one more after a second" |
| 5 | Reply-once (Roster.lua) | `if answered[from] then return end` | roster: "reply-once: a second plain HELLO from b gets no second reply"; alts: "and does not reply to a HELLO from someone already answered" |
| 6 | Own-message ignore (Comms.lua) | `if key == DT.charKey() then return end` | comms: 4 checks incl. "own message ignored: the GUILD echo does not reach the sender's handlers"; roster: 7 checks incl. "login HELLO goes out once…", "settled: b never answers a reply; 3 HELLOs in all"; alts: 2 checks |
| 7a | Malformed-input `pcall` (Comms.lua) | `pcall(parse, …)` → `true, parse(…)` | comms: "a fault inside parsing never escapes the handler, and is counted" |
| 7b | Malformed-input check (Comms.lua) | `if not ok or res == "malformed" then … return end` | comms: "malformed input is counted and delivers nothing", "a non-string message never raises and is counted", "no sender: counted as malformed", "a reassembled message that is malformed is counted", "a fault inside parsing never escapes…" |

The parser checks every input itself, so to prove the `pcall` (7a) the test injects a fault
inside parsing (`string.char` made to error, in that client's environment only) and checks
that it is caught and counted rather than raised.

## Offline acceptance

- **G1:** `run_all.sh` exits 0 and runs one suite per module:

```
core: 44 passed, 0 failed
guild: 13 passed, 0 failed
comms: 53 passed, 0 failed
roster: 26 passed, 0 failed
alts: 21 passed, 0 failed
welcome: 17 passed, 0 failed
ALL GREEN
```

  (`run_all.sh` fails if a module file exists without its suite. While modules were still
  being built it reported "not built yet" for missing ones, so it could run green after each
  module, as the working rules ask.)
- **G2:** the table above lists all seven guards (7 split into its `pcall` and its check).
- **G3:** `grep -rE "COMBAT_LOG|CombatLog|SendChatMessage" DeadTired/` finds nothing. Its first
  run matched `test_core.lua`'s own self-check, which spelt those names out. The strings in that
  check are now split (`"COMBAT" .. "_LOG"`), and the grep exits 1.
- **G4:** `grep -r "reference/" DeadTired/*.toc DeadTired/*.lua` finds nothing (exit 1).

How the tests work: each client is a separate addon instance, loaded with `setfenv` into its own
environment with its own `ns`, `DeadTiredDB` and stubs. All clients share one clock and timer
queue. The fake GUILD bus delivers each `SendAddonMessage` on the next tick to every client in
the same guild, **the sender included** (the real GUILD channel echoes, which is what the
own-message guard is for). A relog is simulated by a new instance on the same `DeadTiredDB`.

Run from the repo root:

```bash
sh DeadTired/tests/run_all.sh
```

## Left undone, stop conditions

- Nothing in the brief's task list is left undone. The in-game checks G5-G9 and H1 are Tim's.
- Stop conditions: none tripped. lua5.1 (5.1.5) installed with apt; all four API functions
  found; HELLO with a 40-character main is 65 bytes; every guard removal went red; nothing needs
  combat events, public chat, or another player's game state.
- Not proved offline, and can't be without the live client: the interface number (P2); the exact
  sender format `CHAT_MSG_ADDON` uses on the live client (both `Name-Realm` and a bare `Name` are
  handled); whether `PLAYER_GUILD_UPDATE` fires when guild info arrives late on a login (if it
  doesn't, that character's HELLO and welcome wait until the next zone change or `/reload`).
- `docs/UAT_dt_foundation_results.md` was not written; that file is Tim's.

## Fix round 1 (F1-F5)

Built 2026-11-02 from `docs/COWORK_BRIEF_dt_fixes1.md` (audit `docs/AUDIT_2026-11-02.md` on
`audit/2026-11-02`, findings AUD-01, 05, 12, 15, 16). The round report is
`docs/COWORK_REPORT_dt_fixes1.md` on the session branch.

- **F1 (AUD-01), `Roster.lua`:** a session token, `math.random(1, 999999)` through `DT.try`
  (falling back to `time() % 999999 + 1` when that doesn't give an integer in range), exposed as
  `DT.sessionToken` and sent as `s` in every HELLO. `answered` is keyed `<sender>#<s>`; a HELLO
  with no `s` is token `0`. On receipt `s` must be 1-6 digits, else the HELLO is refused and
  counted in `comms.badHello`. `PROTOCOL` stays 1.
- **F2 (AUD-05), `Roster.lua`:** while a reply is scheduled, a further HELLO that needs one is
  marked answered and counted in `comms.repliesSaved`; nothing more is scheduled. The pending
  reply goes out once and covers it.
- **F3 (AUD-12), `tests/harness.lua`:** `client:reload()` (Lua state dropped, a new instance on
  the same SavedVariables, `PLAYER_ENTERING_WORLD(false, true)`) and `client:reboot(uptime)`
  (as reload, `GetTime()` restarting at `uptime`, default 600, then a login). `time()` now moves
  with the world clock (`1793833200` at the start, +1 per world second) instead of being frozen,
  which `reboot` needs and which a clock-based id needs to be testable. `opts.setup(c)` runs
  before `ADDON_LOADED` and is kept across reload/reboot.
- **F4 (AUD-15), `Core.lua`:** `pcall(def.init)`; a failure is counted under `errorKey`, its text
  under `lastKey` as `init: <error>`, the events are registered anyway, then the error is
  re-raised (as a handler failure is).
- **F5 (AUD-16), `Comms.lua`:** `msgid` starts at `time() % 100000` (guarded; 0 if the clock
  can't be read), so the first chunked message is `time() % 100000 + 1`.

Wire, as built now:

```
1^HELLO^main~Classic Beta PvP-Stromham^s~123456^v~0.1.0        login HELLO, 55 bytes
1^HELLO^main~Classic Beta PvP-Stromham^r~1^s~123456^v~0.1.0    reply, 59 bytes
```

Longest HELLO: `34 + len(main)` bytes, 74 with a 40-character main.

New checks: core +3 (F4), comms +1 (F5; two chunk checks no longer pin `msgid` to 1), roster +15
(F1 reload, second reload, relog, same-session HELLO; token validation and token 0; F2 wave of 5).
Two HELLO text checks (roster, alts x2) now include `s~<token>`. Suites: core 47, guild 13,
comms 54, roster 41, alts 21, welcome 17.

Guard proofs (removed once, suite red, restored):

| Guard | Removed as | Red |
|---|---|---|
| F1 token in the `answered` key | `local who = from` | 8 roster checks, incl. *F1: after B reloads, A replies once more*, *F1: after the relog, B's /dt who lists A* |
| F1 token validation | `or not validToken(f.s)` dropped | *F1: a token that isn't 1-6 digits is refused and counted*, *F1: a HELLO with no token is answered (token 0)*, *F1: ... and is the same session as an explicit s~0* |
| F2 one pending reply | `if replyPending` → `if false` | *F2: in a wave of 5, each client sends at most 2 replies (most 4)*, *F2: replies saved are counted (0)* |
| F4 `pcall` around `init` | `def.init()` called directly | *F4: and counted under the module's own key*, *F4: its events are registered anyway, and run* |

No player-facing line changed.
