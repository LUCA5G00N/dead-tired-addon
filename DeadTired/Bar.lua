-- Dead Tired: the launcher bar and DT's data objects.
--
-- DT objects have an LDB-shaped interface ({ type, text, icon, OnClick(frame, button),
-- OnTooltipShow(tooltip) }) and live in DT.objects. DT draws them itself, natively.
-- LibDataBroker-1.1 is BORROWED, never bundled (no licence in its source; CLAUDE.md, ruled
-- 2026-11-11): when another addon has loaded it (LibStub("LibDataBroker-1.1", true)), DT registers
-- its objects there too, so any LDB display (Titan Panel...) shows them, and the bar also hosts
-- every other addon's LDB launcher and data source. When it isn't loaded, the bar shows DT's own
-- buttons only. DT never creates the library.
-- Shown: inside the guild, while bar.mode is "on", or "auto" (the default) with no LDB display
-- addon loaded (Config.DISPLAY_ADDONS): DT stands back for Titan-style hosts unless /dt bar on.
-- One intro line the first time it shows, ever. Dragged to move; the place is kept. It never hides
-- or moves another addon's minimap button.
local ADDON, ns = ...
local DT = ns.DT

local INTRO = "DeadTired's bar has risen. /dt bar off to bury it."
local OWN = "DeadTired_"          -- LDB names of DT's own objects
local ICON = [[Interface\Icons\Spell_Shadow_RaiseDead]]

DT.objects = {}                   -- ordered: { name, obj }
local byName = {}
local proxies = {}                -- DT object name -> its LDB data object
local others = {}                 -- ordered third-party LDB objects: { name, obj }
local otherByName = {}
local ldb = nil                   -- the borrowed library, once bound
local bar, buttons = nil, {}
local refresh

-- ---------------------------------------------------------------- objects

function DT.object(name, def)
  local o = byName[name]
  if not o then
    o = {}
    byName[name] = o
    DT.objects[#DT.objects + 1] = { name = name, obj = o }
  end
  for k, v in pairs(def) do o[k] = v end
  o.type = o.type or "launcher"
  if ldb and not proxies[name] then
    proxies[name] = ldb:NewDataObject(OWN .. name, def)
  end
  if refresh then refresh() end
  return o
end

function DT.update(name, field, value)
  local o = byName[name]
  if not o then return end
  o[field] = value
  if proxies[name] then proxies[name][field] = value end
  if refresh then refresh() end
end

-- ---------------------------------------------------------------- LibDataBroker, borrowed

local BAR = {}                    -- CallbackHandler owner for LDB callbacks

local function addOther(name, obj)
  if type(name) ~= "string" or name:sub(1, #OWN) == OWN then return end   -- DT's own are drawn natively
  if type(obj) ~= "table" or otherByName[name] then return end
  local t = obj.type
  if t ~= "launcher" and t ~= "data source" then return end
  otherByName[name] = obj
  others[#others + 1] = { name = name, obj = obj }
end

-- Bind to LibDataBroker if another addon loaded it. Returns the library or nil.
local function borrow()
  if ldb then return ldb end
  local lib = LibStub and LibStub("LibDataBroker-1.1", true)
  if type(lib) ~= "table" then return nil end                              -- guard: borrow only (LDB)
  ldb = lib
  for _, e in ipairs(DT.objects) do
    if not proxies[e.name] then
      local fields = {}
      for k, v in pairs(e.obj) do fields[k] = v end
      proxies[e.name] = lib:NewDataObject(OWN .. e.name, fields)
    end
  end
  if type(lib.DataObjectIterator) == "function" then
    for name, obj in lib:DataObjectIterator() do addOther(name, obj) end
  end
  if type(lib.RegisterCallback) == "function" then
    lib.RegisterCallback(BAR, "LibDataBroker_DataObjectCreated", function(_, name, obj)
      addOther(name, obj)
      if refresh then refresh() end
    end)
    lib.RegisterCallback(BAR, "LibDataBroker_AttributeChanged", function(_, name)
      if otherByName[name] and refresh then refresh() end
    end)
  end
  return ldb
end
DT.borrowLDB = borrow

-- ---------------------------------------------------------------- stand-back

function DT.displayAddon()
  for _, name in ipairs(DT.Config.DISPLAY_ADDONS or {}) do
    if DT.addonLoaded(name) then return name end
  end
  return nil
end

function DT.barWanted()
  if not DT.isMember() then return false end
  local mode = DT.get("bar", "mode")
  if mode == "off" then return false end
  if mode == "on" then return true end
  return DT.displayAddon() == nil                                          -- guard: stand-back
end

-- ---------------------------------------------------------------- the bar

local function entries()
  local list = {}
  for _, e in ipairs(DT.objects) do list[#list + 1] = e end
  for _, e in ipairs(others) do list[#list + 1] = e end
  return list
end
DT.barEntries = entries

local function button(i)
  local b = buttons[i]
  if b then return b end
  b = CreateFrame("Button", nil, bar)
  b:SetHeight(DT.style("spacing.barHeight") - 4)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(16, 16)
  b.icon:SetPoint("LEFT", b, "LEFT", 2, 0)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  b.text:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function(self, which)
    local o = self.entry and self.entry.obj
    if o and type(o.OnClick) == "function" then o.OnClick(self, which) end
  end)
  b:SetScript("OnEnter", function(self)
    local o = self.entry and self.entry.obj
    if not o then return end
    if type(o.OnTooltipShow) == "function" then
      local tt = DT.tooltip()
      tt:SetOwner(self, "ANCHOR_BOTTOM")
      o.OnTooltipShow(tt)
      tt:Show()
    elseif type(o.OnEnter) == "function" then
      o.OnEnter(self)
    end
  end)
  b:SetScript("OnLeave", function(self)
    local o = self.entry and self.entry.obj
    if DT._tooltip then DT._tooltip:Hide() end
    if o and type(o.OnLeave) == "function" then o.OnLeave(self) end
  end)
  DT.draggable(bar, "bar", b)
  buttons[i] = b
  return b
end

local function build()
  bar = CreateFrame("Frame", "DeadTiredBar", UIParent, "BackdropTemplate")
  bar:SetHeight(DT.style("spacing.barHeight"))
  bar:SetFrameStrata("MEDIUM")
  bar:Hide()
  DT.restorePlace(bar, "bar", { "TOP", "TOP", 0, -4 })
  DT.draggable(bar, "bar")
  DT.skin(function()
    DT.paint(bar, true)
    for _, b in ipairs(buttons) do DT.fontTo(b.text, "small") end
  end)
end

refresh = function()
  if not bar then return end
  local x = 6
  local list = entries()
  for i, e in ipairs(list) do
    local b = button(i)
    b.entry = e
    local o = e.obj
    b.icon:SetTexture(o.icon or ICON)
    b.text:SetText(DT.safe(o.text or o.label or e.name, 40))
    DT.fontTo(b.text, "small")
    local w = 24 + math.max(8, (b.text:GetStringWidth() or 40))
    b:SetWidth(w)
    b:ClearAllPoints()
    b:SetPoint("LEFT", bar, "LEFT", x, 0)
    b:Show()
    x = x + w + 4
  end
  for i = #list + 1, #buttons do buttons[i].entry = nil; buttons[i]:Hide() end
  bar:SetWidth(x + 2)
end

local function intro()
  local db = DT.db()
  if db.barIntroSaid or not (bar and bar:IsShown()) then return end        -- guard: intro once
  db.barIntroSaid = true
  DT.out(INTRO)
end

local entered = false
local function evaluate()
  borrow()
  local want = DT.barWanted()
  if want and not bar then build() end
  if bar then
    if want then refresh(); bar:Show() else bar:Hide() end
  end
  if entered then intro() end
end
DT.barEvaluate = evaluate

local function barVerb(args)
  local w = (args or ""):lower()
  if w ~= "on" and w ~= "off" and w ~= "auto" then
    return DT.out("bar.mode = " .. DT.get("bar", "mode") .. ". /dt bar on|off|auto")
  end
  DT.set("bar", "mode", w)
  return DT.out("bar.mode = " .. w)
end

DT.module({
  id = "bar",
  title = "Launcher bar",
  settings = {
    { key = "mode", type = "choice", choices = { "auto", "on", "off" }, default = "auto", label = "Bar",
      verb = "bar on|off|auto", onChange = function() evaluate() end,
      desc = "The Dead Tired bar: Dead Tired's buttons, and other addons' when their library is loaded. Auto hides it while Titan Panel or another bar addon is loaded." },
    { key = "place", type = "position", label = "Bar place", desc = "Where the bar sits. Kept through reloads.",
      noVerb = "drag the bar to move it" },
  },
  verbs = { { verb = "bar", usage = "bar on|off|auto", fn = barVerb } },
  init = function()
    DT.object("DeadTired", { type = "launcher", text = "Dead Tired", icon = ICON,
      OnClick = function(_, which) DT.openSettings(which == "RightButton" and "bar" or nil) end,
      OnTooltipShow = function(tt) tt:AddLine("Dead Tired"); tt:AddLine("/dt help", 1, 1, 1) end })
  end,
  events = {
    PLAYER_LOGIN = evaluate,
    ADDON_LOADED = function() if bar or DT.loaded then evaluate() end end,
    PLAYER_ENTERING_WORLD = function() entered = true; evaluate() end,
  },
})

DT.listen("member", function() evaluate() end)
DT.listen("loaded", function()
  for _, m in ipairs(DT.modules) do
    if m.ldb then DT.object(m.id, m.ldb) end
  end
end)

DT._bar = { INTRO = INTRO, frame = function() return bar end, others = function() return others end,
  proxies = function() return proxies end, buttons = function() return buttons end }
