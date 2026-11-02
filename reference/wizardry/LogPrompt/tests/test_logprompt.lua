-- Stub-driven checks for LogPrompt.lua.  lua5.1 addons/WizardryLogPrompt/tests/test_logprompt.lua
--
-- The stubs model only API *shape*: C_ChatInfo.IsLoggingCombat/IsLoggingChat exist on
-- 69977 (WizardryProbe sweep). Whether /combatlog runs from a SecureActionButton's macro
-- text on this client is NOT modelled -- that is unobserved, and 0012 forbids a stub for
-- it. It is the UAT's first check.

local here = (arg and arg[0] or ""):match("^(.*)[/\\]tests[/\\]") or "."
local fails, passes = 0, 0
local function check(name, cond)
  if cond then passes = passes + 1 else fails = fails + 1; print("FAIL " .. name) end
end

-- ---- stubs
local S = { combat = false, chat = false, lockdown = false, keydown = true, printed = {} }
C_ChatInfo = { IsLoggingCombat = function() return S.combat end,
               IsLoggingChat   = function() return S.chat end }
function InCombatLockdown() return S.lockdown end
function GetCVarBool(n) if n == "ActionButtonUseKeyDown" then return S.keydown end end
C_Timer = { After = function(_, fn) fn() end }
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(S.printed, m) end }
SlashCmdList = {}
UIParent = {}

local frames = {}
local function newFrame(name)
  local f = { name = name, attrs = {}, scripts = {}, shown = false, enabled = true, events = {} }
  function f:SetSize() end
  function f:SetPoint() end
  function f:SetFrameStrata() end
  function f:SetBackdrop() end
  function f:SetText(t) self.text = t end
  function f:CreateFontString() return newFrame() end
  function f:RegisterForClicks(...) self.clicks = { ... } end
  function f:SetAttribute(k, v) if S.lockdown then error("attribute in combat") end self.attrs[k] = v end
  function f:SetScript(k, fn) self.scripts[k] = fn end
  function f:RegisterEvent(e) self.events[e] = true end
  function f:Show() self.shown = true end
  function f:Hide() if S.lockdown and self.name == "WizardryLogPromptFrame" then error("hide in combat") end self.shown = false end
  function f:Enable() self.enabled = true end
  function f:Disable() self.enabled = false end
  if name then frames[name] = f end
  return f
end
function CreateFrame(_, name) return newFrame(name) end

-- LogPrompt creates its event frame unnamed at load, so capture every frame made.
local chunk = assert(loadfile(here .. "/LogPrompt.lua"))
local NS, evFrame
local captured = {}
CreateFrame = function(_, name) local f = newFrame(name); table.insert(captured, f); return f end
chunk("WizardryLogPrompt"); NS = WizardryLogPrompt_NS
for _, f in ipairs(captured) do if f.events.PLAYER_ENTERING_WORLD then evFrame = f end end
local function event(e, ...) evFrame.scripts.OnEvent(evFrame, e, ...) end
local function btn(k) return frames["WizardryLogPromptButton_" .. k] end
local function dlg() return frames["WizardryLogPromptFrame"] end
local function click(k)  -- a full press: down then up, as the client delivers both
  local b = btn(k)
  if b.enabled == false then return end
  b.scripts.PostClick(b, "LeftButton", true)
  if dlg().shown or not S.keydown then b.scripts.PostClick(b, "LeftButton", false) end
end

-- ---- plan
local p = NS.plan(false, false)
check("plan both off", p.combat == "/combatlog" and p.chat == "/chatlog" and p.both == "/combatlog\n/chatlog")
p = NS.plan(true, false)
check("plan combat on: never toggles it off", p.combat == nil and p.chat == "/chatlog" and p.both == nil)
p = NS.plan(false, true)
check("plan chat on", p.combat == "/combatlog" and p.chat == nil and p.both == nil)
p = NS.plan(nil, nil)
check("plan unknown treated as off", p.both == "/combatlog\n/chatlog")

-- ---- login, both off: shown, all armed
event("PLAYER_ENTERING_WORLD", true, false)
check("shown at login", dlg().shown)
check("combat armed", btn("Combat").attrs.type == "macro" and btn("Combat").attrs.macrotext == "/combatlog")
check("both armed", btn("Both").attrs.macrotext == "/combatlog\n/chatlog")
check("neither runs nothing", btn("Neither").attrs.type == nil)
check("buttons take down and up", btn("Both").clicks[1] == "AnyUp" and btn("Both").clicks[2] == "AnyDown")

-- ---- click Both with key-down on: acts once, hides, reports
S.printed = {}
S.combat, S.chat = true, true     -- what the macro would do; unobserved, so set by hand
click("Both")
check("hidden after Both", not dlg().shown)
check("one report line", #S.printed == 1 and S.printed[1]:find("Both") ~= nil)

-- ---- key-down OFF: the down half must not hide before the up half runs the macro
S.combat, S.chat, S.keydown = false, false, false
NS.show(true)
local b = btn("Chat")
b.scripts.PostClick(b, "LeftButton", true)
check("down half ignored when keydown is off", dlg().shown)
b.scripts.PostClick(b, "LeftButton", false)
check("up half finishes", not dlg().shown)
S.keydown = true

-- ---- zone change: not shown
dlg():Hide()
event("PLAYER_ENTERING_WORLD", false, false)
check("no prompt on a loading screen", not dlg().shown)

-- ---- reload with both on: skipped; with one off: shown with only that one armed
S.combat, S.chat = true, true
event("PLAYER_ENTERING_WORLD", false, true)
check("skipped when both on", not dlg().shown)
S.chat = false
event("PLAYER_ENTERING_WORLD", false, true)
check("shown on reload when one is off", dlg().shown)
check("combat disabled when on", btn("Combat").enabled == false and btn("Combat").attrs.macrotext == nil)
check("both disabled when one is on", btn("Both").enabled == false)
check("chat armed", btn("Chat").enabled and btn("Chat").attrs.macrotext == "/chatlog")

-- ---- Neither
S.printed = {}
click("Neither")
check("neither closes", not dlg().shown)
check("neither says so", S.printed[1] and S.printed[1]:find("no logs changed") ~= nil)

-- ---- combat at login: deferred, then shown on REGEN_ENABLED
S.combat, S.chat, S.lockdown = false, false, true
local r = NS.show(false)
check("deferred in combat, no attribute touched", r == "deferred" and not dlg().shown)
S.lockdown = false
event("PLAYER_REGEN_ENABLED")
check("shown when combat ends", dlg().shown)

-- ---- a click whose finish lands in combat: hide deferred, not an error
S.lockdown = true
local ok = pcall(function() btn("Combat").scripts.PostClick(btn("Combat"), "LeftButton", true) end)
check("no hide attempted in combat", ok and dlg().shown)
S.lockdown = false
event("PLAYER_REGEN_ENABLED")
check("hidden after combat", not dlg().shown)

-- ---- /logprompt forces it open even with both on
S.combat, S.chat = true, true
SlashCmdList.WIZARDRYLOGPROMPT("")
check("slash forces open", dlg().shown)

-- ---- no reader at all: '?' and treated as off
C_ChatInfo = nil
local c, h = NS.state()
check("unknown state is nil", c == nil and h == nil)

print(string.format("%d passed, %d failed", passes, fails))
os.exit(fails == 0 and 0 or 1)
