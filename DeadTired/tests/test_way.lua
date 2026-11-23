-- Offline checks for Way.lua (dt_waypointer, 0.5.0; rulings W1-W7, PR #36).
--   lua5.1 DeadTired/tests/test_way.lua
-- A small fake world: each map is a rectangle of world yards (north edge N, west edge W, H yards tall,
-- Wd yards wide) on a continent, so worked examples are done by hand. Map x runs west to east (world Y
-- falls), map y runs north to south (world X falls), as in the game. Stubs per client (c.env): C_Map
-- (positions, the pin, the zone list), C_SuperTrack, UiMapPoint, GetPlayerFacing.
--   c.map, c.px, c.py: where the player is; c.facing; c.lost (no position); c.secretPos (a secret one);
--   c.noPin[map] (the game refuses a pin there); c.wp (Blizzard's pin); c.reads (position reads).
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local P = "|cff7fa650Dead Tired|r "
local PI = math.pi

local MAPS = {
  [1446] = { name = "Tanaris", c = 1, N = 0, W = 0, H = 1000, Wd = 1000 },
  [1413] = { name = "The Barrens", c = 1, N = 5000, W = 0, H = 2000, Wd = 1000 },
  [1425] = { name = "The Hinterlands", c = 0, N = 3000, W = 3000, H = 1000, Wd = 1000 },
  [1441] = { name = "Thousand Needles", c = 1, N = 1000, W = 0, H = 1000, Wd = 1000 },
  [1422] = { name = "Western Plaguelands", c = 0, N = 2000, W = 2000, H = 1000, Wd = 1000 },
  [1423] = { name = "Eastern Plaguelands", c = 0, N = 2000, W = 1000, H = 1000, Wd = 1000 },
  [1458] = { name = "Undercity", c = 0, N = 2500, W = 2500, H = 200, Wd = 200 },
}
local function vec(x, y) return { x = x, y = y, GetXY = function(s) return s.x, s.y end } end

local function stub(c)
  c.map, c.px, c.py, c.facing, c.noPin, c.reads, c.clears = 1446, 0.5, 0.5, 0, {}, 0, 0
  c.world.pins = c.world.pins or {}
  c.wp = c.world.pins[c.full]                    -- Blizzard's pin outlives a /reload (the client keeps it)
  local env = c.env
  rawset(env, "UiMapPoint", { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, position = vec(x, y) } end })
  rawset(env, "GetPlayerFacing", function() return c.facing end)
  rawset(env, "C_SuperTrack", { SetSuperTrackedUserWaypoint = function(v) c.tracked = v end })
  rawset(env, "C_Map", {
    GetBestMapForUnit = function(u) if u == "player" then return c.map end end,
    GetPlayerMapPosition = function(m, u)
      c.reads = c.reads + 1
      if c.lost or m ~= c.map then return nil end
      local v = vec(c.px, c.py)
      if c.secretPos then c.secrets[v] = true end
      return v
    end,
    GetWorldPosFromMapPos = function(m, v)
      local r = MAPS[m]
      if not r or type(v) ~= "table" then return nil end
      return r.c, vec(r.N - v.y * r.H, r.W - v.x * r.Wd)
    end,
    GetMapChildrenInfo = function(root)
      if root ~= 947 or c.noZones then return {} end
      local out = {}
      for id, r in pairs(MAPS) do out[#out + 1] = { mapID = id, name = r.name, mapType = 3 } end
      return out
    end,
    GetMapInfo = function(m) local r = MAPS[m]; return r and { mapID = m, name = r.name } end,
    CanSetUserWaypointOnMap = function(m) return not c.noPin[m] end,
    SetUserWaypoint = function(p) c.wp = p; c.world.pins[c.full] = p end,
    GetUserWaypoint = function() return c.wp end,
    HasUserWaypoint = function() return c.wp ~= nil end,
    ClearUserWaypoint = function() c.wp = nil; c.world.pins[c.full] = nil; c.clears = c.clears + 1 end,
  })
end

local function mk(w, o)
  o = o or {}
  o.name, o.full = o.name or "Stromham", o.full or "Stromham Hamson"
  o.realm = o.realm or "CAMWOW EU4 Realm 2 PvP"
  if o.guild == nil then o.guild = G end
  if o.guild == false then o.guild = nil end
  local setup = o.setup
  o.setup = function(c) stub(c); if setup then setup(c) end end
  return w:client(o)
end

local function pinTo(c, p) c.wp = p; c.world.pins[c.full] = p end    -- the player sets (or removes) the pin by hand
local function rotation(c)
  local n = c.DT._way.needle()
  local r
  for _, call in ipairs(n and n.calls or {}) do if call[1] == "SetRotation" then r = call[2] end end
  return r
end
local function near(a, b, tol) return type(a) == "number" and math.abs(a - b) <= (tol or 1e-6) end
local function deg(r) return r * 180 / PI end
local function ang(a, b) local d = math.abs((a - b + PI) % (2 * PI) - PI); return deg(d) <= 1 end
local function arrowShown(c) local a = c.DT._way.arrow(); return a ~= nil and a:IsShown() end
local function lineText(c) local l = c.DT._way.line(); return l and l.text end        -- the distance line
local function placeText(c) local l = c.DT._way.place(); return l and l.text end      -- the place under it

-- ---------------------------------------------------------------- parsing and zones (W1)
do
  local w = H.world()
  local a = mk(w)
  a:login(); w:advance(5)
  local DT = a.DT
  local x, y, z = DT.wayParse("45.2 61.8")
  check("parse: two numbers", x == 45.2 and y == 61.8 and z == nil)
  x, y, z = DT.wayParse("45.2, 61.8 Tanaris")
  check("parse: a comma between, then a zone", x == 45.2 and y == 61.8 and z == "Tanaris")
  x, y = DT.wayParse("45,2")
  check("parse: \"45,2\" is x 45, y 2 (a comma separates)", x == 45 and y == 2)
  check("parse: out of range refused", DT.wayParse("101 50") == nil and DT.wayParse("50 -1") == nil)
  check("parse: missing or junk refused", DT.wayParse("50") == nil and DT.wayParse("") == nil and DT.wayParse("north east") == nil)
  check("parse: 0 and 100 are inside", DT.wayParse("0 100") == 0)
  local id, name = DT.wayZone("tanaris")
  check("zone: by name, any case", id == 1446 and name == "Tanaris")
  check("zone: a unique prefix", DT.wayZone("thous") == 1441)
  local none, why = DT.wayZone("The")
  check("zone: an ambiguous prefix is refused", none == nil and why == "many")
  none, why = DT.wayZone("Narnia")
  check("zone: an unknown name is refused", none == nil and why == "none")
  a:slash("way 50 50 The")
  check("/dt way with an ambiguous zone: one line, nothing set", #a.printed == 1 and a:said("More than one zone") and DT.wayCurrent() == nil)
  a:slash("way 50 50 Narnia")
  check("/dt way with an unknown zone: one line, nothing set", a:said('No zone called "Narnia"') and DT.wayCurrent() == nil)
  a:slash("way 150 50")
  check("/dt way out of range: the usage line, nothing set", a:said("/dt way <x> <y> [zone]") and DT.wayCurrent() == nil)
end

-- ---------------------------------------------------------------- the pin (W2)
do
  local w = H.world()
  local a = mk(w)
  a:login(); w:advance(5)
  local DT = a.DT
  a:slash("way 50 40")
  local cur = DT.wayCurrent()
  check("set in the current zone: saved, labelled", cur and cur.map == 1446 and near(cur.x, 0.5) and near(cur.y, 0.4)
    and cur.label == "Tanaris 50.0, 40.0" and a:said("Waypoint: Tanaris 50.0, 40.0."))
  check("the pin is set there and tracked", a.wp and a.wp.uiMapID == 1446 and near(a.wp.position.y, 0.4) and a.tracked == true)
  check("the arrow shows", arrowShown(a))
  a:slash("way 30 70 Western")
  check("set in a named zone: the pin moves there", a.wp.uiMapID == 1422 and near(a.wp.position.x, 0.3)
    and DT.wayCurrent().label == "Western Plaguelands 30.0, 70.0")
  a.noPin[1458] = true
  a:slash("way 50 50 Undercity")
  check("a map that takes no pin: the line, the arrow still on", a:said(DT._way.NO_PIN) and arrowShown(a)
    and DT.wayCurrent().map == 1458)
  check("...and the old pin (DT's own) was cleared, not left behind", a.wp == nil)
  a:slash("way 50 30 Tanaris")
  local mine = a.wp
  pinTo(a, { uiMapID = 1446, position = vec(0.1, 0.1) })                     -- the player moved the pin since
  a:slash("way clear")
  check("clear: a pin the player has moved since is left alone", a.wp and near(a.wp.position.x, 0.1) and a:said("Waypoint cleared."))
  a:slash("way 20 20 Tanaris")
  a:slash("way clear")
  check("clear: DT's own pin is cleared", a.wp == nil and DT.wayCurrent() == nil and not arrowShown(a))
  a:slash("way clear")
  check("clear with nothing set: says so", a:said("No waypoint set."))
  check("(the first pin was a real one)", mine ~= nil)
end

-- ---------------------------------------------------------------- the arrow (W3)
do
  local w = H.world()
  local a = mk(w)
  a:login(); w:advance(5)
  local DT = a.DT
  local function at(x, y, facing) a.facing = facing or 0; a:slash(("way %s %s"):format(x, y)); w:advance(0.2) end
  at(50, 40, 0)
  check("ahead: bearing 0, 100 yd", ang(rotation(a), 0) and lineText(a) == "100 yd" and placeText(a) == "Tanaris 50.0, 40.0")
  at(50, 60, 0)
  check("behind: bearing 180", ang(rotation(a), PI) and lineText(a) == "100 yd")
  at(40, 50, 0)
  check("left (west, facing north): bearing +90 (counter-clockwise)", ang(rotation(a), PI / 2))
  at(50, 40, PI / 2)
  check("right (north, facing west): bearing 270", ang(rotation(a), 3 * PI / 2))
  at(80, 90, 0)
  local d = math.sqrt(300 ^ 2 + 400 ^ 2)
  check("a 3-4-5 triangle: 500 yd", lineText(a) == "500 yd" and near(d, 500))
  a:slash("way 50 50 The Hint"); w:advance(0.2)
  check("another continent: said, no needle", lineText(a) == "another continent" and placeText(a) == "The Hinterlands 50.0, 50.0"
    and not a.DT._way.needle():IsShown())
  a:slash("way 10 10"); w:advance(0.2)
  a.secretPos = true; w:advance(0.2)
  check("a secret position: the needle hides, no error", not a.DT._way.needle():IsShown() and lineText(a):find("\226\128\166", 1, true)
    and #a.errors == 0)
  a.secretPos = false; a.lost = true; w:advance(0.2)
  check("no position at all: the same", not a.DT._way.needle():IsShown() and #a.errors == 0)
  a.lost = false; w:advance(0.2)
  check("back again: the needle returns", a.DT._way.needle():IsShown())
  a:slash("way 50 50 Western"); w:advance(0.2)
  check("a long place: the yards line is whole; the place may be cut, never the yards", not a.DT.textRecord(a.DT._way.line()).cut)
  check("thousands get a comma", DT._way.yards(12345.4) == "12,345" and DT._way.yards(999) == "999")
  -- the throttle: at most 10 updates a second
  local r0 = a.reads
  w:advance(1)
  check("throttle: about 10 position reads a second, not one a frame", a.reads - r0 >= 9 and a.reads - r0 <= 11)
  -- the throttle again, at a real frame rate: 100 frames of 0.01 s are 10 updates, not 100
  local arrow = DT._way.arrow()
  r0 = a.reads
  for _ = 1, 100 do arrow.scripts.OnUpdate(arrow, 0.01) end
  check("throttle: 100 frames in a second make about 10 updates", a.reads - r0 >= 9 and a.reads - r0 <= 11)
  -- hidden does nothing
  arrow:Hide()
  local r1 = a.reads
  arrow.scripts.OnUpdate(arrow, 1)
  check("hidden: OnUpdate reads nothing", a.reads == r1)
  a:slash("way clear")
  r1 = a.reads
  arrow:Show(); arrow.scripts.OnUpdate(arrow, 1)
  check("no waypoint: OnUpdate reads nothing", a.reads == r1)
  check("the arrow uses the client's own art", DT._way.needle().texture == DT._way.TEXTURE)
end

-- ---------------------------------------------------------------- arrival (W5)
do
  local w = H.world()
  local a = mk(w)
  a:login(); w:advance(5)
  a.px, a.py = 0.5, 0.5
  a:slash("way 50.3 49.6")                                                -- 3 yd east... 4 yd north: 5 yd away
  w:advance(0.2)
  check("arrival: within 5 yards it clears itself, pin and all", a.DT.wayCurrent() == nil and a.wp == nil
    and a:said("You're there.") and not arrowShown(a))
  a:slash("way 50 49.4")                                                  -- 6 yd north
  w:advance(0.2)
  check("arrival: 6 yards away it stays", a.DT.wayCurrent() ~= nil and arrowShown(a) and lineText(a) == "6 yd")
  a.py = 0.4945; w:advance(0.2)                                           -- walk to 0.5 yd off
  check("...and walking up to it clears it", a.DT.wayCurrent() == nil)
end

-- ---------------------------------------------------------------- the switches (W4), the store (W6)
do
  local w = H.world()
  local a = mk(w)
  a:login(); w:advance(5)
  local DT = a.DT
  check("arrow and pin: both on by default, each a card with its typed path", DT.get("way", "arrow") == true
    and DT.get("way", "pin") == true and DT.setting("way", "arrow").verb == "way arrow on|off"
    and DT.setting("way", "pin").verb == "way pin on|off" and #DT.setting("way", "pin").desc > 0)
  a:slash("way arrow off"); a:slash("way pin off")
  a:slash("way 50 40")
  check("both off: the waypoint is set, and the line says both are off", DT.wayCurrent() ~= nil and a:said("Arrow and pin are both off.")
    and a.wp == nil and not arrowShown(a))
  a:slash("way pin on")
  check("pin on again: the pin goes up", a.wp ~= nil)
  a:slash("way arrow on")
  check("arrow on again: the arrow shows", arrowShown(a))
  a:slash("way pin off")
  check("pin off: DT's pin comes down", a.wp == nil)
  a:slash("way pin on")
  a:slash("way 20 30 Thousand")
  local b = a:reload(); w:advance(1)
  check("a /reload keeps it", b.DT.wayCurrent() and b.DT.wayCurrent().map == 1441 and arrowShown(b))
  check("...and leaves the client's pin as it was", b.wp ~= nil and b.wp.uiMapID == 1441)
  pinTo(b, nil)
  local c = b:reload(); w:advance(1)
  check("after a relog with no pin: the pin goes back up", c.wp ~= nil and c.wp.uiMapID == 1441)
  pinTo(c, { uiMapID = 1413, position = vec(0.2, 0.2) })
  local d = c:reload(); w:advance(1)
  check("...but never over a pin the player set", d.wp.uiMapID == 1413)
  d:slash("way 70 70 Tanaris")
  check("a new waypoint replaces the old", d.DT.wayCurrent().map == 1446)
  local s = d.DT.wayStore().current
  for i = 1, 60 do s["Realm-Alt " .. i] = { map = 1446, x = 0.5, y = 0.5, label = "x", t = i } end
  d:slash("way 10 10")
  local n = 0
  for _ in pairs(s) do n = n + 1 end
  check("the store keeps 50 characters, yours always among them", n == 50 and s[d:key()] ~= nil and s["Realm-Alt 1"] == nil)
end

-- ---------------------------------------------------------------- the list (W1)
do
  local w = H.world()
  local a = mk(w, { setup = function(c) rawset(c.env, "UISpecialFrames", {}) end })
  a:login(); w:advance(5)
  local DT = a.DT
  a:slash("way list")
  local vp, L = DT._way.vp(), DT._way.list()
  check("list: the window opens, titled", vp:IsShown() and vp.title.text == "Where to?")
  check("list: 39 books", #L.model.rows == 39)
  check("list: the closing line names the source", vp.footer.text == "Coordinates from Warcraft Tavern's Forever book guide.")
  local esc = false
  for _, n in ipairs(a.env.UISpecialFrames) do if n == "DeadTiredViewport_way" then esc = true end end
  check("list: Escape closes it", esc)
  L.model:filter("potatoes"); L:refresh()
  local vis = L.model:visible()
  check("list: search", #vis == 1 and vis[1].name == "Undead Potatoes" and vis[1].coords == "38.0, 54.0")
  L.rows[1].scripts.OnClick(L.rows[1], "LeftButton")
  check("list: a click sets it (Western Plaguelands), the pin with it", DT.wayCurrent() and DT.wayCurrent().map == 1422
    and DT.wayCurrent().label == "Undead Potatoes" and a.wp and a.wp.uiMapID == 1422)
  check("list: ...and says where", a:said("Waypoint: Undead Potatoes, Western Plaguelands 38.0, 54.0."))
  L.model:filter("no such book"); L:refresh()
  check("list: the empty state", L.empty.text == "No books match." and L.empty.shown)
  L.model:filter(""); L:refresh()
  local grey
  for _, r in ipairs(L.model.rows) do if r.name == "Ka-Boom!" then grey = r end end
  check("list: a book whose zone the client doesn't list is greyed, and says so", grey and grey.map == nil
    and grey.zone == "Winterspring (zone not found)" and grey.nameRGB[1] == 0.5)
  local before = DT.wayCurrent()
  local b = grey
  for i, r in ipairs(L.model:visible()) do if r == b then L.offset = math.max(0, i - 1); L:refresh() end end
  for _, btn in ipairs(L.rows) do if btn.row == b then btn.scripts.OnClick(btn, "LeftButton") end end
  check("list: clicking it sets nothing", DT.wayCurrent() == before and a:said("Winterspring: zone not found."))
  local faults = {}
  for _, l in ipairs(DT.fitCheck()) do if l:find(" way ", 1, true) then faults[#faults + 1] = l end end
  check("fit: nothing over in the list or the arrow under any skin", #faults == 0)
end

-- ---------------------------------------------------------------- outside the guild; the switch
do
  local w = H.world()
  local x = mk(w, { name = "Out", full = "Out Sider", guild = false })
  x:login(); w:advance(5)
  x:slash("way 50 50")
  check("outside the guild: nothing set, nothing printed, no pin", x.DT.wayCurrent() == nil and #x.printed == 0 and x.wp == nil)
  check("outside the guild: setting directly refuses too", x.DT.waySet(1446, 0.5, 0.5, "x") == false and x.wp == nil)
  local a = mk(w)
  a:login(); w:advance(5)
  local m = a.DT.byId.way
  check("way: an On card, default on", m.optional and a.DT.setting("way", "enabled").label == "On" and a.DT.enabled("way"))
  check("/dt way is in /dt help", a.DT.helpLine():find("way <x> <y>", 1, true) ~= nil)
  a:slash("way 50 40")
  a:slash("set way enabled off")
  check("off: the arrow goes", not arrowShown(a))
  for _, v in ipairs({ "way 50 50", "way list", "way clear", "way pin off" }) do
    local wp = a.wp
    a:slash(v)
    check("off: /dt " .. v .. " says so and does nothing else", #a.printed == 1 and a.printed[1] == P .. "way.enabled = off" and a.wp == wp)
  end
  check("off: setting directly refuses", a.DT.waySet(1446, 0.1, 0.1, "x") == false)
  a:slash("set way enabled on")
  check("on again: the arrow comes back", arrowShown(a))
end

H.finish("way")
