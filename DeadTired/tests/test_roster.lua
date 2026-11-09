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
  check("HELLO carries version, an empty main and the session token",
    a.sent[1].text == "1^HELLO^main~^s~" .. a.DT.sessionToken .. "^v~0.1.0")
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
  check("each stores the other under the guild, Realm-Name", ra["ClassicBetaPvP-Graverobber"]
    and rb["ClassicBetaPvP-Stromham"] and rb["ClassicBetaPvP-Stromham"].v == "0.1.0"
    and rb["ClassicBetaPvP-Stromham"].seen == "2026-11-04 23:00:00" and b:db().roster["dead tired"] == rb)
  check("each records itself as the account's own", ra["ClassicBetaPvP-Stromham"].mine == true)

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
    ["ClassicBetaPvP-Lich"] = { v = "0.1.0", main = "", seen = "2026-11-03 01:00:00" },
    ["Nethergarde-Banshee"] = { v = "0.1.0", main = "Nethergarde-Banshee", seen = "2026-11-03 01:00:00" },
    ["ClassicBetaPvP-Myalt"] = { v = "0.1.0", main = "", seen = "x", mine = true },
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
  check("a HELLO with a bad main or no version is not stored", a.DT.roster()["ClassicBetaPvP-Ghoul"] == nil
    and a.DT.roster()["ClassicBetaPvP-Wight"] == nil and a:db().comms.badHello == 2)
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
  check("three clients: everyone hears everyone", heardA["ClassicBetaPvP-Graverobber"] and heardA["ClassicBetaPvP-Ghoul"]
    and b.DT._roster.heard()["ClassicBetaPvP-Stromham"] and c.DT._roster.heard()["ClassicBetaPvP-Stromham"]
    and c.DT._roster.heard()["ClassicBetaPvP-Graverobber"])
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


-- ---------------------------------------------------------------- fix round 1 (F1, F2, F3)
local function replies(c)
  local n = 0
  for _, s in ipairs(c.sent) do if s.text:find("^1%^HELLO") and s.text:find("r~1", 1, true) then n = n + 1 end end
  return n
end
local ALL = { "Config.lua", "Core.lua", "Guild.lua", "Comms.lua", "Roster.lua", "Alts.lua", "Welcome.lua" }

-- F1: a reload, a relog and a second reload each get exactly one reply.
do
  local w = H.world()
  local a = w:client({ name = "Stromham", guild = G, files = ALL, random = half })
  a:login()
  w:advance(60)
  local b = w:client({ name = "Graverobber", guild = G, files = ALL, random = half })
  b:login()
  w:advance(60)
  check("F1 baseline: A answered B once", replies(a) == 1)
  local b2 = b:reload()
  w:advance(30)
  check("F1: after B reloads, A replies once more", replies(a) == 2)
  b2:slash("who")
  check("F1: after the reload, B's /dt who lists A", b2:said("this session (1): Stromham") ~= nil)
  local b3 = b2:reload()
  w:advance(30)
  check("F1: a second reload gets one more reply, not zero and not two", replies(a) == 3)
  b3:slash("who")
  check("F1: and B lists A again", b3:said("this session (1): Stromham") ~= nil)
  -- a relog: the old session leaves, the same character logs in on the same SavedVariables
  local db = b3:db()
  b3:logout()
  w:advance(120)
  local b4 = w:client({ name = "Graverobber", guild = G, files = ALL, random = half, db = db })
  b4:login()
  w:advance(30)
  check("F1: after a relog, A replies once more", replies(a) == 4)
  b4:slash("who")
  check("F1: after the relog, B's /dt who lists A", b4:said("this session (1): Stromham") ~= nil)
  -- the same session saying HELLO again (e.g. /dt main) still gets no second reply
  b4.DT.hello()
  w:advance(30)
  check("F1: the same session's second HELLO gets no reply", replies(a) == 4)
end

-- F1: the token is validated; no token counts as token 0.
do
  local w = H.world()
  local a = w:client({ name = "Stromham", guild = G, files = ALL, random = half })
  a:login()
  w:advance(60)
  local function inject(text, sender) a:fire("CHAT_MSG_ADDON", "DEADTIRED", text, "GUILD", sender) end
  inject("1^HELLO^main~^s~12ab^v~0.1.0", "Ghoul-ClassicBetaPvP")
  inject("1^HELLO^main~^s~1234567^v~0.1.0", "Wight-ClassicBetaPvP")
  w:advance(30)
  check("F1: a token that isn't 1-6 digits is refused and counted", a:db().comms.badHello == 2
    and replies(a) == 0 and a.DT._roster.heard()["ClassicBetaPvP-Ghoul"] == nil)
  inject("1^HELLO^main~^v~0.1.0", "Ghoul-ClassicBetaPvP")
  w:advance(30)
  check("F1: a HELLO with no token is answered (token 0)", replies(a) == 1
    and a.DT._roster.answered()["ClassicBetaPvP-Ghoul#0"] == true)
  inject("1^HELLO^main~^s~0^v~0.1.0", "Ghoul-ClassicBetaPvP")
  w:advance(30)
  check("F1: ... and is the same session as an explicit s~0", replies(a) == 1)
  check("F1: the session token is 1-6 digits", type(a.DT.sessionToken) == "number"
    and a.DT.sessionToken >= 1 and a.DT.sessionToken <= 999999)
end

-- F2: a wave of 5 logins within 1 s: each client sends at most 2 replies, all list each other.
do
  local w = H.world()
  local cs, rnd = {}, 0
  local function spread() rnd = (rnd * 7 + 3) % 10; return rnd / 10 end
  for i = 1, 5 do
    w:schedule(i * 0.2, function()
      cs[i] = w:client({ name = "Wave" .. string.char(64 + i), guild = G, files = ALL, random = spread })
      cs[i]:login()
    end)
  end
  w:advance(120)
  local most, saved, total = 0, 0, 0
  for i = 1, 5 do
    most = math.max(most, replies(cs[i]))
    total = total + #cs[i].sent
    saved = saved + (cs[i]:db().comms.repliesSaved or 0)
  end
  check("F2: in a wave of 5, each client sends at most 2 replies (most " .. most .. ")", most <= 2)
  check("F2: replies saved are counted (" .. saved .. ")", saved > 0)
  local all = true
  for i = 1, 5 do
    cs[i]:slash("who")
    if not cs[i]:said("this session (4)") then all = false end
  end
  check("F2: every client lists every other (" .. total .. " messages in all)", all)
end

-- ---------------------------------------------------------------- AUD-06: display and sender keys
do
  local w = H.world()
  local a = w:client({ name = "Stromham", realm = "Argent Dawn", guild = G, files = FILES, random = half })
  local DT = a.DT
  check("AUD-06: a sender Name-ArgentDawn and the local Argent Dawn realm give the same key",
    DT.senderKey("Bob-ArgentDawn") == DT.keyOf("Bob", "Argent Dawn") and DT.senderKey("Bob") == "ArgentDawn-Bob"
    and DT.charKey() == "ArgentDawn-Stromham" and DT.senderKey("Stromham-ArgentDawn") == DT.charKey())
  check("AUD-06: display hides the own realm", DT.display("ArgentDawn-Bob") == "Bob"
    and DT.display("Argent Dawn-Bob") == "Bob" and DT.display(DT.charKey()) == "Stromham")
  check("AUD-06: display names another realm", DT.display("Nethergarde-Bob") == "Bob-Nethergarde")
  a.normRealm = false
  check("AUD-06: display hides the own realm on the GetRealmName fallback too", DT.display("ArgentDawn-Bob") == "Bob")
  a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^HELLO^main~Argent Dawn-Bob^v~0.1.0", "GUILD", "Bob-ArgentDawn")
  check("AUD-06: one entry per character; a main sent in the old spelling is stored in the new",
    DT.roster()["ArgentDawn-Bob"] and DT.roster()["ArgentDawn-Bob"].main == "ArgentDawn-Bob"
    and DT.roster()["Argent Dawn-Bob"] == nil)
end

H.finish("roster")
