# Cowork report: DEAD TIRED fix round 4 (`dt_fixes4`, 0.3.1)

**Branch: `claude/sleepy-knuth-z4fo3c`** (this session can push only to its own branch; the brief
allows it). Branch point: `main` at `3fbb61f` (merge of the brief, ratified 12 Nov 14:26; `4637b47`
+ the brief and walk-sheet, so the brief's file and line references held). New head: see the
commit this report is in. Nothing merged to `main`; Tim merges after his walk. No `_results.md`
written.

**Outcome:** every task done. No stop condition hit. **Follow-ups (Tim, 12 Nov, same branch):**
(1) Task 11's *What every module must do* is now in `CLAUDE.md`, with the fourteen rules as Tim
gave them (the design note itself is not in this repo); (2) Tim's ruling that the sharing toggle
always withdraws: `Played.lua`'s `shareChanged` sends the withdrawal and removes your own entry
even while Played is off (Task 9, the ruling section below). Report, guard table and zip updated. `run_all.sh`: **ALL GREEN, 26 suites, 1319 checks** (baseline 25 suites, 1136).
**109 guards proved** (0.3.0's 74, one of them replaced because R-F4-1 reverses it, plus 35 new),
every file restored byte for byte; two of the new ones needed their tests strengthened (test
files only, diff below). `dist/DeadTired-0.3.1.zip`: 174,053 bytes, `diff -r` clean.
Nothing was copied from `reference/` this round.

## Task 1: baseline (G1)
`apt-get install -y lua5.1` (5.1.5; `luac5.1` with it). `sh DeadTired/tests/run_all.sh` at `3fbb61f`:
**ALL GREEN, 25 suites, 1136 checks**, libraries unmodified. That matches the walk log's count at
`ef2a768`.

| Suite | Baseline | Final |
|---|---|---|
| alts | 28 | 28 |
| bar | 78 | 82 |
| comms | 46 | 46 |
| core | 37 | 37 |
| crypt | 98 | 103 |
| debug | 10 | 26 |
| events | 31 | 40 |
| eventslist | 4 | 4 |
| gank | 71 | 82 |
| guild | 20 | 20 |
| keys | 29 | 29 |
| logs | 123 | 140 |
| migrate | 53 | 63 |
| played | 62 | 86 |
| prep | 47 | 47 |
| recruit | 94 | 104 |
| recruitlines | 7 | 7 |
| session | 9 | 9 |
| settings | 33 | 33 |
| settingsview | 28 | 31 |
| skins | 22 | 29 |
| stash | 86 | 101 |
| taint | 34 | 34 |
| textfit | (new) | 8 |
| ui | 50 | 92 |
| who | 36 | 38 |
| **total** | **1136** (25 suites) | **1319** (26 suites) |

Final run at the head: ALL GREEN, `libs: unmodified (SHA256SUMS)`.

Existing checks changed because this round changes the contract they tested (none dropped to get green):
- `test_ui`: `rowHeight: the tallest cell plus padding` and `rowHeight: never under the minimum` removed
  with `DT.rowHeight` (rows no longer grow); `rows: a long cell makes its row taller` became
  `R-F4-1: a long cell doesn't make its row taller: every row one height`. The list-view test's one
  column became `flex = true` (a list now needs exactly one).
- `test_who`: `rows: a wrapped name makes its row taller` became three R-F4-1 checks (one line, cut
  with "…"; every row one height; the full name in the tooltip after the list's own lines).
- `test_skins`: `two skins ship` → three; `the default skin is deadtired` → `clean`.
- `test_settings`: the bad-skin reply lists `clean, deadtired, forever`. `test_settingsview`: the
  choice button starts at `clean` and cycles to `deadtired`.
- `test_core`, `test_who`: the version reads `0.3.1`.
- `test_crypt`, `test_events`, `test_gank`, `test_played`, `test_stash`: the closing line is checked
  on `vp.footer` (the viewport's) instead of the module's own `vp.note`. `test_crypt`'s full-date
  tooltip check finds the date among the module's own lines (a cut cell's text now follows them).
- `harness.lua`: text metrics are font-aware (half the font's size a character, the size a line;
  no font set: 6 px and 12 px, as before), count UTF-8 characters rather than bytes, and a string
  with word wrap off is one line. The whole tree stayed green with only that change before any addon
  code changed.

## Task 2: the text helper (`UI.lua`)
`DT.text(parent, kind, opts)` is the only caller of `CreateFontString` in `DeadTired/` (tests
excluded): `grep -n CreateFontString DeadTired/*.lua` shows `UI.lua` only (a comment at 15, the
measuring string at 90, `DT.text` at 188). Kinds `line` (word wrap off, a stated width, text set
through `DT.fitLine`), `block` (word wrap on, bounded; `DT.textHeight` gives the height and records
it as the box), `label` (one line, unbounded). Each string is fonted through the skin (`DT.fontTo`)
and re-fitted by its own painter when the skin changes, except `fixedFont = true` (the two log
dialogs, and the game's Settings page stub: question 5). Each is recorded (`DT.texts`: window id
from the nearest parent's `dtWindow`, kind, role, width, box) for Task 5.

`DT.measure(text, role)` uses one hidden string per font role (under one hidden frame), fonted
from the current skin at each call, read with `GetStringWidth` under `pcall`. A non-number, a secret,
or a width <= 0 for non-empty text is counted under `DeadTiredDB.errors["ui:measure"]` and `nil`
returned; `DT.fitLine` then treats the text as fitting. `DT.fitLine(text, width, role)` returns the
text unchanged when it fits, else the longest prefix that fits with `…` after it (binary search
over cut points), trailing spaces dropped before the `…`. Cut points fall after whole UTF-8
characters and never inside an escaped `||`. The text calls used: `GetStringWidth`, `SetWidth`,
`SetWordWrap` (only where the string has it), `GetStringHeight`. No `IsTruncated`, no `SetMaxLines`.

### Every text site in 0.3.0 and what it became
| 0.3.0 site | What it is | Now |
|---|---|---|
| `UI.lua:119` | viewport title | `line`, title role, `width - pad - 40` (ends left of the close button) |
| `UI.lua:227` | list empty-state line | `block`, `width = total - 8`, box from its height |
| `UI.lua:240` | list cells | `line`s at the column's width |
| `UI.lua:335` | toast text | `block`, 260 wide; the toast's height from it (never under 0.3.0's 44) |
| `Crypt.lua:175` | graveyard closing note | viewport `footer` (`block`, small, muted) |
| `Gank.lua:203` | Grudges closing note | viewport `footer` |
| `Played.lua:160` | Glacial Progress closing note | viewport `footer` |
| `Who.lua:154` | Who note | viewport `footer` |
| `Stash.lua:288` | Who has it closing note | viewport `footer` |
| `Events.lua:86` | "Times are server time." | viewport `footer` |
| `Logs.lua:171` | log dialog title | `block`, `fixedFont` (GameFontNormal), `width - 40`, centred |
| `Logs.lua:174` | log dialog status | `block`, `fixedFont` (GameFontHighlightSmall), `width - 40`, centred |
| `Bar.lua:282` | bar button text | `label`, small role, inset 22 (the icon) |
| `SettingsView.lua:84` | a list row's drag grip "=" | `line`, 14 wide, centred |
| `SettingsView.lua:113` | a list row's label | `line`, `textWidth() - x` (as before) |
| `SettingsView.lua:296` | a module's title on its card | `line`, title role, the content's width |
| `SettingsView.lua:304` | a setting's label | `line`, `textWidth()` |
| `SettingsView.lua:308` | a setting's description | `block`, `textWidth()` |
| `SettingsView.lua:313` | a setting's `/dt set` hint | `block`, `rowWidth()` |
| `SettingsView.lua:319` | a list card's empty line | `block`, `textWidth()` (had no width in 0.3.0) |
| `SettingsView.lua:359` | the game's Settings page stub title | `line`, `fixedFont` (GameFontNormalLarge), 200 (its button's width) |

New: `UI.lua:90`, the hidden measuring string (one per role; not drawn, not recorded). Text DT
doesn't create: the labels of template buttons (`UIPanelButtonTemplate`: the log dialogs' buttons,
the settings view's choice and Remove buttons, the stub's button) and the search box's edit text;
question 6.

No window size, title, column order or 0.3.0 line changed. The settings view's layout is the same
(each card measured from its label, description and hint as before); the bar's buttons are still
`24 + text width` wide.

## Task 3: lists (`DT.list`)
Cells are `line`s. A column is `fixed = true` (`ceil(widest DT.measure over every row in the model) +
2`, re-measured when the model's rows change or the skin changes), `width = n`, or `flex = true`
(the list's declared width, from the viewport's `body.dtWidth = width - 2 * pad`, or `opts.width`;
never a layout read; no declared width raises). Not exactly one flex column raises. Rows are one
height (`spacing.row`, 18). Left 4, gap 6, right 4. A cut cell's full text goes in the row's
tooltip after the module's own lines; a list with no `tip` shows a tooltip only for a cut row.

Measured under the harness (6 px a character at body 12, so wider than Friz Quadrata in game), with
a fixture holding a death on `12 Nov`, one on `9 Nov`, a grudge, two played entries, two Who
entries and the event list, `clean` skin (the three skins share body fonts, so the same on all):

| List | Declared width | Columns (kind, width px) |
|---|---|---|
| Graveyard (`Crypt.lua`) | 412 | day fixed 38, name static 160, lvl fixed 14, zone flex 174 |
| Grudges (`Gank.lua`) | 492 | n fixed 14, name static 130, what fixed 68, by static 100, last flex 104, day fixed 38 |
| Glacial Progress (`Played.lua`) | 392 | n fixed 14, name flex 142, rateText fixed 68, lvlText fixed 50, hoursText fixed 86 |
| Who (`Who.lua`) | 352 | name flex 232, v fixed 32, when fixed 68 |
| Who has it (`Stash.lua`) | 392 | holder static 130, items flex 248 |
| Events (`Events.lua`) | 412 | name static 190, when flex 208 |

The brief's table, column for column. Other `DT.list` callers: **none**. Prep draws no list, and the
settings view's list cards are its own rows, not `DT.list`.

## Task 4: footers, dialogs, toasts, titles
`DT.viewport{ footer = "<text>" }` makes a `block` at `BOTTOMLEFT (pad, 6)`, `width - 2*pad` wide;
the body's bottom is `pad + ceil(measured height)`, recomputed by the viewport's painter when the
skin changes. A number as `footer` raises (`DT.viewport: footer takes text`). The six hand-made
`note` strings are gone. The toast's text is a `block`; the toast is `max(44, height + 24)` tall,
set at every show and on a skin change. The log dialogs: title and status are `fixedFont` blocks,
the dialog is `14 + title + 8 + status + 22 + 24 + 14` tall (0.3.0's 104 for one line of each),
`SetSize` once in `frame()`; the buttons keep their 0.3.0 anchors (`BOTTOMLEFT x, 14`), so they sit
below. A dialog is only built from `showLogin`/`askInstance` after their in-combat check, and from
`fit` only out of combat. The login dialog's status is sized at creation for its state line
(`combat log OFF    chat log OFF`, one line in 388 px). In the harness the instance dialog's status
wraps to two lines and the dialog is 118 tall; the login dialog is 106 (the harness's 12 px lines; GameFontHighlightSmall is smaller in game). Checks in `test_logs`.

## Task 5: `/dt debug fit`
`Debug.lua`'s verb prints `DT.fitCheck()` (`UI.lua`). Every module with a window declares `fit`:
crypt, gank, played, who, stash, events (their viewport, built if needed, filled with current data,
refreshed, not shown), settingsview (the settings viewport, laid out), logs (both dialogs, out of
combat only), ui (the toast, with the test line), bar (built hidden if absent, refreshed). A
switched-off module's `fit` is skipped. Each `fit` runs under `pcall`, failures counted under the
module's key. Then for each skin in `DT.skins` (sorted) `DT.fitSkin` is set (read by `DT.skinName`
before the saved choice), `DT.restyle()` runs every painter, the records are checked; at the end
`DT.fitSkin = nil` and a restyle. Nothing is written: the saved `core.skin` is never read for it,
no `DT.set`, no setting signal (G7 checks). Output under the harness with the fixture above:

```
fit: 1407 checked, 0 over, 3 rows cut, measure failures 0
```
Per skin (`DT.fitFaults()` after the in-memory switch):
```
clean: 469 checked, 0 over, 1 rows cut
deadtired: 469 checked, 0 over, 1 rows cut
forever: 469 checked, 0 over, 1 rows cut
```
The cut row is the event: `Stranglethorn Fishing Extravaganza` is 204 px against `name 190`, and its
`when` 216 against 208. Harness pixels; Friz Quadrata at 12 is narrower (question 4). "Checked"
counts every recorded string plus every list column, per skin. A planted 30 px button with a label
"Far too wide for its button" gives `fit: clean plant label "Far too wide for its but" 162/30` (and
the same for `deadtired` and `forever`), and the last line counts `3 over`.

## Task 6: the static suite (`tests/test_textfit.lua`, run beside `test_taint.lua`)
It reads `luac5.1 -p -l` listings, as `taint_scan.lua` does. Red on `CreateFontString` as a SELF or
GETTABLE constant key in any `DeadTired/*.lua` but `UI.lua`. Red on a table field `footer = <number
constant>`. That is stricter than the brief: anywhere, not only in a `DT.viewport` call, and
`DT.viewport` raises at run time on a footer that isn't text. The fixture: a raw `f:CreateFontString`,
`f.CreateFontString(f)` and one inside a function are caught; the same name in a comment, in a
string and through `DT.text` passes; `footer = 16` and `t.footer = 2.5` are caught; `footer = "text"`
passes. Plus a one-call fixture and a one-footer fixture, each red alone. On the tree: no raw call
outside `UI.lua`, no numeric footer, every file compiles, and `UI.lua`'s two calls are seen (the scan
isn't blind). 8 checks.

## Task 7: tooltips (defect 4, G8)
`Played.lua`'s tip is the name only; `Crypt.lua`'s is the name and the date. Gank's and Who's keep
their realm line (R-F4-10).

## Task 8: the nudge (R-F4-6, G9)
`Recruit.lua`'s `PLAYER_ENTERING_WORLD` takes `(isInitialLogin, isReload)` and calls the existing
`rearm()` when `isReload == true`; nothing else changed. `rearm()` already arms only while the
cooldown runs, so a cooldown that ended during the reload gives no late line. `CLAUDE.md`'s nudge
line now reads "...after a post this session (a `/reload` keeps it) (card 5, fix round 3; ...)".
Checks: re-armed by a reload and comes at 15 min after the post, once; two reloads, still one; a
fresh login inside the cooldown, none; a reload after the cooldown, none; nudge off, none; a flag
that isn't exactly `true`, none.

## Task 9: hint, switches, skin
**Hint (R-F4-7):** `/dt played` asks the client as before, then prints `Sharing's off. /dt slowest
share on` when `played.share` is off (after the client's own line if it can't say). Nothing
recorded, nothing sent (checks in `test_played`).

**Master switches (R-F4-5):** `optional = true` on gank, played, stash, events, logs; the framework's
`On` card, default on, unchanged. Each module's `DT.on` handlers, timer callbacks and verbs return
at once when `DT.enabled(id)` is false; each verb prints `<id>.enabled = off` and returns.
- **gank:** `GANK` inbound ignored (not even counted bad); `/dt gank`, `/dt ganks`, `/dt ganks <name>`
  answer the line (no target read, nothing logged or sent, no board). On again: `/dt ganks` opens
  the board with the grudges intact; inbound heard. The guildie's board keeps a grudge already sent.
- **played:** `TIME_PLAYED_MSG` unregistered; `PLAYED` inbound (entries and withdrawals) ignored;
  `/dt slowest`, `/dt slowest share on|off`, `/dt slowest share`, `/dt played` answer the line (the
  client not asked); switching Played off withdraws nothing: your own entry stays and no withdrawal
  is sent. **But switching `share` off (the card or `/dt set`) withdraws even while Played is off**
  (Tim's ruling, 12 Nov, below). On again: events back, inbound heard, the board opens.
- **stash:** `PLAYER_ENTERING_WORLD`, `BAG_UPDATE_DELAYED`, `BANKFRAME_OPENED` unregistered;
  `STASHQ` and `STASH` ignored (a late answer not even recorded); an answer already waiting on its
  delay is not sent; the pending bag rescan's timer returns; the bags aren't read; `/dt stash`
  (overview, search, share on/off, share) answers the line. On again: answers searches.
- **events:** `PLAYER_ENTERING_WORLD` unregistered; the minute ticker's callback returns at once and
  stops; `onEnable` restarts it once the world has been entered (else the next
  `PLAYER_ENTERING_WORLD` does); `/dt events`, `remind on|off`, `remind` answer the line. On again:
  reminders come back. Events has no inbound messages and sends nothing, so "off ignores inbound"
  and "off sends nothing" are its events and its ticker.
- **logs:** all three events unregistered; the `member` listener returns (no prompt, no login
  offer); the report line after a click returns; `/dt logs`, `now`, `on`, `login off` answer the
  line; `LoggingCombat`/`LoggingChat` never called with an argument. `onDisable` hides an open
  prompt out of combat (question 7). Still off after a reload; on again the dungeon prompt is back.

One framework change beyond `fit` and the footer's text form: `DT.get` no longer creates an empty
`settings[id]` table when it reads. The values it returns are the same. It mattered because the
switches are now read outside the guild, and `test_logs`' "another guild: nothing stored" went red.
I judged it not a contract change; say if you see it otherwise.

**Skin (R-F4-3, R-F4-8):** `clean` (title `Dead Tired`; `deadtired`'s colour, texture and spacing
tables, shared; no `fonts`, so the base's Friz Quadrata 14/12/10 apply); `deadtired`'s title is
`Dead Tired Gothic`. `core.skin`: choices `clean, deadtired, forever`, default `clean`, verb usage
`skin clean|deadtired|forever`, the description exactly R-F4-8's.

**The skin move (R-F4-4), `Migrate.lua`**, on fixtures (`test_migrate`, G11):

| Saved before | After first load | `migrated.skin031` | Later |
|---|---|---|---|
| `deadtired` | `clean` | true | `/dt skin deadtired` then `/reload`: stays `deadtired` |
| `forever` | `forever` | true | |
| none (0.3.0 store, no `core` table) | `clean` | true | |
| no `DeadTiredDB` at all | `clean` | true | |
| `clean` | `clean` | true | |

Run alone on a loaded store it changes `settings.core.skin` and `migrated.skin031` and nothing else
(a dump compared). Silent: no chat line. A second run refuses.

## Ruling (Tim, 12 Nov): the sharing toggle always withdraws
Asked as question 2 of the first report. `shareChanged` in `Played.lua` no longer returns when the
module is off: switching `played.share` off sends `PLAYED {off=1}` and removes your own entry from
your board, whether Played is on or off. It is the only send Played makes while off. The typed
`/dt slowest share off` is Played's own verb, so while off it still answers `played.enabled = off`
and does nothing (R-F4-5); the card and `/dt set played share off` are the paths that withdraw.
Said in Played's header comment and in `FEATURES.md` under R-F4-5.
- Check (`test_played`): `played off: switching sharing off still withdraws (PLAYED off=1 sent, your
  own entry removed)`. The check before it now reads `R-F4-5: off is not a withdrawal: your own
  entry stays, no withdrawal sent` (switching the module off sends nothing), and `G10 played off:
  nothing recorded from the client, nothing sent`. These replace the first build's `G10 played off:
  sends nothing (sharing switched off on the card: no withdrawal sent)` and its `R-F4-5` check,
  which asserted the opposite. `played` stays at 86 checks.
- Guard (row 96 below): the gate `if not DT.enabled("played") then return end` put back after
  `if on then return end` → **red**: the check above. It replaces the first build's guard `played off:
  sends nothing (no withdrawal from the card)`, whose line is gone. Still 109 guards, all proved, all
  files restored. 0.3.0's F9 guard (`played withdrawn when sharing off`) is still red too.

## Task 10: guard proofs (`lua5.1 tools/guard_proofs.lua`)
Every guard: the line changed once, its suite run, the named checks that went red, the file restored
and compared. **0.3.0's guards: 74** (`tools/guard_proofs.lua` at `3fbb61f` has 74 entries and the
Port 2 report's table 74 rows; its "75" and the brief's are an off-by-one). All 74 still red; one
was replaced: 0.3.0's `list rows fit their text` (rows taller for wrapped text) guarded the
behaviour R-F4-1 reverses, so its entry now proves the opposite rule: every row one height.
Rows 75-109 are this round's.

### Two strengthened tests (`CLAUDE.md`'s one exception)
On the first run two removals turned nothing red:
- **fitLine: the UTF-8 boundary.** The harness gives a continuation byte no width, so with byte-level
  cut points the binary search's longest fitting prefix still ended on a whole character; no
  check could tell. Added a check on `DT._cuts` itself: every cut point falls after a whole
  character (two- and three-byte).
- **stash off: ignores inbound answers.** The summary's own gate (no window when off) hid it.
  Added: a late answer is not even recorded in the open search.

Test files only; re-proved, both red. The diff:
```diff
--- (before) test_ui.lua	2026-11-12 14:57:41.312349349 +0000
+++ DeadTired/tests/test_ui.lua	2026-11-12 14:57:41.327095375 +0000
@@ -214,6 +214,14 @@
     end
   end
   check("G2 fitLine: a two-byte character is never split, at any width", ok)
+  -- the cut points themselves (the harness gives a continuation byte no width, so a split
+  -- character would measure the same as a whole one: check the boundaries directly)
+  local whole = true
+  for _, j in ipairs(D._cuts(word .. "\226\128\148x")) do                 -- é and a three-byte dash
+    local nb = (word .. "\226\128\148x"):byte(j + 1)
+    if nb and nb >= 128 and nb < 192 then whole = false end
+  end
+  check("G2 fitLine: every cut point falls after a whole UTF-8 character (two- and three-byte)", whole)
   local f = D.fitLine("ab\195\169\195\169\195\169", 24, "body")
   check("G2 fitLine: the cut falls between whole characters", f == "ab\195\169" .. ELL)
   f = D.fitLine("a||b||c||d||e", 36, "body")
--- (before) test_stash.lua	2026-11-12 14:57:41.312386213 +0000
+++ DeadTired/tests/test_stash.lua	2026-11-12 14:57:41.328335960 +0000
@@ -432,6 +432,8 @@
   a:slash("stash linen")
   a:slash("set stash enabled off")
   inject(a, "STASH", b:key(), { q = tostring(a.DT._stash.open() and a.DT._stash.open().q or 0), to = a:key(), hits = "2589:5:Echo Nightclaw" })
+  local o = a.DT._stash.open()
+  check("G10 stash off: a late answer is not even recorded", o == nil or next(o.answers) == nil)
   w:advance(11)
   check("G10 stash off: late answers ignored, no window", not (a.DT._stash.vp() and a.DT._stash.vp():IsShown()))
   a:slash("set stash enabled on")
```

### 0.3.0's guards (rows 1-74)
| Guard | File | Change | Suite | Went red |
|---|---|---|---|---|
| guild gate | `Guild.lua` | `return want ~= nil` | test_guild | **red**: another guild is not the guild; no guild is not the guild; outside: login prints nothing (no welcome, no bar intro) (+8 more) |
| lockdown hold (R-1) | `Comms.lua` | `if false then` | test_comms | **red**: in lockdown: held, nothing sent; a hold is counted; a typed command's message: the held line (+4 more) |
| AUD-10 success test | `Comms.lua` | `if false then item.failed = true end` | test_comms | **red**: refused every time: tried 3 times, then dropped and counted; and not tried again; refused once, then sent: delivered once (+3 more) |
| 3-refusal limit (AUD-10) | `Comms.lua` | `if false then` | test_comms | **red**: refused every time: tried 3 times, then dropped and counted; and not tried again |
| payload-key name match | `Comms.lua` | `return true` | test_comms | **red**: a payload key naming someone else is not taken; the mismatch is counted and kept, not guessed; a short name is not the full name (+2 more) |
| self-exclusion in Who (R-P6: own entry never doubled) | `Who.lua` | line removed | test_who | **red**: self in the saved list is never shown; own GUILD echo: not listed; R-P6: your own entry exactly once, saved copies of you never doubled (+2 more) |
| settings verb-or-noVerb rule | `Core.lua` | `if false then` | test_settings | **red**: a setting with no typed path and no noVerb is refused at registration; a blank noVerb is no reason |
| bar stand-back | `Bar.lua` | `return true` | test_bar | **red**: Titan Panel loaded: DT's bar stands back; standing back: no intro; and the intro then, once (+3 more) |
| borrow-only LibDataBroker | `Bar.lua` | line removed | test_bar | **red**: no LDB: loads and logs in without an error |
| bar intro once only | `Bar.lua` | `if not (bar and bar:IsShown()) then return end` | test_bar | **red**: after /reload: no intro again; on again: no second intro |
| taint scan (rc3's line inserted) | `Core.lua` | `SLASH_DEADTIRED2 = "/deadtired" ⏎ SlashCmdList = SlashCmdList or {}` | test_taint | **red**: taint scan: no hits in DeadTired/*.lua; rc3's SlashCmdList = SlashCmdList or {} in a copy of Core.lua: the scan goes red |
| guild gate: DT.out | `Core.lua` | line removed | test_guild | **red**: outside: DT.out itself prints nothing |
| guild gate: DT.send | `Comms.lua` | line removed | test_guild | **red**: outside: DT.send refuses; outside: nothing on the wire, ever |
| guild gate: inbound | `Comms.lua` | line removed | test_guild | **red**: outside: inbound ignored |
| disabled module registers nothing | `Core.lua` | `if true then` | test_core | **red**: /dt set t enabled off: events unregistered, onDisable ran; off: its handler never runs; on again: registered and running (+1 more) |
| handler error count | `Core.lua` | line removed | test_core | **red**: and counted under the module's own error key; each failure counts; a verb failure is counted and re-raised |
| legacy move | `Core.lua` | `if false then` | test_core | **red**: an rc3 store is moved under legacy, the same table, untouched; the old-records line, once, on the first login; not again after a reload (+1 more) |
| protocol version | `Comms.lua` | line removed | test_comms | **red**: an unknown version is counted and ignored, not decoded; junk never raises, counted malformed; only GUILD and only our prefix are read |
| held line once per hold | `Comms.lua` | `if holding and DT.inCommand then` | test_comms | **red**: once per hold |
| held line for typed commands only | `Comms.lua` | `if holding and not heldSaid then` | test_comms | **red**: a send the addon makes itself: no held line; a typed command's message: the held line |
| realm normalise (AUD-06) | `Keys.lua` | `realm = realm` | test_keys | **red**: realmKey: spaces and hyphens go; realmKey(): GetRealmName when the normalised name is missing; keyOf: two-part name, realm normalised (+3 more) |
| full name for my key | `Keys.lua` | `return DT.fullName(str((try(UnitName, "player"))))` | test_keys | **red**: myKey: the full name (GetUnitName("player", true)), not UnitName |
| list filter | `UI.lua` | `out[#out + 1] = r` | test_ui | **red**: filter: case-insensitive; filter: as you type, letter by letter; filter: plain text, not a pattern (+5 more) |
| toast gate | `UI.lua` | line removed | test_ui | **red**: toast: off by default, nothing shown; toast: a setting that isn't a bool on is not on; toast: switched off, nothing (+1 more) |
| skin base fallback | `Skins.lua` | line removed | test_skins | **red**: loads and logs in under the default skin without an error |
| Who ask rate limit | `Who.lua` | `if true then` | test_who | **red**: /dt who asks once; not again within 30 s; again after 30 s |
| Who hello rate limit | `Who.lua` | line removed | test_who | **red**: the other answers the ask; again after 30 s; two asks within 10 s: one answer each |
| recruit officer check (A1) | `Recruit.lua` | `if false then` | test_recruit | **red**: A1: IsGuildOfficer false: refused, nothing posted; A1: nil or an error is not an officer either; A1: /dt recruit next still answers a non-officer, posts nothing (+1 more) |
| recruit cooldown | `Recruit.lua` | `if false then` | test_recruit | **red**: inside the cooldown: refused, minutes rounded up; rounded up: 779 s left is 13 min; /dt recruit next shows the line and the wait (+18 more) |
| recruit click-only post (R1, R-P1) | `Recruit.lua` | `if false then` | test_recruit | **red**: R1: post() called from anywhere but a typed command or the click refuses, silently; R1: ...from a timer too |
| recruit General only (A1) | `Recruit.lua` | `return true` | test_recruit | **red**: not in General: refused; a failed post: refused, cooldown and rotation unmoved; the chat function absent: nothing posted, nothing moved (+10 more) |
| death share opt-in (A2) | `Crypt.lua` | `if true then` | test_crypt | **red**: a normal death is not sent by default; so the guildie hears nothing and records nothing; share on: a normal death is sent (+3 more) |
| battleground rule | `Crypt.lua` | line removed | test_crypt | **red**: a battleground on a hardcore character counts as normal: sent as hc 0, not HC; an arena likewise |
| hardcore line once only | `Crypt.lua` | `if not me then return end` | test_crypt | **red**: A2: not after a /reload; A2: not on the second login; A2: when membership arrives, the line, once (+1 more) |
| prep officers-only acceptance | `Prep.lua` | `if false then` | test_prep | **red**: a list from a member (rank 4) is refused, counted; a sender not on the guild roster is refused; the roster's realm must match the key's (Lilbit High is on Realm 4) (+3 more) |
| prep verdict only (no names or counts) | `Prep.lua` | `short = tostring(math.min(#short, MAX_SHORT)), items = short[1] and short[1].e.name or nil })` | test_prep | **red**: a sharing member answers once with the verdict only: ok and how many short, no names or counts; the summary at 10 s |
| prep officers set the list | `Prep.lua` | `local item` | test_prep | **red**: a member can't set the list |
| migration runs once | `Migrate.lua` | line removed | test_migrate | **red**: runs once: nothing copied twice (no second set of legacy deaths, no entry brought back, no setting reset) |
| short->full merge: exactly one | `Migrate.lua` | `if hits >= 1 then map[k] = hit` | test_migrate | **red**: exactly one: two full keys starting with the short name: kept, counted; exactly one: the unmatched count |
| R-P5 collision rule | `Keys.lua` | `if false then` | test_keys | **red**: R-P5 collision: two shown entries sharing a full name both get (Realm); R-P5 collision: case and spacing don't hide one; R-P5: display among a shown set |
| bar: others unticked by default (R-P4) | `Bar.lua` | `b.on[name] = true` | test_bar | **red**: no LDB: the bar shows DT's own buttons, drawn natively; R-P4: other addons' objects are listed but unticked: the bar shows DT's own only; with LDB: ticked, the bar hosts other addons' launchers and data sources (+13 more) |
| bar: colour codes pass | `Bar.lua` | `if false then` | test_bar | **red**: colour codes: another addon's colour code is shown, not escaped; R-P4: /dt bar remove unticks it; R-P4 move: to position 1 (+4 more) |
| every row one height (R-F4-1; replaces 'list rows fit their text') | `UI.lua` | `b:SetHeight(#b.cut > 0 and rh * 2 or rh)` | test_ui | **red**: R-F4-1: a long cell doesn't make its row taller: every row one height; rows: each row starts below the one above (no overlap); G3 every row the same height |
| settings content follows the scroll | `SettingsView.lua` | `if scroll > maxS then scroll = maxS end` | test_settingsview | **red**: defect 2: reopened, the content is back at the top (the first setting visible); defect 2: a search after a scroll starts at the top too |
| gank reads the target only on the verb (R1) | `Gank.lua` | line removed | test_gank | **red**: R1: DT.gank() called from anywhere but the typed verb reads nothing, logs nothing; R1: ...from a timer too |
| stash shares only unbound items (A4) | `Stash.lua` | `if true then` | test_stash | **red**: a bound item is never listed; the bank is read when opened: bank and bank bags, bound skipped; /dt stash alone: items across characters, bank read (+19 more) |
| stash shares only known-unbound (unknown not listed) | `Stash.lua` | `if bound ~= true then` | test_stash | **red**: A4 bags: isBound nil, C_Item.IsBound nil: skipped; A4 bags: isBound nil, C_Item.IsBound erroring: skipped; A4 bags: isBound nil, C_Item.IsBound not a boolean: skipped (+10 more) |
| stash opt-in: answering | `Stash.lua` | line removed | test_stash | **red**: a member with sharing off sends nothing and doesn't note the question |
| stash opt-in: scanning | `Stash.lua` | line removed | test_stash | **red**: store: DeadTiredDB.stash, sharing off, badStash 0, no characters; sharing off: no scan at login, no list; sharing off: no scan on bag or bank events (+1 more) |
| stash list deleted when sharing off | `Stash.lua` | `end` | test_stash | **red**: sharing off deletes the account's list; sharing off from the card (or /dt set) deletes it too |
| played shares only after /dt played (R-P2-1) | `Played.lua` | line removed | test_played | **red**: R-P2-1: a TIME_PLAYED_MSG nobody asked for sends nothing; R-P2-1: a plain /played is ignored: nothing recorded or sent; R-P2-1: the report 11 s after /dt played: nothing (+6 more) |
| played: one report per /dt played (R-P2-1) | `Played.lua` | line removed | test_played | **red**: R-P2-1: the request is used up by that report; R-P2-1: and that stale request is gone too |
| played: share gate on sending | `Played.lua` | line removed | test_played | **red**: sharing off: /dt played records and sends nothing; sharing on: /dt played records and sends lvl and hours to one decimal; the guildie stores it, printing nothing (+2 more) |
| played withdrawn when sharing off (F9) | `Played.lua` | line removed | test_played | **red**: /dt slowest share off: no play time sent after it, only the one withdrawal (F9); F9: share off sends one PLAYED with off=1 and nothing else; F9: a guildie online deletes B's entry on off=1 (+2 more) |
| played: the 30-day drop (F9) | `Played.lua` | `if type(e) ~= "table" then b[key] = nil end` | test_played | **red**: F9: past 30 days, /dt slowest drops it before showing; F9: at load, an entry over 30 days old is dropped; F9: at load, an entry with no time is dropped |
| played: no hook (a hooksecurefunc on /played inserted) | `Played.lua` | `local SEND_WINDOW = 60 ⏎ hooksecurefunc(SlashCmdList, "PLAYED", function() end)` | test_taint | **red**: taint scan: no hits in DeadTired/*.lua |
| events print only once switched on (R4) | `Events.lua` | line removed | test_events | **red**: R4: reminders off by default: nothing; /dt events remind off: nothing |
| logs never switch a log off: combat (only an OFF log armed) | `Logs.lua` | `local c = (combatOn ~= nil) and "/combatlog" or nil` | test_logs | **red**: combat on: only the chat log offered; F10: chat unknown, combat on: the line names /chatlog |
| logs never switch a log off: chat | `Logs.lua` | `local h = "/chatlog"` | test_logs | **red**: chat on: only the combat log offered; F10: nothing armable: no login dialog, the combat line instead; F10: chat unknown, combat on: the line names /chatlog (+2 more) |
| logs only read the state (no argument to LoggingCombat/LoggingChat) | `Logs.lua` | `if v == nil then v = clean((try(_G[legacyName], true))) end` | test_logs | **red**: scripted session: zero calls to the logging switches with an argument; G10 logs off: never touches a client log |
| logs one prompt at a time: login covers a dungeon (F12) | `Logs.lua` | `if false then` | test_logs | **red**: F12: walking into a dungeon with the login prompt up: no second prompt; F12: the visit counts as asked: no prompt later in the same visit; F12: a new visit asks as usual (+1 more) |
| logs one prompt at a time: instance hidden for login (F12) | `Logs.lua` | line removed | test_logs | **red**: F12: /dt logs now with the instance prompt up: only the login prompt; F12: combat over: the instance prompt hidden, then the login prompt shown |
| logs one prompt at a time: a click hides the others (F13) | `Logs.lua` | line removed | test_logs | **red**: F13: a click on the login prompt hides the instance prompt too; F13: ... so Log it can't be pressed after Combat log: one /combatlog run, the log on |
| logs never in a battleground or arena | `Logs.lua` | `if kind == "none" then return kind, nil end` | test_logs | **red**: battleground, arena and open world: never |
| logs never in the open world | `Logs.lua` | `if kind == "pvp" or kind == "arena" then return kind, nil end` | test_logs | **red**: open world at login: no dialog; raid, combat log off: the dialog; battleground, arena and open world: never (+17 more) |
| nudge re-armed on 'nudge on' (Port 1 defect 1) | `Recruit.lua` | line removed | test_recruit | **red**: Port 2: ...and it comes once at 15 min; G9 a /reload with the cooldown running: re-armed, the nudge comes at 15 min after the post; G9 ...and only once (+2 more) |
| nudge once per post | `Recruit.lua` | `if store().at ~= at then return end` | test_recruit | **red**: Port 2: on just after it, with the clock 1 s behind: no second nudge for that post |
| UISpecialFrames insert only (R-P2-2) | `UI.lua` | `table.insert(UISpecialFrames, 1, name)` | test_taint | **red**: taint scan: no hits in DeadTired/*.lua |
| UISpecialFrames: never a removal (R-P2-2) | `UI.lua` | `escaped[name] = true ⏎   table.remove(UISpecialFrames, 1) ⏎   return true` | test_taint | **red**: taint scan: no hits in DeadTired/*.lua; R-P2-2: only UI.lua reads UISpecialFrames (once to check it, once to insert) |
| UISpecialFrames: DT's own names, once each (R-P2-2) | `UI.lua` | `if type(name) ~= "string" then return false end` | test_ui | **red**: R-P2-2: a name that isn't DT's is refused; R-P2-2: inserting the same name twice is refused |
| Escape registration at creation (R-P2-2) | `UI.lua` | line removed | test_ui | **red**: R-P2-2: each DT viewport adds its own frame name once, at the end, at creation (Who, settings, graveyard, gank board, slowest board, events); R-P2-2: a name that isn't DT's is refused; R-P2-2: inserting the same name twice is refused (+1 more) |
| bar list shows names, not live text (Port 1 defect 2) | `Bar.lua` | `local l = DT.trim(plain(e.obj.label or e.obj.text or "")) or ""` | test_bar | **red**: Port 2: the list names each object, never its live text (BugSack, not 0; Recruit, not Recruit 8:23); Port 2: /dt bar list shows the names; Port 2: not by its text |
| graveyard date on one line (Port 1 defect 4) | `Crypt.lua` | `rows[#rows + 1] = { key = e.who, day = DT.safe(day, 20),` | test_crypt | **red**: newest first, date, name, level, zone, (HC) on hardcore; Port 2: the date column is short ("3 Nov"), the full date kept for the tooltip; G3 defect 1: "12 Nov" and "9 Nov" each on one line, uncut |
| Port 2 migration runs once | `Migrate.lua` | line removed | test_migrate | **red**: Port 2 runs once: no second set of logs, no setting reset |

### This round's guards (rows 75-109)
| Guard | File | Change | Suite | Went red |
|---|---|---|---|---|
| fitLine cuts to the width | `UI.lua` | `if true then return text, false end` | test_ui | **red**: G2 fitLine: too wide: no wider than the box, ending with "…"; G2 fitLine: a trailing space is dropped before the "…"; G2 fitLine: the cut falls between whole characters (+6 more) |
| fitLine: the UTF-8 boundary | `UI.lua` | line removed | test_ui | **red**: G2 fitLine: every cut point falls after a whole UTF-8 character (two- and three-byte) |
| the cut row's tooltip text | `UI.lua` | line removed | test_ui | **red**: G4 a cut row's tooltip: the module's own line first, then the cut cell's full text; G4 no tip, a cut cell: the tooltip shows its full text |
| fixed columns measured from the widest value | `UI.lua` | line removed | test_ui | **red**: G3 a fixed column is as wide as its widest value (12 Nov), measured, plus 2; G3 "12 Nov" and "9 Nov" in one model: both on one line, neither cut; G3 static width as given; flex is the rest of the declared width (+4 more) |
| exactly one flex column | `UI.lua` | line removed | test_ui | **red**: G3 exactly one flex column: none -> DT.list raises; two -> raises |
| the footer insets the body by its measured height | `UI.lua` | `vp.body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -pad, pad + 16)` | test_ui | **red**: G5 footer: the body inset by the footer's measured height (one line); G5 footer: a longer footer wraps inside the width, the body inset by all of it; no footer: the body reaches the padding |
| a measure failure is counted (ui:measure) | `UI.lua` | line removed | test_ui | **red**: R-F4-1: a width <= 0 for non-empty text: counted under ui:measure, the text treated as fitting; R-F4-1: a non-number width: counted too |
| static suite: the CreateFontString rule (a raw call inserted) | `Crypt.lua` | `local ICON = [[Interface\Icons\Spell_Shadow_RaiseDead]] ⏎ local function raw(f) return f:CreateFontString() end` | test_textfit | **red**: R-F4-1: no CreateFontString outside UI.lua (DT.text is the only maker of text) |
| static suite: the numeric-footer rule (a pixel footer put back) | `Crypt.lua` | `width = 440, height = 400, footer = 16,` | test_textfit | **red**: R-F4-1: no viewport footer given as a number |
| /dt debug fit restores the skin | `UI.lua` | line removed | test_debug | **red**: G7 debug fit: the saved skin is the same before and after |
| /dt debug fit never saves the skin | `UI.lua` | `DT.fitSkin = name; DT.set("core", "skin", name) ⏎ ` | test_debug | **red**: G7 debug fit: the saved skin is the same before and after; G7 debug fit: never written (no setting signal, no saved choice touched) |
| realm line absent from the slowest board's tooltip | `Played.lua` | `tip = function(row, tt) tt:AddLine(DT.safe(DT.nameOf(row.key), 48)); tt:AddLine(DT.realmLabel(row.key), 1, 1, 1) end,` | test_played | **red**: G8 the tooltip is the name only: no realm line (defect 4) |
| realm line absent from the graveyard's tooltip | `Crypt.lua` | `tt:AddLine(DT.safe(DT.nameOf(row.key), 48)); tt:AddLine(DT.realmLabel(row.key), 1, 1, 1) ⏎       tt:AddLine(row.full` | test_crypt | **red**: G8 the graveyard's tooltip: the name, then the date; no realm line |
| nudge: re-armed on a /reload (R-F4-6) | `Recruit.lua` | line removed | test_recruit | **red**: G9 a /reload with the cooldown running: re-armed, the nudge comes at 15 min after the post; G9 ...and only once; G9 two reloads inside one cooldown: still one nudge for the post (+1 more) |
| nudge: no re-arm on a first login | `Recruit.lua` | `rearm()` | test_recruit | **red**: G9 a fresh login inside the cooldown: no nudge (never re-armed at login); G9 a reload flag that isn't exactly true re-arms nothing |
| nudge: no re-arm once the cooldown has ended | `Recruit.lua` | `if type(at) == "number" then` | test_recruit | **red**: G9 a /reload after the cooldown ended: no late line |
| the hint only when sharing is off (R-F4-7) | `Played.lua` | `DT.out(HINT)` | test_played | **red**: R-P2-1: noRequest: one line says so; R-P2-1: requestFails: one line says so; R-F4-7: sharing on: no hint |
| gank off: ignores inbound | `Gank.lua` | line removed | test_gank | **red**: G10 gank off: inbound ignored; G10 gank off: not even counted as bad; G10 gank on again: /dt ganks opens the board, the grudges intact |
| gank off: /dt gank sends nothing, does nothing else | `Gank.lua` | line removed | test_gank | **red**: G10 gank off: /dt gank prints gank.enabled = off and nothing else; G10 gank off: the verbs did nothing else: no target read, nothing logged, nothing sent, no board; G10 gank off: inbound ignored (+3 more) |
| gank off: /dt ganks does nothing else | `Gank.lua` | line removed | test_gank | **red**: G10 gank off: /dt ganks prints gank.enabled = off and nothing else; G10 gank off: /dt ganks backstabz prints gank.enabled = off and nothing else; G10 gank off: the verbs did nothing else: no target read, nothing logged, nothing sent, no board |
| played off: ignores inbound | `Played.lua` | line removed | test_played | **red**: G10 played off: inbound ignored (no entry added, none withdrawn) |
| the sharing toggle withdraws even while Played is off (Tim, 12 Nov) | `Played.lua` | `if on then return end ⏎   if not DT.enabled("played") then return end` | test_played | **red**: played off: switching sharing off still withdraws (PLAYED off=1 sent, your own entry removed) |
| played off: /dt slowest does nothing else | `Played.lua` | line removed | test_played | **red**: G10 played off: /dt slowest prints played.enabled = off and nothing else; G10 played off: /dt slowest share off prints played.enabled = off and nothing else; G10 played off: /dt slowest share prints played.enabled = off and nothing else (+5 more) |
| played off: /dt played does nothing else (the client not asked) | `Played.lua` | line removed | test_played | **red**: G10 played off: /dt played prints played.enabled = off and nothing else |
| stash off: ignores inbound searches | `Stash.lua` | line removed | test_stash | **red**: G10 stash off: inbound not even counted as bad |
| stash off: ignores inbound answers | `Stash.lua` | line removed | test_stash | **red**: G10 stash off: a late answer is not even recorded |
| stash off: sends nothing (a waiting answer) | `Stash.lua` | line removed | test_stash | **red**: G10 stash off: an answer already waiting is not sent; G10 stash on again: answers searches |
| stash off: /dt stash does nothing else | `Stash.lua` | line removed | test_stash | **red**: G10 stash off: /dt stash prints stash.enabled = off and nothing else; G10 stash off: /dt stash linen prints stash.enabled = off and nothing else; G10 stash off: /dt stash share off prints stash.enabled = off and nothing else (+4 more) |
| events off: prints nothing unasked (the ticker stops) | `Events.lua` | line removed | test_events | **red**: G10 events off: no reminder printed unasked (the ticker stops) |
| events off: /dt events does nothing else | `Events.lua` | line removed | test_events | **red**: G10 events off: /dt events prints events.enabled = off and nothing else; G10 events off: /dt events remind off prints events.enabled = off and nothing else; G10 events off: /dt events remind prints events.enabled = off and nothing else (+2 more) |
| logs off: no prompt (the member signal) | `Logs.lua` | line removed | test_logs | **red**: G10 logs off: no prompt, no login offer |
| logs off: /dt logs does nothing else | `Logs.lua` | line removed | test_logs | **red**: G10 logs off: /dt logs prints logs.enabled = off and nothing else; G10 logs off: /dt logs now prints logs.enabled = off and nothing else; G10 logs off: /dt logs on prints logs.enabled = off and nothing else (+3 more) |
| a log dialog sized from its text | `Logs.lua` | `dlg:SetSize(w, 104)` | test_logs | **red**: defect 3: the dialog's height comes from its text (the status's two lines), the buttons below; login dialog: sized from its text too |
| the skin move runs once (R-F4-4) | `Migrate.lua` | line removed | test_migrate | **red**: G11 the move runs once: /dt skin deadtired afterwards sticks after a /reload; G11 the move refuses a second run |
| the skin move leaves forever alone | `Migrate.lua` | `if cur ~= "clean" then` | test_migrate | **red**: G11 a saved forever is left alone |

`every guard proved; every file restored`

## Task 11: docs
- `CLAUDE.md`: the nudge line amended (R-F4-6). New section *What every module must do* (before
  *Tests*): the sentence "New modules meet all of these; an existing module is brought into line
  only where a brief says so." then the fourteen rules exactly as Tim gave them on 12 Nov (code
  names in backticks), since the design note isn't in this repo.
- `docs/FEATURES.md`: under R-F4-5, "Ruled (Tim, 12 Nov): the sharing toggle always withdraws..."
- `docs/FEATURES.md`: the shell table's viewport row now reads "Escape closes it (R-P2-2, walked 12
  Nov)"; new section *Ruled 12 Nov (for `dt_fixes4`)* with R-F4-1 to R-F4-10 as ratified.
- `docs/RELEASE_0.3.0.md`: the graveyard line under *Fixed* is now "The graveyard's dates are short
  (`10 Nov`), the full date in the tooltip. Some still wrapped: fixed in 0.3.1."
- New `docs/RELEASE_0.3.1.md` (draft): the look has changed and `/dt skin deadtired` for the gothic
  titles; what's fixed; the switches and the hint as a one-off in a PATCH (R-F4-9); install steps.

## Task 12: version and zip
`DeadTired.toc` `## Version: 0.3.1`, `DT.VERSION = "0.3.1"`. `sh tools/package.sh` →
**`dist/DeadTired-0.3.1.zip`, 174,053 bytes** (rebuilt after the follow-ups), sha256
`2fb64504930a50768ad97723a502c77998f09dd860bb8dbaeafa2f119ad32aac`, `diff -r: clean`. Older zips
left in `dist/`. Files: `DeadTired/` with `DeadTired.toc`, `Config.lua`, `Core.lua`, `Keys.lua`,
`Guild.lua`, `Comms.lua`, `Settings.lua`, `Skins.lua`, `UI.lua`, `SettingsView.lua`, `Bar.lua`,
`Debug.lua`, `Who.lua`, `Alts.lua`, `Crypt.lua`, `RecruitLines.lua`, `Recruit.lua`, `Prep.lua`,
`Session.lua`, `Gank.lua`, `Played.lua`, `Stash.lua`, `EventsList.lua`, `Events.lua`, `Logs.lua`,
`Migrate.lua`, and `Libs/` (LibStub, CallbackHandler-1.0, AceComm-3.0 + ChatThrottleLib,
LibSerialize, LibDeflate, LibSharedMedia-3.0, each with its licence; `README.md`, `SHA256SUMS`). No
`tests/`.

## Player-facing lines added
- `Sharing's off. /dt slowest share on` (R-F4-7).
- The skin card's description (R-F4-8); the skin titles `Dead Tired` and `Dead Tired Gothic`; the
  usage `skin clean|deadtired|forever`.
- `gank.enabled = off`, `played.enabled = off`, `stash.enabled = off`, `events.enabled = off`,
  `logs.enabled = off` (the line Who already uses).
- `/dt debug fit`'s lines (`fit: <skin> <window> <kind> "<text>" <measured>/<box>` and
  `fit: <n> checked, <m> over, <k> rows cut, measure failures <f>`); `debug fit` in the help line.
- The `…` on cut text.
- Not new wording but new instances: the five `On` cards carry the framework's default description,
  "Switches Gank diary on or off. Off, it listens to nothing." (and Glacial Progress, Stash, Events,
  Logs), question 3.

## Anything in the brief that turned out wrong
- "every guard 0.3.0 proved (75)": 74 (above).
- Task 11's fourteen points: their source isn't in the repo (Tim supplied them in the follow-up).
- Task 3's "Any other `DT.list` caller (Prep, the settings view's lists)": there are none.
- Not wrong, worth knowing: R-F4-1 "re-measured when rows or skin change" needed the bar's painter to
  re-lay the bar too (0.3.0 re-fonted the buttons on a skin change but kept their old widths).

## Questions for Tim
1. ~~The module template~~: answered (follow-up 1, Task 11).
2. ~~Played off, then sharing off~~: ruled, the toggle always withdraws (the ruling section).
3. **The five `On` cards' description** is the framework's default ("Switches <title> on or off. Off,
   it listens to nothing."). Keep it, or give each its own line (saying, say, that off isn't a
   withdrawal)?
4. **Events' name column is 190 (static, per the brief).** In the harness `Stranglethorn Fishing
   Extravaganza` is cut (204 px at 6 px a character). In game Friz Quadrata 12 is narrower, so it may
   fit; H5's `/dt debug fit` will say. Its full text is in the row's tooltip either way.
5. **The game's Settings → AddOns stub** ("Dead Tired" above its button) is a `fixedFont` line, so
   it keeps the game's lettering and isn't skinned, as in 0.3.0. Fine?
6. **Template button labels** (the log dialogs' buttons, settings' Remove and choice buttons) are the
   template's own text, not `DT.text`: not measured, not cut, not in `/dt debug fit`. In scope later?
7. **Logs switched off while its prompt is up in combat:** the prompt can't be hidden in combat and,
   with the module off, nothing hides it afterwards. A click still runs only the player's own
   `/combatlog`. Acceptable, or should the prompt go when combat ends even with Logs off?
