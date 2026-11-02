-- Stub-driven checks for Forever/Core.lua (0.28.0, docs/COWORK_BRIEF_forever_wizardry_core.md).
--   lua5.1 addons/WizardryLedger/tests/test_forever_core.lua     (from the repo root)
--
-- 0012: every stub here is one the other Forever suites already carry, with their captures:
-- GetTime / date / GetBuildInfo / UnitName ("Unknown" on a cold login, 2026-09-25) /
-- GetRealmName / issecretvalue / C_Timer.After / C_Map (GetBestMapForUnit, GetPlayerMapPosition
-- with GetXY, nil position in instances). GetRealZoneText / GetSubZoneText: first sighted
-- 2026-10-08 on 0.27.0 as plain strings ("Thunder Bluff", "Southern Barrens"; subzone "" in town).

local root = (arg and arg[0] or ""):match("^(.*)[/\\]addons[/\\]WizardryLedger[/\\]tests[/\\]") or "."
local addonDir = root .. "/addons/WizardryLedger"
local fails, passes = 0, 0
local function check(name, cond)
  if cond then passes = passes + 1 else fails = fails + 1; print("FAIL " .. name) end
end

-- ---------------------------------------------------------------- stubs
local S = { t = 100, secrets = {}, printed = {}, name = "Hamson", date = true,
  map = 1456, x = 0.48954, y = 0.36811, zone = "Thunder Bluff", sub = "" }
function GetTime() return S.t end
function date(fmt) if not S.date then error("no date") end return "2026-10-08 16:49:55" end
function time() return 1791474595 end
function GetBuildInfo() return "1.60.1", "70245" end
function GetRealmName() return "Classic Beta PvP" end
function UnitName(u) if u == "player" then return S.name end end
function issecretvalue(v) return S.secrets[v] == true end
function GetRealZoneText() return S.zone end
function GetSubZoneText() return S.sub end
C_Timer = { After = function(d, fn) S.timer = { d = d, fn = fn } end }
C_Map = {
  GetBestMapForUnit = function() return S.map end,
  GetPlayerMapPosition = function()
    if S.x == nil then return nil end
    return { GetXY = function() return S.x, S.y end }
  end,
}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(S.printed, m) end }
SlashCmdList = {}
local frames = {}
function CreateFrame()
  local f = { events = {}, scripts = {} }
  function f:RegisterEvent(e) self.events[e] = true end
  function f:UnregisterEvent(e) self.events[e] = nil end
  function f:SetScript(k, fn) self.scripts[k] = fn end
  table.insert(frames, f)
  return f
end
local function fire(ev, ...)
  for _, f in ipairs(frames) do
    if ev == "ADDON_LOADED" or f.events[ev] then f.scripts.OnEvent(f, ev, ...) end
  end
end
local function printed(needle)
  for _, m in ipairs(S.printed) do if m:find(needle, 1, true) then return m end end
end

local ns = {}
assert(loadfile(addonDir .. "/Forever/Core.lua"))("WizardryLedger", ns)
local W = ns.WZ
check("Core exports ns.WZ and creates no frame of its own", type(W) == "table" and #frames == 0)

-- ---------------------------------------------------------------- helpers
check("try returns the call's results", select(2, W.try(function() return 1, 2 end)) == 2)
check("try answers nothing for an absent function or an error",
  W.try(nil) == nil and W.try(function() error("x") end) == nil)
local secretV = {}
S.secrets[secretV] = true
check("try answers nothing for a secret first value", W.try(function() return secretV end) == nil)
check("clean drops secrets and keeps values", W.clean(secretV) == nil and W.clean(5) == 5)
check("now is GetTime", W.now() == 100)
check("stamp is the date", W.stamp() == "2026-10-08 16:49:55")
S.date = false
check("stamp falls back to time() when date fails", W.stamp() == "1791474595")
S.date = true
check("round4", W.round4(0.123456) == 0.1235 and W.round4("x") == nil)
check("build", W.build() == "1.60.1-70245")
check("charKey is Realm-Name", W.charKey() == "Classic Beta PvP-Hamson")
S.name = "Unknown"
check("charKey refuses 'Unknown'", W.charKey() == nil)
S.name = "Hamson"
local w = W.where()
check("where: map and rounded x, y", w.map == 1456 and w.x == 0.4895 and w.y == 0.3681)
local map, x, y, z, s = W.place()
check("place: map, x, y, zone; an empty subzone is nothing", map == 1456 and x == 0.4895 and y == 0.3681
  and z == "Thunder Bluff" and s == nil)
S.x, S.zone, S.sub = nil, 42, "Southern Barrens"
map, x, y, z, s = W.place()
check("place in an instance: map only; a non-string zone is nothing", map == 1456 and x == nil and y == nil
  and z == nil and s == "Southern Barrens")
check("after uses C_Timer", W.after(0.5, function() end) == true and S.timer.d == 0.5)
W.out("hello")
check("out prints with the Ledger prefix", printed("Ledger|r hello") ~= nil)

-- ---------------------------------------------------------------- modules
local store, calls = nil, { init = 0, ev = 0 }
local fA = W.module({
  id = "a", events = { PLAYER_MONEY = function() calls.ev = calls.ev + 1 end,
    BOOM = function() error("kaboom") end },
  init = function() calls.init = calls.init + 1; store = {} end,
  ready = function() return store end,
  errorKey = "aErrors", lastKey = "lastAError",
  slash = { alpha = function(m) S.got = "alpha:" .. m end },
  pane = { id = "a", title = "Alpha", question = "q?", toggle = function() end },
})
check("module returns its own frame", fA == frames[1] and fA.events.ADDON_LOADED)
check("nothing registered before ADDON_LOADED", fA.events.PLAYER_MONEY == nil)
fire("ADDON_LOADED", "SomeOtherAddon")
check("another addon's ADDON_LOADED is ignored", calls.init == 0)
fire("ADDON_LOADED", "WizardryLedger")
check("init runs once, events registered, ADDON_LOADED dropped", calls.init == 1
  and fA.events.PLAYER_MONEY and fA.events.BOOM and not fA.events.ADDON_LOADED)
fire("ADDON_LOADED", "WizardryLedger")
check("a second ADDON_LOADED does not re-init", calls.init == 1)
fire("PLAYER_MONEY")
check("a handler runs when ready", calls.ev == 1)
local ok, err = pcall(fire, "BOOM")
check("a failure is re-raised", not ok and tostring(err):find("kaboom", 1, true) ~= nil)
check("and counted under the module's own key", store.aErrors == 1 and store.lastAError:find("BOOM: ", 1, true) == 1)
store = nil
fire("PLAYER_MONEY")
check("a handler does not run while ready answers nothing", calls.ev == 1)

local silent = 0
local fB = W.module({ id = "b", events = { BOOM = function() silent = silent + 1; error("quiet") end } })
fire("ADDON_LOADED", "WizardryLedger")
check("with no errorKey a failure is swallowed, as the views did", pcall(fire, "BOOM") and silent == 1)
check("a module with no ready always runs", fB.events.BOOM == true)

-- ---------------------------------------------------------------- panes
check("a module's pane is appended to ns.WZpanes", ns.WZpanes and ns.WZpanes[1] and ns.WZpanes[1].id == "a")

-- ---------------------------------------------------------------- the router
W.verb("prof", function(m) S.got = "prof:" .. m end)
W.verb("prune", function(m) S.got = "prune:" .. m end)
W.default = function(m) S.got = "default:" .. m end
SlashCmdList.WIZARDRYLEDGERFOREVER("  Prof First Aid ")
check("a verb is a prefix, the message lower-cased and trimmed", S.got == "prof:prof first aid")
SlashCmdList.WIZARDRYLEDGERFOREVER("prune confirm")
check("prune is not taken by prof", S.got == "prune:prune confirm")
SlashCmdList.WIZARDRYLEDGERFOREVER("alpha")
check("a module's slash table registers its verbs", S.got == "alpha:alpha")
SlashCmdList.WIZARDRYLEDGERFOREVER("")
check("/ledger with nothing goes to the default (quest counts, as before)", S.got == "default:")
SlashCmdList.WIZARDRYLEDGERFOREVER("quests last")
check("quests goes to the default", S.got == "default:quests last")
S.got, S.printed = nil, {}
SlashCmdList.WIZARDRYLEDGERFOREVER("nonsense")
check("an unknown verb prints the help, naming verbs and panes", S.got == nil
  and printed("/wiz") and printed("prof") and printed("Alpha"))
SlashCmdList.WIZARDRYWIZ("prof x")
check("/wiz <verb> reaches the same table", S.got == "prof:prof x")
S.got, S.printed = nil, {}
SlashCmdList.WIZARDRYWIZ("  ")
check("/wiz alone is the help, naming the version", S.got == nil and printed("Wizardry " .. W.VERSION))
check("both commands are declared", SLASH_WIZARDRYLEDGERFOREVER1 == "/ledger" and SLASH_WIZARDRYWIZ1 == "/wiz")
W.verb("prof", function(m) S.got = "prof2" end)
SlashCmdList.WIZARDRYLEDGERFOREVER("prof")
check("registering a verb twice replaces it, keeping its place", S.got == "prof2" and W.verbs[1].prefix == "alpha")

-- ---------------------------------------------------------------- files
local function read(p) local f = io.open(p, "rb"); if not f then return nil end local s = f:read("*a"); f:close(); return s end
local camelot = read(addonDir .. "/WizardryLedger_Camelot.toc") or ""
check("camelot toc: Core.lua first, then Dock.lua (0.31.0), at Core's version", camelot:find("\nForever\\Core.lua\r?\nForever\\Dock.lua\r?\nForever\\Cohorts.lua") ~= nil
  and camelot:find("## Version: " .. W.VERSION, 1, true) ~= nil)
local HELPERS = { "secret", "try", "clean", "now", "stamp", "round4", "build", "buildKey", "charKey",
  "after", "out", "where", "place", "zoneText" }
local strays = {}
for _, f in ipairs({ "Cohorts", "QuestRecorder", "ProfessionRecorder", "LevelRecorder", "LootRecorder",
    "LogRecorder", "TrainerRecorder", "MoneyRecorder", "RepRecorder", "SkillsView", "QuestsView", "Hub", "XPRecorder", "Panes" }) do
  local t = read(addonDir .. "/Forever/" .. f .. ".lua") or ""
  for _, h in ipairs(HELPERS) do
    if t:find("\nlocal function " .. h .. "%(") then strays[#strays + 1] = f .. ":" .. h end
  end
  if t:find("SlashCmdList%[") or t:find("SLASH_") then strays[#strays + 1] = f .. ":slash" end
end
check("no Forever file but Core declares a helper or a slash command (" .. table.concat(strays, ",") .. ")", #strays == 0)

print(string.format("%d passed, %d failed", passes, fails))
os.exit(fails == 0 and 0 or 1)
