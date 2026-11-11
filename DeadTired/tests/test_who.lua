-- Offline checks for Who.lua: HELLO both ways, self never listed as someone else, the rate limits,
-- the LDB count, seen before, the switches.  lua5.1 DeadTired/tests/test_who.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"

local function kinds(c)
  local n = {}
  for _, m in ipairs(c.sent) do
    local ok, p = c.DT._comms.decode(m.text)
    if ok == "ok" then n[p.k] = (n[p.k] or 0) + 1 end
  end
  return n
end

local LIL = { name = "Lilbit", full = "Lilbit High", realm = "CAMWOW EU4 Realm 4 PvP" }
local function mk(w, who, db)
  return w:client({ name = who.name, full = who.full, realm = who.realm, guild = G, db = db, random = function() return 0.5 end })
end

-- a is loaded at once; b() loads the second client (a client is in the world from its load on).
local function pair(o)
  o = o or {}
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson", realm = "CAMWOW EU4 Realm 2 PvP" }, o.adb)
  local b
  local function getb() if not b then b = mk(w, LIL, o.bdb) end return b end
  return w, a, getb
end

-- The rows other than your own (R-P6 puts yours first, marked; checked on its own below).
local function others(c)
  local out = {}
  for _, r in ipairs(c.DT.whoRows()) do if not r.you then out[#out + 1] = r end end
  return out
end
local function names(c)
  local out = {}
  for _, r in ipairs(others(c)) do out[#out + 1] = r.name .. "/" .. r.when end
  return table.concat(out, ", ")
end

-- ---------------------------------------------------------------- HELLO both ways
do
  local w, a, getb = pair()
  a:login()
  w:advance(10)
  check("first one in: says hello once after login, hears nobody", kinds(a).HELLO == 1 and names(a) == "")
  local b = getb(); b:login()
  w:advance(10)
  check("the second hears the first's answer", names(b) == "Stromham Hamson/this session")
  check("the first hears the second's login hello", names(a) == "Lilbit High/this session")
  check("each lists the other once, never itself", #others(a) == 1 and #others(b) == 1)
  check("version shown", others(a)[1].v == "0.3.0")
  check("the bar object: DT: 1 online", a.DT.objects[2].obj.text == "DT: 1 online" and a.DT.whoCount() == 1)
  check("no reply storm: one login hello and one answer from the first", kinds(a).HELLO == 2 and kinds(b).HELLO == 1)
end

-- ---------------------------------------------------------------- self never listed as someone else
do
  local w, a, getb = pair({ adb = { schema = 3, who = { seen = {
    ["CAMWOWEU4Realm2PvP-Stromham Hamson"] = { v = "0.2.0-fw1" },     -- my own key, from an older session
    ["CAMWOWEU4Realm2PvP-stromham hamson"] = { v = "0.1.0" },        -- and in another case
    ["CAMWOWEU4Realm4PvP-Lilbit High"] = { v = "0.2.0-fw1" } } } } })
  a:login()
  check("self in the saved list is never shown", names(a) == "Lilbit High/seen before")
  a.DT._who.record("CAMWOWEU4Realm2PvP-Stromham Hamson", { v = "x" })
  check("self heard directly is never recorded", a.DT.whoCount() == 0 and a.DT._who.session()["CAMWOWEU4Realm2PvP-Stromham Hamson"] == nil)
  -- my own HELLO echoed back by the GUILD channel
  a.DT.send("HELLO", { v = "0.2.0-fw1" })
  w:advance(3)
  check("own GUILD echo: not listed", a.DT.whoCount() == 0 and #others(a) == 1)
end

-- ---------------------------------------------------------------- rate limits
do
  local w, a, getb = pair()
  a:login(); local b = getb(); b:login()
  w:advance(20)                        -- past both login hellos' 10 s answer limit
  local before = kinds(a).WHO or 0
  a:slash("who")
  a:slash("who")
  a:slash("who")
  w:advance(5)
  check("/dt who asks once", (kinds(a).WHO or 0) - before == 1)
  check("/dt who opens the list", a:frame("DeadTiredViewport_who").shown)
  local helloB = kinds(b).HELLO
  check("the other answers the ask", helloB == 2)
  w:advance(10)
  a:slash("who")
  w:advance(5)
  check("not again within 30 s", (kinds(a).WHO or 0) - before == 1)
  w:advance(20)
  a:slash("who")
  w:advance(5)
  check("again after 30 s", (kinds(a).WHO or 0) - before == 2 and kinds(b).HELLO == 3)
  -- answers are rate-limited per answerer: two asks within 10 s get one answer
  local c = w:client({ name = "Ghoul", full = "Ghoul Grim", guild = G, random = function() return 0.5 end })
  c:login()
  w:advance(20)                        -- c's login hello and its answers are past
  local n = kinds(b).HELLO
  c:slash("who")
  a.DT._who.reset(); a:slash("who")
  w:advance(5)
  check("two asks within 10 s: one answer each", kinds(b).HELLO - n == 1)
end

-- ---------------------------------------------------------------- seen before, across a reload
do
  local w, a, getb = pair()
  a:login(); local b = getb(); b:login()
  w:advance(12)
  b:logout()
  local r = a:reload()
  w:advance(10)
  check("after a reload: heard before, not this session", names(r) == "Lilbit High/seen before"
    and r.DT.whoCount() == 0 and r.DT.objects[2].obj.text == "DT: 0 online")
end

-- ---------------------------------------------------------------- the list window
do
  local w, a, getb = pair()
  local c = nil
  a:login(); local b = getb(); b:login()
  c = w:client({ name = "Ghoul", full = "Ghoul Grim", guild = G, random = function() return 0.5 end })
  c:login()
  w:advance(12)
  a:slash("who")
  local vp = a.DT.viewports.who
  check("the list window says only DT runners show", (function()
    for _, f in ipairs(a.frames) do if f.text == "Only guildies running Dead Tired show here." then return true end end
  end)())
  vp.search:SetText("LIL"); vp.search.scripts.OnTextChanged(vp.search)
  check("searchable: case-insensitive", #a.DT.viewports.who and #(function() local n = {} for _, b2 in ipairs(a.frames) do
    if b2._type == "Button" and b2.row and b2.shown then n[#n + 1] = b2 end end return n end)() == 1)
end

-- ---------------------------------------------------------------- switches
do
  local w, a, getb = pair({ adb = { schema = 3, settings = { who = { hello = false } } } })
  a:login()
  w:advance(10)
  check("who.hello off: no hello at login", (kinds(a).HELLO or 0) == 0)
  local b = getb(); b:login()
  w:advance(10)
  check("who.hello off: no answer either", (kinds(a).HELLO or 0) == 0 and names(b) == "")
  check("but it still hears others", names(a) == "Lilbit High/this session")
end

do
  local w, a, getb = pair({ adb = { schema = 3, settings = { who = { enabled = false } } } })
  a:login()
  local n = 0
  for _ in pairs(a.DT.byId.who.frame.events) do n = n + 1 end
  check("who switched off: no events registered", n == 0 and not a.DT.byId.who.active)
  local b = getb(); b:login()
  w:advance(12)
  check("who off: sends nothing, hears nothing", (kinds(a).HELLO or 0) == 0 and names(a) == "" and names(b) == "")
  a:slash("who")
  check("/dt who while off says so", a:said("who.enabled = off") ~= nil and (kinds(a).WHO or 0) == 0)
  a:slash("set who enabled on")
  w:advance(10)
  check("switched on: says hello", kinds(a).HELLO == 1 and names(b) ~= "")
end

-- ---------------------------------------------------------------- Port 1: R-P6, R-P5, empty state, rows
do
  local w, a, getb = pair({ adb = { schema = 3, who = { seen = {
    ["CAMWOWEU4Realm2PvP-Stromham Hamson"] = { v = "0.2.0-fw1" },
    ["CAMWOWEU4Realm2PvP-stromham  hamson"] = { v = "0.1.0" } } } } })
  a:login()
  local rows = a.DT.whoRows()
  check("R-P6: you are listed first, marked (you)", rows[1] and rows[1].you and rows[1].name == "Stromham Hamson (you)"
    and rows[1].v == "0.3.0")
  local mine = 0
  for _, r in ipairs(rows) do if a.DT.sameKey(r.key, a:key()) then mine = mine + 1 end end
  check("R-P6: your own entry exactly once, saved copies of you never doubled", mine == 1 and #rows == 1)
  a:slash("who")
  local L = a.DT._who.list()
  check("empty state: just you, the line shows", L.empty.shown and L.empty.text == "Just you so far. The rest are still in their coffins.")
  local b = getb(); b:login()
  w:advance(12)
  a:slash("who")
  check("empty state: gone once someone else is listed", not L.empty.shown)
  check("R-P5: names by full name only, no realm", names(a) == "Lilbit High/this session" and a.DT.whoRows()[1].name == "Stromham Hamson (you)")
  -- the tooltip carries the realm
  local btn
  for _, f in ipairs(a.frames) do if f._type == "Button" and f.row and f.row.key == b:key() and f.shown then btn = f end end
  btn.scripts.OnEnter(btn)
  local tt = a:frame("DeadTiredTooltip")
  check("R-P5: the realm is in the row's tooltip", tt.lines[#tt.lines - 2] == "Lilbit High" and tt.lines[#tt.lines - 1] == "CAMWOW EU4 Realm 4 PvP")
  -- a same-named player on a third realm: both get (Realm)
  local c = w:client({ name = "Lilbit", full = "Lilbit High", realm = "CAMWOW EU5 Realm 8 PvP", guild = G, random = function() return 0.5 end })
  c:login()
  w:advance(12)
  local n = names(a)
  check("R-P5 collision: two Lilbit High on two realms both carry the realm",
    n:find("Lilbit High (CAMWOW EU4 Realm 4 PvP)/this session", 1, true) ~= nil
    and n:find("Lilbit High (CAMWOW EU5 Realm 8 PvP)/this session", 1, true) ~= nil)
  check("R-P5 collision: others keep the plain name", a.DT.whoRows()[1].name == "Stromham Hamson (you)")
  -- row heights fit a wrapped name
  local long = "CAMWOWEU4Realm2PvP-Bartholomew Wolfgang Featherstonehaugh-Smythe"
  a.DT._who.record("CAMWOWEU4Realm2PvP-Bartholomew Wolfgangus Featherstonehaughsmythe", { v = "0.2.0" })
  a:slash("who")
  local tall, prev, overlap = nil, nil, false
  local shownRows = {}
  for _, f in ipairs(a.frames) do if f._type == "Button" and f.row and f.shown and f.top then shownRows[#shownRows + 1] = f end end
  table.sort(shownRows, function(x, y) return x.top < y.top end)
  for _, f in ipairs(shownRows) do
    if prev and f.top < prev.top + prev.h then overlap = true end
    if f.row.name:find("Bartholomew", 1, true) then tall = f end
    prev = f
  end
  check("rows: a wrapped name makes its row taller", tall and tall.h > 18)
  check("rows: no row starts inside the one above", not overlap and #shownRows >= 4)
end

H.finish("who")
