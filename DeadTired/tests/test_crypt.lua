-- Offline checks for Crypt.lua (card 3, Rest in Pieces, ported from rc3 in Port 1): rc3's checks
-- on full-name keys, the settings as cards, the graveyard viewport, names without realm.
--   lua5.1 DeadTired/tests/test_crypt.lua
-- Stubs added per client (c.env): UnitLevel (c.level), GetRealZoneText (c.zone), IsInInstance
-- (c.itype), C_GameRules.IsHardcoreActive (c.hc; "error"; c.noRules), date("*t") (c.clock = {h, m};
-- c.noClock).
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local R2 = "CAMWOW EU4 Realm 2 PvP"
local function half() return 0.5 end

local function stub(c)
  c.level, c.zone, c.itype, c.hc, c.clock = 23, "The Barrens", "none", false, { 20, 0 }
  local env = c.env
  rawset(env, "UnitLevel", function() if c.level == "error" then error("x") end return c.level end)
  rawset(env, "GetRealZoneText", function() return c.zone end)
  rawset(env, "IsInInstance", function() return c.itype ~= "none", c.itype end)
  rawset(env, "C_GameRules", { IsHardcoreActive = function()
    if c.noRules then return nil end
    if c.hc == "error" then error("rules") end
    return c.hc
  end })
  local plain = rawget(env, "date")
  rawset(env, "date", function(f)
    if f == "*t" then
      if c.noClock then return nil end
      return { hour = c.clock[1], min = c.clock[2], year = 2026, month = 11, day = 11 }
    end
    return plain(f)
  end)
end

local function mk(w, o)
  o.realm = o.realm or R2
  if o.guild == nil then o.guild = G end
  o.random = half
  local setup = o.setup
  o.setup = function(c) stub(c); if setup then setup(c) end end
  return w:client(o)
end

local function deaths(c)
  local n = 0
  for _, m in ipairs(c.sent) do
    local ok, p = c.DT._comms.decode(m.text)
    if ok == "ok" and p.k == "DEATH" then n = n + 1 end
  end
  return n
end
local function lastDeath(c)
  for i = #c.sent, 1, -1 do
    local ok, p = c.DT._comms.decode(c.sent[i].text)
    if ok == "ok" and p.k == "DEATH" then return p.d, #c.sent[i].text end
  end
end

-- ---------------------------------------------------------------- store and settings
local w = H.world()
local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
local b = mk(w, { name = "Echo", full = "Echo Nightclaw" })
local o = mk(w, { name = "Outsider", full = "Out Sider", guild = "Other Guild" })
a:login(); b:login(); o:login(); w:advance(30)
local DT = a.DT
check("store: DeadTiredDB.crypt, notices on, share unset, no bedtime", type(a:db().crypt) == "table"
  and DT.get("crypt", "rip") == true and (a:db().settings.crypt or {}).share == nil and DT.get("crypt", "bedtime") == "off")
check("store: one deaths list", type(a:db().crypt.deaths) == "table" and #a:db().crypt.deaths == 0)
check("every setting is a card with a typed path", DT.setting("crypt", "rip").verb == "rip on|off"
  and DT.setting("crypt", "share").verb == "rip share on|off" and DT.setting("crypt", "bedtime").verb == "bedtime HH:MM|off")
a:slash("rip")
check("/dt rip alone shows both settings, share unset shown as off (A2)", a:said("notices on; sharing your deaths off.") ~= nil)
check("/dt rip opens the graveyard", a:frame("DeadTiredViewport_crypt").shown)
a:slash("rip off")
check("/dt rip off", DT.get("crypt", "rip") == false and a:said("notices off. Let the dead bury the dead.") ~= nil)
a:slash("rip on")
check("/dt rip on", DT.get("crypt", "rip") == true and a:said("notices on. You'll hear about every fall.") ~= nil)
a:slash("rip share on")
check("/dt rip share on", DT.get("crypt", "share") == true and a:said("your deaths will be shared. Every last one.") ~= nil)
a:slash("rip share off")
check("/dt rip share off", DT.get("crypt", "share") == false and a:said("your deaths stay between you and the spirit healer.") ~= nil)
a:slash("rip")
check("/dt rip shows share off once set", a:said("notices on; sharing your deaths off.") ~= nil)
a:slash("rip sideways")
check("/dt rip <other> prints usage, changes nothing", a:said("/dt rip on/off, or /dt rip share on/off") ~= nil and DT.get("crypt", "rip") == true)
a:slash("set crypt share on")
check("the same setting through /dt set", DT.get("crypt", "share") == true and a:said("crypt.share = on") ~= nil)
a:slash("set crypt share off")
a:slash("bedtime")
check("/dt bedtime alone: off", a:said("bedtime is off. /dt bedtime HH:MM to set one.") ~= nil)
a:slash("bedtime 9:05")
check("/dt bedtime H:MM stored zero-padded", DT.get("crypt", "bedtime") == "09:05" and a:said("bedtime set for 09:05. You'll be told.") ~= nil)
a:slash("bedtime 23:59")
check("/dt bedtime 23:59", DT.get("crypt", "bedtime") == "23:59")
a:slash("bedtime 24:00")
check("/dt bedtime 24:00 refused, unchanged", a:said("/dt bedtime HH:MM (24-hour), or /dt bedtime off") ~= nil and DT.get("crypt", "bedtime") == "23:59")
a:slash("bedtime 7")
check("/dt bedtime 7 refused", a:said("/dt bedtime HH:MM (24-hour), or /dt bedtime off") ~= nil)
a:slash("bedtime")
check("/dt bedtime alone: the time", a:said("bedtime is 23:59.") ~= nil)
a:slash("bedtime off")
check("/dt bedtime off", DT.get("crypt", "bedtime") == "off" and a:said("bedtime off. Stay up forever; you're dead anyway.") ~= nil)
a:slash("set crypt bedtime 25:00")
check("/dt set crypt bedtime validates too", a:said("/dt set: expects HH:MM (24-hour) or off") ~= nil)
a:slash("help")
check("the help lists the verbs", a:said("rip [share] on/off") ~= nil and a:said("bedtime HH:MM/off") ~= nil and a:said("graveyard") ~= nil)

-- ---------------------------------------------------------------- own death
local n0 = deaths(a)
a:fire("PLAYER_DEAD")
w:advance(1)
local list = a:db().crypt.deaths
check("a member's death is recorded locally, on the full-name key", #list == 1 and list[1].who == "CAMWOWEU4Realm2PvP-Stromham Hamson"
  and list[1].lvl == 23 and list[1].zone == "The Barrens" and list[1].mine == true)
check("a normal death is not sent by default", deaths(a) == n0)
w:advance(2)
check("so the guildie hears nothing and records nothing", #b:db().crypt.deaths == 0 and not b:said("died"))
a:fire("PLAYER_DEAD")
check("a second death inside 60 s is ignored entirely", #list == 1)
w:advance(61)
a:fire("PLAYER_DEAD")
check("one 61 s later is handled", #a:db().crypt.deaths == 2)
a:slash("rip share on")
w:advance(61); a:fire("PLAYER_DEAD"); w:advance(1)
check("share on: a normal death is sent", deaths(a) == n0 + 1 and lastDeath(a).hc == "0")
a.hc = true
w:advance(61); a:fire("PLAYER_DEAD"); w:advance(1)
check("share on: a hardcore death is sent", deaths(a) == n0 + 2 and lastDeath(a).hc == "1")
a:slash("rip share off")
w:advance(61); a:fire("PLAYER_DEAD"); w:advance(1)
check("share off: a hardcore death is recorded but not sent", deaths(a) == n0 + 2 and a:db().crypt.deaths[#a:db().crypt.deaths].hc == true)
a:slash("rip share on")
a.itype = "pvp"
w:advance(61); a:fire("PLAYER_DEAD"); w:advance(1)
check("a battleground on a hardcore character counts as normal: sent as hc 0, not HC", lastDeath(a).hc == "0"
  and a:db().crypt.deaths[#a:db().crypt.deaths].hc == false)
a.itype = "arena"
w:advance(61); a:fire("PLAYER_DEAD"); w:advance(1)
check("an arena likewise", lastDeath(a).hc == "0")
a.itype = "party"
w:advance(61); a:fire("PLAYER_DEAD"); w:advance(1)
check("a dungeon on a hardcore character still counts", lastDeath(a).hc == "1")
a.itype, a.hc = "none", false
a.level, a.zone = nil, nil
w:advance(61); a:fire("PLAYER_DEAD"); w:advance(1)
check("no level and no zone: 0 and \"somewhere\"", lastDeath(a).lvl == "0" and lastDeath(a).zone == "somewhere")
a.level = "x"
w:advance(61); a:fire("PLAYER_DEAD"); w:advance(1)
check("a non-number level is 0", lastDeath(a).lvl == "0")
a.level, a.zone = 30, string.rep("z", 80)
w:advance(61); a:fire("PLAYER_DEAD"); w:advance(1)
check("a long zone is cut to 48 bytes", #lastDeath(a).zone == 48)
local _, longest = lastDeath(a)
check("the longest DEATH is at most 250 bytes (" .. tostring(longest) .. ")", longest <= 250)
a.zone = "The Barrens"
a.noRules = true; a.hc = true
a:slash("rip share off")
w:advance(61); a:fire("PLAYER_DEAD"); w:advance(1)
check("C_GameRules absent: not hardcore", a:db().crypt.deaths[#a:db().crypt.deaths].hc == false)
a.noRules = false; a.hc = "error"
w:advance(61); a:fire("PLAYER_DEAD"); w:advance(1)
check("IsHardcoreActive erroring: not hardcore", a:db().crypt.deaths[#a:db().crypt.deaths].hc == false)
a.hc = false
o:fire("PLAYER_DEAD")
check("a non-member records nothing and sends nothing", #o:db().crypt.deaths == 0 and #o.sent == 0)

-- ---------------------------------------------------------------- received deaths
a:slash("rip share on")
local bd = #b:db().crypt.deaths
b.printed = {}
a.hc = true; a.level = 41; a.zone = "Stranglethorn Vale"
w:advance(61); a:fire("PLAYER_DEAD"); w:advance(1)
check("hardcore notice, exactly", b:said("Rest in Pieces: Stromham Hamson, level 41, Stranglethorn Vale. Hardcore. Gone for good.") ~= nil)
local got = b:db().crypt.deaths[#b:db().crypt.deaths]
check("the receiver records it, on the sender's full key, not as its own", #b:db().crypt.deaths == bd + 1
  and got.who == "CAMWOWEU4Realm2PvP-Stromham Hamson" and got.mine == false and got.hc == true)
check("nothing replies to a DEATH", deaths(b) == 0)
a.hc = false
b.printed = {}
w:advance(61); a:fire("PLAYER_DEAD"); w:advance(1)
check("normal notice, exactly", b:said("Stromham Hamson died at level 41 in Stranglethorn Vale. Again.") ~= nil)
check("the sender prints nothing about its own death", not a:said("died at level"))
check("the outsider hears nothing", #o:db().crypt.deaths == 0 and #o.printed == 0)

local function inject(c, from, d, sender)
  c.DT._comms.inbound("DEADTIRED", c.DT._comms.encode("DEATH", d, from), "GUILD", sender or from:match("%-(.+)$"))
end
b.printed = {}
inject(b, "CAMWOWEU4Realm4PvP-Lilbit High", { lvl = "0", zone = "Duskwood", hc = "0" })
check("level 0 (unknown at the sender) prints as ??, name without realm (R-P5)", b:said("Lilbit High died at level ?? in Duskwood. Again.") ~= nil)
inject(b, "CAMWOWEU4Realm4PvP-Vespa Grim", { lvl = "12", zone = "a|cffff0000b", hc = "0" })
check("a bar in a zone is printed safely", b:said("a||cffff0000b") ~= nil)
local bad = b:db().crypt.badDeath
for i, d in ipairs({ { lvl = "101", zone = "z", hc = "0" }, { lvl = "x", zone = "z", hc = "0" }, { lvl = "5", zone = "", hc = "0" },
    { lvl = "5", zone = string.rep("z", 49), hc = "0" }, { lvl = "5", zone = "z", hc = "2" }, { lvl = 5, zone = "z", hc = "0" } }) do
  inject(b, "CAMWOWEU4Realm2PvP-Bad Death" .. string.char(64 + i), d)
end
check("each invalid DEATH is counted in badDeath, not recorded, not printed", b:db().crypt.badDeath == bad + 6
  and not b:said("Bad Death"))
b:slash("rip off")
b.printed = {}
local before = #b:db().crypt.deaths
inject(b, "CAMWOWEU4Realm2PvP-Quiet One", { lvl = "9", zone = "Mulgore", hc = "0" })
check("rip off: recorded, nothing printed", #b:db().crypt.deaths == before + 1 and #b.printed == 0)
b:slash("rip on")

-- F6a: one sender's flood
b.printed = {}
local nb = #b:db().crypt.deaths
for _ = 1, 10 do inject(b, "CAMWOWEU4Realm2PvP-Flood Er", { lvl = "9", zone = "Mulgore", hc = "0" }); w:advance(1) end
check("F6a: one sender's 10 DEATHs in 10 s: one notice, one record", b:count("Flood Er died") == 1 and #b:db().crypt.deaths == nb + 1)
check("F6a: the rest are counted in crypt.dropped, silently", b:db().crypt.dropped == 9)
inject(b, "CAMWOWEU4Realm2PvP-Other Guy", { lvl = "9", zone = "Mulgore", hc = "0" })
check("F6a: the limit is per sender: another guildie's death still prints", b:said("Other Guy died") ~= nil)
w:advance(61)
inject(b, "CAMWOWEU4Realm2PvP-Flood Er", { lvl = "9", zone = "Mulgore", hc = "0" })
check("F6a: 60 s after the last one kept, the same sender is heard again", b:count("Flood Er died") == 2)
inject(b, "CAMWOWEU4Realm2PvP-Bad Then Good", { lvl = "x", zone = "z", hc = "0" })
inject(b, "CAMWOWEU4Realm2PvP-Bad Then Good", { lvl = "9", zone = "z", hc = "0" })
check("F6a: an invalid DEATH is counted bad and doesn't start the window", b:said("Bad Then Good died") ~= nil)

-- ---------------------------------------------------------------- the graveyard viewport
do
  local w2 = H.world()
  local g = mk(w2, { name = "Gravedigger", full = "Grave Digger" })
  g:login()
  g:slash("graveyard")
  local L = g.DT._crypt.list()
  check("empty graveyard: the empty line in the viewport", L.empty.shown and L.empty.text == "The graveyard's empty. Give it time.")
  check("the closing line under the list", g.DT._crypt.vp().note.text == "Only guildies running the addon, and only deaths seen while you were online.")
  local d = g:db().crypt.deaths
  d[#d + 1] = { who = "CAMWOWEU4Realm2PvP-Old One", lvl = 10, zone = "Durotar", hc = false, at = "2026-11-01 20:00:00" }
  d[#d + 1] = { who = "CAMWOWEU4Realm4PvP-Lilbit High", lvl = 0, zone = "Duskwood", hc = true, at = "2026-11-02 21:00:00" }
  d[#d + 1] = { who = "CAMWOWEU5Realm8PvP-Lilbit High", lvl = 22, zone = "Ashenvale", hc = false, at = "2026-11-03 21:00:00" }
  local rows = g.DT.graveRows()
  check("newest first, date, name, level, zone, (HC) on hardcore", rows[1].day == "2026-11-03" and rows[2].zone == "Duskwood (HC)"
    and rows[2].lvl == "??" and rows[3].name == "Old One")
  check("R-P5 in the graveyard: two of one name both carry the realm", rows[1].name == "Lilbit High (CAMWOWEU5Realm8PvP)"
    and rows[2].name == "Lilbit High (CAMWOWEU4Realm4PvP)" and rows[3].name == "Old One")
  g:slash("graveyard")
  local vp = g.DT._crypt.vp()
  vp.search:SetText("ashen"); vp.search.scripts.OnTextChanged(vp.search)
  local shown = 0
  for _, f in ipairs(g.frames) do if f._type == "Button" and f.row and f.shown and f.row.day then shown = shown + 1 end end
  check("the graveyard is searchable", shown == 1)
  check("not empty: no empty line", not L.empty.shown)
  for i = 1, 120 do d[#d + 1] = { who = "R-X" .. i, lvl = 1, zone = "z", at = "x" } end
  g.DT.crypt()
  local w3 = H.world()
  local g2 = mk(w3, { name = "Gravedigger", full = "Grave Digger", db = g:db() })
  g2:login()
  inject(g2, "CAMWOWEU4Realm2PvP-Last One", { lvl = "9", zone = "Mulgore", hc = "0" })
  check("the memorial is capped at 100, oldest dropped first", #g2:db().crypt.deaths == 100
    and g2:db().crypt.deaths[100].who == "CAMWOWEU4Realm2PvP-Last One")
end

-- ---------------------------------------------------------------- the bedtime nag
do
  local w2 = H.world()
  local n = mk(w2, { name = "Nightowl", full = "Night Owl" })
  n:login()
  local function hour(h, m) n.clock = { h, m } end
  hour(23, 0); w2:advance(600)
  check("off by default: no nag, ever", n:count("Even the dead sleep") == 0)
  n:slash("bedtime 23:30")
  n.printed = {}
  hour(23, 29); w2:advance(60)
  check("not before bedtime", #n.printed == 0)
  hour(23, 30); w2:advance(60)
  check("fires at the time, exactly as written", n:said("It's 23:30. Even the dead sleep.") ~= nil)
  hour(23, 45); w2:advance(60)
  check("nothing more inside 30 minutes", #n.printed == 1)
  hour(0, 0); w2:advance(60)
  check("the second at +30", n:said("Still here. The crypt has a bed with your name on it.") ~= nil)
  hour(0, 30); w2:advance(60)
  check("the third at +60", n:said("Last call. Log off before the sun gets you.") ~= nil)
  hour(1, 30); w2:advance(600)
  check("never a fourth, and not by erroring", #n.printed == 3 and next(n:db().errors) == nil)
  hour(6, 0); w2:advance(60)
  n.printed = {}
  hour(23, 30); w2:advance(60); hour(0, 0); w2:advance(60); hour(0, 30); w2:advance(60); hour(1, 30); w2:advance(60)
  check("the next night starts again: 3 more, no more, no errors", #n.printed == 3 and next(n:db().errors) == nil)
  n.noClock = true
  hour(6, 0); w2:advance(60); n.printed = {}
  hour(23, 30); w2:advance(600)
  check("no clock: the nag never fires, never errors", #n.printed == 0 and next(n:db().errors) == nil)
  n.noClock = false
end

do
  local w2 = H.world()
  local n = mk(w2, { name = "Late", full = "Late Comer", db = { schema = 3, migrated = { port1 = true },
    settings = { crypt = { bedtime = "21:00" } } } })
  n.clock = { 23, 0 }
  n:login()
  w2:advance(61)
  check("a login at bedtime +2 h nags at once", n:said("It's 23:00. Even the dead sleep.") ~= nil)
  w2:advance(120)
  check("not again on the next ticks", n:count("Even the dead sleep") == 1 and #n.printed == 3)
  n.clock = { 23, 30 }; w2:advance(60)
  check("then 30 minutes later", n:said("Still here.") ~= nil)
  local m = mk(w2, { name = "Early", full = "Early Bird", db = { schema = 3, settings = { crypt = { bedtime = "13:00" } } } })
  m.clock = { 20, 0 }
  m:login(); w2:advance(120)
  check("more than 6 hours after bedtime: nothing", m:count("Even the dead sleep") == 0)
  local x = mk(w2, { name = "Out", full = "Out Side", guild = "Elsewhere", db = { schema = 3, settings = { crypt = { bedtime = "19:00" } } } })
  x.clock = { 19, 0 }
  x:login(); w2:advance(120)
  check("nothing for a non-member", #x.printed == 0)
end

-- ---------------------------------------------------------------- A2: the hardcore line
do
  local w2 = H.world()
  local db = { schema = 3 }
  local h = mk(w2, { name = "Hardy", full = "Hardy Bones", db = db, setup = function(c) c.hc = true end })
  h.hc = true
  h:login(); w2:advance(5)
  local HC = "This one's hardcore. If it falls, the guild won't hear unless you /dt rip share on."
  check("A2: first login of a hardcore member prints the line, once", h:count(HC) == 1)
  check("A2: after the welcome, and nothing else", #h.printed == 3 and h.printed[1]:find("Rest in Pieces, Hardy Bones", 1, true)
    and h.printed[3]:find(HC, 1, true))
  h:fire("PLAYER_ENTERING_WORLD", false, false)
  check("A2: not again in the same session", h:count(HC) == 1)
  local r = h:reload(); r.hc = true
  check("A2: not after a /reload", r:count(HC) == 0)
  local h2 = mk(w2, { name = "Hardy", full = "Hardy Bones", db = db }); h2.hc = true
  h2:login()
  check("A2: not on the second login", h2:count(HC) == 0)
  local h3 = mk(w2, { name = "Other", full = "Other Bones", db = db, setup = function(c) c.hc = true end }); h3.hc = true
  h3:login()
  check("A2: another hardcore character on the account gets its own line", h3:count(HC) == 1
    and db.crypt.hcTold["CAMWOWEU4Realm2PvP-Other Bones"] == true)
  local nh = mk(w2, { name = "Soft", full = "Soft Bones" })
  nh:login()
  check("A2: not on a normal character", nh:count(HC) == 0)
  local out = mk(w2, { name = "Hard", full = "Hard Out", guild = "Other" }); out.hc = true
  out:login()
  check("A2: not for a non-member", #out.printed == 0)
  local set = mk(w2, { name = "Set", full = "Set Bones", db = { schema = 3, settings = { crypt = { share = false } } } }); set.hc = true
  set:login()
  check("A2: not once share has been set (even to off)", set:count(HC) == 0)
  local nr = mk(w2, { name = "Norules", full = "No Rules" }); nr.noRules = true
  nr:login()
  check("A2: C_GameRules absent: no line", nr:count(HC) == 0)
  local late = mk(w2, { name = "Late", full = "Late Hard", guild = false }); late.hc = true
  late.guild = nil
  late:login()
  check("A2: guild info not there yet: no line", #late.printed == 0)
  late.guild = G
  late:fire("PLAYER_GUILD_UPDATE")
  check("A2: when membership arrives, the line, once", late:count(HC) == 1)
  late:fire("PLAYER_GUILD_UPDATE")
  check("A2: and not twice", late:count(HC) == 1)
  -- share unset, hardcore: nothing sent
  local nd = deaths(h2)
  w2:advance(61); h2:fire("PLAYER_DEAD"); w2:advance(1)
  check("A2: hardcore, share unset: nothing sent", deaths(h2) == nd and db.crypt.deaths[#db.crypt.deaths].hc == true)
end

-- ---------------------------------------------------------------- quiet, end to end
do
  local w2 = H.world()
  local p = mk(w2, { name = "Pal", full = "Pal Bones" })
  local q = mk(w2, { name = "Quill", full = "Quill Bones" })
  p:login(); q:login(); w2:advance(30)
  check("a login prints nothing from Crypt: each member has only the welcome (and the bar's intro)", #p.printed == 2 and #q.printed == 2
    and p.printed[1]:find("Rest in Pieces, Pal Bones", 1, true) and p.printed[2]:find("bar has risen", 1, true))
  p:slash("rip share on")
  p.printed, q.printed = {}, {}
  w2:advance(61); p:fire("PLAYER_DEAD"); w2:advance(2)
  check("a death on one prints exactly one line on the other", #q.printed == 1 and q.printed[1]:find("Pal Bones died at level 23 in The Barrens. Again.", 1, true))
  check("and nothing on the sender", #p.printed == 0)
  check("the Session counts: one own death on the sender, one new grave on the receiver",
    p.DT.cryptSession.mine == 1 and q.DT.cryptSession.heard == 1)
  p:slash("set crypt enabled off")
  q.printed = {}
  w2:advance(61); p:fire("PLAYER_DEAD"); w2:advance(2)
  check("crypt switched off: nothing recorded or sent", #q.printed == 0 and p.DT.cryptSession.mine == 1)
end

H.finish("crypt")
