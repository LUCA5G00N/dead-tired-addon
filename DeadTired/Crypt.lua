-- Dead Tired: the crypt. "Rest in Pieces" death notices, the graveyard memorial, the bedtime nag.
-- docs/COWORK_BRIEF_dt_crypt.md (card 3; R1-R3 ratified 2026-11-02).
--
-- No combat data: PLAYER_DEAD says only that you died. Level and zone are read from game state
-- afterwards. Nothing names a killer, and nothing here reads the death recap.
-- R1: guildies' death notices print unasked (one line each, /dt rip off silences them).
-- R2: your own hardcore death is shared by default; a normal death only after /dt rip share on.
-- R3: this file keeps its own store, DeadTiredDB.crypt; card 1's files are untouched.
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local DEATH_WINDOW = 60      -- seconds: at most one death handled per window
local CAP = 100              -- deaths kept per guild
local SHOW = 10              -- graveyard lines
local ZONE_MAX = 48
local TICK = 60              -- bedtime ticker, seconds
local NIGHT = 360            -- minutes after bedtime the nag may fire
local NAG_GAP = 30           -- minutes between nags
local NAGS = {
  "It's %s. Even the dead sleep.",
  "Still here. The crypt has a bed with your name on it.",
  "Last call. Log off before the sun gets you.",
}
local CLOSING = "Only guildies running the addon, and only deaths seen while you were online."

-- ---------------------------------------------------------------- the store

local function crypt()
  local db = DT.db()
  if type(db.crypt) ~= "table" then db.crypt = {} end
  local c = db.crypt
  if c.rip == nil then c.rip = true end
  if type(c.badDeath) ~= "number" then c.badDeath = 0 end
  return c
end

local function deaths()
  local c = crypt()
  local g = DT.guildKey() or "?"
  if type(c[g]) ~= "table" then c[g] = {} end
  if type(c[g].deaths) ~= "table" then c[g].deaths = {} end
  return c[g].deaths
end
DT.crypt, DT.deaths = crypt, deaths

local function record(e)
  local list = deaths()
  list[#list + 1] = e
  while #list > CAP do table.remove(list, 1) end                       -- guard: memorial cap
end

-- ---------------------------------------------------------------- own death

local function isHardcore()
  return (try(C_GameRules and C_GameRules.IsHardcoreActive)) == true
end

local function level()
  local l = clean(try(UnitLevel, "player"))
  if type(l) ~= "number" or l < 1 or l > 100 or l ~= math.floor(l) then return 0 end
  return l
end

local function zone()
  local z = clean(try(GetRealZoneText))
  if type(z) ~= "string" or z == "" then return "somewhere" end
  return z:sub(1, ZONE_MAX)
end

local lastDeath

local function onDead()
  if not DT.isMember() then return end                                 -- guard: member check
  local t = DT.now()
  if lastDeath and t - lastDeath < DEATH_WINDOW then return end        -- guard: death window
  lastDeath = t
  local lvl, z, hc = level(), zone(), isHardcore()
  local itype = clean(select(2, try(IsInInstance)))
  if itype == "pvp" or itype == "arena" then hc = false end            -- guard: battleground rule
  record({ who = DT.charKey() or "?", lvl = lvl, zone = z, hc = hc, at = DT.stamp(), mine = true })
  local c = crypt()
  if c.share == true or (c.share == nil and hc) then                   -- guard: normal not sent by default
    DT.send("DEATH", { lvl = tostring(lvl), zone = z, hc = hc and "1" or "0" })
  end
end

-- ---------------------------------------------------------------- received deaths

local function lvlText(l) return (l and l > 0) and tostring(l) or "??" end

-- lvl "0" is accepted as "level unknown": it is what a sender whose UnitLevel failed sends.
local function valid(f)
  local lvl = type(f.lvl) == "string" and f.lvl:match("^%d%d?%d?$") and tonumber(f.lvl)
  return lvl and lvl <= 100 and type(f.zone) == "string" and #f.zone >= 1 and #f.zone <= ZONE_MAX
    and (f.hc == "0" or f.hc == "1")
end

DT.on("DEATH", function(from, f)
  local c = crypt()
  if not valid(f) then c.badDeath = c.badDeath + 1 return end          -- guard: field validation
  local lvl, hc = tonumber(f.lvl), f.hc == "1"
  record({ who = from, lvl = lvl, zone = f.zone, hc = hc, at = DT.stamp(), mine = false })
  if not c.rip then return end                                         -- guard: rip toggle
  local who, z = DT.display(from), DT.safe(f.zone, ZONE_MAX)
  if hc then
    DT.out("Rest in Pieces: " .. who .. ", level " .. lvlText(lvl) .. ", " .. z .. ". Hardcore. Gone for good.")
  else
    DT.out(who .. " died at level " .. lvlText(lvl) .. " in " .. z .. ". Again.")
  end
end)

-- ---------------------------------------------------------------- the graveyard

function DT.graveyard()
  local list = deaths()
  if #list == 0 then
    DT.out("The graveyard's empty. Give it time.")
  else
    for i = #list, math.max(1, #list - SHOW + 1), -1 do
      local e = list[i]
      local day = type(e.at) == "string" and (e.at:match("^(%d%d%d%d%-%d%d%-%d%d)") or e.at) or "?"
      DT.out(DT.safe(day, 20) .. " " .. DT.display(e.who) .. " " .. lvlText(e.lvl) .. " "
        .. DT.safe(e.zone, ZONE_MAX) .. (e.hc and " (HC)" or ""))
    end
  end
  DT.out(CLOSING)
end

-- ---------------------------------------------------------------- settings

local function rip(msg)
  local c = crypt()
  local share = msg:match("^rip%s+share%s+(%S+)$")
  local onoff = msg:match("^rip%s+(%S+)$")
  if share == "on" then c.share = true; return DT.out("your deaths will be shared. Every last one.")
  elseif share == "off" then c.share = false; return DT.out("your deaths stay between you and the spirit healer.")
  elseif onoff == "on" then c.rip = true; return DT.out("notices on. You'll hear about every fall.")
  elseif onoff == "off" then c.rip = false; return DT.out("notices off. Let the dead bury the dead.")
  elseif msg == "rip" then
    local s = c.share == nil and "default (hardcore only)" or (c.share and "on" or "off")
    return DT.out("notices " .. (c.rip and "on" or "off") .. "; sharing your deaths " .. s .. ".")
  end
  return DT.out("/dt rip on/off, or /dt rip share on/off")
end

local function bedtime(msg)
  local c = crypt()
  local arg = msg:match("^bedtime%s+(.-)%s*$")
  if not arg or arg == "" then
    return DT.out(c.bedtime and ("bedtime is " .. c.bedtime .. ".") or "bedtime is off. /dt bedtime HH:MM to set one.")
  end
  if arg == "off" then
    c.bedtime = nil
    return DT.out("bedtime off. Stay up forever; you're dead anyway.")
  end
  local h, m = arg:match("^(%d%d?):(%d%d)$")
  h, m = tonumber(h), tonumber(m)
  if not h or h > 23 or m > 59 then return DT.out("/dt bedtime HH:MM (24-hour), or /dt bedtime off") end
  c.bedtime = string.format("%02d:%02d", h, m)
  return DT.out("bedtime set for " .. c.bedtime .. ". You'll be told.")
end

-- ---------------------------------------------------------------- the nag

local shown, lastM = 0, 0

local function tick()
  if not DT.isMember() then return end
  local bt = crypt().bedtime
  if type(bt) ~= "string" then return end
  local bh, bm = bt:match("^(%d%d):(%d%d)$")
  if not bh then return end
  local now = clean(try(date, "*t"))
  if type(now) ~= "table" or type(now.hour) ~= "number" or type(now.min) ~= "number" then return end
  local m = ((now.hour * 60 + now.min) - (tonumber(bh) * 60 + tonumber(bm))) % 1440
  if m >= NIGHT then shown = 0 return end                              -- guard: 6-hour window
  if shown >= #NAGS then return end                                    -- guard: 3-nag cap
  if shown > 0 and m - lastM < NAG_GAP then return end
  shown, lastM = shown + 1, m
  DT.out(string.format(NAGS[shown], string.format("%02d:%02d", now.hour, now.min)))
end

local function loop()
  local ok, err = pcall(tick)
  if not ok then
    local e = DT.errors()
    e.crypt = (e.crypt or 0) + 1
    e.lastCrypt = "bedtime: " .. tostring(err)
  end
  DT.after(TICK, loop)
end

-- For the offline tests only.
DT._crypt = { tick = tick, nags = function() return shown end }

local entered = false
DT.module({
  id = "crypt",
  init = function() crypt() end,
  events = {
    PLAYER_DEAD = onDead,
    PLAYER_ENTERING_WORLD = function()
      if entered then return end
      entered = true
      DT.after(TICK, loop)
    end,
  },
  ready = DT.errors,
  errorKey = "crypt", lastKey = "lastCrypt",
})
DT.verb("rip", rip, "rip [share] on/off")
DT.verb("graveyard", function() DT.graveyard() end)
DT.verb("bedtime", bedtime, "bedtime HH:MM/off")
