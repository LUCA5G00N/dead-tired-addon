# Decisions — dead-tired-addon

Rulings that govern how this addon is built, released and walked. Format: the L5GN-Tools
convention `docs/CONVENTION_decisions.md` (an entry is a metadata line, Context, Decision,
Consequences and What would show this wrong; append-only once accepted; drafted `proposed`,
ratified by Tim on a later day).

**Where the earlier rulings are.** Rulings before this log (R-1, R-F4-1, the card rulings such as
`dt_crypt` R1 or `dt_pvp` R1, the library and taint rulings) live in the briefs in `docs/` and are
summarised in `CLAUDE.md`. They are **not recovered here**: this log starts on 2026-11-22 with the
first rulings made after the move to branch-and-PR releases. A bare number below means this log;
a number from another repo carries the repo's name (`dead-tired-bot-0001`).

---

## 0001 — A release is a PR Tim has walked and merged: Claude builds on a `claude/` branch, Tim's merge is the go-ahead, the Release workflow publishes, and Claude never merges, pushes to `main`, force-pushes or deletes a tag or release

**Date:** 2026-11-22 · **Status:** proposed · **Source:** release-process thread, Fri 20 Nov 2026
(R1–R6 agreed 19:16; project doc `claude/28_release_process_proposal_2026-11-20.md`), and PR #20
(the Release workflow) · **Relates to:** `dead-tired-bot-0001` (the same flow for the bot)

### Context
Until 20 Nov, Tim did the git and the publishing: Claude built in a working tree, Tim committed,
tagged, zipped and published by hand, and every addon brief's out-of-scope list said "publishing
the release (Tim's)". With the repo on GitHub and a cloud session able to push branches, the hand
steps were the slow part of every round, and a mis-zipped release was possible each time.

On 20 Nov Tim asked Claude to take the building and publishing, keeping the review and merge for
himself. R1 as agreed that evening had **Claude** tag and publish after the merge. PR #20
(merged 21 Nov) moved that step into `.github/workflows/release.yml`, so in force today the
**workflow** publishes, not Claude. This entry records the flow as it now runs.

### Decision
1. Claude builds each round on a branch named `claude/<slug>` and opens a pull request against
   `main` carrying the brief's report, the test counts and the walk-sheet.
2. **Tim walks the sheet in game and merges.** The merge is the go-ahead to publish (R1).
   Nothing is published from an unmerged branch.
3. Publishing is done by the Release workflow on the push to `main`: it publishes `vX.Y.Z` only
   when the `.toc` version has no release yet, and only after its checks pass (`.toc` and
   `DT.VERSION` agree, every suite green, the zip in `dist/` matches the source, release notes in
   `docs/RELEASE_X.Y.Z.md` exist). A merge that leaves the version alone publishes nothing.
4. Claude drafts the #dt-crypt-workshop release post inside the PR. Tim reviews it with the code
   and pastes it after the release (R2). Claude's Discord access is read-only.
5. Claude never merges its own PR, never pushes to `main`, never force-pushes, and never deletes a
   tag or release unless Tim asks (R4). A bad release is fixed forward with a new patch version.
6. Claude never writes `docs/UAT_<slug>_results.md`; the results log is Tim's (house rule,
   restated here because the PR flow puts Claude next to it).
7. PRs are not stacked: each PR targets `main` directly. (Learnt from bot PRs #2 and #3, which
   merged only into their base branches; see `dead-tired-bot-0001`.)

### Consequences
- Each release now needs a version bump in two places and a release notes file before merge, or
  the workflow refuses. That is extra ceremony on a one-line hotfix (0.3.4 paid it).
- Tim no longer sees the zip before it goes out; he sees the source. A zip that is wrong in a way
  the workflow's `diff` check does not catch would ship. The check is the only guard.
- Docs-only merges (briefs, this log) release nothing, which is intended but means a doc change
  never reaches players through the release page.
- The walk is still the bottleneck, and nothing here shortens it; 0002 is the attempt.
- Clause 3 depends on GitHub Actions being available and the repo's `contents: write` permission
  staying granted. If either goes, publishing falls back to hand steps nobody has rehearsed since
  0.3.1.

### What would show this wrong
- Count releases from 0.3.2 onward whose published zip differs from the tagged source, or that
  needed a fix-forward patch for a packaging fault (not a code fault). **Zero** across the next five
  releases vindicates the workflow-publishes clause; **one or more** means the check is too weak
  and the clause needs a human look at the zip again.
- Count PRs on this repo merged by anyone other than Tim, or pushes to `main` not from a merge.
  Any non-zero count is a breach of clause 2 or 5.
- If the median time from "PR opened" to "release published" over the next five releases is not
  shorter than 0.3.1's hand-release turnaround, the flow bought nothing but ceremony.

---

## 0002 — Walks get shorter by moving checks to the machine: an in-game self-test and a debug-only pretend guildie; the walk stays Tim's; Claude never drives the game client

**Date:** 2026-11-22 · **Status:** proposed · **Builds on:** 0001 (Tim walks and merges; the
walk is the go-ahead) · **Source:** release-process thread, Fri 20 Nov 2026 (U1–U7 agreed 19:21;
project doc `claude/28_release_process_proposal_2026-11-20.md`)

### Context
With 0001 in place, UAT is the slowest step of every round: Tim transcribes [H] checks by hand,
and every shared feature (deaths, Who, stash, ganks) waits until a second guildie on the new
version is online at the same time. P1 and H4 have been open since 0.3.2 for exactly that reason.
The realm-blank incident of 21 Nov (DT silent on client build 71037) was found by a player, not by
any check.

### Decision
1. **U1, self-test.** The addon gains `/dt selftest`, which runs its own checks in the real client
   (APIs present, windows build, text fits, switches silence modules, saved data migrates) and
   writes a pass/fail report into `DeadTiredDB`. Tim runs it and `/reload`s; Claude reads the
   result from the WTF folder. Checks the self-test covers become [G] on walk-sheets.
2. **U2, pretend guildie.** A debug-only loopback feeds the addon messages as if from a fake
   guildie (deaths, Who replies, stash answers, gank entries). It is off unless debug is on, is
   never saved, and never sends anything on the wire. Shared checks use it; a real second player
   is required only for a round that changes the messaging itself.
3. **U3, screenshots.** Tim's existing screenshot sync (with in-game marks and comments) is the
   evidence channel for checks judged by eye; Claude reads it through folder access.
4. **U4, short walk-sheets.** [H] checks only for what the round changed and what only an eye can
   judge (looks, wording, feel). Everything else is [G] or covered by the self-test. In force from
   0.3.3's sheet.
5. **U5.** Two builds that do not overlap may be walked in one sitting, when it fits.
6. **U6, long term.** Volunteer "crypt testers" (a role and test zips in #dt-crypt-workshop) are
   agreed in principle; nothing is built for it until a brief asks.
7. **U7, refused.** Claude does not drive the game client: no computer use and no scripts playing
   the game. It risks Blizzard's automation rules. In-game hands stay Tim's.
8. U1 and U2 are built together in one round, before the Waypointer.

### Consequences
- The self-test and the loopback are code that ships to every guildie, debug-gated or not. They
  are surface area: a bug in either is a bug players can hit, and the loopback is a path into the
  same handlers real messages use. Clause 2's "never sends" and "off outside debug" must be
  guard-proved, not assumed.
- A self-test proves the addon agrees with itself in one client on one character. It cannot prove
  two real clients talk to each other; the loopback cannot catch a wire-format or AceComm fault.
  Clause 2's exception for messaging rounds is where that risk is paid.
- Shorter sheets mean fewer things are looked at by a person each round. Something the self-test
  does not cover and the round did not change will go unlooked-at longer.
- U7 keeps the slowest step slow on purpose.

### What would show this wrong
- Over the next three addon rounds after U1/U2 ship, count [H] checks per walk-sheet against the
  0.3.2–0.3.4 sheets. If the count does not fall by at least a third, the self-test is not
  absorbing checks and clause 1 is not paying for itself.
- Count bugs found by a guildie in a released build that the self-test or loopback was meant to
  cover. Any such bug in a covered area means the check is decorative and must be strengthened.
- If a messaging change released after a loopback-only walk breaks between two real clients, the
  line in clause 2 is drawn in the wrong place.
- Any report of DT sending a message, or printing, because of the loopback outside debug is a
  breach of clause 2.
