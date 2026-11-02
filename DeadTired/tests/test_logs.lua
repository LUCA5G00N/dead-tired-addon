-- Offline checks for Logs.lua.  lua5.1 DeadTired/tests/test_logs.lua  (from the repo root)
--
-- The card 1 harness builds a client from card 1's files with a minimal CreateFrame. This suite
-- builds the client with load = false, adds the stubs Logs.lua needs (instance and logging
-- state, combat lockdown, dialog frames and secure buttons), loads Logs.lua into the same
-- environment, then fires ADDON_LOADED, so card 1's harness is used unchanged.
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"

local calls = { argCalls = 0, reads = 0 }   -- across every client in the suite

local function richFrames(c)
  c.named = {}
  local function fontString()
    local s = {}
    function s:SetPoint() end
    function s:SetText(t) self.text = t end
    function s:GetText() return self.text end
    return s
  end
  c.env.CreateFrame = function(kind, name, parent, template)
    local f = { events = {}, scripts = {}, attrs = {}, shown = true, enabled = true,
                kind = kind, name = name, template = template }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:SetSize() end
    function f:SetPoint() end
    function f:SetFrameStrata() end
    function f:CreateFontString() return fontString() end
    function f:SetText(t) self.text = t end
    function f:RegisterForClicks() end
    function f:SetAttribute(k, v)
      if c.combat and self.template and self.template:find("Secure") then
        error("secure attribute changed in combat")
      end
      self.attrs[k] = v
    end
    function f:Enable() self.enabled = true end
    function f:Disable() self.enabled = false end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    -- deliberately no SetBackdrop: the dialog must survive frames without it
    if name then c.named[name] = f end
    table.insert(c.frames, f)
    return f
  end
end

-- opts as the harness, plus combatLog/chatLog (true/false/nil), where = { type, id, zone },
-- noCI (no C_ChatInfo logging readers), keyDown (ActionButtonUseKeyDown).
local function client(w, opts)
  local o = {}
  for k, v in pairs(opts) do o[k] = v end
  o.load = false
  local c = w:client(o)
  c.combatLog, c.chatLog = opts.combatLog or false, opts.chatLog or false
  c.where = opts.where or { type = "none" }
  c.combat, c.deadState = false, false
  c.keyDown = opts.keyDown or false
  richFrames(c)
  local env = c.env
  env.IsInInstance = function() return c.where.type ~= "none", c.where.type end
  env.GetInstanceInfo = function()
    return c.where.zone or "Somewhere", c.where.type, 1, "Normal", 5, 0, false, c.where.id
  end
  env.GetRealZoneText = function() return c.where.zone or "Orgrimmar" end
  env.InCombatLockdown = function() return c.combat end
  env.UnitIsDeadOrGhost = function() return c.deadState end
  env.GetCVarBool = function(k) if k == "ActionButtonUseKeyDown" then return c.keyDown end end
  if not opts.noCI then
    env.C_ChatInfo.IsLoggingCombat = function() calls.reads = calls.reads + 1 return c.combatLog end
    env.C_ChatInfo.IsLoggingChat = function() calls.reads = calls.reads + 1 return c.chatLog end
  end
  env.LoggingCombat = function(...)
    if select("#", ...) > 0 then calls.argCalls = calls.argCalls + 1 end
    calls.reads = calls.reads + 1
    return c.combatLog
  end
  env.LoggingChat = function(...)
    if select("#", ...) > 0 then calls.argCalls = calls.argCalls + 1 end
    calls.reads = calls.reads + 1
    return c.chatLog
  end
  env.UIParent = {}
  local chunk = assert(loadfile(H.addonDir .. "/Logs.lua"))
  setfenv(chunk, env)
  chunk("DeadTired", c.ns)
  c:fire("ADDON_LOADED", "DeadTired")
  return c
end

-- Move the player. PLAYER_ENTERING_WORLD (a loading screen) unless zoneOnly.
local function go(c, where, zoneOnly)
  c.where = where
  if zoneOnly then c:fire("ZONE_CHANGED_NEW_AREA") else c:fire("PLAYER_ENTERING_WORLD", false, false) end
end

local WORLD = { type = "none", zone = "Orgrimmar" }
local RFC = { type = "party", id = 389, zone = "Ragefire Chasm" }
local WC = { type = "party", id = 43, zone = "Wailing Caverns" }
local MC = { type = "raid", id = 409, zone = "Molten Core" }
local WSG = { type = "pvp", id = 489, zone = "Warsong Gulch" }
local ARENA = { type = "arena", id = 559, zone = "Nagrand Arena" }

local function inst(c) return c.named.DeadTiredLogsInstance end
local function login(c) return c.named.DeadTiredLogsLogin end
local function instShown(c) return inst(c) ~= nil and inst(c):IsShown() end
local function loginShown(c) return login(c) ~= nil and login(c):IsShown() end

-- Count instance dialogs shown: wrap Show on first build.
local function counter(c)
  c.instShows, c.loginShows = 0, 0
  local orig = c.env.CreateFrame
  c.env.CreateFrame = function(kind, name, ...)
    local f = orig(kind, name, ...)
    if name == "DeadTiredLogsInstance" then
      function f:Show() self.shown = true c.instShows = c.instShows + 1 end
    elseif name == "DeadTiredLogsLogin" then
      function f:Show() self.shown = true c.loginShows = c.loginShows + 1 end
    end
    return f
  end
end

-- A full secure click: both halves, the macro running on the half the cvar picks.
local function click(c, name)
  local b = c.named[name]
  assert(b, "no button " .. name)
  if not b.enabled then return "disabled" end
  for _, down in ipairs({ true, false }) do
    local runs = (down and c.keyDown) or (not down and not c.keyDown)
    if runs and b.attrs.type == "macro" and b.attrs.macrotext then
      for line in b.attrs.macrotext:gmatch("[^\n]+") do
        if line == "/combatlog" then c.combatLog = not c.combatLog
        elseif line == "/chatlog" then c.chatLog = not c.chatLog end
      end
    end
    if b.scripts.PostClick then b.scripts.PostClick(b, "LeftButton", down) end
  end
  return "clicked"
end

local function newClient(w, opts)
  -- install the counter before Logs.lua builds anything
  local c
  local o = {}
  for k, v in pairs(opts) do o[k] = v end
  c = client(w, o)
  return c
end

local w = H.world()

-- ------------------------------------------------------------ entering a dungeon or raid
do
  local db = {}
  local a = newClient(w, { guild = G, db = db })
  counter(a)
  a:login()
  check("open world at login: no dialog", not instShown(a) and not loginShown(a))
  check("nothing printed unasked at load or login (welcome aside)", not a:said("log"))
  go(a, RFC)
  check("dungeon, combat log off: the dialog", instShown(a) and a.instShows == 1)
  check("dialog title and line", inst(a).title.text == "Log this one?"
    and inst(a).status.text == "Combat log is off. Warcraft Logs needs it on.")
  check("Log it is armed with /combatlog only", a.named.DeadTiredLogsButton_LogIt.attrs.macrotext == "/combatlog"
    and a.named.DeadTiredLogsButton_LogIt.attrs.type == "macro")
  check("Not now runs nothing", a.named.DeadTiredLogsButton_NotNow.attrs.type == nil)
  local offersChat = false
  for _, f in ipairs(a.frames) do
    if f.attrs and type(f.attrs.macrotext) == "string" and f.attrs.macrotext:find("/chatlog")
       and f.name and f.name:find("LogIt") then offersChat = true end
  end
  check("the instance dialog never offers the chat log", not offersChat
    and a.named.DeadTiredLogsButton_Chat == nil)
  go(a, RFC, true)
  a:fire("PLAYER_ENTERING_WORLD", false, false)
  check("zone change or loading screen inside: still one dialog", a.instShows == 1)
  -- Log it, and the line 0.5 s later
  a.printed = {}
  click(a, "DeadTiredLogsButton_LogIt")
  check("Log it switched the log on through /combatlog", a.combatLog == true)
  check("the dialog closed", not instShown(a))
  check("no line before the re-read", #a.printed == 0)
  w:advance(0.5)
  check("after-click line matches the state read 0.5 s later (on)",
    a:said("Logging. Try not to die on the record.") ~= nil and #a.printed == 1)
  go(a, WORLD)
  go(a, MC)
  check("raid with logging on: no dialog", a.instShows == 1)
  a.combatLog = false
  go(a, WORLD)
  go(a, MC)
  check("raid, combat log off: the dialog", instShown(a) and a.instShows == 2)
  -- the log doesn't start (the command did nothing)
  local b = a.named.DeadTiredLogsButton_LogIt
  b.attrs.macrotext = "/nothing"    -- simulate a client that ignores the command
  a.printed = {}
  click(a, "DeadTiredLogsButton_LogIt")
  w:advance(0.5)
  check("after-click line matches the state read 0.5 s later (off)",
    a:said("The log didn't start. Type /combatlog yourself.") ~= nil)
  check("Log it never reached the client's logging switch with an argument", calls.argCalls == 0)
end

-- ------------------------------------------------------------ battlegrounds, arenas, open world
do
  local a = newClient(w, { guild = G, db = {} })
  counter(a)
  a:login()
  go(a, WSG); go(a, WORLD); go(a, ARENA); go(a, WORLD); go(a, WSG, true); go(a, WORLD, true)
  check("battleground, arena and open world: never", a.instShows == 0 and not instShown(a))
end

-- ------------------------------------------------------------ Not now, reload, re-entry, corpse run
do
  local db = {}
  local a = newClient(w, { guild = G, db = db })
  counter(a)
  a:login()
  go(a, WC)
  check("dungeon: one dialog", a.instShows == 1)
  a.printed = {}
  click(a, "DeadTiredLogsButton_NotNow")
  check("Not now closes it and changes nothing", not instShown(a) and a.combatLog == false)
  w:advance(1)
  check("Not now prints nothing", #a.printed == 0)
  a:fire("PLAYER_ENTERING_WORLD", false, false)
  check("Not now, then a loading screen inside: no second dialog", a.instShows == 1)
  -- /reload inside: a new Lua session on the same SavedVariables
  a:logout()
  local a2 = newClient(w, { guild = G, db = db, where = WC })
  counter(a2)
  a2:fire("PLAYER_ENTERING_WORLD", false, true)
  check("Not now, then /reload inside the same instance: no dialog", a2.instShows == 0)
  go(a2, WC, true)
  check("and a zone change after it: still none", a2.instShows == 0)
  -- corpse run: released, ghost outside, back in
  a2.deadState = true
  go(a2, WORLD)
  go(a2, WC)
  a2.deadState = false
  check("a corpse run back in: no dialog", a2.instShows == 0)
  -- leave and enter again
  go(a2, WORLD)
  go(a2, WC)
  check("leaving and entering again: one dialog", a2.instShows == 1)
  -- a fresh login inside (the client switched the log off at logout): a new visit
  a2:logout()
  local a3 = newClient(w, { guild = G, db = db, where = WC })
  counter(a3)
  a3:login()
  check("a fresh login inside an instance asks again", a3.instShows == 1)
end

-- ------------------------------------------------------------ combat
do
  local a = newClient(w, { guild = G, db = {} })
  counter(a)
  a:login()
  a.combat = true
  local okEnter = pcall(go, a, RFC)
  check("entering in combat: no secure change attempted (no error)", okEnter)
  check("entering in combat: no dialog yet", a.instShows == 0 and not instShown(a))
  check("no handler error from secure changes in combat", (a:db().errors.logs or 0) == 0)
  a.combat = false
  a:fire("PLAYER_REGEN_ENABLED")
  check("combat ends inside: shown", a.instShows == 1 and instShown(a))
  -- dropped if you've left
  click(a, "DeadTiredLogsButton_NotNow")
  go(a, WORLD)
  a.combat = true
  go(a, MC)
  go(a, WORLD)
  a.combat = false
  a:fire("PLAYER_REGEN_ENABLED")
  check("combat ends outside: dropped", a.instShows == 1 and not instShown(a))
  -- a click in combat: hidden when combat ends
  go(a, RFC)
  check("re-entry: dialog", a.instShows == 2)
  a.combat = true
  click(a, "DeadTiredLogsButton_NotNow")
  check("clicked in combat: stays up until combat ends", instShown(a))
  a.combat = false
  a:fire("PLAYER_REGEN_ENABLED")
  check("then closes", not instShown(a))
end

-- ------------------------------------------------------------ /dt logs off / on
do
  local db = {}
  local a = newClient(w, { guild = G, db = db })
  counter(a)
  a:login()
  a:slash("logs off")
  check("/dt logs off stored", db.logs.ask == false and a:said("No more asking") ~= nil)
  go(a, RFC); go(a, WORLD); go(a, MC)
  check("/dt logs off: never", a.instShows == 0)
  a:logout()
  local a2 = newClient(w, { guild = G, db = db })
  counter(a2)
  a2:login()
  go(a2, RFC)
  check("off survives a reload", a2.instShows == 0)
  a2:slash("logs")
  check("/dt logs reports state and both settings", a2:said("combat log") ~= nil
    and a2:said("Asking in dungeons and raids: off") ~= nil and a2:said("At login: off") ~= nil)
  a2:slash("logs on")
  check("/dt logs on stored", db.logs.ask == true and a2:said("I'll ask") ~= nil)
  go(a2, WORLD); go(a2, RFC)
  check("/dt logs on: back", a2.instShows == 1)
  a2:logout()
  local a3 = newClient(w, { guild = G, db = db })
  counter(a3)
  a3:login(); go(a3, MC)
  check("on survives a reload", a3.instShows == 1)
  a3:slash("logs nonsense")
  check("a bad argument prints usage", a3:said("logs login on/off") ~= nil)
end

-- ------------------------------------------------------------ the login prompt (R2)
do
  local db = {}
  local a = newClient(w, { guild = G, db = db })
  counter(a)
  a:login()
  check("login asking off by default", a.loginShows == 0 and db.logs == nil)
  a:slash("logs login on")
  check("/dt logs login on stored", db.logs.login == true)
  a:logout()
  local a2 = newClient(w, { guild = G, db = db })
  counter(a2)
  a2:fire("PLAYER_ENTERING_WORLD", false, true)
  check("login on: asks at /reload", a2.loginShows == 1)
  check("login dialog title", login(a2).title.text == "The dead keep records. Turn them on?")
  check("status line, both off", login(a2).status.text:find("combat log", 1, true) == 1
    and login(a2).status.text:find("OFF") ~= nil)
  local B = function(k) return a2.named["DeadTiredLogsButton_" .. k] end
  check("both off: Combat log armed /combatlog", B("Combat").enabled and B("Combat").attrs.macrotext == "/combatlog")
  check("both off: Chat log armed /chatlog", B("Chat").enabled and B("Chat").attrs.macrotext == "/chatlog")
  check("both off: Both armed with both", B("Both").enabled and B("Both").attrs.macrotext == "/combatlog\n/chatlog")
  check("Neither runs nothing", B("Neither").attrs.type == nil)
  go(a2, WORLD, true); a2:fire("PLAYER_ENTERING_WORLD", false, false)
  check("not on zone changes or loading screens", a2.loginShows == 1)
  a2.printed = {}
  click(a2, "DeadTiredLogsButton_Chat")
  w:advance(0.5)
  check("Chat log: chat log on, combat untouched", a2.chatLog == true and a2.combatLog == false)
  check("after-click line from the re-read", a2.printed[1] ~= nil
    and a2.printed[1]:find("combat log |cffff4040OFF|r, chat log |cff40ff40ON|r.", 1, true) ~= nil)
  -- reload with chat on: only combat offered
  a2:logout()
  local a3 = newClient(w, { guild = G, db = db, chatLog = true })
  counter(a3)
  a3:fire("PLAYER_ENTERING_WORLD", false, true)
  local C = function(k) return a3.named["DeadTiredLogsButton_" .. k] end
  check("chat on: dialog shows", a3.loginShows == 1)
  check("chat on: only the combat log offered", C("Combat").enabled and not C("Chat").enabled
    and not C("Both").enabled and C("Chat").attrs.macrotext == nil and C("Both").attrs.macrotext == nil)
  a3:logout()
  local a4 = newClient(w, { guild = G, db = db, combatLog = true })
  counter(a4)
  a4:fire("PLAYER_ENTERING_WORLD", true, false)
  local D = function(k) return a4.named["DeadTiredLogsButton_" .. k] end
  check("combat on: only the chat log offered", D("Chat").enabled and not D("Combat").enabled
    and not D("Both").enabled and D("Combat").attrs.macrotext == nil)
  a4:logout()
  local a5 = newClient(w, { guild = G, db = db, combatLog = true, chatLog = true })
  counter(a5)
  a5:fire("PLAYER_ENTERING_WORLD", true, false)
  check("both on: nothing shows", a5.loginShows == 0 and not loginShown(a5))
  a5:slash("logs now")
  check("/dt logs now, both on: Already logging both.", a5:said("Already logging both.") ~= nil and a5.loginShows == 0)
  a5.chatLog = false
  a5:slash("logs now")
  check("/dt logs now, one off: the login dialog", a5.loginShows == 1)
  a5:slash("logs login off")
  check("/dt logs login off stored", db.logs.login == false)
  a5:logout()
  local a6 = newClient(w, { guild = G, db = db })
  counter(a6)
  a6:fire("PLAYER_ENTERING_WORLD", false, true)
  check("login off: no dialog at reload", a6.loginShows == 0)
  -- login inside a dungeon with login asking on: one dialog, the login one
  db.logs.login = true
  a6:logout()
  local a7 = newClient(w, { guild = G, db = db, where = RFC })
  counter(a7)
  a7:login()
  check("login inside a dungeon: the login dialog only, not two", a7.loginShows == 1 and a7.instShows == 0)
  -- login prompt in combat
  a7:logout()
  local a8 = newClient(w, { guild = G, db = db })
  counter(a8)
  a8.combat = true
  local okLogin = pcall(a8.login, a8)
  check("login in combat: no secure change attempted (no error)", okLogin)
  check("login in combat: waits", a8.loginShows == 0)
  a8.combat = false
  a8:fire("PLAYER_REGEN_ENABLED")
  check("login in combat: shown when combat ends", a8.loginShows == 1)
  -- the Neither click still reports the re-read
  a8.printed = {}
  click(a8, "DeadTiredLogsButton_Neither")
  w:advance(0.5)
  check("Neither: nothing switched, one line", a8.combatLog == false and a8.chatLog == false
    and #a8.printed == 1 and a8.printed[1]:find("chat log", 1, true) ~= nil)
end

-- ------------------------------------------------------------ key-down clients
do
  local a = newClient(w, { guild = G, db = {}, keyDown = true })
  counter(a)
  a:login(); go(a, RFC)
  click(a, "DeadTiredLogsButton_LogIt")
  w:advance(0.5)
  check("ActionButtonUseKeyDown: macro and PostClick on the same half", a.combatLog == true
    and a:said("Logging.") ~= nil and not instShown(a))
end

-- ------------------------------------------------------------ fallback reads, unknown state
do
  local a = newClient(w, { guild = G, db = {}, noCI = true })
  counter(a)
  a:login(); go(a, RFC)
  check("no C_ChatInfo readers: the globals read with no argument still work", a.instShows == 1)
  a.combatLog = true
  go(a, WORLD); go(a, MC)
  check("fallback read sees logging on: no dialog", a.instShows == 1)
  local u = newClient(w, { guild = G, db = {}, noCI = true })
  u.env.LoggingCombat, u.env.LoggingChat = nil, nil
  counter(u)
  u:login(); go(u, RFC)
  check("unknown state is treated as off: the dialog", u.instShows == 1)
  u:slash("logs")
  check("unknown state shows ?", u:said("|cffaaaaaa?|r") ~= nil)
end

-- ------------------------------------------------------------ non-members
do
  local db = {}
  local x = newClient(w, { name = "Spy", guild = "Alliance Spies", db = db })
  counter(x)
  x:login(); go(x, RFC); go(x, WORLD); go(x, MC)
  check("another guild: no dialog", x.instShows == 0 and x.loginShows == 0)
  check("another guild: nothing stored", db.logs == nil)
  check("another guild: nothing printed", #x.printed == 0)
  x:slash("logs on")
  check("/dt logs outside the guild: card 1's one line, nothing stored",
    x:said("only stirs inside") ~= nil and db.logs == nil)
  -- the account-wide setting is on (set by a guild character), played on an alt outside the guild
  local adb = { logs = { login = true } }
  local alt = newClient(w, { name = "Outsider", guild = "Alliance Spies", db = adb })
  counter(alt)
  alt:fire("PLAYER_ENTERING_WORLD", true, false)
  alt:fire("PLAYER_ENTERING_WORLD", false, true)
  check("login asking on, character outside the guild: no login dialog", alt.loginShows == 0
    and not loginShown(alt) and #alt.printed == 0)
  go(alt, RFC)
  check("and nothing stored for it", adb.logs.visit == nil and alt.instShows == 0)
  local y = newClient(w, { name = "Loner", guild = nil, db = {} })
  counter(y)
  y:login(); go(y, RFC)
  check("no guild: no dialog, nothing stored", y.instShows == 0 and y:db().logs == nil)
  -- guild info arriving late inside a dungeon
  local late = newClient(w, { name = "Latecomer", guild = nil, db = {} })
  counter(late)
  late:login(); go(late, RFC)
  check("guild info late: no dialog yet", late.instShows == 0)
  late.guild = G
  late:fire("PLAYER_GUILD_UPDATE", "player")
  check("guild info late: the dialog when membership arrives", late.instShows == 1)
end

-- ------------------------------------------------------------ a scripted session: no switching, no combat events
do
  local db = {}
  local s = newClient(w, { guild = G, db = db })
  counter(s)
  s:login()
  for i = 1, 3 do
    go(s, RFC); s.combat = true; go(s, RFC, true); s.combat = false; s:fire("PLAYER_REGEN_ENABLED")
    if instShown(s) then click(s, i == 2 and "DeadTiredLogsButton_LogIt" or "DeadTiredLogsButton_NotNow") end
    go(s, WORLD); s.combatLog = false
    go(s, WSG); go(s, WORLD); go(s, MC)
    if instShown(s) then click(s, "DeadTiredLogsButton_LogIt") end
    w:advance(1)
    s:slash("logs"); s:slash("logs now")
    if loginShown(s) then click(s, "DeadTiredLogsButton_Both") end
    w:advance(1)
    s:slash("logs login on"); go(s, WORLD)
    s:logout()
    s = newClient(w, { guild = G, db = db })
    counter(s)
    s:fire("PLAYER_ENTERING_WORLD", false, true)
    if loginShown(s) then click(s, "DeadTiredLogsButton_Neither") end
    w:advance(1)
  end
  check("scripted session: zero calls to the logging switches with an argument", calls.argCalls == 0)
  check("scripted session: the state was read", calls.reads > 0)
  local combatEvents = false
  for _, c in ipairs(w.clients) do
    for _, f in ipairs(c.frames) do
      for e in pairs(f.events or {}) do
        if e:find("COMBAT") or e:find("UNIT_") then combatEvents = true end
      end
    end
  end
  check("no combat event registered by any frame", not combatEvents)
  check("no handler errors recorded", (s:db().errors.logs or 0) == 0)
end

H.finish("logs")
