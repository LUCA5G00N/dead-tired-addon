-- Dead Tired: the gank diary. A button press on a target, never a kill detector.
-- docs/COWORK_BRIEF_dt_pvp.md (card 4; R1-R3 ratified 2026-11-02).
--
-- R1: reads only what the target frame shows (name with realm, class, level, and faction,
--     which is checked and never stored), and only when /dt gank is pressed.
-- R2: a log goes to the guild when it is made; receivers record it silently.
-- R3: this file keeps its own store, DeadTiredDB.gank; card 1's files are untouched.
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local CAP = 500          -- logs kept per guild
local AGAIN = 300        -- seconds: a second press on the same enemy is "already noted"
local SHOW = 10          -- board lines, and lines for one enemy
local ZONE_MAX = 48
local WHO_MAX = 64
local CLOSING = "Only logs from guildies running the addon, seen while you were online."

-- ---------------------------------------------------------------- the store

local function gank()
  local db = DT.db()
  if type(db.gank) ~= "table" then db.gank = {} end
  local g = db.gank
  if type(g.badGank) ~= "number" then g.badGank = 0 end
  return g
end

local function logs()
  local g = gank()
  local k = DT.guildKey() or "?"
  if type(g[k]) ~= "table" then g[k] = {} end
  if type(g[k].logs) ~= "table" then g[k].logs = {} end
  return g[k].logs
end
DT.ganks = logs

local function record(e)
  local list = logs()
  list[#list + 1] = e
  while #list > CAP do table.remove(list, 1) end                       -- guard: 500 cap
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

function DT.gank()
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
  local name, realm = try(UnitName, "target")
  name, realm = clean(name), clean(realm)
  if not nonEmpty(name) then                                                          -- guard: unreadable name
    return DT.out("The game won't say who that is right now. Try again out of combat.")
  end
  if not nonEmpty(realm) then realm = clean(try(GetRealmName)) end
  if not nonEmpty(realm) then
    return DT.out("The game won't say who that is right now. Try again out of combat.")
  end
  local who = (realm .. "-" .. name):sub(1, WHO_MAX)
  local cls = clean(select(2, try(UnitClass, "target")))
  if type(cls) ~= "string" or not cls:match("^[A-Z]+$") or #cls > 12 then cls = "UNKNOWN" end
  local lvl = clean(try(UnitLevel, "target"))
  if type(lvl) ~= "number" or lvl < 1 or lvl > 100 or lvl ~= math.floor(lvl) then lvl = -1 end
  -- 4. where
  local zone = clean(try(GetRealZoneText))
  zone = nonEmpty(zone) and zone:sub(1, ZONE_MAX) or "somewhere"
  -- 5. double press
  local now, list = DT.now(), logs()
  for i = #list, 1, -1 do
    local e = list[i]
    if e.who == who and e.t then
      if now - e.t < AGAIN then                                                       -- guard: double-press window
        return DT.out("Already noted. Grudges don't need two copies.")
      end
      break
    end
  end
  -- 6. record, send, confirm
  local e = { who = who, cls = cls, lvl = lvl, zone = zone, by = DT.charKey() or "?", at = DT.stamp(), t = now }
  record(e)
  DT.send("GANK", { who = who, cls = cls, lvl = tostring(lvl), zone = zone })
  DT.out("Noted: " .. DT.display(who) .. " " .. what(e) .. ", " .. DT.safe(zone, ZONE_MAX) .. ". The crypt remembers.")
end

-- ---------------------------------------------------------------- inbound

local function valid(f)
  local who, cls, lvl, zone = f.who, f.cls, f.lvl, f.zone
  if type(who) ~= "string" or #who < 1 or #who > WHO_MAX or not who:match("^.+%-[^%-]+$") then return false end
  if type(cls) ~= "string" or #cls > 12 or not cls:match("^[A-Z]+$") then return false end
  if lvl ~= "-1" then
    local n = type(lvl) == "string" and lvl:match("^%d%d?%d?$") and tonumber(lvl)
    if not n or n < 1 or n > 100 then return false end
  end
  return type(zone) == "string" and #zone >= 1 and #zone <= ZONE_MAX
end

DT.on("GANK", function(from, f)
  if not valid(f) then                                                                -- guard: field validation
    local g = gank()
    g.badGank = g.badGank + 1
    return
  end
  -- Silent receipt (R2): stored, never printed, never replied to, never re-sent.
  record({ who = f.who, cls = f.cls, lvl = tonumber(f.lvl), zone = f.zone, by = from, at = DT.stamp() })
end)

-- ---------------------------------------------------------------- the board

local function board()
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
  table.sort(order, function(x, y)
    if x.count ~= y.count then return x.count > y.count end
    if x.lastIndex ~= y.lastIndex then return x.lastIndex > y.lastIndex end
    return DT.display(x.who):lower() < DT.display(y.who):lower()
  end)
  if #order == 0 then
    DT.out("No grudges yet. Go and make some.")
  else
    for n = 1, math.min(#order, SHOW) do                                              -- guard: 10-line board
      local g = order[n]
      DT.out(n .. ". " .. DT.display(g.who) .. " " .. what(g.last) .. " x" .. g.count .. " by " .. g.loggers
        .. (g.loggers == 1 and " guildie" or " guildies") .. ", last " .. DT.safe(g.last.zone, ZONE_MAX)
        .. " " .. day(g.last.at))
    end
  end
  DT.out(CLOSING)
end

-- Enemies matching `arg`: "name", "name-realm" or "realm-name", case-insensitive.
-- Copied from Alts.lua's find(), over the board's enemies instead of the roster.
local function squash(s) return (s or ""):gsub("[%s%-]", ""):lower() end
local function find(arg)
  arg = arg:lower():gsub("^%s+", ""):gsub("%s+$", "")
  local tries = { { name = arg } }
  local n1, r1 = arg:match("^([^%-]+)%-(.+)$")          -- Name-Realm
  local r2, n2 = arg:match("^(.+)%-([^%-]+)$")          -- Realm-Name
  if n1 then tries = { { name = n1, realm = squash(r1) }, { name = n2, realm = squash(r2) } } end
  local hits, seen = {}, {}
  for _, e in ipairs(logs()) do
    local key = e.who
    if type(key) == "string" and not seen[key] then
      local name = DT.nameOf(key)
      local realm = squash(key:sub(1, #key - #name - 1))
      for _, t in ipairs(tries) do
        if not seen[key] and name:lower() == t.name and (not t.realm or t.realm == realm) then
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
    local names = {}
    for _, k in ipairs(hits) do names[#names + 1] = DT.display(k) end
    return DT.out("more than one " .. DT.safe(arg, 48) .. ": " .. table.concat(names, ", ") .. ". Add the realm.")
  end
  local list, shown = logs(), 0
  for i = #list, 1, -1 do
    local e = list[i]
    if e.who == hits[1] then
      DT.out(day(e.at) .. " " .. DT.safe(e.zone, ZONE_MAX) .. " " .. what(e) .. ", by " .. DT.display(e.by))
      shown = shown + 1
      if shown >= SHOW then break end
    end
  end
  DT.out(CLOSING)
end

DT.module({
  id = "gank",
  init = function() gank() end,
  ready = DT.errors,
  errorKey = "gank", lastKey = "lastGank",
})
DT.verb("gank", function() DT.gank() end)
DT.verb("ganks", function(msg)
  local arg = (DT.raw or msg):match("^%S+%s+(.+)$")
  if arg then return one(arg) end
  return board()
end, "ganks [name]")
