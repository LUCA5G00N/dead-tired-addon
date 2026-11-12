-- Offline checks for EventsList.lua (card 6, R4: the event tracker's list; data, not logic).
-- Port 2 ships rc3's file byte for byte.  lua5.1 DeadTired/tests/test_eventslist.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check

local ns = {}
local chunk = assert(loadfile(H.addonDir .. "/EventsList.lua"))
chunk("DeadTired", ns)
local L = ns.EventsList
check("the list is a table of events", type(L) == "table" and #L >= 1)
check("rc3's one event: the Fishing Extravaganza, Sunday 14:00 for 120 minutes", L[1].name == "Stranglethorn Fishing Extravaganza"
  and L[1].weekday == 1 and L[1].start == "14:00" and L[1].minutes == 120)
local ok = true
for _, e in ipairs(L) do
  if type(e.name) ~= "string" or type(e.weekday) ~= "number" or e.weekday < 1 or e.weekday > 7
     or type(e.start) ~= "string" or not e.start:match("^%d%d?:%d%d$") then ok = false end
end
check("every entry has a name, a weekday 1-7 and an HH:MM start", ok)
local env = setmetatable({}, { __index = _G, __newindex = function(t, k) error("global write " .. k) end })
local c2 = assert(loadfile(H.addonDir .. "/EventsList.lua"))
setfenv(c2, env)
check("it writes no global", pcall(c2, "DeadTired", {}))

H.finish("eventslist")
