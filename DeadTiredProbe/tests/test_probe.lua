-- Offline checks for DeadTiredProbe/Probe.lua (docs/COWORK_BRIEF_dt_probe.md, Task 5).
--   lua5.1 DeadTiredProbe/tests/test_probe.lua      (from the repo root)
-- House style of reference/wizardry/tests/test_forever_core.lua: plain Lua, a check() counter,
-- exit non-zero on any failure. PROBE_FILE=<path> runs the suite against another copy of
-- Probe.lua (used for the guard proofs; the addon file is never edited by the suite).

local PROBE = os.getenv("PROBE_FILE") or "DeadTiredProbe/Probe.lua"
local fails, passes = 0, 0
local realPrint = print
local function check(name, cond)
  if cond then passes = passes + 1 else fails = fails + 1; realPrint("FAIL " .. name) end
end

-- ---------------------------------------------------------------- the world

local S, frames
local fire   -- forward: the LoggingCombat stub fires ADDON_ACTION_BLOCKED
local SECRET_V = setmetatable({}, { __tostring = function() return "SECRETVALUE" end })

local GLOBAL_FNS = { "GetTime", "time", "date", "GetBuildInfo", "GetRealmName",
  "GetNormalizedRealmName", "UnitName", "UnitLevel", "UnitClass", "UnitExists", "UnitIsPlayer",
  "UnitFactionGroup", "UnitIsEnemy", "InCombatLockdown", "UnitAffectingCombat", "IsInGuild",
  "IsInGroup", "GetGuildInfo", "Ambiguate", "GetChannelList", "EnumerateServerChannels",
  "GetChannelName", "GetRealZoneText", "GetServerTime", "GetGameTime", "IsInInstance",
  "GetGuildRecipeInfoPostQuery", "GetGuildRecipeMember", "hooksecurefunc", "issecretvalue",
  "SendChatMessage", "RequestTimePlayed", "JoinChannelByName", "LeaveChannelByName",
  "GetInstanceInfo", "LoggingCombat", "LoggingChat" }
local NAMESPACES = { "C_GameRules", "C_GuildInfo", "C_ChatInfo", "C_Container", "C_Item",
  "C_DateAndTime", "C_Calendar", "C_TradeSkillUI", "C_Timer", "C_PlayerInfo" }

local function count(k) S.calls[k] = (S.calls[k] or 0) + 1 end

local function fullWorld()
  function GetTime() return S.t end
  function time() return 1793836800 + math.floor(S.t) end
  function date(fmt)
    if fmt == "*t" then return { year = 2026, month = 11, day = 28 } end
    return "2026-11-04 23:05:00"
  end
  function GetBuildInfo() return "1.60.1", "70500", "Nov 1 2026", 16001 end
  function GetRealmName() return "Forever PvP" end
  function GetNormalizedRealmName() return "ForeverPvP" end
  function UnitName(u)
    if u == "player" then return S.name end
    if u == "target" then return S.tname, S.trealm end
  end
  function UnitLevel(u) if u == "player" then return 60 end return S.tlevel end
  function UnitClass(u) if u == "player" then return "Warrior", "WARRIOR", 1 end return "Rogue", "ROGUE", 4 end
  function UnitExists() return true end
  function UnitIsPlayer() return true end
  function UnitFactionGroup(u) if u == "player" then return "Horde", "Horde" end return "Alliance", "Alliance" end
  function UnitIsEnemy() return true end
  function InCombatLockdown() return S.combat end
  function UnitAffectingCombat() return S.combat end
  function IsInGuild() return S.guild end
  function IsInGroup() return S.group end
  function GetGuildInfo(u)
    if S.guild and S.guildReady then return "DEAD TIRED", "Crypt Keeper", 1, nil end
  end
  function Ambiguate(name) return (name:gsub("%-ForeverPvP$", "")) end
  function GetChannelList() return 1, "General", false, 2, "Trade", false end
  function EnumerateServerChannels() return "General", "Trade", "LocalDefense" end
  function GetChannelName(i) if i == 1 then return 1, "General - Orgrimmar", 0, false end return 0, nil end
  function GetRealZoneText() return "Orgrimmar" end
  function GetServerTime() return 1793836800 end
  function GetGameTime() return 23, 5 end
  function IsInInstance() return S.inInstance, S.instanceType end
  function GetInstanceInfo() return "Orgrimmar", S.instanceType, 0, "", 0, 0, false, 1454, 0 end
  -- Amendment 2: the logging globals. With an argument they switch logging (S.logCombat).
  function LoggingCombat(arg)
    count("LoggingCombat")
    S.logArgs[#S.logArgs + 1] = arg
    if S.blockMode == "error" then
      error("[ADDON_ACTION_FORBIDDEN] AddOn 'DeadTiredProbe' tried to call the protected function 'LoggingCombat()'.", 0)
    elseif S.blockMode == "event" then
      fire("ADDON_ACTION_BLOCKED", "DeadTiredProbe", "LoggingCombat()")
      return S.logCombat
    end
    if arg ~= nil then S.logCombat = arg and true or false end
    return S.logCombat
  end
  function LoggingChat(arg) count("LoggingChat") return false end
  C_PlayerInfo = { IsSelfFoundActive = function() return false end }
  function GetGuildRecipeInfoPostQuery() return 185, S.recipeIDs[1], S.numMembers end
  function GetGuildRecipeMember(i) return "Cook" .. i, true end
  function hooksecurefunc(t, k, post)
    local orig = t[k]
    if type(orig) ~= "function" then error("hooksecurefunc(): " .. tostring(k) .. " is not a function") end
    t[k] = function(...) orig(...) post(...) end
  end
  function issecretvalue(v) return S.secrets[v] == true end
  function SendChatMessage() count("SendChatMessage") end
  function RequestTimePlayed() count("RequestTimePlayed") end
  function JoinChannelByName() count("JoinChannelByName") end
  function LeaveChannelByName() count("LeaveChannelByName") end

  C_GameRules = {
    GetActiveGameMode = function() return 2 end,
    IsHardcoreActive = function() return S.hardcore end,
    IsSelfFoundAllowed = function() return false end,   -- Amendment 2 B1
  }
  C_GuildInfo = {
    IsGuildOfficer = function() return S.officer end,
    CanSpeakInGuildChat = function() return S.guild end,
    QueryGuildMembersForRecipe = function(line, id) count("Query") S.queryArgs = { line, id } end,
    QueryGuildMemberRecipes = function() end,
  }
  C_ChatInfo = {
    AreOutgoingAddonChatMessagesRestricted = function() return S.restricted end,
    InChatMessagingLockdown = function() return false end,
    IsLoggingCombat = function() return S.logCombat end,
    IsLoggingChat = function() return false end,
    RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(prefix, text, chan)
      count("SendAddonMessage")
      S.sent[#S.sent + 1] = { prefix = prefix, text = text, chan = chan }
      return 0
    end,
    SendChatMessage = function() count("C_ChatInfo.SendChatMessage") end,
    GetNumActiveChannels = function() return 2 end,
    GetGeneralChannelID = function() return 1 end,
    GetGeneralChannelLocalID = function() return 1 end,
  }
  C_Container = {
    GetContainerNumSlots = function(bag) return S.numSlots[bag] or 0 end,
    GetContainerItemInfo = function(bag, slot)
      local b = S.bagItems[bag]
      return b and b[slot] or nil
    end,
  }
  ItemLocation = { CreateFromBagAndSlot = function(self, bag, slot) return { bag = bag, slot = slot } end }
  C_Item = {
    IsBound = function(loc) return loc.bag == 0 and loc.slot == 1 end,
    GetItemInfoInstant = function(id) return id, "Consumable", "Potion", "", 134830, 0, 1 end,
    GetItemInfo = function(id) return S.itemNames[id] end,
    RequestLoadItemDataByID = function(id) count("RequestLoad") end,
    GetItemCount = function(id, bank) return bank and 5 or 2 end,
  }
  C_DateAndTime = {
    GetServerTimeLocal = function() return 1793836800 end,
    GetCurrentCalendarTime = function() return { year = 2026, month = 11, monthDay = 28, hour = 23, minute = 5 } end,
  }
  C_Calendar = {
    OpenCalendar = function() count("OpenCalendar") end,
    GetNumDayEvents = function(off, day) return S.calN end,
    GetDayEvent = function(off, day, i)
      return { title = "Fishing Extravaganza", calendarType = "HOLIDAY", sequenceType = "ONGOING",
        startTime = { year = 2026, month = 11 + off, monthDay = day, hour = 14, minute = 0 } }
    end,
  }
  C_TradeSkillUI = {
    IsTradeSkillReady = function() return S.tradeReady end,
    GetAllRecipeIDs = function() return S.recipeIDs end,
    GetTradeSkillLineForRecipe = function(id) return 2550, "Classic Cooking", 185 end,
  }
  C_Timer = { After = function(d, f) S.timers[#S.timers + 1] = { at = S.t + d, f = f } end }
  WOW_PROJECT_ID = 1
  Enum = { BagIndex = { Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4, ReagentBag = 5,
    Bank = -1, BankBag_1 = 6, BankBag_2 = 7 } }
  SlashCmdList = { PLAYED = function() S.playedTyped = (S.playedTyped or 0) + 1 end }
  DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) S.printed[#S.printed + 1] = m end }
end

local function boom() error("boom from the client") end

local function setup(mode)
  S = { t = 1000, name = "Stromham", guild = true, guildReady = true, group = false,
    officer = true, hardcore = false, restricted = false, combat = false, tradeReady = true,
    tname = "Nameless", trealm = nil, tlevel = 60, secrets = { [SECRET_V] = true },
    calls = {}, sent = {}, printed = {}, timers = {}, numSlots = {}, bagItems = {},
    itemNames = { [13446] = "Major Healing Potion", [17029] = "Sacred Candle" },
    recipeIDs = { 2546, 2547 }, numMembers = 3, calN = 1,
    logCombat = false, logArgs = {}, inInstance = false, instanceType = "none" }
  -- items: bag 0 has 3 items, bank -1 has 2
  S.numSlots[0], S.numSlots[-1] = 16, 24
  S.bagItems[0] = { [1] = { itemID = 6948, isBound = true }, [2] = { itemID = 13446, isBound = false },
    [5] = { itemID = 5140 } }
  S.bagItems[-1] = { [1] = { itemID = 17029, isBound = false }, [3] = { itemID = 6265, isBound = false } }
  frames = {}
  for _, k in ipairs(GLOBAL_FNS) do _G[k] = nil end
  for _, k in ipairs(NAMESPACES) do _G[k] = nil end
  ItemLocation, Enum, WOW_PROJECT_ID, DEFAULT_CHAT_FRAME, UNKNOWNOBJECT = nil, nil, nil, nil, nil
  SlashCmdList = {}
  print = function(m) S.printed[#S.printed + 1] = m end
  if mode == "absent" then
    -- every game function absent: nil globals, empty namespaces
    for _, k in ipairs(NAMESPACES) do _G[k] = {} end
  else
    fullWorld()
    if mode == "throw" then
      for _, k in ipairs(GLOBAL_FNS) do
        local keep = k == "SendChatMessage" or k == "RequestTimePlayed" or k == "JoinChannelByName"
          or k == "LeaveChannelByName"
        if not keep then _G[k] = boom end
      end
      for _, k in ipairs(NAMESPACES) do
        for f in pairs(_G[k]) do
          if not (k == "C_ChatInfo" and f == "SendChatMessage") then _G[k][f] = boom end
        end
      end
      ItemLocation.CreateFromBagAndSlot = boom
      DEFAULT_CHAT_FRAME.AddMessage = boom
    end
  end
  CreateFrame = function()
    local f = { events = {}, scripts = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    frames[#frames + 1] = f
    return f
  end
end

function fire(ev, ...)
  for _, f in ipairs(frames) do
    if f.events[ev] and f.scripts.OnEvent then f.scripts.OnEvent(f, ev, ...) end
  end
end

local function advance(d)
  S.t = S.t + d
  local guard = 0
  repeat
    local ran = false
    for i, tm in ipairs(S.timers) do
      if tm.at <= S.t then table.remove(S.timers, i) tm.f() ran = true break end
    end
    guard = guard + 1
  until not ran or guard > 1000
end

local function load()
  local ns = {}
  local chunk = assert(loadfile(PROBE))
  chunk("DeadTiredProbe", ns)
  return ns.P
end

local function login(P, opts)
  opts = opts or {}
  if opts.cold then S.name = "Unknown" end
  fire("ADDON_LOADED", "SomeOtherAddon")
  fire("ADDON_LOADED", "DeadTiredProbe")
  if opts.cold then S.name = "Stromham" end
  fire("PLAYER_LOGIN")
  fire("PLAYER_ENTERING_WORLD", true, false)
  advance(15)
end

local function slash(msg) SlashCmdList.DTPROBE(msg) end
local function secs(P) return P.state().cur.sections end

local function deepFind(t, pred, seen)
  seen = seen or {}
  if type(t) ~= "table" or seen[t] then return false end
  seen[t] = true
  for k, v in pairs(t) do
    if pred(k) or pred(v) then return true end
    if deepFind(k, pred, seen) or deepFind(v, pred, seen) then return true end
  end
  return false
end

local function ser(v)
  if type(v) ~= "table" then return tostring(v) end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. ser(v[k]) end
  return "{" .. table.concat(parts, ",") .. "}"
end

local COMMANDS = { "ping", "channels", "bags", "items", "target", "calendar", "recipes", "report" }
local function isMarker(v, m) return type(v) == "string" and v:find("^" .. m) ~= nil end

-- ---------------------------------------------------------------- helpers: rec and ask
setup("full")
DeadTiredProbeDB = nil
local P = load()
check("rec: a secret value is recorded as <secret>", P.rec(SECRET_V) == "<secret>")
check("rec: nil is recorded as <nil>", P.rec(nil) == "<nil>")
check("rec: a function is recorded as <function>", P.rec(print) == "<function>")
local big = {}
for i = 1, 30 do big["k" .. i] = i end
local copied, n = P.rec(big), 0
for k in pairs(copied) do if k ~= "<more>" then n = n + 1 end end
check("rec: a table is a shallow copy of up to 20 keys", n == 20 and copied["<more>"] == true)
check("rec: table values go through rec", P.rec({ a = SECRET_V, b = print }).a == "<secret>"
  and P.rec({ b = print }).b == "<function>")
check("rec: a secret key is not stored raw", P.rec({ [SECRET_V] = 1 })["<secret>"] == 1)
check("ask: an absent function reads <absent>", P.ask(nil) == "<absent>")
check("ask: an erroring function reads <error: ...>", isMarker(P.ask(boom), "<error: "))
local long = P.ask(function() error(string.rep("x", 300), 0) end)
check("ask: the error message is cut to 120 bytes", #long == #"<error: >" + 120)
local r = P.ask(function() return 1, nil, SECRET_V end)
check("ask: all results, each through rec", type(r) == "table" and r[1] == 1 and r[2] == "<nil>"
  and r[3] == "<secret>")
issecretvalue = boom
check("rec: a throwing issecretvalue counts as secret (fail closed)", P.rec(5) == "<secret>")
fullWorld()

-- ---------------------------------------------------------------- a scripted session, in a guild
setup("full")
DeadTiredProbeDB = nil
P = load()
login(P, { cold = true })
local st = P.state()
local x = secs(P)
check("login: the load line printed once, verbatim",
  #S.printed == 1 and S.printed[1] == "Dead Tired probe: recording. /dtprobe for commands.")
check("login: the run sits under Realm-Name (not the cold 'Unknown')", st.key == "Forever PvP-Stromham"
  and DeadTiredProbeDB.chars["Forever PvP-Stromham"].runs[1] == st.cur)
check("record: version 1, run has at, inGuild, sections", DeadTiredProbeDB.version == 1
  and type(st.cur.at) == "number" and st.cur.inGuild == true and type(st.cur.sections) == "table")
check("build: GetBuildInfo, all returns", x.build.buildInfo[1] == "1.60.1" and x.build.buildInfo[4] == 16001)
check("build (A2 B1): self-found from IsSelfFoundAllowed and C_PlayerInfo.IsSelfFoundActive",
  x.build.selfFoundAllowed == false and x.build.selfFoundActive == false and x.build.selfFound == nil)
check("logging (A2 B2): automatic read at PEW + 15 s", x.logging.reads[1].combat == false
  and x.logging.reads[1].chat == false and x.logging.reads[1].combatGlobal == "function"
  and x.logging.reads[1].chatGlobal == "function" and x.logging.reads[1].t == 1015)
check("instances (A2 B3): the login's world entry", x.instances.worlds[1].isLogin == true
  and x.instances.worlds[1].isReload == false and x.instances.worlds[1].instance[2] == "none"
  and x.instances.worlds[1].info[1] == "Orgrimmar" and x.instances.worlds[1].info[2] == "none"
  and x.instances.worlds[1].lockdown == false and x.instances.worlds[1].loggingCombat == false)
check("build: game mode, hardcore, level, class", x.build.gameMode == 2 and x.build.hardcore == false
  and x.build.level == 60 and x.build.class[2] == "WARRIOR")
check("login: loaded, login, world stamps", x.login.loaded.t == 1000 and x.login.login.t == 1000
  and x.login.world.isInitialLogin == true)
check("login: first guild name and when", x.login.firstGuildName and x.login.firstGuildName.name == "DEAD TIRED")
check("guild: in guild, info, officer, can speak", x.guild.isInGuild == true and x.guild.guildInfo[1] == "DEAD TIRED"
  and x.guild.guildInfo[2] == "Crypt Keeper" and x.guild.officer == true and x.guild.canSpeak == true
  and x.guild.noGuild == false)
check("guild: ran at PEW + 15 s", x.guild.at == 1015)
check("comms: passive part at PEW + 15 s", x.comms.restricted == false and x.comms.lockdown == false
  and x.comms.registered == true)
check("channels: one automatic snapshot", #x.channels.snapshots == 1
  and x.channels.snapshots[1].channelList[2] == "General" and x.channels.snapshots[1].byIndex[20] ~= nil
  and x.channels.snapshots[1].zone == "Orgrimmar")
check("time: every clock", x.time.time ~= nil and x.time.serverTime == 1793836800
  and x.time.serverTimeLocal == 1793836800 and x.time.gameTime[1] == 23 and x.time.date == "2026-11-04 23:05:00")
check("played: hook placed at load", x.played.hook.placed == true and x.played.hook.playedType == "function")
check("played: whether /played was already cached is recorded", x.played.hook.cachedBeforeHook == "<absent>")
check("death: exists from login", x.death.count == 0)
check("events print nothing", #S.printed == 1)

-- guild events: 5 kept, count goes on
for i = 1, 7 do fire("PLAYER_GUILD_UPDATE") fire("GUILD_ROSTER_UPDATE") end
check("login: first 5 guild and roster updates kept, all counted", #x.login.guildUpdates == 5
  and #x.login.rosterUpdates == 5 and x.login.guildUpdatesCount == 7 and x.login.guildUpdates[1].guild[1] == "DEAD TIRED")

-- commands
local before = #S.printed
for _, c in ipairs(COMMANDS) do slash(c) end
local replies = #S.printed - before
check("one reply per command, 15 report lines", replies == (#COMMANDS - 1) + 15)
check("ping: one addon message on GUILD, prefix DTPROBE, text ping", S.calls.SendAddonMessage == 1
  and S.sent[1].chan == "GUILD" and S.sent[1].prefix == "DTPROBE" and S.sent[1].text == "ping"
  and x.comms.pings[1].channel == "GUILD" and x.comms.pings[1].result[1] == 0)
local tgt = x.target.snapshots[1]
check("target: unit fields", tgt.name[1] == "Nameless" and tgt.name[2] == "<nil>" and tgt.level == 60
  and tgt.class[2] == "ROGUE" and tgt.factionTarget[1] == "Alliance" and tgt.isEnemy == true)
local found
for _, m in ipairs(S.printed) do if m:find("recorded target: ", 1, true) then found = m end end
check("target: reply headline", found == "Dead Tired probe: recorded target: Nameless, level 60, in combat: no, name secret: no")
check("bags: occupied slots, item IDs, isBound as returned", #x.bags.last.slots == 3
  and x.bags.last.slots[1].isBound == true and x.bags.last.slots[2].isBound == false
  and x.bags.last.slots[3].isBound == "<nil>" and x.bags.last.slots[3].itemID == 5140)
check("bags: C_Item.IsBound on the item location", x.bags.last.slots[1].isBoundByLocation == true
  and x.bags.last.slots[2].isBoundByLocation == false)
check("bags: Enum.BagIndex and its slot counts", x.bags.last.bagIndex.Bank == -1
  and x.bags.last.numSlotsByIndex.Backpack == 16 and x.bags.last.numSlotsByIndex.Bank == 24)
check("bags: GetItemCount with and without bank for the first item IDs", #x.bags.last.counts == 3
  and x.bags.last.counts[1].count == 2 and x.bags.last.counts[1].withBank == 5)
check("bags: no bank containers while the bank is shut", x.bags.last.bankOpen == false and #x.bags.last.bags == 5)
check("calendar: OpenCalendar called, waits", S.calls.OpenCalendar == 1 and x.calendar.readBy == nil)
fire("CALENDAR_UPDATE_EVENT_LIST")
check("calendar: read on the event list, 14 days, crossing the month", x.calendar.readBy == "event"
  and #x.calendar.days == 14 and x.calendar.days[3].offset == 0 and x.calendar.days[4].offset == 1
  and x.calendar.days[4].monthDay == 1 and #x.calendar.events == 14
  and x.calendar.events[1].title == "Fishing Extravaganza" and x.calendar.events[1].startTime.hour == 14)

local att = x.recipes.attempts[1]
check("recipes: functions recorded", att.fns.QueryGuildMembersForRecipe == true and att.fns.GetGuildRecipeMember == true)
check("recipes: first recipe, its line, query on the parent line", att.recipeID == 2546
  and att.line[3] == 185 and S.queryArgs[1] == 185 and S.queryArgs[2] == 2546 and att.ready == true)
advance(3)
fire("GUILD_RECIPE_KNOWN_BY_MEMBERS")
check("recipes: an answer within 10 s is recorded", #att.events == 1 and att.events[1].info[3] == 3
  and #att.events[1].members == 3 and att.events[1].members[1][1] == "Cook1")
advance(10)
fire("GUILD_RECIPE_KNOWN_BY_MEMBERS")
check("recipes: an answer after 10 s is not", #att.events == 1 and x.recipes.stray == 1)

check("items: names known, unknown requested", x.items.list[1].name == "Major Healing Potion"
  and x.items.list[3].name == "<nil>" and x.items.list[3].pending and S.calls.RequestLoad == 6
  and x.items.list[1].instant[2] == "Consumable")
S.itemNames[17020] = "Arcane Powder"
advance(2)
fire("GET_ITEM_INFO_RECEIVED", 17020, true)
check("items: a name is filled in on GET_ITEM_INFO_RECEIVED", x.items.list[3].name == "Arcane Powder"
  and x.items.list[3].received.after == 15 and x.items.list[3].received.success == true)
advance(30)
check("items: after 30 s the rest are marked", x.items.list[4].received == "<not in 30 s>" and not x.items.list[4].pending)
S.itemNames[17033] = "Late"
fire("GET_ITEM_INFO_RECEIVED", 17033, true)
check("items: nothing filled in after 30 s", x.items.list[4].name == "<nil>")

-- 20 addon messages: half from this character
for i = 1, 20 do
  local who = (i % 2 == 0) and "Stromham-ForeverPvP" or "Guildie-ForeverPvP"
  fire("CHAT_MSG_ADDON", "DTPROBE", "ping and a very long tail of text", "GUILD", who)
end
fire("CHAT_MSG_ADDON", "OTHER", "x", "GUILD", "Someone")
check("comms: 10 messages kept, the rest counted", #x.comms.messages == 10 and x.comms.dropped == 10
  and x.comms.heard == 20)
check("comms: raw sender, Ambiguate, channel, text cut to 20, isMe",
  x.comms.messages[1].sender == "Guildie-ForeverPvP" and x.comms.messages[1].ambiguated == "Guildie"
  and x.comms.messages[1].channel == "GUILD" and #x.comms.messages[1].text == 20
  and x.comms.messages[1].isMe == false and x.comms.messages[2].isMe == true)

-- deaths
for i = 1, 7 do fire("PLAYER_DEAD") end
check("death: 5 kept, all counted", #x.death.deaths == 5 and x.death.count == 7
  and x.death.deaths[1].instance[2] == "none" and x.death.deaths[1].zone == "Orgrimmar")

-- /played: typed, then a report nobody typed for
SlashCmdList.PLAYED("")
advance(1)
fire("TIME_PLAYED_MSG", 3600, 600)
fire("TIME_PLAYED_MSG", 3601, 601)
check("played: the typed /played was seen by the hook", x.played.typed == 1 and S.playedTyped == 1)
check("played: arguments in order and the stamp's age", x.played.events[1].args[1] == 3600
  and x.played.events[1].args[2] == 600 and x.played.events[1].stampAge == 1)
check("played: <no stamp> when /played wasn't typed", x.played.events[2].stampAge == "<no stamp>")
for i = 1, 5 do fire("TIME_PLAYED_MSG", 1, 1) end
check("played: 5 events kept", #x.played.events == 5 and x.played.dropped == 2)

-- caps on commands
for i = 1, 6 do slash("channels") end
check("channels: 5 snapshots at most", #x.channels.snapshots == 5 and x.channels.refused >= 1)
for i = 1, 12 do slash("target") end
check("target: 10 snapshots at most", #x.target.snapshots == 10 and x.target.refused == 3)
for i = 1, 7 do slash("recipes") end
check("recipes: 5 attempts at most", #x.recipes.attempts == 5 and x.recipes.refused == 3)
S.numMembers = 100
x.recipes.attempts[5].openedAt = S.t
x.recipes.attempts[5].open = true
fire("GUILD_RECIPE_KNOWN_BY_MEMBERS")
local ev5 = x.recipes.attempts[5].events
ev5 = ev5[#ev5]
check("recipes: 40 members at most", #ev5.members == 40 and ev5.capped == true and ev5.numMembers == 100)
S.calN = 5
slash("calendar")
advance(10)
check("calendar: read by the timer when no list comes; 60 events at most",
  x.calendar.readBy == "10 s timer" and #x.calendar.events == 60 and x.calendar.capped == true)
S.numSlots[1] = 300
S.bagItems[1] = {}
for i = 1, 300 do S.bagItems[1][i] = { itemID = 1000 + i, isBound = false } end
slash("bags")
check("bags: 200 slots at most", #x.bags.last.slots == 200 and x.bags.last.capped == true)

-- bank: once, with bank containers
S.numSlots[1] = 0
fire("BANKFRAME_OPENED")
check("bags: one snapshot at bank open, with the bank containers", x.bags.bank and x.bags.bank.bankOpen == true
  and x.bags.bank.why == "bank" and #x.bags.bank.bags > 5)
local bankSlots = 0
for _, e in ipairs(x.bags.bank.slots) do if e.bag == -1 then bankSlots = bankSlots + 1 end end
check("bags: the bank's items are in the bank snapshot", bankSlots == 0 or bankSlots == 2)
local bankRef = x.bags.bank
fire("BANKFRAME_CLOSED")
fire("BANKFRAME_OPENED")
check("bags: only once at bank open", x.bags.bank == bankRef)

-- secret target name
S.tname = SECRET_V
x.target.snapshots, x.target.refused = {}, 0
before = #S.printed
slash("target")
check("target: a secret name is recorded <secret>, and the reply says so",
  x.target.snapshots[1].name[1] == "<secret>"
  and S.printed[#S.printed] == "Dead Tired probe: recorded target: <secret>, level 60, in combat: no, name secret: yes")
S.combat = true
slash("target")
check("target: in combat shows in the headline", S.printed[#S.printed]:find("in combat: yes", 1, true) ~= nil)
check("secret: never stored raw anywhere in the saved table",
  not deepFind(DeadTiredProbeDB, function(v) return rawequal(v, SECRET_V) end))

-- what was never called
check("zero LoggingCombat and LoggingChat over the whole scripted session (A2)",
  (S.calls.LoggingCombat or 0) == 0 and (S.calls.LoggingChat or 0) == 0)
check("zero SendChatMessage", (S.calls.SendChatMessage or 0) == 0)
check("zero C_ChatInfo.SendChatMessage", (S.calls["C_ChatInfo.SendChatMessage"] or 0) == 0)
check("zero RequestTimePlayed", (S.calls.RequestTimePlayed or 0) == 0)
check("zero JoinChannelByName", (S.calls.JoinChannelByName or 0) == 0)
check("zero LeaveChannelByName", (S.calls.LeaveChannelByName or 0) == 0)
slash("ping")
check("exactly one SendAddonMessage per ping in a guild", S.calls.SendAddonMessage == 2)
S.group = true
slash("ping")
check("ping: in a guild and a group, the guild wins", S.calls.SendAddonMessage == 3 and S.sent[3].chan == "GUILD")
S.group = false

-- printing
local ok = true
for _, m in ipairs(S.printed) do
  if m:sub(1, 18) ~= "Dead Tired probe: " or m:find("|", 1, true) then ok = false end
end
check("every line is the probe's, and none has a |", ok)
before = #S.printed
slash("")
check("/dtprobe alone: the command list, one line", #S.printed == before + 1
  and S.printed[#S.printed] == "Dead Tired probe: /dtprobe ping, channels, bags, items, target, calendar, recipes, logging, logging try, report, reset.")
slash("nonsense")
check("an unknown verb: the list", S.printed[#S.printed] == S.printed[#S.printed - 1])
before = #S.printed
slash("report")
local rep = {}
for i = before + 1, #S.printed do rep[#rep + 1] = S.printed[i] end
check("report: one line per section, in order", #rep == 15 and rep[1]:find("^Dead Tired probe: build: 1%.60%.1")
  and rep[13]:find("^Dead Tired probe: recipes: ") ~= nil and rep[14]:find("^Dead Tired probe: logging: ") ~= nil
  and rep[15]:find("^Dead Tired probe: instances: ") ~= nil)
check("no errors were raised anywhere", P.state().cur.errors == nil)

-- reset
slash("reset")
local runs = DeadTiredProbeDB.chars["Forever PvP-Stromham"].runs
check("reset: runs cleared, a fresh one recording", #runs == 1 and runs[1] == P.state().cur
  and runs[1].sections.target == nil)
before = #S.printed
slash("report")
check("report after reset: not run yet", S.printed[before + 10] == "Dead Tired probe: target: not run yet")

-- ---------------------------------------------------------------- per-section pcall isolation
setup("full")
DeadTiredProbeDB = nil
P = load()
P.S.guild = function() error("guild section broke") end
login(P)
x = secs(P)
check("isolation: a throwing section records failed", type(x.guild) == "table"
  and x.guild.failed and x.guild.failed:find("guild section broke", 1, true) ~= nil)
check("isolation: the next sections still run", x.comms and not x.comms.failed and x.channels
  and #x.channels.snapshots == 1 and x.time and x.time.serverTime == 1793836800)
check("isolation: nothing escaped to the handler", P.state().cur.errors == nil)
before = #S.printed
P.S.target = function() error("target broke") end
slash("target")
check("isolation: a failing command still replies one line", #S.printed == before + 1
  and S.printed[#S.printed]:find("^Dead Tired probe: target: failed: ") ~= nil)

-- ---------------------------------------------------------------- every function absent / throwing
local function everything(mode)
  setup(mode)
  DeadTiredProbeDB = nil
  local p = load()
  login(p)
  for _, c in ipairs(COMMANDS) do slash(c) end
  fire("CHAT_MSG_ADDON", "DTPROBE", "ping", "GUILD", "Guildie")
  fire("BANKFRAME_OPENED")
  fire("GET_ITEM_INFO_RECEIVED", 17020, true)
  fire("CALENDAR_UPDATE_EVENT_LIST")
  fire("GUILD_RECIPE_KNOWN_BY_MEMBERS")
  if type(SlashCmdList.PLAYED) == "function" then pcall(SlashCmdList.PLAYED, "") end
  fire("TIME_PLAYED_MSG", 1, 1)
  fire("PLAYER_DEAD")
  slash("logging")
  slash("logging try")
  fire("ZONE_CHANGED_NEW_AREA")
  fire("ADDON_ACTION_BLOCKED", "DeadTiredProbe", "LoggingCombat()")
  advance(60)
  return p
end

for _, mode in ipairs({ "absent", "throw" }) do
  local okAll, pp = pcall(everything, mode)
  check(mode .. ": login, every command and every event complete", okAll)
  if okAll then
    local cur = pp.state().cur
    local all, none = true, true
    for _, name in ipairs(pp.ORDER) do
      if type(cur.sections[name]) ~= "table" then all = false realPrint("  missing " .. name) end
      if type(cur.sections[name]) == "table" and cur.sections[name].failed then
        none = false realPrint("  failed " .. name .. ": " .. cur.sections[name].failed)
      end
    end
    check(mode .. ": every section exists", all)
    check(mode .. ": no section failed", none)
    check(mode .. ": no error reached a handler", cur.errors == nil)
    check(mode .. ": the run is saved (under ?-? with no name)", DeadTiredProbeDB.chars["?-?"]
      and DeadTiredProbeDB.chars["?-?"].runs[1] == cur)
    check(mode .. ": the load line still printed", S.printed[1] == "Dead Tired probe: recording. /dtprobe for commands.")
    local x2 = cur.sections
    local m = mode == "absent" and "<absent>" or "<error: "
    check(mode .. ": reads are " .. m, isMarker(x2.build.gameMode, m) and isMarker(x2.guild.officer, m)
      and isMarker(x2.time.serverTime, m) and isMarker(x2.build.buildInfo, m)
      and isMarker(x2.channels.snapshots[1].numActive, m) and isMarker(x2.target.snapshots[1].level, m)
      and isMarker(x2.death.deaths[1].zone, m) and isMarker(x2.items.list[1].instant, m)
      and isMarker(x2.calendar.open, m) and isMarker(x2.recipes.attempts[1].ready, m)
      and isMarker(x2.comms.restricted, m) and isMarker(x2.login.loaded.t, m))
    check(mode .. ": A2 reads are " .. m, isMarker(x2.build.selfFoundAllowed, m)
      and isMarker(x2.build.selfFoundActive, m) and isMarker(x2.logging.reads[1].combat, m)
      and isMarker(x2.logging.reads[1].chat, m) and isMarker(x2.instances.worlds[1].info, m)
      and isMarker(x2.instances.zones[1].instance, m) and isMarker(x2.logging.attempts[1].before, m))
    check(mode .. ": logging try calls nothing when the state can't be read",
      x2.logging.attempts[1].called == false and (S.calls.LoggingCombat or 0) == 0)
    check(mode .. ": the hook is recorded as not placed, with why", x2.played.hook.placed == false
      and type(x2.played.hook.why) == "string")
    check(mode .. ": recipes says why there's no query", x2.recipes.attempts[1].why ~= nil
      and x2.recipes.attempts[1].query == nil)
    check(mode .. ": no guild recorded", x2.guild.noGuild == true and x2.recipes.attempts[1].noGuild == true)
    check(mode .. ": ping sends nothing and says so", x2.comms.pings[1].channel == "<none: no guild, no group>")
    check(mode .. ": calendar records why it has no days", type(x2.calendar.today) == "string")
    if mode == "throw" then
      check("throw: the played event still records, with no stamp", x2.played.events[1]
        and x2.played.events[1].stampAge == "<no stamp>")
    end
  end
end

-- ---------------------------------------------------------------- no frame at all
setup("full")
CreateFrame = nil
local okNF = pcall(load)
check("no CreateFrame: the file still loads", okNF)
before = #S.printed
pcall(slash, "")
check("no CreateFrame: /dtprobe still answers", #S.printed == before + 1)

-- ---------------------------------------------------------------- no guild
setup("full")
S.guild, S.officer = false, false
DeadTiredProbeDB = nil
P = load()
login(P)
for _, c in ipairs(COMMANDS) do slash(c) end
fire("PLAYER_DEAD")
x = secs(P)
local allNG = true
for _, name in ipairs(P.ORDER) do if type(x[name]) ~= "table" or x[name].failed then allNG = false end end
check("no guild: every section completes", allNG)
check("no guild: guild, login and recipes record it", x.guild.noGuild == true and x.login.firstGuildName == nil
  and x.recipes.attempts[1].noGuild == true and P.state().cur.inGuild == false)
check("no guild, solo: ping sends nothing", (S.calls.SendAddonMessage or 0) == 0
  and x.comms.pings[1].channel == "<none: no guild, no group>"
  and S.printed[2] == "Dead Tired probe: recorded ping: not sent: no guild and no group")
S.group = true
slash("ping")
check("no guild, in a party: ping goes to PARTY, once", S.calls.SendAddonMessage == 1 and S.sent[1].chan == "PARTY")
local firstRun = ser(DeadTiredProbeDB.chars["Forever PvP-Stromham"].runs[1])
-- second login: the saved table survives, the file loads again
local saved = DeadTiredProbeDB
setup("full")
S.guild = false
DeadTiredProbeDB = saved
P = load()
login(P)
runs = DeadTiredProbeDB.chars["Forever PvP-Stromham"].runs
check("second login: a second run, the first untouched", #runs == 2 and ser(runs[1]) == firstRun
  and runs[2] == P.state().cur)
for i = 1, 6 do
  setup("full")
  DeadTiredProbeDB = saved
  P = load()
  login(P)
end
check("runs: 5 kept, newest last", #DeadTiredProbeDB.chars["Forever PvP-Stromham"].runs == 5
  and DeadTiredProbeDB.chars["Forever PvP-Stromham"].runs[5] == P.state().cur)

-- ---------------------------------------------------------------- restricted: held, not forced
setup("full")
DeadTiredProbeDB = nil
P = load()
login(P)
S.restricted = true
slash("ping")
check("restricted: ping held, nothing sent", (S.calls.SendAddonMessage or 0) == 0
  and secs(P).comms.pings[1].held == 1)
advance(5)
check("restricted: still held while restricted", (S.calls.SendAddonMessage or 0) == 0)
S.restricted = false
advance(5)
check("restricted: sent once when lifted", S.calls.SendAddonMessage == 1 and S.sent[1].chan == "GUILD"
  and secs(P).comms.pings[1].result[1] == 0)
advance(60)
check("restricted: sent only once", S.calls.SendAddonMessage == 1)

-- ---------------------------------------------------------------- hook on a client with no /played
setup("full")
SlashCmdList = {}
DeadTiredProbeDB = nil
P = load()
login(P)
x = secs(P)
check("hook: no PLAYED handler, recorded as not placed", x.played.hook.placed == false
  and x.played.hook.why:find("not a function", 1, true) ~= nil and not x.played.failed)
fire("TIME_PLAYED_MSG", 5, 5)
check("hook: events still recorded, with no stamp", x.played.events[1].stampAge == "<no stamp>")

-- ---------------------------------------------------------------- Amendment 2: logging try
local function fresh(f)
  setup("full")
  if f then f() end
  DeadTiredProbeDB = nil
  local p = load()
  login(p)
  return p
end
P = fresh()
x = secs(P)
before = #S.printed
slash("logging")
check("logging: /dtprobe logging records a read and replies one line", #x.logging.reads == 2
  and #S.printed == before + 1 and S.printed[#S.printed]:find("^Dead Tired probe: recorded logging: combat log on: no") ~= nil
  and (S.calls.LoggingCombat or 0) == 0)
before = #S.printed
slash("logging try")
check("try, off: LoggingCombat called once, with true", S.calls.LoggingCombat == 1 and S.logArgs[1] == true
  and x.logging.attempts[1].called == true and x.logging.attempts[1].before == false)
check("try, off: the reply waits for the 1 s read", #S.printed == before)
advance(1)
check("try, off: one line, logging now on", #S.printed == before + 1 and S.printed[#S.printed] ==
  "Dead Tired probe: recorded logging try: combat logging is now on (it was off). /combatlog switches it off.")
check("try, off: results and the 1 s read recorded", x.logging.attempts[1].result[1] == true
  and x.logging.attempts[1].after1s == true and x.logging.attempts[1].blocked == false)
slash("logging try")
check("try, on: nothing called, says so", S.calls.LoggingCombat == 1 and x.logging.attempts[2].called == false
  and S.printed[#S.printed] == "Dead Tired probe: recorded logging try: already on: nothing called")
S.logCombat = false
slash("Logging   TRY")
advance(1)
check("try: third attempt, any case and spacing", S.calls.LoggingCombat == 2 and #x.logging.attempts == 3)
S.logCombat = false
slash("logging try")
check("try: 3 attempts at most", #x.logging.attempts == 3 and S.calls.LoggingCombat == 2
  and x.logging.refused == 1 and S.printed[#S.printed] == "Dead Tired probe: logging try: already 3 attempts")
advance(5)
check("try: nothing else printed afterwards", S.printed[#S.printed] == "Dead Tired probe: logging try: already 3 attempts")

P = fresh(function() end)
C_ChatInfo.IsLoggingCombat = nil
slash("logging try")
check("try, state absent: LoggingCombat never called", (S.calls.LoggingCombat or 0) == 0
  and secs(P).logging.attempts[1].why == "state unknown (<absent>): nothing called")
P = fresh()
LoggingCombat = nil
slash("logging try")
advance(1)
check("try, LoggingCombat absent: recorded <absent>", secs(P).logging.attempts[1].result == "<absent>"
  and secs(P).logging.attempts[1].after1s == false)

P = fresh()
S.blockMode = "event"
fire("ADDON_ACTION_BLOCKED", "OtherAddon", "Something()")
slash("logging try")
advance(1)
local la = secs(P).logging.attempts[1]
check("try, blocked: ADDON_ACTION_BLOCKED for this addon recorded", la.blocked == true and #la.blockedEvents == 1
  and la.blockedEvents[1].event == "ADDON_ACTION_BLOCKED" and la.blockedEvents[1].func == "LoggingCombat()")
check("try, blocked: another addon's event is ignored", secs(P).logging.strayBlocked == nil)
check("try, blocked: the line says so", S.printed[#S.printed] ==
  "Dead Tired probe: recorded logging try: combat logging is still off; the client blocked the call.")
fire("ADDON_ACTION_FORBIDDEN", "DeadTiredProbe", "LoggingCombat()")
check("try, blocked: an event after the 1 s window is stray", #la.blockedEvents == 1 and secs(P).logging.strayBlocked == 1)
P = fresh()
S.blockMode = "error"
slash("logging try")
advance(1)
la = secs(P).logging.attempts[1]
check("try, blocked by error text", la.blockedByError == true and la.blocked == true
  and isMarker(la.result, "<error: %[ADDON_ACTION_FORBIDDEN%]"))
P = fresh(function() C_Timer = nil end)
before = #S.printed
slash("logging try")
check("try, no timer: read at once, one line", #S.printed == before + 1 and secs(P).logging.attempts[1].readAt
  == "at once (no timer)" and S.calls.LoggingCombat == 1)

-- ---------------------------------------------------------------- Amendment 2: instances
P = fresh()
x = secs(P)
S.inInstance, S.instanceType = true, "pvp"
for i = 1, 12 do fire("PLAYER_ENTERING_WORLD", false, false) fire("ZONE_CHANGED_NEW_AREA") end
check("instances: 10 world entries kept, all counted", #x.instances.worlds == 10 and x.instances.worldCount == 13)
check("instances: 10 zone changes kept, all counted", #x.instances.zones == 10 and x.instances.zoneCount == 12)
check("instances: a battleground entry", x.instances.worlds[2].instance[1] == true
  and x.instances.worlds[2].instance[2] == "pvp" and x.instances.worlds[2].isLogin == false
  and x.instances.zones[1].instance[2] == "pvp" and x.instances.zones[1].zone == "Orgrimmar")
check("instances: entries print nothing", #S.printed == 1)
check("logging and instances: no LoggingCombat or LoggingChat call", (S.calls.LoggingCombat or 0) == 0
  and (S.calls.LoggingChat or 0) == 0)

-- ---------------------------------------------------------------- fix round 3: the registered read (AUD-10)
for _, case in ipairs({ { "0 (Success)", 0, true }, { "1 (DuplicatePrefix)", 1, true }, { "true", true, true },
    { "2", 2, false }, { "false", false, false }, { "an error", "error", false } }) do
  local p = fresh(function()
    C_ChatInfo.RegisterAddonMessagePrefix = function()
      if case[2] == "error" then error("no prefix for you") end
      return case[2]
    end
  end)
  local c = secs(p).comms
  check("registered (AUD-10): return " .. case[1] .. " -> " .. tostring(case[3]), c.registered == case[3])
  if case[2] ~= "error" then
    check("registered (AUD-10): the raw return " .. case[1] .. " is kept", c.register == case[2])
  end
end

realPrint(string.format("probe: %d passed, %d failed", passes, fails))
os.exit(fails == 0 and 0 or 1)
