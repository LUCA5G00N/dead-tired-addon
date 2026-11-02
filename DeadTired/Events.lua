-- Dead Tired: the event tracker. Next occurrence and countdown, in server time; opt-in reminders.
-- docs/COWORK_BRIEF_dt_stretch.md (card 6; R1-R6 ratified 2026-11-02).
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local WEEK = 7 * 1440
local TICK = 60
local PRE = 30              -- minutes before the start for the first reminder
local GO = 10               -- minutes after the start the "has started" line may still fire
local DAYS = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }

local function store()
  local db = DT.db()
  if type(db.events) ~= "table" then db.events = {} end
  if db.events.remind == nil then db.events.remind = false end
  return db.events
end

-- Server wall clock: epoch seconds, and minutes into the week (Sunday 00:00 = 0), or nil.
local function clock()
  local t = clean(try(C_DateAndTime and C_DateAndTime.GetServerTimeLocal))
  if type(t) ~= "number" then return nil end
  local d = clean(try(date, "!*t", t))
  if type(d) ~= "table" or type(d.wday) ~= "number" or type(d.hour) ~= "number" or type(d.min) ~= "number" then
    return nil
  end
  return t, (d.wday - 1) * 1440 + d.hour * 60 + d.min
end

local function events()
  local out = {}
  for _, e in ipairs(ns.EventsList or {}) do
    local h, m
    if type(e) == "table" and type(e.name) == "string" and type(e.weekday) == "number" and e.weekday >= 1
       and e.weekday <= 7 and type(e.start) == "string" then
      h, m = e.start:match("^(%d%d?):(%d%d)$")
      if h then
        out[#out + 1] = { name = e.name, at = (e.weekday - 1) * 1440 + tonumber(h) * 60 + tonumber(m),
          minutes = tonumber(e.minutes) or 60, day = DAYS[e.weekday], start = e.start }
      end
    end
  end
  return out
end

-- minutes since the start (mod a week) and minutes until the next start
local function position(ev, now)
  return (now - ev.at) % WEEK, (ev.at - now) % WEEK
end

local function countdown(m)
  local d, h, mm = math.floor(m / 1440), math.floor((m % 1440) / 60), m % 60
  if d > 0 then return d .. "d " .. h .. "h " .. mm .. "m" end
  if h > 0 then return h .. "h " .. mm .. "m" end
  return mm .. "m"
end

local function list()
  local _, now = clock()
  if not now then return DT.out("Can't read the server clock.") end
  local evs = events()
  if #evs == 0 then return DT.out("No events on the list.") end
  for _, ev in ipairs(evs) do
    local since, untilStart = position(ev, now)
    if since < ev.minutes then
      DT.out(DT.safe(ev.name, 64) .. ": on now, " .. (ev.minutes - since) .. " min left.")
    else
      DT.out(DT.safe(ev.name, 64) .. ": " .. ev.day .. " " .. ev.start .. " server time, in " .. countdown(untilStart) .. ".")
    end
  end
  DT.out("Times are server time.")
end

local fired = {}
local function tick()
  if not store().remind then return end                                -- guard: remind gate
  if not DT.isMember() then return end
  local t, now = clock()
  if not now then return end
  local base = math.floor(t / 60)
  for _, ev in ipairs(events()) do
    local since, untilStart = position(ev, now)
    if untilStart > 0 and untilStart <= PRE then                       -- guard: 30-minute window
      local key = "pre:" .. ev.name .. ":" .. (base + untilStart)
      if not fired[key] then                                           -- guard: once per occurrence
        fired[key] = true
        DT.out(DT.safe(ev.name, 64) .. " in " .. untilStart .. " minutes. Bring a rod, or a grudge.")
      end
    end
    if since < GO and since < ev.minutes then
      local key = "go:" .. ev.name .. ":" .. (base - since)
      if not fired[key] then                                           -- guard: once per occurrence (start)
        fired[key] = true
        DT.out(DT.safe(ev.name, 64) .. " has started.")
      end
    end
  end
end

local function loop()
  local ok, err = pcall(tick)
  if not ok then
    local e = DT.errors()
    e.events = (e.events or 0) + 1
    e.lastEvents = "tick: " .. tostring(err)
  end
  DT.after(TICK, loop)
end

local function verb(msg)
  local s = store()
  if msg == "events" then return list()
  elseif msg == "events remind on" then s.remind = true; return DT.out("reminders on. You'll hear 30 minutes before, and at the start.")
  elseif msg == "events remind off" then s.remind = false; return DT.out("reminders off. Miss things in peace.")
  elseif msg == "events remind" then return DT.out("reminders are " .. (s.remind and "on" or "off") .. ". /dt events remind on/off")
  end
  return DT.out("/dt events, or /dt events remind on/off")
end

local entered = false
DT.module({
  id = "events",
  init = function() store() end,
  events = {
    PLAYER_ENTERING_WORLD = function()
      if entered then return end
      entered = true
      DT.after(TICK, loop)
    end,
  },
  ready = DT.errors,
  errorKey = "events", lastKey = "lastEvents",
})
DT.verb("events", verb, "events [remind on/off]")
