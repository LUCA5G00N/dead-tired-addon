-- Dead Tired: the self-test (U1; dt_selftest, R-F8-1 and R-F8-2). /dt selftest runs these checks in
-- the live client and prints one line, plus one line per failure:
--   S1 version   the .toc's Version (C_AddOns.GetAddOnMetadata) equals DT.VERSION
--   S2 client    GetBuildInfo's build and interface, recorded; information, never a failure
--   S3 key       DT.myKey() is a key; the realm's source recorded (fails on a client like 21 Nov's)
--   S4 apis      every global and C_* function in DT.REQUIRED is present
--   S5 modules   every module loaded, none failed its init
--   S6 errors    no error recorded by any module this session
--   S7 windows   DT.fitCheck(): 0 over, measure failures 0
--   S8 switches  every optional module off (in memory): a ghost message of every kind prints nothing
--                and sends nothing
--   S9 saved     schema, every migrated flag, each capped list within its cap
--   S10 wire     every kind's sample survives encode then decode unchanged
--   S11 loopback a ghost HELLO puts the ghost in Who's list; the purge takes it out again
-- R-F8-2: only the last run is kept, as DeadTiredDB.selftest (lines capped at 100). It runs only when
-- typed. Every override is in memory (DT.enabled, DT.out swapped and put back, as DT.fitSkin is) and
-- restored even when a check errors; no setting is written.
-- S5/S6: DT.fail is wrapped at file load (before ADDON_LOADED), so failures this session, inits
-- included, are counted in memory: the brief's "login snapshot", taken without touching Core.
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local MAX_LINES = 100
local SUMMARY = "Self-test: %d passed, %d failed. /reload to keep the record."

-- Every global and C_* function DT calls (from the code: each try(X) and each C_*.Name, 22 Nov 2026,
-- plus CreateFrame and GetBuildInfo). All are in reference/SPEC_forever_namespaces.md or are globals.
DT.REQUIRED = {
  "CreateFrame", "GetBuildInfo", "GetTime", "GetGuildInfo", "GetNumGuildMembers", "GetGuildRosterInfo",
  "UnitName", "UnitFullName", "GetUnitName", "UnitGUID", "UnitLevel", "UnitClass", "UnitExists",
  "UnitIsPlayer", "UnitIsDeadOrGhost", "UnitFactionGroup", "GetRealmName", "GetNormalizedRealmName",
  "GetRealZoneText", "GetZoneText", "IsInInstance", "GetInstanceInfo", "InCombatLockdown",
  "GetChannelName", "GetChannelList", "GetCVarBool", "GetCursorPosition", "SetCursor", "ResetCursor",
  "C_AddOns.IsAddOnLoaded", "C_AddOns.GetAddOnMetadata", "C_ChatInfo.SendAddonMessage",
  "C_ChatInfo.RegisterAddonMessagePrefix", "C_ChatInfo.InChatMessagingLockdown",
  "C_ChatInfo.AreOutgoingAddonChatMessagesRestricted", "C_ChatInfo.SendChatMessage",
  "C_DateAndTime.GetServerTimeLocal", "C_GameRules.IsHardcoreActive", "C_GuildInfo.GuildRoster",
  "C_GuildInfo.IsGuildOfficer", "C_Item.GetItemCount", "C_Item.GetItemInfoInstant",
  "C_Item.GetItemNameByID", "C_Item.IsBound", "C_Item.RequestLoadItemDataByID", "C_Timer.After",
}

-- Every migration flag DT defines (Migrate.lua; realm034 is set by Keys' store on first use).
local FLAGS = { "port1", "port2", "skin031", "realm034" }

-- The capped lists: path in DeadTiredDB, and the cap the owning module keeps.
local CAPS = {
  { "crypt", "deaths", 100 }, { "gank", "logs", 500 }, { "realms", "byChar", 200 },
  { "realms", "byServer", 200 }, { "comms", "senders", 50 }, { "comms", "mismatches", 10 },
}

-- One sample of every message kind (S8 and S10). Query kinds are safe here: S8 runs with every
-- optional module off, and S10 never delivers.
local function samples(me)
  me = me or "Realm-Some One"
  return {
    { "HELLO", { v = DT.VERSION, main = "", pl = "999999" } },
    { "WHO", { v = DT.VERSION } },
    { "DEATH", { lvl = "13", zone = "The Barrens", hc = "0" } },
    { "GANK", { who = DT.GHOST.realm .. "-Hapless Gnome", cls = "MAGE", lvl = "14", zone = "The Barrens" } },
    { "PLAYED", { lvl = "13", h = "666.0" } },
    { "STASHQ", { q = "1", term = "Linen" } },
    { "STASH", { q = "1", to = me, hits = "2589:20:" .. DT.GHOST.name } },
    { "PREPQ", { q = "1" } },
    { "PREP", { q = "1", to = me, ok = "1", short = "0" } },
    { "PREPLIST", { ver = "1", items = { { id = 2589, need = 20, name = "Linen Cloth" } } } },
  }
end

-- ---------------------------------------------------------------- errors this session (S5, S6)

local session = { count = 0, ids = {}, init = {} }
local realFail = DT.fail
DT.fail = function(id, where, err)
  session.count = session.count + 1
  session.ids[tostring(id)] = (session.ids[tostring(id)] or 0) + 1
  if where == "init" then session.init[tostring(id)] = true end
  return realFail(id, where, err)
end

-- ---------------------------------------------------------------- helpers

local function lookup(path)
  local t = _G
  for part in path:gmatch("[^%.]+") do
    if type(t) ~= "table" then return nil end
    t = t[part]
  end
  return t
end

local function same(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do if not same(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

-- Run fn with the named modules forced on/off in memory, DT.out recorded; always restored.
local function forced(states, fn)
  local realEnabled, realOut = DT.enabled, DT.out
  local outs = {}
  DT.enabled = function(id)
    if states[id] ~= nil then return states[id] end
    return realEnabled(id)
  end
  DT.out = function(m) outs[#outs + 1] = tostring(m); return true end
  local ok, a, b = pcall(fn, outs)
  DT.enabled, DT.out = realEnabled, realOut                                -- guard: switches restored
  if not ok then error(a, 0) end
  return a, b
end

-- ---------------------------------------------------------------- the checks

local CHECKS = {}
local function add(id, name, fn) CHECKS[#CHECKS + 1] = { id = id, name = name, fn = fn } end

add("S1", "version", function()
  local f = C_AddOns and C_AddOns.GetAddOnMetadata
  local v = clean((try(f, ADDON, "Version")))
  if v ~= DT.VERSION then                                                  -- guard: S1
    return false, ".toc says " .. tostring(v) .. ", DT.VERSION " .. DT.VERSION
  end
  return true, DT.VERSION
end)

add("S2", "client", function(rec)
  local _, build, _, iface = try(GetBuildInfo)
  rec.build, rec.interface = clean(build), clean(iface)
  return true, "build " .. tostring(rec.build) .. ", interface " .. tostring(rec.interface), true
end)

add("S3", "key", function(rec)
  local key = DT.myKey()
  rec.key, rec.source = key, DT.realmSource()
  if not key then return false, "no key (realm from " .. tostring(rec.source or "nowhere") .. ")" end  -- guard: S3
  return true, key .. " (realm from " .. tostring(rec.source) .. ")"
end)

add("S4", "apis", function()
  local missing = {}
  for _, name in ipairs(DT.REQUIRED) do
    if type(lookup(name)) ~= "function" then missing[#missing + 1] = name end  -- guard: S4
  end
  if #missing > 0 then return false, "missing " .. table.concat(missing, ", ") end
  return true, #DT.REQUIRED .. " present"
end)

add("S5", "modules", function()
  local bad = {}
  for _, m in ipairs(DT.modules) do
    if not m.loaded or session.init[m.id] then bad[#bad + 1] = m.id end      -- guard: S5
  end
  if #bad > 0 then return false, "not loaded or init failed: " .. table.concat(bad, ", ") end
  return true, #DT.modules .. " loaded"
end)

add("S6", "errors", function()
  if session.count > 0 then                                                -- guard: S6
    local ids = {}
    for id, n in pairs(session.ids) do ids[#ids + 1] = id .. " " .. n end
    table.sort(ids)
    return false, table.concat(ids, ", ")
  end
  return true, "none this session"
end)

add("S7", "windows", function()
  local lines = DT.fitCheck()
  local last = lines[#lines] or ""
  local over, fails = last:match("(%d+) over,.*measure failures (%d+)")
  if not over then return false, "no fit summary" end
  if tonumber(over) ~= 0 or tonumber(fails) ~= 0 then                     -- guard: S7
    return false, over .. " over, measure failures " .. fails
  end
  return true, (last:gsub("^fit: ", ""))
end)

add("S8", "switches", function()
  local states = {}
  for _, m in ipairs(DT.modules) do
    if m.optional and m.id ~= "ghost" and m.id ~= "selftest" then states[m.id] = false end
  end
  local loud = forced(states, function(outs)
    local loud = {}
    for _, s in ipairs(samples(DT.myKey())) do
      local before = #outs
      local _, sends = DT.ghostDeliver(s[1], s[2])
      if #outs > before then loud[#loud + 1] = s[1] .. " printed" end      -- guard: S8 (out)
      if #sends > 0 then loud[#loud + 1] = s[1] .. " sent " .. table.concat(sends, "/") end  -- guard: S8 (send)
    end
    return loud
  end)
  DT.ghostPurge()
  if #loud > 0 then return false, "with its module off: " .. table.concat(loud, ", ") end
  return true, "nothing heard from switched-off modules"
end)

add("S9", "saved", function()
  local db, bad = DT.db(), {}
  if db.schema ~= DT.SCHEMA then bad[#bad + 1] = "schema " .. tostring(db.schema) end
  DT.realmStore()                                                          -- realm034 runs on first use
  local M = type(db.migrated) == "table" and db.migrated or {}
  for _, f in ipairs(FLAGS) do
    if M[f] ~= true then bad[#bad + 1] = "migrated." .. f .. " not set" end  -- guard: S9 (flags)
  end
  for _, c in ipairs(CAPS) do
    local t = type(db[c[1]]) == "table" and db[c[1]][c[2]] or nil
    if type(t) == "table" then
      local n = 0
      for _ in pairs(t) do n = n + 1 end
      if n > c[3] then bad[#bad + 1] = c[1] .. "." .. c[2] .. " " .. n .. "/" .. c[3] end  -- guard: S9 (caps)
    end
  end
  if #bad > 0 then return false, table.concat(bad, ", ") end
  return true, "schema " .. db.schema .. ", " .. #FLAGS .. " flags, " .. #CAPS .. " caps"
end)

add("S10", "wire", function()
  local C, bad = DT._comms, {}
  for _, s in ipairs(samples(DT.myKey())) do
    local wire = C.encode(s[1], s[2], DT.GHOST.key)
    local res, p = C.decode(wire)
    if res ~= "ok" or p.k ~= s[1] or p.f ~= DT.GHOST.key or not same(p.d, s[2]) then  -- guard: S10
      bad[#bad + 1] = s[1]
    end
  end
  if #bad > 0 then return false, "changed in transit: " .. table.concat(bad, ", ") end
  return true, #samples() .. " kinds"
end)

add("S11", "loopback", function()
  local function listed()
    for _, r in ipairs(DT.whoRows()) do if r.key == DT.GHOST.key then return true end end
    return false
  end
  local heard = forced({ who = true }, function()
    DT.ghostDeliver("HELLO", { v = DT.VERSION, main = "", pl = "999999" })
    return listed()
  end)
  DT.ghostPurge()
  if not heard then return false, "the ghost's HELLO never reached Who" end  -- guard: S11 (heard)
  if listed() then return false, "the ghost was still listed after the purge" end  -- guard: S11 (purged)
  return true, "heard, then laid to rest"
end)

DT._selftest = { CHECKS = CHECKS, session = session, samples = samples, FLAGS = FLAGS, CAPS = CAPS }

-- ---------------------------------------------------------------- the run

function DT.selftest()
  local rec = { at = DT.stamp(), version = DT.VERSION, pass = 0, fail = 0, lines = {} }
  local failed = {}
  for _, c in ipairs(CHECKS) do
    local ok, okRes, detail, info = pcall(c.fn, rec)
    if not ok then okRes, detail = false, "error: " .. DT.safe(okRes, 120) end
    local line = c.id .. " " .. c.name .. ": " .. (info and "info" or (okRes and "pass" or "FAIL")) .. " - "
      .. DT.safe(detail or "", 160)
    if #rec.lines < MAX_LINES then rec.lines[#rec.lines + 1] = line end
    if not info then
      if okRes then rec.pass = rec.pass + 1 else rec.fail = rec.fail + 1; failed[#failed + 1] = line end
    end
  end
  DT.db().selftest = rec                                                   -- guard: the last run only
  return rec, failed
end

local function verb()
  if not DT.isMember() then return end                                     -- guard: guild gate (selftest)
  if not DT.enabled("selftest") then return DT.out("selftest.enabled = off") end
  local rec, failed = DT.selftest()
  DT.out(string.format(SUMMARY, rec.pass, rec.fail))
  for _, l in ipairs(failed) do DT.out(l) end
end

DT.module({
  id = "selftest",
  title = "Self-test",
  optional = true,
  switchDesc = "Checks Dead Tired from the inside when you type /dt selftest. Off, it does nothing.",
  verbs = { { verb = "selftest", usage = "selftest", fn = verb } },
})
