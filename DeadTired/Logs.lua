-- Dead Tired: logs. Asks a member entering a dungeon or raid, with the combat log off, whether to
-- switch it on (Warcraft Logs needs it, and the client switches it off at every logout).
-- Card 7, brief docs/COWORK_BRIEF_dt_logs.md, rulings R1-R6.
--
-- COPIED from Tim's beta reminder (reference/wizardry/LogPrompt/LogPrompt.lua): readState,
-- word, plan, finish, clickRan, makeButton, build, arm and the combat deferral, bodies kept
-- where they fit. What changed is listed in docs/COWORK_REPORT_dt_logs.md.
--
-- HOW A LOG IS SWITCHED ON (R4). Every button that switches anything is a secure action button
-- running the client's own slash command (/combatlog, /chatlog) as macro text, so every switch is
-- the player's click. A button is armed only for a log that is OFF, because both commands toggle.
-- This file only ever READS the logging state (the legacy globals are called with no argument),
-- never reads a log file, never reads a combat event, and never switches a log off.
--
-- WHEN IT ASKS:
--   * R1/R3/R5: entering a "party" or "raid" instance, combat log off, asking on (default):
--     one two-button dialog, once per visit. Battlegrounds, arenas and the open world never.
--   * R2: at login or /reload, only after /dt logs login on: the four-button dialog offering
--     both logs. Never on a loading screen.
--   * In combat a dialog waits until combat ends; an instance dialog is dropped if you have left.
--
-- STORED (members only): DeadTiredDB.logs = { ask, login, visit }. ask/login: nil means the
-- default (ask on, login off). visit: the key of the instance visit in progress, so a /reload
-- inside it does not ask again.

local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local L = {}                          -- exposed for tests as DT.logs
DT.logs = L

-- ---------------------------------------------------------------- settings

local function settings()             -- a read; creates nothing
  local l = type(DeadTiredDB) == "table" and DeadTiredDB.logs
  return type(l) == "table" and l or {}
end

local function store()                -- a write; callers are members only
  local db = DT.db()
  if type(db.logs) ~= "table" then db.logs = {} end
  return db.logs
end

function L.asking() return settings().ask ~= false end
function L.loginAsking() return settings().login == true end

-- ---------------------------------------------------------------- state (copied: readState)

local function readState(ciName, legacyName)
  local ci = C_ChatInfo and C_ChatInfo[ciName]
  local v = clean((try(ci)))
  if v == nil then v = clean((try(_G[legacyName]))) end   -- no argument: a read
  if v == nil then return nil end                          -- unknown: no reader answered
  return v and true or false
end

function L.state()
  return readState("IsLoggingCombat", "LoggingCombat"),
         readState("IsLoggingChat", "LoggingChat")
end

local function word(on)
  if on == nil then return "|cffaaaaaa?|r" end
  return on and "|cff40ff40ON|r" or "|cffff4040OFF|r"
end
L.word = word

-- What each choice runs, given the current state. Only logs that are OFF get a command; a log in
-- an unknown state is treated as off (the dialog shows "?" for it).
function L.plan(combatOn, chatOn)
  local c = (combatOn ~= true) and "/combatlog" or nil
  local h = (chatOn ~= true) and "/chatlog" or nil
  local both
  if c and h then both = c .. "\n" .. h end
  return { combat = c, chat = h, both = both }
end

local function inCombat() return (clean((try(InCombatLockdown)))) == true end

-- ---------------------------------------------------------------- where am I

-- Returns the instance type, and a visit key only for a dungeon or raid.
function L.where()
  local _, kind = try(IsInInstance)
  kind = clean(kind)
  if type(kind) ~= "string" then
    local _, k2 = try(GetInstanceInfo)
    kind = clean(k2)
  end
  if type(kind) ~= "string" then kind = "none" end
  if kind ~= "party" and kind ~= "raid" then return kind, nil end
  local id = clean((select(8, try(GetInstanceInfo))))
  if id == nil then id = clean((try(GetRealZoneText))) or clean((try(GetZoneText))) or "?" end
  return kind, kind .. ":" .. tostring(id)
end

-- ---------------------------------------------------------------- dialogs (copied: build et al.)

local dialogs = {}                    -- login, instance
local pendingShow, pendingHide

local function finish(dlg, report)
  if inCombat() then
    pendingHide = true                -- a frame holding secure buttons can't hide in combat
  else
    dlg:Hide()
  end
  if not report then return end
  if not DT.after(0.5, report) then report() end
end

-- A secure button acts on key-down or key-up depending on ActionButtonUseKeyDown, and is
-- registered for both. PostClick fires for both, so act only on the half that ran the macro.
local function clickRan(down)
  local useDown = clean((try(GetCVarBool, "ActionButtonUseKeyDown"))) == true
  return (down and useDown) or (not down and not useDown)
end
L.clickRan = clickRan

local function makeButton(dlg, key, text, x, onRan)
  local b = CreateFrame("Button", "DeadTiredLogsButton_" .. key, dlg,
                        "SecureActionButtonTemplate,UIPanelButtonTemplate")
  b:SetSize(96, 24)
  b:SetPoint("BOTTOMLEFT", dlg, "BOTTOMLEFT", x, 14)
  b:SetText(text)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("type", "macro")
  b:SetScript("PostClick", function(self, _, down)
    if not clickRan(down) then return end
    onRan(self)
  end)
  return b
end

local function frame(name, w, title)
  local dlg = CreateFrame("Frame", name, UIParent,
                          BackdropTemplateMixin and "BackdropTemplate" or nil)
  dlg:SetSize(w, 104)
  dlg:SetPoint("TOP", UIParent, "TOP", 0, -140)
  dlg:SetFrameStrata("DIALOG")
  if dlg.SetBackdrop then
    dlg:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                      tile = true, tileSize = 32, edgeSize = 24,
                      insets = { left = 6, right = 6, top = 6, bottom = 6 } })
  end
  dlg.title = dlg:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  dlg.title:SetPoint("TOP", dlg, "TOP", 0, -14)
  dlg.title:SetText(title)
  dlg.status = dlg:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  dlg.status:SetPoint("TOP", dlg.title, "BOTTOM", 0, -8)
  dlg.buttons = {}
  return dlg
end

local function reportBoth()
  local c, h = L.state()
  DT.out("combat log " .. word(c) .. ", chat log " .. word(h) .. ".")
end

local function reportCombat()
  local c = L.state()
  if c == true then DT.out("Logging. Try not to die on the record.")
  else DT.out("The log didn't start. Type /combatlog yourself.") end
end

local function buildLogin()
  if dialogs.login then return dialogs.login end
  local dlg = frame("DeadTiredLogsLogin", 428, "The dead keep records. Turn them on?")
  local ran = function() finish(dlg, reportBoth) end
  dlg.buttons.combat  = makeButton(dlg, "Combat", "Combat log", 14, ran)
  dlg.buttons.chat    = makeButton(dlg, "Chat", "Chat log", 116, ran)
  dlg.buttons.both    = makeButton(dlg, "Both", "Both", 218, ran)
  dlg.buttons.neither = makeButton(dlg, "Neither", "Neither", 320, ran)
  dlg.buttons.neither:SetAttribute("type", nil)   -- runs nothing; it only closes
  dlg:Hide()
  dialogs.login = dlg
  return dlg
end

local function buildInstance()
  if dialogs.instance then return dialogs.instance end
  local dlg = frame("DeadTiredLogsInstance", 224, "Log this one?")
  dlg.status:SetText("Combat log is off. Warcraft Logs needs it on.")
  dlg.buttons.logit = makeButton(dlg, "LogIt", "Log it", 14, function(self)
    finish(dlg, self.macro and reportCombat or nil)
  end)
  dlg.buttons.notnow = makeButton(dlg, "NotNow", "Not now", 114, function()
    finish(dlg, nil)
  end)
  dlg.buttons.notnow:SetAttribute("type", nil)    -- runs nothing; it only closes
  dlg:Hide()
  dialogs.instance = dlg
  return dlg
end
L.dialogs = dialogs

local function arm(b, macro)
  b.macro = macro
  b:SetAttribute("macrotext", macro)
  if macro then b:Enable() else b:Disable() end
end

-- The login dialog (R2). force: show even with both logs on (unused by the commands; kept as
-- the beta had it). Returns "shown", "deferred" or "both on".
function L.showLogin(force)
  if inCombat() then
    pendingShow = { kind = "login", force = force or false }   -- secure attributes can't change in combat
    return "deferred"
  end
  local c, h = L.state()
  if c == true and h == true and not force then return "both on" end
  local dlg = buildLogin()
  local p = L.plan(c, h)
  arm(dlg.buttons.combat, p.combat)
  arm(dlg.buttons.chat, p.chat)
  arm(dlg.buttons.both, p.both)
  dlg.status:SetText("combat log " .. word(c) .. "    chat log " .. word(h))
  dlg:Show()
  return "shown"
end

-- The instance dialog (R1, R3): combat log only. Returns "shown", "deferred", "on" or "quiet".
function L.askInstance(key)
  if not L.asking() then return "quiet" end
  local c = L.state()
  if c == true then return "on" end
  if inCombat() then
    pendingShow = { kind = "instance", key = key }
    return "deferred"
  end
  local dlg = buildInstance()
  arm(dlg.buttons.logit, L.plan(c, true).combat)
  dlg:Show()
  return "shown"
end

-- ---------------------------------------------------------------- visits (R5)

local visit, held                     -- the visit in progress; a visit held over a corpse run
local resumable                       -- this Lua session began with a /reload
local entered, loginDone, coveredByLogin = false, false, false

local function dead() return (clean((try(UnitIsDeadOrGhost, "player")))) == true end

local function zoneCheck()
  if not DT.isMember() then return end
  local _, key = L.where()
  local wasResumable = resumable
  resumable = false
  if not key then
    if visit then
      if dead() then held = visit end            -- released inside: the corpse run comes back
      visit = nil
      if type(settings().visit) == "string" then store().visit = nil end
    end
    return
  end
  if visit then return end                       -- a zone change or loading screen inside
  if wasResumable and settings().visit == key then visit = key return end   -- /reload inside
  local back = (held == key)
  held = nil
  visit = key
  store().visit = key
  if back or coveredByLogin then return end
  L.askInstance(key)
end

local function loginCheck()
  if loginDone or not DT.isMember() then return end
  loginDone = true
  if not L.loginAsking() then return end
  local r = L.showLogin(false)
  coveredByLogin = (r == "shown" or r == "deferred")   -- it already offers the combat log
end

local function onWorld(isLogin, isReload)
  if not entered then
    entered = true
    resumable = isReload and true or false
  end
  if isLogin or isReload then loginCheck() end     -- not on loading screens
  zoneCheck()
  coveredByLogin = false
end

DT.listen("member", function(isMember)
  if not isMember or not entered then return end
  loginCheck()
  zoneCheck()
  coveredByLogin = false
end)

local function regen()
  if pendingHide then
    pendingHide = nil
    for _, d in pairs(dialogs) do d:Hide() end
  end
  if pendingShow then
    local p = pendingShow
    pendingShow = nil
    if p.kind == "login" then L.showLogin(p.force)
    elseif visit ~= nil and visit == p.key and DT.isMember() then L.askInstance(p.key) end
  end
end

-- ---------------------------------------------------------------- /dt logs

local function onoff(v) return v and "on" or "off" end

local function logs(msg)
  local rest = msg:match("^logs%s*(.-)%s*$") or ""
  if rest == "on" then
    store().ask = true
    return DT.out("I'll ask about the combat log in dungeons and raids.")
  elseif rest == "off" then
    store().ask = false
    return DT.out("No more asking in dungeons and raids. /dt logs on to undo.")
  elseif rest == "login on" then
    store().login = true
    return DT.out("I'll ask about both logs at login.")
  elseif rest == "login off" then
    store().login = false
    return DT.out("No more asking at login.")
  elseif rest == "now" then
    local r = L.showLogin(false)
    if r == "both on" then return DT.out("Already logging both.") end
    if r == "deferred" then return DT.out("In combat. The prompt waits until it's over.") end
    return
  elseif rest == "" then
    local c, h = L.state()
    return DT.out("combat log " .. word(c) .. ", chat log " .. word(h)
      .. ". Asking in dungeons and raids: " .. onoff(L.asking())
      .. ". At login: " .. onoff(L.loginAsking()) .. ".")
  end
  return DT.out("/dt logs | logs on/off | logs login on/off | logs now")
end

DT.module({
  id = "logs",
  events = {
    PLAYER_ENTERING_WORLD = onWorld,
    ZONE_CHANGED_NEW_AREA = zoneCheck,
    PLAYER_REGEN_ENABLED = regen,
  },
  ready = DT.errors,
  errorKey = "logs", lastKey = "lastLogs",
})
DT.verb("logs", logs, "logs on/off/login/now")
