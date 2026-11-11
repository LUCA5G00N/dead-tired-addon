-- Dead Tired: the core. Loaded after the libraries and Config.lua; every other file uses it.
--
-- WHAT IT HOLDS: the guarded-read helpers (bodies copied from Tim's Wizardry Forever core, as rc3
-- did), the store (DeadTiredDB, schema 3), out(), the module core (DT.module), the settings
-- registry (declare, read, validate, write; the /dt set|get verbs live in Settings.lua), the one
-- slash router (/dt and /deadtired), internal signals and addon detection. No game logic.
--
-- RULES (CLAUDE.md):
--   * Every read of game state goes through try / clean / secret.
--   * A module keeps its own frame and its own error key; a handler failure is counted in
--     DeadTiredDB.errors and re-raised.
--   * The router sets only SLASH_DEADTIRED1, SLASH_DEADTIRED2 and SlashCmdList["DEADTIRED"]. It never
--     assigns SlashCmdList itself, or any other Blizzard global (rc3's Core.lua:305 did; it tainted
--     every slash command Blizzard ran afterwards). tests/test_taint.lua enforces it.

local ADDON, ns = ...
ns = ns or {}
local DT = {}
ns.DT = DT
DT.ADDON = ADDON
DT.VERSION = "0.3.0"
DT.SCHEMA = 3
DT.Config = ns.Config or {}

-- ---------------------------------------------------------------- guarded reads (Wizardry Core.lua)

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
function DT.epoch() return (try(time)) or 0 end

function DT.stamp()
  return (try(date, "%Y-%m-%d %H:%M:%S")) or tostring((try(time)) or "?")
end

function DT.after(d, fn)
  if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(d, fn) return true end
  return false
end

function DT.trim(s)
  if type(s) ~= "string" then return nil end
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Text from another player's client (or any game string), made safe to print: no UI escapes (|),
-- no control bytes, bounded length. Inbound data is printed, never interpreted (rc3).
function DT.safe(s, max)
  s = tostring(s == nil and "" or s):gsub("[%z\1-\31]", ""):gsub("|", "||")
  max = max or 64
  if #s > max then s = s:sub(1, max) .. "..." end
  return s
end

-- ---------------------------------------------------------------- the store

-- One SavedVariables table, account-wide, schema 3. An older DeadTiredDB (rc3 and before carry no
-- schema field) is moved, untouched, under DeadTiredDB.legacy for the port round; the old-records
-- line is said once (Guild.lua) when DeadTiredDB.legacySaid is still false.
local function fill(db)
  if type(db.errors) ~= "table" then db.errors = {} end
  if type(db.settings) ~= "table" then db.settings = {} end
  if type(db.frames) ~= "table" then db.frames = {} end
  if type(db.comms) ~= "table" then db.comms = {} end
  for _, k in ipairs({ "sent", "received", "malformed", "unknownVersion", "keyMismatch", "sendRefused",
                       "refusedDropped", "dropped", "held" }) do
    if type(db.comms[k]) ~= "number" then db.comms[k] = 0 end
  end
  if type(db.comms.senders) ~= "table" then db.comms.senders = {} end
  if type(db.comms.mismatches) ~= "table" then db.comms.mismatches = {} end
end

function DT.db()
  local db = DeadTiredDB
  if type(db) ~= "table" then
    db = { schema = DT.SCHEMA }
    DeadTiredDB = db
  elseif db.schema == nil or (type(db.schema) == "number" and db.schema < DT.SCHEMA) then
    if next(db) ~= nil then                                               -- guard: legacy move
      db = { schema = DT.SCHEMA, legacy = db, legacySaid = false }
    else
      db = { schema = DT.SCHEMA }
    end
    DeadTiredDB = db
  end
  fill(db)
  return db
end

-- ---------------------------------------------------------------- out

-- Every line DT prints goes through here. Outside the guild DT says nothing: DT.out prints only
-- while DT.isMember() (Guild.lua) answers true.
function DT.out(m)
  if not (DT.isMember and DT.isMember()) then return false end             -- guard: guild gate (out)
  local s = "|cff7fa650Dead Tired|r " .. tostring(m)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(s) else print(s) end
  return true
end

-- ---------------------------------------------------------------- signals

-- Modules tell each other about state changes without naming each other (rc3).
DT.listeners = {}
function DT.listen(name, fn)
  DT.listeners[name] = DT.listeners[name] or {}
  table.insert(DT.listeners[name], fn)
end
function DT.signal(name, ...)
  for _, fn in ipairs(DT.listeners[name] or {}) do fn(...) end
end

-- ---------------------------------------------------------------- addon detection

-- DT.addonLoaded(name): true only when the client says that addon is loaded. C_AddOns.IsAddOnLoaded
-- (SPEC_forever_namespaces.md, C_AddOns), else the old global, both guarded.
function DT.addonLoaded(name)
  if type(name) ~= "string" or name == "" then return false end
  local f = C_AddOns and C_AddOns.IsAddOnLoaded
  if type(f) ~= "function" then f = IsAddOnLoaded end
  return (try(f, name)) == true
end

-- ---------------------------------------------------------------- errors

function DT.fail(id, where, err)
  local e = DT.db().errors
  e[id] = (e[id] or 0) + 1
  e[id .. ":last"] = tostring(where) .. ": " .. DT.safe(err, 200)
end

-- ---------------------------------------------------------------- settings registry

-- A setting: { key, label, desc, type, default, choices, min, max, maxLen, noVerb, onChange, verb,
--              validate }
--   type: "bool" | "number" | "choice" | "string" | "position" | "list"
--   validate (optional, Port 1): fn(value) -> true, value | false, reason, run after the type's own
--     parse (e.g. a bedtime "HH:MM").
--   "list" (Port 1): a list the settings card draws as rows (the bar's objects, the raid-prep list):
--     items = fn() -> { { name, label, on, tip } ... }; toggle = fn(name, on) (a tick box per row);
--     move = fn(name, n) (a drag grip per row); remove = fn(name) (a remove button per row);
--     empty = the line shown when there are no rows. A list is never /dt set: its own verbs are its
--     typed path, named in noVerb.
-- Every setting can be typed with /dt set <module> <key> <value>, except a "position" (or one
-- declared typed = false). One that can't be typed must carry noVerb = "<reason>", which names the
-- one place it lives (FEATURES.md, General requirements). DT.module refuses one without it.
DT.settings = {}     -- [moduleId] = { list = { setting... }, by = { [key] = setting } }

function DT.typed(s) return s.type ~= "position" and s.type ~= "list" and s.typed ~= false end

local TYPES = { bool = true, number = true, choice = true, string = true, position = true, list = true }

local function declare(id, s)
  if type(s) ~= "table" or type(s.key) ~= "string" or not s.key:match("^[%a][%w]*$") then
    error("DT.module " .. id .. ": a setting needs a key of letters and digits", 3)
  end
  if not TYPES[s.type] then error("DT.module " .. id .. "." .. s.key .. ": unknown type " .. tostring(s.type), 3) end
  if type(s.label) ~= "string" or type(s.desc) ~= "string" then
    error("DT.module " .. id .. "." .. s.key .. ": a setting needs a label and a desc in plain words", 3)
  end
  if not DT.typed(s) and not (type(s.noVerb) == "string" and s.noVerb:match("%S")) then    -- guard: verb or noVerb
    error("DT.module " .. id .. "." .. s.key .. ": no /dt set path and no noVerb reason", 3)
  end
  if s.type == "choice" and (type(s.choices) ~= "table" or #s.choices == 0) then
    error("DT.module " .. id .. "." .. s.key .. ": a choice needs choices", 3)
  end
  local reg = DT.settings[id]
  if not reg then reg = { list = {}, by = {} }; DT.settings[id] = reg end
  if reg.by[s.key] then error("DT.module " .. id .. "." .. s.key .. ": declared twice", 3) end
  s.module = id
  reg.list[#reg.list + 1] = s
  reg.by[s.key] = s
end

function DT.setting(id, key)
  local reg = DT.settings[id]
  return reg and reg.by[key] or nil
end

local function store(id)
  local all = DT.db().settings
  if type(all[id]) ~= "table" then all[id] = {} end
  return all[id]
end

function DT.get(id, key)
  local s = DT.setting(id, key)
  if not s then return nil end
  local v = store(id)[key]
  if v == nil then return s.default end
  return v
end

-- Parse and validate a value for setting s. From typing it is a string; from the settings view
-- it is already typed. Returns true, value | false, reason.
local ON = { on = true, ["true"] = true, yes = true, ["1"] = true }
local OFF = { off = false, ["false"] = false, no = false, ["0"] = false }
local parseType
function DT.parse(s, raw)
  local ok, v = parseType(s, raw)
  if ok and type(s.validate) == "function" then
    local okv, vv = s.validate(v)
    if not okv then return false, vv end
    v = vv
  end
  return ok, v
end
parseType = function(s, raw)
  if s.type == "bool" then
    if type(raw) == "boolean" then return true, raw end
    local w = type(raw) == "string" and raw:lower() or ""
    if ON[w] then return true, true end
    if OFF[w] ~= nil then return true, false end
    return false, "expects on or off"
  elseif s.type == "number" then
    local n = tonumber(raw)
    local lo, hi = s.min or -math.huge, s.max or math.huge
    if not n or n ~= n or n < lo or n > hi then
      if s.min and s.max then return false, "expects a number from " .. s.min .. " to " .. s.max end
      return false, "expects a number"
    end
    return true, n
  elseif s.type == "choice" then
    local w = type(raw) == "string" and raw:lower() or ""
    for _, c in ipairs(s.choices) do if c == w then return true, c end end
    return false, "expects one of: " .. table.concat(s.choices, ", ")
  elseif s.type == "string" then
    if type(raw) ~= "string" then return false, "expects text" end
    local t = DT.trim(raw):gsub("[%z\1-\31|]", "")
    if #t > (s.maxLen or 64) then return false, "expects at most " .. (s.maxLen or 64) .. " characters" end
    return true, t
  elseif s.type == "position" or s.type == "list" then
    if type(raw) ~= "table" then return false, "can't be typed: " .. tostring(s.noVerb) end
    return true, raw
  end
  return false, "unknown type"
end

-- DT.set(id, key, raw, fromTyping): returns true, value | false, reason. Saved at once in
-- DeadTiredDB.settings[id][key]; onChange runs; the "setting" signal tells the views.
function DT.set(id, key, raw, fromTyping)
  if not DT.settings[id] then return false, "no module called " .. DT.safe(id, 24) end
  local s = DT.setting(id, key)
  if not s then return false, "no setting " .. DT.safe(id, 24) .. "." .. DT.safe(key, 24) end
  if fromTyping and not DT.typed(s) then return false, "can't be typed: " .. s.noVerb end
  local ok, v = DT.parse(s, raw)
  if not ok then return false, v end
  store(id)[key] = v
  if s.onChange then
    local okc, err = pcall(s.onChange, v)
    if not okc then DT.fail(id, "setting " .. key, err) end
  end
  DT.signal("setting", id, key, v)
  return true, v
end

function DT.format(s, v)
  if s.type == "bool" then return v and "on" or "off" end
  if s.type == "position" then return "(placed by dragging)" end
  if s.type == "list" then return "(a list: " .. tostring(s.noVerb) .. ")" end
  return tostring(v)
end

-- ---------------------------------------------------------------- the module core

-- DT.module{ id, title, desc, optional, settings, verbs, events, init, onEnable, onDisable, ldb }
--   optional = true: the module gets its own switch, setting "enabled" (default on, saved), and
--   registers no events while it is off. Its own frame receives its events; a handler failure is
--   counted under errors[id] (text under errors[id .. ":last"]) and re-raised. init runs at
--   DT's ADDON_LOADED under pcall, counted the same way, and the other modules still load.
--   verbs: { { verb = "who", usage = "who", fn = function(args) end }, ... }
--   ldb: one launcher/data object for the bar (Bar.lua), { text, icon, OnClick, OnTooltipShow }.
DT.modules, DT.byId = {}, {}

function DT.enabled(id)
  local m = DT.byId[id]
  if not m then return false end
  if not m.optional then return true end
  return DT.get(id, "enabled") ~= false
end

local function register(m)
  for ev in pairs(m.events or {}) do pcall(m.frame.RegisterEvent, m.frame, ev) end
end
local function unregister(m)
  for ev in pairs(m.events or {}) do pcall(m.frame.UnregisterEvent, m.frame, ev) end
end

-- Switch a module's events to match its saved switch.
function DT.apply(id)
  local m = DT.byId[id]
  if not m or not m.loaded then return end
  local on = DT.enabled(id)
  if on == m.active then return end
  m.active = on
  if on then                                                               -- guard: disabled registers nothing
    register(m)
    if m.onEnable then local ok, err = pcall(m.onEnable) if not ok then DT.fail(id, "enable", err) end end
  else
    unregister(m)
    if m.onDisable then local ok, err = pcall(m.onDisable) if not ok then DT.fail(id, "disable", err) end end
  end
end

function DT.module(def)
  assert(type(def) == "table" and type(def.id) == "string" and def.id:match("^[%l][%w]*$"), "DT.module: id")
  assert(not DT.byId[def.id], "DT.module: " .. def.id .. " registered twice")
  def.title = def.title or def.id
  if def.optional then
    declare(def.id, { key = "enabled", type = "bool", default = true, label = "On",
      desc = def.switchDesc or ("Switches " .. def.title .. " on or off. Off, it listens to nothing."),
      onChange = function() DT.apply(def.id) end })
  end
  for _, s in ipairs(def.settings or {}) do declare(def.id, s) end
  local f = CreateFrame("Frame")
  def.frame = f
  f:SetScript("OnEvent", function(_, ev, ...)
    local h = def.events and def.events[ev]
    if not h then return end
    local ok, err = pcall(h, ...)
    if not ok then
      DT.fail(def.id, ev, err)                                              -- guard: handler error count
      error(err, 0)
    end
  end)
  DT.modules[#DT.modules + 1] = def
  DT.byId[def.id] = def
  for _, v in ipairs(def.verbs or {}) do
    v.module = def.id
    DT.verb(v)
  end
  return def
end

-- DT's own loader: at this addon's ADDON_LOADED the store is made, then every module's init runs in
-- order and its events are registered if it is switched on. One failing init doesn't stop the rest;
-- the first failure is re-raised once all have loaded.
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, ev, name)
  if ev ~= "ADDON_LOADED" or name ~= ADDON or DT.loaded then return end
  DT.loaded = true
  loader:UnregisterEvent("ADDON_LOADED")
  DT.db()
  local first
  for _, m in ipairs(DT.modules) do
    m.loaded = true
    if m.init then
      local ok, err = pcall(m.init)
      if not ok then DT.fail(m.id, "init", err); first = first or err end
    end
    m.active = nil
    DT.apply(m.id)
  end
  DT.signal("loaded")
  if first then error(first, 0) end
end)

-- ---------------------------------------------------------------- the slash router

-- Verbs are word prefixes ("debug names"); the longest matching one wins. The message is trimmed
-- and lower-cased for matching; DT.raw keeps the untouched text for a verb that needs case.
DT.verbs = {}
function DT.verb(v)
  assert(type(v) == "table" and type(v.verb) == "string" and type(v.fn) == "function", "DT.verb")
  for i, old in ipairs(DT.verbs) do
    if old.verb == v.verb then DT.verbs[i] = v return end
  end
  DT.verbs[#DT.verbs + 1] = v
end

function DT.helpLine()
  local names = {}
  for _, v in ipairs(DT.verbs) do names[#names + 1] = v.usage or v.verb end
  table.sort(names)
  return "Dead Tired " .. DT.VERSION .. ": /dt " .. table.concat(names, " | ")
end

function DT.help() return DT.out(DT.helpLine()) end

-- DT.inCommand is true while a typed /dt verb runs: Comms says "held" only to a player who asked
-- for something, never for a send the addon makes by itself (rc3, fix round 3).
local function run(v, args)
  DT.inCommand = true
  local ok, err = pcall(v.fn, args)
  DT.inCommand = false
  if not ok then
    DT.fail(v.module or "router", "/dt " .. v.verb, err)
    error(err, 0)
  end
end

function DT.dispatch(msg)
  if not (DT.isMember and DT.isMember()) then return end                   -- outside the guild: nothing
  DT.raw = DT.trim(type(msg) == "string" and msg or "") or ""
  local low = DT.raw:lower():gsub("%s+", " ")
  if low == "" or low == "help" then return DT.help() end
  local best
  for _, v in ipairs(DT.verbs) do
    if (low == v.verb or low:sub(1, #v.verb + 1) == v.verb .. " ") and (not best or #v.verb > #best.verb) then
      best = v
    end
  end
  if not best then return DT.help() end
  -- args keep their case: the raw text after the verb's words
  local words = select(2, best.verb:gsub("%S+", ""))
  local args = DT.raw
  for _ = 1, words do args = args:gsub("^%s*%S+", "", 1) end
  return run(best, DT.trim(args) or "")
end

SLASH_DEADTIRED1 = "/dt"
SLASH_DEADTIRED2 = "/deadtired"
if type(SlashCmdList) == "table" then
  SlashCmdList["DEADTIRED"] = function(msg) DT.dispatch(msg) end
end
