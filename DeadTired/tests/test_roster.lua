-- Offline checks for Roster.lua, with two (and three) clients on one fake GUILD bus.
--   lua5.1 DeadTired/tests/test_roster.lua  (from the repo root)
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local FILES = { "Config.lua", "Core.lua", "Guild.lua", "Comms.lua", "Roster.lua" }
local G = "DEAD TIRED"
local function half() return 0.5 end   -- reply delay 2 + 0.5 * 6 = 5 s

local function hellos(c)
  local n = 0
  for _, s in ipairs(c.sent) do if s.text:find("^1%^HELLO") then n = n + 1 end end
  return n
end

-- ---------------------------------------------------------------- one exchange settles
do
  local w = H.world()
  local a = w:client({ name = "Stromham", guild = G, files = FILES, random = half })
  a:login()
  w:advance(60)   -- a has been online a while; its login HELLO went to nobody
  check("login HELLO goes out once, 10 s after entering the world", hellos(a) == 1 and a.sent[1].t == 1010)
  check("HELLO carries version and an empty main", a.sent[1].text == "1^HELLO^main~^v~0.1.0")
  local b = w:client({ name = "Graverobber", guild = G, files = FILES, random = half })
  b:login()
  b:fire("PLAYER_ENTERING_WORLD", false, false)  -- a zone change is not a login
  w:advance(9.9)
  check("nothing from b before 10 s", hellos(b) == 0)
  w:advance(0.2)
  check("b says HELLO at 10 s", hellos(b) == 1)
  w:advance(1.9)
  check("a's reply waits at least 2 s", hellos(a) == 1)
  w:advance(6.5)
  check("a replies once, within 8 s, marked as a reply", hellos(a) == 2 and a.sent[2].text:find("r~1", 1, true))
  w:advance(60)
  check("settled: b never answers a reply; 3 HELLOs in all", hellos(a) == 2 and hellos(b) == 1)
  local ra, rb = a.DT.roster(), b.DT.roster()
  check("each stores the other under the guild, Realm-Name", ra["Classic Beta PvP-Graverobber"]
    and rb["Classic Beta PvP-Stromham"] and rb["Classic Beta PvP-Stromham"].v == "0.1.0"
    and rb["Classic Beta PvP-Stromham"].seen == "2026-11-04 23:00:00" and b:db().roster["dead tired"] == rb)
  check("each records itself as the account's own", ra["Classic Beta PvP-Stromham"].mine == true)

  -- A fresh HELLO from someone already answered (e.g. after /dt main) gets no second reply.
  b.DT.hello()
  w:advance(30)
  check("reply-once: a second plain HELLO from b gets no second reply", hellos(a) == 2 and hellos(b) == 2)

  -- /dt who on each side.
  a:slash("who")
  local out = a:printedText()
  check("/dt who lists b under this session", a:said("this session (1): Graverobber") ~= nil)
  check("/dt who ends with the closing line", a.printed[#a.printed]:find("Only guildies running the addon show up here.", 1, true) ~= nil)
  check("/dt who does not list the player themself", not out:find("Stromham", 1, true))
  b:slash("who")
  check("/dt who on b lists a", b:said("this session (1): Stromham 0.1.0") ~= nil
    and b.printed[#b.printed]:find("Only guildies running the addon show up here.", 1, true))
end

-- ---------------------------------------------------------------- seen before, names made safe
do
  local w = H.world()
  local db = { roster = { ["dead tired"] = {
    ["Classic Beta PvP-Lich"] = { v = "0.1.0", main = "", seen = "2026-11-03 01:00:00" },
    ["Nethergarde-Banshee"] = { v = "0.1.0", main = "Nethergarde-Banshee", seen = "2026-11-03 01:00:00" },
    ["Classic Beta PvP-Myalt"] = { v = "0.1.0", main = "", seen = "x", mine = true },
  } } }
  local a = w:client({ name = "Stromham", guild = G, files = FILES, random = half, db = db })
  a:slash("who")
  check("nobody this session: says so", a:said("this session: nobody yet") ~= nil)
  check("seen before: names from the store, other realms named, the account's own left out",
    a:said("seen before (2): Banshee-Nethergarde (main) 0.1.0, Lich 0.1.0") ~= nil)
  check("and still the closing line", a.printed[#a.printed]:find("Only guildies running the addon show up here.", 1, true))
  a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^HELLO^main~^v~%7CTInterface%7Ct", "GUILD", "Lich-ClassicBetaPvP")
  a:slash("who")
  check("heard now: moved from seen before to this session, UI escapes defused",
    a:said("this session (1): Lich ||TInterface||t") ~= nil and a:said("seen before (1): Banshee") ~= nil)
  a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^HELLO^main~nonsense^v~0.1.0", "GUILD", "Ghoul-ClassicBetaPvP")
  a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^HELLO^main~", "GUILD", "Wight-ClassicBetaPvP")
  check("a HELLO with a bad main or no version is not stored", a.DT.roster()["Classic Beta PvP-Ghoul"] == nil
    and a.DT.roster()["Classic Beta PvP-Wight"] == nil and a:db().comms.badHello == 2)
end

-- ---------------------------------------------------------------- three clients, an early reply
do
  -- c logs in and is heard by a, which is itself only just logged in: a's reply goes out first,
  -- then a's login HELLO. b, long online, must still answer a's login HELLO so a learns of b.
  local w = H.world()
  local b = w:client({ name = "Graverobber", guild = G, files = FILES, random = half })
  b:login(); w:advance(30)
  local c = w:client({ name = "Ghoul", guild = G, files = FILES, random = half })
  local a = w:client({ name = "Stromham", guild = G, files = FILES, random = half })
  c:login(); w:advance(3); a:login()
  w:advance(60)
  local heardA = a.DT._roster.heard()
  check("three clients: everyone hears everyone", heardA["Classic Beta PvP-Graverobber"] and heardA["Classic Beta PvP-Ghoul"]
    and b.DT._roster.heard()["Classic Beta PvP-Stromham"] and c.DT._roster.heard()["Classic Beta PvP-Stromham"]
    and c.DT._roster.heard()["Classic Beta PvP-Graverobber"])
  local before = hellos(a) + hellos(b) + hellos(c)
  w:advance(120)
  check("three clients: settled, nothing more is said", hellos(a) + hellos(b) + hellos(c) == before)
end

-- ---------------------------------------------------------------- outside the guild
do
  local w = H.world()
  local a = w:client({ name = "Stromham", guild = G, files = FILES, random = half })
  local x = w:client({ name = "Spy", guild = "Alliance Spies", files = FILES, random = half })
  local y = w:client({ name = "Loner", guild = nil, files = FILES, random = half })
  a:login(); x:login(); y:login()
  w:advance(60)
  check("non-members send nothing at all", #x.sent == 0 and #y.sent == 0)
  a:slash("who")
  check("and never show up in a member's /dt who", not a:printedText():find("Spy", 1, true)
    and not a:printedText():find("Loner", 1, true))

  -- Guild info late at login: not a member at 10 s, the HELLO goes when PLAYER_GUILD_UPDATE says so.
  local w2 = H.world()
  local late = w2:client({ name = "Latecomer", guild = nil, files = FILES, random = half })
  late:login(); w2:advance(15)
  check("guild info late: no HELLO while not yet a member", #late.sent == 0)
  late.guild = G
  late:fire("PLAYER_GUILD_UPDATE", "player")
  check("guild info late: HELLO once membership arrives", hellos(late) == 1)
  late:fire("PLAYER_GUILD_UPDATE", "player")
  late.guild = nil; late:fire("PLAYER_GUILD_UPDATE", "player")
  late.guild = G; late:fire("PLAYER_GUILD_UPDATE", "player")
  w2:advance(30)
  check("and only once", hellos(late) == 1)
end

H.finish("roster")
