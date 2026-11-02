-- Offline checks for EventsList.lua and Events.lua (card 6: the event tracker).
--   lua5.1 DeadTired/tests/test_events.lua  (from the repo root)
-- Stubs added here, per client, on client.env (card 1's harness is not changed):
-- C_DateAndTime.GetServerTimeLocal (an epoch that moves with the world clock) and date("!*t", t).
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local ALL = {}
for _, f in ipairs(H.FILES) do ALL[#ALL + 1] = f end
for _, f in ipairs({ "Stash.lua", "Played.lua", "EventsList.lua", "Events.lua" }) do ALL[#ALL + 1] = f end
local P = "|cff7fa650Dead Tired|r "
local SUNDAY = 1793491200          -- 2026-11-01 00:00:00, a Sunday (server wall clock)
local EV = "Stranglethorn Fishing Extravaganza"

local function client(w, opts)
  opts.files = opts.files or ALL
  if opts.guild == nil and not opts.outside then opts.guild = G end
  local c = w:client(opts)
  c.base = SUNDAY
  c.env.C_DateAndTime = { GetServerTimeLocal = function() if c.noClock then return nil end return c.base + (w.t - 1000) end }
  c.env.date = function(fmt, t) if fmt == "!*t" then return os.date("!*t", t) end return "2026-11-04 23:00:00" end
  return c
end
-- Set the server clock so that "now" is <day offset from Sunday> <HH:MM>.
local function at(w, c, dayOffset, hhmm)
  local h, m = hhmm:match("^(%d+):(%d+)$")
  c.base = SUNDAY + dayOffset * 86400 + tonumber(h) * 3600 + tonumber(m) * 60 - (w.t - 1000)
end
local function reminders(c)
  local n = 0
  for _, m in ipairs(c.printed) do if m:find("in %d+ minutes%. Bring a rod") or m:find("has started%.") then n = n + 1 end end
  return n
end

-- ---------------------------------------------------------------- the list
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  check("the list ships one event: Sunday 14:00 for 120 minutes", #a.ns.EventsList == 1 and a.ns.EventsList[1].name == EV
    and a.ns.EventsList[1].weekday == 1 and a.ns.EventsList[1].start == "14:00" and a.ns.EventsList[1].minutes == 120)
  check("store: reminders off by default", a:db().events.remind == false)
  at(w, a, 1, "10:30")                               -- Monday 10:30
  a:slash("events")
  check("later this week: days, hours, minutes", a.printed[1] == P .. EV .. ": Sunday 14:00 server time, in 6d 3h 30m."
    and a.printed[2] == P .. "Times are server time.")
  at(w, a, 0, "11:15")                               -- Sunday 11:15
  a:slash("events")
  check("later today: zero days dropped", a.printed[1] == P .. EV .. ": Sunday 14:00 server time, in 2h 45m.")
  at(w, a, 0, "13:55")
  a:slash("events")
  check("minutes only", a.printed[1] == P .. EV .. ": Sunday 14:00 server time, in 5m.")
  at(w, a, 0, "14:00")
  a:slash("events")
  check("at the start: on now", a.printed[1] == P .. EV .. ": on now, 120 min left.")
  at(w, a, 0, "15:59")
  a:slash("events")
  check("near the end: on now, 1 min left", a.printed[1] == P .. EV .. ": on now, 1 min left.")
  at(w, a, 0, "16:00")
  a:slash("events")
  check("just after: next week", a.printed[1] == P .. EV .. ": Sunday 14:00 server time, in 6d 22h 0m.")
  at(w, a, 6, "23:00")                               -- Saturday 23:00
  a:slash("events")
  check("across the week's end", a.printed[1] == P .. EV .. ": Sunday 14:00 server time, in 15h 0m.")
  a.ns.EventsList[2] = { name = "Midnight Mass", weekday = 7, start = "23:30", minutes = 60 }
  at(w, a, 0, "00:10")                               -- Sunday 00:10, inside Saturday 23:30's hour
  a:slash("events")
  check("an event running across midnight into Sunday is on now", a.printed[2] == P .. "Midnight Mass: on now, 20 min left.")
  a.ns.EventsList[2] = nil
  a.noClock = true
  a:slash("events")
  check("server clock absent: says so", a.printed[1] == P .. "Can't read the server clock." and #a.printed == 1)
  a.noClock = false
  a.env.C_DateAndTime = nil
  a:slash("events")
  check("C_DateAndTime absent: says so", a.printed[1] == P .. "Can't read the server clock.")
  a:slash("events remind"); check("/dt events remind shows the setting", a:said("reminders are off.") ~= nil)
  a:slash(""); check("the help lists events [remind on/off]", a:said("events [remind on/off]") ~= nil)
end

-- ---------------------------------------------------------------- reminders
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  at(w, a, 0, "13:00")
  a:login(); a.printed = {}
  w:advance(3600 * 4)
  check("reminders off by default: nothing", reminders(a) == 0)

  local w2 = H.world()
  local b = client(w2, { name = "Graverobber" })
  b:db().events.remind = true
  at(w2, b, 0, "13:20")
  b:login(); b.printed = {}
  w2:advance(60 * 9)                                 -- to 13:29: 31 minutes away
  check("nothing more than 30 minutes before", reminders(b) == 0)
  w2:advance(60)                                     -- 13:30
  check("the 30-minute line, exactly", #b.printed == 1 and b.printed[1] == P .. EV .. " in 30 minutes. Bring a rod, or a grudge.")
  w2:advance(60 * 29)                                -- 13:59
  check("only once before the start", reminders(b) == 1)
  w2:advance(60)                                     -- 14:00
  check("the start line, exactly, once", #b.printed == 2 and b.printed[2] == P .. EV .. " has started.")
  w2:advance(60 * 60 * 3)
  check("nothing else that day", reminders(b) == 2)
  w2:advance(86400 * 7)
  check("next week: one more pair, no more", reminders(b) == 4)
  b:slash("events remind off"); b.printed = {}
  w2:advance(86400 * 7)
  check("/dt events remind off: nothing", reminders(b) == 0)

  -- logging in mid-event: the start line if within 10 minutes of the start, not later
  local w3 = H.world()
  local c = client(w3, { name = "Ghoul" })
  c:db().events.remind = true
  at(w3, c, 0, "14:05")
  c:login(); c.printed = {}
  w3:advance(61)
  check("logged in 6 minutes after the start: the start line", #c.printed == 1 and c.printed[1] == P .. EV .. " has started.")
  local w4 = H.world()
  local d = client(w4, { name = "Wight" })
  d:db().events.remind = true
  at(w4, d, 0, "14:20")
  d:login(); d.printed = {}
  w4:advance(60 * 30)
  check("logged in 20 minutes after the start: nothing", reminders(d) == 0)

  -- a non-member, and no clock
  local w5 = H.world()
  local x = client(w5, { name = "Spy", guild = "Alliance Spies" })
  x:db().events.remind = true
  at(w5, x, 0, "13:00")
  x:login(); w5:advance(3600 * 2)
  check("nothing for a non-member", #x.printed == 0)
  local y = client(w5, { name = "Lich" })
  y:db().events.remind = true
  y.noClock = true
  y:login(); y.printed = {}
  w5:advance(86400 * 7)
  check("no server clock: no reminder, no error", #y.printed == 0 and (y:db().errors.events or 0) == 0)
end

H.finish("events")
