-- Dead Tired offline test harness. Plain Lua 5.1, no framework.
--
-- A "world" holds one clock, one timer queue and one fake GUILD bus. Each client is a separate
-- addon instance: its own environment (setfenv), its own ns, its own DeadTiredDB and WoW stubs.
-- SendAddonMessage on one client is delivered (on the next tick, as the real client delivers
-- asynchronously) to the CHAT_MSG_ADDON handler of every client in the same guild, the sender
-- included, exactly as the GUILD channel echoes to its sender.
--
-- Stub style follows reference/wizardry/tests/test_forever_core.lua: GetTime, date, time,
-- GetBuildInfo ("1.60.1", "70245"), UnitName, GetRealmName ("Classic Beta PvP"), issecretvalue,
-- C_Timer.After, DEFAULT_CHAT_FRAME, CreateFrame with RegisterEvent / SetScript.
-- Fix round 3: GetNormalizedRealmName (the realm without spaces or hyphens; c.normRealm
-- overrides it, false makes it answer nil, "absent" removes it), C_ChatInfo.InChatMessagingLockdown
-- (c.lockdown: true / false, "absent" or "error"), and a settable SendAddonMessage result
-- (c.sendResult: 0 by default; H.NIL answers nil; a function is called; anything that isn't a
-- success is refused: kept in c.refused, not sent, not delivered).

local H = {}
H.NIL = {}

local here = (arg and arg[0] or ""):match("^(.*)[/\\]tests[/\\][^/\\]+$")
H.addonDir = here or "DeadTired"

H.FILES = { "Config.lua", "Core.lua", "Guild.lua", "Comms.lua", "Roster.lua", "Alts.lua", "Welcome.lua" }

-- ---------------------------------------------------------------- checks
local fails, passes = 0, 0
function H.check(name, cond)
  if cond then passes = passes + 1 else fails = fails + 1; print("FAIL " .. name) end
end
function H.finish(suite)
  print(string.format("%s: %d passed, %d failed", suite, passes, fails))
  os.exit(fails == 0 and 0 or 1)
end

-- ---------------------------------------------------------------- the world
local World = {}
World.__index = World

function H.world()
  local w = setmetatable({ t = 1000, timers = {}, seq = 0, clients = {}, wire = {} }, World)
  return w
end

function World:schedule(d, fn)
  self.seq = self.seq + 1
  table.insert(self.timers, { due = self.t + (tonumber(d) or 0), seq = self.seq, fn = fn })
end

-- Run every timer due within the next `d` seconds, in time order, moving the clock.
function World:advance(d)
  local stop = self.t + (d or 0)
  while true do
    local best, bi
    for i, tm in ipairs(self.timers) do
      if tm.due <= stop and (not best or tm.due < best.due or (tm.due == best.due and tm.seq < best.seq)) then
        best, bi = tm, i
      end
    end
    if not best then break end
    table.remove(self.timers, bi)
    if best.due > self.t then self.t = best.due end
    best.fn()
  end
  self.t = stop
end

-- Deliver a GUILD addon message from `from` to every client in the same guild.
function World:deliver(from, prefix, text, chan)
  table.insert(self.wire, { from = from, prefix = prefix, text = text, chan = chan, t = self.t })
  local sender = from.name .. "-" .. from.realm:gsub("[%s%-]", "")
  self:schedule(0, function()
    for _, c in ipairs(self.clients) do
      if c.guild and from.guild and c.guild == from.guild and c.registered[prefix] then
        c:fire("CHAT_MSG_ADDON", prefix, text, chan, sender, c.name, 0, 0, "", 0)
      end
    end
  end)
end

-- ---------------------------------------------------------------- a client
local Client = {}
Client.__index = Client

-- opts: name, realm, guild (string or nil), files (list), load (false to skip ADDON_LOADED),
--       db (pre-existing DeadTiredDB table: the account's SavedVariables)
function World:client(opts)
  local c = setmetatable({ world = self, name = opts.name or "Stromham", realm = opts.realm or "Classic Beta PvP",
    guild = opts.guild, printed = {}, sent = {}, frames = {}, registered = {}, secrets = {},
    restricted = false, sendError = false, lockdown = false, sendResult = 0, refused = {}, ns = {}, opts = opts, uptimeOffset = opts.uptimeOffset or 0 }, Client)
  local env = setmetatable({}, { __index = _G })
  c.env = env
  env._G = env
  env.DeadTiredDB = opts.db
  -- GetTime is this machine's uptime (the world clock, less any reboot offset); time() is the
  -- epoch, moving with the world clock and never reset (fix round 1, F3).
  env.GetTime = function() return self.t - c.uptimeOffset end
  env.date = function(fmt) if c.noDate then error("no date") end return "2026-11-04 23:00:00" end
  env.time = function() return 1793833200 + math.floor(self.t - 1000) end
  env.GetBuildInfo = function() return "1.60.1", "70245", "Nov 1 2026", 16001 end
  env.GetRealmName = function() return c.realm end
  env.GetNormalizedRealmName = function()
    if c.normRealm == false then return nil end
    if c.normRealm ~= nil then return c.normRealm end
    return (c.realm:gsub("[%s%-]", ""))
  end
  if opts.normRealm == "absent" then env.GetNormalizedRealmName = nil end
  env.UnitName = function(u) if u == "player" then return c.name end end
  env.issecretvalue = function(v) return c.secrets[v] == true end
  env.GetGuildInfo = function(u)
    if c.guildError then error("no guild info yet") end
    if u == "player" and c.guild then return c.guild, "Restless Dead", 3, c.realm end
    return nil
  end
  env.C_Timer = { After = function(d, fn) self:schedule(d, fn) end }
  env.C_ChatInfo = {
    RegisterAddonMessagePrefix = function(p) c.registered[p] = true return true end,
    AreOutgoingAddonChatMessagesRestricted = function() c.flagCalls = (c.flagCalls or 0) + 1 return c.restricted end,
    InChatMessagingLockdown = function()
      if c.lockdown == "error" then error("no lockdown info") end
      return c.lockdown
    end,
    SendAddonMessage = function(prefix, text, chan)
      if c.sendError then error("send failed") end
      assert(type(text) == "string" and #text <= 255, "addon message over 255 bytes")
      local r = c.sendResult
      if type(r) == "function" then r = r(text) end
      if r == H.NIL then r = nil end
      if not (r == 0 or r == true or r == nil) then
        table.insert(c.refused, { prefix = prefix, text = text, chan = chan, t = self.t, r = r })
        return r
      end
      table.insert(c.sent, { prefix = prefix, text = text, chan = chan, t = self.t })
      self:deliver(c, prefix, text, chan)
      return r
    end,
  }
  if opts.lockdown == "absent" then env.C_ChatInfo.InChatMessagingLockdown = nil end
  env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(c.printed, m) end }
  env.SlashCmdList = {}
  env.CreateFrame = function()
    local f = { events = {}, scripts = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    table.insert(c.frames, f)
    return f
  end
  if opts.random then env.math = setmetatable({ random = opts.random }, { __index = math }) end

  for _, file in ipairs(opts.files or H.FILES) do
    local chunk = assert(loadfile(H.addonDir .. "/" .. file))
    setfenv(chunk, env)
    chunk("DeadTired", c.ns)
  end
  c.DT = c.ns.DT
  table.insert(self.clients, c)
  -- opts.setup(c): stubs a test needs in place before ADDON_LOADED (kept for reload and reboot).
  if opts.setup then opts.setup(c) end
  if opts.load ~= false then c:fire("ADDON_LOADED", "DeadTired") end
  return c
end

-- Fix round 1 (F3): the harness learns to forget.
local function again(c, extra)
  local o = {}
  for k, v in pairs(c.opts) do o[k] = v end
  for k, v in pairs(extra or {}) do o[k] = v end
  o.name, o.realm, o.guild, o.db, o.load = c.name, c.realm, c.guild, c:db(), nil
  c:logout()
  return c.world:client(o)
end

-- /reload: this client's Lua state is dropped and a new instance loads on the same
-- SavedVariables, then PLAYER_ENTERING_WORLD(false, true). Returns the new client.
function Client:reload()
  local n = again(self)
  n:fire("PLAYER_ENTERING_WORLD", false, true)
  return n
end

-- A restart of the machine: as reload, but GetTime() starts again at `uptime` (default 600)
-- while time() carries on, and the next PLAYER_ENTERING_WORLD is a login. Returns the new client.
function Client:reboot(uptime)
  local n = again(self, { uptimeOffset = self.world.t - (uptime or 600) })
  n:login()
  return n
end

-- Log out: the client leaves the world (its SavedVariables table stays with the test).
function Client:logout()
  for i, c in ipairs(self.world.clients) do if c == self then table.remove(self.world.clients, i) return end end
end

function Client:fire(ev, ...)
  for _, f in ipairs(self.frames) do
    if ev == "ADDON_LOADED" or f.events[ev] then f.scripts.OnEvent(f, ev, ...) end
  end
end

-- Log in: the first PLAYER_ENTERING_WORLD (isInitialLogin, isReloadingUi).
function Client:login() self:fire("PLAYER_ENTERING_WORLD", true, false) end

function Client:slash(msg) self.printed = {}; return self.env.SlashCmdList.DEADTIRED(msg) end

function Client:printedText() return table.concat(self.printed, "\n") end

function Client:said(needle)
  for _, m in ipairs(self.printed) do if m:find(needle, 1, true) then return m end end
end

-- The one key spelling (fix round 3, AUD-06): the realm without spaces or hyphens.
function Client:key() return self.realm:gsub("[%s%-]", "") .. "-" .. self.name end
function Client:oldKey() return self.realm .. "-" .. self.name end

function Client:db() return self.env.DeadTiredDB end

return H
