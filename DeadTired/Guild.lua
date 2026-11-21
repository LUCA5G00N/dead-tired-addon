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

-- ---------------------------------------------------------------- class colours (0.3.3)
-- R-F6-3: the class comes from the guild roster (GetGuildRosterInfo's 11th value, the class token),
-- matched on the full name, and on the realm too when the roster name carries "-Realm" (the rule
-- DT.rankOf uses). Nothing is sent or saved. R-F6-4: the client's own RAID_CLASS_COLORS, read only.
-- R-F6-5: anything that can't be placed gives nil, and the name stays plain.
local ROSTER_MAX = 1000

-- One guarded walk of the roster: lower-case full name -> { name (the roster's spelling), token,
-- realm (realm key or nil) }.
function DT.rosterClasses()
  local out = {}
  local n = clean(try(GetNumGuildMembers))
  if type(n) ~= "number" or n < 1 then return out end
  DT.rosterWalks = (DT.rosterWalks or 0) + 1
  for i = 1, math.min(n, ROSTER_MAX) do
    local rn, _, _, _, _, _, _, _, _, _, token = try(GetGuildRosterInfo, i)
    rn, token = clean(rn), clean(token)
    if type(rn) == "string" and type(token) == "string" and token ~= "" then
      local full = DT.fullName(rn)
      local rr = rn:match("%-(.+)$")
      if full then out[(full:lower():gsub("%s+", " "))] = { name = full, token = token, realm = rr and DT.realmKey(rr) or nil } end
    end
  end
  return out
end

local function unit(v) return type(v) == "number" and v >= 0 and v <= 1 end

-- r, g, b, hex for a character key's class, or nil. roster: from DT.rosterClasses (built when absent).
function DT.classColour(key, roster)
  local realm, name = DT.splitKey(key)
  if not realm then return nil end
  roster = roster or DT.rosterClasses()
  local e = roster[(name:lower():gsub("%s+", " "))]
  if not e then return nil end                                             -- guard: not on the roster, plain
  if e.realm and e.realm:lower() ~= realm:lower() then return nil end      -- guard: realm match
  local tbl = RAID_CLASS_COLORS
  if type(tbl) ~= "table" then return nil end
  local c = tbl[e.token]
  if type(c) ~= "table" then return nil end
  local r, g, b, hex = clean(c.r), clean(c.g), clean(c.b), clean(c.colorStr)
  if not (unit(r) and unit(g) and unit(b)) then return nil end             -- guard: r/g/b in range
  if type(hex) ~= "string" or not hex:match("^%x%x%x%x%x%x%x%x$") then return nil end   -- guard: colorStr is 8 hex digits
  return r, g, b, hex
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
