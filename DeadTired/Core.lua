-- Dead Tired: the core. Loaded after Config.lua; every other file uses it.
--
-- WHAT IT HOLDS, and nothing else: the guarded-read helpers (bodies copied from Tim's Wizardry
-- Forever core), the store, out(), the module wiring and the one slash router (/dt and
-- /deadtired share it). No game logic.
--
-- RULES (house rules, CLAUDE.md):
--   * Every read of game state goes through try / clean / secret.
--   * A module keeps its own frame and its own error key; a handler failure is recorded in
--     DeadTiredDB.errors and re-raised.

local ADDON, ns = ...
ns = ns or {}
local DT = {}
ns.DT = DT
DT.VERSION = "0.1.0"
DT.Config = ns.Config or {}

-- ---------------------------------------------------------------- guarded reads

function DT.secret(v)
  return issecretvalue ~= nil and issecretvalue(v) and true or false
end
local secret = DT.secret

-- Call fn(...) and return its results, or nothing if it is absent, errors, or answers
-- with a secret first value.
function DT.try(fn, ...)
  if type(fn) ~= "function" then return nil end
  local r = { pcall(fn, ...) }
  if not r[1] or secret(r[2]) then return nil end
  return unpack(r, 2, table.maxn(r))
end
local try = DT.try

function DT.clean(v)
  if v == nil or secret(v) then return nil end
  return v
end
local clean = DT.clean

function DT.now() return (try(GetTime)) or 0 end

function DT.stamp()
  return (try(date, "%Y-%m-%d %H:%M:%S")) or tostring((try(time)) or "?")
end

function DT.build()
  local v, b = try(GetBuildInfo)
  return tostring(v or "?") .. "-" .. tostring(b or "?")
end

-- nil until the client can name the character (UnitName answers "Unknown" at ADDON_LOADED on
-- a cold login).
function DT.charKey()
  local name, realm = clean(try(UnitName, "player")), clean(try(GetRealmName))
  if type(name) ~= "string" or name == "" or name == "Unknown"
     or (UNKNOWNOBJECT and name == UNKNOWNOBJECT) then return nil end
  if type(realm) ~= "string" or realm == "" then return nil end
  return realm .. "-" .. name
end

function DT.after(d, fn)
  if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(d, fn) return true end
  return false
end

function DT.out(m)
  local s = "|cff7fa650Dead Tired|r " .. tostring(m)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(s) else print(s) end
end

-- Text that came from another player's client, made safe to print: no UI escapes (|), no
-- control bytes, bounded length. Inbound data is printed, never interpreted.
function DT.safe(s, max)
  s = tostring(s or ""):gsub("[%z\1-\31]", ""):gsub("|", "||")
  max = max or 64
  if #s > max then s = s:sub(1, max) .. "..." end
  return s
end

-- "Realm-Name" -> "Name". Character names never contain "-", realms may.
function DT.nameOf(key)
  return type(key) == "string" and (key:match("%-([^%-]+)$") or key) or "?"
end

-- ---------------------------------------------------------------- the store

-- One SavedVariables table, account-wide. Created and filled with defaults on first use.
function DT.db()
  if type(DeadTiredDB) ~= "table" then DeadTiredDB = {} end
  local db = DeadTiredDB
  if type(db.errors) ~= "table" then db.errors = {} end
  if type(db.comms) ~= "table" then db.comms = {} end
  for _, k in ipairs({ "dropped", "unknownVersion", "malformed", "stale" }) do
    if type(db.comms[k]) ~= "number" then db.comms[k] = 0 end
  end
  if type(db.roster) ~= "table" then db.roster = {} end
  if type(db.account) ~= "table" then db.account = {} end
  if db.welcome == nil then db.welcome = true end
  return db
end

-- ---------------------------------------------------------------- modules

-- def = { id, events = { EVENT = fn }, init = fn, ready = fn -> store or nil,
--         errorKey = "comms", lastKey = "lastComms", slash = { verb = fn } }
-- init runs at this addon's ADDON_LOADED; events are then registered under pcall (an event the
-- client lacks is skipped). A handler runs only when ready() answers; a failure is counted in
-- the store under errorKey, its text kept under lastKey, and re-raised. With no errorKey the
-- failure is swallowed. Returns the module's frame.
DT.modules = {}
function DT.module(def)
  local f = CreateFrame("Frame")
  def.frame = f
  DT.modules[#DT.modules + 1] = def
  f:RegisterEvent("ADDON_LOADED")
  f:SetScript("OnEvent", function(_, ev, ...)
    if ev == "ADDON_LOADED" then
      if ... ~= ADDON or def.loaded then return end
      def.loaded = true
      if def.init then def.init() end
      for name in pairs(def.events or {}) do pcall(f.RegisterEvent, f, name) end
      f:UnregisterEvent("ADDON_LOADED")
      return
    end
    local h = def.events and def.events[ev]
    if not h then return end
    local store = def.ready and def.ready() or (not def.ready and true) or nil
    if not store then return end
    if not def.errorKey then pcall(h, ...) return end
    local ok, err = pcall(h, ...)
    if not ok then
      if type(store) == "table" then
        store[def.errorKey] = (store[def.errorKey] or 0) + 1
        store[def.lastKey or ("last" .. def.errorKey)] = ev .. ": " .. tostring(err)
      end
      error(err, 0)
    end
  end)
  if def.slash then for prefix, fn in pairs(def.slash) do DT.verb(prefix, fn) end end
  return f
end

-- The usual store for a module: the errors table of DeadTiredDB.
function DT.errors() return DT.db().errors end

-- ---------------------------------------------------------------- tiny internal signals

-- Modules tell each other about state changes (membership, main) without naming each other.
DT.listeners = {}
function DT.listen(name, fn)
  DT.listeners[name] = DT.listeners[name] or {}
  table.insert(DT.listeners[name], fn)
end
function DT.signal(name, ...)
  for _, fn in ipairs(DT.listeners[name] or {}) do fn(...) end
end

-- ---------------------------------------------------------------- the slash router

-- Verbs are prefixes; the longest matching prefix wins. The message is lower-cased and trimmed;
-- DT.raw keeps the untouched text for a verb that needs case (names).
DT.verbs = {}
function DT.verb(prefix, fn, usage)
  for _, v in ipairs(DT.verbs) do
    if v.prefix == prefix then v.fn = fn v.usage = usage or v.usage return end
  end
  DT.verbs[#DT.verbs + 1] = { prefix = prefix, fn = fn, usage = usage }
end

function DT.help()
  local names = {}
  for _, v in ipairs(DT.verbs) do names[#names + 1] = v.usage or v.prefix end
  table.sort(names)
  DT.out(DT.VERSION .. ", still twitching. /dt " .. table.concat(names, " | "))
end

function DT.dispatch(msg)
  DT.raw = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  msg = DT.raw:lower()
  -- Does nothing outside the guild: one line when asked, nothing otherwise.
  if DT.isMember and not DT.isMember() then
    return DT.out("only stirs inside <" .. tostring(DT.Config.GUILD_NAME) .. ">.")
  end
  if msg == "" then return DT.help() end
  local best
  for _, v in ipairs(DT.verbs) do
    if (msg == v.prefix or msg:sub(1, #v.prefix + 1) == v.prefix .. " ")
       and (not best or #v.prefix > #best.prefix) then best = v end
  end
  if best then return best.fn(msg) end
  return DT.help()
end

SLASH_DEADTIRED1 = "/dt"
SLASH_DEADTIRED2 = "/deadtired"
SlashCmdList = SlashCmdList or {}
SlashCmdList["DEADTIRED"] = function(msg) return DT.dispatch(msg) end
