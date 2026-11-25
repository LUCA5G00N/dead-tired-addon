-- Offline checks for Quests.lua (dt_guildquests, 0.8.0; rulings Q1-Q9).
--   lua5.1 DeadTired/tests/test_quests.lua
-- Stubs per client: C_QuestLog (c.done[id] = true / false / "secret"; c.onQuest[id]), UnitFactionGroup (c.faction),
-- time on the world clock (+ c.skew), and a small map world for the Waypointer (as test_way.lua): Kalimdor
-- (Orgrimmar, the Barrens, Stonetalon) and the Eastern Kingdoms (Tirisfal, Silverpine, Loch Modan, Hillsbrad,
-- Westfall). c.map, c.px, c.py: where the player stands.
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local DAY = 86400
local T0 = 1794000000

local MAPS = {
  [1454] = { name = "Orgrimmar", c = 1, N = 7400, W = -1000, H = 400, Wd = 400 },
  [1413] = { name = "The Barrens", c = 1, N = 5000, W = 0, H = 2000, Wd = 1000 },
  [1442] = { name = "Stonetalon Mountains", c = 1, N = 6000, W = 1500, H = 1000, Wd = 1000 },
  [1420] = { name = "Tirisfal Glades", c = 0, N = 9000, W = 0, H = 1000, Wd = 1000 },
  [1421] = { name = "Silverpine Forest", c = 0, N = 8000, W = 1000, H = 1000, Wd = 1000 },
  [1432] = { name = "Loch Modan", c = 0, N = 3000, W = -2000, H = 1000, Wd = 1000 },
  [1424] = { name = "Hillsbrad Foothills", c = 0, N = 7000, W = 0, H = 1000, Wd = 1000 },
  [1436] = { name = "Westfall", c = 0, N = 1000, W = 2000, H = 1000, Wd = 1000 },
}
local function vec(x, y) return { x = x, y = y, GetXY = function(s) return s.x, s.y end } end

local function stub(c)
  c.done, c.onQuest, c.faction = c.done or {}, c.onQuest or {}, c.faction or "Horde"
  c.map, c.px, c.py, c.facing, c.skew = 1454, 0.5, 0.5, 0, 0
  local env = c.env
  rawset(env, "time", function() return T0 + math.floor(c.world.t - 1000) + c.skew end)
  rawset(env, "C_QuestLog", {
    IsQuestFlaggedCompleted = function(id)
      local v = c.done[id]
      if v == "secret" then local s = {}; c.secrets[s] = true; return s end
      if v == "error" then error("no quest log") end
      return v == true
    end,
    IsOnQuest = function(id) return c.onQuest[id] == true end,
  })
  rawset(env, "UnitFactionGroup", function(u) if u == "player" then return c.faction end end)
  rawset(env, "UiMapPoint", { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, position = vec(x, y) } end })
  rawset(env, "GetPlayerFacing", function() return c.facing end)
  rawset(env, "C_SuperTrack", { SetSuperTrackedUserWaypoint = function() end })
  rawset(env, "C_Map", {
    GetBestMapForUnit = function(u) if u == "player" then return c.map end end,
    GetPlayerMapPosition = function(m) if m ~= c.map then return nil end return vec(c.px, c.py) end,
    GetWorldPosFromMapPos = function(m, v)
      local r = MAPS[m]
      if not r or type(v) ~= "table" then return nil end
      return r.c, vec(r.N - v.y * r.H, r.W - v.x * r.Wd)
    end,
    GetMapChildrenInfo = function(root)
      if root ~= 947 then return {} end
      local out = {}
      for id, r in pairs(MAPS) do out[#out + 1] = { mapID = id, name = r.name, mapType = 3 } end
      return out
    end,
    GetMapInfo = function(m) local r = MAPS[m]; return r and { mapID = m, name = r.name } end,
    CanSetUserWaypointOnMap = function() return true end,
    SetUserWaypoint = function(p) c.wp = p end,
    GetUserWaypoint = function() return c.wp end,
    HasUserWaypoint = function() return c.wp ~= nil end,
    ClearUserWaypoint = function() c.wp = nil end,
  })
end

local function mk(w, o)
  o.realm = o.realm or "CAMWOW EU4 Realm 2 PvP"
  if o.guild == nil then o.guild = G end
  if o.guild == false then o.guild = nil end
  local pre = { done = o.done, onQuest = o.onQuest, faction = o.faction }
  local setup = o.setup
  o.setup = function(c)
    c.done, c.onQuest, c.faction = pre.done, pre.onQuest, pre.faction
    stub(c); if setup then setup(c) end
  end
  local c = w:client(o)
  c:login()
  return c
end

local function sentKind(c, kind)
  local out = {}
  for _, m in ipairs(c.sent) do
    local ok, p = c.DT._comms.decode(m.text)
    if ok == "ok" and p.k == kind then out[#out + 1] = p.d end
  end
  return out
end
local function inject(c, kind, from, d)
  c.DT._comms.inbound("DEADTIRED", c.DT._comms.encode(kind, d, from), "GUILD", from:match("%-(.+)$"))
end
local function bad(c) return c.DT._quests.store().bad end
local function wp(c) local w = c.DT._way.current and c.DT._way.current() return w end

local BAG = { 79007, 79192, 80001, 79980, 79974, 79975, 79976 }
local function bagDone(list) local t = {} for _, i in ipairs(list) do t[BAG[i]] = true end return t end

-- ---------------------------------------------------------------- Q1, Q2: the bag arc
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson", done = {} })
  local steps, finished, nxt = a.DT.questBag()
  check("Q2: 0 steps: not finished; next is step 1", #steps == 7 and not finished and nxt.n == 1)
  check("Q2: step 1 not on it: the Barrens 46, 74", nxt.zone == "The Barrens" and nxt.x == 46 and nxt.y == 74)
  a.onQuest[79007] = true
  local _, _, n1 = a.DT.questBag()
  check("Q2: step 1 on it (IsOnQuest): Westfall 37, 50", n1.zone == "Westfall" and n1.x == 37 and n1.y == 50 and n1.handin)
  a.done = bagDone({ 1, 2 }); a.onQuest = {}
  local _, _, n3 = a.DT.questBag()
  check("Q2: steps 1-2 done: next skips Rekindle to Scramble (4)", n3.n == 4)
  a.done = bagDone({ 1, 2, 3 })
  local _, _, n4 = a.DT.questBag()
  check("Q2: Rekindle done or not changes nothing: still Scramble", n4.n == 4)
  a.done = bagDone({ 1, 2, 4, 5, 6, 7 })
  local s7, fin7, nx7 = a.DT.questBag()
  check("Q2: all but Rekindle: finished, no next step", fin7 and nx7 == nil)
  a.done = bagDone({ 1, 2, 3, 4, 5, 6 })
  local _, fin6 = a.DT.questBag()
  check("Q2: 6 of 7 without step 7: not finished", not fin6)
  a.done = { [79007] = "secret" }
  local s, _, nxs = a.DT.questBag()
  check("Q1: a secret read counts as not done", s[1].state == "unknown" and nxs.n == 1)
  a.done = { [79007] = "error" }
  local se = a.DT.questBag()
  check("Q1: a failed read counts as not done, no error", se[1].state == "unknown" and #a.errors == 0)
  local w2 = H.world()
  local ally = mk(w2, { name = "Pally", full = "Pally Bright", faction = "Alliance", done = { [79008] = true } })
  local sa = ally.DT.questBag()
  check("Q2: an Alliance character's step 1 is 79008", sa[1].id == 79008 and sa[1].state == "done")
  local horde = mk(w2, { name = "Orc", full = "Orc Smash", done = { [79008] = true } })
  check("Q2: a Horde character's step 1 is 79007 (79008 done means nothing)", horde.DT.questBag()[1].state == "no")
end

-- ---------------------------------------------------------------- Q3: the library
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson", done = {} })
  local D = a.DT
  local books, n = D.questBooks()
  check("Q3: 39 books, none done", #books == 39 and n == 0)
  check("Q3: 0 books: 10 more to Friend of the Library", D.questTierLine(0) == "0 books. 10 more to Friend of the Library (10).")
  check("Q3: 9 books", D.questTierLine(9) == "9 books. 1 more to Friend of the Library (10).")
  check("Q3: 10 books: next is 20", D.questTierLine(10) == "10 books. 10 more to Greater Friend of the Library (20).")
  check("Q3: 14 books (the brief's example)", D.questTierLine(14) == "14 books. 6 more to Greater Friend of the Library (20).")
  check("Q3: 39 books: every reward", D.questTierLine(39) == "39 books. Every reward reached.")
  check("Q3: a claimed tier shows", D.questTierLine(14, { 10 }) == "14 books. 6 more to Greater Friend of the Library (20). Claimed: 10.")
  check("Q3: one book", D.questTierLine(1):sub(1, 7) == "1 book.")
  a.done = { [79094] = true, [79095] = true }
  local b2, n2 = D.questBooks()
  check("Q3: two done count", n2 == 2)
  check("Q3: sort: not done first", b2[1].state ~= "done" and b2[38].state == "done" and b2[39].state == "done")
  check("Q3: sort: then by level band ('any' first, blank last)", b2[1].lvl == "any" and b2[37].level == 99)
  local okSort = true
  for i = 2, 37 do
    local p, q = b2[i - 1], b2[i]
    if p.level > q.level or (p.level == q.level and p.name:lower() > q.name:lower()) then okSort = false end
  end
  check("Q3: sort: then by name", okSort)
  a.done = {}
  for _, b in ipairs(D.WAY_BOOKS) do a.done[b[5]] = true end
  a.done[78150] = true
  a:slash("quests library")
  local raw = D.textRecord(D._quests.parts().libHead).raw
  check("Q3: the header, all 39 with tier 10 claimed", raw == "39 books. Every reward reached. Claimed: 10.")
  check("Q3: Antonidas is listed, with its note (nothing hidden)", (function()
    for _, b in ipairs(D.questBooks()) do if b.name:find("Antonidas", 1, true) then return b.note == "Hall of Explorers" end end
  end)())
  local m = D._quests.parts().libModel
  m:filter("potatoes")
  check("Q3: search finds a book", #m:visible() == 1 and m:visible()[1].name == "Undead Potatoes")
  m:filter("zzzz")
  check("Q3: an empty search", #m:visible() == 0)
end

-- ---------------------------------------------------------------- Q4: sharing
local function two(doneA, doneB)
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson", done = doneA or {} })
  local b = mk(w, { name = "Sap", full = "Sap Hapi", done = doneB or {} })
  return w, a, b
end
do
  local w, a, b = two(bagDone({ 1, 2, 4, 5, 6, 7 }), { [79094] = true, [79095] = true })
  w:advance(14)
  check("Q4: nothing at 14 s", #sentKind(a, "QUESTS") == 0)
  w:advance(2)
  local s = sentKind(a, "QUESTS")
  check("Q4: QUESTS 15 s after login", #s == 1 and s[1].bag == "124567" and s[1].lib == "")
  local sb = sentKind(b, "QUESTS")
  check("Q4: lib carries the book IDs", #sb == 1 and sb[1].bag == "" and (sb[1].lib == "79095,79094" or sb[1].lib == "79094,79095"))
  check("Q4: each sees the other on the board", a.DT._quests.store().board[b:key()] ~= nil and b.DT._quests.store().board[a:key()] ~= nil)
  w:advance(600)
  local before = #sentKind(a, "QUESTS")
  check("Q4: never on a timer", before == 1)
  a.DT._modules = a.DT._modules
  a:fire("QUEST_TURNED_IN", 12345)
  w:advance(2)
  check("Q4: someone else's quest turned in: nothing sent", #sentKind(a, "QUESTS") == 1)
  a.done[79096] = true
  a:fire("QUEST_TURNED_IN", 79096)
  w:advance(2)
  local s2 = sentKind(a, "QUESTS")
  check("Q4: one of ours turned in: sent again, with it", #s2 == 2 and s2[2].lib == "79096")
  a:slash("quests share off")
  local s3 = sentKind(a, "QUESTS")
  check("Q4: share off sends QUESTS {off=1}", s3[#s3].off == "1")
  w:advance(1)
  check("Q4: and every board drops you", b.DT._quests.store().board[a:key()] == nil and a.DT._quests.store().board[a:key()] == nil)
  a:fire("QUEST_TURNED_IN", 79096); w:advance(2)
  check("Q4: share off: nothing more sent", #sentKind(a, "QUESTS") == #s3)
  a.DT.set("quests", "enabled", false)
  a:slash("quests share on")
  check("off: a typed share on changes nothing", a.DT.get("quests", "share") == false)
  local before5 = #sentKind(a, "QUESTS")
  a.DT.set("quests", "share", true)
  check("off: switching sharing on sends nothing while the module is off", #sentKind(a, "QUESTS") == before5)
  a.DT.set("quests", "share", false)
  local s4 = sentKind(a, "QUESTS")
  check("Q4: withdraw is sent even with the module off", s4[#s4].off == "1")
  a.DT.set("quests", "enabled", true)
  check("Q4: share is on by default, with a typed form and a description", b.DT.get("quests", "share") == true
    and b.DT.setting("quests", "share").verb == "quests share on|off" and b.DT.setting("quests", "share").desc ~= "")
  local w2, x = two({}, {})
  w2:advance(20)
  check("Q4: nothing done yet: nothing sent", #sentKind(x, "QUESTS") == 0)
end
do
  local w, a, b = two()
  local K = "CAMWOWEU4Realm2PvP-"
  local before = bad(a)
  inject(a, "QUESTS", K .. "Bad One", { bag = "128", lib = "" })
  inject(a, "QUESTS", K .. "Bad Two", { bag = "112", lib = "" })
  inject(a, "QUESTS", K .. "Bad Three", { bag = "12", lib = "79094,99999" })
  inject(a, "QUESTS", K .. "Bad Four", { bag = "12", lib = "79094,79094" })
  inject(a, "QUESTS", K .. "Bad Five", { bag = "12" })
  inject(a, "QUESTS", K .. "Bad Six", { bag = "12", lib = "79094,x" })
  inject(a, "QUESTS", K .. "Bad Seven", { off = "1", bag = "1" })
  check("Q4: bad QUESTS are counted and dropped", bad(a) == before + 7 and a.DT._quests.store().board[K .. "Bad One"] == nil)
  inject(a, "QUESTS", K .. "Good One", { bag = "1234567", lib = "79094" })
  check("Q4: a good one is kept", a.DT._quests.store().board[K .. "Good One"] ~= nil)
  for i = 1, 205 do inject(a, "QUESTS", K .. "Player " .. i, { bag = "1", lib = "" }) end
  local n = 0 for _ in pairs(a.DT._quests.store().board) do n = n + 1 end
  check("Q4: the board caps at 200", n == 200)
  a.DT.set("quests", "enabled", false)
  inject(a, "QUESTS", K .. "While Off", { bag = "1", lib = "" })
  check("off: nothing heard", a.DT._quests.store().board[K .. "While Off"] == nil)
  a.DT.set("quests", "enabled", true)
end
do
  local w, a = two()
  local K = "CAMWOWEU4Realm2PvP-"
  local s = a.DT._quests.store()
  inject(a, "QUESTS", K .. "Old Timer", { bag = "1", lib = "" })
  a.skew = 29 * DAY; a.DT.questBoardRows()
  check("Q4: 29 days unseen: still there", s.board[K .. "Old Timer"] ~= nil)
  a.skew = 31 * DAY; a.DT.questBoardRows()
  check("Q4: 31 days unseen: dropped", s.board[K .. "Old Timer"] == nil)
end

-- ---------------------------------------------------------------- Q6: the board
do
  local w, a = two()
  local K = "CAMWOWEU4Realm2PvP-"
  a:slash("quests")
  check("Q6: the empty board line", a.DT._quests.parts().bagBoard.empty.text == a.DT._quests.BOARD_EMPTY)
  check("Q6: no first finisher yet: only the closing line", a.DT.questFooter("bag") == a.DT._quests.CLOSING)
  inject(a, "QUESTS", K .. "Echo Nightclaw", { bag = "12", lib = "79094,79095,79096" })
  inject(a, "QUESTS", K .. "Liliac High", { bag = "1234567", lib = "79094" })
  inject(a, "QUESTS", K .. "Zed Last", { bag = "1245", lib = "79094" })
  inject(a, "QUESTS", K .. "Ann First", { bag = "1245", lib = "79094" })
  local rows = a.DT.questBoardRows()
  check("Q6: sorted by books, then bag, then name",
    rows[1].name == "Echo Nightclaw" and rows[2].name == "Liliac High" and rows[3].name == "Ann First" and rows[4].name == "Zed Last")
  check("Q6: Bag: 2/7 and Books: 3", rows[1].bag == "Bag: 2/7" and rows[1].lib == "Books: 3")
  check("Q6: Bag: done, with the sleeping-bag icon", rows[2].bag == a.DT._quests.BAG_ICON .. "Bag: done")
  check("Q6: the footer names the first to the bag", a.DT.questFooter("bag") == "First to the bag: Liliac High. " .. a.DT._quests.CLOSING)
  inject(a, "QUESTS", K .. "Liliac High", { off = "1" })
  inject(a, "QUESTS", K .. "Echo Nightclaw", { bag = "1234567", lib = "79094" })
  check("Q6: the first finisher is kept once seen", a.DT.questFooter("bag"):find("Liliac High", 1, true) ~= nil)
  check("Q6: the library tab's footer is the closing line", a.DT.questFooter("lib") == a.DT._quests.CLOSING)
  a:slash("quests library")
  local L = a.DT._quests.parts().libList
  local tip
  for _, r in ipairs(L.rows) do if r.row and r.row.book.id == 79094 then tip = r end end
  if tip then tip.scripts.OnEnter(tip) end
  local tt = a.DT.tooltip()
  local found = false
  for _, l in ipairs(tt.lines or {}) do
    if l == "Handed in by: Ann First, Echo Nightclaw, Zed Last" then found = true end
  end
  check("Q3: a book's tooltip names the guildies who handed it in", found)
end

-- ---------------------------------------------------------------- Q5: the hand-off
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson", done = bagDone({ 1, 2 }) })
  a.DT.questNextStep()
  local cur = a:db().way.current[a:key()]
  check("Q5: Next step sets the waypoint: Scramble, Stonetalon 39.6, 49.8",
    cur and cur.map == 1442 and math.abs(cur.x - 0.396) < 1e-9 and math.abs(cur.y - 0.498) < 1e-9 and cur.label == "Scramble")
  check("Q5: and says so", a:said("Waypoint: Scramble, Stonetalon Mountains 39.6, 49.8.") ~= nil)
  a:slash("quests library")
  local L = a.DT._quests.parts().libList
  for _, r in ipairs(L.rows) do
    if r.row and r.row.book.name == "The Apothecary's Metaphysical Primer" then r.scripts.OnClick(r, "LeftButton") end
  end
  cur = a:db().way.current[a:key()]
  check("Q5: a book row click sets its waypoint (Tirisfal 59.5, 52.3)", cur.map == 1420 and math.abs(cur.x - 0.595) < 1e-9)
  a.c = nil
  a.map, a.px, a.py = 1454, 0.5, 0.5
  a.DT.questNearestBook()
  cur = a:db().way.current[a:key()]
  check("Q5: Nearest book from Orgrimmar: The Lessons of Ta'zo", cur.label == "The Lessons of Ta'zo")
  a.done[79094] = true
  a.DT.questNearestBook()
  cur = a:db().way.current[a:key()]
  check("Q5: Ta'zo done: the next nearest on Kalimdor (Arcanic Systems Manual)", cur.label == "Arcanic Systems Manual")
  a.done = {}
  for _, b in ipairs(a.DT.WAY_BOOKS) do
    if b[2] == "Orgrimmar" or b[2] == "The Barrens" or b[2] == "Stonetalon Mountains" then a.done[b[5]] = true end
  end
  a.DT.questNearestBook()
  check("Q5: none left on this continent: says so", a:said(a.DT._quests.NO_CONTINENT) ~= nil)
  local finished = mk(w, { name = "Done", full = "Done Sleeping", done = bagDone({ 1, 2, 4, 5, 6, 7 }) })
  finished.DT.questNextStep()
  check("Q5: a finished arc has no next step", finished:said("Nowhere left to go") ~= nil)
end

-- ---------------------------------------------------------------- Q7, Q8: the window, quiet
do
  local w, a = two(bagDone({ 1, 2 }))
  w:advance(20)
  local printed = #a.printed
  a:fire("QUEST_TURNED_IN", 79192); w:advance(2)
  check("Q8: nothing prints unasked (a turn-in)", #a.printed == printed)
  a:slash("quests")
  local P = a.DT._quests.parts()
  check("Q7: /dt quests opens the window on the bag tab", a.DT._quests.vp():IsShown() and P.bagFrames[2]:IsShown() and not P.libFrames[2]:IsShown())
  check("Q2: the header names the next step", a.DT.textRecord(P.bagHead).raw == "Next: step 4, Scramble.")
  check("Q2: Rekindle is marked optional", P.bagModel.rows[3].name == "Rekindle (optional)")
  check("Q2: step 5 carries its note", P.bagModel.rows[5].st.note == "Dwarf country. Bring a friend.")
  a.DT._quests.tabs().lib.scripts.OnClick(a.DT._quests.tabs().lib)
  check("Q7: the Library tab", P.libFrames[2]:IsShown() and not P.bagFrames[2]:IsShown())
  check("Q7: Escape closes it", a.namedFrames["DeadTiredViewport_quests"] ~= nil)
  check("fit: no text over its box under any skin", (function()
    local last = a.DT.fitCheck()
    return last[#last]:find(" 0 over,", 1, true) ~= nil and last[#last]:find("measure failures 0", 1, true) ~= nil
  end)())
  local help = a.DT.helpLine()
  check("help: /dt quests is listed", help:find("quests [bag|library|share on|off]", 1, true) ~= nil)
  local w2 = H.world()
  local out = mk(w2, { name = "Stromham", full = "Stromham Hamson", guild = false, done = bagDone({ 1 }) })
  w2:advance(20)
  out:slash("quests")
  check("outside the guild: nothing sent, nothing shown", #out.sent == 0 and #out.printed == 0)
  a.DT.set("quests", "enabled", false)
  a:slash("quests")
  check("off: the verb says off and nothing else", a:said(a.DT._quests.OFF) ~= nil and #a.printed == 1)
  check("nothing errors", #a.errors == 0)
end

-- ---------------------------------------------------------------- the ghost
do
  local w, a = two()
  a:slash("debug ghost quests")
  local rows = a.DT.questBoardRows()
  check("ghost: /dt debug ghost quests puts the Restless Ghost on the board (Bag: 3/7, Books: 3)",
    #rows == 1 and rows[1].name == "Restless Ghost" and rows[1].bag == "Bag: 3/7" and rows[1].lib == "Books: 3")
end

H.finish("quests")
