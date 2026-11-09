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

-- Fix round 3 (AUD-06): one realm spelling for every character key, "NormalisedRealm-Name".
-- DT.realmKey(realm): the realm with spaces and hyphens removed ("Argent Dawn" -> "ArgentDawn",
-- as CHAT_MSG_ADDON spells it). With no realm, the player's own: GetNormalizedRealmName when it
-- answers a non-empty string, else GetRealmName, normalised the same way. nil when unknown.
function DT.realmKey(realm)
  if realm == nil then
    realm = clean(try(GetNormalizedRealmName))
    if type(realm) ~= "string" or realm == "" then realm = clean(try(GetRealmName)) end
  end
  if type(realm) ~= "string" then return nil end
  realm = realm:gsub("[%s%-]", "")                                       -- guard: realmKey normalise (AUD-06)
  if realm == "" then return nil end
  return realm
end

-- DT.keyOf(name, realm): the character key; realm nil means the player's own realm.
function DT.keyOf(name, realm)
  if type(name) ~= "string" or name == "" then return nil end
  local r = DT.realmKey(realm)
  if not r then return nil end
  return r .. "-" .. name
end

-- A stored "Realm-Name" key in the one spelling; anything that isn't a key comes back as it was.
function DT.normKey(key)
  if type(key) ~= "string" then return key end
  local name = key:match("%-([^%-]+)$")
  if not name then return key end
  return DT.keyOf(name, key:sub(1, #key - #name - 1)) or key
end

-- nil until the client can name the character (UnitName answers "Unknown" at ADDON_LOADED on
-- a cold login).
function DT.charKey()
  local name = clean(try(UnitName, "player"))
  if type(name) ~= "string" or name == "" or name == "Unknown"
     or (UNKNOWNOBJECT and name == UNKNOWNOBJECT) then return nil end
  return DT.keyOf(name)
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

-- "Realm-Name" -> "Name". Character names never contain "-"; a realm in an old key may.
function DT.nameOf(key)
  return type(key) == "string" and (key:match("%-([^%-]+)$") or key) or "?"
end

-- ---------------------------------------------------------------- the store

-- Fix round 3 (AUD-06): rewrite a stored table's character keys to the one spelling.
-- tbl's string keys that are character keys are rewritten; so is each named field (`fields`, a
-- list) of every entry that is a table. Where two old keys collapse into one, the entry with the
-- newer `stamp` field (default "seen"; stamps compare as strings or numbers) is kept; on a tie,
-- or with no stamp, the entry already under the new key (else the first old key, sorted) stays.
-- Safe to run again: a key already in the one spelling is left alone. Returns rewritten, merged.
local function newer(a, b, stamp)
  local sa = type(a) == "table" and a[stamp] or nil
  local sb = type(b) == "table" and b[stamp] or nil
  if sa == nil then return false end
  if sb == nil then return true end
  if type(sa) ~= type(sb) or (type(sa) ~= "string" and type(sa) ~= "number") then return false end
  return sa > sb
end

function DT.migrateKeys(tbl, fields, stamp)
  if type(tbl) ~= "table" then return 0, 0 end
  stamp = stamp or "seen"
  local n, merged = 0, 0
  for _, e in pairs(tbl) do
    if type(e) == "table" then
      for _, f in ipairs(fields or {}) do
        local v = DT.normKey(e[f])
        if v ~= e[f] then e[f] = v; n = n + 1 end
      end
    end
  end
  local moves = {}
  for k in pairs(tbl) do
    if type(k) == "string" and DT.normKey(k) ~= k then moves[#moves + 1] = k end
  end
  table.sort(moves)
  for _, k in ipairs(moves) do
    local nk, e = DT.normKey(k), tbl[k]
    tbl[k] = nil
    n = n + 1
    if tbl[nk] == nil then tbl[nk] = e
    else
      merged = merged + 1
      if newer(e, tbl[nk], stamp) then tbl[nk] = e end
    end
  end
  return n, merged
end

-- Once per account (DeadTiredDB.keysV = 2): the roster and the alt registry (every roster key,
-- every entry's main, the account's main) move to the one spelling.
local function migrate(db)
  if db.keysV == 2 then return end                                      -- guard: migration runs once (AUD-06)
  for _, g in pairs(db.roster) do DT.migrateKeys(g, { "main" }) end
  db.account.main = DT.normKey(db.account.main)
  db.keysV = 2
end

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
  migrate(db)
  return db
end

-- ---------------------------------------------------------------- modules

-- def = { id, events = { EVENT = fn }, init = fn, ready = fn -> store or nil,
--         errorKey = "comms", lastKey = "lastComms", slash = { verb = fn } }
-- init runs at this addon's ADDON_LOADED, under pcall (fix round 1, F4: a failure is counted
-- under errorKey like a handler's, the events are still registered, then the error is
-- re-raised); events are registered under pcall (an event the client lacks is skipped). A handler runs only when ready() answers; a failure is counted in
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
      -- Fix round 1 (F4): a failing init is recorded like a handler failure, and the module's
      -- events are registered anyway; then the error is re-raised.
      local okInit, initErr = true, nil
      if def.init then okInit, initErr = pcall(def.init) end                -- guard: init pcall (F4)
      for name in pairs(def.events or {}) do pcall(f.RegisterEvent, f, name) end
      f:UnregisterEvent("ADDON_LOADED")
      if not okInit then
        local store = def.ready and def.ready()
        if def.errorKey and type(store) == "table" then
          store[def.errorKey] = (store[def.errorKey] or 0) + 1
          store[def.lastKey or ("last" .. def.errorKey)] = "init: " .. tostring(initErr)
        end
        if def.errorKey then error(initErr, 0) end
      end
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

-- DT.inCommand is true while a typed /dt verb runs (fix round 3: Comms says "held" only to a
-- player who asked for something, never for a send the addon makes by itself).
local function run(fn, msg)
  DT.inCommand = true
  local r = { pcall(fn, msg) }
  DT.inCommand = false
  if not r[1] then error(r[2], 0) end
  return unpack(r, 2, table.maxn(r))
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
  if best then return run(best.fn, msg) end
  return DT.help()
end

SLASH_DEADTIRED1 = "/dt"
SLASH_DEADTIRED2 = "/deadtired"
SlashCmdList = SlashCmdList or {}
SlashCmdList["DEADTIRED"] = function(msg) return DT.dispatch(msg) end
