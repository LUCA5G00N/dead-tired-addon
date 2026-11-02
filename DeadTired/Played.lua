-- Dead Tired: the slowest-leveller award. Hours played per level, from guildies who share it.
-- docs/COWORK_BRIEF_dt_stretch.md (card 6; R1-R6 ratified 2026-11-02).
--
-- R3: play time is shared only when the player types /played themselves (TIME_PLAYED_MSG), with
-- /dt slowest share on. This file never asks the game for play time: asking prints the played
-- lines to the player's chat unasked.
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local SEND_WINDOW = 60
local SHOW = 5
local CLOSING = "Only guildies running the addon who share their /played. Type /played to update yours."

local function store()
  local db = DT.db()
  if type(db.played) ~= "table" then db.played = {} end
  local p = db.played
  if p.share == nil then p.share = false end
  if type(p.badPlayed) ~= "number" then p.badPlayed = 0 end
  return p
end

local function board()
  local p, g = store(), DT.guildKey() or "?"
  if type(p[g]) ~= "table" then p[g] = {} end
  return p[g]
end
DT.playedBoard = board

local lastSend

local function onPlayed(total)
  local p = store()
  if not p.share then return end                                       -- guard: share gate on sending
  if not DT.isMember() then return end
  local lvl = clean(try(UnitLevel, "player"))
  total = clean(total)
  if type(lvl) ~= "number" or lvl < 1 or lvl > 100 or lvl ~= math.floor(lvl) then return end
  if type(total) ~= "number" or total < 0 then return end
  local t = DT.now()
  if lastSend and t - lastSend < SEND_WINDOW then return end           -- guard: 60 s window
  lastSend = t
  local hours = math.floor(total / 360) / 10
  local me = DT.charKey()
  if me then board()[me] = { lvl = lvl, hours = hours, at = DT.stamp() } end
  DT.send("PLAYED", { lvl = tostring(lvl), h = string.format("%.1f", hours) })
end

local function valid(f)
  local lvl = type(f.lvl) == "string" and f.lvl:match("^%d%d?%d?$") and tonumber(f.lvl)
  if not lvl or lvl < 1 or lvl > 100 then return false end
  local h = type(f.h) == "string" and f.h:match("^%d+%.?%d?$") and tonumber(f.h)
  return h and h <= 100000
end

DT.on("PLAYED", function(from, f)
  if not valid(f) then                                                 -- guard: PLAYED validation
    local p = store()
    p.badPlayed = p.badPlayed + 1
    return
  end
  board()[from] = { lvl = tonumber(f.lvl), hours = tonumber(f.h), at = DT.stamp() }
end)

local function h1(x) return string.format("%.1f", x) end

function DT.slowest()
  local rows = {}
  for key, e in pairs(board()) do
    if type(e) == "table" and type(e.lvl) == "number" and type(e.hours) == "number" then
      if e.lvl >= 2 then                                               -- guard: level-1 exclusion
        rows[#rows + 1] = { key = key, lvl = e.lvl, hours = e.hours, rate = e.hours / e.lvl }
      end
    end
  end
  table.sort(rows, function(a, b)
    if a.rate ~= b.rate then return a.rate > b.rate end
    return DT.display(a.key):lower() < DT.display(b.key):lower()
  end)
  if #rows == 0 then
    DT.out("No contenders. Everyone's either fast or shy.")
  else
    local r = rows[1]
    DT.out("The Crypt Keeper's Award for Glacial Progress goes to " .. DT.display(r.key) .. ": " .. h1(r.rate)
      .. " hours a level (level " .. r.lvl .. ", " .. h1(r.hours) .. " h played).")
    for i = 2, math.min(#rows, SHOW) do
      r = rows[i]
      DT.out(i .. ". " .. DT.display(r.key) .. ": " .. h1(r.rate) .. " h/level (level " .. r.lvl .. ")")
    end
  end
  DT.out(CLOSING)
end

local function verb(msg)
  local p = store()
  if msg == "slowest" then return DT.slowest()
  elseif msg == "slowest share on" then
    p.share = true
    return DT.out("sharing your /played. Type /played to put yourself on the board.")
  elseif msg == "slowest share off" then
    p.share = false
    return DT.out("not sharing your /played. Your pace is your own.")
  elseif msg == "slowest share" then
    return DT.out("sharing your /played is " .. (p.share and "on" or "off") .. ". /dt slowest share on/off")
  end
  return DT.out("/dt slowest, or /dt slowest share on/off")
end

DT.module({
  id = "played",
  init = function() store() end,
  events = { TIME_PLAYED_MSG = onPlayed },
  ready = DT.errors,
  errorKey = "played", lastKey = "lastPlayed",
})
DT.verb("slowest", verb, "slowest [share on/off]")
