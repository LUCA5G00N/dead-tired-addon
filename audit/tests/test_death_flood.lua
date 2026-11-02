-- AUD-07 (card 3, Crypt.lua): a received DEATH is printed every time it arrives. One guildie's
-- client (buggy, modified, or a /run DT.send) can make every client print without limit.
--   lua5.1 audit/tests/test_death_flood.lua   (from the repo root, after setup.sh)
-- The sender's own 60 s window is the only brake, and it lives in the sender's client.
-- Red now: 10 DEATHs from one sender in 10 seconds print 10 lines on every guildie.
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local L = dofile(dir .. "/lib.lua")
local H = L.harness("dt_crypt")
local check = H.check
local FILES = { "Config.lua", "Core.lua", "Guild.lua", "Comms.lua", "Roster.lua", "Alts.lua", "Welcome.lua",
  "Crypt.lua" }

local w = H.world()
local a = w:client({ name = "Stromham", guild = L.G, files = FILES })
local b = w:client({ name = "Graverobber", guild = L.G, files = FILES })
a:login(); b:login()
w:advance(60)
a.printed = {}
for i = 1, 10 do
  b.DT.send("DEATH", { lvl = "60", zone = "Orgrimmar", hc = "0" })   -- what any client's code can call
  w:advance(1)
end
w:advance(10)
local n = 0
for _, m in ipairs(a.printed) do if m:find("died at level", 1, true) then n = n + 1 end end
check("one sender's 10 DEATHs in 10 s print at most one notice on a guildie (printed " .. n .. ")", n <= 1)
check("and the graveyard keeps at most one of them (kept " .. #a.DT.deaths() .. ")", #a.DT.deaths() <= 1)

H.finish("audit death_flood")
