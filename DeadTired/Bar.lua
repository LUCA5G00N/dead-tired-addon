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
-- R-P4 (Port 1): what the bar shows is an ordered list, saved in DeadTiredDB.bar ({ order = {names},
-- on = {[name] = bool} }). DT's own objects are ticked from the start (one declared offByDefault,
-- the Session object, waits to be ticked); every other addon's object is listed unticked, a newly
-- seen one at the bottom. The bar follows the order. Settings card (tick, drag by the grip) and
-- /dt bar add|remove|move|list. An object with visible = fn answering false (Recruit, for
-- non-officers) is neither drawn nor listed.
-- Text: other addons' colour codes are shown, not escaped (fw1 walk defect 3). DT.barText keeps
-- colour codes, textures and hyperlinks, and escapes every other "|" sequence.
-- Port 2 (the Port 1 walk's defect 2): the list (settings card, /dt bar list) names each object by
-- its name, never its live text: an object's label if it has one (DT's own carry their module's
-- title), else its registered name ("BugSack", not "0").
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

local known                       -- fn(name, own, offByDefault): the name in the saved order

function DT.object(name, def)
  local o = byName[name]
  if not o then
    o = {}
    byName[name] = o
    DT.objects[#DT.objects + 1] = { name = name, obj = o, own = true }
  end
  for k, v in pairs(def) do o[k] = v end
  o.type = o.type or "launcher"
  if known then known(name, true, o.offByDefault) end
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
  if known then known(name, false) end
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

-- ---------------------------------------------------------------- the list (R-P4)

local function store()
  local db = DT.db()
  if type(db.bar) ~= "table" then db.bar = {} end
  local b = db.bar
  if type(b.order) ~= "table" then b.order = {} end
  if type(b.on) ~= "table" then b.on = {} end
  return b
end

-- Put a name in the saved order (at the bottom) the first time it is seen, with its default tick:
-- on for DT's own (unless offByDefault), off for every other addon's.
known = function(name, own, offByDefault)
  if not DT.loaded then return end
  local b = store()
  for _, n in ipairs(b.order) do if n == name then return end end
  b.order[#b.order + 1] = name
  if b.on[name] == nil then
    b.on[name] = own and not offByDefault or false                       -- guard: others unticked by default
  end
end

local function entryOf(name)
  local o = byName[name]
  if o then return { name = name, obj = o, own = true } end
  local x = otherByName[name]
  if x then return { name = name, obj = x, own = false } end
  return nil
end

local function shownToMe(e)
  local v = e.obj.visible
  if type(v) ~= "function" then return true end
  local ok, yes = pcall(v)
  return ok and yes == true
end

-- Every object present this session, in the saved order: { name, obj, own, on }.
function DT.barList()
  local b = store()
  for _, e in ipairs(DT.objects) do known(e.name, true, e.obj.offByDefault) end
  for _, e in ipairs(others) do known(e.name, false) end
  local list = {}
  for _, name in ipairs(b.order) do
    local e = entryOf(name)
    if e and shownToMe(e) then
      e.on = b.on[name] == true
      list[#list + 1] = e
    end
  end
  return list
end

-- What the bar draws: the ticked ones, in order.
local function entries()
  local out = {}
  for _, e in ipairs(DT.barList()) do if e.on then out[#out + 1] = e end end
  return out
end

-- An object's name for the list: its label (plain), else its registered name. Never its text.
local function plain(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function nameOf(e)
  local l = type(e.obj.label) == "string" and DT.trim(plain(e.obj.label)) or ""
  if l ~= "" then return l end                                             -- guard: the list shows names, not text
  return e.name
end
DT.barName = nameOf

-- A name as typed ("atlasloot", "Dead Tired", "who"): the object's name, else its plain label.
function DT.barFind(typed)
  typed = (DT.trim(typed) or ""):lower()
  if typed == "" then return nil end
  local list = DT.barList()
  for _, e in ipairs(list) do if e.name:lower() == typed then return e, list end end
  for _, e in ipairs(list) do
    if nameOf(e):lower() == typed then return e, list end
  end
  return nil, list
end

function DT.barTick(name, on)
  local b = store()
  b.on[name] = on and true or false
  if refresh then refresh() end
  DT.signal("barlist")
  return true
end

-- Move name to position n (1 = leftmost) among the objects present this session.
function DT.barMove(name, n)
  local list = DT.barList()
  local from
  for i, e in ipairs(list) do if e.name == name then from = i end end
  if not from then return false end
  n = math.floor(tonumber(n) or from)
  if n < 1 then n = 1 end
  if n > #list then n = #list end
  local e = table.remove(list, from)
  table.insert(list, n, e)
  local b, order, present = store(), {}, {}
  for _, x in ipairs(list) do order[#order + 1] = x.name; present[x.name] = true end
  for _, old in ipairs(b.order) do if not present[old] then order[#order + 1] = old end end
  b.order = order
  if refresh then refresh() end
  DT.signal("barlist")
  return true, n
end

DT.barEntries = entries

-- Text from another addon, for a bar button: its colour codes (|cAARRGGBB, |r), textures (|T..|t)
-- and hyperlinks (|H..|h..|h) are kept; any other "|" is escaped; control bytes go. At most `max`
-- visible characters; an open colour is closed.
function DT.barText(s, max)
  s = tostring(s == nil and "" or s):gsub("[%z\1-\31]", "")
  max = max or 40
  local out, i, shown, n, open = {}, 1, 0, #s, false
  while i <= n and shown < max do
    local ch = s:sub(i, i)
    if ch ~= "|" then
      out[#out + 1] = ch; shown = shown + 1; i = i + 1
    else
      local nx = s:sub(i + 1, i + 1)
      local colour = s:match("^|c%x%x%x%x%x%x%x%x", i)
      local tex = nx == "T" and s:match("^|T[^|]*|t", i)
      local link = nx == "H" and s:match("^|H[^|]*|h[^|]*|h", i)
      if colour then out[#out + 1] = colour; i = i + #colour; open = true   -- guard: colour codes pass
      elseif nx == "r" then out[#out + 1] = "|r"; i = i + 2; open = false
      elseif tex then out[#out + 1] = tex; i = i + #tex; shown = shown + 1
      elseif link then out[#out + 1] = link; i = i + #link; shown = shown + 1
      elseif nx == "|" then out[#out + 1] = "||"; i = i + 2; shown = shown + 1
      else out[#out + 1] = "||"; i = i + 1; shown = shown + 1 end          -- anything else: escaped
    end
  end
  local t = table.concat(out)
  if i <= n then t = t .. "..." end
  if open then t = t .. "|r" end
  return t
end

local function button(i)
  local b = buttons[i]
  if b then return b end
  b = CreateFrame("Button", nil, bar)
  b:SetHeight(DT.style("spacing.barHeight") - 4)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(16, 16)
  b.icon:SetPoint("LEFT", b, "LEFT", 2, 0)
  -- fix round 4: a label (one line, unbounded): the button is sized from its text
  b.text = DT.text(b, "label", { role = "small", inset = 22 })
  b.text:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function(self, which)
    local o = self.entry and self.entry.obj
    if o and type(o.OnClick) == "function" then o.OnClick(self, which) end
  end)
  b.isBarButton = true
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
  bar.dtWindow = "bar"
  bar:SetHeight(DT.style("spacing.barHeight"))
  bar:SetFrameStrata("MEDIUM")
  bar:Hide()
  DT.restorePlace(bar, "bar", { "TOP", "TOP", 0, -4 })
  DT.draggable(bar, "bar")
  DT.skin(function()
    DT.paint(bar, true)
    if refresh then refresh() end         -- fix round 4: the buttons re-sized to the new lettering
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
    DT.setText(b.text, e.own and DT.safe(o.text or o.label or e.name, 40) or DT.barText(o.text or o.label or e.name, 40))
    DT.fontTo(b.text, "small")            -- fonted before it is measured (the bar repaints before its labels)
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

local function label(e) return DT.safe(nameOf(e), 32) end

local function listLine()
  local parts = {}
  for i, e in ipairs(DT.barList()) do
    parts[#parts + 1] = i .. " " .. label(e) .. (label(e):lower() ~= e.name:lower() and (" (" .. DT.safe(e.name, 32) .. ")") or "")
      .. (e.on and " [on]" or " [off]")
  end
  return "bar.list: " .. (#parts > 0 and table.concat(parts, ", ") or "nothing")
end

local function tickVerb(on)
  return function(args)
    local e = DT.barFind(args)
    if not e then return DT.out("bar.list: no " .. DT.safe(args, 32) .. ". /dt bar list") end
    DT.barTick(e.name, on)
    return DT.out("bar." .. DT.safe(e.name, 32) .. " = " .. (on and "on" or "off"))
  end
end

local function moveVerb(args)
  local name, n = (args or ""):match("^(.-)%s+(%d+)$")
  local e = name and DT.barFind(name)
  if not e then return DT.out("/dt bar move <name> <position>. /dt bar list") end
  local _, at = DT.barMove(e.name, tonumber(n))
  return DT.out("bar." .. DT.safe(e.name, 32) .. " at " .. at)
end

DT.module({
  id = "bar",
  title = "Launcher bar",
  settings = {
    { key = "mode", type = "choice", choices = { "auto", "on", "off" }, default = "auto", label = "Bar",
      verb = "bar on|off|auto", onChange = function() evaluate() end,
      desc = "The Dead Tired bar: Dead Tired's buttons, and other addons' when their library is loaded. Auto hides it while Titan Panel or another bar addon is loaded." },
    { key = "objects", type = "list", label = "On the bar",
      desc = "What the bar shows, left to right as listed here. Dead Tired's own are ticked; other addons' wait unticked until you tick them. Drag a row by its grip to move it.",
      noVerb = "typed as /dt bar add|remove|move|list",
      items = function()
        local out = {}
        for _, e in ipairs(DT.barList()) do
          out[#out + 1] = { name = e.name, label = label(e), on = e.on, tip = e.own and "Dead Tired" or e.name }
        end
        return out
      end,
      toggle = function(name, on) DT.barTick(name, on) end,
      move = function(name, n) DT.barMove(name, n) end },
    { key = "place", type = "position", label = "Bar place", desc = "Where the bar sits. Kept through reloads.",
      noVerb = "drag the bar to move it" },
  },
  verbs = { { verb = "bar", usage = "bar on|off|auto", fn = barVerb },
    { verb = "bar list", usage = "bar list", fn = function() DT.out(listLine()) end },
    { verb = "bar add", usage = "bar add <name>", fn = tickVerb(true) },
    { verb = "bar remove", usage = "bar remove <name>", fn = tickVerb(false) },
    { verb = "bar move", usage = "bar move <name> <n>", fn = moveVerb } },
  fit = function()
    if not bar then build() end
    refresh()
  end,
  init = function()
    DT.object("DeadTired", { type = "launcher", text = "Dead Tired", label = "Dead Tired", icon = ICON,
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
DT.barRefresh = function() if refresh then refresh() end end
DT.listen("loaded", function()
  for _, m in ipairs(DT.modules) do
    if m.ldb then
      if m.ldb.label == nil then m.ldb.label = m.title end
      DT.object(m.id, m.ldb)
    end
  end
end)

DT._bar = { INTRO = INTRO, frame = function() return bar end, others = function() return others end,
  proxies = function() return proxies end, buttons = function() return buttons end,
  store = function() return store() end }
