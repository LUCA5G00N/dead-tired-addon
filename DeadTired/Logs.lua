-- Dead Tired: logs. Asks a member entering a dungeon or raid, with the combat log off, whether to
-- switch it on (Warcraft Logs needs it, and the client switches it off at every logout).
-- Card 7 (docs/COWORK_BRIEF_dt_logs.md, rulings R1-R6), ported from rc3's Logs.lua onto the
-- framework in Port 2. Logic, frames and lines are rc3's (rc3 copied readState, word, plan, finish,
-- clickRan, makeButton, build, arm and the combat deferral from Tim's beta reminder,
-- reference/wizardry/LogPrompt/LogPrompt.lua). What changed: the two settings are cards (logs.ask,
-- typed /dt logs on|off; logs.login, typed /dt logs login on|off) instead of DeadTiredDB.logs.ask /
-- .login; the visit in progress stays in DeadTiredDB.logs.visit; verbs through the router.
--
-- HOW A LOG IS SWITCHED ON (R4, a ruled exception). Every button that switches anything is a
-- secure action button, DT's own frame (DeadTiredLogsButton_*, in DT's own dialogs
-- DeadTiredLogsLogin / DeadTiredLogsInstance), running the client's own slash command (/combatlog,
-- /chatlog) as macro text, so every switch is the player's click. A button is armed only for a log
-- that is OFF, because both commands toggle. This file only ever READS the logging state (the
-- legacy globals are called with no argument), never reads a log file, never reads a combat
-- event, never switches a log off, and touches no Blizzard frame or table.
--
-- WHEN IT ASKS:
--   * R1/R3/R5: entering a "party" or "raid" instance, combat log off, asking on (default):
--     one two-button dialog, once per visit. Battlegrounds, arenas and the open world never.
--   * R2: at login or /reload, only after /dt logs login on: the four-button dialog offering
--     both logs. Never on a loading screen.
--   * In combat a dialog waits until combat ends; an instance dialog is dropped if you have left.
--   * Fix round 1: F10, a log whose state can't be read is never armed (both commands toggle);
--     with nothing to arm, one line says so instead of a dialog. F11, leaving the instance hides
--     its dialog (after combat, if in combat).
--   * Fix round 2: F12, one logs prompt at a time (an open or pending login prompt covers a
--     dungeon visit; the login prompt hides an instance prompt before it shows). F13, a click on
--     any logs button hides every other open logs prompt.
-- The dialogs are not on Escape (R-P2-2 names the viewports): a frame holding secure buttons
-- can't be hidden in combat, and Escape would try.
-- Fix round 4: each dialog's title and status are wrapped blocks (DT.text, fixedFont: the dialogs
-- keep the game's lettering, unskinned); the dialog's height comes from them, measured once at
-- creation (always out of combat: a dialog is only built out of combat), the buttons below.
-- R-F4-5: a master switch (optional = true, the On card, default on). Off: no events, no prompt,
-- no login offer, never touches a client log; /dt logs answers "logs.enabled = off".

local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local L = {}                          -- exposed for tests as DT.logs
DT.logs = L

-- ---------------------------------------------------------------- settings

local function store()                -- a write; callers are members only
  local db = DT.db()
  if type(db.logs) ~= "table" then db.logs = {} end
  return db.logs
end

local function saved()                -- a read; creates nothing
  local l = type(DeadTiredDB) == "table" and DeadTiredDB.logs
  return type(l) == "table" and l or {}
end

function L.asking() return DT.get("logs", "ask") ~= false end
function L.loginAsking() return DT.get("logs", "login") == true end

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

-- What each choice runs, given the current state. Only logs known to be OFF get a command. Fix
-- round 1 (F10): a log in an unknown state is NOT armed (both commands toggle, so arming one could
-- switch a running log off); the dialog shows "?" for it.
function L.plan(combatOn, chatOn)
  local c = (combatOn == false) and "/combatlog" or nil                     -- guard: unknown not armed (F10)
  local h = (chatOn == false) and "/chatlog" or nil
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
  if kind ~= "party" and kind ~= "raid" then return kind, nil end        -- guard: dungeons and raids only (R1)
  local id = clean((select(8, try(GetInstanceInfo))))
  if id == nil then id = clean((try(GetRealZoneText))) or clean((try(GetZoneText))) or "?" end
  return kind, kind .. ":" .. tostring(id)
end

-- ---------------------------------------------------------------- dialogs (copied: build et al.)

local dialogs = {}                    -- login, instance
local function shown(d) return d ~= nil and d:IsShown() == true end
local pendingShow, pendingHide
local pendingHideInstance             -- F11: the visit ended in combat; hide when it's over

-- F10: what is printed instead of arming a button for a log whose state can't be read.
local UNKNOWN = {
  combat = "Can't tell if the combat log is on. Type /combatlog if it isn't.",
  chat = "Can't tell if the chat log is on. Type /chatlog if it isn't.",
}

local function finish(dlg, report)
  if report then
    local r = report
    report = function() if DT.enabled("logs") then r() end end         -- off: no line after the click
  end
  if inCombat() then
    pendingHide = true                -- a frame holding secure buttons can't hide in combat
  else
    dlg:Hide()
    -- Fix round 2 (F13): a click closes every other logs prompt too, so a stale button armed
    -- with the same toggle can't be clicked after this one ran. (In combat, pendingHide above
    -- hides them all when combat ends.)
    for _, d in pairs(dialogs) do
      if d ~= dlg and d:IsShown() then d:Hide() end                       -- guard: hide the others (F13)
    end
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

local TEXT_TOP, TEXT_GAP, TEXT_SIDE = 14, 8, 20      -- the title's top, title to status, each side
local BUTTON_H, BUTTON_BOTTOM, BUTTON_GAP = 24, 14, 22 -- the buttons' row and the room above it

-- The dialog's height from its title and status (0.3.0's 104 for one line of each).
function L.dialogHeight(titleH, statusH)
  return TEXT_TOP + math.ceil(titleH) + TEXT_GAP + math.ceil(statusH) + BUTTON_GAP + BUTTON_H + BUTTON_BOTTOM
end

-- status: the text the status line is sized for (the instance dialog's line, or the login
-- dialog's longest state line); set at creation, measured once with the title.
local function frame(name, w, title, status)
  local dlg = CreateFrame("Frame", name, UIParent,
                          BackdropTemplateMixin and "BackdropTemplate" or nil)
  dlg.dtWindow = name
  dlg:SetPoint("TOP", UIParent, "TOP", 0, -140)
  dlg:SetFrameStrata("DIALOG")
  if dlg.SetBackdrop then
    dlg:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                      tile = true, tileSize = 32, edgeSize = 24,
                      insets = { left = 6, right = 6, top = 6, bottom = 6 } })
  end
  local tw = w - 2 * TEXT_SIDE
  dlg.title = DT.text(dlg, "block", { fixedFont = true, layer = "ARTWORK", template = "GameFontNormal",
    justify = "CENTER", width = tw })
  dlg.title:SetPoint("TOP", dlg, "TOP", 0, -TEXT_TOP)
  DT.setText(dlg.title, title)
  dlg.status = DT.text(dlg, "block", { fixedFont = true, layer = "ARTWORK", template = "GameFontHighlightSmall",
    justify = "CENTER", width = tw })
  dlg.status:SetPoint("TOP", dlg.title, "BOTTOM", 0, -TEXT_GAP)
  DT.setText(dlg.status, status)
  dlg:SetSize(w, L.dialogHeight(DT.textHeight(dlg.title, tw), DT.textHeight(dlg.status, tw)))   -- guard: dialog sized from its text
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
  local dlg = frame("DeadTiredLogsLogin", 428, "The dead keep records. Turn them on?",
    "combat log " .. word(false) .. "    chat log " .. word(false))
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
  local dlg = frame("DeadTiredLogsInstance", 224, "Log this one?", "Combat log is off. Warcraft Logs needs it on.")
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
-- the beta had it). Returns "shown", "deferred", "both on" or "unknown" (F10: nothing could be
-- armed because a log's state can't be read; a line was printed for each such log instead).
function L.showLogin(force)
  if inCombat() then
    pendingShow = { kind = "login", force = force or false }   -- secure attributes can't change in combat
    return "deferred"
  end
  local c, h = L.state()
  if c == true and h == true and not force then return "both on" end
  local p = L.plan(c, h)
  if not p.combat and not p.chat and not force then                         -- F10: nothing to arm
    if c == nil then DT.out(UNKNOWN.combat) end
    if h == nil then DT.out(UNKNOWN.chat) end
    return "unknown"
  end
  -- Fix round 2 (F12): one prompt at a time. The login prompt offers the combat log too, so an
  -- instance prompt still up goes first (this runs out of combat: in combat the show was deferred).
  if shown(dialogs.instance) then dialogs.instance:Hide() end              -- guard: instance hidden for login (F12)
  local dlg = buildLogin()
  arm(dlg.buttons.combat, p.combat)
  arm(dlg.buttons.chat, p.chat)
  arm(dlg.buttons.both, p.both)
  DT.setText(dlg.status, "combat log " .. word(c) .. "    chat log " .. word(h))
  dlg:Show()
  return "shown"
end

-- The instance dialog (R1, R3): combat log only. Returns "shown", "deferred", "on", "quiet",
-- "unknown" (F10: the state can't be read, so no dialog; one line, once per visit) or "covered"
-- (F12: the login prompt is up or pending, and already offers the combat log).
local toldUnknown                     -- the visit key the F10 line was printed for
function L.askInstance(key)
  if not L.asking() then return "quiet" end
  -- Fix round 2 (F12): the login prompt already offers the combat log. If it's up (or waiting for
  -- combat to end), no second prompt: the visit counts as asked.
  if shown(dialogs.login) or (pendingShow and pendingShow.kind == "login") then   -- guard: login prompt covers (F12)
    return "covered"
  end
  local c = L.state()
  if c == true then return "on" end
  if c == nil then                                                          -- guard: unknown, no dialog (F10)
    if toldUnknown ~= key then
      toldUnknown = key
      DT.out(UNKNOWN.combat)
    end
    return "unknown"
  end
  if inCombat() then
    pendingShow = { kind = "instance", key = key }
    return "deferred"
  end
  local dlg = buildInstance()
  arm(dlg.buttons.logit, L.plan(c, true).combat)
  dlg:Show()
  return "shown"
end

-- F11: when the visit ends, the instance dialog goes too. A frame holding secure buttons can't be
-- hidden in combat, so then it waits for combat to end (and stays only if a visit began again).
function L.hideInstance()
  local d = dialogs.instance
  if not d then return end
  if inCombat() then pendingHideInstance = true else d:Hide() end          -- guard: hide on visit end (F11)
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
      L.hideInstance()                           -- F11: the dialog leaves with you
      if type(saved().visit) == "string" then store().visit = nil end
    end
    return
  end
  if visit then return end                       -- a zone change or loading screen inside
  if wasResumable and saved().visit == key then visit = key return end      -- /reload inside
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
  -- it already offers the combat log, or (F10) already said it can't tell
  coveredByLogin = (r == "shown" or r == "deferred" or r == "unknown")
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
  if not DT.enabled("logs") then return end                                 -- guard: off, no prompt (logs)
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
  if pendingHideInstance then
    pendingHideInstance = nil
    if visit == nil and dialogs.instance then dialogs.instance:Hide() end
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

local function logs(args)
  if not DT.enabled("logs") then return DT.out("logs.enabled = off") end    -- guard: off verbs do nothing else (logs)
  local rest = (args or ""):lower():gsub("%s+", " ")
  if rest == "on" then
    DT.set("logs", "ask", true)
    return DT.out("I'll ask about the combat log in dungeons and raids.")
  elseif rest == "off" then
    DT.set("logs", "ask", false)
    return DT.out("No more asking in dungeons and raids. /dt logs on to undo.")
  elseif rest == "login on" then
    DT.set("logs", "login", true)
    return DT.out("I'll ask about both logs at login.")
  elseif rest == "login off" then
    DT.set("logs", "login", false)
    return DT.out("No more asking at login.")
  elseif rest == "now" then
    local r = L.showLogin(false)
    if r == "both on" then return DT.out("Already logging both.") end
    if r == "deferred" then return DT.out("In combat. The prompt waits until it's over.") end
    if r == "unknown" then return end           -- F10: its line is already printed
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
  title = "Logs",
  optional = true,
  -- off: an open prompt goes (out of combat; a frame holding secure buttons can't hide in combat)
  onDisable = function()
    pendingShow = nil
    if inCombat() then return end
    for _, d in pairs(dialogs) do d:Hide() end
  end,
  -- built hidden, never in combat
  fit = function() if not inCombat() then buildLogin(); buildInstance() end end,
  settings = {
    { key = "ask", type = "bool", default = true, label = "Ask in dungeons and raids", verb = "logs on|off",
      desc = "Entering a dungeon or raid with the combat log off, one prompt to switch it on (Warcraft Logs needs it). Never in battlegrounds, arenas or the open world." },
    { key = "login", type = "bool", default = false, label = "Ask at login", verb = "logs login on|off",
      desc = "At login or /reload, one prompt offering the combat log and the chat log, whichever is off. Off until you switch it on." },
  },
  verbs = { { verb = "logs", usage = "logs on/off/login/now", fn = logs } },
  events = {
    PLAYER_ENTERING_WORLD = onWorld,
    ZONE_CHANGED_NEW_AREA = zoneCheck,
    PLAYER_REGEN_ENABLED = regen,
  },
})
