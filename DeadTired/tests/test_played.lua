-- Offline checks for Played.lua (card 6, the slowest-leveller award, ported from rc3 in Port 2):
-- rc3's checks on full-name keys, R-P2-1 (/dt played, no hook), the board in a viewport.
--   lua5.1 DeadTired/tests/test_played.lua
-- Stubs per client (c.env): UnitLevel (c.lvl), RequestTimePlayed (counted in c.requests; c.noRequest
-- leaves it out, c.requestFails makes it error) and the game's own /played command
-- (SlashCmdList.PLAYED, counted in c.typed), time (c.now, which moves with the world clock).
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local R2 = "CAMWOW EU4 Realm 2 PvP"
local K2 = "CAMWOWEU4Realm2PvP-"
local P = "|cff7fa650Dead Tired|r "
local CLOSING = "Only guildies running the addon who share their /played. Type /dt played to update yours."
local EMPTY = "No contenders. Everyone's either fast or shy."

local function stub(c)
  c.lvl, c.requests, c.typed, c.skew = 30, 0, 0, 0
  local env = c.env
  -- time() moves with the world clock, plus c.skew (days pass without stepping the world through them)
  rawset(env, "time", function() return 1794000000 + math.floor(c.world.t - 1000) + c.skew end)
  rawset(env, "UnitLevel", function(u) if u == "player" then return c.lvl end end)
  if not c.opts.noRequest then
    rawset(env, "RequestTimePlayed", function()
      if c.opts.requestFails then error("no") end
      c.requests = c.requests + 1
    end)
  end
  rawget(env, "SlashCmdList").PLAYED = function() c.typed = c.typed + 1 end   -- the game's /played
end

local function mk(w, o)
  o.realm = o.realm or R2
  if o.guild == nil then o.guild = G end
  local setup = o.setup
  o.setup = function(c) stub(c); if setup then setup(c) end end
  return w:client(o)
end

-- The player types /dt played; the game answers with TIME_PLAYED_MSG a moment later.
local function dtPlayed(c, total, lvlTime) c:slash("played"); c:fire("TIME_PLAYED_MSG", total, lvlTime) end
-- A plain /played: the game's own command runs and the game answers; DT asked for nothing.
local function plainPlayed(c, total) c.env.SlashCmdList.PLAYED(""); c:fire("TIME_PLAYED_MSG", total, 3600) end
local function sentKind(c, kind)
  local out = {}
  for _, m in ipairs(c.sent) do
    local ok, p = c.DT._comms.decode(m.text)
    if ok == "ok" and p.k == kind then out[#out + 1] = p.d end
  end
  return out
end
local function inject(c, from, d)
  c.DT._comms.inbound("DEADTIRED", c.DT._comms.encode("PLAYED", d, from), "GUILD", from:match("%-(.+)$"))
end

-- ---------------------------------------------------------------- sending
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  local b = mk(w, { name = "Echo", full = "Echo Nightclaw" })
  a:login(); b:login(); w:advance(30)
  local p = a:db().played
  local DT = a.DT
  check("store: sharing off by default, badPlayed 0, one board", DT.get("played", "share") == false and p.badPlayed == 0
    and type(p.board) == "table" and DT.playedBoard() == p.board)
  check("the setting is a card with a typed path", DT.setting("played", "share").verb == "slowest share on|off")
  dtPlayed(a, 360000, 3600); w:advance(1)
  check("sharing off: /dt played records and sends nothing", #sentKind(a, "PLAYED") == 0 and DT.playedBoard()[a:key()] == nil)
  check("sharing off: /dt played still asks the game (its played lines print)", a.requests == 1)
  a:slash("slowest share on")
  check("/dt slowest share on (the line names /dt played)", DT.get("played", "share") == true
    and a.printed[1] == P .. "sharing your /played. Type /dt played to put yourself on the board.")
  dtPlayed(a, 362000, 3600); w:advance(1)
  local s = sentKind(a, "PLAYED")[1]
  check("sharing on: /dt played records and sends lvl and hours to one decimal", s and s.h == "100.5" and s.lvl == "30"
    and DT.playedBoard()[a:key()].hours == 100.5 and DT.playedBoard()[a:key()].lvl == 30)
  check("the guildie stores it, printing nothing", b.DT.playedBoard()[a:key()] and b.DT.playedBoard()[a:key()].hours == 100.5
    and not b:said("played"))
  w:advance(57); dtPlayed(a, 400000, 3600); w:advance(1)
  check("a second /dt played inside 60 s sends nothing", #sentKind(a, "PLAYED") == 1)
  w:advance(2); dtPlayed(a, 400000, 3600); w:advance(1)
  check("after 60 s it sends again", #sentKind(a, "PLAYED") == 2 and sentKind(a, "PLAYED")[2].h == "111.1")
  w:advance(61); a.lvl = nil; dtPlayed(a, 400000, 3600); w:advance(1)
  check("level unreadable: nothing", #sentKind(a, "PLAYED") == 2)
  a.lvl = 30; dtPlayed(a, nil, 3600); w:advance(1)
  check("total unreadable: nothing", #sentKind(a, "PLAYED") == 2)
  dtPlayed(a, 7200, 3600); w:advance(1)
  check("whole hours are sent with .0", sentKind(a, "PLAYED")[3].h == "2.0")
  a:slash("slowest share off"); w:advance(1)
  w:advance(61); dtPlayed(a, 9000, 3600); w:advance(1)
  local all = sentKind(a, "PLAYED")
  check("/dt slowest share off: no play time sent after it, only the one withdrawal (F9)", DT.get("played", "share") == false
    and #all == 4 and all[4].off == "1" and all[4].lvl == nil and all[4].h == nil)
  local x = mk(w, { name = "Spy", full = "Spy Glass", guild = "Alliance Spies" })
  x:login()
  x.DT.set("played", "share", true)
  x:fire("TIME_PLAYED_MSG", 9000, 3600); x.DT._played = x.DT._played
  w:advance(1)
  check("a non-member sends nothing", #x.sent == 0)
end

-- ---------------------------------------------------------------- R-P2-1: only after /dt played
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  local b = mk(w, { name = "Echo", full = "Echo Nightclaw" })
  a:login(); b:login(); w:advance(30)
  local function n() return #sentKind(a, "PLAYED") end
  a:slash("slowest share on")
  local function ownHooks(c)
    local n = 0
    for _, h in ipairs(c.hooks) do if h.key == "PLAYED" or h.tbl == c.env.SlashCmdList then n = n + 1 end end
    return n
  end
  check("R-P2-1: no hook on /played or any slash command (the libraries' own hooks aside)", ownHooks(a) == 0 and ownHooks(b) == 0)
  check("R-P2-1: the game's /played is left as it was", type(a.env.SlashCmdList.PLAYED) == "function"
    and (function() local before = a.typed; a.env.SlashCmdList.PLAYED(""); return a.typed == before + 1 end)())
  a:fire("TIME_PLAYED_MSG", 36000, 3600); w:advance(1)
  check("R-P2-1: a TIME_PLAYED_MSG nobody asked for sends nothing", n() == 0 and a.DT.playedBoard()[a:key()] == nil)
  plainPlayed(a, 36000); w:advance(1)
  check("R-P2-1: a plain /played is ignored: nothing recorded or sent", n() == 0 and a.DT.playedBoard()[a:key()] == nil)
  a:slash("played")
  check("R-P2-1: /dt played asks the game, once (RequestTimePlayed)", a.requests == 1 and a.DT._played.asked() ~= nil)
  w:advance(9.5); a:fire("TIME_PLAYED_MSG", 36000, 3600); w:advance(0.4)
  check("R-P2-1: the report inside 10 s: recorded and sent", n() == 1 and a.DT.playedBoard()[a:key()].hours == 10)
  check("R-P2-1: the request is used up by that report", a.DT._played.asked() == nil)
  w:advance(1); a:fire("TIME_PLAYED_MSG", 36000, 3600); w:advance(1)
  check("R-P2-1: a second report after it: nothing", n() == 1)
  w:advance(61)
  a:slash("played"); w:advance(11); a:fire("TIME_PLAYED_MSG", 36000, 3600); w:advance(1)
  check("R-P2-1: the report 11 s after /dt played: nothing", n() == 1)
  check("R-P2-1: and that stale request is gone too", a.DT._played.asked() == nil)
  w:advance(61); a:fire("TIME_PLAYED_MSG", 36000, 3600); w:advance(1)
  check("R-P2-1: still nothing later without asking", n() == 1)
  dtPlayed(a, 40000, 3600); w:advance(1)
  check("R-P2-1: /dt played again: sent", n() == 2)
  -- another addon asks the game for play time: the report that follows is ignored
  w:advance(61)
  a.env.RequestTimePlayed()
  a:fire("TIME_PLAYED_MSG", 50000, 3600); w:advance(1)
  check("R-P2-1: a report someone else asked for: ignored", n() == 2)
  w:advance(1)
  check("R-P2-1: the guildie got only the asked-for ones", b.DT.playedBoard()[a:key()].hours == 11.1)
  check("R-P2-1: DT asked the game only on /dt played", a.requests == 4 and b.requests == 0)
  -- no RequestTimePlayed on this client, or it errors
  for _, how in ipairs({ "noRequest", "requestFails" }) do
    local c = mk(w, { name = "Nope" .. how, full = "Nope " .. how, [how] = true })
    c:login(); w:advance(30)
    c.DT.set("played", "share", true)
    c:slash("played")
    check("R-P2-1: " .. how .. ": one line says so", #c.printed == 1
      and c.printed[1] == P .. "The client won't say how long you've played. Nothing recorded.")
    c:fire("TIME_PLAYED_MSG", 36000, 3600); w:advance(1)
    check("R-P2-1: " .. how .. ": nothing is sent", #sentKind(c, "PLAYED") == 0)
  end
end

-- ---------------------------------------------------------------- validation
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  a:login()
  local bad = { { h = "10", lvl = "0" }, { h = "10", lvl = "101" }, { h = "10", lvl = "x" }, { h = "10" },
    { lvl = "10" }, { h = "-1", lvl = "10" }, { h = "1.25", lvl = "10" }, { h = "100001", lvl = "10" }, { h = "abc", lvl = "10" } }
  for _, d in ipairs(bad) do inject(a, K2 .. "Ghoul Grim", d) end
  check("each invalid PLAYED is counted in badPlayed and not stored", a:db().played.badPlayed == #bad
    and next(a.DT.playedBoard()) == nil)
  inject(a, K2 .. "Ghoul Grim", { h = "100000", lvl = "100" })
  check("the edges are valid", a.DT.playedBoard()[K2 .. "Ghoul Grim"].hours == 100000)
end

-- ---------------------------------------------------------------- the award and the board
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  a:login()
  a:slash("slowest")
  local vp, L = a.DT._played.vp(), a.DT._played.list()
  check("no contenders: rc3's empty line printed, and in the board", a.printed[1] == P .. EMPTY and #a.printed == 1
    and vp:IsShown() and L.empty.shown and L.empty.text == EMPTY)
  check("the closing line under the board", vp.note.text == CLOSING)
  check("the board is a DT viewport: Escape closes it (R-P2-2)", vp.name == "DeadTiredViewport_slowest")
  local function ing(name, lvl, h) inject(a, K2 .. name, { h = h, lvl = tostring(lvl) }) end
  ing("Sloth Slow", 10, "50.0")      -- 5.0 h/level
  ing("Snail Shell", 20, "100.0")    -- 5.0: ties with Sloth, sorts by name
  ing("Hare Quick", 60, "60.0")      -- 1.0
  ing("Newbie New", 1, "99.0")       -- level 1: excluded
  ing("Turtle Shell", 30, "210.0")   -- 7.0
  ing("Mole Dig", 40, "120.0")       -- 3.0
  ing("Owl Night", 50, "100.0")      -- 2.0
  a:slash("slowest")
  check("the award line, exactly (R-P5: the name without realm)", #a.printed == 1 and a.printed[1]
    == P .. "The Crypt Keeper's Award for Glacial Progress goes to Turtle Shell: 7.0 hours a level (level 30, 210.0 h played).")
  local rows = a.DT.slowestRows()
  check("the board, a tie broken by name", rows[2].name == "Sloth Slow" and rows[2].rateText == "5.0 h/level"
    and rows[2].lvlText == "level 10" and rows[3].name == "Snail Shell" and rows[4].name == "Mole Dig" and rows[5].name == "Owl Night")
  check("level 1 left out; the rest all listed", #rows == 6 and not (function()
    for _, r in ipairs(rows) do if r.name:find("Newbie", 1, true) then return true end end end)())
  check("the board shows them", L.rows[1].shown and L.rows[1].row.name == "Turtle Shell" and not L.empty.shown)
  vp.search:SetText("shell"); vp.search.scripts.OnTextChanged(vp.search)
  local shown = 0
  for _, b in ipairs(L.rows) do if b.shown then shown = shown + 1 end end
  check("the board is searchable", shown == 2)
  a:slash("slowest share")
  check("/dt slowest share shows the setting", a:said("sharing your /played is off.") ~= nil)
  a:slash("")
  check("the help lists slowest [share on/off] and played", a:said("slowest [share on/off]") ~= nil and a:said("| played") ~= nil)
end

-- ---------------------------------------------------------------- never asks the game unasked
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  local b = mk(w, { name = "Echo", full = "Echo Nightclaw" })
  a.DT.set("played", "share", true)
  a:login(); b:login()
  for i = 1, 24 do
    a:fire("PLAYER_ENTERING_WORLD", false, false)
    a:fire("PLAYER_LEVEL_UP", 31)
    a:slash("slowest"); a:slash("slowest share on")
    w:advance(120); a.skew = i * 3600
  end
  check("a login and a day of ticks, zoning, level-ups and verbs: the play-time request is never called",
    a.requests == 0 and b.requests == 0)
  check("and nothing was sent without /dt played", #sentKind(a, "PLAYED") == 0)
end

-- ---------------------------------------------------------------- fix round 1 (F9)
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  local b = mk(w, { name = "Grave", full = "Grave Robber" })
  local c = mk(w, { name = "Ghoul", full = "Ghoul Grim" })
  a:login(); b:login(); c:login(); w:advance(30)
  local BK = K2 .. "Grave Robber"
  b:slash("slowest share on")
  dtPlayed(b, 360000, 3600)
  w:advance(1)
  check("F9 baseline: B's play time is on A's and C's boards, with the time received",
    a.DT.playedBoard()[BK] ~= nil and c.DT.playedBoard()[BK] ~= nil and a.DT.playedBoard()[BK].t == a.env.time() - 1)
  c:logout()            -- C is offline when B withdraws
  b:slash("slowest share off")
  check("F9: the share-off line, exactly",
    b.printed[1] == P .. "not sharing your /played. Your entry is being withdrawn from guildies' boards.")
  check("F9: and B's own entry leaves B's board", b.DT.playedBoard()[BK] == nil)
  w:advance(1)
  local s = sentKind(b, "PLAYED")
  check("F9: share off sends one PLAYED with off=1 and nothing else", #s == 2 and s[2].off == "1" and s[2].h == nil)
  check("F9: a guildie online deletes B's entry on off=1", a.DT.playedBoard()[BK] == nil)
  a:slash("slowest")
  check("F9: and B is off A's award", a.printed[1] == P .. EMPTY)
  -- switching off from the settings card withdraws too (one path: DT.set's onChange)
  w:advance(61); b.DT.set("played", "share", true); dtPlayed(b, 360000, 3600); w:advance(61)
  b.DT.set("played", "share", false); w:advance(1)
  check("F9: off from the card (or /dt set) withdraws as well", a.DT.playedBoard()[BK] == nil and #sentKind(b, "PLAYED") == 4)
  -- malformed withdrawals are counted and change nothing
  local bad0 = a:db().played.badPlayed
  a.DT.playedBoard()[K2 .. "Wight Pale"] = { lvl = 20, hours = 50, t = a.env.time() }
  for _, d in ipairs({ { off = "2" }, { h = "5.0", lvl = "20", off = "1" }, { off = "" } }) do inject(a, K2 .. "Wight Pale", d) end
  check("F9: a withdrawal with another value or other fields is counted bad, nothing deleted",
    a:db().played.badPlayed == bad0 + 3 and a.DT.playedBoard()[K2 .. "Wight Pale"] ~= nil)
  -- C, offline at the time, keeps the entry until it ages out: 30 days
  local cdb = c:db()
  cdb.played.board[BK] = { lvl = 30, hours = 100, t = a.env.time() }
  local c2 = mk(w, { name = "Ghoul", full = "Ghoul Grim", db = cdb, setup = function(x) x.skew = 29 * 86400 end })
  c2:login()
  check("F9: at 29 days an offline guildie still has the entry", c2.DT.playedBoard()[BK] ~= nil)
  c2:slash("slowest")
  check("F9: ... and still shows it", c2:said("Grave Robber") ~= nil)
  c2.skew = 30 * 86400 + 10
  c2:slash("slowest")
  check("F9: past 30 days, /dt slowest drops it before showing", c2.DT.playedBoard()[BK] == nil and c2.printed[1] == P .. EMPTY)
end
do
  -- at load: an entry older than 30 days, and one with no time, go
  local w = H.world()
  local now = 1794000000
  local db = { schema = 3, played = { badPlayed = 0, board = {
    [K2 .. "Old One"] = { lvl = 30, hours = 100, t = now - 31 * 86400 },
    [K2 .. "No Time"] = { lvl = 30, hours = 100 },
    [K2 .. "Fresh One"] = { lvl = 30, hours = 100, t = now - 86400 } } } }
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson", db = db })
  local b = a.DT.playedBoard()
  check("F9: at load, an entry over 30 days old is dropped", b[K2 .. "Old One"] == nil)
  check("F9: at load, an entry with no time is dropped", b[K2 .. "No Time"] == nil)
  check("F9: at load, a recent entry stays", b[K2 .. "Fresh One"] ~= nil)
  local db2 = { schema = 3, played = { badPlayed = 0, board = { [K2 .. "Old One"] = { lvl = 30, hours = 100, t = now - 31 * 86400 } } } }
  local x = mk(w, { name = "Wight", full = "Wight Pale", db = db2, setup = function(c) rawset(c.env, "time", function() error("no clock") end) end })
  check("F9: with no readable clock nothing is dropped", x.DT.playedBoard()[K2 .. "Old One"] ~= nil)
end

H.finish("played")
