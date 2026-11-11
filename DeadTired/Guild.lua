-- Dead Tired: the guild gate and the welcome.
--
-- DT.isMember() is true only when GetGuildInfo("player") names the guild in Config.lua
-- (case-insensitive, surrounding spaces ignored). Read live on every call, so a login before the
-- guild info arrives is never stuck as "not a member" (rc3). Outside the guild DT loads, says
-- nothing (DT.out) and sends nothing (DT.send).
-- The welcome: one line per login (a /reload counts), members only, while guild.welcome is on.
-- After it, once ever, the old-records line if an rc3 DeadTiredDB was moved under legacy.
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local WELCOME = "Rest in Pieces, %s. The crypt's open. /dt for the rest."
local LEGACY = "Your old crypt records are kept for the move."

local function norm(s)
  if type(s) ~= "string" then return nil end
  s = DT.trim(s):lower()
  if s == "" then return nil end
  return s
end

function DT.guildKey() return norm(DT.Config.GUILD_NAME) end

function DT.isMember()
  local want = DT.guildKey()
  local have = norm(clean((try(GetGuildInfo, "player"))))
  return want ~= nil and have == want                                      -- guard: guild gate
end

local last, entered, shown = nil, false, false

local function greet()
  if shown or not entered or not DT.isMember() then return end
  shown = true
  if DT.get("guild", "welcome") then
    local me = DT.myKey()
    DT.out(WELCOME:format(me and DT.display(me) or "stranger"))
  end
  local db = DT.db()
  if db.legacy ~= nil and not db.legacySaid then
    db.legacySaid = true
    DT.out(LEGACY)
  end
  DT.signal("greeted")
end

local function recheck()
  local now = DT.isMember()
  if now ~= last then
    last = now
    DT.signal("member", now)
  end
  greet()
end
DT.recheckGuild = recheck

DT.module({
  id = "guild",
  title = "Guild",
  settings = {
    { key = "welcome", type = "bool", default = true, label = "Welcome line",
      desc = "One line in chat when you log in or reload. Nothing else is printed unless you ask." },
  },
  init = function() last = DT.isMember() end,
  events = {
    PLAYER_ENTERING_WORLD = function() entered = true; recheck() end,
    PLAYER_GUILD_UPDATE = recheck,
  },
})

DT._guild = { WELCOME = WELCOME, LEGACY = LEGACY }
