-- AUD-02 (card 5, Prep.lua): after the asker's /reload, sharing guildies ignore its roll calls.
--   lua5.1 audit/tests/test_prep_reload.lua   (from the repo root, after setup.sh)
-- Red now: the question id `qid` is a per-session counter that restarts at 1 after a /reload,
-- and each answerer remembers answered[asker .. "#" .. q] for its own session, so the reloaded
-- asker's first roll calls reuse ids the guild has already answered and get silence.
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local L = dofile(dir .. "/lib.lua")
local H = L.harness("dt_prep")
local check = H.check
local FILES = { "Config.lua", "Core.lua", "Guild.lua", "Comms.lua", "Roster.lua", "Alts.lua", "Welcome.lua",
  "PrepList.lua", "Prep.lua" }

local function stubs(c)
  c.env.UnitClass = function() return "Warrior", "WARRIOR" end
  c.env.C_Item = { GetItemCount = function() return 99 end }
end

do
  local w = H.world()
  local a = w:client({ name = "Stromham", guild = L.G, files = FILES, random = L.half })
  local b = w:client({ name = "Graverobber", guild = L.G, files = FILES, random = L.half })
  stubs(a); stubs(b)
  a:login(); b:login()
  w:advance(60)
  b:slash("prep share on")
  a:slash("prep check")
  w:advance(11)
  check("baseline: the first roll call gets B's answer", a:said("Ready (1): Graverobber") ~= nil)

  w:advance(120)
  local a2 = L.reload(w, a, { random = L.half, files = FILES, stubs = stubs })
  w:advance(30)
  a2:slash("prep check")
  w:advance(11)
  check("after the asker's /reload, B answers the new roll call (A printed: "
    .. tostring(a2.printed[#a2.printed - 1]) .. ")", a2:said("Ready (1): Graverobber") ~= nil)
end

H.finish("audit prep_reload")
