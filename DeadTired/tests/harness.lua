-- Dead Tired offline test harness (framework round). Plain Lua 5.1, no framework.
--
-- Copied in shape from rc3's tests/harness.lua (which follows reference/wizardry/tests/
-- test_forever_core.lua): a "world" holds one clock, one timer queue and one GUILD bus; each client
-- is a separate addon instance with its own environment (setfenv), its own ns, its own DeadTiredDB
-- and WoW stubs. New for the framework:
--   * every file in DeadTired.toc is loaded, the bundled libraries included (the real AceComm,
--     ChatThrottleLib, LibSerialize, LibDeflate and LibSharedMedia run in the tests);
--   * generic frames: any method call works (unknown ones do nothing), with points, shown state,
--     scripts, text and checked state kept; OnUpdate runs for shown frames as the clock moves
--     (ChatThrottleLib needs it);
--   * names with surnames: c.name ("Stromham", UnitName) and c.full ("Stromham Hamson",
--     GetUnitName(unit, true));
--   * the sender string a receiver sees is c.senderShape(from, to) (default: the full name, plus
--     "-NormRealm" when the realms differ);
--   * a settable SendAddonMessage result (c.sendResult: 0 default; a function is called with the
--     text; non-zero results are refused: kept in c.refused, not delivered);
--   * global writes are recorded (c.globalWrites) and hooksecurefunc calls too (c.hooks).

local H = {}

local here = (arg and arg[0] or ""):match("^(.*)[/\\]tests[/\\][^/\\]+$")
H.addonDir = here or "DeadTired"

-- ---------------------------------------------------------------- checks
local fails, passes = 0, 0
function H.check(name, cond)
  if cond then passes = passes + 1 else fails = fails + 1; print("FAIL " .. name) end
  return cond
end
function H.finish(suite)
  print(string.format("%s: %d passed, %d failed", suite, passes, fails))
  os.exit(fails == 0 and 0 or 1)
end

-- LibSharedMedia reads bit through getfenv(0), the real global table.
local function band(a, b)
  local r, bitv = 0, 1
  a, b = math.floor(a), math.floor(b)
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then r = r + bitv end
    a, b, bitv = math.floor(a / 2), math.floor(b / 2), bitv * 2
  end
  return r
end
bit = bit or { band = band }

-- The .toc's file list, in order.
function H.tocFiles()
  local files = {}
  for line in io.lines(H.addonDir .. "/DeadTired.toc") do
    line = line:gsub("\r", "")
    if line ~= "" and not line:match("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
  end
  return files
end

H.RESULT = { Success = 0, InvalidPrefix = 1, InvalidMessage = 2, AddonMessageThrottle = 3, InvalidChatType = 4,
  NotInGroup = 5, TargetRequired = 6, InvalidChannel = 7, ChannelThrottle = 8, GeneralError = 9, NotInGuild = 10,
  AddOnMessageLockdown = 11, TargetOffline = 12 }

local function norm(realm) return (realm:gsub("[%s%-]", "")) end
H.norm = norm

-- ---------------------------------------------------------------- frames

local Frame = {}
local function newFrame(c, ftype, name, parent, template)
  local f = { _type = ftype or "Frame", _name = name, _parent = parent, _template = template, events = {},
    scripts = {}, points = {}, shown = true, calls = {}, children = {}, c = c, w = 0, h = 0 }
  setmetatable(f, Frame)
  table.insert(c.frames, f)
  if type(name) == "string" then c.env[name] = f; c.namedFrames[name] = f end
  return f
end
Frame.__index = function(t, k)
  local m = rawget(Frame, k)
  if m then return m end
  if type(k) ~= "string" or not k:match("^%u") then return nil end   -- fields: nil; Methods: recorded
  return function(self, ...)                    -- any other method: recorded, does nothing
    local list = rawget(self, "calls")
    list[#list + 1] = { k, ... }
    return nil
  end
end
function Frame:RegisterEvent(e) self.events[e] = true end
function Frame:UnregisterEvent(e) self.events[e] = nil end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:IsEventRegistered(e) return self.events[e] == true end
function Frame:SetScript(k, fn) self.scripts[k] = fn end
function Frame:GetScript(k) return self.scripts[k] end
function Frame:HookScript(k, fn) local old = self.scripts[k]; self.scripts[k] = function(...) if old then old(...) end fn(...) end end
function Frame:Show()
  local was = self.shown
  self.shown = true
  if not was and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Frame:Hide()
  local was = self.shown
  self.shown = false
  if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() return self.shown end
function Frame:SetShown(v) if v then self:Show() else self:Hide() end end
function Frame:SetPoint(p, rel, rp, x, y)
  if type(rel) == "number" then rel, rp, x, y = nil, p, rel, rp end
  self.points[#self.points + 1] = { p, rel, rp or p, x or 0, y or 0 }
end
function Frame:ClearAllPoints() self.points = {} end
function Frame:GetPoint(i)
  local pt = self.points[i or 1]
  if not pt then return nil end
  return pt[1], pt[2], pt[3], pt[4], pt[5]
end
function Frame:GetNumPoints() return #self.points end
function Frame:SetAllPoints(rel) self.points = { { "TOPLEFT", rel, "TOPLEFT", 0, 0 } } end
function Frame:SetSize(w, h) self.w, self.h = w, h end
function Frame:SetWidth(w) self.w = w end
function Frame:SetHeight(h) self.h = h end
function Frame:GetWidth() return self.w end
function Frame:GetHeight() return self.h end
function Frame:StartMoving() self.moving = true end
function Frame:StopMovingOrSizing() self.moving = false end
function Frame:SetText(t) self.text = t end
function Frame:GetText() return self.text end
-- Text metrics (fix round 4: font-aware). A character (a UTF-8 character, not a byte) is half the
-- font's size wide, a line is the font's size tall; with no font set, 12 (so 6 px a character and
-- 12 px a line, as before). A string with word wrap off is one line; otherwise it wraps at its
-- width when one is set.
local function chars(s) return #(s:gsub("[\128-\191]", "")) end
local function fontSize(f) return (f.font and tonumber(f.font[2])) or 12 end
function Frame:GetStringWidth() return chars(tostring(self.text or "")) * fontSize(self) / 2 end
function Frame:GetStringHeight()
  local n = chars(tostring(self.text or ""))
  if n == 0 then return 0 end
  local size = fontSize(self)
  if self.wordWrap == false or not self.w or self.w <= 0 then return size end
  return math.ceil(n * size / 2 / self.w) * size
end
function Frame:SetWordWrap(v) self.wordWrap = v and true or false end
function Frame:SetChecked(v) self.checked = v and true or false end
function Frame:GetChecked() return self.checked end
function Frame:GetName() return self._name end
function Frame:GetParent() return self._parent end
function Frame:SetBackdrop(b) self.backdrop = b end
function Frame:SetBackdropColor(...) self.bgColour = { ... } end
function Frame:SetBackdropBorderColor(...) self.borderColour = { ... } end
function Frame:SetFont(p, s, fl) self.font = { p, s, fl } end
function Frame:SetTextColor(...) self.textColour = { ... } end
function Frame:SetTexture(t) self.texture = t end
function Frame:SetColorTexture(...) self.colourTexture = { ... } end
function Frame:CreateFontString(name) local fs = newFrame(self.c, "FontString", name, self); return fs end
function Frame:CreateTexture(name) local t = newFrame(self.c, "Texture", name, self); return t end
function Frame:AddLine(t) self.lines = self.lines or {}; table.insert(self.lines, t) end

H.Frame = Frame

-- ---------------------------------------------------------------- the world

local World = {}
World.__index = World

function H.world()
  return setmetatable({ t = 1000, timers = {}, seq = 0, clients = {}, wire = {} }, World)
end

function World:schedule(d, fn)
  self.seq = self.seq + 1
  table.insert(self.timers, { due = self.t + (tonumber(d) or 0), seq = self.seq, fn = fn })
end

local function onUpdates(w, dt)
  for _, c in ipairs(w.clients) do
    for _, f in ipairs(c.frames) do
      if f.shown and f.scripts.OnUpdate then f.scripts.OnUpdate(f, dt) end
    end
  end
end

-- Move the clock `d` seconds in 0.1 s steps: timers in time order, then OnUpdate for shown frames.
function World:advance(d)
  local stop = self.t + (d or 0)
  local step = 0.1
  repeat
    local nextT = math.min(stop, self.t + step)
    while true do
      local best, bi
      for i, tm in ipairs(self.timers) do
        if tm.due <= nextT and (not best or tm.due < best.due or (tm.due == best.due and tm.seq < best.seq)) then
          best, bi = tm, i
        end
      end
      if not best then break end
      table.remove(self.timers, bi)
      if best.due > self.t then self.t = best.due end
      best.fn()
    end
    local dt = nextT - self.t
    self.t = nextT
    onUpdates(self, dt > 0 and dt or step)
  until self.t >= stop
end

-- Deliver a GUILD addon message from `from` to every client in the same guild, the sender included
-- (the GUILD channel echoes), on the next tick.
function World:deliver(from, prefix, text, chan)
  table.insert(self.wire, { from = from, prefix = prefix, text = text, chan = chan, t = self.t })
  self:schedule(0, function()
    for _, c in ipairs(self.clients) do
      if c.guild and from.guild and c.guild == from.guild and c.registered[prefix] and not c.deaf then
        c:fire("CHAT_MSG_ADDON", prefix, text, chan, c.senderShape(from, c), c.full, 0, 0, "", 0)
      end
    end
  end)
end

-- ---------------------------------------------------------------- a client
local Client = {}
Client.__index = Client

local OWN_GLOBAL = { DT = true }
function H.ownGlobal(name)
  return OWN_GLOBAL[name] or name:match("^DeadTired") ~= nil or name:match("^SLASH_DEADTIRED%d+$") ~= nil
end

-- opts: name, full, realm, guild, db, load (false: no ADDON_LOADED), setup(c) (before load),
--       afterLibs(c) (after the libraries load, before DT's own files), addons = { Name = true },
--       senderShape = fn(from, to), random = fn
function World:client(opts)
  opts = opts or {}
  local c = setmetatable({ world = self, name = opts.name or "Stromham", realm = opts.realm or "CAMWOW EU4 Realm 2 PvP",
    guild = opts.guild, printed = {}, sent = {}, refused = {}, frames = {}, namedFrames = {}, registered = {},
    secrets = {}, lockdown = false, sendResult = 0, restricted = true, addons = opts.addons or {},
    globalWrites = {}, hooks = {}, errors = {}, opts = opts, target = opts.target }, Client)
  c.full = opts.full or (c.name .. " Hamson")
  c.senderShape = opts.senderShape or function(from, to)
    if norm(from.realm) == norm(to.realm) then return from.full end
    return from.full .. "-" .. norm(from.realm)
  end
  local env = setmetatable({}, { __index = _G, __newindex = function(t, k, v)
    table.insert(c.globalWrites, k)
    rawset(t, k, v)
  end })
  c.env = env
  rawset(env, "_G", env)
  rawset(env, "DeadTiredDB", opts.db)
  rawset(env, "SlashCmdList", {})
  local E = function(k, v) rawset(env, k, v) end
  E("GetTime", function() return self.t end)
  E("date", function() return "2026-11-11 21:00:00" end)
  E("time", function() return 1794000000 + math.floor(self.t - 1000) end)
  E("GetBuildInfo", function() return "1.60.1", "70245", "Nov 1 2026", 16001 end)
  E("GetRealmName", function() return c.realm end)
  E("GetNormalizedRealmName", function() if c.normRealm == false then return nil end return norm(c.realm) end)
  E("UnitName", function(u)
    if u == "player" then return c.unknown and "Unknown" or c.name end
    if u == "target" and c.target then return c.target.name end
  end)
  E("UnitFullName", function(u)
    if u == "player" then return c.name, norm(c.realm) end
    if u == "target" and c.target then return c.target.name, c.target.realm end
  end)
  E("GetUnitName", function(u, showRealm)
    if u == "player" then if c.unknown then return "Unknown" end return showRealm and c.full or c.name end
    if u == "target" and c.target then return showRealm and c.target.full or c.target.name end
  end)
  E("issecretvalue", function(v) return c.secrets[v] == true end)
  E("GetGuildInfo", function(u)
    if u == "player" and c.guild then return c.guild, "Restless Dead", 3, c.realm end
    return nil
  end)
  E("GetLocale", function() return "enGB" end)
  E("GetFramerate", function() return 60 end)
  E("strlen", string.len)
  E("Ambiguate", function(s, mode)
    local n, r = tostring(s):match("^(.-)%-([^%-]+)$")
    if n and r == norm(c.realm) then return n end
    return s
  end)
  E("geterrorhandler", function() return function(e) table.insert(c.errors, tostring(e)) end end)
  E("securecallfunction", function(fn, ...)
    local args, n = { ... }, select("#", ...)
    local r = { xpcall(function() return fn(unpack(args, 1, n)) end, function(e) table.insert(c.errors, tostring(e)) return e end) }
    return unpack(r, 2, table.maxn(r))
  end)
  -- xpcall with arguments (Lua 5.2 style), as WoW has it
  E("xpcall", function(fn, handler, ...)
    local args = { ... }
    local n = select("#", ...)
    return xpcall(function() return fn(unpack(args, 1, n)) end, handler)
  end)
  E("hooksecurefunc", function(a, b, d)
    local tbl, key, fn = a, b, d
    if type(a) == "string" then tbl, key, fn = env, a, b end
    table.insert(c.hooks, { tbl = tbl, key = key })
    local orig = rawget(tbl, key) or tbl[key]
    if type(orig) ~= "function" then orig = function() end end
    rawset(tbl, key, function(...)
      local r = { orig(...) }
      fn(...)
      return unpack(r, 1, table.maxn(r))
    end)
  end)
  E("Enum", { SendAddonMessageResult = H.RESULT })
  E("C_Timer", { After = function(d, fn) self:schedule(d, fn) end })
  E("C_AddOns", { IsAddOnLoaded = function(n) return c.addons[n] == true, c.addons[n] == true end })
  E("C_UIFileAsset", { IsKnownFile = function(p) return type(p) == "string" end })
  E("C_BattleNet", { SendGameData = function() end })
  E("C_ChatInfo", {
    RegisterAddonMessagePrefix = function(p) c.registered[p] = true return true end,
    AreOutgoingAddonChatMessagesRestricted = function() return c.restricted end,
    InChatMessagingLockdown = function() return c.lockdown end,
    SendChatMessage = function() end,
    SendAddonMessageLogged = function() end,
    SendAddonMessage = function(prefix, text, chan)
      assert(type(text) == "string" and #text <= 255, "addon message over 255 bytes")
      local r = c.sendResult
      if type(r) == "function" then r = r(text) end
      if r ~= 0 then
        table.insert(c.refused, { prefix = prefix, text = text, chan = chan, t = self.t, r = r })
        return r
      end
      table.insert(c.sent, { prefix = prefix, text = text, chan = chan, t = self.t })
      self:deliver(c, prefix, text, chan)
      return r
    end,
  })
  E("DEFAULT_CHAT_FRAME", { AddMessage = function(_, m) table.insert(c.printed, m) end })
  E("Settings", { RegisterCanvasLayoutCategory = function(f, n) c.settingsCat = { frame = f, name = n } return c.settingsCat end,
    RegisterAddOnCategory = function(cat) c.addOnCategory = cat end })
  E("CreateFrame", function(ftype, name, parent, template) return newFrame(c, ftype, name, parent, template) end)
  E("UIParent", newFrame(c, "Frame", "UIParent"))
  if opts.random then E("math", setmetatable({ random = opts.random }, { __index = math })) end
  if opts.setup then opts.setup(c) end

  c.files = opts.files or H.tocFiles()
  local own = false
  for _, file in ipairs(c.files) do
    if not own and not file:match("^Libs/") then
      own = true
      c.libWrites = #c.globalWrites
      if opts.afterLibs then opts.afterLibs(c) end
    end
    local chunk = assert(loadfile(H.addonDir .. "/" .. file))
    setfenv(chunk, env)
    chunk("DeadTired", c.ns or (function() c.ns = {} return c.ns end)())
  end
  c.DT = c.ns.DT
  table.insert(self.clients, c)
  if opts.load ~= false then c:fire("ADDON_LOADED", "DeadTired") end
  return c
end

-- Globals written by DT's own files (not the libraries) during load.
function Client:ownWrites()
  local out = {}
  for i = (self.libWrites or 0) + 1, #self.globalWrites do out[#out + 1] = self.globalWrites[i] end
  return out
end

local function again(c, extra)
  local o = {}
  for k, v in pairs(c.opts) do o[k] = v end
  for k, v in pairs(extra or {}) do o[k] = v end
  o.name, o.full, o.realm, o.guild, o.db, o.load = c.name, c.full, c.realm, c.guild, c:db(), nil
  o.addons = c.addons
  c:logout()
  return c.world:client(o)
end

-- /reload: a new instance on the same SavedVariables, then PLAYER_LOGIN and PLAYER_ENTERING_WORLD.
function Client:reload()
  local n = again(self)
  n:fire("PLAYER_LOGIN")
  n:fire("PLAYER_ENTERING_WORLD", false, true)
  return n
end

function Client:logout()
  for i, c in ipairs(self.world.clients) do if c == self then table.remove(self.world.clients, i) return end end
end

function Client:fire(ev, ...)
  for _, f in ipairs(self.frames) do
    if f.events[ev] and f.scripts.OnEvent then f.scripts.OnEvent(f, ev, ...) end
  end
end

-- Log in: PLAYER_LOGIN, then the first PLAYER_ENTERING_WORLD (isInitialLogin, isReloadingUi).
function Client:login()
  self:fire("PLAYER_LOGIN")
  self:fire("PLAYER_ENTERING_WORLD", true, false)
end

function Client:slash(msg) self.printed = {}; return self.env.SlashCmdList.DEADTIRED(msg) end

function Client:printedText() return table.concat(self.printed, "\n") end

function Client:said(needle)
  for _, m in ipairs(self.printed) do if m:find(needle, 1, true) then return m end end
end

function Client:count(needle)
  local n = 0
  for _, m in ipairs(self.printed) do if m:find(needle, 1, true) then n = n + 1 end end
  return n
end

function Client:key() return norm(self.realm) .. "-" .. self.full end
function Client:db() return rawget(self.env, "DeadTiredDB") end
function Client:frame(name) return self.namedFrames[name] end

-- A stand-in for LibDataBroker-1.1 as another addon would load it: written here from its public API
-- (NewDataObject, DataObjectIterator, GetDataObjectByName, the two callbacks); not LDB's code.
function H.fakeLDB(c)
  local LS = rawget(c.env, "LibStub")
  local lib = LS:NewLibrary("LibDataBroker-1.1", 4)
  local CBH = LS("CallbackHandler-1.0")
  lib.callbacks = CBH:New(lib)
  local store, proxies = {}, {}
  function lib:NewDataObject(name, data)
    if proxies[name] then return nil end
    local attrs = {}
    for k, v in pairs(data or {}) do attrs[k] = v end
    local proxy = setmetatable({}, {
      __index = attrs,
      __newindex = function(_, k, v)
        if attrs[k] == v then return end
        attrs[k] = v
        lib.callbacks:Fire("LibDataBroker_AttributeChanged", name, k, v, proxies[name])
      end })
    proxies[name], store[name] = proxy, attrs
    lib.callbacks:Fire("LibDataBroker_DataObjectCreated", name, proxy)
    return proxy
  end
  function lib:DataObjectIterator() return pairs(proxies) end
  function lib:GetDataObjectByName(name) return proxies[name] end
  return lib
end

return H
