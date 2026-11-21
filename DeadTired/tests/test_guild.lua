-- Offline checks for Guild.lua: the guild gate (silent outside: says nothing, sends nothing, shows
-- nothing) and the welcome line.  lua5.1 DeadTired/tests/test_guild.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"

do
  local w = H.world()
  local c = w:client({ guild = "  dead tired " })
  check("member: case and surrounding spaces ignored", c.DT.isMember() == true)
  c.guild = "Dead Tired Too"
  check("another guild is not the guild", c.DT.isMember() == false)
  c.guild = nil
  check("no guild is not the guild", c.DT.isMember() == false)
end

-- ---------------------------------------------------------------- outside the guild: silent
do
  local w = H.world()
  local out = w:client({ name = "Wanderer", guild = "Some Other Guild" })
  local inG = w:client({ name = "Graverobber", guild = "Some Other Guild" })   -- same other guild, to hear
  out:login()
  w:advance(15)
  check("outside: login prints nothing (no welcome, no bar intro)", #out.printed == 0)
  out:slash("help")
  out:slash("who")
  out:slash("debug names")
  out:slash("set guild welcome off")
  check("outside: /dt says nothing", #out.printed == 0)
  check("outside: a /dt set does nothing either", out:db().settings.guild == nil)
  out.printed = {}
  check("outside: DT.out itself prints nothing", out.DT.out("Rest in Pieces") == false and #out.printed == 0)
  check("outside: DT.send refuses", out.DT.send("TEST", { x = 1 }) == false)
  w:advance(15)
  check("outside: nothing on the wire, ever", #out.sent == 0 and #out.refused == 0)
  check("outside: no bar, no viewport, no toast shown", not (out:frame("DeadTiredBar") and out:frame("DeadTiredBar").shown)
    and out:frame("DeadTiredViewport_who") == nil and out.DT.toast("guild", "welcome", "x") == false)
  -- a message from a member arrives at a non-member: ignored
  local m = w:client({ name = "Ghoul", guild = G })
  local wire = m.DT._comms.encode("HELLO", { v = "x" }, m:key())
  out:fire("CHAT_MSG_ADDON", "DEADTIRED", wire, "GUILD", m.full)
  check("outside: inbound ignored", out:db().comms.received == 0 and next(out.DT._who.session()) == nil)
end

-- ---------------------------------------------------------------- the guild arrives late
do
  local w = H.world()
  local c = w:client({ guild = nil })
  c:login()
  check("guild info not there yet: nothing said", #c.printed == 0)
  c.guild = G
  c:fire("PLAYER_GUILD_UPDATE")
  check("it arrives: the welcome, once", c:count("Rest in Pieces,") == 1)
  c:fire("PLAYER_GUILD_UPDATE")
  check("not twice", c:count("Rest in Pieces,") == 1)
end

-- ---------------------------------------------------------------- the welcome
do
  local w = H.world()
  local c = w:client({ guild = G })
  c:login()
  check("one welcome line, with the full name", c:count("Rest in Pieces,") == 1
    and c:said("Rest in Pieces, Stromham Hamson. The crypt's open. /dt for the rest."))
  c:fire("PLAYER_ENTERING_WORLD", false, false)
  check("zoning doesn't repeat it", c:count("Rest in Pieces,") == 1)
  local r = c:reload()
  check("a /reload counts as a login", r:count("Rest in Pieces,") == 1)
  r:slash("set guild welcome off")
  check("/dt set guild welcome off", r:said("guild.welcome = off") ~= nil and r:db().settings.guild.welcome == false)
  local r2 = r:reload()
  check("off: no welcome next login", r2:count("Rest in Pieces") == 0)
  check("nothing else printed unasked (bar intro was said once already)", #r2.printed == 0)
end

-- ---------------------------------------------------------------- class colours (0.3.3, dt_classcolours)
-- 0.3.3 class colours: the probe's five classes (21 Nov 13:24) and their colours, plus broken entries.
local CC = {
  SHAMAN = { r = 0, g = 0.44, b = 0.87, colorStr = "ff0070dd" },
  ROGUE = { r = 1, g = 0.96, b = 0.41, colorStr = "fffff468" },
  MAGE = { r = 0.25, g = 0.78, b = 0.92, colorStr = "ff3fc7eb" },
  WARLOCK = { r = 0.53, g = 0.53, b = 0.93, colorStr = "ff8788ee" },
  PALADIN = { r = 0.96, g = 0.55, b = 0.73, colorStr = "fff48cba" },
  HUNTER = { r = 0.67, g = 0.83, b = 0.45, colorStr = "ffabd47" },          -- 7 digits: refused
  DRUID = { r = 1.5, g = 0.49, b = 0.04, colorStr = "ffff7c0a" },           -- r out of range: refused
  PRIEST = { r = 1, g = 1, b = 1 },                                        -- no colorStr: refused
}
-- name, token (11th value), as the Forever roster gives them: no "-Realm" (the probe), except where shown
local ROSTER = {
  { "Echo Wagyu", "SHAMAN" }, { "Zupsy Stab", "ROGUE" }, { "Trevlyn Kratos", "MAGE" },
  { "Vespera Grimm", "WARLOCK" }, { "Stromham Hamson", "PALADIN" }, { "Echo Nightclaw", "SHAMAN" },
  { "Odd Token", "WIZARD" }, { "No Token", nil }, { "Hunter Bad", "HUNTER" }, { "Druid Bad", "DRUID" },
  { "Priest Bad", "PRIEST" }, { "Marvella Hex-SomeOtherRealm", "WARLOCK" },
}
local function classStub(c, roster)
  local env = c.env
  rawset(env, "RAID_CLASS_COLORS", CC)
  rawset(env, "GetNumGuildMembers", function() return #(c.roster or roster or ROSTER) end)
  rawset(env, "GetGuildRosterInfo", function(i)
    local e = (c.roster or roster or ROSTER)[i]
    if e then return e[1], "rank", 4, 40, "Class", "Zone", "", "", true, 0, e[2] end
  end)
end

do
  local w = H.world()
  local c = w:client({ name = "Stromham", full = "Stromham Hamson", guild = G, realm = "CAMWOW EU4 Realm 2 PvP",
    setup = function(c) classStub(c) end })
  c:login(); w:advance(5)
  local D = c.DT
  local K = "CAMWOWEU4Realm2PvP-"
  local roster = D.rosterClasses()
  check("R-F6-3: the roster gives the class token, keyed by lower full name", roster["echo wagyu"].token == "SHAMAN" and roster["echo wagyu"].name == "Echo Wagyu"
    and roster["stromham hamson"].token == "PALADIN" and roster["echo wagyu"].realm == nil)
  check("R-F6-3: a roster name with -Realm keeps its realm key", roster["marvella hex"].realm == "SomeOtherRealm")
  check("R-F6-3: no token, no entry", roster["no token"] == nil)
  local probe = { { "Echo Wagyu", "ff0070dd" }, { "Zupsy Stab", "fffff468" }, { "Trevlyn Kratos", "ff3fc7eb" },
    { "Vespera Grimm", "ff8788ee" }, { "Stromham Hamson", "fff48cba" } }
  local all = true
  for _, x in ipairs(probe) do
    local _, _, _, hex = D.classColour(K .. x[1], roster)
    if hex ~= x[2] then all = false end
  end
  check("R-F6-4: the probe's five classes give the client's own colours (shaman blue)", all)
  local r, g, b, hex = D.classColour(K .. "Echo Wagyu")
  check("classColour: r, g, b and hex together; builds a roster when none is given", r == 0 and g == 0.44 and b == 0.87 and hex == "ff0070dd")
  check("classColour: case and spacing in the key's name ignored", D.classColour(K .. "echo  WAGYU", roster) ~= nil)
  check("R-F6-5: not on the roster: nil", D.classColour(K .. "Out Sider", roster) == nil)
  check("R-F6-5: an unknown token: nil", D.classColour(K .. "Odd Token", roster) == nil)
  check("R-F6-5: no token: nil", D.classColour(K .. "No Token", roster) == nil)
  check("R-F6-5: a 7-digit colorStr: nil", D.classColour(K .. "Hunter Bad", roster) == nil)
  check("R-F6-5: r out of range: nil", D.classColour(K .. "Druid Bad", roster) == nil)
  check("R-F6-5: no colorStr: nil", D.classColour(K .. "Priest Bad", roster) == nil)
  check("R-F6-3: a roster name with a different -Realm: nil", D.classColour(K .. "Marvella Hex", roster) == nil)
  check("R-F6-3: the same name on the roster's realm: coloured", D.classColour("SomeOtherRealm-Marvella Hex", roster) ~= nil)
  check("not a key: nil", D.classColour("nonsense", roster) == nil and D.classColour(nil, roster) == nil)
  local wrote = false
  for _, k in ipairs(c:ownWrites()) do if k == "RAID_CLASS_COLORS" then wrote = true end end
  check("RAID_CLASS_COLORS is read, never written", not wrote and c.env.RAID_CLASS_COLORS.SHAMAN.colorStr == "ff0070dd")
  c.roster = {}
  check("an empty roster (not loaded yet): nil", D.classColour(K .. "Echo Wagyu") == nil)
  rawset(c.env, "RAID_CLASS_COLORS", nil); c.roster = nil
  check("no RAID_CLASS_COLORS: nil, no error", D.classColour(K .. "Echo Wagyu") == nil)
  rawset(c.env, "GetGuildRosterInfo", function() error("roster") end)
  check("a roster read that errors: nil, no error", D.classColour(K .. "Echo Wagyu") == nil)
end

H.finish("guild")
