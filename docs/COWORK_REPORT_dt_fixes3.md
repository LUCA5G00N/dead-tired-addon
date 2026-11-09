# Cowork report: DEAD TIRED fix round 3 (dt_fixes3)

Brief: `docs/COWORK_BRIEF_dt_fixes3.md` (on `main` at `97bb28a`). Walk-sheet: `docs/UAT_dt_fixes3.md`.
This report is on `release/0.1.0-rc3`.

**Result:** card 1 now holds messages only in chat lockdown (R-1). It prints the held line once
per hold, and retries and then drops refused sends (AUD-10). It keys every character
`NormalisedRealm-Name` and migrates stored keys once (AUD-06). The foundation is merged into all
five card branches. Cards 3, 4, 5 and 6 migrate their own stores, and card 5 has the recruit
nudge. The probe's `registered` read is fixed. `release/0.1.0-rc3` is cut from rc2. Every suite
passes (rc3: 15 suites, 860 checks), and the audit's `test_realm_spelling.lua` went from 0/2 to
2/2. All 10 of the brief's guards, plus 5 extra, were removed once, turned a check red and were
put back. The three zips match their sources and the rc2 zip is gone from rc3. No stop
condition tripped.

## Heads

| Branch | Old head | New head |
|---|---|---|
| `card/dt_foundation` | `696dd87` | `b0feeaa` |
| `card/dt_crypt` | `f6f97c9` | `e9a77c5` (merge `024821e`) |
| `card/dt_pvp` | `b57c6db` | `3dab8c4` (merge `d16addd`) |
| `card/dt_prep` | `6fb903b` | `716580b` (merge `a4faac4`) |
| `card/dt_stretch` | `39e636f` | `2a43bb7` (merge `73fa9a0`) |
| `card/dt_logs` | `2558f4c` | `9793ec9` (the foundation merge only) |
| `card/dt_probe` | `a25b538` | `2baa6a9` |
| `release/0.1.0-rc2` | `dcaaca4` | `dcaaca4` (untouched) |
| `release/0.1.0-rc3` | (new, from rc2 `dcaaca4`) | the commit adding this report (rc3 changes `399b494`) |

Every head matched the brief's table at the start. `main`, `audit/2026-11-02` and rc1/rc2 were not
changed. The session's own branch (`claude/gallant-lamport-mfne0l`) carries nothing: the brief's
branches are where the work lives.

## Baseline (Task 1)

`lua5.1` was not installed. It was installed with `apt-get install -y lua5.1` (after an
`apt-get update`); no other Lua was used.

| Branch | `run_all.sh` |
|---|---|
| foundation | exit 0: core 47, guild 13, comms 54, roster 41, alts 21, welcome 17 |
| crypt | exit 0: card 1 as above + crypt 93 |
| pvp | exit 0: + gank 58 |
| prep | exit 0: + prep 50, recruit 55 |
| stretch | exit 0: + stash 81, played 61, events 26 |
| logs | exit 0: + logs 122 |
| rc2 | exit 0: 15 suites, 766 checks (together 27) |
| probe | `test_probe.lua` 153 passed |

`audit/tests/test_realm_spelling.lua` against my checkouts of the card branches
(`DT_AUDIT_WT=<worktree dir>`, the same harness loading as `setup.sh`): **0 passed, 2 failed**
(*an asker on a realm with a space…*, */dt alts on the other realm shows Stromham as a main…*:
it said `Stromham-Argent Dawn's lot: … alts (1): Stromham-ArgentDawn.`).

## R-1 + held wording (Task 2), `card/dt_foundation`

- `Comms.lua`: the pump's hold test is now `C_ChatInfo.InChatMessagingLockdown() == true` (via
  `try`). If the function is absent, errors or returns a secret, that counts as not in lockdown.
  Retries stay at every 5 s.
- `AreOutgoingAddonChatMessagesRestricted` is read once per Lua session, at the first
  `PLAYER_ENTERING_WORLD` (a new Comms event), into `comms.flagRestricted` (the last reading) and
  `comms.flagReads` (+1 per read). Nothing reads either value back.
- Held line, `The dead are gagged for this fight. Your message goes when it's over.`, printed by
  `DT.send` when the pump is holding for lockdown **and** the send comes from a typed `/dt`
  command. It prints at most once per hold. A hold ends when the pump next passes the lockdown
  test, and a later hold can print it again.
- Nothing else in the pump changed for R-1.

**The existing "restricted" checks, rewritten to the lockdown form:** *restricted: nothing sent,
the message is held* → *lockdown: …*; *restricted: still held before the 5 s retry* → *lockdown:
…*; *restricted: sent on the 5 s retry once lifted* → *lockdown: …*. The two queue-cap checks now
hold with `lockdown = true`. *A SendAddonMessage failure is counted, never raised* (`sendFailed`)
became *a SendAddonMessage error is counted as a refusal, never raised* (`sendRefused`,
`lastRefusal`), because AUD-10 replaces `sendFailed`.

**New checks (comms):**
- *R-1: the restricted flag is read at login and recorded (flagReads 1, flagRestricted true)*
- *… read once per login, not on every loading screen*
- *R-1: flag true, no lockdown: the message is sent*
- *… the whole queue goes, and the pump never asked the flag* (the stub counts calls: 1)
- *… the next login reads it again: flagReads 2, the last reading kept*
- *InChatMessagingLockdown absent: sends*, *… erroring: sends*
- *lockdown true: held*, *… retried and still held*, *lockdown lifted: sent*
- Held line (9 checks): the brief's exact wording; never outside lockdown; never for a send the
  addon makes by itself; once for a typed command held for lockdown; not for the second queued
  message; not again in the same hold; everything goes when the hold ends; not for a command
  outside lockdown; again for a new hold.

## AUD-10 (Task 3), `card/dt_foundation`

- The `SendAddonMessage` result is checked. Success is `Enum.SendAddonMessageResult.Success`
  when that table has it, else `0`, or `true`/`nil`. Anything else, a raised error, or a missing
  function is a refusal.
- A refusal counts `comms.sendRefused` and sets `comms.lastRefusal` (the code or error text as a
  string). The message goes back to the **front** of the queue, and the next try waits at least
  1 s, or longer if the throttle needs it (a "not before" time, so a new `DT.send` can't skip the
  wait).
- After 3 refusals of the same message it is dropped (`comms.refusedDropped`) and the queue moves
  on. The count resets when a message succeeds or is dropped, and when the queue cap drops the
  head.
- Harness: `c.sendResult` (default `0`; `H.NIL` answers nil; a function is called with the text).
  A non-success result is recorded in `c.refused` and is neither sent nor delivered.

**Checks (15):**
- *return 0: sent*; *return true and return nil: sent*
- *return 5: refused, counted, the code kept*; *the refused message is still at the head of the
  queue*; *nothing retried inside the 1 s wait*; *retried after the wait, then sent in order*
- *two refusals: still queued, still first*; *the third refusal drops it and counts the drop*;
  *the next message then goes*; *a new message starts its own count*, *…and goes when the game
  takes it*
- *a raised error counts as a refusal and requeues*, *…and is retried*
- *with Enum present, a non-Success code is a refusal*; *… Success (0) is sent*

comms: 54 → 88.

## AUD-06 (Task 4), `card/dt_foundation`

- `Core.lua`:
  - `DT.realmKey(realm)`: the given realm, or with none the own realm, taken from
    `GetNormalizedRealmName()` if that returns a non-empty string and from `GetRealmName()`
    otherwise. Either way spaces and hyphens are removed.
  - `DT.keyOf(name, realm)` builds the key.
  - `DT.normKey(key)` rewrites one stored key (not in the brief; see *Choices*).
  - `DT.migrateKeys(tbl, fields, stamp)`.
  - `DT.charKey()` uses `keyOf`.
- `Comms.lua`: `senderKey()` = `DT.keyOf(name, realm)`, with a bare `Name` on the own realm.
- `Roster.lua`: `DT.display()` treats a key as the own realm when `DT.realmKey(realm) ==
  DT.realmKey()`, so it shows the name alone. A HELLO's `main` is stored as `DT.normKey(main)`.
- Harness: `GetNormalizedRealmName` (`c.normRealm` overrides; `false` answers nil; the
  `normRealm = "absent"` option removes it) and `InChatMessagingLockdown` (`c.lockdown`).
  `Client:key()` is the new spelling, and `Client:oldKey()` the old.

**Migration behaviour:**
- It runs in `DT.db()`, so at the first store access at load, once per account. The flag is
  `DeadTiredDB.keysV = 2`, and a brand-new store gets the flag too.
- It rewrites every key in every guild's roster, every roster entry's `main`, and
  `account.main`.
- When two old keys become one, it keeps the entry with the newer `seen`. On a tie, or with no
  stamp, the entry already under the new key stays (else the first old key, sorted).
- It is safe to run again: already-normalised keys are left alone. It returns (rewritten, merged).
- No entry was found that it could not merge (every roster entry carries `seen`).

**Checks:**
- core (13 new): `realmKey` from `GetNormalizedRealmName`, then the fallback when it is empty and
  when it is nil (`CAMWOW EU4 Realm 2 PvP` → `CAMWOWEU4Realm2PvP`, and `charKey` matches), hyphens
  removed, a given realm normalised, `keyOf`, `normKey`, `migrateKeys` (rewrites, merges by newer
  `seen` either way round, its counts, a second run changes nothing, another stamp field), a new
  store marked `keysV = 2`. *charKey is Realm-Name* became *charKey is NormalisedRealm-Name
  (AUD-06)*.
- roster (5 new): a sender `Bob-ArgentDawn` and the local `Argent Dawn` realm give the same key
  (and own-message detection agrees); display hides the own realm (both spellings), names another
  realm, and hides the own realm on the `GetRealmName` fallback too; one entry per character, a
  main sent in the old spelling stored in the new.
- alts (6 new): the migration rewrites every roster key and merges collapsing pairs; the merge
  keeps the newer `seen`; each `main` and the account's main are rewritten; `keysV = 2`;
  `/dt alts` shows main and alt once each; a second load does not migrate again.

## Merges and card stores (Task 5)

All five foundation merges were clean: no conflicts and no files outside the card's own. After
the merges, every card's own suite was red only where its tests spelt keys the old way
(`Classic Beta PvP-…`). Those literals were rewritten to `ClassicBetaPvP-…` in the card tests.
User input such as `/dt alts Classic Beta PvP-BONECHILL` and pure wire-encoding examples were
left as they were. Then:

| Card | Store migrated (own flag `keysV = 2`, in the module's init) | Also | Suite |
|---|---|---|---|
| 3 crypt | every guild's `deaths[i].who`; `hcTold` keys (else a hardcore character already told would be told again) | | 93 → 98 |
| 4 pvp | every guild's `logs[i].who` and `.by` | `/dt gank` builds `who` with `DT.keyOf(name, realm)` (empty or nil realm means ours); a received `who` is stored as `DT.normKey(who)` | 58 → 62 |
| 5 prep | nothing: prep stores no character keys | PREP's `to` compared as `DT.normKey(to) == DT.charKey()` | prep 50 → 51 |
| 6 stretch | `stash.chars` keys; every played board's keys (two collapsing keep the newer `t`) | STASH's `to` compared the same way | stash 81 → 85, played 61 → 64 |
| 7 logs | nothing (Logs keys nothing) | merge only | 122 |

Checks on each card:
- crypt: an old spaced key in the graveyard is rewritten; `hcTold` moves too; so a character
  already told is not told again; the migration runs once; the graveyard hides the own realm and
  names another.
- pvp: who and by rewritten; a new log of the same enemy groups with the migrated one (x2); the
  migration runs once; a received old-spelling `who` is stored in the new spelling.
  *An enemy on our realm: the realm spelt as GetRealmName spells it* became *… the realm in the
  one key spelling (fix round 3, AUD-06)*.
- prep: an answer whose `to` is in the old spaced spelling is counted once.
- stretch:
  - stash: an old key is rewritten; the logged-in character joins it with one spelling; the
    migration runs once; a STASH answer with an old-spelling `to` still arrives. The existing
    check *each invalid STASH / STASHQ field is counted…, nothing printed* now expects 4 printed
    lines, not 3, because the new old-spelling answer prints one.
  - played: an old key is rewritten; collapsing keys keep the newer `t`; the migration runs once.
- Each card's existing tests still pass.

## Recruit nudge (Task 6), `card/dt_prep`, `Recruit.lua`

A successful post schedules one `DT.after(900)`. When it fires, it prints
`The crypt door creaks open: you can recruit again (/dt recruit).` only if all of these hold:
- it belongs to this session's latest post (a counter);
- the nudge is on (`DeadTiredDB.prep.recruitNudge ~= false`, so default on, account-wide);
- the player is still a member and `IsGuildOfficer` is true.

It prints and does nothing else. `/dt recruit nudge off` / `on` set the saved flag.

**Checks (19 new; recruit 55 → 74):**
- the exact wording; nothing at 899 s; exactly one line at 900 s; once only
- it never posts: the `SendChatMessage` stub's count stays at the one post
- a second post cancels the first's nudge, and its own comes 900 s after it
- no line if not an officer, or out of the guild, when due
- `nudge off` is saved and prints nothing; no line while off; still off on another character
  after a login; `nudge on` brings it back
- no line at login without a post this session; a refused post schedules nothing

## Probe `registered` (Task 7), `card/dt_probe`

`registered = r == 0 or r == 1 or r == true`, where `r` is the raw return still recorded in
`register`. Checks: return 0 → true, 1 → true, true → true, 2 → false, false → false, an error →
false, and the raw return is kept for each non-error case. probe: 153 → 164.

## Guard proofs (Task 8)

Each guard was removed once (scripted: edit, run the branch's suite, restore the file). The trees
were clean afterwards.

| Guard | Removed as | Red (count: examples) |
|---|---|---|
| Lockdown hold (R-1), `Comms.lua` | `if false then …` | 11: *lockdown: nothing sent, the message is held*, *R-1: lockdown true: held*, *R-1: lockdown true: retried and still held*, the queue-cap pair, and held-line checks |
| The flag no longer gates | the old `AreOutgoingAddonChatMessagesRestricted` hold put back at the top of the pump loop | 3: *R-1: flag true, no lockdown: the message is sent*, *R-1: flag true: the whole queue goes, and the pump never asked the flag*, *R-1: InChatMessagingLockdown absent: sends* |
| AUD-10 success test | `return true` | 9: *AUD-10: return 5: refused, counted, the code kept*, *… still at the head of the queue*, *… the third refusal drops it…*, *… a raised error counts as a refusal…*, etc. (the suite then stopped on an index error at `test_comms.lua:297`, also red) |
| AUD-10 3-refusal limit | `if false then` | 8: *AUD-10: the third refusal drops it and counts the drop*, *AUD-10: the next message then goes*, … |
| AUD-10 front-of-queue requeue | requeued at the back | 8: *AUD-10: two refusals: still queued, still first*, *AUD-10: the third refusal drops it…*, … |
| `realmKey` normalise step, `Core.lua` | the `gsub` line removed | 17: *AUD-06: realmKey() falls back to GetRealmName, spaces removed…*, *AUD-06: a sender Name-ArgentDawn and the local Argent Dawn realm give the same key*, *AUD-06 migration: every roster key rewritten…*, *AUD-06 migration: /dt alts shows the main and the alt once each*, … |
| Migration run-once flag | `if db.keysV == 2 then return end` removed | 1: *AUD-06 migration: runs once per account, not at every load* |
| Nudge officer check | removed | 2: *nudge: no line if not an officer at the time*, *nudge: no line if out of the guild at the time* |
| Nudge "posted since" | removed | 3: *nudge: no line for the first post when a second came since*, *nudge: ...not yet for the second*, *nudge: the second post's own nudge 900 s after it* |
| Held line once per hold | `and not heldSaid` removed | 4: *held line: not for the second queued message*, *… not again while the same hold goes on*, *… not for a command outside lockdown*, *… a new hold prints it again* |
| *(extra)* crypt / gank / stash / played migration flags | each `keysV` early return removed | 1 each: *AUD-06: the crypt / gank / stash / played migration runs once* |
| *(extra)* probe `registered` read | back to `r == true` | 2: *registered (AUD-10): return 0 (Success) -> true*, *… return 1 (DuplicatePrefix) -> true* |

No test had to be strengthened after a removal.

## The audit test (Task 9)

`audit/tests/test_realm_spelling.lua` on `card/dt_prep` `716580b` (card 1 files + Prep): before
**0/2**, after **2 passed, 0 failed**. For information, the other audit tests on the new heads:
death_flood 2/2, gank_reboot 3/3, prep_reload 2/2, roster_reload 5/5, stash_reload 2/2, traffic
5/5.

## Re-cut: `release/0.1.0-rc3` (Task 10)

- Branched from `release/0.1.0-rc2` (`dcaaca4`). Merged, all clean: foundation `b0feeaa`, crypt
  `e9a77c5`, pvp `3dab8c4`, prep `716580b`, stretch `2a43bb7`, logs `9793ec9`.
- `test_together.lua`: *15 verbs, 12 keys, 8 kinds* → *15 verbs, 13 keys, 8 kinds*. Card 1's
  `keysV` is the new top-level key; no two cards share a key.
- `run_all.sh`: core 60, guild 13, comms 88, roster 46, alts 27, welcome 17, crypt 98, gank 62,
  prep 51, recruit 74, stash 85, played 64, events 26, logs 122, together 27. Exit 0, 860 checks.
- Version unchanged (`0.1.0`); only the zip name changed.

### Zips

`tools/package.sh` builds `dist/DeadTired-0.1.0-rc3.zip`, and the rc2 zip was `git rm`'d from
this branch (it stays on rc2). All three zips were rebuilt and committed, then checked from the
commit: unzipped and `diff -r` against their sources minus `tests/`. All three were clean, and
none contains `tests/`.

| Zip | Source | Size | Files |
|---|---|---|---|
| `dist/DeadTired-0.1.0-rc3.zip` | this branch's `DeadTired/` | 45,554 bytes | 19: `DeadTired.toc`, `Config`, `Core`, `Guild`, `Comms`, `Roster`, `Alts`, `Welcome`, `Crypt`, `Gank`, `PrepList`, `Prep`, `RecruitLines`, `Recruit`, `Stash`, `Played`, `EventsList`, `Events`, `Logs` (`.lua`) |
| `dist/DeadTired-0.1.0-card1.zip` | `card/dt_foundation` `b0feeaa` | 15,445 bytes | 8: `DeadTired.toc`, `Config`, `Core`, `Guild`, `Comms`, `Roster`, `Alts`, `Welcome` (`.lua`) |
| `dist/DeadTiredProbe-0.1.0.zip` | `card/dt_probe` `2baa6a9` | 13,202 bytes | 2: `DeadTiredProbe.toc`, `Probe.lua` |

## Every doc line changed

- `tools/package.sh`: the header comment and the build lines name `DeadTired-0.1.0-rc3.zip` (and
  the staging dir `rc3`).
- `docs/LAUNCH_NIGHT.md`:
  - `release/0.1.0-rc2` → `release/0.1.0-rc3` (opening line);
  - step 3's install `dist/DeadTired-0.1.0-rc2.zip` → `…-rc3.zip`;
  - "Swap to the `-rc2` zip" → "`-rc3` zip";
  - added under step 3: *WizardryLogPrompt is retired (9 Nov): card 7's prompt is now the only
    logs prompt.*
- `docs/GUIDE_guildies.md`:
  - "release candidate **0.1.0-rc2**" → "**0.1.0-rc3**";
  - "Download `DeadTired-0.1.0-rc2.zip`" → "`…-rc3.zip`";
  - *What it prints on its own* gains: *for officers, one line when `/dt recruit` is ready again
    after your post (`/dt recruit nudge off` stops it).*
- `docs/ANNOUNCE_discord.md`: `<link to DeadTired-0.1.0-rc2.zip>` → `…-rc3.zip>` (the file is
  still 1,354 bytes).
- **WizardryLogPrompt steps:** none of the three docs on rc3 had a "move it out before walking
  card 7" step, so there was nothing to drop. The only addition is the `LAUNCH_NIGHT.md` line above.
- `grep -n rc2` over the three docs finds nothing.
- **Briefs amended** (each gets an *Amended 2026-11-09 (fix round 3)* note, with changed lines
  marked *(amended, fix round 3)*):
  - `COWORK_BRIEF_dt_foundation.md`: note; the WoWWizardry keying line, the *Lockdown* bullet
    (was *Restricted*), the new *Refused sends* bullet, and the inbound normalisation line marked.
  - `COWORK_BRIEF_dt_crypt.md`: note.
  - `COWORK_BRIEF_dt_pvp.md`: note; step 3's realm line marked.
  - `COWORK_BRIEF_dt_prep.md`: note; a marked *The nudge* paragraph after `/dt recruit next`.
  - `COWORK_BRIEF_dt_stretch.md`: note.
  - `COWORK_BRIEF_dt_probe.md` (on `card/dt_probe`): note.
  - Card 7's brief is unchanged: only the merge touched that branch.

## Choices the brief didn't cover (please rule where it matters)

1. **The held line is for typed commands only.** "A shared command queues something" was read as
   a `/dt` verb the player typed. The router sets `DT.inCommand` while a verb runs. A death
   notice, a login HELLO or an automatic reply sent during lockdown prints nothing, because
   printing for those would be unasked.
2. **`/dt recruit nudge off|on` print nothing.** The brief gives no reply line and says to write
   no other player-facing text, so the toggle is silent, and the `/dt` help still reads
   `recruit [next]`. If you want a reply (e.g. "nudge off."), it needs your wording.
3. **Extra helper `DT.normKey(key)`, and an optional third argument on `DT.migrateKeys`** (the
   stamp field, default `seen`). The played board's entries carry `t`, not `seen`.
4. **Old-spelling keys arriving over the wire are normalised:**
   - a HELLO's `main`;
   - a GANK's `who`;
   - a PREP's or STASH's `to` (compared after `normKey`).

   An rc2 client never sends (it holds for ever), so this mostly matters for mixed versions later.
5. **The stash migration can't really collapse keys.** One realm has one `GetRealmName` spelling,
   so two old keys can't name one character. If a collision ever happened, the entry already
   under the new key would stay, since stash entries have no stamp. No such case exists in a real
   store, so the stop condition was not met.
6. **`comms.sendFailed` is gone**; `sendRefused` replaces it (AUD-10 counts errors as refusals).
7. **The probe's own `ping` still holds on the restricted flag** (`Probe.lua`'s `sendPing`). The
   brief asked only for the `registered` fix there, so it was left alone. On Forever a probe
   `ping` will therefore report *gave up: still restricted*. Worth a line in a later probe round.
8. **The nudge waits 900 s on the session's timer** from the post. It doesn't re-read `time()`
   when it fires.
9. The card branches' `CLAUDE.md` copies are older than `main`'s (R-1, the nudge exception). They
   were not touched; `main`'s is the authority.

## What I copied from `reference/`

Nothing new this round. The guarded reads (`try`/`clean`) already in `Core.lua` were reused.

`docs/UAT_dt_fixes3_results.md` was not written; walking is Tim's.
