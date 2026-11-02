-- AUD-01 (card 1, Roster.lua): after a /reload, nobody answers your HELLO, so /dt who stays empty.
--   lua5.1 audit/tests/test_roster_reload.lua   (from the repo root, after setup.sh)
-- Red now: the guildies already online keep answered[you] = true for their session, so the
-- reloaded client's login HELLO gets no reply and its fresh `heard` table never fills.
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local L = dofile(dir .. "/lib.lua")
local H = L.harness("dt_foundation")
local check = H.check
local FILES = { "Config.lua", "Core.lua", "Guild.lua", "Comms.lua", "Roster.lua", "Alts.lua", "Welcome.lua" }

-- Two guildies online and settled, then B reloads.
do
  local w = H.world()
  local a = w:client({ name = "Stromham", guild = L.G, files = FILES, random = L.half })
  a:login()
  w:advance(60)
  local b = w:client({ name = "Graverobber", guild = L.G, files = FILES, random = L.half })
  b.files = FILES
  b:login()
  w:advance(60)
  b:slash("who")
  check("baseline: before the reload, B lists A this session", b:said("this session (1): Stromham") ~= nil)

  local before = L.count(a, "^1%^HELLO")
  local b2 = L.reload(w, b, { random = L.half })
  w:advance(60)
  check("B's login HELLO went out after the /reload", L.count(b2, "^1%^HELLO") == 1)
  check("A answers B's post-reload HELLO (A sent " .. (L.count(a, "^1%^HELLO") - before) .. ")",
    L.count(a, "^1%^HELLO") == before + 1)
  b2:slash("who")
  check("after a /reload, /dt who on B lists A under this session (it says: "
    .. tostring(b2.printed[1]) .. ")", b2:said("this session (1): Stromham") ~= nil)
end

-- The same with a relog of the same character (logout, log back in): a new Lua session too.
do
  local w = H.world()
  local a = w:client({ name = "Stromham", guild = L.G, files = FILES, random = L.half })
  a:login()
  w:advance(60)
  local b = w:client({ name = "Graverobber", guild = L.G, files = FILES, random = L.half })
  b.files = FILES
  b:login()
  w:advance(60)
  local db = b:db()
  b:logout()
  w:advance(300)
  local b2 = w:client({ name = "Graverobber", guild = L.G, files = FILES, random = L.half, db = db })
  b2:login()
  w:advance(60)
  b2:slash("who")
  check("after logging the same character back in, /dt who lists A this session",
    b2:said("this session (1): Stromham") ~= nil)
end

H.finish("audit roster_reload")
