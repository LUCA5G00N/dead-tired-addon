-- Offline checks for UI.lua: the list model (filtering as you type), the list view, the viewport
-- (position saved and restored, insecure; Port 2, R-P2-2: closed by Escape through UISpecialFrames,
-- insert only), toasts gated by a setting, the short date.
-- lua5.1 DeadTired/tests/test_ui.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"

-- ---------------------------------------------------------------- the list model
do
  local w = H.world()
  local c = w:client({ guild = G })
  local m = c.DT.listModel()
  m:set({ { search = "Lilbit High" }, { search = "Stromham Hamson" }, { search = "Graverobber 100%" }, { text = "Ghoul" } })
  check("no query: every row", #m:visible() == 4)
  check("filter: case-insensitive", #m:filter("HAM") == 1 and m:visible()[1].search == "Stromham Hamson")
  check("filter: as you type, letter by letter", #m:filter("g") == 3 and #m:filter("gr") == 1 and #m:filter("gra") == 1)
  check("filter: plain text, not a pattern", #m:filter("100%") == 1 and #m:filter("(") == 0 and #m:filter(".") == 0)
  check("filter: spaces trimmed", #m:filter("  lilbit ") == 1)
  check("filter: falls back to .text", #m:filter("ghoul") == 1)
  check("filter cleared: every row again", #m:filter("") == 4)
  m:filter("ham")
  m:set({ { search = "Hamlet" }, { search = "Bones" } })
  check("new rows keep the query", #m:visible() == 1 and m:visible()[1].search == "Hamlet")

  -- the view
  local vp = c.DT.viewport({ id = "listtest", title = "List", search = true,
    onSearch = function(text) m:filter(text) end })
  local L = c.DT.list(vp.body, m, { count = 3, columns = { { key = "search", flex = true } } })
  m:set({ { search = "a1" }, { search = "a2" }, { search = "b3" }, { search = "a4" }, { search = "a5" } })
  m:filter("")
  L:refresh()
  check("view: the first rows drawn, the rest scrolled", L.rows[1].cells[1].text == "a1" and L.rows[3].cells[1].text == "b3")
  L.frame.scripts.OnMouseWheel(L.frame, -1)
  check("view: the mouse wheel scrolls", L.rows[1].cells[1].text == "a2")
  L.frame.scripts.OnMouseWheel(L.frame, -10)
  check("view: not past the end", L.rows[1].cells[1].text == "b3" and L.rows[3].cells[1].text == "a5")
  vp.search:SetText("A")
  vp.search.scripts.OnTextChanged(vp.search)
  L:refresh()
  check("view: typing in the search box filters", #m:visible() == 4 and L.rows[1].cells[1].text == "a1"
    and L.rows[3].cells[1].text == "a4")
  m:filter("zzz"); L:refresh()
  check("view: unused rows hidden", not L.rows[1].shown and L.rows[1].cells[1].text == "")
  check("search box: Escape only drops focus", vp.search.scripts.OnEscapePressed ~= nil)
end

-- ---------------------------------------------------------------- R-P2-2: Escape closes DT's panes
do
  local w = H.world()
  local blizz = { "GameMenuFrame", "CharacterFrame", "WizardryMarksBar_NotThis" }
  local c = w:client({ guild = G, setup = function(c0)
    rawset(c0.env, "UISpecialFrames", blizz)
    rawset(c0.env, "C_DateAndTime", { GetServerTimeLocal = function() return 1793491200 end })
    rawset(c0.env, "date", function(f, t) if f == "!*t" then return os.date("!*t", t) end return "2026-11-11 21:00:00" end)
  end })
  c:login()
  c:slash("who"); c:slash("settings"); c:slash("graveyard"); c:slash("ganks"); c:slash("slowest"); c:slash("events")
  c.DT.viewport({ id = "pinned", title = "Pinned", sticky = true })
  c.DT.viewport({ id = "who", title = "again" })
  local want = { "DeadTiredViewport_who", "DeadTiredViewport_settings", "DeadTiredViewport_crypt", "DeadTiredViewport_gank",
    "DeadTiredViewport_slowest", "DeadTiredViewport_events" }
  local t = c.env.UISpecialFrames
  check("R-P2-2: the table itself is the client's, not replaced", t == blizz)
  check("R-P2-2: what was there stays, in its order, untouched", t[1] == "GameMenuFrame" and t[2] == "CharacterFrame"
    and t[3] == "WizardryMarksBar_NotThis")
  local added = {}
  for i = 4, #t do added[#added + 1] = t[i] end
  check("R-P2-2: each DT viewport adds its own frame name once, at the end, at creation (Who, settings, graveyard, gank board, slowest board, events)",
    table.concat(added, ",") == table.concat(want, ","))
  local own = true
  for _, n in ipairs(added) do if not n:match("^DeadTired") then own = false end end
  check("R-P2-2: only DT's own names are inserted", own)
  check("R-P2-2: a sticky viewport is left out (the opt-out)", not table.concat(t, ","):find("pinned", 1, true))
  check("R-P2-2: a name that isn't DT's is refused", c.DT.closeOnEscape("GameTooltip") == false and #t == 3 + #want)
  check("R-P2-2: inserting the same name twice is refused", c.DT.closeOnEscape("DeadTiredViewport_who") == false and #t == 3 + #want)
  -- what the client's Escape does with it: hides each frame named there (CloseSpecialWindows)
  c:slash("graveyard")
  local vp = c.DT.viewports.crypt
  for _, n in ipairs(t) do local f = c.env[n]; if type(f) == "table" and f.Hide then f:Hide() end end
  check("R-P2-2: Escape (the client hiding each named frame) closes the graveyard", not vp:IsShown())
end

-- ---------------------------------------------------------------- the short date
do
  local w = H.world()
  local c = w:client({ guild = G })
  local D = c.DT.shortDate
  check("shortDate: a stamp becomes \"10 Nov\"", D("2026-11-10 21:00:00") == "10 Nov" and D("2026-01-03") == "3 Jan")
  check("shortDate: anything else is kept, made safe and short", D("x|y") == "x||y" and D(nil) == "?" and #D(string.rep("z", 30)) <= 13)
end

-- ---------------------------------------------------------------- the viewport
do
  local w = H.world()
  local c = w:client({ guild = G })
  c:login()
  local vp = c.DT.viewport({ id = "crypt", title = "The Crypt", search = true })
  local f = vp.frame
  check("viewport: a DT-named frame, insecure (no secure template)", f._name == "DeadTiredViewport_crypt"
    and f._template == "BackdropTemplate")
  check("viewport: starts hidden, centred", not f.shown and f.points[1][1] == "CENTER")
  vp:Show()
  check("viewport: shows", vp:IsShown())
  check("viewport: title, close button, body, search", vp.title.text == "The Crypt" and vp.close and vp.body and vp.search)
  vp.close.scripts.OnClick(vp.close)
  check("viewport: the close button hides it", not vp:IsShown())
  check("viewport: with no UISpecialFrames on the client, nothing is made (no Blizzard global written)",
    rawget(c.env, "UISpecialFrames") == nil)
  check("viewport: movable, clamped, dragged by the frame", f.scripts.OnDragStart and f.scripts.OnDragStop)
  -- drag: the frame moves, the place is saved on release
  f.scripts.OnDragStart(f)
  f:ClearAllPoints(); f:SetPoint("TOPLEFT", c.env.UIParent, "TOPLEFT", 123.4, -56.6)
  f.scripts.OnDragStop(f)
  check("viewport: the place is saved on release", c:db().frames["viewport.crypt"][1] == "TOPLEFT"
    and c:db().frames["viewport.crypt"][3] == 123 and c:db().frames["viewport.crypt"][4] == -57)
  local r = c:reload()
  local vp2 = r.DT.viewport({ id = "crypt", title = "The Crypt" })
  local p = vp2.frame.points[1]
  check("viewport: after /reload it comes back where it was left", p[1] == "TOPLEFT" and p[3] == "TOPLEFT" and p[4] == 123 and p[5] == -57)
  r:db().frames["viewport.crypt"] = { "junk" }
  local w3 = H.world()
  local r3 = w3:client({ guild = G, db = r:db() })
  local vp3 = r3.DT.viewport({ id = "crypt" })
  check("viewport: a broken saved place is ignored (centred)", vp3.frame.points[1][1] == "CENTER")
  -- shown in combat: no secure templates anywhere in DT's frames, no protected calls
  local secure = false
  for _, fr in ipairs(r.frames) do
    if type(fr._template) == "string" and fr._template:find("Secure", 1, true) then secure = true end
  end
  check("no DT frame uses a secure template (usable in combat)", not secure)
end

-- ---------------------------------------------------------------- toasts
do
  local w = H.world()
  local c = w:client({ guild = G, load = false })
  c.DT.module({ id = "t", settings = { { key = "toasty", type = "bool", default = false, label = "Toasts", desc = "Toast me." } } })
  c:fire("ADDON_LOADED", "DeadTired")
  c:login()
  local DT = c.DT
  check("toast: off by default, nothing shown", DT.toast("t", "toasty", "Rest in Pieces") == false and c:frame("DeadTiredToast") == nil)
  c:slash("set t toasty on")
  check("toast: its setting on, it shows", DT.toast("t", "toasty", "Rest in Pieces") == true
    and c:frame("DeadTiredToast").shown and c:frame("DeadTiredToast").text.text == "Rest in Pieces")
  w:advance(4.5)
  check("toast: gone after 4 s", not c:frame("DeadTiredToast").shown)
  check("toast: a setting that isn't a bool on is not on", DT.toast("t", "nope", "x") == false and DT.toast("core", "skin", "x") == false)
  c:slash("set t toasty off")
  local n = DT.toasted
  check("toast: switched off, nothing", DT.toast("t", "toasty", "x") == false and DT.toasted == n)
  c:slash("toast test")
  check("/dt toast test shows one, as asked", c:frame("DeadTiredToast").shown and DT.toasted == n + 1
    and c:frame("DeadTiredToast").text.text == "Dead Tired toasts look like this.")
  c.guild = nil
  c:slash("set t toasty on")
  check("toast: outside the guild, nothing", DT.toast("t", "toasty", "x") == false)
end

-- ---------------------------------------------------------------- Port 1: the empty line; the body gap
do
  local w2 = H.world()
  local c2 = w2:client({ guild = "DEAD TIRED" })
  c2:login()
  local D = c2.DT
  local fs = c2.env.UIParent:CreateFontString()
  fs:SetText(string.rep("x", 50))
  check("textHeight: wrapped at the width", D.textHeight(fs, 100) == 36 and D.textHeight(fs, 400) == 12)
  local m = D.listModel()
  local vp = D.viewport({ id = "t2", title = "T", search = true })
  local L = D.list(vp.body, m, { count = 4, empty = "Nothing here.", columns = { { key = "a", flex = true } } })
  m:set({}); L:refresh()
  check("empty: the line shows when nothing is listed", L.empty.shown and L.empty.text == "Nothing here.")
  check("empty: a block, bounded both sides, its box from its measured height", D.textRecord(L.empty).kind == "block"
    and L.empty.w == L.total - 8 and D.textRecord(L.empty).boxH == 12)
  m:set({ { a = "short", search = "short" }, { a = string.rep("long ", 80), search = "long" }, { a = "x", search = "x" } }); L:refresh()
  check("empty: hidden once rows show", not L.empty.shown)
  local r1, r2, r3 = L.rows[1], L.rows[2], L.rows[3]
  check("R-F4-1: a long cell doesn't make its row taller: every row one height", r1.h == r2.h and r2.h == r3.h and r1.h == 18)
  check("rows: each row starts below the one above (no overlap)", r2.top == r1.top + r1.h and r3.top == r2.top + r2.h)
  check("viewport: the body starts under the search box with a gap", vp.top >= D.style("spacing.pad") + 22 + D.SEARCH_H + 6)
end

-- ---------------------------------------------------------------- fix round 4: DT.fitLine (G2)
do
  local w = H.world()
  local c = w:client({ guild = G })
  c:login()
  local D = c.DT
  local ELL = "\226\128\166"
  -- the harness: half the font's size a character; body 12 -> 6 px
  check("measure: one hidden string per role, through GetStringWidth", D.measure("abcd", "body") == 24
    and D.measure("abcd", "small") == 20 and D.measure("", "body") == 0)
  local t, cut = D.fitLine("Durotar", 60, "body")
  check("G2 fitLine: text that fits comes back unchanged, not cut", t == "Durotar" and cut == false)
  t, cut = D.fitLine("Durotar", 42, "body")
  check("G2 fitLine: exactly the width fits", t == "Durotar" and cut == false)
  t, cut = D.fitLine("Excavation Site: Wetlands", 100, "body")
  check("G2 fitLine: too wide: no wider than the box, ending with \"…\"", cut == true and D.measure(t, "body") <= 100
    and t:sub(-3) == ELL and t == "Excavation Site" .. ELL)
  check("G2 fitLine: the longest prefix that fits (one more character would not)",
    D.measure("Excavation Site:" .. ELL, "body") > 100)
  t = D.fitLine("Excavation Site: Wetlands", 72, "body")
  check("G2 fitLine: a trailing space is dropped before the \"…\"", t == "Excavation" .. ELL)
  local word = "Caf\195\169s \195\169t\195\169 \195\169t\195\169"   -- two-byte characters (é)
  local ok = true
  for wdt = 12, 120, 6 do
    local f = D.fitLine(word, wdt, "body")
    if f ~= word then
      local body = f:sub(1, -4)
      if body:find("[\192-\255]$") or not f:find(ELL, 1, true) then ok = false end   -- a lead byte left alone at the end
      if D.measure(f, "body") > wdt then ok = false end
    end
  end
  check("G2 fitLine: a two-byte character is never split, at any width", ok)
  -- the cut points themselves (the harness gives a continuation byte no width, so a split
  -- character would measure the same as a whole one: check the boundaries directly)
  local whole = true
  for _, j in ipairs(D._cuts(word .. "\226\128\148x")) do                 -- é and a three-byte dash
    local nb = (word .. "\226\128\148x"):byte(j + 1)
    if nb and nb >= 128 and nb < 192 then whole = false end
  end
  check("G2 fitLine: every cut point falls after a whole UTF-8 character (two- and three-byte)", whole)
  local f = D.fitLine("ab\195\169\195\169\195\169", 24, "body")
  check("G2 fitLine: the cut falls between whole characters", f == "ab\195\169" .. ELL)
  f = D.fitLine("a||b||c||d||e", 36, "body")
  check("fitLine: never inside an escaped \"||\"", not f:gsub(ELL, ""):gsub("||", ""):find("|", 1, true))
  check("fitLine: even \"…\" too wide: just \"…\"", D.fitLine("abcdef", 4, "body") == ELL)
  check("fitLine: no width given: unchanged", D.fitLine("abcdef", nil, "body") == "abcdef")
  -- a measure that fails: counted under ui:measure, the text treated as fitting
  local fs = D.measure and nil
  local host = c.env.UIParent:CreateFontString()
  host.GetStringWidth = function() return 0 end
  local before = c:db().errors["ui:measure"] or 0
  local t2, cut2 = D.fitLine("Excavation Site: Wetlands", 50, "body", host)
  check("R-F4-1: a width <= 0 for non-empty text: counted under ui:measure, the text treated as fitting",
    t2 == "Excavation Site: Wetlands" and cut2 == false and c:db().errors["ui:measure"] == before + 1)
  host.GetStringWidth = function() return "wide" end
  D.fitLine("abc", 5, "body", host)
  check("R-F4-1: a non-number width: counted too", c:db().errors["ui:measure"] == before + 2)
  -- DT.text
  local frame = c.env.CreateFrame("Frame", nil, c.env.UIParent)
  frame.dtWindow = "probe"
  local line = D.text(frame, "line", { width = 60 })
  local rec = D.textRecord(line)
  check("DT.text line: one line (word wrap off), its window recorded", line.wordWrap == false and rec.kind == "line"
    and rec.window == "probe" and rec.width == 60)
  check("DT.setText on a line: cut to its width, the full text kept", D.setText(line, "Excavation Site: Wetlands") == true
    and line:GetStringWidth() <= 60 and rec.raw == "Excavation Site: Wetlands")
  D.setWidth(line, 400)
  check("DT.setWidth: a wider line shows the whole text again", line.text == "Excavation Site: Wetlands")
  local block = D.text(frame, "block", { width = 60 })
  check("DT.text block: wrapped", block.wordWrap == true and D.textRecord(block).kind == "block")
  local okBad = pcall(D.text, frame, "wobbly")
  check("DT.text: an unknown kind raises", not okBad)
  -- re-fitted when the skin changes: a wider title font cuts a title line that fit before
  local tl = D.text(frame, "line", { role = "title", width = 70 })
  D.setText(tl, "Glacial Prog")          -- 12 characters: 84 at 14 (clean), 96 at 16 (gothic)
  c:slash("skin forever")
  local atForever = tl.text
  c:slash("skin deadtired")
  local atGothic = tl.text
  check("R-F4-1: re-fitted when the skin changes", atForever:sub(-3) == ELL and atGothic:sub(-3) == ELL
    and #atGothic < #atForever)
  local fixed = D.text(frame, "line", { width = 40, fixedFont = true })
  D.setText(fixed, "abc")
  c:slash("skin forever")
  check("fixedFont: never fonted by the skin", fixed.font == nil and tl.font ~= nil)
end

-- ---------------------------------------------------------------- fix round 4: lists (G3, G4)
do
  local w = H.world()
  local c = w:client({ guild = G })
  c:login()
  local D = c.DT
  local vp = D.viewport({ id = "lists", title = "Lists", search = true, width = 440 })
  local m = D.listModel()
  local okNone = pcall(D.list, vp.body, m, { columns = { { key = "a", width = 50 }, { key = "b", fixed = true } } })
  local okTwo = pcall(D.list, vp.body, D.listModel(), { columns = { { key = "a", flex = true }, { key = "b", flex = true } } })
  check("G3 exactly one flex column: none -> DT.list raises; two -> raises", not okNone and not okTwo)
  local nlists = #D.lists
  local L = D.list(vp.body, m, { count = 4, tip = function(row, tt) tt:AddLine("own " .. row.name) end,
    columns = { { key = "day", fixed = true }, { key = "name", width = 160 }, { key = "lvl", fixed = true },
      { key = "zone", flex = true } } })
  check("one list registered (the failed ones weren't)", #D.lists == nlists + 1)
  m:set({ { day = "12 Nov", name = "Echo Nightclaw", lvl = "60", zone = "Excavation Site: Wetlands and a very long tail", search = "a" },
    { day = "9 Nov", name = "Lilbit High", lvl = "7", zone = "Durotar", search = "b" } })
  L:refresh()
  local day, name, lvl, zone = L.columns[1], L.columns[2], L.columns[3], L.columns[4]
  check("G3 a fixed column is as wide as its widest value (12 Nov), measured, plus 2", day.w == 36 + 2 and day.widest == 36)
  check("G3 \"12 Nov\" and \"9 Nov\" in one model: both on one line, neither cut",
    L.rows[1].cells[1].text == "12 Nov" and L.rows[2].cells[1].text == "9 Nov"
    and L.rows[1].cells[1]:GetStringHeight() <= 12 and L.rows[2].cells[1]:GetStringHeight() <= 12)
  check("G3 static width as given; flex is the rest of the declared width", name.w == 160 and lvl.w == 14
    and zone.w == (440 - 28) - 4 - 4 - 6 * 3 - 38 - 160 - 14)
  check("G3 cells sit left to right, 6 apart", L.rows[1].cells[2].points[1][4] == 4 + 38 + 6
    and L.rows[1].cells[4].points[1][4] == 4 + 38 + 6 + 160 + 6 + 14 + 6)
  check("G3 every row the same height", L.rows[1].h == L.rows[2].h and L.rows[1].h == D.style("spacing.row"))
  check("the long zone ends in \"…\" inside its column", L.rows[1].cells[4].text:sub(-3) == "\226\128\166"
    and L.rows[1].cells[4]:GetStringWidth() <= zone.w)
  -- G4: the cut row's tooltip: the module's lines, then each cut cell in full
  local tt = D.tooltip()
  tt.lines = {}
  L.rows[1].scripts.OnEnter(L.rows[1])
  check("G4 a cut row's tooltip: the module's own line first, then the cut cell's full text",
    tt.lines[1] == "own Echo Nightclaw" and tt.lines[2] == "Excavation Site: Wetlands and a very long tail" and #tt.lines == 2)
  tt.lines = {}
  L.rows[2].scripts.OnEnter(L.rows[2])
  check("G4 an uncut row adds nothing to the module's tooltip", #tt.lines == 1 and tt.lines[1] == "own Lilbit High")
  -- a wider value: re-measured when the rows change
  m:set({ { day = "10 Nov 2026", name = "x", lvl = "100", zone = "z", search = "c" } })
  L:refresh()
  check("G3 re-measured when the rows change", day.w == 66 + 2 and lvl.w == 18 + 2)
  -- a list with no tip: a tooltip only for a cut row
  local m2 = D.listModel()
  local vp2 = D.viewport({ id = "lists2", title = "L2", width = 300 })
  local L2 = D.list(vp2.body, m2, { count = 2, columns = { { key = "name", width = 100 }, { key = "when", flex = true } } })
  m2:set({ { name = "Fishing", when = "Sunday 14:00 server time, in 3d 3h 39m. And then some more words" }, { name = "x", when = "y" } })
  L2:refresh()
  tt.lines = {}; tt.owner = nil
  local shows = 0
  local oldShow = tt.Show
  tt.Show = function(self) shows = shows + 1 end
  L2.rows[2].scripts.OnEnter(L2.rows[2])
  check("G4 no tip, nothing cut: no tooltip", shows == 0)
  L2.rows[1].scripts.OnEnter(L2.rows[1])
  check("G4 no tip, a cut cell: the tooltip shows its full text", shows == 1
    and tt.lines[#tt.lines] == "Sunday 14:00 server time, in 3d 3h 39m. And then some more words")
  tt.Show = oldShow
  check("a list's width comes from the viewport's declared width, never a layout read",
    L2.total == 300 - 28 and not pcall(D.list, c.env.CreateFrame("Frame"), D.listModel(), { columns = { { key = "a", flex = true } } }))
end

-- ---------------------------------------------------------------- fix round 4: footers, titles, toast (G5)
do
  local w = H.world()
  local c = w:client({ guild = G })
  c:login()
  local D = c.DT
  local pad = D.style("spacing.pad")
  local one = D.viewport({ id = "f1", title = "F1", width = 420, footer = "Short." })
  local function bottom(vp) for _, p in ipairs(vp.body.points) do if p[1] == "BOTTOMRIGHT" then return p[5] end end end
  check("G5 footer: a block between the paddings", D.textRecord(one.footer).kind == "block" and one.footer.w == 420 - 2 * pad
    and one.footer.text == "Short.")
  check("G5 footer: the body inset by the footer's measured height (one line)", one.footerH == 10 and bottom(one) == pad + 10)
  local long = string.rep("Only guildies running the addon. ", 4)
  local two = D.viewport({ id = "f2", title = "F2", width = 420, footer = long })
  check("G5 footer: a longer footer wraps inside the width, the body inset by all of it", two.footerH == 20
    and bottom(two) == pad + 20 and D.textRecord(two.footer).boxH == 20)
  local none = D.viewport({ id = "f3", title = "F3", width = 420 })
  check("no footer: the body reaches the padding", bottom(none) == pad and none.footer == nil)
  check("DT.viewport: a number as footer raises (text only)", not pcall(D.viewport, { id = "f4", footer = 16 }))
  check("title: a line ending left of the close button", D.textRecord(one.title).kind == "line"
    and one.title.w == 420 - pad - 4 - 32 - 4)
  -- the toast: a block, its height from the text
  c:slash("set ui nope on")
  c:slash("toast test")
  local t = c:frame("DeadTiredToast")
  check("toast: its text is a block; one line: the 0.3.0 size", D.textRecord(t.text).kind == "block" and t.w == 280 and t.h == 44)
  D.module({ id = "toasty", settings = { { key = "on", type = "bool", default = true, label = "T", desc = "T." } } })
  D.toast("toasty", "on", string.rep("Rest in Pieces. ", 7))
  check("toast: a longer text: the toast grows to fit it", t.h == 36 + 24 and D.textRecord(t.text).boxH == 36)
end

H.finish("ui")
