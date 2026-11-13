-- Offline checks for SettingsView.lua: the settings viewport builds itself from the registry; a
-- change there shows in /dt get, a /dt set shows there; the entry points (/dt settings, the game's
-- Settings -> AddOns page, the addon compartment).  lua5.1 DeadTired/tests/test_settingsview.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"

local w = H.world()
local c = w:client({ guild = G })
c:login()
local DT = c.DT

check("Settings -> AddOns: a Dead Tired page registered", c.settingsCat and c.settingsCat.name == "Dead Tired"
  and c.addOnCategory == c.settingsCat and c.settingsCat.frame == c:frame("DeadTiredSettingsPanel"))
check("the .toc names the compartment function", (function()
  for line in io.lines(H.addonDir .. "/DeadTired.toc") do
    if line:match("^## AddonCompartmentFunc: DeadTired_OnAddonCompartmentClick") then return true end
  end
end)())
check("the compartment function is DT's own global", type(rawget(c.env, "DeadTired_OnAddonCompartmentClick")) == "function")

c.env.DeadTired_OnAddonCompartmentClick("DeadTired", "LeftButton")
local vpf = c:frame("DeadTiredViewport_settings")
check("the compartment opens the settings viewport", vpf and vpf.shown)
vpf:Hide()
-- the page's button
local button
for _, f in ipairs(c.frames) do if f._parent == c:frame("DeadTiredSettingsPanel") and f.text == "Open Dead Tired settings" then button = f end end
button.scripts.OnClick(button)
check("the Settings page's button opens it", vpf.shown)
vpf:Hide()
c:slash("settings")
check("/dt settings opens it", vpf.shown)

-- every setting has a row in plain words, with its /dt line or where it lives
local rows = {}
for _, f in ipairs(c.frames) do
  if f._type == "FontString" and type(f.text) == "string" and f.text:find("^/dt set ") then rows[#rows + 1] = f.text end
end
local total, typed, notTyped = 0, 0, 0
for id, reg in pairs(DT.settings) do
  for _, s in ipairs(reg.list) do
    total = total + 1
    if DT.typed(s) then typed = typed + 1 else notTyped = notTyped + 1 end
  end
end
check("one /dt line per typed setting", #rows == typed)
local notTypedLines = 0
for _, f in ipairs(c.frames) do
  if f._type == "FontString" and type(f.text) == "string" and f.text:find("^Not typed: ") then notTypedLines = notTypedLines + 1 end
end
check("and a 'Not typed: <where>' line for each one that isn't", notTypedLines == notTyped and notTyped >= 2)
local function fs(text) for _, f in ipairs(c.frames) do if f._type == "FontString" and f.text == text then return f end end end
check("labels and plain-word descriptions shown", fs("Welcome line") and fs(DT.setting("guild", "welcome").desc)
  and fs(DT.setting("who", "hello").desc))
check("a hint names the dedicated verb too", fs("/dt set bar mode <value>  or  /dt bar on|off|auto") ~= nil)

-- a change there shows in /dt get
local check_, choice
for _, f in ipairs(c.frames) do
  if f._type == "CheckButton" and f._parent and f._parent.c and not check_ then
    -- the welcome row's checkbox: the first CheckButton (guild is the first card)
    check_ = f
  end
  if f._type == "Button" and f._template == "UIPanelButtonTemplate" and f.text == "clean" then choice = f end
end
check("the welcome checkbox reads the setting", check_ and check_:GetChecked() == true)
check_:SetChecked(false); check_.scripts.OnClick(check_)
c:slash("get guild welcome")
check("changed in the viewport: /dt get shows it", c:said("guild.welcome = off") ~= nil)
c:slash("set guild welcome on")
check("changed with /dt set: the viewport shows it", check_:GetChecked() == true)
choice.scripts.OnClick(choice)
check("a choice cycles through DT.set", DT.get("core", "skin") == "deadtired" and choice.text == "deadtired")

-- search
local search = c:frame("DeadTiredViewport_settings")
local box
for _, f in ipairs(c.frames) do if f._type == "EditBox" and f._parent == search then box = f end end
box:SetText("HELLO"); box.scripts.OnTextChanged(box)
local shownLabels = 0
for _, f in ipairs(c.frames) do
  if f._type == "Frame" and f.shown and f._parent and f._parent._parent and f._parent._parent._parent == search then
    shownLabels = shownLabels + 1
  end
end
check("searching the settings filters the cards (case-insensitive)", shownLabels == 3)   -- the Who card, its switch (says hello) and its hello row
c:slash("settings who")
check("/dt settings <words> opens it searched", box.text == "who")

-- outside the guild nothing opens
local w2 = H.world()
local o = w2:client({ guild = "Elsewhere" })
o:login()
o.env.DeadTired_OnAddonCompartmentClick()
check("outside the guild: the compartment opens nothing", o:frame("DeadTiredViewport_settings") == nil)

-- ---------------------------------------------------------------- Port 1: rows fit their text; first setting clear
do
  local w2 = H.world()
  local c2 = w2:client({ guild = G })
  c2:login()
  local D = c2.DT
  c2:slash("settings")
  local V = D._settingsView
  local rows2, setting = V.rows(), {}
  for _, r in ipairs(rows2) do if r.setting then setting[#setting + 1] = r end end
  -- defect 1: each row as tall as its label, wrapped description and hint; none overlaps the next
  local fits, overlap, prev = true, false, nil
  for _, r in ipairs(setting) do
    if r.frame.shown then
      local need = 2 + D.textHeight(r.label, nil) + 2 + D.textHeight(r.desc, nil) + 2 + D.textHeight(r.hint, nil) + 6
      if r.frame.h < need then fits = false; print("  too short: " .. r.setting.module .. "." .. r.setting.key .. " " .. r.frame.h .. " < " .. need) end
      if prev and r.top < prev.top + prev.frame.h then overlap = true end
      prev = r
    end
  end
  check("defect 1: every settings row is at least as tall as its wrapped text", fits)
  check("defect 1: no row starts inside the one above", not overlap)
  local long, short
  for _, r in ipairs(setting) do
    if r.setting.module == "crypt" and r.setting.key == "share" then long = r end
    if r.setting.module == "core" and r.setting.key == "windows" then short = r end
  end
  check("defect 1: a long description makes a taller row than a short one", long.frame.h > short.frame.h)
  check("defect 1: the description wraps at its width (not cut)", long.desc.w > 0 and D.textHeight(long.desc, long.desc.w) > 12)
  check("the row height model", D.settingsRowHeight(12, 36, 12, 0) == 72 and D.settingsRowHeight(1, 1, 1, 0) == 30
    and D.settingsRowHeight(12, 12, 12, 2) == 92)
  -- defect 2: the first setting is clear of the search box
  local vp2 = V.vp()
  local first = setting[1]
  local searchBottom = D.style("spacing.pad") + 22 + D.SEARCH_H
  check("defect 2: the body starts below the search box with a gap", vp2.top >= searchBottom + 6)
  check("defect 2: the first setting (the welcome line) is the first row, clear of the body's top",
    first.setting.module == "guild" and first.setting.key == "welcome" and first.top > 0 and first.frame.shown)
  -- the cause found: a scroll left over moved the content above the body; a search or reopen now puts it back
  vp2.body.h = 100
  vp2.body.scripts.OnMouseWheel(vp2.body, -3)
  local _, _, _, _, y = V.vp().content:GetPoint(1)
  check("scrolling moves the content", V.scroll() > 0 and y == V.scroll())
  vp2.frame:Hide()
  c2:slash("settings")
  _, _, _, _, y = V.vp().content:GetPoint(1)
  check("defect 2: reopened, the content is back at the top (the first setting visible)", V.scroll() == 0 and y == 0)
  vp2.body.scripts.OnMouseWheel(vp2.body, -3)
  vp2.search:SetText("welcome"); vp2.search.scripts.OnTextChanged(vp2.search)
  _, _, _, _, y = V.vp().content:GetPoint(1)
  check("defect 2: a search after a scroll starts at the top too", V.scroll() == 0 and y == 0)
  -- skins: both
  c2:slash("skin forever")
  check("the gap holds in the Forever skin", D.bodyTop(true) >= D.style("spacing.pad") + 22 + D.SEARCH_H + 6)
end


-- ---------------------------------------------------------------- fix round 4: the cards' text (R-F4-1)
do
  local w2 = H.world()
  local c2 = w2:client({ guild = "DEAD TIRED" })
  c2:login()
  c2:slash("settings")
  local D2 = c2.DT
  local labels, blocks, headers, boxed = 0, 0, 0, true
  for _, r in ipairs(D2._settingsView.rows()) do
    if r.header then
      if D2.textRecord(r.text).kind == "line" and D2.textRecord(r.text).role == "title" then headers = headers + 1 end
    else
      if D2.textRecord(r.label).kind == "line" then labels = labels + 1 end
      if D2.textRecord(r.desc).kind == "block" and D2.textRecord(r.hint).kind == "block" then blocks = blocks + 1 end
      if r.frame.shown and (D2.textRecord(r.desc).boxH or 0) < r.desc:GetStringHeight() then boxed = false end
    end
  end
  local n = #D2._settingsView.rows() - headers
  check("settings: every label a line, every description and hint a block, every module title a line",
    labels == n and blocks == n and headers > 10)
  check("settings: every shown description sized from its measured height (P1-H5 kept)", boxed)
  local five = 0
  for _, id in ipairs({ "gank", "played", "stash", "events", "logs" }) do
    local s = D2.setting(id, "enabled")
    if s and s.label == "On" and D2.get(id, "enabled") == true then five = five + 1 end
  end
  check("R-F4-5: Gank, Played, Stash, Events and Logs each have an On card, all on", five == 5)
end

H.finish("settingsview")
