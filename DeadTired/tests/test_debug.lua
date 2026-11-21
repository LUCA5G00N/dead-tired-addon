-- Offline checks for Debug.lua: /dt debug names (player and target), /dt debug senders,
-- /dt debug errors.  lua5.1 DeadTired/tests/test_debug.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"

local w = H.world()
local c = w:client({ guild = G, target = { name = "Lilbit", full = "Lilbit High", realm = "CAMWOWEU4Realm4PvP" } })
c:login()
c:slash("debug names")
check("player: every name function", c:said('player: UnitName "Stromham", UnitFullName "Stromham" / "CAMWOWEU4Realm2PvP", GetUnitName(true) "Stromham Hamson"'))
check("target: the same functions", c:said('target: UnitName "Lilbit", UnitFullName "Lilbit" / "CAMWOWEU4Realm4PvP", GetUnitName(true) "Lilbit High"'))
check("realm functions and the key built from them", c:said('realm: GetRealmName "CAMWOW EU4 Realm 2 PvP", GetNormalizedRealmName "CAMWOWEU4Realm2PvP", key "CAMWOWEU4Realm2PvP-Stromham Hamson"'))
c.target = nil
c:slash("debug names")
check("no target: nil, not an error", c:said('target: UnitName nil, UnitFullName nil / nil, GetUnitName(true) nil'))
c.secrets["Stromham"] = true
c:slash("debug names")
check("a secret value is not printed", not c:said('UnitName "Stromham"') and c:said("player: UnitName nil"))
c.secrets["Stromham"] = nil

c:fire("CHAT_MSG_ADDON", "DEADTIRED", "junk", "GUILD", "Ghoul Grim-Somewhere")
c:fire("CHAT_MSG_ADDON", "DEADTIRED", "junk", "GUILD", "|cffff0000Evil|r")
c:slash("debug senders")
check("senders: the count", c:said("senders: 2 (cap 50, over cap 0), key mismatches 0") ~= nil)
check("senders: each raw string, safely", c:said('"Ghoul Grim-Somewhere" x1 GUILD') and c:said('"||cffff0000Evil||r" x1'))

c:slash("debug errors")
check("errors: none recorded", c:said("errors: none") and c:said("comms: sent ") and c:said('restricted flag "true"'))
c.DT.fail("who", "TEST", "it broke")
c:slash("debug errors")
check("errors: each module's count and last text", c:said('errors who: 1 "TEST: it broke"') ~= nil)
check("each debug line goes through DT.out (silent outside the guild)", (function()
  c.guild = nil
  c:slash("debug names")
  return #c.printed == 0
end)())


-- ---------------------------------------------------------------- fix round 4: /dt debug fit (Task 5, G7)
do
  local w2 = H.world()
  local d = w2:client({ guild = G, setup = function(c0)
    rawset(c0.env, "C_DateAndTime", { GetServerTimeLocal = function() return 1793491200 end })
    rawset(c0.env, "date", function(f, t) if f == "!*t" then return os.date("!*t", t) end return "2026-11-11 21:00:00" end)
  end })
  d:login()
  local D = d.DT
  -- some data in every window
  local deaths = d:db().crypt.deaths
  deaths[#deaths + 1] = { who = "CAMWOWEU4Realm2PvP-Echo Nightclaw", lvl = 31, zone = "Excavation Site: Wetlands", at = "2026-11-12 00:12:33" }
  deaths[#deaths + 1] = { who = "CAMWOWEU4Realm2PvP-Nine Lives", lvl = 9, zone = "Mulgore", at = "2026-11-09 10:00:00" }
  D.ganks()[1] = { who = "Nethergarde-Junesong Ikkin", cls = "SHAMAN", lvl = 25, zone = "Ashenvale", by = d:key(), at = "2026-11-12 11:02:09" }
  D.playedBoard()["CAMWOWEU4Realm2PvP-Turtle Shell"] = { lvl = 34, hours = 93.7, t = 1794000000 }
  d:db().settings.core = { skin = "deadtired" }
  local savedBefore = d:db().settings.core.skin
  local signals = 0
  D.listen("setting", function() signals = signals + 1 end)
  local printedBefore = #d.printed
  d:slash("debug fit")
  local last = d.printed[#d.printed]
  check("G7 debug fit: the last line, 0 over on each of the three skins, no measure failures",
    last and last:find("fit: %d+ checked, 0 over, %d+ rows cut, measure failures 0$") ~= nil)
  check("G7 debug fit: only its last line (no fault lines), nothing else printed", #d.printed == 1)
  check("G7 debug fit: every skin was checked (clean, deadtired, forever)", (function()
    local n = 0; for _ in pairs(D.skins) do n = n + 1 end; return n == 3 end)())
  check("G7 debug fit: the saved skin is the same before and after", d:db().settings.core.skin == savedBefore
    and D.skinName() == "deadtired")
  check("G7 debug fit: never written (no setting signal, no saved choice touched)", signals == 0)
  check("debug fit: each window was built, and left hidden", D.viewports.crypt and not D.viewports.crypt:IsShown()
    and D.viewports.gank and D.viewports.slowest and D.viewports.who and D.viewports.stash and D.viewports.events
    and D.viewports.settings and not D.viewports.settings:IsShown())
  check("debug fit: the log dialogs built, hidden", d:frame("DeadTiredLogsLogin") and not d:frame("DeadTiredLogsLogin"):IsShown()
    and d:frame("DeadTiredLogsInstance") and not d:frame("DeadTiredLogsInstance"):IsShown())
  check("debug fit: built windows printed nothing and sent no WHO", d:count("Award") == 0 and (function()
    for _, m in ipairs(d.sent) do local ok, p = D._comms.decode(m.text); if ok == "ok" and p.k == "WHO" then return false end end
    return true end)())
  local checked = tonumber(last:match("fit: (%d+) checked"))
  check("debug fit: many strings checked (every window's text, three times)", checked and checked > 300)
  -- a planted over-wide label is reported, under each skin
  local host = d.env.CreateFrame("Frame", nil, d.env.UIParent)
  host.dtWindow = "plant"
  host:SetWidth(30)
  local lab = D.text(host, "label", {})
  D.setText(lab, "Far too wide for its button")
  d:slash("debug fit")
  local planted = 0
  for _, l in ipairs(d.printed) do
    if l:find('fit: %a+ plant label "Far too wide for its but" %d+/30') then planted = planted + 1 end
  end
  check("G7 a planted over-wide label is reported, once per skin, in the brief's shape", planted == 3)
  check("G7 ...and counted in the last line", d.printed[#d.printed]:find(", 3 over,", 1, true) ~= nil)
  -- a line with no width, a block over its box
  local nw = D.text(host, "line", {})
  D.setText(nw, "x")
  local bl = D.text(host, "block", { width = 30 })
  D.setText(bl, string.rep("words ", 10))
  D.textHeight(bl, 30)
  D.setWidth(bl, 30)
  bl.w = 10                                      -- the box stays, the text now needs more room
  d:slash("debug fit")
  check("debug fit: a line with no width is a fault", d:said('plant line "x" 0/0') ~= nil)
  check("debug fit: a block taller than its box is a fault", d:said('plant block "words words words words "') ~= nil)
  -- a fixed column too narrow, a flex column under 60
  local vp = D.viewport({ id = "narrow", title = "N", width = 160 })
  local m = D.listModel()
  local L = D.list(vp.body, m, { columns = { { key = "a", fixed = true }, { key = "b", width = 100 }, { key = "c", flex = true } } })
  m:set({ { a = "12 Nov", b = "x", c = "y" } }); L:refresh()
  L.columns[1].w = 10
  local b1 = d.printed
  d:slash("debug fit")
  check("debug fit: a fixed column re-measured on the skin change fits again; a flex under 60 is a fault",
    d:said('narrow flex "c"') ~= nil and not d:said('narrow fixed'))
  -- a measure that fails is counted in the last line
  local fs = d.env.UIParent:CreateFontString()
  host.GetWidth = function() return 1000 end
  local oldMeasure = D.measure
  D.measure = function(t, r, f) D.fail("ui:measure", "test", "w 0"); return nil end
  d:slash("debug fit")
  D.measure = oldMeasure
  check("debug fit: measure failures counted in the last line", d.printed[#d.printed]:find("measure failures [1-9]") ~= nil)
  check("debug fit outside the guild: nothing", (function() d.guild = nil; d:slash("debug fit"); return #d.printed == 0 end)())
end

-- ---------------------------------------------------------------- 0.3.3: /dt debug rip <name> (R-F6-6)
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
  local w2 = H.world()
  local d = w2:client({ guild = G, setup = function(c0) classStub(c0) end })
  d:login(); w2:advance(5)
  local graves, sent = #d:db().crypt.deaths, #d.sent
  d:slash("debug rip Echo Wagyu")
  check("debug rip: two lines, ordinary then hardcore, the name in its class colour", #d.printed == 2
    and d.printed[1] == "|cff7fa650Dead Tired|r |cff0070ddEcho Wagyu|r died at level 30 in Duskwood. Again."
    and d.printed[2] == "|cff7fa650Dead Tired|r Rest in Pieces: |cff0070ddEcho Wagyu|r, level 30, Duskwood. Hardcore. Gone for good.")
  d:slash("debug rip  stromham   HAMSON ")
  check("debug rip: case and spaces ignored; a paladin is pink", #d.printed == 2 and d.printed[1]:find("|cfff48cbaStromham Hamson|r died at level 30", 1, true) ~= nil)
  w2:advance(30)
  check("debug rip: records nothing", #d:db().crypt.deaths == graves and d.DT.cryptSession.heard == 0)
  check("debug rip: sends nothing", #d.sent == sent)
  d:slash("debug rip Out Sider")
  check("debug rip: a stranger: not on the roster.", #d.printed == 1 and d:said("not on the roster.") ~= nil)
  d:slash("debug rip")
  check("debug rip alone: the usage", d:said("/dt debug rip <name>") ~= nil)
  d:slash("debug rip Hunter Bad")
  check("debug rip: on the roster but no usable colour: both lines plain", #d.printed == 2
    and d.printed[1] == "|cff7fa650Dead Tired|r Hunter Bad died at level 30 in Duskwood. Again.")
  d:slash("help")
  check("debug rip is listed in /dt help", d:said("debug rip <name>") ~= nil)
  d.guild = nil
  d:slash("debug rip Echo Wagyu")
  check("debug rip outside the guild: nothing", #d.printed == 0)
end

H.finish("debug")
