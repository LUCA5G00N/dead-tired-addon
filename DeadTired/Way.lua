-- Dead Tired: the Waypointer (dt_waypointer, 0.5.0; docs/COWORK_BRIEF_dt_waypointer.md, rulings W1-W7
-- ratified by Tim's merge of PR #36, 22 Nov 2026). Block F (F1-F4, 20 Nov); F6 and the F5 probe, 22 Nov.
--
-- W1 Where to: /dt way <x> <y> [zone] (0-100, the zone by name or unique prefix, else the zone you're
--    in), or /dt way list: the built-in list, round one the 39 library books (WayBooks.lua).
-- W2 Blizzard's pin: C_Map.SetUserWaypoint, then tracked, only where CanSetUserWaypointOnMap says yes;
--    cleared only while the pin is still the one DT set.
-- W3 Our arrow: a needle, "<n> yd", and the place under it (two lines, so the yards are never cut), from the client's map positions and facing, every read
--    guarded; a secret or missing read hides the needle for that update. At most 10 updates a second.
-- W4 way.arrow and way.pin, both on. W5 Within 5 yards it clears itself; /dt way clear any time.
-- W6 One waypoint per character, saved (a /reload keeps it); never shared: no messages.
-- No hook, no library, no write to a Blizzard frame. Nothing from OpenMap, TomTom or HereBeDragons.
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local TICK = 0.1             -- seconds between arrow updates (W3)
local ARRIVE = 5             -- yards (W5)
local CAP = 50               -- characters with a saved waypoint
local LABEL_MAX = 48
local TEXTURE = "Interface\\Minimap\\MinimapArrow"
local ROOTS = { 947, 1414, 1415 }   -- Azeroth, Kalimdor, the Eastern Kingdoms: where zones are listed from
local ZONE_TYPE = 3                 -- Enum.UIMapType.Zone (read from Enum when the client has it)
local OFF = "way.enabled = off"
local USAGE = "/dt way <x> <y> [zone], /dt way list, /dt way clear, /dt way arrow|pin on|off"
local NO_PIN = "No map pin there; the arrow will do."
local BOTH_OFF = "Arrow and pin are both off."
local THERE = "You're there."
local CLEARED = "Waypoint cleared."
local NONE = "No waypoint set."
local EMPTY = "No books match."
local NOWHERE = "Can't tell where you are. Try again outdoors."

-- ---------------------------------------------------------------- the store (W6)

local function store()
  local db = DT.db()
  if type(db.way) ~= "table" then db.way = {} end
  local s = db.way
  if type(s.current) ~= "table" then s.current = {} end
  return s
end
DT.wayStore = store

local function valid(w)
  return type(w) == "table" and type(w.map) == "number" and type(w.x) == "number" and type(w.y) == "number"
    and w.x >= 0 and w.x <= 1 and w.y >= 0 and w.y <= 1
end

local function current()
  local me = DT.myKey()
  if not me then return nil end
  local w = store().current[me]
  if valid(w) then return w, me end
  return nil, me
end
DT.wayCurrent = current

local function capStore(keep)
  local c = store().current
  local n = 0
  for _ in pairs(c) do n = n + 1 end
  while n > CAP do                                                         -- guard: store cap
    local oldK, oldT
    for k, w in pairs(c) do
      local t = type(w) == "table" and type(w.t) == "number" and w.t or -1
      if k ~= keep and (not oldK or t < oldT or (t == oldT and k < oldK)) then oldK, oldT = k, t end
    end
    if not oldK then break end
    c[oldK] = nil
    n = n - 1
  end
end

-- ---------------------------------------------------------------- zones (W1)

local zones                  -- lower-case name -> { { id, name }, ... }, built once

local function zoneIndex()
  if zones then return zones end
  local idx, seen, any = {}, {}, false
  local ztype = (type(Enum) == "table" and type(Enum.UIMapType) == "table" and Enum.UIMapType.Zone) or ZONE_TYPE
  for _, root in ipairs(ROOTS) do
    local kids = clean(try(C_Map and C_Map.GetMapChildrenInfo, root, ztype, true))
    if type(kids) == "table" then
      for _, m in ipairs(kids) do
        local id, name = type(m) == "table" and clean(m.mapID), type(m) == "table" and clean(m.name)
        if type(id) == "number" and type(name) == "string" and name ~= "" and not seen[id] then
          seen[id] = true
          any = true
          local k = name:lower()
          idx[k] = idx[k] or {}
          table.insert(idx[k], { id = id, name = name })
        end
      end
    end
  end
  if any then zones = idx end                                              -- an empty answer is asked again next time
  return idx
end
DT._wayZones = function() zones = nil end

-- A zone name (or unique prefix) -> id, name | nil, reason ("none" or "many").
function DT.wayZone(text)
  local q = (DT.trim(text) or ""):lower()
  if q == "" then return nil, "none" end
  local idx = zoneIndex()
  local exact = idx[q]
  if exact and #exact == 1 then return exact[1].id, exact[1].name end
  if exact and #exact > 1 then return nil, "many" end
  local hit, n = nil, 0
  for k, list in pairs(idx) do
    if k:sub(1, #q) == q then
      n = n + #list
      hit = list[1]
    end
  end
  if n == 1 then return hit.id, hit.name end
  if n > 1 then return nil, "many" end                                     -- guard: ambiguous zone refused
  return nil, "none"
end

local function mapName(id)
  local info = clean(try(C_Map and C_Map.GetMapInfo, id))
  local n = type(info) == "table" and clean(info.name)
  return type(n) == "string" and n or "?"
end

local function here()
  local m = clean(try(C_Map and C_Map.GetBestMapForUnit, "player"))
  return type(m) == "number" and m or nil
end

-- ---------------------------------------------------------------- parsing (W1)

-- "45.2 61.8 [zone]" or "45.2, 61.8 [zone]" -> x, y (0-100), zone text | nil
function DT.wayParse(args)
  local s = DT.trim(args) or ""
  local x, y, rest = s:match("^(%-?[%d%.]+)%s*,%s*(%-?[%d%.]+)%s*(.-)$")
  if not x then x, y, rest = s:match("^(%-?[%d%.]+)%s+(%-?[%d%.]+)%s*(.-)$") end
  x, y = tonumber(x), tonumber(y)
  if not x or not y then return nil end
  if x < 0 or x > 100 or y < 0 or y > 100 then return nil end              -- guard: coordinate range
  return x, y, (rest ~= "" and rest or nil)
end

-- ---------------------------------------------------------------- the pin (W2)

local function point(map, x, y)
  if type(UiMapPoint) ~= "table" then return nil end
  return clean(try(UiMapPoint.CreateFromCoordinates, map, x, y))
end

local function xy(v)
  if type(v) ~= "table" then return nil end
  local x, y = try(v.GetXY, v)
  x, y = clean(x), clean(y)
  if type(x) ~= "number" or type(y) ~= "number" then return nil end
  return x, y
end

-- Is Blizzard's pin still the one DT set for w?
local function ours(w)
  if not w or not w.pinned then return false end
  local p = clean(try(C_Map and C_Map.GetUserWaypoint))
  if type(p) ~= "table" or clean(p.uiMapID) ~= w.map then return false end
  local px, py = xy(p.position)
  return px ~= nil and math.abs(px - w.x) < 0.0005 and math.abs(py - w.y) < 0.0005
end

local function setPin(w)
  if DT.get("way", "pin") ~= true then return false end
  local can = clean(try(C_Map and C_Map.CanSetUserWaypointOnMap, w.map))
  if can ~= true then DT.out(NO_PIN) return false end                     -- guard: CanSetUserWaypointOnMap
  local p = point(w.map, w.x, w.y)
  local f = C_Map and C_Map.SetUserWaypoint
  if not p or type(f) ~= "function" or not pcall(f, p) then DT.out(NO_PIN) return false end
  local st = C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint
  if type(st) == "function" then pcall(st, true) end
  w.pinned = true
  return true
end

local function clearPin(w)
  if not ours(w) then return false end                                     -- guard: clear only ours
  local f = C_Map and C_Map.ClearUserWaypoint
  if type(f) == "function" then pcall(f) end
  w.pinned = nil
  return true
end

-- ---------------------------------------------------------------- the arrow (W3)

local arrow, needle, line, place
local acc = 0
local clearWay

local function worldOf(map, v)
  if type(v) ~= "table" then return nil end
  local c, wpos = try(C_Map and C_Map.GetWorldPosFromMapPos, map, v)
  c = clean(c)
  local wx, wy = xy(wpos)
  if type(c) ~= "number" or not wx then return nil end
  return c, wx, wy
end

local function yards(n)
  local s = tostring(math.floor(n + 0.5))
  while true do
    local k
    s, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
    if k == 0 then return s end
  end
end

-- One reading: dist (yards), rel (radians, counter-clockwise from straight ahead), state.
-- state: "ok", "far" (another continent), "lost" (a read missing or secret).
function DT.wayReading(w)
  local m = here()
  if not m then return nil, nil, "lost" end
  local pos = clean(try(C_Map and C_Map.GetPlayerMapPosition, m, "player"))
  local pc, px, py = worldOf(m, pos)
  if not pc then return nil, nil, "lost" end                               -- guard: a secret or missing read hides the needle
  local target = point(w.map, w.x, w.y)
  local tc, tx, ty = worldOf(w.map, target and target.position)
  if not tc then return nil, nil, "lost" end
  if tc ~= pc then return nil, nil, "far" end
  local facing = clean(try(GetPlayerFacing))
  if type(facing) ~= "number" then return nil, nil, "lost" end
  local dn, dw = tx - px, ty - py                                          -- world X runs north, Y runs west
  local dist = math.sqrt(dn * dn + dw * dw)
  local rel = math.atan2(dw, dn) - facing
  rel = rel % (2 * math.pi)
  return dist, rel, "ok"
end

local function hideArrow()
  if arrow then arrow:Hide() end
end

local function update()
  local w = current()
  if not w then hideArrow() return end
  local dist, rel, state = DT.wayReading(w)
  local label = DT.safe(w.label, LABEL_MAX)
  if state == "ok" then
    if dist <= ARRIVE then                                                 -- guard: arrival radius
      clearWay(true)
      return
    end
    needle:Show()
    needle:SetRotation(rel)
    DT.setText(line, yards(dist) .. " yd")
  elseif state == "far" then
    needle:Hide()
    DT.setText(line, "another continent")
  else
    needle:Hide()
    DT.setText(line, "\226\128\166")
  end
  DT.setText(place, label)
end
DT._wayUpdate = function() update() end

local function arrowOn() return DT.get("way", "arrow") == true end

local function build()
  if arrow then return end
  arrow = CreateFrame("Frame", "DeadTiredWayArrow", UIParent)
  arrow:SetSize(180, 78)
  arrow:SetFrameStrata("MEDIUM")
  arrow:Hide()
  DT.restorePlace(arrow, "way.arrow", { "TOP", "TOP", 0, -140 })
  DT.draggable(arrow, "way.arrow")
  needle = arrow:CreateTexture(nil, "ARTWORK")
  needle:SetSize(40, 40)
  needle:SetPoint("TOP", arrow, "TOP", 0, 0)
  needle:SetTexture(TEXTURE)
  -- (two lines: the distance, which must never be cut, and the place under it, cut with "…" if long)
  line = DT.text(arrow, "line", { width = 180, justify = "CENTER", window = "way" })
  line:SetPoint("TOP", needle, "BOTTOM", 0, -2)
  place = DT.text(arrow, "line", { width = 180, justify = "CENTER", role = "small", colour = "muted", window = "way" })
  place:SetPoint("TOP", line, "BOTTOM", 0, -1)
  arrow:SetScript("OnUpdate", function(_, elapsed)
    if not arrow:IsShown() or not current() then return end                -- guard: hidden does nothing
    acc = acc + (tonumber(elapsed) or 0)
    if acc < TICK then return end                                          -- guard: OnUpdate throttle
    acc = 0
    update()
  end)
end

local function showArrow()
  if not arrowOn() or not DT.enabled("way") or not DT.isMember() then hideArrow() return end
  if not current() then hideArrow() return end
  build()
  acc = TICK
  arrow:Show()
  update()
end

-- ---------------------------------------------------------------- set and clear (W5, W6)

clearWay = function(arrived)
  local w, me = current()
  if not w then return false end
  clearPin(w)
  store().current[me] = nil
  hideArrow()
  DT.out(arrived and THERE or CLEARED)
  return true
end

function DT.waySet(map, x, y, label)
  if not DT.isMember() or not DT.enabled("way") then return false end    -- guard: guild gate and module switch (set)
  local me = DT.myKey()
  if not me then return false end
  local old = current()
  if old then clearPin(old) end
  local w = { map = map, x = x, y = y, label = DT.safe(label, LABEL_MAX), t = clean(try(time)) }
  store().current[me] = w
  capStore(me)
  local pinOn, arrowSet = DT.get("way", "pin") == true, arrowOn()
  if not pinOn and not arrowSet then
    DT.out(BOTH_OFF)
  else
    setPin(w)
    showArrow()
  end
  return true
end

-- ---------------------------------------------------------------- the list (W1)

local vp, list, model

function DT.wayRows()
  local rows = {}
  for i, b in ipairs(DT.WAY_BOOKS or {}) do
    local id = DT.wayZone(b[2])
    local coords = string.format("%.1f, %.1f", b[3], b[4])
    rows[#rows + 1] = { i = i, book = b, map = id, name = b[1], zone = id and b[2] or (b[2] .. " (zone not found)"),
      coords = coords, lvl = b[6] ~= "" and b[6] or "-", note = b[7],
      nameRGB = (not id) and { 0.5, 0.5, 0.5 } or nil,
      search = table.concat({ b[1], b[2], b[7] or "" }, " ") }
  end
  return rows
end

local function pick(row)
  if not row then return end
  if not row.map then return DT.out(row.book[2] .. ": zone not found.") end
  if DT.waySet(row.map, row.book[3] / 100, row.book[4] / 100, row.name) then
    DT.out("Waypoint: " .. DT.safe(row.name, LABEL_MAX) .. ", " .. DT.safe(row.book[2], 32) .. " " .. row.coords .. ".")
  end
end

local function buildList()
  if vp then return end
  model = DT.listModel()
  vp = DT.viewport({ id = "way", title = "Where to?", search = true, width = 520, height = 400,
    footer = DT.WAY_BOOKS_SOURCE,
    onSearch = function(text) model:filter(text); list.offset = 0; list:refresh() end })
  list = DT.list(vp.body, model, { count = 14, tipCovers = { "name" },
    empty = function(m) if #m:visible() == 0 then return EMPTY end end,
    onClick = function(row) pick(row) end,
    tip = function(row, tt)
      tt:AddLine(DT.safe(row.name, 64))
      if row.note and row.note ~= "" then tt:AddLine(DT.safe(row.note, 80), 0.8, 0.8, 0.8, true) end
      tt:AddLine("Click to set the waypoint.", 0.6, 0.6, 0.6)
    end,
    columns = { { key = "name", flex = true, rgb = "nameRGB" }, { key = "zone", fixed = true, colour = "muted" },
      { key = "coords", fixed = true }, { key = "lvl", fixed = true, colour = "muted" } } })
end

local function showList()
  if not DT.isMember() then return end
  buildList()
  model:set(DT.wayRows())
  list:refresh()
  vp:Show()
end

-- ---------------------------------------------------------------- the verb

local function setting(key, w)
  if w == "on" or w == "off" then
    DT.set("way", key, w == "on")
    if key == "arrow" then if w == "on" then showArrow() else hideArrow() end end
    if key == "pin" and w == "off" then local cur = current(); if cur then clearPin(cur) end end
    if key == "pin" and w == "on" then local cur = current(); if cur then setPin(cur) end end
    return DT.out("the " .. key .. " is " .. w .. ".")
  end
  return DT.out("the " .. key .. " is " .. (DT.get("way", key) and "on" or "off") .. ". /dt way " .. key .. " on|off")
end

local function verb(args)
  if not DT.enabled("way") then return DT.out(OFF) end                     -- guard: off verbs do nothing else (way)
  local a = DT.trim(args) or ""
  local lw = a:lower()
  if lw == "list" then return showList() end
  if lw == "clear" then if not clearWay(false) then DT.out(NONE) end return end
  local key, val = lw:match("^(arrow)%s*(%a*)$")
  if not key then key, val = lw:match("^(pin)%s*(%a*)$") end
  if key then return setting(key, val) end
  if a == "" then
    local w = current()
    if not w then return DT.out(NONE .. " " .. USAGE) end
    return DT.out("Waypoint: " .. DT.safe(w.label, LABEL_MAX) .. ".")
  end
  local x, y, zoneText = DT.wayParse(a)
  if not x then return DT.out(USAGE) end
  local map, name
  if zoneText then
    local why
    map, why = DT.wayZone(zoneText)
    if not map then
      return DT.out(why == "many" and ("More than one zone starts \"" .. DT.safe(zoneText, 32) .. "\". Type more of it.")
        or ("No zone called \"" .. DT.safe(zoneText, 32) .. "\"."))
    end
    name = why
  else
    map = here()
    if not map then return DT.out(NOWHERE) end
    name = mapName(map)
  end
  local label = string.format("%s %.1f, %.1f", name, x, y)
  if DT.waySet(map, x / 100, y / 100, label) then DT.out("Waypoint: " .. DT.safe(label, LABEL_MAX) .. ".") end
end

-- ---------------------------------------------------------------- the module

local entered = false

DT.module({
  id = "way",
  title = "Waypointer",
  optional = true,
  switchDesc = "The Waypointer: /dt way. Off, no arrow, no pin, no list.",
  settings = {
    { key = "arrow", type = "bool", default = true, label = "Arrow", verb = "way arrow on|off",
      onChange = function(v) if v then showArrow() else hideArrow() end end,
      desc = "Shows Dead Tired's arrow toward your waypoint, with the distance in yards. Drag it where you like." },
    { key = "pin", type = "bool", default = true, label = "Map pin", verb = "way pin on|off",
      desc = "Puts the game's own map pin on your waypoint (where the game allows one). Dead Tired only clears a pin it set." },
  },
  verbs = { { verb = "way", usage = "way <x> <y> [zone]|list|clear", fn = verb } },
  init = function() store() end,
  onDisable = function() hideArrow() end,
  onEnable = function() if entered then showArrow() end end,
  fit = function()
    buildList(); model:set(DT.wayRows()); list:refresh()
    build(); DT.setText(line, "another continent"); DT.setText(place, "Archmage Antonidas: The Unabridged Autobiography")
  end,
  events = {
    PLAYER_ENTERING_WORLD = function()
      entered = true
      local w = current()
      if not w then return end
      if DT.get("way", "pin") == true and not clean(try(C_Map and C_Map.HasUserWaypoint)) then setPin(w) end
      showArrow()
    end,
  },
})

-- For the offline tests only.
DT._way = { arrow = function() return arrow end, needle = function() return needle end, line = function() return line end,
  place = function() return place end,
  vp = function() return vp end, list = function() return list end, ours = ours, TICK = TICK, ARRIVE = ARRIVE, CAP = CAP,
  NO_PIN = NO_PIN, BOTH_OFF = BOTH_OFF, THERE = THERE, CLEARED = CLEARED, NONE = NONE, EMPTY = EMPTY, OFF = OFF,
  TEXTURE = TEXTURE, yards = yards }
