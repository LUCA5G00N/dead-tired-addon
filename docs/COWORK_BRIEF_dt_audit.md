# Cowork brief: DEAD TIRED independent audit (every card, before launch)

Read first, in order:
1. `CLAUDE.md` (house rules and *Ruled exceptions*).
2. This brief and its walk-sheet, `docs/UAT_dt_audit.md`.
3. Each card's **brief** and **code** on its branch (list below). **Do not read the card reports
   (`docs/COWORK_REPORT_*.md`) until Task 4.** You are the second pair of eyes: form your own view
   from the brief and the code first, then compare.
4. `reference/SPEC_forever_namespaces.md` (search it) and `reference/wizardry/` for the patterns
   the cards copied.

**Draft-status: ratified by Tim 2026-11-02.** Launch is Wed 2026-11-04, 11pm UK; no card has been
walked in game.

| Card | Branch | Module files |
|---|---|---|
| 1 `dt_foundation` | `card/dt_foundation` | `Config`, `Core`, `Guild`, `Comms`, `Roster`, `Alts`, `Welcome` |
| 3 `dt_crypt` | `card/dt_crypt` | `Crypt` |
| 4 `dt_pvp` | `card/dt_pvp` | `Gank` |
| 5 `dt_prep` | `card/dt_prep` | `PrepList`, `Prep`, `RecruitLines`, `Recruit` |
| 6 `dt_stretch` | `card/dt_stretch` | `Stash`, `Played`, `EventsList`, `Events` |
| 7 `dt_logs` | `card/dt_logs` | `Logs` |
| probe | `card/dt_probe` | `DeadTiredProbe/Probe.lua` (lighter pass: Task 3 only) |

## Origin

Every card was built and tested by the session that wrote it. Their offline suites are green, but
a builder checking its own work shares its own blind spots. The review of 2026-11-02 asked for an
independent audit before anything is walked or merged.

## Precondition

- P1: every branch above exists, and each card branch's `DeadTired/tests/run_all.sh` exits 0
  (record the counts).

## Deliverable

`docs/AUDIT_2026-11-02.md` on branch `audit/2026-11-02`: a ranked list of findings across all
cards, each with severity, file and line, what goes wrong in game, the evidence, and a suggested
fix. Every finding at *high* or above has a **reproducing offline test** (red now) in
`audit/tests/`, or says plainly why it can't be reproduced offline. **No addon code is changed.**

## What to look for

Ranked roughly by how much it would hurt on launch night.

1. **Rule breaks.** Anything against `CLAUDE.md` not covered by *Ruled exceptions*, or a ruled
   exception used wider than its ruling: combat data, public chat, unasked prints, personal data
   without opt-in, anything happening outside the guild, reading another player beyond card 4 R1.
2. **Lua errors in the real client.** Code paths the stubs can't reach: nil from a game call that
   the stub always answers, secret values reaching string operations or comparisons, `#` on
   tables with holes, string patterns with unescaped user text, timers firing after a module's
   state is gone, events arriving before `PLAYER_LOGIN`, `DT.db()` used before
   `ADDON_LOADED`.
3. **Secure-frame and taint risks** (card 7, probe): attributes set in combat, frames shown or
   hidden in combat, anything that could taint Blizzard UI or trigger `ADDON_ACTION_BLOCKED`.
4. **Guild-channel traffic.** With 20 members online running every card: messages sent at login
   and per hour, whether card 1's throttle (bucket 5, refill 1/s) and restricted-hold queue
   (cap 50) hold, whether any card's replies can multiply (one message causing many), and whether
   the queue can drop something important. Write a simulation in `audit/tests/` and report the
   numbers.
5. **Input from guildies.** Every received message kind on every card: malformed, oversized,
   duplicated, out of order, from a non-member, from yourself (the channel echoes). Escapes
   (`|`) reaching the chat frame. A guildie able to make your client print, store or send
   something it shouldn't.
6. **SavedVariables growth.** Every table that grows: is it capped, and what does a year of play
   look like?
7. **Cross-card collisions** (the cards were built apart): `/dt` verbs, `DeadTiredDB` keys, comms
   message kinds, error keys, event handlers that could conflict once all are loaded together.
8. **Live-client assumptions** that the probe won't answer: list them so Tim knows what the walk
   is really testing.
9. **Test quality.** A guard proved red by a test that would pass for the wrong reason; a check
   whose name says more than it asserts.

## Working rules

- Read-only on every card branch. Write only on `audit/2026-11-02` (branched from `main`), under
  `audit/` and `docs/`.
- Reproducing tests load the card's real files from a checkout of its branch (use
  `git worktree` into a scratch directory), with stubs in the house style. They live in
  `audit/tests/test_<area>.lua`; `audit/tests/README.md` says how to run each.
- Severity: **blocker** (breaks a house rule, or a Lua error or broken feature on a normal path),
  **high** (wrong behaviour players will hit), **medium** (edge case, or a cost that grows),
  **low** (tidiness, wording). Don't inflate: a finding you can't show is *medium* at most and
  says so.
- Be specific: file, line, the sequence of events, what the player sees.
- Praise nothing, summarise nothing the reports already say. Findings only, plus the traffic
  numbers.

## Tasks

1. **Branch and baseline.** Create `audit/2026-11-02` off `main`. Run every card's `run_all.sh`
   and the probe suite; record counts.
2. **Read and audit cards 1, 3, 4, 5, 6, 7** against *What to look for*, briefs and code only.
3. **Probe, lighter pass:** rule breaks, Lua errors, secure-frame risks only.
4. **Then read the reports**, and add a column to your findings: *already known to the report?*
   (yes / partly / no). A finding the report already flagged and Tim already ruled on is dropped
   unless you think the ruling is wrong, in which case say why.
5. **Traffic simulation** (item 4) in `audit/tests/test_traffic.lua`: 20 clients, all cards'
   modules loaded together (merge the module lists in the test; don't merge branches), a login
   wave, an hour of normal use. Report messages per minute, peak queue length, anything dropped.
6. **Reproducing tests** for every blocker and high.
7. **Write `docs/AUDIT_2026-11-02.md`:** a summary table first (id, severity, card, one line,
   known?), then each finding in full, then the traffic numbers, then *live-client assumptions*.
8. **Push** `audit/2026-11-02` (or the session branch, said at the top of the audit).

## Explicitly out of scope

- Fixing anything. Suggested fixes are text in the audit; fixes come in a later round Tim rules.
- Merging any branch, or changing any card branch.
- Style preferences that change no behaviour (unless *low*, and few).
- Re-deciding rulings Tim made, except to say why you think one is wrong (Task 4).
- Card 2 (not built).

## Stop conditions

- A card branch's suite fails at baseline (P1) → stop and report which.
- Auditing needs a change to a card branch → stop.

## UAT: acceptance checks

In `docs/UAT_dt_audit.md`.

## Reporting

The audit document is the report. At its top: branch heads audited, baseline test counts, and the
number of findings per severity. Never write a `_results.md` file.
