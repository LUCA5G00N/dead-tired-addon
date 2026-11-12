-- Offline checks for Events.lua (card 6, the event tracker, ported from rc3 in Port 2): rc3's checks,
-- the setting as a card, the list in a viewport.  lua5.1 DeadTired/tests/test_events.lua
-- Stubs per client (c.env): C_DateAndTime.GetServerTimeLocal (an epoch that moves with the world
-- clock, from c.base; c.noClock) and date("!*t", t).
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local P = "|cff7fa650Dead Tired|r "
local SUNDAY = 1793491200          -- 2026-11-01 00:00:00, a Sunday (server wall clock)
local EV = "Stranglethorn Fishing Extravaganza"

local function stub(c)
  c.base = SUNDAY
  local env = c.env
  rawset(env, "C_DateAndTime", { GetServerTimeLocal = function()
    if c.noClock then return nil end
    return c.base + math.floor(c.world.t - 1000)
  end })
  local plain = rawget(env, "date")
  rawset(env, "date", function(fmt, t) if fmt == "!*t" then return os.date("!*t", t) end return plain(fmt, t) end)
end
local function mk(w, o)
  if o.guild == nil then o.guild = G end
  o.full = o.full or (o.name .. " Hamson")
  local setup = o.setup
  o.setup = function(c) stub(c); if setup then setup(c) end end
  return w:client(o)
end
-- Set the server clock so that "now" is <day offset from Sunday> <HH:MM>.
local function at(w, c, dayOffset, hhmm)
  local h, m = hhmm:match("^(%d+):(%d+)$")
  c.base = SUNDAY + dayOffset * 86400 + tonumber(h) * 3600 + tonumber(m) * 60 - math.floor(w.t - 1000)
end
local function reminders(c)
  local n = 0
  for _, m in ipairs(c.printed) do if m:find("in %d+ minutes%. Bring a rod") or m:find("has started%.") then n = n + 1 end end
  return n
end
local function lines(c)
  local out = {}
  for _, r in ipairs(c.DT._events.list().model.rows) do out[#out + 1] = r.line end
  return out
end

-- ---------------------------------------------------------------- the list (a viewport)
do
  local w = H.world()
  local a = mk(w, { name = "Stromham" })
  a:login()
  check("store: reminders off by default; the setting is a card with a typed path", a.DT.get("events", "remind") == false
    and a.DT.setting("events", "remind").verb == "events remind on|off")
  at(w, a, 1, "10:30")                               -- Monday 10:30
  a:slash("events")
  local vp = a.DT._events.vp()
  check("/dt events opens the list; later this week: days, hours, minutes", vp:IsShown()
    and lines(a)[1] == EV .. ": Sunday 14:00 server time, in 6d 3h 30m." and #a.printed == 0)
  check("'Times are server time.' under the list", vp.footer.text == "Times are server time.")
  check("the list is a DT viewport: Escape closes it (R-P2-2)", vp.name == "DeadTiredViewport_events")
  at(w, a, 0, "11:15"); a:slash("events")
  check("later today: zero days dropped", lines(a)[1] == EV .. ": Sunday 14:00 server time, in 2h 45m.")
  at(w, a, 0, "13:55"); a:slash("events")
  check("minutes only", lines(a)[1] == EV .. ": Sunday 14:00 server time, in 5m.")
  at(w, a, 0, "14:00"); a:slash("events")
  check("at the start: on now", lines(a)[1] == EV .. ": on now, 120 min left.")
  at(w, a, 0, "15:59"); a:slash("events")
  check("near the end: on now, 1 min left", lines(a)[1] == EV .. ": on now, 1 min left.")
  at(w, a, 0, "16:00"); a:slash("events")
  check("just after: next week", lines(a)[1] == EV .. ": Sunday 14:00 server time, in 6d 22h 0m.")
  at(w, a, 6, "23:00"); a:slash("events")
  check("across the week's end", lines(a)[1] == EV .. ": Sunday 14:00 server time, in 15h 0m.")
  a.ns.EventsList[2] = { name = "Midnight Mass", weekday = 7, start = "23:30", minutes = 60 }
  at(w, a, 0, "00:10"); a:slash("events")
  check("an event running across midnight into Sunday is on now", lines(a)[2] == "Midnight Mass: on now, 20 min left.")
  local L = a.DT._events.list()
  check("the list shows both rows", L.rows[1].shown and L.rows[2].shown and L.rows[2].row.name == "Midnight Mass")
  a.ns.EventsList[2] = nil
  local saved = a.ns.EventsList[1]
  a.ns.EventsList[1] = nil
  a:slash("events")
  check("an empty list: rc3's line in the viewport", L.empty.shown and L.empty.text == "No events on the list.")
  a.ns.EventsList[1] = saved
  a.noClock = true
  a:slash("events")
  check("server clock absent: says so", #a.printed == 1 and a.printed[1] == P .. "Can't read the server clock.")
  a.noClock = false
  rawset(a.env, "C_DateAndTime", nil)
  a:slash("events")
  check("C_DateAndTime absent: says so", a.printed[1] == P .. "Can't read the server clock.")
  a:slash("events remind"); check("/dt events remind shows the setting", a:said("reminders are off.") ~= nil)
  a:slash(""); check("the help lists events [remind on/off]", a:said("events [remind on/off]") ~= nil)
end

-- ---------------------------------------------------------------- reminders (R4)
do
  local w = H.world()
  local a = mk(w, { name = "Stromham" })
  at(w, a, 0, "13:00")
  a:login(); a.printed = {}
  w:advance(3600 * 2)
  check("R4: reminders off by default: nothing", reminders(a) == 0)

  local w2 = H.world()
  local b = mk(w2, { name = "Grave" })
  b.DT.set("events", "remind", true)
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
  w2:advance(60 * 60)
  check("nothing else that day", reminders(b) == 2)
  at(w2, b, 7, "13:20"); w2:advance(60 * 45)
  check("next week: one more pair, no more", reminders(b) == 4)
  b:slash("events remind off")
  check("/dt events remind off: the line", b:said("reminders off. Miss things in peace.") ~= nil)
  b.printed = {}
  at(w2, b, 14, "13:20"); w2:advance(60 * 45)
  check("/dt events remind off: nothing", reminders(b) == 0)
  b:slash("events remind on")
  check("/dt events remind on: the line", b:said("reminders on. You'll hear 30 minutes before, and at the start.") ~= nil)

  local w3 = H.world()
  local c = mk(w3, { name = "Ghoul" })
  c.DT.set("events", "remind", true)
  at(w3, c, 0, "14:05")
  c:login(); c.printed = {}
  w3:advance(61)
  check("logged in 6 minutes after the start: the start line", #c.printed == 1 and c.printed[1] == P .. EV .. " has started.")
  local w4 = H.world()
  local d = mk(w4, { name = "Wight" })
  d.DT.set("events", "remind", true)
  at(w4, d, 0, "14:20")
  d:login(); d.printed = {}
  w4:advance(60 * 30)
  check("logged in 20 minutes after the start: nothing", reminders(d) == 0)

  local w5 = H.world()
  local x = mk(w5, { name = "Spy", guild = "Alliance Spies" })
  x.DT.set("events", "remind", true)
  at(w5, x, 0, "13:00")
  x:login(); w5:advance(3600 * 2)
  check("nothing for a non-member", #x.printed == 0)
  local y = mk(w5, { name = "Lich" })
  y.DT.set("events", "remind", true)
  y.noClock = true
  y:login(); y.printed = {}
  w5:advance(3600 * 2)
  check("no server clock: no reminder, no error", #y.printed == 0 and (y:db().errors.events or 0) == 0)
end


-- ---------------------------------------------------------------- fix round 4: the master switch (R-F4-5, G10)
do
  local OFF = "events.enabled = off"
  local w = H.world()
  local a = mk(w, { name = "Stromham" })
  a:login()
  local m = a.DT.byId.events
  check("G10 events: an On card, default on", m.optional and a.DT.setting("events", "enabled").label == "On"
    and a.DT.enabled("events") and m.frame.events.PLAYER_ENTERING_WORLD)
  a:slash("events remind on")
  at(w, a, 0, "13:20")                  -- 40 minutes before the Sunday 14:00 fishing
  a:slash("set events enabled off")
  check("G10 events off: registers no events", not m.frame.events.PLAYER_ENTERING_WORLD)
  for _, v in ipairs({ "events", "events remind off", "events remind" }) do
    a:slash(v)
    check("G10 events off: /dt " .. v .. " prints " .. OFF .. " and nothing else", #a.printed == 1 and a.printed[1] == P .. OFF
      and not (a.DT._events.vp() and a.DT._events.vp():IsShown()))
  end
  check("G10 events off: the verbs changed nothing", a.DT.get("events", "remind") == true)
  a.printed = {}
  w:advance(3600)
  check("G10 events off: no reminder printed unasked (the ticker stops)", reminders(a) == 0)
  -- on again: the ticker comes back
  a:slash("set events enabled on")
  a.printed = {}
  at(w, a, 7, "13:20")
  w:advance(3600)
  check("G10 events on again: the reminders come back", reminders(a) == 2)
  a:slash("events")
  check("G10 events on again: /dt events opens the list", a.DT._events.vp():IsShown())
end

H.finish("events")
