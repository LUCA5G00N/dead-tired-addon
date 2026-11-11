-- Dead Tired: the Session object on the bar (Port 1, "DT info on the bar"). This session's play
-- time, your own deaths this session and the graveyard entries added this session (Crypt.lua
-- records both). The tooltip lists them. Off the bar until ticked (R-P4: offByDefault).
-- It only reads DT's own counters and the clock; nothing is sent or saved.
local ADDON, ns = ...
local DT = ns.DT

local ICON = [[Interface\Icons\INV_Misc_PocketWatch_01]]
local started = nil

-- Hours and minutes: "0:42", "1:05".
function DT.sessionClock(s)
  s = math.max(0, math.floor(s or 0))
  return string.format("%d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60)
end

function DT.sessionStats()
  local c = DT.cryptSession or { mine = 0, heard = 0 }
  return { time = started and (DT.now() - started) or 0, deaths = c.mine or 0, graves = c.heard or 0 }
end

local function text()
  local s = DT.sessionStats()
  return "Session " .. DT.sessionClock(s.time)
end

local function tooltip(tt)
  local s = DT.sessionStats()
  tt:AddLine("This session")
  tt:AddLine("Time: " .. DT.sessionClock(s.time), 1, 1, 1)
  tt:AddLine("Your deaths: " .. s.deaths, 1, 1, 1)
  tt:AddLine("New in the graveyard: " .. s.graves, 1, 1, 1)
end

-- Redrawn once a minute (and on every death); it only redraws.
local ticking = false
local function tick()
  DT.update("session", "text", text())
  DT.after(60, tick)
end

DT.module({
  id = "session",
  title = "Session",
  ldb = { type = "data source", text = "Session 0:00", icon = ICON, offByDefault = true,
    OnClick = function(_, which) if which == "RightButton" then DT.openSettings("bar") else DT.graveyard() end end,
    OnTooltipShow = tooltip },
  events = {
    PLAYER_ENTERING_WORLD = function()
      if not started then started = DT.now() end
      if not ticking then ticking = true; tick() end
    end,
  },
})
DT.listen("death", function() DT.update("session", "text", text()) end)

-- For the offline tests only.
DT._session = { text = text, tooltip = tooltip }
