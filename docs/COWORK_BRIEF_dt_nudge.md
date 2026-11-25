# Cowork brief: "a newer Dead Tired walks among us", the version nudge (dt_nudge)

You are in `LUCA5G00N/dead-tired-addon`, building in a cloud session. Tim walks the result in game. Read first, in order:
1. `CLAUDE.md` on `main`, and `docs/DECISIONS.md` 0001 and 0002.
2. This brief and its walk-sheet, `docs/UAT_dt_nudge.md`.
3. `DeadTired/Who.lua`: `hello()`, the `DT.on("HELLO")` and `DT.on("WHO")` handlers, `session`, and `DeadTiredDB.who.seen`.

**Draft status:** written 25 Nov 2026, against `main` at `bf431f4` (0.7.0), with 0.7.1, 0.8.0 and the ledger (0.9.0) still to merge ahead of it. It builds **after the ledger is walked and merged** (Tim: briefs may queue, builds may not pile up unwalked). Task 1 re-reads every name above against the tree. A name that's gone is a stop condition.

## Origin
- `claude/43` (24 Nov), auto-update option 4: "An in-addon 'newer version seen' nudge from HELLO versions. It needs a prints-unasked ruling."
- Tim, 25 Nov: brief it, and queue it.
- The evidence for it: the guild runs a mix of versions (`/dt who`), and 0.3.4 showed what an old copy costs: it stayed silent until it was updated.

## Precondition
`main` carries the ledger (0.9.0), walked and merged, and `run_all.sh` is ALL GREEN.

## Depends on
- **CLAUDE.md, quiet by default:** the nudge is a new "prints unasked" line, so **N1 is the ruling it needs**.
- **0001:** the release is a PR, merged by Tim.
- **Card 1's HELLO:** `v` is already sent. **No new message kind and no new field.**

## Rulings: ratify before code (Tim's merge of this brief ratifies N1–N6)
- **N1, prints unasked:**
  - at most one chat line per login, and only when a newer version is seen;
  - `/dt who nudge off` stops it;
  - on by default.
  - The line goes into CLAUDE.md's "Prints unasked" list, in the same PR.
- **N2, what "newer" means:** both versions must match `^%d+%.%d+%.%d+$`, compared number by number. Anything else (a `-rc`, junk, a missing `v`) is ignored, never counted as newer.
- **N3, two witnesses:** the nudge needs **two different guildies' keys** on the same newer version this session. Tim walks unreleased builds, and one walker must never send the whole guild after a version that isn't out.
- **N4, the line:** `A newer Dead Tired (0.9.1) walks among us. Yours is 0.9.0. It's in #dt-crypt-workshop.` It goes through `DT.text` and fits one line at the default chat width.
- **N5, once:**
  - it fires once per login (a `/reload` doesn't repeat it, the way the recruit nudge works);
  - it fires again only for a still newer version;
  - nothing is saved apart from the switch.
- **N6, `/dt who`:** every row on a version newer than yours is marked in the version column, and your own row shows `(update)` once N3 is met. This doesn't print unasked.

## Deliverable
With two pretend guildies on a newer version (Ghost, 0002), one login prints exactly the N4 line once, and `/dt who` marks your row. With one witness, a non-numeric version or the switch off, nothing prints. Offline tests prove each of these.

## Working rules
- Every read of the HELLO's `v` goes through `clean` and the N2 pattern.
- The module switch: Who off means no nudge.
- Outside the guild, nothing.
- A wait over a minute? There isn't one. The nudge is checked when a HELLO lands, plus 10 s so the login HELLOs settle.

## Tasks
1. Re-read the tree: Who.lua's names above, `DT.helloField`, `Ghost.lua`'s HELLO, and the recruit nudge's once-per-login pattern (`Recruit.lua`).
2. `Who.lua`:
   - `DT.versionNewer(a, b)` (N2);
   - the witness count per version (N3);
   - the once-per-login check (N5);
   - the line (N4);
   - the setting `nudge` (bool, default true, label "Nudge me when I'm behind", verb `who nudge on|off`).
3. `/dt who`: the N6 marks.
4. `Ghost.lua`: `/dt ghost say hello <version>` sends a HELLO with that `v`, so a walk can pretend.
   - The debug pretend guildie sends from **two** keys when asked (`/dt ghost say hello 9.9.9 2`), or the walk can't meet N3.
5. Selftest: no new REQUIRED; a HELLO sample with a newer `v` still validates.
6. Tests in `test_who.lua`, covering:
   - N2's table (`0.10.0 > 0.9.9`, `1.0.0 > 0.99.99`, `0.9.0 = 0.9.0`, `0.9.0-rc1` ignored, `nil` ignored);
   - N3 (one witness: silent; two: one line);
   - N5 (a third witness and a `/reload` both stay silent; a still newer version prints once more);
   - the switch off; Who off; outside the guild;
   - N4's text, verbatim and fitted.
7. CLAUDE.md's "Prints unasked" line (N1), `docs/FEATURES.md`, the release notes, and the version (the next patch on `main`).

## Explicitly out of scope
- Any auto-update, download or link-opening. Addons can't, and Blizzard's rules say no.
- A popup, a sound, or anything on screen besides the one chat line and the `/dt who` marks.
- Telling *other* people they're behind, or a list of who's out of date.
- WowUp, CurseForge or a PowerShell updater: options 1–3, not addon code.
- Reading versions from anywhere but HELLO and WHO.

## The one deliberate widening, named
N1 adds a line that prints unasked. It's bounded to one line per login, only when two guildies prove a newer version exists, with a switch to stop it.

## Stop conditions
- HELLO's `v` isn't the plain `DT.VERSION` string on the tree → stop.
- Meeting N3 in a walk would need a second real player online, because the Ghost can't send from two keys without changing the comms core → stop and report. Don't change Comms.lua.
- Any test would need the nudge to send a message → stop. It never sends.

## Guards to prove (remove once, see red, put back)
- the N2 pattern;
- the two-witness count;
- once per login;
- the switch;
- Who off;
- the guild gate.

## Acceptance (the walk-sheet is `docs/UAT_dt_nudge.md`)
| # | Check | |
|---|---|---|
| N-G1 | `/dt debug on`, `/dt ghost say hello 9.9.9 2`, wait 10 s: the N4 line prints once, with 9.9.9 and your version. | [G] |
| N-G2 | `/reload`, then the same again: nothing prints. | [G] |
| N-G3 | `/dt ghost say hello 10.0.0 2`: one more line, for 10.0.0. | [G] |
| N-G4 | `/dt who nudge off`, relog, `/dt ghost say hello 11.0.0 2`: nothing prints. `/dt who` still shows `(update)` on your row. | [G] |
| N-G5 | `/dt ghost say hello 12.0.0` with one key only: nothing prints. | [G] |
| N-H1 | Would the line make you update, or would you tune it out? | [H] |

## Reporting
`docs/COWORK_REPORT_dt_nudge.md` covers:
- the branch and head; counts per suite;
- each guard proof;
- the N4 line as it prints, verbatim;
- how the Ghost sends from two keys (Task 4);
- the zip's name, size and sha256;
- what the brief got wrong.

Never write a `_results.md`.
