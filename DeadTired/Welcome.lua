-- Dead Tired: the welcome. One line per login (a /reload counts) for members only, and only
-- while DeadTiredDB.welcome is on. /dt welcome on|off. Nothing else is ever printed unasked.
local ADDON, ns = ...
local DT = ns.DT

local entered, shown = false, false

local function show()
  if shown or not entered then return end
  if not DT.isMember() or not DT.db().welcome then return end
  shown = true
  local me = DT.charKey()
  DT.out("Rest in Pieces, " .. (me and DT.display(me) or "stranger") .. ". The crypt's open. /dt for the rest.")
end

DT.listen("member", function(isMember) if isMember then show() end end)

local function welcome(msg)
  local arg = msg:match("^welcome%s+(%S+)")
  local db = DT.db()
  if arg == "on" then
    db.welcome = true
    return DT.out("welcome line exhumed. See you next login.")
  elseif arg == "off" then
    db.welcome = false
    return DT.out("welcome line buried. Silence, as the dead prefer.")
  end
  return DT.out("welcome line is " .. (db.welcome and "on" or "off") .. ". /dt welcome on|off")
end

DT.module({
  id = "welcome",
  init = function() DT.db() end,
  events = {
    PLAYER_ENTERING_WORLD = function()
      if entered then return end
      entered = true
      show()
    end,
  },
  ready = DT.errors,
  errorKey = "welcome", lastKey = "lastWelcome",
})
DT.verb("welcome", welcome, "welcome on|off")
