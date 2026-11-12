-- Dead Tired: the gank diary. A button press on a target, never a kill detector.
-- Card 4 (docs/COWORK_BRIEF_dt_pvp.md on card/dt_pvp; R1-R3 ratified 2026-11-02), ported from rc3's
-- Gank.lua onto the framework in Port 2. Logic and lines are rc3's; what changed: full-name keys
-- (the enemy's full name from GetUnitName("target", true), with the surname; the realm only from that
-- name's "-Realm", else ours: never from UnitFullName or UnitName's second value), the store one
-- list (DeadTiredDB.gank.logs) instead of per guild, the board in a searchable viewport (most
-- frequent first; /dt ganks <name> still prints that enemy's lines), names without realm (R-P5).
--
-- R1 (a ruled "reads another player" exception): your target's name, realm, class and level, and
--     its faction (checked, never stored), read only when /dt gank is pressed. DT.gank() refuses
--     unless a typed /dt command is running it (Port 2: proved, not assumed).
-- R2 (a ruled "shares without a separate opt-in" exception): a log goes to the guild when it is
--     made; receivers record it silently: never printed, replied to or re-sent.
-- No combat data: nothing here reads a combat event, a kill or a death recap.
-- Fix round 1: F7, the double-press window lives in memory and a log's stored t is the epoch; F6b,
-- a received GANK is kept at most once per sender and enemy per 300 s.
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local CAP = 500          -- logs kept
local AGAIN = 300        -- seconds: a second press on the same enemy is "already noted"
local SHOW = 10          -- lines for one enemy
local ZONE_MAX = 48
local WHO_MAX = 64
local CLOSING = "Only logs from guildies running the addon, seen while you were online."
local EMPTY = "No grudges yet. Go and make some."

-- ---------------------------------------------------------------- the store

local function gank()
  local db = DT.db()
  if type(db.gank) ~= "table" then db.gank = {} end
  local g = db.gank
  if type(g.badGank) ~= "number" then g.badGank = 0 end
  if type(g.logs) ~= "table" then g.logs = {} end
  return g
end
DT.gankStore = gank
local function logs() return gank().logs end
DT.ganks = logs

local redraw

local function record(e)
  local list = logs()
  list[#list + 1] = e
  while #list > CAP do table.remove(list, 1) end                       -- guard: 500 cap
  if redraw then redraw() end
end

-- ---------------------------------------------------------------- formatting

local function className(cls)
  if type(cls) ~= "string" or cls == "" then return "Unknown" end
  return cls:sub(1, 1) .. cls:sub(2):lower()
end
local function lvlText(l) return (type(l) == "number" and l > 0) and tostring(l) or "??" end
local function day(at) return type(at) == "string" and (at:match("^(%d%d%d%d%-%d%d%-%d%d)") or DT.safe(at, 20)) or "?" end
local function what(e) return "(" .. className(e.cls) .. " " .. lvlText(e.lvl) .. ")" end

-- ---------------------------------------------------------------- /dt gank

local function nonEmpty(s) return type(s) == "string" and s ~= "" end
local lastPress = {}      -- this session: [who] = DT.now() of the last /dt gank on them (F7)

-- The target's key: the full name GetUnitName("target", true) gives (surname included), its
-- "-Realm" when the client adds one, else our realm. UnitName("target") only when that is empty.
local function targetKey()
  local shown = clean(try(GetUnitName, "target", true))
  local name = nonEmpty(shown) and shown or clean((try(UnitName, "target")))
  if not nonEmpty(name) then return nil end
  local realm = name:match("^.-%-(.+)$")
  return DT.keyOf(name, nonEmpty(realm) and realm or nil)
end

function DT.gank()
  if not DT.inCommand then return false end                            -- guard: target read only on /dt gank (R1)
  -- 1. a player
  if try(UnitExists, "target") ~= true or try(UnitIsPlayer, "target") ~= true then   -- guard: player check
    return DT.out("Target a player first. Preferably one who deserves it.")
  end
  -- 2. of the other faction
  local theirs = clean(try(UnitFactionGroup, "target"))
  local ours = clean(try(UnitFactionGroup, "player"))
  if not nonEmpty(theirs) or not nonEmpty(ours) or theirs == ours then                -- guard: faction check
    return DT.out("That's one of ours. Put the pen down.")
  end
  -- 3. who, class, level
  local who = targetKey()
  if not who then                                                                     -- guard: unreadable name
    return DT.out("The game won't say who that is right now. Try again out of combat.")
  end
  who = who:sub(1, WHO_MAX)
  local cls = clean(select(2, try(UnitClass, "target")))
  if type(cls) ~= "string" or not cls:match("^[A-Z]+$") or #cls > 12 then cls = "UNKNOWN" end
  local lvl = clean(try(UnitLevel, "target"))
  if type(lvl) ~= "number" or lvl < 1 or lvl > 100 or lvl ~= math.floor(lvl) then lvl = -1 end
  -- 4. where
  local zone = clean(try(GetRealZoneText))
  zone = nonEmpty(zone) and zone:sub(1, ZONE_MAX) or "somewhere"
  -- 5. double press (F7): decided in memory, by GetTime() this session
  local now = DT.now()
  if lastPress[who] and now - lastPress[who] < AGAIN then                             -- guard: double-press window (F7)
    return DT.out("Already noted. Grudges don't need two copies.")
  end
  lastPress[who] = now
  -- 6. record, send, confirm. The stored time is the epoch (time()), which survives a restart.
  local epoch = clean(try(time))
  local e = { who = who, cls = cls, lvl = lvl, zone = zone, by = DT.myKey() or "?", at = DT.stamp(),
    t = type(epoch) == "number" and epoch or nil }
  record(e)
  DT.send("GANK", { who = who, cls = cls, lvl = tostring(lvl), zone = zone })
  DT.out("Noted: " .. DT.display(who) .. " " .. what(e) .. ", " .. DT.safe(zone, ZONE_MAX) .. ". The crypt remembers.")
  return true
end

-- ---------------------------------------------------------------- inbound

local function valid(f)
  local who, cls, lvl, zone = f.who, f.cls, f.lvl, f.zone
  if type(who) ~= "string" or #who < 1 or #who > WHO_MAX or not DT.normKey(who) then return false end
  if type(cls) ~= "string" or #cls > 12 or not cls:match("^[A-Z]+$") then return false end
  if lvl ~= "-1" then
    local n = type(lvl) == "string" and lvl:match("^%d%d?%d?$") and tonumber(lvl)
    if not n or n < 1 or n > 100 then return false end
  end
  return type(zone) == "string" and #zone >= 1 and #zone <= ZONE_MAX
end

-- F6b: at most one received GANK per sender and enemy per 300 s.
local lastFrom = {}

DT.on("GANK", function(from, f)
  if not valid(f) then                                                                -- guard: field validation
    local g = gank()
    g.badGank = g.badGank + 1
    return
  end
  local who = DT.normKey(f.who)
  local k, t = from .. "#" .. who, DT.now()
  if lastFrom[k] and t - lastFrom[k] < AGAIN then                                     -- guard: per-sender limit (F6b)
    local g = gank()
    g.dropped = (g.dropped or 0) + 1
    return
  end
  lastFrom[k] = t
  -- Silent receipt (R2): stored, never printed, never replied to, never re-sent.
  record({ who = who, cls = f.cls, lvl = tonumber(f.lvl), zone = f.zone, by = from, at = DT.stamp() })
end)

-- ---------------------------------------------------------------- the board (a viewport)

-- One row per enemy, most frequent first, then the newest: name (R-P5 among the board), class and
-- level of the newest log, how many logs, by how many guildies, the last zone and day.
function DT.gankRows()
  local list, groups, order = logs(), {}, {}
  for i, e in ipairs(list) do
    if type(e) == "table" and type(e.who) == "string" then
      local g = groups[e.who]
      if not g then
        g = { who = e.who, count = 0, by = {}, loggers = 0 }
        groups[e.who] = g
        order[#order + 1] = g
      end
      g.count = g.count + 1
      if e.by and not g.by[e.by] then g.by[e.by] = true; g.loggers = g.loggers + 1 end
      g.last, g.lastIndex = e, i
    end
  end
  local keys = {}
  for _, g in ipairs(order) do keys[#keys + 1] = g.who end
  local name = DT.namer(keys)
  table.sort(order, function(x, y)
    if x.count ~= y.count then return x.count > y.count end
    if x.lastIndex ~= y.lastIndex then return x.lastIndex > y.lastIndex end
    return name(x.who):lower() < name(y.who):lower()
  end)
  local rows = {}
  for n, g in ipairs(order) do
    local nm = name(g.who)
    local by = "x" .. g.count .. " by " .. g.loggers .. (g.loggers == 1 and " guildie" or " guildies")
    local last = "last " .. DT.safe(g.last.zone, ZONE_MAX)
    rows[#rows + 1] = { key = g.who, n = n .. ".", name = nm, what = what(g.last), by = by, last = last,
      day = DT.shortDate(g.last.at), full = day(g.last.at),
      search = table.concat({ nm, tostring(g.who), className(g.last.cls), tostring(g.last.zone), day(g.last.at) }, " ") }
  end
  return rows
end

local vp, list, model

redraw = function()
  if model and vp and vp:IsShown() then model:set(DT.gankRows()); list:refresh() end
end

function DT.gankBoard()
  if not DT.isMember() then return end
  if not vp then
    model = DT.listModel()
    vp = DT.viewport({ id = "gank", title = "Grudges", search = true, width = 520, height = 400, footer = 16,
      onSearch = function(text) model:filter(text); list.offset = 0; list:refresh() end })
    local note = vp.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    note:SetPoint("BOTTOMLEFT", vp.frame, "BOTTOMLEFT", DT.style("spacing.pad"), 6)
    note:SetText(CLOSING)
    vp.note = note
    DT.skin(function() DT.fontTo(note, "small", "muted") end)
    list = DT.list(vp.body, model, { count = 16,
      empty = function(m) if #m.rows == 0 then return EMPTY end end,
      tip = function(row, tt)
        tt:AddLine(DT.safe(DT.nameOf(row.key), 48)); tt:AddLine(DT.realmLabel(row.key), 1, 1, 1)
        tt:AddLine(row.full, 0.8, 0.8, 0.8)
      end,
      columns = { { key = "n", width = 22, colour = "muted" }, { key = "name", width = 130 },
        { key = "what", width = 80, colour = "muted" }, { key = "by", width = 100 },
        { key = "last", width = 96, colour = "muted" }, { key = "day", width = 40, colour = "muted" } } })
  end
  model:set(DT.gankRows())
  list:refresh()
  vp:Show()
end

-- ---------------------------------------------------------------- one enemy (printed, as rc3)

-- Enemies matching `arg`: "name", "name-realm" or "realm-name", case-insensitive; the name is the
-- full name ("Backstabz Dagger") or its first part ("Backstabz").
local function squash(s) return (s or ""):gsub("[%s%-]", ""):lower() end
local function find(arg)
  arg = arg:lower():gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
  local tries = { { name = arg } }
  local n1, r1 = arg:match("^([^%-]+)%-(.+)$")          -- Name-Realm
  local r2, n2 = arg:match("^(.+)%-([^%-]+)$")          -- Realm-Name
  if n1 then tries = { { name = n1, realm = squash(r1) }, { name = n2, realm = squash(r2) } } end
  local hits, seen = {}, {}
  for _, e in ipairs(logs()) do
    local key = e.who
    local realm, name = DT.splitKey(key)
    if realm and not seen[key] then
      local full, first = name:lower(), (name:match("^(%S+)") or name):lower()
      for _, t in ipairs(tries) do
        if not seen[key] and (full == t.name or first == t.name) and (not t.realm or t.realm == squash(realm)) then
          seen[key] = true
          hits[#hits + 1] = key
        end
      end
    end
  end
  table.sort(hits)
  return hits
end

local function one(arg)
  local hits = find(arg)
  if #hits == 0 then return DT.out("Never heard of them. Yet.") end
  if #hits > 1 then
    local names, show = {}, DT.namer(hits)
    for _, k in ipairs(hits) do names[#names + 1] = show(k) end
    return DT.out("more than one " .. DT.safe(arg, 48) .. ": " .. table.concat(names, ", ") .. ". Add the realm.")
  end
  local list, shown = logs(), 0
  for i = #list, 1, -1 do
    local e = list[i]
    if e.who == hits[1] then
      DT.out(day(e.at) .. " " .. DT.safe(e.zone, ZONE_MAX) .. " " .. what(e) .. ", by " .. DT.display(e.by))
      shown = shown + 1
      if shown >= SHOW then break end                                  -- guard: 10 lines for one enemy
    end
  end
  DT.out(CLOSING)
end

DT.keySource(function()
  local out = {}
  for _, e in ipairs(logs()) do if type(e) == "table" then out[#out + 1] = e.who; out[#out + 1] = e.by end end
  return out
end)

DT.module({
  id = "gank",
  title = "Gank diary",
  verbs = {
    { verb = "gank", usage = "gank", fn = function() DT.gank() end },
    { verb = "ganks", usage = "ganks [name]", fn = function(args)
        if args ~= "" then return one(args) end
        return DT.gankBoard()
      end },
  },
  init = function() gank() end,
})

-- For the offline tests only.
DT._gank = { CLOSING = CLOSING, EMPTY = EMPTY, vp = function() return vp end, list = function() return list end,
  targetKey = targetKey }
