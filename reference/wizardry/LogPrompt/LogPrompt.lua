-- WizardryLogPrompt -- a login reminder for the Forever beta's two client logs.
--
-- The combat log (Logs\WoWCombatLog-*.txt) and chat log (Logs\WoWChatLog.txt) are the
-- offline lane's raw material (draft 0014; clientlog.py), and both are off again after
-- every client start. The operator kept forgetting them. On login, and on /reload if
-- either is off, this shows one small dialog: Combat log / Chat log / Both / Neither.
--
-- HOW THE LOGS ARE SWITCHED ON. Each button is a SecureActionButton running the same
-- slash commands the operator would type (/combatlog, /chatlog) as macro text. That works
-- whether or not LoggingCombat/LoggingChat are callable from addon code on this client:
-- WizardryProbe's sweep covered C_* namespaces only, so the globals are unobserved here,
-- and on a Midnight-era client they may be restricted. A button is only armed for a log
-- that is OFF, because both commands toggle: running /combatlog with the log already on
-- would turn it off.
--
-- State is read from C_ChatInfo.IsLoggingCombat / IsLoggingChat (observed present, 69977
-- sweep), falling back to the legacy globals called with no argument. After a click the
-- state is read again and the result printed, so a command that did nothing says so.
--
-- It keeps no SavedVariables: asking every login is the point, and it needs no link
-- under draft 0016. It reads nothing else and writes nothing but the two client logs'
-- on/off state, through the client's own commands.

local ADDON = ...
local NS = {}                         -- exposed for tests only, as WizardryLogPrompt_NS
WizardryLogPrompt_NS = NS

local function out(m)
  local s = "|cff66ccffLogPrompt|r " .. tostring(m)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(s) else print(s) end
end

-- ------------------------------------------------------------------ state

local function readState(ciName, legacyName)
  local ci = C_ChatInfo and C_ChatInfo[ciName]
  if type(ci) == "function" then return ci() and true or false end
  local legacy = _G[legacyName]
  if type(legacy) == "function" then return legacy() and true or false end
  return nil                          -- unknown: no reader on this client
end

function NS.state()
  return readState("IsLoggingCombat", "LoggingCombat"),
         readState("IsLoggingChat", "LoggingChat")
end

local function word(on)
  if on == nil then return "|cffaaaaaa?|r" end
  return on and "|cff40ff40ON|r" or "|cffff4040OFF|r"
end

-- What each choice runs, given the current state. Only logs that are OFF get a
-- command; a log in an unknown state is treated as off (the dialog says "?" for it).
function NS.plan(combatOn, chatOn)
  local c = (combatOn ~= true) and "/combatlog" or nil
  local h = (chatOn ~= true) and "/chatlog" or nil
  local both
  if c and h then both = c .. "\n" .. h end
  return { combat = c, chat = h, both = both }
end

-- ------------------------------------------------------------------ dialog

local dlg, buttons, pendingShow, pendingHide

local function finish(label)
  if InCombatLockdown and InCombatLockdown() then
    pendingHide = true                -- a frame holding secure buttons can't hide in combat
  else
    dlg:Hide()
  end
  if label == nil then out("no logs changed.") return end
  local report = function()
    local c, h = NS.state()
    out(label .. " -> combat log " .. word(c) .. ", chat log " .. word(h))
  end
  if C_Timer and C_Timer.After then C_Timer.After(0.5, report) else report() end
end
NS.finish = finish

-- A secure button acts on key-down or key-up depending on ActionButtonUseKeyDown, and
-- is registered for both. PostClick fires for both too, so it must act only on the
-- half that ran the macro, or it would hide the dialog before the macro half arrives.
local function clickRan(down)
  local useDown = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")
  return (down and useDown) or (not down and not useDown)
end
NS.clickRan = clickRan

local function makeButton(key, text, x)
  local b = CreateFrame("Button", "WizardryLogPromptButton_" .. key, dlg,
                        "SecureActionButtonTemplate,UIPanelButtonTemplate")
  b:SetSize(96, 24)
  b:SetPoint("BOTTOMLEFT", dlg, "BOTTOMLEFT", x, 14)
  b:SetText(text)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("type", "macro")
  b:SetScript("PostClick", function(self, _, down)
    if not clickRan(down) then return end
    finish(self.macro and text or nil)
  end)
  return b
end

local function build()
  if dlg then return end
  dlg = CreateFrame("Frame", "WizardryLogPromptFrame", UIParent,
                    BackdropTemplateMixin and "BackdropTemplate" or nil)
  dlg:SetSize(428, 104)
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
  dlg.title:SetText("Beta telemetry -- turn the logs on?")
  dlg.status = dlg:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  dlg.status:SetPoint("TOP", dlg.title, "BOTTOM", 0, -8)

  buttons = {
    combat  = makeButton("Combat", "Combat log", 14),
    chat    = makeButton("Chat", "Chat log", 116),
    both    = makeButton("Both", "Both", 218),
    neither = makeButton("Neither", "Neither", 320),
  }
  -- "Neither" runs nothing; it only closes.
  buttons.neither:SetAttribute("type", nil)
  dlg:Hide()
end

local function arm(b, macro)
  b.macro = macro
  b:SetAttribute("macrotext", macro)
  if macro then b:Enable() else b:Disable() end
end

function NS.show(force)
  if InCombatLockdown and InCombatLockdown() then
    pendingShow = force or false      -- secure attributes can't change in combat
    return "deferred"
  end
  local c, h = NS.state()
  if c == true and h == true and not force then return "both on" end
  build()
  local p = NS.plan(c, h)
  arm(buttons.combat, p.combat)
  arm(buttons.chat, p.chat)
  arm(buttons.both, p.both)
  dlg.status:SetText("combat log " .. word(c) .. "    chat log " .. word(h))
  dlg:Show()
  return "shown"
end

-- ------------------------------------------------------------------ events

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event, isLogin, isReload)
  if event == "PLAYER_ENTERING_WORLD" then
    if isLogin or isReload then NS.show(false) end   -- not on zone loading screens
  elseif event == "PLAYER_REGEN_ENABLED" then
    if pendingHide and dlg then pendingHide = nil; dlg:Hide() end
    if pendingShow ~= nil then local f = pendingShow; pendingShow = nil; NS.show(f) end
  end
end)

SLASH_WIZARDRYLOGPROMPT1 = "/logprompt"
SlashCmdList["WIZARDRYLOGPROMPT"] = function()
  local r = NS.show(true)
  if r == "deferred" then out("in combat -- the prompt will open when combat ends.") end
end
