-- Audit item 4: guild-channel traffic with every card loaded together, 20 clients.
--   lua5.1 audit/tests/test_traffic.lua   (from the repo root, after setup.sh)
--
-- Each client loads card 1's seven files plus every card's own files, each from its own branch
-- checkout (the module lists are merged here; no branch is merged). They share one fake GUILD
-- bus (card 1's harness). Card 1's real Comms.lua does the throttling and queueing.
--
-- Prints the numbers the audit reports. Exits non-zero only if a check below fails: the checks
-- state what should hold (nothing dropped, every answer inside its window), so a red check here
-- is a finding, and the audit names it.
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local L = dofile(dir .. "/lib.lua")
local H = L.harness("dt_foundation")
H.addonDir = L.WT
local check = H.check

local FILES = {}
for _, f in ipairs({ "Config", "Core", "Guild", "Comms", "Roster", "Alts", "Welcome" }) do
  FILES[#FILES + 1] = "dt_foundation/DeadTired/" .. f .. ".lua"
end
for _, cf in ipairs({ { "dt_crypt", "Crypt" }, { "dt_pvp", "Gank" },
    { "dt_prep", "PrepList" }, { "dt_prep", "Prep" }, { "dt_prep", "RecruitLines" }, { "dt_prep", "Recruit" },
    { "dt_stretch", "Stash" }, { "dt_stretch", "Played" }, { "dt_stretch", "EventsList" }, { "dt_stretch", "Events" },
    { "dt_logs", "Logs" } }) do
  FILES[#FILES + 1] = cf[1] .. "/DeadTired/" .. cf[2] .. ".lua"
end

-- ---------------------------------------------------------------- deterministic randomness
local function lcg(seed)
  local s = seed
  return function()
    s = (s * 1103515245 + 12345) % 2147483648
    return s / 2147483648
  end
end

-- ---------------------------------------------------------------- the clients
local LINEN = 2589
local stats   -- per scenario

local function stubs(c, i)
  local e = c.env
  e.UnitClass = function() return "Warrior", "WARRIOR" end
  e.UnitLevel = function() return 40 + (i % 20) end
  e.GetRealZoneText = function() return "Stranglethorn Vale" end
  e.IsInInstance = function() return false, "none" end
  e.InCombatLockdown = function() return false end
  e.C_Item = { GetItemCount = function() return (i % 3 == 0) and 0 or 99 end,
    GetItemNameByID = function(id) if id == LINEN then return "Linen Cloth" end end,
    RequestLoadItemDataByID = function() end }
  e.C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end,
    GetContainerItemInfo = function(bag, slot)
      if bag == 0 and slot == 1 then return { itemID = LINEN, stackCount = 5 + i, isBound = false } end
    end,
  }
  e.UnitExists = function(u) return u == "target" end
  e.UnitIsPlayer = function(u) return u == "target" end
  e.UnitFactionGroup = function(u) if u == "target" then return "Alliance" end return "Horde" end
  e.UnitName = function(u)
    if u == "player" then return c.name end
    if u == "target" then return c.targetName or "Backstabz", nil end
  end
  -- /played and hooksecurefunc, so card 6's A3 hook can be placed (stubs set before ADDON_LOADED)
  e.SlashCmdList.PLAYED = function() end
  e.hooksecurefunc = function(t, k, f)
    local o = t[k]
    t[k] = function(...) o(...) f(...) end
  end
end

-- Wraps a client's DT.send and SendAddonMessage to measure queue length and queueing delay.
local function instrument(c)
  local DT = c.DT
  local fifo = {}
  local orig = DT.send
  DT.send = function(kind, fields)
    local dropped0 = c:db().comms.dropped
    local ok = orig(kind, fields)
    local q = #DT._comms.queue()
    if ok then
      -- what pump() already sent went out inside orig(); what is still queued waits
      for _ = 1, q - #fifo do fifo[#fifo + 1] = { t = c.world.t, kind = kind } end
      local d = c:db().comms.dropped - dropped0
      for _ = 1, d do table.remove(fifo, 1) end
      stats.byKind[kind] = (stats.byKind[kind] or 0) + 1
    end
    if q > stats.peakQueue then stats.peakQueue, stats.peakWho, stats.peakAt = q, c.name, c.world.t end
    return ok
  end
  local send = c.env.C_ChatInfo.SendAddonMessage
  c.env.C_ChatInfo.SendAddonMessage = function(p, text, chan)
    local r = send(p, text, chan)
    -- a send from the queue (not the immediate one inside DT.send) pops our FIFO
    if #fifo > #DT._comms.queue() then
      local m = table.remove(fifo, 1)
      local delay = c.world.t - m.t
      if delay > stats.maxDelay then stats.maxDelay, stats.maxDelayKind = delay, m.kind end
    end
    return r
  end
end

local NAMES = {}
for i = 1, 40 do NAMES[i] = "Ghoul" .. string.char(64 + ((i - 1) % 26) + 1) .. (i > 26 and "x" or "") end

local function newStats()
  return { peakQueue = 0, maxDelay = 0, byKind = {} }
end

local function makeClient(w, i, opts)
  opts = opts or {}
  local c = w:client({ name = opts.name or NAMES[i], guild = L.G, files = FILES, load = false,
    random = lcg(i * 7919 + (opts.seed or 0)), db = opts.db })
  stubs(c, i)
  c:fire("ADDON_LOADED", "DeadTired")
  instrument(c)
  c.idx = i
  return c
end

local function reload(w, c)
  local db = c:db()
  c:logout()
  local n = makeClient(w, c.idx, { name = c.name, db = db, seed = 1 })
  n:fire("PLAYER_ENTERING_WORLD", false, true)
  return n
end

-- ---------------------------------------------------------------- reporting
local function perMinute(w, t0, minutes)
  local out = {}
  for m = 1, minutes do out[m] = 0 end
  for _, m in ipairs(w.wire) do
    local k = math.floor((m.t - t0) / 60) + 1
    if k >= 1 and k <= minutes then out[k] = out[k] + 1 end
  end
  return out
end

local function dropped(clients)
  local n, failed = 0, 0
  for _, c in ipairs(clients) do
    n = n + c:db().comms.dropped
    failed = failed + (c:db().comms.sendFailed or 0)
  end
  return n, failed
end

local function kinds(s)
  local keys = {}
  for k in pairs(s.byKind) do keys[#keys + 1] = k end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = k .. " " .. s.byKind[k] end
  return table.concat(parts, ", ")
end

local function report(name, w, t0, minutes, clients, s)
  local pm = perMinute(w, t0, minutes)
  local total, peak, peakM = 0, 0, 0
  for m, n in ipairs(pm) do total = total + n; if n > peak then peak, peakM = n, m end end
  local d, f = dropped(clients)
  print(string.format("%s: %d messages in %d min (mean %.1f/min, peak %d in minute %d); peak queue %d (%s at +%ds); "
    .. "max queueing delay %.1f s (%s); dropped %d; send failures %d",
    name, total, minutes, total / minutes, peak, peakM, s.peakQueue, tostring(s.peakWho),
    math.floor((s.peakAt or t0) - t0), s.maxDelay, tostring(s.maxDelayKind), d, f))
  print("  by kind: " .. kinds(s))
  local first = {}
  for m = 1, math.min(minutes, 5) do first[#first + 1] = pm[m] end
  print("  first minutes: " .. table.concat(first, ", "))
  return pm, total
end

-- How many sharing answers made it into an asker's summary line ("Ready (k)... Short (m)").
local function answersIn(c)
  for i = #c.printed, 1, -1 do
    local r, s = c.printed[i]:match("Ready %((%d+)%).-Short %((%d+)%)")
    if r then return tonumber(r) + tonumber(s) end
  end
end

-- ================================================================ S1: login wave, spread over 2 minutes
do
  stats = newStats()
  local w = H.world()
  local t0 = w.t
  local clients, rnd = {}, lcg(42)
  for i = 1, 20 do
    local at = rnd() * 120
    w:schedule(at, function()
      local c = makeClient(w, i)
      clients[#clients + 1] = c
      c:login()
    end)
  end
  w:advance(600)
  local pm, total = report("S1 login wave (20 log in over 2 min)", w, t0, 10, clients, stats)
  -- each login HELLO gets one reply from every client that hasn't answered that sender yet; two
  -- clients whose login HELLOs cross (both inside each other's 10 s) answer each other twice.
  -- So a wave costs 20 + between 190 and 380 replies.
  print("  replies: " .. (total - 20) .. " (bounds 190 to 380)")
  local d = dropped(clients)
  check("S1: nothing dropped", d == 0)
end

-- ================================================================ S1b: everyone at once (a reconnect wave)
do
  stats = newStats()
  local w = H.world()
  local t0 = w.t
  local clients = {}
  for i = 1, 20 do
    w:schedule(i * 0.1, function()
      local c = makeClient(w, i)
      clients[#clients + 1] = c
      c:login()
    end)
  end
  w:advance(600)
  report("S1b login wave (20 log in within 2 s)", w, t0, 10, clients, stats)
  check("S1b: nothing dropped", dropped(clients) == 0)
end

-- ================================================================ S2: an hour of normal use
local S2
do
  stats = newStats()
  local w = H.world()
  local clients, byName = {}, {}
  for i = 1, 20 do
    local c = makeClient(w, i)
    clients[i] = c
    byName[c.name] = c
    c:login()
  end
  w:advance(300)   -- settle after the login wave
  -- half the guild shares everything
  for i = 1, 20 do
    if i % 2 == 0 then
      local c = clients[i]
      c:slash("prep share on"); c:slash("stash share on"); c:slash("rip share on"); c:slash("slowest share on")
    end
  end
  stats = newStats()
  w.wire = {}
  local t0 = w.t
  local rnd = lcg(7)
  local plan = {}
  local function at(t, what, fn) plan[#plan + 1] = { t = t, what = what, fn = fn } end
  local function pick() return math.floor(rnd() * 20) + 1 end
  local prepAsks = {}
  for k = 1, 6 do at(rnd() * 3600, "prep check", function()
    local c = clients[pick()]
    c:slash("prep check")
    prepAsks[#prepAsks + 1] = c
  end) end
  for k = 1, 10 do at(rnd() * 3600, "stash search", function() clients[pick()]:slash("stash linen") end) end
  for k = 1, 15 do at(rnd() * 3600, "death", function() clients[pick()]:fire("PLAYER_DEAD") end) end
  for k = 1, 10 do at(rnd() * 3600, "gank", function()
    local c = clients[pick()]
    c.targetName = "Enemy" .. string.char(65 + math.floor(rnd() * 26))
    c:slash("gank")
  end) end
  for k = 1, 8 do at(rnd() * 3600, "/played", function()
    local c = clients[pick()]
    c.env.SlashCmdList.PLAYED()
    c:fire("TIME_PLAYED_MSG", 360000, 3600)
  end) end
  for k = 1, 4 do at(rnd() * 3600, "/reload", function()
    local i = pick()
    clients[i] = reload(w, clients[i])
  end) end
  for k = 1, 3 do at(rnd() * 3600, "alt login", function()
    -- someone logs an alt: one character leaves, a new one (new key) arrives
    local i = pick()
    local db = clients[i]:db()
    clients[i]:logout()
    local c = makeClient(w, i, { name = NAMES[20 + i], db = db, seed = 2 })
    clients[i] = c
    c:login()
  end) end
  table.sort(plan, function(a, b) return a.t < b.t end)
  for _, p in ipairs(plan) do w:schedule(p.t, p.fn) end
  w:advance(3600 + 60)
  local pm, total = report("S2 an hour, 20 online, half sharing everything", w, t0, 60, clients, stats)
  local mx = 0
  for _, n in ipairs(pm) do if n > mx then mx = n end end
  S2 = { total = total, max = mx }
  check("S2: nothing dropped", dropped(clients) == 0)
end

-- ================================================================ S3: raid night (logins, then a roll call)
do
  stats = newStats()
  local w = H.world()
  local t0 = w.t
  local clients, rnd = {}, lcg(99)
  for i = 1, 20 do
    w:schedule(rnd() * 60, function()
      local c = makeClient(w, i)
      clients[#clients + 1] = c
      c:login()
      c:slash("prep share on")
    end)
  end
  -- the raid leader asks 30 s after the last of them arrived
  local asker
  w:schedule(90, function() asker = clients[1]; asker:slash("prep check") end)
  w:advance(600)
  report("S3 raid night: 20 log in within 60 s, roll call at +90 s", w, t0, 10, clients, stats)
  local got = answersIn(asker)
  print("  roll call answers inside the 10 s window: " .. tostring(got) .. " of 19")
  check("S3: every sharing guildie's answer reaches the 10 s summary (got " .. tostring(got) .. " of 19)", got == 19)
  w:schedule(0, function() asker:slash("prep check") end)
end

-- ================================================================ S4: an hour-long restricted spell (in an encounter)
do
  stats = newStats()
  local w = H.world()
  local clients = {}
  for i = 1, 20 do clients[i] = makeClient(w, i); clients[i]:login() end
  w:advance(300)
  for i = 1, 20 do clients[i]:slash("prep share on"); clients[i]:slash("stash share on") end
  stats = newStats()
  w.wire = {}
  local t0 = w.t
  -- ten of them are in a raid encounter: addon messages restricted for 10 minutes
  for i = 1, 10 do clients[i].restricted = true end
  -- meanwhile: 6 alts log in, 5 roll calls, 5 searches from the others
  for k = 1, 6 do w:schedule(k * 60, function()
    local i = 10 + k
    local db = clients[i]:db()
    clients[i]:logout()
    clients[i] = makeClient(w, i, { name = NAMES[20 + i], db = db, seed = 3 })
    clients[i]:login()
    clients[i]:slash("prep share on")
  end) end
  local askers = {}
  for k = 1, 5 do w:schedule(k * 100, function()
    askers[k] = clients[10 + k]
    askers[k]:slash("prep check")
    w:schedule(10.5, function() askers[k].got = answersIn(askers[k]) end)
  end) end
  for k = 1, 5 do w:schedule(k * 100 + 40, function() clients[15 + k]:slash("stash linen") end) end
  w:schedule(600, function() for i = 1, 10 do clients[i].restricted = false end end)
  w:advance(900)
  report("S4 ten clients restricted for 10 min, traffic around them", w, t0, 15, clients, stats)
  local d = dropped(clients)
  check("S4: nothing dropped while restricted", d == 0)
  local gots = {}
  for k = 1, 5 do gots[k] = tostring(askers[k].got) end
  print("  roll calls during the restriction got " .. table.concat(gots, ", ")
    .. " answers of 19 (the 10 restricted clients answer after the window closes)")
end

-- ================================================================ S5: worst case, everyone asks at once
do
  stats = newStats()
  local w = H.world()
  local clients = {}
  for i = 1, 20 do clients[i] = makeClient(w, i); clients[i]:login() end
  w:advance(300)
  for i = 1, 20 do clients[i]:slash("prep share on") end
  stats = newStats()
  w.wire = {}
  local t0 = w.t
  for i = 1, 20 do clients[i]:slash("prep check") end
  w:advance(120)
  report("S5 all 20 run /dt prep check in the same second, all sharing", w, t0, 2, clients, stats)
  local short, worst = 0, 19
  for i = 1, 20 do
    local n = answersIn(clients[i]) or 0
    if n < 19 then short = short + 1 end
    if n < worst then worst = n end
  end
  print("  askers missing answers: " .. short .. " of 20; worst got " .. worst .. " of 19")
end

print(string.format("S2 summary: %d messages in the hour, busiest minute %d", S2.total, S2.max))
H.finish("audit traffic")
