-- Dead Tired: the guild gate. DT.isMember() is true only when GetGuildInfo("player") names the
-- guild in Config.lua (case-insensitive, surrounding spaces ignored). Read live on every call,
-- so a login before the guild info arrives is never stuck as "not a member"; re-checked on
-- PLAYER_GUILD_UPDATE, which signals "member" to the other modules when the answer changes.
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local function norm(s)
  if type(s) ~= "string" then return nil end
  s = s:gsub("^%s+", ""):gsub("%s+$", ""):lower()
  if s == "" then return nil end
  return s
end

function DT.guildKey() return norm(DT.Config.GUILD_NAME) end

function DT.isMember()
  local want = DT.guildKey()
  local have = norm(clean((try(GetGuildInfo, "player"))))
  return want ~= nil and have == want
end

local last
local function recheck()
  local now = DT.isMember()
  if now ~= last then
    last = now
    DT.signal("member", now)
  end
end
DT.recheckGuild = recheck

DT.module({
  id = "guild",
  init = function() DT.db(); last = DT.isMember() end,
  events = {
    PLAYER_GUILD_UPDATE = recheck,
    PLAYER_ENTERING_WORLD = recheck,
  },
  ready = DT.errors,
  errorKey = "guild", lastKey = "lastGuild",
})
