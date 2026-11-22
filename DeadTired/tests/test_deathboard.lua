-- Offline checks for DeathBoard.lua (dt_deathboard, 0.4.0; rulings L1-L6, 22 Nov 2026).
--   lua5.1 DeadTired/tests/test_deathboard.lua
-- Stubs per client (c.env): time (moves with the world clock, plus c.skew for days that pass without
-- stepping the world), date (os.date on that clock, so DT.stamp and the week's start agree),
-- C_DateAndTime.GetSecondsUntilWeeklyReset (the next of RESET + k weeks; c.noReset leaves it out).
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local R2 = "CAMWOW EU4 Realm 2 PvP"
local K2 = "CAMWOWEU4Realm2PvP-"
local P = "|cff7fa650Dead Tired|r "
local DAY, WEEK = 86400, 7 * 86400
local T0 = 1794000000                       -- time() at the world's start
local RESET = T0 + 3 * DAY                  -- this week ends 3 days in
local SKULL = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t"
local EMPTY = "No deaths shared yet. /dt rip share on to join the board."
local CLOSING = "Only guildies running the addon who share their deaths."
local OLDER = "Older deaths may not be counted."

local function stub(c)
  c.skew = c.skew or 0
  local env = c.env
  local function now() return T0 + math.floor(c.world.t - 1000) + c.skew end
  c.now = now
  rawset(env, "time", function() return now() end)
  rawset(env, "date", function(fmt, t) return os.date(fmt, t or now()) end)
  if not c.opts.noReset then
    rawset(env, "C_DateAndTime", { GetSecondsUntilWeeklyReset = function()
      local r = RESET
      while r <= now() do r = r + WEEK end
      return r - now()
    end })
  end
end

local function mk(w, o)
  o.realm = o.realm or R2
  if o.guild == nil then o.guild = G end
  if o.guild == false then o.guild = nil end
  local setup = o.setup
  o.setup = function(c) stub(c); if setup then setup(c) end end
  return w:client(o)
end

local function sentKind(c, kind)
  local out = {}
  for _, m in ipairs(c.sent) do
    local ok, p = c.DT._comms.decode(m.text)
    if ok == "ok" and p.k == kind then out[#out + 1] = p.d end
  end
  return out
end
local function inject(c, from, d)
  c.DT._comms.inbound("DEADTIRED", c.DT._comms.encode("TALLY", d, from), "GUILD", from:match("%-(.+)$"))
end
local function stamp(t) return os.date("%Y-%m-%d %H:%M:%S", t) end
local function die(c) c:fire("PLAYER_DEAD"); c.world:advance(61) end
local function rows(c) return c.DT.deathRows() end
local function rowOf(c, key) for _, r in ipairs(rows(c)) do if r.key == key then return r end end end
local function tally(n, w, we, hc) return { n = tostring(n), w = tostring(w), we = tostring(we or RESET), hc = hc or "0" } end

local STROM = K2 .. "Stromham Hamson"

-- ---------------------------------------------------------------- L2: the seed
do
  local w = H.world()
  local deaths = {
    { who = STROM, lvl = 10, zone = "Durotar", at = stamp(T0 - 9 * DAY), mine = true },       -- before this week
    { who = STROM, lvl = 11, zone = "Durotar", at = stamp(T0 - 5 * DAY), mine = true },       -- before this week
    { who = STROM, lvl = 12, zone = "The Barrens", at = stamp(T0 - 1 * DAY), mine = true },   -- this week
    { who = K2 .. "Stromalt Hamson", lvl = 5, zone = "Mulgore", at = stamp(T0 - DAY), mine = true },   -- another character
    { who = K2 .. "Echo Nightclaw", lvl = 30, zone = "Duskwood", at = stamp(T0 - DAY), mine = false }, -- heard
  }
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson", db = { schema = 4, crypt = { deaths = deaths } } })
  a:login(); w:advance(30)
  local t = a.DT.deathTally()
  check("L2 seed: the character's own graveyard deaths (3), not another character's or heard ones", t.n == 3)
  check("L2 seed: this week counts those since the last reset (1)", t.w == 1)
  check("L3: we is this week's reset", t.we == RESET)
  check("L2 seed: sharing off, nothing sent at login", #sentKind(a, "TALLY") == 0)
  local db = a:db()
  table.insert(db.crypt.deaths, { who = STROM, lvl = 13, zone = "Ashenvale", at = stamp(T0), mine = true })
  local b = a:reload(); w:advance(30)
  check("L2 seed once: a reload doesn't count the graveyard again", b.DT.deathTally().n == 3)
  die(b)
  check("a death adds 1 to the total and the week", b.DT.deathTally().n == 4 and b.DT.deathTally().w == 2)
  check("a death with sharing off: nothing sent", #sentKind(b, "TALLY") == 0)
  local x = mk(w, { name = "Fresh", full = "Fresh Corpse" })
  x:login(); w:advance(30)
  die(x)
  check("L2: a first-ever death seeds from the graveyard and is counted once", x.DT.deathTally().n == 1 and x.DT.deathTally().w == 1)
  die(x)
  check("...and the next adds one", x.DT.deathTally().n == 2)
end

-- ---------------------------------------------------------------- L1: sending, receiving, withdrawing
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  local b = mk(w, { name = "Echo", full = "Echo Nightclaw" })
  a:login(); b:login(); w:advance(30)
  die(a)
  check("share off: a death sends no TALLY", #sentKind(a, "TALLY") == 0 and b.DT.deathBoard()[a:key()] == nil)
  b.printed = {}
  a:slash("rip share on"); w:advance(2)
  local s = sentKind(a, "TALLY")
  check("share on: the tally is sent at once (n, w, we, hc)", #s == 1 and s[1].n == "1" and s[1].w == "1"
    and s[1].we == tostring(RESET) and s[1].hc == "0")
  check("the guildie keeps it, printing nothing", b.DT.deathBoard()[a:key()] and b.DT.deathBoard()[a:key()].n == 1 and #b.printed == 0)
  die(a); w:advance(2)
  check("each death sends the new tally", #sentKind(a, "TALLY") == 2 and b.DT.deathBoard()[a:key()].n == 2)
  local a2 = a:reload(); w:advance(5)
  local before = #sentKind(a2, "TALLY")
  w:advance(6)
  check("10 s after login the tally is sent", #sentKind(a2, "TALLY") == before + 1)
  a2:slash("rip share off"); w:advance(2)
  local last = sentKind(a2, "TALLY")
  check("share off: TALLY {off=1} sent", last[#last].off == "1" and last[#last].n == nil)
  check("share off: receivers delete the entry, and your own is gone", b.DT.deathBoard()[a2:key()] == nil
    and a2.DT.deathBoard()[a2:key()] == nil)
  check("share off: you're not on your own board", rowOf(a2, a2:key()) == nil)
  -- the off-withdraw happens even while the module is off
  a2:slash("rip share on"); w:advance(2)
  check("share on again: back on the guildie's board", b.DT.deathBoard()[a2:key()] ~= nil)
  a2:slash("set deathboard enabled off")
  local n0 = #sentKind(a2, "TALLY")
  die(a2); w:advance(2)
  check("module off: a death sends nothing", #sentKind(a2, "TALLY") == n0)
  check("module off: your own count still goes on", a2.DT.deathTally().n == 3)
  a2.DT.set("crypt", "share", false); w:advance(2)
  local o = sentKind(a2, "TALLY")
  check("module off: switching share off still withdraws", #o == n0 + 1 and o[#o].off == "1" and b.DT.deathBoard()[a2:key()] == nil)
end

-- ---------------------------------------------------------------- L3: the week
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  local b = mk(w, { name = "Echo", full = "Echo Nightclaw" })
  a:login(); b:login(); w:advance(30)
  a:slash("rip share on"); die(a); die(a); w:advance(2)
  check("this week: 2", a.DT.deathTally().w == 2 and rowOf(b, a:key()).w == 2)
  a.skew = 4 * DAY; b.skew = 4 * DAY
  local t = a.DT.deathTally()
  check("L3 own: past the reset, this week reads 0; the total stays", t.w == 0 and t.n == 2)
  check("L3 own: the week moves on to the next reset", t.we == RESET + WEEK)
  check("L3 received: past its we, the guildie's row reads 0 this week", rowOf(b, a:key()).w == 0 and rowOf(b, a:key()).n == 2)
  die(a); w:advance(2)
  check("L3: a death in the new week counts 1", a.DT.deathTally().w == 1 and rowOf(b, a:key()).w == 1)
  local x = mk(w, { name = "Blind", full = "Blind Wight", noReset = true })
  x:login(); w:advance(30)
  die(x); die(x)
  check("L3 no reset readable: we is 0", x.DT.deathTally().we == 0 and x.DT.weekEnd() == nil)
  x.skew = 30 * DAY
  check("L3 no reset readable: this week is never zeroed", x.DT.deathTally().w == 2)
  inject(b, K2 .. "Old Bones", tally(5, 3, 0))
  b.skew = 20 * DAY
  check("L3 received with we 0: never zeroed (20 days on)", rowOf(b, K2 .. "Old Bones").w == 3)
end

-- ---------------------------------------------------------------- inbound: validated, counted, capped, dropped
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  a:login(); w:advance(30)
  local s = a:db().deathboard
  local BAD = {
    { n = "3", w = "4", we = "1", hc = "0" },                -- w over n
    { n = "100001", w = "0", we = "1", hc = "0" },           -- over the cap
    { n = "-1", w = "0", we = "1", hc = "0" },
    { n = "3.5", w = "1", we = "1", hc = "0" },
    { n = "3", w = "1", we = "soon", hc = "0" },
    { n = "3", w = "1", hc = "0" },                          -- no we
    { n = "3", w = "1", we = "1", hc = "2" },
    { n = "3", w = "1", we = "1" },                          -- no hc
    { off = "1", n = "3" },                                  -- a withdrawal carries nothing else
    { off = "yes" },
  }
  for i, d in ipairs(BAD) do inject(a, K2 .. "Bad " .. string.char(64 + i), d) end
  check("validation: every bad TALLY counted under badTally, none kept", s.badTally == #BAD and next(s.board) == nil)
  inject(a, K2 .. "Good One", tally(100000, 100000))
  check("validation: n = w = 100000 is kept", s.board[K2 .. "Good One"] and s.board[K2 .. "Good One"].n == 100000)
  for i = 1, 205 do
    a.skew = i                                               -- each heard a second apart
    inject(a, K2 .. "Ghoul " .. string.format("%03d", i), tally(i, 0))
  end
  local k = 0
  for _ in pairs(s.board) do k = k + 1 end
  check("cap: the board keeps 200", k == 200)
  check("cap: the ones heard longest ago went; the newest is kept", s.board[K2 .. "Good One"] == nil
    and s.board[K2 .. "Ghoul 001"] == nil and s.board[K2 .. "Ghoul 205"] ~= nil)
  inject(a, K2 .. "Ghoul 205", tally(300, 1))
  check("cap: an update to a known entry evicts nobody", s.board[K2 .. "Ghoul 006"] ~= nil and s.board[K2 .. "Ghoul 205"].n == 300)
  a.skew = 31 * DAY
  inject(a, K2 .. "Recent One", tally(1, 0))
  local r = rows(a)
  check("30 days: entries not heard for 30 days drop off; a fresh one stays", #r == 1 and r[1].key == K2 .. "Recent One")
  local db = { schema = 4, deathboard = { mine = {}, badTally = 0, board = { [K2 .. "Old"] = { n = 1, w = 0, we = 0, hc = false, t = T0 - 31 * DAY },
    [K2 .. "Timeless"] = { n = 1, w = 0, we = 0, hc = false } } } }
  local y = mk(w, { name = "Wight", full = "Wight Pale", db = db })
  check("30 days: dropped at load too, and an entry with no time", next(y.DT.deathBoard()) == nil)
end

-- ---------------------------------------------------------------- L5: the window
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson", setup = function(c) rawset(c.env, "UISpecialFrames", {}) end })
  a:login(); w:advance(30)
  a:slash("deaths")
  local vp, L = a.DT._deathboard.vp(), a.DT._deathboard.list()
  check("L5 /dt deaths opens the window, titled", vp:IsShown() and vp.title.text == "Body Count")
  check("L5 empty state", L.empty.text == EMPTY and L.empty.shown)
  check("L5 the closing line, and the older-deaths note; no zone line with no deaths", vp.footer.text == OLDER .. " " .. CLOSING)
  local esc = false
  for _, n in ipairs(a.env.UISpecialFrames) do if n == "DeadTiredViewport_deaths" then esc = true end end
  check("Escape closes it: its frame is in UISpecialFrames", esc)
  check("its place is remembered (draggable, restored from viewport.deaths)", vp.frame.scripts.OnDragStop ~= nil)
  inject(a, K2 .. "Alpha Ash", tally(5, 2))
  inject(a, K2 .. "Bravo Bone", tally(9, 2))
  inject(a, K2 .. "Delta Dust", tally(9, 2, nil, "1"))
  inject(a, K2 .. "Charlie Crow", tally(4, 3))
  inject(a, K2 .. "Echo Ember", tally(20, 0))
  local order = {}
  for _, r in ipairs(rows(a)) do order[#order + 1] = r.name end
  check("L5 sort: this week, then total, then name; names without realm",
    table.concat(order, ",") == "Charlie Crow,Bravo Bone,Delta Dust,Alpha Ash,Echo Ember")
  local d = rowOf(a, K2 .. "Delta Dust")
  check("L5 hardcore: the skull; others none", d.hc == SKULL and rowOf(a, K2 .. "Alpha Ash").hc == "")
  check("L5 columns read \"9 total\" and \"2 this week\"", d.total == "9 total" and d.week == "2 this week")
  a:slash("deaths")
  local drawn
  for _, b in ipairs(L.rows) do if b.row and b.row.key == K2 .. "Delta Dust" then drawn = b end end
  check("L5 the skull is drawn as the icon, not escaped text", drawn and drawn.cells[1].text == SKULL)
  check("L5 the name is the flex column, class colour by row", L.columns[2].key == "name" and L.columns[2].flex and L.columns[2].rgb == "nameRGB")
  check("not empty now", not L.empty.shown)
  -- L4: the deadliest zone from the graveyard, this week only
  local deaths = a:db().crypt.deaths
  local now = a.now()
  table.insert(deaths, { who = K2 .. "Alpha Ash", zone = "Duskwood", at = stamp(now - DAY), mine = false })
  table.insert(deaths, { who = K2 .. "Bravo Bone", zone = "Duskwood", at = stamp(now - 2 * DAY), mine = false })
  table.insert(deaths, { who = a:key(), zone = "The Barrens", at = stamp(now - DAY), mine = true })
  table.insert(deaths, { who = K2 .. "Echo Ember", zone = "Ashenvale", at = stamp(now - 6 * DAY), mine = false })   -- last week
  table.insert(deaths, { who = K2 .. "Echo Ember", zone = "Ashenvale", at = stamp(now - 5 * DAY), mine = false })   -- last week
  a:slash("deaths")
  check("L4 the footer names this week's deadliest zone first", vp.footer.text == "Duskwood claimed 2 this week. " .. OLDER .. " " .. CLOSING)
  a.skew = 4 * DAY
  a:slash("deaths")
  check("L4 a new week with no deaths yet: no zone line", vp.footer.text == OLDER .. " " .. CLOSING)
  -- fit under every skin, a long name and the skull included
  inject(a, K2 .. "Stromham Hamsonbergensteinovich", tally(99999, 9999, nil, "1"))
  a:slash("deaths")
  local faults = {}
  for _, l in ipairs(a.DT.fitCheck()) do if l:find("deaths", 1, true) then faults[#faults + 1] = l end end
  check("fit: nothing over in the deaths window under any skin", #faults == 0)
  for _, skin in ipairs({ "clean", "deadtired", "forever" }) do
    a.DT.fitSkin = skin; a.DT.restyle()
    check("fit: the board's body is inset above the footer under " .. skin, vp.body.dtHeight > 0 and vp.footerH > 0)
  end
  a.DT.fitSkin = nil; a.DT.restyle()
end

-- ---------------------------------------------------------------- class colour (as 0.3.3)
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson", setup = function(c)
    rawset(c.env, "GetNumGuildMembers", function() return 1 end)
    rawset(c.env, "GetGuildRosterInfo", function(i) if i == 1 then return "Echo Nightclaw", "", 0, 30, "", "", "", "", true, 0, "ROGUE" end end)
    rawset(c.env, "RAID_CLASS_COLORS", { ROGUE = { r = 1, g = 0.96, b = 0.41, colorStr = "fffff569" } })
  end })
  a:login(); w:advance(30)
  inject(a, K2 .. "Echo Nightclaw", tally(3, 1))
  inject(a, K2 .. "Not Listed", tally(3, 1))
  check("class colour from the roster; plain when it can't be placed", rowOf(a, K2 .. "Echo Nightclaw").nameRGB[2] == 0.96
    and rowOf(a, K2 .. "Not Listed").nameRGB == nil)
end

-- ---------------------------------------------------------------- three clients agree
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  local b = mk(w, { name = "Echo", full = "Echo Nightclaw" })
  local c = mk(w, { name = "Liliac", full = "Liliac Bloom" })
  for _, x in ipairs({ a, b, c }) do x:login() end
  w:advance(30)
  for _, x in ipairs({ a, b, c }) do x:slash("rip share on") end
  die(a); die(a); die(a); die(b); die(c); die(c)
  w:advance(2)
  local function board(x)
    local out = {}
    for _, r in ipairs(rows(x)) do out[#out + 1] = r.key .. "=" .. r.n .. "/" .. r.w end
    return table.concat(out, ",")
  end
  local want = a:key() .. "=3/3," .. c:key() .. "=2/2," .. b:key() .. "=1/1"
  check("three clients sharing: the same board on each, sorted", board(a) == want and board(b) == want and board(c) == want)
  a:slash("rip share off"); w:advance(2)
  local want2 = c:key() .. "=2/2," .. b:key() .. "=1/1"
  check("share off removes you from every board", board(a) == want2 and board(b) == want2 and board(c) == want2)
  a.skew, b.skew, c.skew = 4 * DAY, 4 * DAY, 4 * DAY
  local want3 = c:key() .. "=2/0," .. b:key() .. "=1/0"
  check("a week rolling over zeroes this week everywhere", board(a) == want3 and board(b) == want3 and board(c) == want3)
end

-- ---------------------------------------------------------------- outside the guild; the master switch
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  local x = mk(w, { name = "Out", full = "Out Sider", guild = false })
  a:login(); x:login(); w:advance(30)
  x.DT.set("crypt", "share", true)
  die(x); w:advance(12)
  check("outside the guild: no TALLY sent", #x.sent == 0)
  check("outside the guild: the send refuses before Comms, keeping no entry of its own",
    x.DT._deathboard.sendTally() == false and x.DT.deathBoard()[x:key()] == nil)
  inject(x, K2 .. "Echo Nightclaw", tally(3, 1))
  check("outside the guild: nothing received", next(x.DT.deathBoard()) == nil)
  x:slash("deaths")
  check("outside the guild: /dt deaths prints and shows nothing", #x.printed == 0
    and not (x.DT._deathboard.vp() and x.DT._deathboard.vp():IsShown()))

  local m = a.DT.byId.deathboard
  check("deathboard: an On card, default on, with a description", m.optional and a.DT.setting("deathboard", "enabled").label == "On"
    and a.DT.enabled("deathboard") and #a.DT.setting("deathboard", "enabled").desc > 0)
  check("/dt deaths is in /dt help", a.DT.helpLine():find("deaths", 1, true) ~= nil)
  a:slash("set deathboard enabled off")
  inject(a, K2 .. "Echo Nightclaw", tally(3, 1))
  check("module off: inbound ignored", a.DT.deathBoard()[K2 .. "Echo Nightclaw"] == nil)
  inject(a, K2 .. "Echo Nightclaw", { n = "x" })
  check("module off: a bad one isn't even counted", a:db().deathboard.badTally == 0)
  a:slash("deaths")
  check("module off: /dt deaths says so and shows nothing", #a.printed == 1 and a.printed[1] == P .. "deathboard.enabled = off"
    and not (a.DT._deathboard.vp() and a.DT._deathboard.vp():IsShown()))
  a:slash("set deathboard enabled on")
  inject(a, K2 .. "Echo Nightclaw", tally(3, 1))
  a:slash("deaths")
  check("module on again: heard, and the window opens", a.DT.deathBoard()[K2 .. "Echo Nightclaw"] ~= nil
    and a.DT._deathboard.vp():IsShown())
end

H.finish("deathboard")
