-- Offline checks for Session.lua: the Session object (this session's time, your deaths, new graves),
-- off the bar until ticked (R-P4).  lua5.1 DeadTired/tests/test_session.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"

local w = H.world()
local c = w:client({ guild = G, full = "Stromham Hamson" })
c:login()
local DT = c.DT
local function onBar()
  for _, b in ipairs(DT._bar.buttons()) do if b.shown and b.entry and b.entry.name == "session" then return b end end
end
local obj
for _, e in ipairs(DT.objects) do if e.name == "session" then obj = e.obj end end
check("the Session object exists, off the bar until ticked", obj and obj.offByDefault == true and obj.type == "data source" and onBar() == nil)
local listed
for _, e in ipairs(DT.barList()) do if e.name == "session" then listed = e end end
check("but listed in the bar's card, unticked", listed and listed.on == false)
c:slash("bar add session")
local b = onBar()
check("ticked: on the bar, this session's time", b and b.text.text == "Session 0:00")
w:advance(3600 + 5 * 60)
check("the time moves (redrawn each minute)", b.text.text == "Session 1:05")
check("the clock model", DT.sessionClock(0) == "0:00" and DT.sessionClock(59) == "0:00" and DT.sessionClock(42 * 60) == "0:42"
  and DT.sessionClock(3 * 3600 + 7 * 60 + 9) == "3:07")
DT.cryptSession.mine = 2
DT.cryptSession.heard = 5
b.scripts.OnEnter(b)
local tt = c:frame("DeadTiredTooltip")
local n = #tt.lines
check("the tooltip lists time, deaths and new graves", tt.lines[n - 3] == "This session" and tt.lines[n - 2] == "Time: 1:05"
  and tt.lines[n - 1] == "Your deaths: 2" and tt.lines[n] == "New in the graveyard: 5")
local sent = #c.sent
w:advance(600)
check("it sends nothing and prints nothing", #c.sent == sent and c:count("Session") == 0)
check("stats model", DT.sessionStats().deaths == 2 and DT.sessionStats().graves == 5 and DT.sessionStats().time >= 3600)
local r = c:reload()
local rb
for _, x in ipairs(r.DT._bar.buttons()) do if x.shown and x.entry and x.entry.name == "session" then rb = x end end
check("a reload: still ticked, the session starts again", rb and rb.text.text == "Session 0:00")
H.finish("session")
