-- Offline checks for UI.lua: the list model (filtering as you type), the list view, the viewport
-- (position saved and restored, not closed by Escape, insecure), toasts gated by a setting.
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
  local L = c.DT.list(vp.body, m, { count = 3, columns = { { key = "search", width = 100 } } })
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
  check("viewport: Escape doesn't close it (nothing added to UISpecialFrames)", rawget(c.env, "UISpecialFrames") == nil)
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

-- ---------------------------------------------------------------- Port 1: rows fit wrapped text; empty line
do
  local w2 = H.world()
  local c2 = w2:client({ guild = "DEAD TIRED" })
  c2:login()
  local D = c2.DT
  check("rowHeight: the tallest cell plus padding", D.rowHeight({ 12, 36, 24 }, 18, 4) == 40)
  check("rowHeight: never under the minimum", D.rowHeight({ 2 }, 18, 4) == 18 and D.rowHeight({}, 18, 4) == 18)
  local fs = c2.env.UIParent:CreateFontString()
  fs:SetText(string.rep("x", 50))
  check("textHeight: wrapped at the width", D.textHeight(fs, 100) == 36 and D.textHeight(fs, 400) == 12)
  local m = D.listModel()
  local vp = D.viewport({ id = "t2", title = "T", search = true })
  local L = D.list(vp.body, m, { count = 4, empty = "Nothing here.", columns = { { key = "a", width = 60 } } })
  m:set({}); L:refresh()
  check("empty: the line shows when nothing is listed", L.empty.shown and L.empty.text == "Nothing here.")
  m:set({ { a = "short", search = "short" }, { a = string.rep("long ", 8), search = "long" }, { a = "x", search = "x" } }); L:refresh()
  check("empty: hidden once rows show", not L.empty.shown)
  local r1, r2, r3 = L.rows[1], L.rows[2], L.rows[3]
  check("rows: a long cell makes its row taller", r2.h > r1.h)
  check("rows: each row starts below the one above (no overlap)", r2.top == r1.top + r1.h and r3.top == r2.top + r2.h)
  check("viewport: the body starts under the search box with a gap", vp.top >= D.style("spacing.pad") + 22 + D.SEARCH_H + 6)
end

H.finish("ui")
