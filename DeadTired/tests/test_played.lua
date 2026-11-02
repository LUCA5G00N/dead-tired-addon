-- Offline checks for Played.lua (card 6: the slowest-leveller award).
--   lua5.1 DeadTired/tests/test_played.lua  (from the repo root)
-- Stubs added here, per client, on client.env (card 1's harness is not changed): UnitLevel, and a
-- counting stub for the game's play-time request, which the addon must never call.
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local ALL = {}
for _, f in ipairs(H.FILES) do ALL[#ALL + 1] = f end
for _, f in ipairs({ "Stash.lua", "Played.lua", "EventsList.lua", "Events.lua" }) do ALL[#ALL + 1] = f end
local P = "|cff7fa650Dead Tired|r "
local CLOSING = P .. "Only guildies running the addon who share their /played. Type /played to update yours."
local REQ = "Request" .. "TimePlayed"   -- spelt so that G3's grep over the addon stays clean

local function client(w, opts)
  opts.files = opts.files or ALL
  if opts.guild == nil and not opts.outside then opts.guild = G end
  local c = w:client(opts)
  c.lvl, c.requests = opts.lvl or 30, 0
  c.env.UnitLevel = function(u) if u == "player" then return c.lvl end end
  c.env[REQ] = function() c.requests = c.requests + 1 end
  return c
end
local function sentKind(c, kind)
  local out = {}
  for _, s in ipairs(c.sent) do if s.text:find("^1%^" .. kind .. "%^") then out[#out + 1] = s.text end end
  return out
end

-- ---------------------------------------------------------------- sending
do
  local w = H.world()
  local a = client(w, { name = "Stromham", lvl = 30 })
  local b = client(w, { name = "Graverobber" })
  local p = a:db().played
  check("store: sharing off by default, badPlayed 0", p.share == false and p.badPlayed == 0)
  a:fire("TIME_PLAYED_MSG", 360000, 3600)
  check("sharing off: /played sends and records nothing", #a.sent == 0 and a.DT.playedBoard()[a:key()] == nil)
  a:slash("slowest share on")
  check("/dt slowest share on", p.share == true and a:said("sharing your /played.") ~= nil)
  a:fire("TIME_PLAYED_MSG", 362000, 3600)           -- 100.55... h -> 100.5
  check("sharing on: /played records and sends lvl and hours to one decimal", sentKind(a, "PLAYED")[1] == "1^PLAYED^h~100.5^lvl~30"
    and a.DT.playedBoard()[a:key()].hours == 100.5 and a.DT.playedBoard()[a:key()].lvl == 30)
  w:advance(1)
  check("the guildie stores it, printing nothing", b.DT.playedBoard()[a:key()].hours == 100.5 and #b.printed == 0)
  w:advance(58); a:fire("TIME_PLAYED_MSG", 400000, 3600)
  check("a second /played inside 60 s sends nothing", #sentKind(a, "PLAYED") == 1)
  w:advance(2); a:fire("TIME_PLAYED_MSG", 400000, 3600)
  check("after 60 s it sends again", #sentKind(a, "PLAYED") == 2 and sentKind(a, "PLAYED")[2] == "1^PLAYED^h~111.1^lvl~30")
  w:advance(61); a.lvl = nil; a:fire("TIME_PLAYED_MSG", 400000, 3600)
  check("level unreadable: nothing", #sentKind(a, "PLAYED") == 2)
  a.lvl = 30; a:fire("TIME_PLAYED_MSG", nil, 3600)
  check("total unreadable: nothing", #sentKind(a, "PLAYED") == 2)
  a:fire("TIME_PLAYED_MSG", 7200, 3600)
  check("whole hours are sent with .0", sentKind(a, "PLAYED")[3] == "1^PLAYED^h~2.0^lvl~30")
  a:slash("slowest share off")
  w:advance(61); a:fire("TIME_PLAYED_MSG", 9000, 3600)
  check("/dt slowest share off: nothing sent", p.share == false and #sentKind(a, "PLAYED") == 3)
  local x = client(w, { name = "Spy", guild = "Alliance Spies" })
  x:db().played.share = true
  x:fire("TIME_PLAYED_MSG", 9000, 3600)
  check("a non-member sends nothing", #x.sent == 0)
end

-- ---------------------------------------------------------------- validation
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local function inject(t, from) a:fire("CHAT_MSG_ADDON", "DEADTIRED", t, "GUILD", (from or "Ghoul") .. "-ClassicBetaPvP") end
  local bad = { "1^PLAYED^h~10^lvl~0", "1^PLAYED^h~10^lvl~101", "1^PLAYED^h~10^lvl~x", "1^PLAYED^h~10",
    "1^PLAYED^lvl~10", "1^PLAYED^h~-1^lvl~10", "1^PLAYED^h~1.25^lvl~10", "1^PLAYED^h~100001^lvl~10", "1^PLAYED^h~abc^lvl~10" }
  for _, t in ipairs(bad) do inject(t) end
  check("each invalid PLAYED is counted in badPlayed and not stored", a:db().played.badPlayed == #bad
    and next(a.DT.playedBoard()) == nil)
  inject("1^PLAYED^h~100000^lvl~100")
  check("the edges are valid", a.DT.playedBoard()["Classic Beta PvP-Ghoul"].hours == 100000)
end

-- ---------------------------------------------------------------- the award
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  a:slash("slowest")
  check("no contenders: the empty text, then the closing line", a.printed[1] == P .. "No contenders. Everyone's either fast or shy."
    and a.printed[2] == CLOSING and #a.printed == 2)
  local function inject(name, lvl, h) a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^PLAYED^h~" .. h .. "^lvl~" .. lvl, "GUILD", name .. "-ClassicBetaPvP") end
  inject("Sloth", 10, "50.0")      -- 5.0 h/level
  inject("Snail", 20, "100.0")     -- 5.0 h/level: ties with Sloth, sorts by name
  inject("Hare", 60, "60.0")       -- 1.0
  inject("Newbie", 1, "99.0")      -- level 1: excluded
  inject("Turtle", 30, "210.0")    -- 7.0
  inject("Mole", 40, "120.0")      -- 3.0
  inject("Owl", 50, "100.0")       -- 2.0
  a:slash("slowest")
  check("the award line, exactly", a.printed[1]
    == P .. "The Crypt Keeper's Award for Glacial Progress goes to Turtle: 7.0 hours a level (level 30, 210.0 h played).")
  check("the list, a tie broken by name", a.printed[2] == P .. "2. Sloth: 5.0 h/level (level 10)"
    and a.printed[3] == P .. "3. Snail: 5.0 h/level (level 20)" and a.printed[4] == P .. "4. Mole: 3.0 h/level (level 40)"
    and a.printed[5] == P .. "5. Owl: 2.0 h/level (level 50)")
  check("at most 5, level 1 left out, then the closing line", a.printed[6] == CLOSING and #a.printed == 6
    and not a:printedText():find("Newbie", 1, true))
  a:slash("slowest share")
  check("/dt slowest share shows the setting", a:said("sharing your /played is off.") ~= nil)
  a:slash("")
  check("the help lists slowest [share on/off]", a:said("slowest [share on/off]") ~= nil)
end

-- ---------------------------------------------------------------- never asks the game for play time
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local b = client(w, { name = "Graverobber" })
  a:db().played.share = true
  a:login(); b:login()
  for i = 1, 24 do
    a:fire("PLAYER_ENTERING_WORLD", false, false)
    a:fire("PLAYER_LEVEL_UP", 31)
    a:slash("slowest"); a:slash("slowest share on")
    w:advance(3600)
  end
  check("a login and a day of ticks, zoning, level-ups and verbs: the play-time request is never called",
    a.requests == 0 and b.requests == 0)
  check("and nothing was sent without a /played", #sentKind(a, "PLAYED") == 0)
end

-- ---------------------------------------------------------------- byte budget
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local m = a.DT._comms.encode("PLAYED", { lvl = "100", h = "100000.0" })
  print("played: longest PLAYED is " .. #m .. " bytes")
  check("the longest PLAYED is at most 250 bytes", #m <= 250)
end

H.finish("played")
