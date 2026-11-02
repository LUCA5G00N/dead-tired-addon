-- AUD-04 (card 4, Gank.lua): after the computer restarts, /dt gank on an enemy you logged in an
-- earlier session says "Already noted" for as long as the old uptime was.
--   lua5.1 audit/tests/test_gank_reboot.lua   (from the repo root, after setup.sh)
-- Red now: a local log stores t = GetTime() in SavedVariables, and the double-press check
-- compares it with GetTime() in a later session. GetTime() is the machine's uptime clock, so
-- after a restart `now - e.t` is negative, always "< 300".
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local L = dofile(dir .. "/lib.lua")
local H = L.harness("dt_pvp")
local check = H.check
local FILES = { "Config.lua", "Core.lua", "Guild.lua", "Comms.lua", "Roster.lua", "Alts.lua", "Welcome.lua",
  "Gank.lua" }

local function stubs(c)
  local e = c.env
  e.UnitExists = function(u) return u == "target" end
  e.UnitIsPlayer = function(u) return u == "target" end
  e.UnitFactionGroup = function(u) if u == "target" then return "Alliance" end return "Horde" end
  e.UnitName = function(u) if u == "player" then return c.name end if u == "target" then return "Backstabz", nil end end
  e.UnitClass = function() return "Rogue", "ROGUE" end
  e.UnitLevel = function() return 60 end
  e.GetRealZoneText = function() return "Stranglethorn Vale" end
end

-- Session 1: the machine has been up ~5.8 days. Tim logs Backstabz.
local w1 = H.world()
w1.t = 500000
local a = w1:client({ name = "Stromham", guild = L.G, files = FILES })
stubs(a)
a:login()
w1:advance(5)
a:slash("gank")
check("baseline: the first press is noted", a:said("Noted: Backstabz") ~= nil)
local db = a:db()
a:logout()

-- Session 2: the next evening, after a restart. Uptime is 20 minutes. Backstabz is back.
local w2 = H.world()
w2.t = 1200
local a2 = w2:client({ name = "Stromham", guild = L.G, files = FILES, db = db })
stubs(a2)
a2:login()
w2:advance(5)
a2:slash("gank")
check("after a restart, a new press on the same enemy a day later is noted (it says: "
  .. tostring(a2.printed[1]) .. ")", a2:said("Noted: Backstabz") ~= nil)
check("and it is sent to the guild", #a2.sent >= 1 and a2.sent[#a2.sent].text:find("^1%^GANK") ~= nil)

H.finish("audit gank_reboot")
