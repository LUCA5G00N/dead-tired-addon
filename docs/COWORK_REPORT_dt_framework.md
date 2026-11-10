# Cowork report: DEAD TIRED framework (0.2.0-fw1): **stopped at Task 2**

Brief: `docs/COWORK_BRIEF_dt_framework.md` (ratified 2026-11-10). Session date: 2026-11-10.
**Status: halted on a stop condition** (*"a library ... its licence doesn't allow bundling → stop"*).
No addon code was written, no library was committed, no zip was built. Walk-sheet: not walkable.

## The stop, in one paragraph

LibDataBroker-1.1 has no licence that grants bundling. Its source has no licence file or notice,
and its WowAce project page gives the licence as **"All Rights Reserved"**. The author's own project
text tells addon authors to *"hard-embed LDB in your addon"*. Whether that sentence counts as the
"explicitly stated" exception to "All Rights Reserved" is a licensing call, and the brief keeps that
call for Tim (FEATURES.md: *"LibDataBroker-1.1: licence unclear: confirm before the first release"*).
LibDBIcon-1.0 requires LibDataBroker-1.1, and the launcher bar is an LDB host, so without it Tasks 2,
7 (in part), 8 and 10's LDB count can't be built as briefed. I stopped instead of guessing.

### LibDataBroker-1.1: everything the sources say, quoted
| Source | What it says |
|---|---|
| `github.com/tekkub/libdatabroker-1-1` (the primary repo, per the WowAce page), HEAD `1a63ede`, tag `v1.1.4`, minor 4 | Two files, `LibDataBroker-1.1.lua` and `README.textile`. **No licence file**, and no licence or copyright line in either file |
| The repo's wiki (`libdatabroker-1-1.wiki.git`: API, Data-Specifications, Home, How-to, Addons-using-LDB) | No mention of a licence |
| WowAce project page, `wowace.com/projects/libdatabroker-1-1` (project 20113, created 21 Jul 2009, last file 22 Jul 2009) | Sidebar: **"License: All Rights Reserved"**. The licence modal (`/project/20113/license`) in full: **"All Rights Reserved unless otherwise explicitly stated."** |
| The same page, project description (the author's words) | *"You can find LDB's primary repo and it's documentation on GitHub ... Note to addon authors: If you have a .pkgmeta, Do not use an embed entry for LDB if you allow no-lib packages, your no-lib versions will not include LDB in them. **Instead you should hard-embed LDB in your addon** and add a "tools used" entry for "libdatabroker-1-1"."* |
| `repos.wowace.com/wow/libdatabroker-1-1` (git) | The same two files, same commits as GitHub; no licence |
| The copy inside LibDBIcon's trunk (`LibDBIcon-1.0/LibDataBroker-1.1/`) | Byte-identical to GitHub's file |

### What Tim needs to rule (one question)
**Does the author's "you should hard-embed LDB in your addon" count as the permission, given the
page's "All Rights Reserved unless otherwise explicitly stated"?**
- **Yes:** the next session vendors LDB with a `Libs/LibDataBroker-1.1/NOTICE.md` quoting the page
  and the author's sentence, and carries on from Task 2. Everything below is already sourced.
- **No:** the bar and LDB objects need a rethink (LibDBIcon needs LDB too). Options, for the ruling:
  ask the author (tekkub) for a licence line; or DT keeps its own launcher registry with no LDB, and
  the "show other addons' launchers" and Titan stand-back parts of the bar are dropped.

## Task 1: baseline (done)

- **Branch.** The brief names `card/dt_framework`. This cloud session can push only to its own
  branch, **`claude/hopeful-thompson-4rpsrp`** (made from `main` at `97ec890`), so this report is
  there. No addon code on `main` (confirmed: no `DeadTired/` folder). Rename or re-branch when the
  round resumes.
- **lua5.1:** not installed; installed with `apt-get install -y lua5.1` (Lua 5.1.5). Nothing was run
  with it yet.
- **Network.** WowAce and CurseForge were blocked here. With Tim's approval a personal environment,
  `dead-tired-addon`, was created and this session moved onto it: GitHub plus `www.wowace.com`,
  `repos.wowace.com` and `www.curseforge.com`. (CurseForge still answers 403 to scripts; WowAce
  answers, and was enough.) Later sessions on this repo can use that environment.

### G2: rc3's taint cause: **confirmed**, with one more finding
`release/0.1.0-rc3` (`6754f20`), `DeadTired/Core.lua:303-306`:
```lua
SLASH_DEADTIRED1 = "/dt"
SLASH_DEADTIRED2 = "/deadtired"
SlashCmdList = SlashCmdList or {}          -- line 305
SlashCmdList["DEADTIRED"] = function(msg) return DT.dispatch(msg) end
```
`SlashCmdList` always exists when an addon loads, so line 305 is in effect `SlashCmdList = SlashCmdList`:
it writes Blizzard's global from addon code. The value doesn't change, but the variable is now
tainted. Every secure Blizzard path that reads `SlashCmdList` afterwards (the chat edit box's
slash parsing, which runs `/run` and `/invite`) runs tainted, and protected actions inside it fail.
The allow-scripts confirmation for `/run` is one of them. This matches what the walk saw (Liliac's
blocked prompt) and the brief's diagnosis.

Two more things, for the record:
1. **rc3 `Played.lua:66-68`** places `hooksecurefunc(SlashCmdList, "PLAYED", ...)`. That's
   `hooksecurefunc`'s intended use and doesn't taint `/played` on its own, so it isn't the
   cause. It does break this brief's rule (no hook on slash code), so the rebuild won't carry it.
2. **The same line is in Wizardry.** `reference/wizardry/Forever/Core.lua` ends with
   `SlashCmdList = SlashCmdList or {}`. rc3 copied it from there. **For H5:** if Tim runs
   WizardryLedger alongside fw1, Wizardry alone will still taint `/run` and `/invite`. Walk H5 with
   Wizardry disabled, or fix Wizardry the same way first (outside this repo; `reference/` is
   read-only here). Liliac's test is the clean one if Liliac doesn't run Wizardry.

## Task 2: the libraries (stopped)

Fetched for inspection only, into the session's scratch space. **Nothing committed.** The table
records what the next session should vendor, so the round can resume quickly.

| Library | Source (canonical) | Version / commit | Licence (from the source) | Bundling |
|---|---|---|---|---|
| LibStub | `github.com/WoWUIDev/Ace3`, `LibStub/` | Ace3 HEAD `ac3d122` (21 commits past `Release-r1403`; those commits touch AceDB/AceGUI/AceTab/toc only); LibStub minor 2 | Public domain (LibStub's own notice) / Ace3 `LICENSE.txt` | OK |
| CallbackHandler-1.0 | Ace3, `CallbackHandler-1.0/` | minor 8 | Ace3 BSD-style (`LICENSE.txt`, quoted below) | OK (not as a standalone release) |
| AceComm-3.0 | Ace3, `AceComm-3.0/` | minor 14 | Ace3 BSD-style | OK |
| ChatThrottleLib | Ace3, `AceComm-3.0/ChatThrottleLib.lua` | `CTL_VERSION = 32` | Public domain (file header) | OK |
| LibSerialize | `github.com/rossnichols/LibSerialize` | tag `v1.2.3` = HEAD `aa6e50d`; minor 7 | MIT (`LICENSE`) | OK |
| LibDeflate | `github.com/SafeteeWoW/LibDeflate` | tag `1.0.2-release` (HEAD `afc3b78` is 53 commits past it) | zlib (`LICENSE.txt`) | OK |
| LibDBIcon-1.0 | WowAce page names `repos.wowace.com/wow/libdbicon-1-0/trunk` (svn) | r168 (last change r167, 21 Oct 2026, funkehdude); minor 57 | WowAce page: "Ace3 Style BSD", same text as Ace3's licence | OK, **but it requires LibDataBroker-1.1** |
| LibSharedMedia-3.0 | WowAce page names `repos.wowace.com/wow/libsharedmedia-3-0/trunk` (svn) | r186 (9 Nov 2026, elkano); minor 12000005 | File header: **"License: LGPL v2.1"**. WowAce page: "All Rights Reserved unless otherwise explicitly stated" (the file states LGPL explicitly) | OK as its own unmodified file, with the LGPL 2.1 text alongside. Flagged: the page and the file disagree |
| **LibDataBroker-1.1** | `github.com/tekkub/libdatabroker-1-1` | `v1.1.4` = `1a63ede`; minor 4 | **None in the source; WowAce: "All Rights Reserved"** | **Stop: Tim rules** |

The Ace3 licence (applies to CallbackHandler, AceComm, and LibDBIcon "Ace3 Style"), as in
`Ace3/LICENSE.txt`: *"Copyright (c) 2007, Ace3 Development Team. All rights reserved.
Redistribution and use in source and binary forms, with or without modification, are permitted
provided that ... Redistributions of source code must retain the above copyright notice ... Redistribution of a
stand alone version is strictly prohibited without prior written authorization from the Lead of
the Ace3 Development Team ..."*. Bundling inside DT is fine; shipping Ace3 on its own is not.

### Found while reading ChatThrottleLib (for Task 5, not acted on)
ChatThrottleLib v32 keeps and retries a message only when the result is
`AddonMessageThrottle` (3). That retry has no limit: the message moves to a blocked ring until the
throttle lifts. Any other non-success result drops the message and passes `didSend = false, sendResult`
to the caller's callback (`Despool`, lines 397-427). It doesn't read `InChatMessagingLockdown`.
So AUD-10 (3 tries, then drop and count) and R-1 (hold in lockdown) look buildable **on top**, in
DT's gate and AceComm's per-chunk callback, with no change inside the library. Two open points for
that round: the unlimited retry on result 3 differs from AUD-10's 3-try cap, and that cap needs
DT to see each chunk's result. This is for the resumed round to prove, not a finding of this one.

## Tasks 3-13
Not started (halted at Task 2). No pieces, checks, guard proofs, zip or player-facing lines to
report. **Player-facing lines added: none.**

## What's on the branch
This report only. `reference/` and rc3 were read, not touched. No `_results.md` written.

## To resume
1. Tim rules on LibDataBroker-1.1 (the question above).
2. If yes: start a session on the `dead-tired-addon` environment, on the brief as written, from
   Task 2. Use the sources and revisions in the table, add LDB's `NOTICE.md`, and put the H5 note
   (Wizardry's same line) in the walk.
