# Cowork report: dt_pvp (card 4)

Brief: `docs/COWORK_BRIEF_dt_pvp.md` (R1-R3 ratified 2026-11-02, as proposed). Walk-sheet:
`docs/UAT_dt_pvp.md`. Built 2026-11-02 in a cloud session, offline only. G6-G11 and H1 are Tim's
to walk.

**Result:** `DeadTired/Gank.lua` is built, all seven suites are green (224 checks, 50 of them
gank), all eight guards were proved red on the first try, and **no stop condition tripped**. One
brief-level finding: the board's third sort key can never be reached (see *Differences*).

## Branch and start

- Branch **`card/dt_pvp`**, created from `origin/card/dt_foundation` at **`61fe2d3`**. It does not
  touch `card/dt_crypt`, and nothing was read from it. The brief and walk-sheet were brought over
  from `claude/loving-meitner-yzdxtn` and stamped ratified.
- P1: `card/dt_foundation` is on origin at `61fe2d3`, and `run_all.sh` → exit 0 on it. P2: R1-R3
  are ratified.

## Task 1: re-verification

Every *Builds on* name was found unchanged at `61fe2d3`:
- **Core.lua:** `DT.module`, `DT.verb`, `DT.charKey`, `DT.nameOf`, `DT.safe`, `DT.stamp`,
  `DT.now`, `DT.try`, `DT.clean`, `DT.out`, `DT.db`, `DT.errors`, and the router (`DT.raw`,
  whole-word verbs, longest wins).
- **Comms.lua:** `DT.send`, `DT.on`.
- **Guild.lua:** `DT.isMember`, `DT.guildKey`.
- **Roster.lua:** `DT.display`.
- **Alts.lua:** `find()`, whose matching rules `/dt ganks <name>` copies.
- **Harness:** `H.world`, `world:client` (`files`, `db`), `client.env`, `:slash`, `:said`,
  `:fire`, `world:advance`.

No delta to report.

## R1-R3 as built

- **R1:** `/dt gank` reads `UnitExists`, `UnitIsPlayer`, `UnitFactionGroup` (target and player),
  `UnitName`, `UnitClass` (the class file only), `UnitLevel` (target) and `GetRealZoneText`.
  It reads them only inside the command and stores name+realm, class, level and zone. Faction is
  checked, never stored. G3's grep confirms no inspect, aura, health or race call.
- **R2:** the log is sent in the same act. The receiver's handler validates and records it;
  there is no print, no reply and no re-send (guard 6 proves the silence).
- **R3:** card 1 changed by exactly two lines (see G4). `Gank.lua` keeps its own store,
  `DeadTiredDB.gank`. The version is still `0.1.0`.

## Copied

`find()` and `squash()` were copied from card 1's `DeadTired/Alts.lua` (not from `reference/`),
with the bodies kept. The only change is the loop: it runs over the board's enemies (`log.who`)
instead of the roster, skipping keys already matched.

## Differences from the brief

1. **The board's third sort key (name) is unreachable.** The order is count, then newest, then
   name. But "newest" is a log's position in the list, and no two logs share a position, so two
   enemies can never tie on recency. The name key is kept in the code (harmless), but no test can
   reach it. Instead the suite proves the second key decides even against name order
   (`Bbb`, logged after `Aaa`, is listed first). If Tim wants names to break ties he
   meant something else by "newest" (the date, say); that's a brief question for later, not a bug.
2. **Our own realm unreadable:** if the target has no realm and `GetRealmName` fails too,
   `/dt gank` refuses with the "won't say who that is" line rather than record a key with no realm.
   The brief didn't cover this case.
3. **`who` is capped at 64 bytes on the sending side**, matching the inbound limit, so an
   absurdly long realm can't produce a log the guild then rejects.
4. **Board wording:** `by 1 guildie` and `by 2 guildies` (the brief wrote `guildie(s)`; G9 expects
   "by 1 guildie").
5. **Names from other realms print as `Name-Realm`** (card 1's `DT.display`), e.g.
   `Backstabz-Nethergarde`. Same-realm names print bare.
6. **The double press counts only your own local logs.** A guildie's received log of the same
   enemy doesn't block your press, as the brief says ("your own most recent local log").
7. Lines carry card 1's `Dead Tired ` prefix. `gank` has no usage string (it takes no
   arguments); `ganks [name]` does.

## Player-facing lines, for H1

| When | Line (after `Dead Tired `) |
|---|---|
| Logged | `Noted: Backstabz-Nethergarde (Rogue 60), Stranglethorn Vale. The crypt remembers.` |
| No target, or an NPC | `Target a player first. Preferably one who deserves it.` |
| Same faction / faction unreadable | `That's one of ours. Put the pen down.` |
| Name hidden or unreadable | `The game won't say who that is right now. Try again out of combat.` |
| Double press | `Already noted. Grudges don't need two copies.` |
| Board row | `1. Backstabz-Nethergarde (Rogue 60) x3 by 2 guildies, last Hillsbrad Foothills 2026-11-03` |
| Board empty | `No grudges yet. Go and make some.` |
| One enemy, row | `2026-11-02 Arathi Highlands (Rogue 60), by Wight` |
| Unknown enemy | `Never heard of them. Yet.` |
| Two realms | `more than one backstabz: Backstabz-Nethergarde, Backstabz-Stormrage. Add the realm.` |
| Closing, every time | `Only logs from guildies running the addon, seen while you were online.` |

Level -1 (a skull) and an unreadable level both print as `??`; an unreadable class prints as
`Unknown`.

## Wire

```
1^GANK^cls~ROGUE^lvl~60^who~Nethergarde-Backstabz^zone~Stranglethorn Vale      73 bytes
```

**Longest GANK: 250 bytes**, exactly as the brief worked out (a 64-byte `who`, a 12-letter class,
`lvl` 100, a 48-byte zone of `^`). That is at most 250, so the stop condition was not tripped.
There is no slack: any wider field limit would make it chunk.

## Task 9: guard proofs

Each guard (marked `-- guard: …` in `Gank.lua`) was broken by script, `run_all.sh` was run, and
the file was restored. The suites were green again afterwards.

| # | Guard | Broken by | Checks that went red |
|---|---|---|---|
| 1 | Player check (NPC refused) | condition → `false` | 9, incl. "no target: refused, nothing recorded or sent", "an NPC: refused" |
| 2 | Faction check | condition → `false` | 7, incl. "a same-faction player: refused", "a player with no faction readable: refused" |
| 3 | Unreadable-name refusal | condition → `false` | "name empty: refused, nothing recorded or sent", then the suite stopped with a Lua error (concatenating a nil name) |
| 4 | 300-second double press | condition → `false` | 8, incl. "a second press at 299 s: already noted" |
| 5 | Inbound field validation | condition → `false` | "each invalid GANK is counted in badGank, not stored, not printed", plus 2 more |
| 6 | Silent receipt | a `DT.out` added after `record` | "nothing printed on the receiver", "a log on one appears on the other's board", plus 1 more |
| 7 | 10-line board | `math.min(#order, SHOW)` → `#order` | "at most 10 lines, then the closing line" |
| 8 | 500 cap | `while` loop deleted | "the store is capped at 500, oldest dropped first" |

## Offline acceptance

- **G1:** `run_all.sh` exits 0 with seven suites:

```
core: 44 passed, 0 failed
guild: 13 passed, 0 failed
comms: 53 passed, 0 failed
roster: 26 passed, 0 failed
alts: 21 passed, 0 failed
welcome: 17 passed, 0 failed
gank: longest GANK is 250 bytes
gank: 50 passed, 0 failed
ALL GREEN
```

- **G2:** the table above lists all eight.
- **G3:** `grep -rE "COMBAT_LOG|CombatLog|SendChatMessage|C_DeathRecap|UNIT_DIED|PARTY_KILL|NotifyInspect|UnitAura|C_UnitAuras|UnitRace|UnitHealth" DeadTired/`
  finds nothing (exit 1).
- **G4:** `git diff card/dt_foundation --stat -- DeadTired/`:

```
 DeadTired/DeadTired.toc       |   1 +
 DeadTired/Gank.lua            | 221 ++++++++++++++++++++++++++++++++
 DeadTired/tests/run_all.sh    |   2 +-
 DeadTired/tests/test_gank.lua | 285 ++++++++++++++++++++++++++++++++++++++++++
```

  In `run_all.sh`, one line changes (`... welcome:Welcome gank:Gank; do`), which git counts as one
  removed and one added.
- **G5:** longest GANK 250 bytes, at most 250.

## For Tim's walk

- The macro is one line: `/dt gank`. Put it on a bar.
- **G11 is the question that matters most for later cards:** does an enemy's name come back
  readable in combat, or hidden? Either answer passes the check. Write down which.
- **Merging with card 3:** both cards append to the `.toc` (after `Welcome.lua`) and to the
  `run_all.sh` module list. Keep both, Crypt first:
  `... welcome:Welcome crypt:Crypt gank:Gank; do`, then `Crypt.lua`, then `Gank.lua` in the `.toc`.

## Left undone, stop conditions

- Nothing in Tasks 1-10 is left undone.
- Stop conditions: none tripped. P1/P2 hold; nothing is missing from *Builds on*; no card 1 file
  changed beyond R3; the longest GANK is 250 bytes; every guard removal went red; nothing needs
  combat data, automatic logging, inspect or public chat.
- Not provable offline: whether an enemy's name or level is secret in combat on the live client
  (G11); what `UnitName` returns for realms on Forever (the stub returns `"Nethergarde"`, retail's
  no-spaces form); whether `UnitFactionGroup` answers for enemy players at range.
- `docs/UAT_dt_pvp_results.md` was not written; that file is Tim's.

## Fix round 1 (F7, F6b)

Built 2026-11-02 from `docs/COWORK_BRIEF_dt_fixes1.md` (audit AUD-04, AUD-07). Round report:
`docs/COWORK_REPORT_dt_fixes1.md` on the session branch. `card/dt_foundation` (F1-F5) was merged
in first: clean, card 1's files identical to its branch, all suites green before these fixes.

- **F7, `Gank.lua`:** `/dt gank`'s "Already noted" is decided by a session table
  `lastPress[who] = DT.now()`, never by a stored value. A new log stores `t = time()` (the
  epoch, guarded; nil if unreadable). No migration: a stored `t` below 1,000,000,000 is old
  uptime, and nothing reads `t`. One consequence, by design: a `/reload` inside the 300 s
  forgets the press.
- **F6b, `Gank.lua`:** a received GANK, after validation, is kept at most once per
  `<sender>#<who>` per 300 s (memory only); the rest count in `gank.dropped`.
- **Tests:** the suite's stubs moved into `opts.setup` so `c:reload()`/`c:reboot()` keep them.
  New: F7 (4 checks: the stored `t` is the epoch; noted after a restart; the window holds within
  a session; a reload forgets it) and F6b (4 checks). The first log's check now asserts
  `t == time()`. Existing board tests that inject the same enemy from the same sender now space
  injections 301 s apart; the `|`-in-zone check logs a different enemy. gank: 58 checks.
- **Guard proofs:** F7, the old stored-`GetTime()` comparison put back: 5 red, incl. *F7: after
  a restart, the same enemy a day later is noted, not 'already noted'*. F6b removed: 4 red, incl.
  *F6b: one sender's 10 GANKs on one enemy inside 300 s keep one*.
- The audit's `test_gank_reboot.lua` passes unchanged. No player-facing line changed.
