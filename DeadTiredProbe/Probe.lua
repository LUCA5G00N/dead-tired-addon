-- Dead Tired Probe: one login answers what the cards couldn't. docs/COWORK_BRIEF_dt_probe.md.
--
-- A throwaway diagnostic, separate from DeadTired/ (shares no code with it at runtime). Tim and
-- one guildie run it on launch night, then delete it. It RECORDS into DeadTiredProbeDB and
-- prints only the load line and replies to /dtprobe. It decides nothing and fixes nothing.
--
-- Bounds (brief, "The one deliberate widening"): no combat log or combat events, no inspect, no
-- public chat, no channel joins or leaves, never asks the game for play time. The only thing it
-- sends is the addon message "ping" (prefix DTPROBE), on command, to GUILD, else PARTY, else
-- nothing.
--
-- Every read goes through ask() and every recorded value through rec(). Every section runs in its
-- own pcall (run()). Every handler, timer callback and slash command is wrapped: an error is
-- recorded, never raised to the player's screen.

local ADDON, ns = ...
ADDON = ADDON or "DeadTiredProbe"
ns = ns or {}
local P = {}
ns.P = P

local SECRET, NIL, ABSENT = "<secret>", "<nil>", "<absent>"
local PREFIX = "DTPROBE"
local CAP = { runs = 5, msgs = 10, targets = 10, deaths = 5, played = 5, channels = 5,
  slots = 200, calendar = 60, members = 40, recipes = 5, guildEvents = 5, errors = 10,
  recipeEvents = 5, bagIndexKeys = 40 }
P.CAP = CAP
local ITEMS = { 13446, 17029, 17020, 17033, 17026, 17030, 6265, 5140 }   -- card 5's starter list
local ORDER = { "build", "login", "guild", "comms", "channels", "bags", "items", "time",
  "played", "target", "death", "calendar", "recipes" }
P.ORDER = ORDER

-- ---------------------------------------------------------------- guarded reads
-- Copied from reference/wizardry/Forever/Core.lua (W.secret, W.try, W.clean), bodies kept.

function P.secret(v)
  return issecretvalue ~= nil and issecretvalue(v) and true or false
end
-- The probe's one addition: an issecretvalue that errors counts as secret (fail closed), so a
-- throwing client can't make a read raise. try and clean below use this.
local function secret(v)
  local ok, s = pcall(P.secret, v)
  return (not ok) or s
end

function P.try(fn, ...)
  if type(fn) ~= "function" then return nil end
  local r = { pcall(fn, ...) }
  if not r[1] or secret(r[2]) then return nil end
  return unpack(r, 2, table.maxn(r))
end
local try = P.try

function P.clean(v)
  if v == nil or secret(v) then return nil end
  return v
end
local clean = P.clean

-- ---------------------------------------------------------------- rec and ask

local function cut(s, n)
  local ok, t = pcall(tostring, s)
  t = ok and t or "?"
  if #t > n then t = t:sub(1, n) end
  return t
end

-- rec(v): what gets stored. Secret, nil, function, table, as the brief's "Shape of the record".
function P.rec(v, depth)
  if secret(v) then return SECRET end                              -- guard: rec's secret branch
  if v == nil then return NIL end
  local t = type(v)
  if t == "function" then return "<function>" end
  if t == "userdata" or t == "thread" then return "<" .. t .. ">" end
  if t == "table" then
    depth = depth or 1
    if depth > 3 then return "<table>" end
    local out, n = {}, 0
    for k, x in pairs(v) do
      n = n + 1
      if n > 20 then out["<more>"] = true break end
      local key = k
      if secret(k) then key = SECRET
      elseif type(k) ~= "string" and type(k) ~= "number" then key = cut(k, 40) end
      out[key] = P.rec(x, depth + 1)
    end
    return out
  end
  return v
end
local rec = P.rec

-- select("#") and not table.maxn: a trailing nil ("both returns" of UnitName) is kept.
local function pack(...) return { n = select("#", ...), ... } end

-- askRaw(f, ...): the call itself. Returns the raw results packed { n = count, ... }, or nil and
-- the reason. ask() is rec() over it; both branches below are ask's.
function P.askRaw(f, ...)
  if type(f) ~= "function" then return nil, ABSENT end             -- guard: ask's absent branch
  local r = pack(pcall(f, ...))
  local n = r.n
  if not r[1] then                                                 -- guard: ask's error branch
    return nil, "<error: " .. cut(r[2], 120) .. ">"
  end
  local out = { n = n - 1 }
  for i = 2, n do out[i - 1] = r[i] end
  return out
end
local askRaw = P.askRaw

-- ask(f, ...): "<absent>", "<error: ...>", or the list of results, each through rec.
function P.ask(f, ...)
  local r, why = askRaw(f, ...)
  if not r then return why end
  local out = {}
  for i = 1, r.n do out[i] = rec(r[i]) end
  return out
end
local ask = P.ask

-- The first value of an ask() answer, or the reason it has none.
local function first(x)
  if type(x) ~= "table" then return x end
  if x[1] == nil then return NIL end
  return x[1]
end
P.first = first

-- A game function by path ("GetTime", "C_ChatInfo.SendAddonMessage"), looked up at call time.
local function fn(path)
  local ok, f = pcall(function()
    local t = _G
    for part in path:gmatch("[^%.]+") do
      if type(t) ~= "table" then return nil end
      t = t[part]
    end
    return t
  end)
  return ok and f or nil
end
local function A(path, ...) return ask(fn(path), ...) end          -- recorded
local function A1(path, ...) return first(ask(fn(path), ...)) end  -- recorded, first value
local function T(path, ...) return try(fn(path), ...) end          -- for logic, secrets dropped

local function now()
  local t = clean(T("GetTime"))
  return type(t) == "number" and t or nil
end

-- Copied pattern: reference W.charKey (Realm-Name; nil while UnitName answers "Unknown").
local function charKey()
  local name, realm = clean(T("UnitName", "player")), clean(T("GetRealmName"))
  if type(name) ~= "string" or name == "" or name == "Unknown"
     or (UNKNOWNOBJECT and name == UNKNOWNOBJECT) then return nil end
  if type(realm) ~= "string" or realm == "" then return nil end
  return realm .. "-" .. name
end

local function out(m)
  local s = "Dead Tired probe: " .. tostring(m)
  local f = DEFAULT_CHAT_FRAME
  if type(f) == "table" and type(f.AddMessage) == "function" and pcall(f.AddMessage, f, s) then
    return
  end
  pcall(print, s)
end

-- Run fn after d seconds, wrapped. False when the client has no timer (the caller then runs
-- its fallback at once).
local function after(d, f)
  local ok = pcall(fn("C_Timer.After"), d, function() pcall(f) end)
  return ok
end
P.after = after

-- ---------------------------------------------------------------- the record

local DB, cur, attached, key

local function newRun()
  local at = clean(T("time"))
  return { at = type(at) == "number" and at or ABSENT, inGuild = T("IsInGuild") == true,
    sections = {} }
end

local function noteError(where, err)
  if not cur then return end
  cur.errors = cur.errors or {}
  if #cur.errors < CAP.errors then cur.errors[#cur.errors + 1] = where .. ": " .. cut(err, 120) end
end

local function ensureDB()
  if type(DeadTiredProbeDB) ~= "table" then DeadTiredProbeDB = {} end
  DB = DeadTiredProbeDB
  DB.version = 1
  if type(DB.chars) ~= "table" then DB.chars = {} end
  if not cur then cur = newRun() end
end

-- Put the current run under this character, once its name is known (force: under "?-?").
local function attach(force)
  if attached then return end
  ensureDB()
  local k = charKey()
  if not k then
    if not force then return end
    k = "?-?"
  end
  key = k
  local c = DB.chars[k]
  if type(c) ~= "table" then c = {} DB.chars[k] = c end
  if type(c.runs) ~= "table" then c.runs = {} end
  c.runs[#c.runs + 1] = cur
  while #c.runs > CAP.runs do table.remove(c.runs, 1) end
  attached = true
end

-- Each section in its own pcall. A failure is kept in the section; the next one still runs.
local function run(name, f, ...)
  ensureDB()
  local secs = cur.sections
  if type(secs[name]) ~= "table" then secs[name] = {} end
  local sec = secs[name]
  local r = { pcall(f, sec, ...) }                                  -- guard: per-section pcall
  if not r[1] then
    secs[name] = secs[name] or sec
    secs[name].failed = cut(r[2], 200)
    return false
  end
  return true, unpack(r, 2, table.maxn(r))
end
P.run = run

local S = {}      -- section bodies, by name: S.x(sec, ...)
P.S = S
local function R(name, ...) return run(name, function(sec, ...) return S[name](sec, ...) end, ...) end

local function guildNow()
  local g = { A("GetGuildInfo", "player") }
  return g[1]
end

-- ---------------------------------------------------------------- 1 build (automatic)

function S.build(sec)
  sec.buildInfo = A("GetBuildInfo")
  sec.WOW_PROJECT_ID = rec(WOW_PROJECT_ID)
  sec.realm = A1("GetRealmName")
  sec.normalizedRealm = A1("GetNormalizedRealmName")
  sec.gameMode = A1("C_GameRules.GetActiveGameMode")
  sec.hardcore = A1("C_GameRules.IsHardcoreActive")
  sec.selfFound = A1("C_GameRules.IsSelfFoundActive")
  sec.level = A1("UnitLevel", "player")
  sec.class = A("UnitClass", "player")
end

-- ---------------------------------------------------------------- 2 login (automatic)

local function stamp(sec, field)
  local s = { t = A1("GetTime"), guild = A("GetGuildInfo", "player") }
  if field then sec[field] = s end
  local name = clean(T("GetGuildInfo", "player"))
  if not sec.firstGuildName and type(name) == "string" and name ~= "" then
    sec.firstGuildName = { t = s.t, name = name }
  end
  return s
end

function S.login(sec, ev, a, b)
  if ev == "ADDON_LOADED" then stamp(sec, "loaded")
  elseif ev == "PLAYER_LOGIN" then stamp(sec, "login")
  elseif ev == "PLAYER_ENTERING_WORLD" then
    sec.worldCount = (sec.worldCount or 0) + 1
    if sec.worldCount == 1 then
      local s = stamp(sec, "world")
      s.isInitialLogin, s.isReloadingUi = rec(a), rec(b)
    else stamp(sec) end
  else
    local field = ev == "PLAYER_GUILD_UPDATE" and "guildUpdates" or "rosterUpdates"
    sec[field .. "Count"] = (sec[field .. "Count"] or 0) + 1
    if type(sec[field]) ~= "table" then sec[field] = {} end
    if #sec[field] < CAP.guildEvents then sec[field][#sec[field] + 1] = stamp(sec)
    else stamp(sec) end
  end
end

-- ---------------------------------------------------------------- 3 guild (PEW + 15 s)

function S.guild(sec)
  sec.at = A1("GetTime")
  sec.isInGuild = A1("IsInGuild")
  sec.guildInfo = A("GetGuildInfo", "player")
  sec.officer = A1("C_GuildInfo.IsGuildOfficer")
  sec.canSpeak = A1("C_GuildInfo.CanSpeakInGuildChat")
  sec.noGuild = T("IsInGuild") ~= true
  cur.inGuild = not sec.noGuild
end

-- ---------------------------------------------------------------- 4 comms (PEW + 15 s, ping, messages)

local function register(sec)
  sec.register = A1("C_ChatInfo.RegisterAddonMessagePrefix", PREFIX)
  sec.registered = sec.register == true
end

function S.comms(sec)
  sec.at = A1("GetTime")
  sec.restricted = A1("C_ChatInfo.AreOutgoingAddonChatMessagesRestricted")
  sec.lockdown = A1("C_ChatInfo.InChatMessagingLockdown")
  register(sec)
end

-- Restricted means held (house rule: queued, not forced): retried every 5 s for a minute.
local function sendPing(sec, p, tries)
  if T("C_ChatInfo.AreOutgoingAddonChatMessagesRestricted") == true then
    p.held = (p.held or 0) + 1
    if tries >= 12 then p.result = "<gave up: still restricted after 60 s>" return "gave up" end
    if not after(5, function() run("comms", function(s2) sendPing(s2, p, tries + 1) end) end) then
      p.result = "<held: restricted, and no timer to retry>"
    end
    return "held"
  end
  p.result = A("C_ChatInfo.SendAddonMessage", PREFIX, "ping", p.channel)
  p.sentAt = A1("GetTime")
  return "sent"
end

function S.ping(sec)
  if not sec.registered then register(sec) end
  sec.pings = sec.pings or {}
  local p = { at = A1("GetTime") }
  sec.pings[#sec.pings + 1] = p
  if #sec.pings > CAP.msgs then table.remove(sec.pings, 1) end
  local channel                                                    -- guard: channel choice
  if T("IsInGuild") == true then channel = "GUILD"
  elseif T("IsInGroup") == true then channel = "PARTY" end
  if not channel then
    p.channel = "<none: no guild, no group>"
    return "not sent: no guild and no group"
  end
  p.channel = channel
  local how = sendPing(sec, p, 0)
  if how == "held" then return "held on " .. channel .. ": addon messages restricted; it goes when they lift" end
  return how .. " on " .. channel
end

function S.message(sec, prefix, text, channel, sender)
  if clean(prefix) ~= PREFIX then return end
  sec.heard = (sec.heard or 0) + 1
  sec.messages = sec.messages or {}
  if #sec.messages >= CAP.msgs then sec.dropped = (sec.dropped or 0) + 1 return end  -- guard: cap
  local amb = A1("Ambiguate", sender, "none")
  local me, realm = clean(T("UnitName", "player")), clean(T("GetNormalizedRealmName"))
  local s = clean(sender)
  local isMe = NIL
  if type(s) == "string" and type(me) == "string" then
    isMe = s == me or (type(realm) == "string" and s == me .. "-" .. realm)
      or (type(amb) == "string" and amb == me)
  end
  local t = clean(text)
  sec.messages[#sec.messages + 1] = { t = A1("GetTime"), sender = rec(sender), ambiguated = amb,
    channel = rec(channel), text = type(t) == "string" and t:sub(1, 20) or rec(text), isMe = isMe }
end

-- ---------------------------------------------------------------- 5 channels (PEW + 15 s, command)

function S.channels(sec)
  sec.snapshots = sec.snapshots or {}
  if #sec.snapshots >= CAP.channels then                            -- guard: cap
    sec.refused = (sec.refused or 0) + 1
    return "already " .. CAP.channels .. " snapshots"
  end
  local s = { t = A1("GetTime") }
  s.channelList = A("GetChannelList")
  s.serverChannels = A("EnumerateServerChannels")
  s.numActive = A1("C_ChatInfo.GetNumActiveChannels")
  s.generalID = A1("C_ChatInfo.GetGeneralChannelID")
  s.generalLocalID = A1("C_ChatInfo.GetGeneralChannelLocalID")
  s.byIndex = {}
  for i = 1, 20 do s.byIndex[i] = A("GetChannelName", i) end
  s.zone = A1("GetRealZoneText")
  sec.snapshots[#sec.snapshots + 1] = s
end

-- ---------------------------------------------------------------- 6 bags (command, bank open)

local bankOpen = false

local function boundAt(bag, slot)
  local IL = ItemLocation
  if type(IL) ~= "table" then return ABSENT end
  local r, why = askRaw(IL.CreateFromBagAndSlot, IL, bag, slot)
  if not r then return "<no location: " .. why .. ">" end
  return A1("C_Item.IsBound", r[1])
end

local function bankBags(idx)
  local list, seen = {}, {}
  if type(idx) == "table" then
    for k, v in pairs(idx) do
      if type(k) == "string" and k:lower():find("bank") and type(v) == "number"
         and not (v >= 0 and v <= 4) and not seen[v] then
        seen[v] = true
        list[#list + 1] = v
      end
    end
    table.sort(list)
  end
  if #list == 0 then list = { -1, 5, 6, 7, 8, 9, 10, 11 } end
  return list
end

function S.bags(sec, why)
  local snap = { t = A1("GetTime"), why = why, bankOpen = bankOpen, slots = {}, bags = {},
    capped = false }
  local E = Enum
  local idx = type(E) == "table" and E.BagIndex or nil
  snap.bagIndex = idx == nil and ABSENT or rec(idx)
  snap.numSlotsByIndex = {}
  if type(idx) == "table" then
    local n = 0
    for k, v in pairs(idx) do
      n = n + 1
      if n > CAP.bagIndexKeys then break end
      snap.numSlotsByIndex[cut(k, 40)] = A1("C_Container.GetContainerNumSlots", v)
    end
  end
  local list = { 0, 1, 2, 3, 4 }
  if bankOpen then for _, b in ipairs(bankBags(idx)) do list[#list + 1] = b end end
  local ids, seen = {}, {}
  for _, bag in ipairs(list) do
    if snap.capped then break end
    local b = { bag = bag, numSlots = A1("C_Container.GetContainerNumSlots", bag), errors = 0 }
    snap.bags[#snap.bags + 1] = b
    local n = clean(T("C_Container.GetContainerNumSlots", bag))
    if type(n) == "number" then
      for slot = 1, math.min(n, 200) do
        if #snap.slots >= CAP.slots then snap.capped = true break end   -- guard: slot cap
        local r, err = askRaw(fn("C_Container.GetContainerItemInfo"), bag, slot)
        if not r then
          b.errors = b.errors + 1
          b.firstError = b.firstError or err
        elseif r[1] ~= nil then
          local info = r[1]
          local e = { bag = bag, slot = slot }
          if secret(info) then e.info = SECRET
          elseif type(info) == "table" then
            e.itemID = rec(info.itemID)
            e.isBound = rec(info.isBound)
            e.isBoundByLocation = boundAt(bag, slot)
            local id = clean(info.itemID)
            if type(id) == "number" and not seen[id] and #ids < 5 then seen[id] = true ids[#ids + 1] = id end
          else e.info = rec(info) end
          snap.slots[#snap.slots + 1] = e
        end
      end
    end
  end
  snap.counts = {}
  for _, id in ipairs(ids) do
    snap.counts[#snap.counts + 1] = { id = id, count = A1("C_Item.GetItemCount", id),
      withBank = A1("C_Item.GetItemCount", id, true) }
  end
  if why == "bank" then sec.bank = snap else sec.last = snap end
  sec.snapshots = (sec.snapshots or 0) + 1
end

-- ---------------------------------------------------------------- 7 items (command)

local itemsOpen = false

function S.items(sec)
  sec.asks = (sec.asks or 0) + 1
  sec.askedAt = now()
  sec.list = {}
  local pending = 0
  for _, id in ipairs(ITEMS) do
    local e = { id = id, instant = A("C_Item.GetItemInfoInstant", id) }
    e.name = A1("C_Item.GetItemInfo", id)
    if e.name == NIL then
      e.requested = A("C_Item.RequestLoadItemDataByID", id)
      e.pending = true
      pending = pending + 1
    end
    sec.list[#sec.list + 1] = e
  end
  itemsOpen = pending > 0
  if itemsOpen then
    local asks = sec.asks
    after(30, function()
      run("items", function(s2)
        if s2.asks ~= asks then return end
        itemsOpen = false
        for _, e in ipairs(s2.list or {}) do
          if e.pending then e.pending = nil e.received = "<not in 30 s>" end
        end
      end)
    end)
  end
  return pending
end

function S.itemReceived(sec, itemID, success)
  if not itemsOpen or type(sec.list) ~= "table" then return end
  local t = now()
  if t and type(sec.askedAt) == "number" and t - sec.askedAt > 30 then itemsOpen = false return end
  local id = clean(itemID)
  for _, e in ipairs(sec.list) do
    if e.pending and e.id == id then
      e.pending = nil
      e.name = A1("C_Item.GetItemInfo", id)
      e.received = { after = (t and type(sec.askedAt) == "number") and (t - sec.askedAt) or NIL,
        success = rec(success) }
    end
  end
end

-- ---------------------------------------------------------------- 8 time (PEW + 15 s)

function S.time(sec)
  sec.time = A1("time")
  sec.serverTime = A1("GetServerTime")
  sec.serverTimeLocal = A1("C_DateAndTime.GetServerTimeLocal")
  sec.calendarTime = A1("C_DateAndTime.GetCurrentCalendarTime")
  sec.gameTime = A("GetGameTime")
  sec.date = A1("date", "%Y-%m-%d %H:%M:%S")
end

-- ---------------------------------------------------------------- 9 played (hook at load, events)

local typedAt   -- the hook's stamp: a number, "<no clock>", or nil

function S.played(sec)
  sec.events = sec.events or {}
  sec.typed = sec.typed or 0
  local list = SlashCmdList
  sec.hook = { playedType = type(list) == "table" and type(list.PLAYED) or ABSENT }
  -- card 6's named risk: a /played the chat system already cached is never seen by the hook.
  local okH, cached = pcall(function() return type(hash_SlashCmdList) == "table"
    and type(hash_SlashCmdList["/PLAYED"]) or ABSENT end)
  sec.hook.cachedBeforeHook = okH and cached or "<error>"
  if type(hooksecurefunc) ~= "function" then
    sec.hook.placed, sec.hook.why = false, "hooksecurefunc " .. ABSENT
    return
  end
  local ok, err = pcall(hooksecurefunc, list, "PLAYED", function()   -- guard: the hook's own pcall
    pcall(function()
      typedAt = now() or "<no clock>"
      local s = cur and cur.sections.played
      if type(s) == "table" then s.typed = (s.typed or 0) + 1 end
    end)
  end)
  sec.hook.placed = ok and true or false
  if not ok then sec.hook.why = "<error: " .. cut(err, 120) .. ">" end
end

function S.playedMsg(sec, ...)
  sec.events = sec.events or {}
  sec.seen = (sec.seen or 0) + 1
  local at = typedAt
  typedAt = nil
  if #sec.events >= CAP.played then sec.dropped = (sec.dropped or 0) + 1 return end  -- guard: cap
  local args = {}
  for i = 1, select("#", ...) do args[i] = rec((select(i, ...))) end
  local age
  if at == nil then age = "<no stamp>"
  elseif type(at) == "number" and now() then age = now() - at
  else age = "<no clock>" end
  sec.events[#sec.events + 1] = { t = A1("GetTime"), args = args, stampAge = age }
end

-- ---------------------------------------------------------------- 10 target (command)

function S.target(sec)
  sec.snapshots = sec.snapshots or {}
  if #sec.snapshots >= CAP.targets then                             -- guard: cap
    sec.refused = (sec.refused or 0) + 1
    return "already " .. CAP.targets .. " snapshots"
  end
  sec.snapshots[#sec.snapshots + 1] = {
    t = A1("GetTime"),
    exists = A1("UnitExists", "target"),
    isPlayer = A1("UnitIsPlayer", "target"),
    factionTarget = A("UnitFactionGroup", "target"),
    factionPlayer = A("UnitFactionGroup", "player"),
    name = A("UnitName", "target"),
    class = A("UnitClass", "target"),
    level = A1("UnitLevel", "target"),
    isEnemy = A1("UnitIsEnemy", "player", "target"),
    lockdown = A1("InCombatLockdown"),
    affectingCombat = A1("UnitAffectingCombat", "player"),
  }
end

-- ---------------------------------------------------------------- 11 death (automatic)

function S.death(sec, ev)
  sec.deaths = sec.deaths or {}
  sec.count = sec.count or 0
  if ev ~= "PLAYER_DEAD" then return end
  sec.count = sec.count + 1
  if #sec.deaths >= CAP.deaths then return end                      -- guard: cap
  sec.deaths[#sec.deaths + 1] = { t = A1("GetTime"), instance = A("IsInInstance"),
    zone = A1("GetRealZoneText"), level = A1("UnitLevel", "player"),
    hardcore = A1("C_GameRules.IsHardcoreActive") }
end

-- ---------------------------------------------------------------- 12 calendar (command)

local function daysIn(m, y)
  local d = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  if m == 2 and (y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0)) then return 29 end
  return d[m] or 31
end

local calPending, calAsk = false, 0

function S.calendarRead(sec, by)
  if not calPending then return end
  calPending = false
  sec.readBy = by
  sec.readAt = A1("GetTime")
  sec.events = {}
  sec.days = {}
  local y, m, d, from
  local ct = T("C_DateAndTime.GetCurrentCalendarTime")
  if type(ct) == "table" then
    y, m, d, from = clean(ct.year), clean(ct.month), clean(ct.monthDay), "GetCurrentCalendarTime"
  end
  if type(y) ~= "number" or type(m) ~= "number" or type(d) ~= "number" then
    local t = T("date", "*t")
    if type(t) == "table" then y, m, d, from = clean(t.year), clean(t.month), clean(t.day), "date" end
  end
  if type(y) ~= "number" or type(m) ~= "number" or type(d) ~= "number" then
    sec.today = "<no date: calendar time and date() both unavailable>"
    return
  end
  sec.today = { year = y, month = m, day = d, from = from }
  local offset = 0
  for i = 0, 13 do
    local day = { i = i, offset = offset, monthDay = d, num = A1("C_Calendar.GetNumDayEvents", offset, d) }
    sec.days[#sec.days + 1] = day
    local n = clean(T("C_Calendar.GetNumDayEvents", offset, d))
    if type(n) == "number" then
      for e = 1, n do
        if #sec.events >= CAP.calendar then sec.capped = true break end  -- guard: cap
        local r, why = askRaw(fn("C_Calendar.GetDayEvent"), offset, d, e)
        local ev = r and r[1]
        local entry = { i = i, offset = offset, monthDay = d, index = e }
        if not r then entry.error = why
        elseif type(ev) == "table" and not secret(ev) then
          entry.title = rec(ev.title)
          entry.calendarType = rec(ev.calendarType)
          entry.sequenceType = rec(ev.sequenceType)
          entry.startTime = rec(ev.startTime)
        else entry.event = rec(ev) end
        sec.events[#sec.events + 1] = entry
      end
    end
    d = d + 1
    if d > daysIn(m, y) then d, m, offset = 1, m + 1, offset + 1 if m > 12 then m, y = 1, y + 1 end end
  end
end

function S.calendar(sec)
  calAsk = calAsk + 1
  local ask_ = calAsk
  sec.asks = calAsk
  sec.readBy, sec.events, sec.days, sec.today = nil, nil, nil, nil
  sec.open = A1("C_Calendar.OpenCalendar")
  calPending = true
  local placed = after(10, function()
    if ask_ == calAsk then run("calendar", function(s2) S.calendarRead(s2, "10 s timer") end) end
  end)
  if not placed then S.calendarRead(sec, "at once (no timer)") end
end

-- ---------------------------------------------------------------- 13 recipes (command)

function S.recipes(sec)
  sec.attempts = sec.attempts or {}
  if #sec.attempts >= CAP.recipes then                              -- guard: cap
    sec.refused = (sec.refused or 0) + 1
    return "already " .. CAP.recipes .. " attempts"
  end
  local a = { t = A1("GetTime"), events = {} }
  sec.attempts[#sec.attempts + 1] = a
  a.inGuild = A1("IsInGuild")
  a.noGuild = T("IsInGuild") ~= true
  a.fns = {
    QueryGuildMembersForRecipe = type(fn("C_GuildInfo.QueryGuildMembersForRecipe")) == "function",
    QueryGuildMemberRecipes = type(fn("C_GuildInfo.QueryGuildMemberRecipes")) == "function",
    GetGuildRecipeInfoPostQuery = type(fn("GetGuildRecipeInfoPostQuery")) == "function",
    GetGuildRecipeMember = type(fn("GetGuildRecipeMember")) == "function",
  }
  a.ready = A1("C_TradeSkillUI.IsTradeSkillReady")
  local r, why = askRaw(fn("C_TradeSkillUI.GetAllRecipeIDs"))
  local ids = r and r[1]
  local id
  if not r then a.why = "no recipe ID: GetAllRecipeIDs " .. why
  elseif secret(ids) then a.why = "no recipe ID: the list is secret"
  elseif type(ids) ~= "table" then a.why = "no recipe ID: GetAllRecipeIDs answered " .. tostring(rec(ids))
  else
    id = clean(ids[1])
    if type(id) ~= "number" then a.why = "no recipe ID: the list is empty" id = nil end
  end
  if not id then return a end
  a.recipeID = id
  a.line = A("C_TradeSkillUI.GetTradeSkillLineForRecipe", id)
  local child, _, parent = T("C_TradeSkillUI.GetTradeSkillLineForRecipe", id)
  parent = clean(parent)
  local line = type(parent) == "number" and parent or clean(child)
  a.queryLine = rec(line)
  a.query = A("C_GuildInfo.QueryGuildMembersForRecipe", line, id)
  a.open = true
  a.openedAt = now()
  local n = #sec.attempts
  if not after(10, function()
    run("recipes", function(s2) local x = s2.attempts and s2.attempts[n] if x then x.open = false end end)
  end) then a.window = "<no timer: open until the next attempt>" end
  return a
end

function S.recipeEvent(sec)
  local a = sec.attempts and sec.attempts[#sec.attempts]
  local t = now()
  if not a or not a.open or (t and a.openedAt and t - a.openedAt > 10) then
    sec.stray = (sec.stray or 0) + 1
    return
  end
  if #a.events >= CAP.recipeEvents then a.droppedEvents = (a.droppedEvents or 0) + 1 return end
  local e = { t = rec(t), info = A("GetGuildRecipeInfoPostQuery"), members = {} }
  a.events[#a.events + 1] = e
  local _, _, n = T("GetGuildRecipeInfoPostQuery")
  n = clean(n)
  if type(n) ~= "number" then return end
  e.numMembers = n
  for i = 1, n do
    if #e.members >= CAP.members then e.capped = true break end    -- guard: cap
    e.members[#e.members + 1] = A("GetGuildRecipeMember", i)
  end
end

-- ---------------------------------------------------------------- headlines

local function s(v) if type(v) == "table" then return tostring(v[1]) end return tostring(v) end
local function yn(v) if v == true then return "yes" elseif v == false then return "no" end return tostring(v) end

local H = {}
function H.build(x)
  local b = x.buildInfo
  if type(b) == "table" then
    return string.format("%s (build %s, interface %s), realm %s, hardcore: %s", tostring(b[1]),
      tostring(b[2]), tostring(b[4]), tostring(x.realm), yn(x.hardcore))
  end
  return "build info " .. tostring(b) .. ", realm " .. tostring(x.realm)
end
function H.login(x)
  local g = x.firstGuildName and ("guild name first seen at " .. tostring(x.firstGuildName.t))
    or "no guild name seen"
  return string.format("%s; guild updates %d, roster updates %d", g, x.guildUpdatesCount or 0,
    x.rosterUpdatesCount or 0)
end
function H.guild(x)
  if x.noGuild then return "no guild (in guild: " .. yn(x.isInGuild) .. ")" end
  local gi = type(x.guildInfo) == "table" and x.guildInfo or {}
  return string.format("%s, rank %s, officer: %s, can speak: %s", tostring(gi[1]), tostring(gi[2]),
    yn(x.officer), yn(x.canSpeak))
end
function H.comms(x)
  local last = x.pings and x.pings[#x.pings]
  return string.format("restricted: %s, prefix registered: %s, pings: %d%s, heard: %d",
    yn(x.restricted), yn(x.registered), x.pings and #x.pings or 0,
    last and (" (last " .. tostring(last.channel) .. ")") or "", x.heard or 0)
end
function H.channels(x)
  local last = x.snapshots and x.snapshots[#x.snapshots]
  if not last then return "no snapshot" end
  return string.format("%d snapshot(s), general ID %s, active %s, zone %s", #x.snapshots,
    tostring(last.generalID), tostring(last.numActive), tostring(last.zone))
end
function H.bags(x)
  local function one(snap)
    if not snap then return nil end
    local nilBound = 0
    for _, e in ipairs(snap.slots) do if e.isBound == NIL then nilBound = nilBound + 1 end end
    return string.format("%d slots%s, isBound nil on %d", #snap.slots, snap.capped and " (capped)" or "", nilBound)
  end
  local parts = {}
  if x.last then parts[#parts + 1] = one(x.last) end
  if x.bank then parts[#parts + 1] = "at the bank " .. one(x.bank) end
  return #parts > 0 and table.concat(parts, "; ") or "no snapshot"
end
function H.items(x)
  local known, pending = 0, 0
  for _, e in ipairs(x.list or {}) do
    if type(e.name) == "string" and not e.name:find("^<") then known = known + 1 end
    if e.pending then pending = pending + 1 end
  end
  return string.format("%d of %d named, %d waiting for item data", known, #ITEMS, pending)
end
function H.time(x)
  return string.format("time %s, server %s, server local %s, date %s", tostring(x.time),
    tostring(x.serverTime), tostring(x.serverTimeLocal), tostring(x.date))
end
function H.played(x)
  local h = x.hook or {}
  local last = x.events and x.events[#x.events]
  return string.format("hook placed: %s, typed %d, events %d%s", yn(h.placed), x.typed or 0,
    x.events and #x.events or 0, last and (", last stamp age " .. tostring(last.stampAge)) or "")
end
function H.target(x)
  local t = x.snapshots and x.snapshots[#x.snapshots]
  if not t then return "no snapshot" end
  local name = s(t.name)
  local combat = (t.lockdown == true or t.affectingCombat == true) and "yes" or "no"
  return string.format("%s, level %s, in combat: %s, name secret: %s", name, tostring(t.level),
    combat, name == SECRET and "yes" or "no")
end
function H.death(x)
  local d = x.deaths and x.deaths[#x.deaths]
  return string.format("%d death(s)%s", x.count or 0, d and (", last in " .. tostring(d.zone)) or "")
end
function H.calendar(x)
  if not x.readBy then return "asked; waiting for the event list (10 s at most)" end
  if type(x.today) ~= "table" then return "read " .. tostring(x.readBy) .. ": " .. tostring(x.today) end
  return string.format("%d event(s) over 14 days%s, read by %s", #x.events, x.capped and " (capped)" or "",
    tostring(x.readBy))
end
function H.recipes(x)
  local a = x.attempts and x.attempts[#x.attempts]
  if not a then return "no attempt" end
  local guild = a.noGuild and ", no guild" or ""
  if not a.recipeID then return string.format("attempt %d%s: %s", #x.attempts, guild, tostring(a.why)) end
  local members = 0
  for _, e in ipairs(a.events) do members = members + #e.members end
  return string.format("attempt %d%s: recipe %s, line %s, answers %d, members %d", #x.attempts, guild,
    tostring(a.recipeID), tostring(a.queryLine), #a.events, members)
end
P.H = H

local function headline(name)
  local x = cur and cur.sections[name]
  if type(x) ~= "table" then return "not run yet" end
  if x.failed then return "failed: " .. x.failed end
  local ok, h = pcall(H[name], x)
  return ok and h or ("headline failed: " .. cut(h, 80))
end
P.headline = headline

-- ---------------------------------------------------------------- events

local loadedOnce, worldOnce = false, false

local function delayed()
  attach(true)
  R("guild")
  R("comms")
  R("channels")
  R("time")
end
P.delayed = delayed

local E = {}
E.ADDON_LOADED = function(name)
  if name ~= ADDON or loadedOnce then return end
  loadedOnce = true
  ensureDB()
  R("login", "ADDON_LOADED")
  R("played")
  out("recording. /dtprobe for commands.")
end
E.PLAYER_LOGIN = function()
  attach()
  R("login", "PLAYER_LOGIN")
  R("build")
  R("death", "init")
end
E.PLAYER_ENTERING_WORLD = function(a, b)
  attach()
  R("login", "PLAYER_ENTERING_WORLD", a, b)
  if worldOnce then return end
  worldOnce = true
  if not after(15, delayed) then
    cur.timer = "<no timer: the 15 s sections ran at once>"
    delayed()
  end
end
E.PLAYER_GUILD_UPDATE = function() R("login", "PLAYER_GUILD_UPDATE") end
E.GUILD_ROSTER_UPDATE = function() R("login", "GUILD_ROSTER_UPDATE") end
E.CHAT_MSG_ADDON = function(...) run("comms", S.message, ...) end
E.BANKFRAME_OPENED = function()
  bankOpen = true
  local b = cur.sections.bags
  if not (type(b) == "table" and b.bank) then R("bags", "bank") end
end
E.BANKFRAME_CLOSED = function() bankOpen = false end
E.GET_ITEM_INFO_RECEIVED = function(...) run("items", S.itemReceived, ...) end
E.TIME_PLAYED_MSG = function(...) run("played", S.playedMsg, ...) end
E.PLAYER_DEAD = function() R("death", "PLAYER_DEAD") end
E.CALENDAR_UPDATE_EVENT_LIST = function()
  if calPending then run("calendar", S.calendarRead, "event") end
end
E.GUILD_RECIPE_KNOWN_BY_MEMBERS = function() run("recipes", S.recipeEvent) end

local function onEvent(_, ev, ...)
  local h = E[ev]
  if not h then return end
  if ev ~= "ADDON_LOADED" and not cur then return end
  local ok, err = pcall(h, ...)
  if not ok then noteError(tostring(ev), err) end
end
P.onEvent = onEvent

local okF, frame = pcall(CreateFrame, "Frame")
if okF and type(frame) == "table" then
  for ev in pairs(E) do pcall(frame.RegisterEvent, frame, ev) end
  pcall(frame.SetScript, frame, "OnEvent", onEvent)
end
P.frame = okF and frame or nil

-- ---------------------------------------------------------------- /dtprobe

local LIST = "/dtprobe ping, channels, bags, items, target, calendar, recipes, report, reset."

local REPLY = {
  ping = function(r) return "ping: " .. tostring(r) end,
  items = function(r) return "items: " .. headline("items") ..
    ((type(r) == "number" and r > 0) and "; names fill in over 30 s" or "") end,
  calendar = function() return "calendar: " .. headline("calendar") end,
}

local function command(verb)
  attach(true)
  if verb == "report" then
    for _, name in ipairs(ORDER) do out(name .. ": " .. headline(name)) end
    return
  end
  if verb == "reset" then
    if key and DB.chars[key] then DB.chars[key].runs = {} end
    attached = false
    local old = cur
    cur = newRun()
    -- the hook and the death counter belong to the login, not the run: carry their state.
    if old and type(old.sections.played) == "table" then
      cur.sections.played = { hook = old.sections.played.hook, typed = 0, events = {} }
    end
    attach(true)
    out("this character's runs cleared. A fresh one is recording.")
    return
  end
  local name = verb == "ping" and "comms" or verb
  local okRun, r = run(name, S[verb])
  if not okRun then out(verb .. ": failed: " .. tostring(cur.sections[name].failed)) return end
  if type(r) == "string" and verb ~= "ping" then out(verb .. ": " .. r) return end
  if REPLY[verb] then out("recorded " .. REPLY[verb](r)) return end
  out("recorded " .. verb .. ": " .. headline(name))
end

local VERBS = { ping = true, channels = true, bags = true, items = true, target = true,
  calendar = true, recipes = true, report = true, reset = true }

function P.dispatch(msg)
  local verb = (type(msg) == "string" and msg or ""):lower():match("^%s*(%S*)")
  if not VERBS[verb] then out(LIST) return end
  command(verb)
end

SLASH_DTPROBE1 = "/dtprobe"
if type(SlashCmdList) ~= "table" then SlashCmdList = {} end
SlashCmdList["DTPROBE"] = function(msg)
  local ok, err = pcall(P.dispatch, msg)
  if not ok then pcall(noteError, "slash", err) end
end

-- for the offline suite
function P.state() return { db = DB, cur = cur, key = key, attached = attached } end
