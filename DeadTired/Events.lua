-- Dead Tired: the event tracker. Next occurrence and countdown, in server time; opt-in reminders.
-- Card 6 (docs/COWORK_BRIEF_dt_stretch.md on card/dt_stretch; R1-R6 ratified 2026-11-02), ported
-- from rc3's Events.lua onto the framework in Port 2. Logic and lines are rc3's; what changed: the
-- setting events.remind as a card (typed: /dt events remind on|off), the list in a viewport (each
-- event a row, "Times are server time." under it). EventsList.lua is rc3's, byte for byte.
-- R4 (a ruled "prints unasked" exception): reminders print only once switched on: 30 minutes
-- before an event, and at its start (up to 10 minutes late), once per occurrence.
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local WEEK = 7 * 1440
local TICK = 60
local PRE = 30              -- minutes before the start for the first reminder
local GO = 10               -- minutes after the start the "has started" line may still fire
local DAYS = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
local NOTE = "Times are server time."
local NONE = "No events on the list."
local NO_CLOCK = "Can't read the server clock."

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

-- Rows: { name, when } with rc3's wording, or nil, reason when the clock can't be read.
function DT.eventRows()
  local _, now = clock()
  if not now then return nil, NO_CLOCK end
  local rows = {}
  for _, ev in ipairs(events()) do
    local since, untilStart = position(ev, now)
    local when
    if since < ev.minutes then
      when = "on now, " .. (ev.minutes - since) .. " min left."
    else
      when = ev.day .. " " .. ev.start .. " server time, in " .. countdown(untilStart) .. "."
    end
    local name = DT.safe(ev.name, 64)
    rows[#rows + 1] = { name = name, when = when, line = name .. ": " .. when, search = name .. " " .. when }
  end
  return rows
end

local vp, list, model

local function view(rows)
  if not vp then
    model = DT.listModel()
    vp = DT.viewport({ id = "events", title = "Events", search = true, width = 440, height = 260, footer = 16,
      onSearch = function(text) model:filter(text); list.offset = 0; list:refresh() end })
    local note = vp.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    note:SetPoint("BOTTOMLEFT", vp.frame, "BOTTOMLEFT", DT.style("spacing.pad"), 6)
    note:SetText(NOTE)
    vp.note = note
    DT.skin(function() DT.fontTo(note, "small", "muted") end)
    list = DT.list(vp.body, model, { count = 10,
      empty = function(m) if #m.rows == 0 then return NONE end end,
      columns = { { key = "name", width = 190 }, { key = "when", width = 200, colour = "muted" } } })
  end
  model:set(rows)
  list:refresh()
  vp:Show()
end

local function show()
  local rows, why = DT.eventRows()
  if not rows then return DT.out(why) end
  view(rows)
end

-- ---------------------------------------------------------------- reminders

local fired = {}
local function tick()
  if DT.get("events", "remind") ~= true then return end                 -- guard: reminders only once switched on (R4)
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
  if not ok then DT.fail("events", "tick", err) end
  DT.after(TICK, loop)
end

local function verb(args)
  local w = (args or ""):lower():gsub("%s+", " ")
  if w == "" then return show()
  elseif w == "remind on" then
    DT.set("events", "remind", true)
    return DT.out("reminders on. You'll hear 30 minutes before, and at the start.")
  elseif w == "remind off" then
    DT.set("events", "remind", false)
    return DT.out("reminders off. Miss things in peace.")
  elseif w == "remind" then
    return DT.out("reminders are " .. (DT.get("events", "remind") == true and "on" or "off") .. ". /dt events remind on/off")
  end
  return DT.out("/dt events, or /dt events remind on/off")
end

local entered = false
DT.module({
  id = "events",
  title = "Events",
  settings = {
    { key = "remind", type = "bool", default = false, label = "Reminders", verb = "events remind on|off",
      desc = "One line in chat 30 minutes before each event on the list, and one at its start. Off until you switch it on." },
  },
  verbs = { { verb = "events", usage = "events [remind on/off]", fn = verb } },
  events = {
    PLAYER_ENTERING_WORLD = function()
      if entered then return end
      entered = true
      DT.after(TICK, loop)
    end,
  },
})

-- For the offline tests only.
DT._events = { tick = tick, NOTE = NOTE, NONE = NONE, NO_CLOCK = NO_CLOCK, vp = function() return vp end,
  list = function() return list end }
