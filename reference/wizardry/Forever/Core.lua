-- WizardryLedger, Forever line: the core. Loaded first; every other Forever file uses it.
--
-- WHY. The operator, 2026-10-08: "turn this app from a collection of scripts and ledgers into a
-- cohesive addon (or at least the start of one)". docs/COWORK_BRIEF_forever_wizardry_core.md.
-- On 0.27.0 the same guarded-read helpers were declared in up to eleven files (identical bodies,
-- measured by hash), every file repeated the same ADDON_LOADED / pcall / error-key wiring, and
-- /ledger was an if-chain in QuestRecorder.lua naming ten other files' slash functions.
--
-- WHAT IT HOLDS, and nothing else: the helpers (bodies moved verbatim from the recorders),
-- place(), the module wiring, the slash router (/wiz and /ledger share one verb table) and pane
-- registration (appends to ns.WZpanes, which Hub.lua already reads). No game logic, no store.
--
-- RULES:
--   * A module keeps its own frame (the tests address frames by index) and its own error key.
--   * A handler failure is kept in the module's store AND re-raised, as every recorder did.
--   * The SavedVariables name, the folder and SlashCmdList["WIZARDRYLEDGERFOREVER"] are unchanged.

local ADDON, ns = ...
ns = ns or {}
local W = {}
ns.WZ = W
W.VERSION = "0.38.1"

-- ---------------------------------------------------------------- guarded reads

function W.secret(v)
  return issecretvalue ~= nil and issecretvalue(v) and true or false
end
local secret = W.secret

-- Call fn(...) and return its results, or nothing if it is absent, errors, or answers
-- with a secret first value.
function W.try(fn, ...)
  if type(fn) ~= "function" then return nil end
  local r = { pcall(fn, ...) }
  if not r[1] or secret(r[2]) then return nil end
  return unpack(r, 2, table.maxn(r))
end
local try = W.try

function W.clean(v)
  if v == nil or secret(v) then return nil end
  return v
end
local clean = W.clean

function W.now() return (try(GetTime)) or 0 end

-- QuestRecorder's fallback (time() when date fails) was the only divergent copy; it is kept.
function W.stamp()
  return (try(date, "%Y-%m-%d %H:%M:%S")) or tostring((try(time)) or "?")
end

function W.round4(v)
  if type(v) ~= "number" then return nil end
  return math.floor(v * 10000 + 0.5) / 10000
end

function W.build()
  local v, b = try(GetBuildInfo)
  return tostring(v or "?") .. "-" .. tostring(b or "?")
end

-- nil until the client can name the character (UnitName answers "Unknown" at ADDON_LOADED on
-- a cold login; 2026-09-25).
function W.charKey()
  local name, realm = clean(try(UnitName, "player")), clean(try(GetRealmName))
  if type(name) ~= "string" or name == "" or name == "Unknown"
     or (UNKNOWNOBJECT and name == UNKNOWNOBJECT) then return nil end
  if type(realm) ~= "string" or realm == "" then return nil end
  return realm .. "-" .. name
end

function W.after(d, fn)
  if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(d, fn) return true end
  return false
end

function W.out(m)
  local s = "|cffffcc00Ledger|r " .. tostring(m)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(s) else print(s) end
end

-- Copper as g/s/c, the skills view's format ("2g 05s 33c", "45s", "7c"). 0.30.0: one formatter for
-- the panes, after an 8 Oct results log divided copper by 100 instead of 10,000. A negative amount
-- keeps its sign in front.
function W.money(c)
  c = math.floor(tonumber(c) or 0)
  local sign = c < 0 and "-" or ""
  c = math.abs(c)
  local g, s, cu = math.floor(c / 10000), math.floor((c % 10000) / 100), c % 100
  if g > 0 then return sign .. string.format("%dg %02ds", g, s) .. (cu > 0 and string.format(" %02dc", cu) or "") end
  if s > 0 then return sign .. string.format("%ds", s) .. (cu > 0 and string.format(" %02dc", cu) or "") end
  return sign .. string.format("%dc", cu)
end

-- Where the player is: { map = uiMapID, x = 0..1, y = 0..1 }, or nil (instances often answer
-- no position, which is recorded as nothing).
function W.where()
  if not C_Map then return nil end
  local map = try(C_Map.GetBestMapForUnit, "player")
  if type(map) ~= "number" then return nil end
  local pos = try(C_Map.GetPlayerMapPosition, map, "player")
  local x, y
  if type(pos) == "table" and type(pos.GetXY) == "function" then
    local ok, a, b = pcall(pos.GetXY, pos)
    if ok and not secret(a) then x, y = a, b end
  end
  return { map = map, x = W.round4(x), y = W.round4(y) }
end

-- map, x, y, zone, subzone. Zone texts: first sighted 2026-10-08 (0.27.0 walk) as plain
-- strings; anything else is stored as nothing.
local function zoneText(fn)
  local v = clean(try(fn))
  if type(v) == "string" and v ~= "" then return v end
  return nil
end
function W.place()
  local w = W.where()
  local map, x, y
  if type(w) == "table" then map, x, y = w.map, w.x, w.y end
  return map, x, y, zoneText(GetRealZoneText), zoneText(GetSubZoneText)
end

-- ---------------------------------------------------------------- modules

-- def = { id, events = { EVENT = fn }, init = fn, ready = fn -> store or nil,
--         errorKey = "levelErrors", lastKey = "lastLevelError" }
-- init runs at this addon's ADDON_LOADED; events are then registered under pcall (an event the
-- client lacks is skipped). A handler runs only when ready() answers; a failure is counted in
-- the store under errorKey, its text kept under lastKey, and re-raised. With no errorKey the
-- failure is swallowed, as the views always did. Returns the module's frame.
W.modules = {}
function W.module(def)
  local f = CreateFrame("Frame")
  def.frame = f
  W.modules[#W.modules + 1] = def
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
  if def.slash then for prefix, fn in pairs(def.slash) do W.verb(prefix, fn) end end
  if def.pane then W.pane(def.pane) end
  return f
end

-- ---------------------------------------------------------------- panes

function W.pane(p)
  ns.WZpanes = ns.WZpanes or {}
  table.insert(ns.WZpanes, p)
end

-- ---------------------------------------------------------------- the slash router

-- Verbs are prefixes, matched in registration order (the .toc order), exactly as the 0.27.0
-- if-chain matched them: "prof" also takes "prof first aid", "ups" takes "ups wands".
W.verbs = {}
function W.verb(prefix, fn)
  for _, v in ipairs(W.verbs) do if v.prefix == prefix then v.fn = fn return end end
  W.verbs[#W.verbs + 1] = { prefix = prefix, fn = fn }
end
W.default = nil   -- fn(msg) for what no verb takes: QuestRecorder's quests / quests last

function W.help()
  local names = {}
  for _, v in ipairs(W.verbs) do names[#names + 1] = v.prefix end
  if W.default then names[#names + 1] = "quests" end
  table.sort(names)
  W.out("Wizardry " .. W.VERSION .. ": /wiz " .. table.concat(names, " | "))
  local panes = {}
  for _, p in ipairs(ns.WZpanes or {}) do panes[#panes + 1] = tostring(p.title or p.id) end
  if #panes > 0 then W.out("panes: " .. table.concat(panes, ", ") .. " (minimap book, or /wiz panes)") end
end

function W.dispatch(msg)
  -- 0.37.0: the untouched message, for a verb that must keep case (marks' notes).
  W.raw = msg
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  -- 0.34.2: the longest matching prefix wins, so "professions" is not taken by "prof". Every
  -- earlier verb set had no prefix of another, so for them this is the old first-match.
  local best
  for _, v in ipairs(W.verbs) do
    if msg:find("^" .. v.prefix) and (not best or #v.prefix > #best.prefix) then best = v end
  end
  if best then return best.fn(msg) end
  if W.default and (msg == "" or msg:find("^quests")) then return W.default(msg) end
  return W.help()
end

SLASH_WIZARDRYLEDGERFOREVER1 = "/ledger"
SlashCmdList = SlashCmdList or {}
SlashCmdList["WIZARDRYLEDGERFOREVER"] = function(msg) return W.dispatch(msg) end
-- /wiz with nothing after it is the front door's help; with a verb it is /ledger.
SLASH_WIZARDRYWIZ1 = "/wiz"
SlashCmdList["WIZARDRYWIZ"] = function(msg)
  if (msg or ""):match("^%s*$") then return W.help() end
  return W.dispatch(msg)
end
