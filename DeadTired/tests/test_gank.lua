-- Offline checks for Gank.lua (card 4, the gank diary, ported from rc3 in Port 2): rc3's checks on
-- full-name keys, the board in a viewport, R1 proved (the target is read only on /dt gank).
--   lua5.1 DeadTired/tests/test_gank.lua
-- Stubs per client (c.env): UnitExists, UnitIsPlayer, UnitFactionGroup, UnitName / GetUnitName for
-- the target, UnitClass, UnitLevel, GetRealZoneText, date. c.tgt = { name, full, faction, cls, lvl,
-- npc, shown (what GetUnitName("target", true) answers; default full) } or nil. Every read of the
-- target is counted in c.targetReads.
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local R2 = "CAMWOW EU4 Realm 2 PvP"
local K2 = "CAMWOWEU4Realm2PvP-"
local P = "|cff7fa650Dead Tired|r "
local CLOSING = "Only logs from guildies running the addon, seen while you were online."

local function stub(c)
  c.faction, c.zone, c.stampStr, c.targetReads = "Horde", "Stranglethorn Vale", "2026-11-04 23:00:00", 0
  local env = c.env
  local function tread(u) if u == "target" then c.targetReads = c.targetReads + 1 end end
  rawset(env, "UnitExists", function(u) tread(u); if u == "player" then return true end return u == "target" and c.tgt ~= nil end)
  rawset(env, "UnitIsPlayer", function(u) tread(u); if u == "player" then return true end return u == "target" and c.tgt ~= nil and not c.tgt.npc end)
  rawset(env, "UnitFactionGroup", function(u)
    tread(u)
    if u == "player" then return c.faction end
    if u == "target" and c.tgt then return c.tgt.faction end
  end)
  local plainName, plainGet = rawget(env, "UnitName"), rawget(env, "GetUnitName")
  rawset(env, "UnitName", function(u, ...)
    if u == "target" then tread(u); if c.tgt then return c.tgt.name, c.tgt.second end return nil end
    return plainName(u, ...)
  end)
  rawset(env, "GetUnitName", function(u, showRealm)
    if u == "target" then
      tread(u)
      if not c.tgt then return nil end
      if c.tgt.shown ~= nil then return c.tgt.shown or nil end
      return showRealm and c.tgt.full or c.tgt.name
    end
    return plainGet(u, showRealm)
  end)
  rawset(env, "UnitClass", function(u)
    tread(u)
    if u == "target" and c.tgt and c.tgt.cls then
      if c.tgt.cls == "error" then error("no class") end
      return c.tgt.cls:sub(1, 1) .. c.tgt.cls:sub(2):lower(), c.tgt.cls, 4
    end
  end)
  rawset(env, "UnitLevel", function(u)
    tread(u)
    if u == "target" and c.tgt then
      if c.tgt.lvl == "error" then error("no level") end
      return c.tgt.lvl
    end
  end)
  rawset(env, "GetRealZoneText", function() return c.zone end)
  rawset(env, "date", function() return c.stampStr end)
end

local function mk(w, o)
  o.realm = o.realm or R2
  if o.guild == nil then o.guild = G end
  local setup = o.setup
  o.setup = function(c) stub(c); if setup then setup(c) end end
  return w:client(o)
end

-- An Alliance rogue on another realm: GetUnitName("target", true) gives "Backstabz Dagger-Nethergarde".
local function rogue(over)
  local t = { name = "Backstabz", full = "Backstabz Dagger-Nethergarde", faction = "Alliance", cls = "ROGUE", lvl = 60,
    second = "Dagger" }       -- what UnitName / UnitFullName's second value would be on Forever: the surname
  for k, v in pairs(over or {}) do if v == false then t[k] = nil else t[k] = v end end
  return t
end
local function ganksSent(c)
  local out = {}
  for _, m in ipairs(c.sent) do
    local ok, p = c.DT._comms.decode(m.text)
    if ok == "ok" and p.k == "GANK" then out[#out + 1] = p.d end
  end
  return out
end
local function logs(c) return c.DT.ganks() end
local function inject(c, from, d, sender)
  c.DT._comms.inbound("DEADTIRED", c.DT._comms.encode("GANK", d, from), "GUILD", sender or from:match("%-(.+)$"))
end
local function boardRows(c) return c.DT.gankRows() end

-- ---------------------------------------------------------------- the store and the verbs
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  a:login()
  local g = a:db().gank
  check("store: DeadTiredDB.gank, badGank 0, one logs list", type(g) == "table" and g.badGank == 0
    and type(logs(a)) == "table" and g.logs == logs(a))
  a:slash("")
  check("the help lists gank and ganks [name]", a:said(" gank ") ~= nil and a:said("ganks [name]") ~= nil)
end

-- ---------------------------------------------------------------- logging
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  a:login(); w:advance(30)
  local function refused(line)
    return #a.printed == 1 and a.printed[1] == P .. line and #logs(a) == 0 and #ganksSent(a) == 0
  end
  a.tgt = nil; a:slash("gank")
  check("no target: refused, nothing recorded or sent", refused("Target a player first. Preferably one who deserves it."))
  a.tgt = rogue({ npc = true }); a:slash("gank")
  check("an NPC: refused", refused("Target a player first. Preferably one who deserves it."))
  a.tgt = rogue({ faction = "Horde" }); a:slash("gank")
  check("a same-faction player: refused", refused("That's one of ours. Put the pen down."))
  a.tgt = rogue({ faction = false }); a:slash("gank")
  check("a player with no faction readable: refused", refused("That's one of ours. Put the pen down."))
  a.tgt = rogue(); a.faction = nil; a:slash("gank")
  check("our own faction unreadable: refused", refused("That's one of ours. Put the pen down."))
  a.faction = "Horde"
  local hidden = {}
  a.secrets[hidden] = true
  for _, case in ipairs({ { "secret", hidden }, { "empty", "" }, { "nil", false } }) do
    local label, nm = case[1], case[2]
    a.tgt = rogue({ name = nm, shown = nm, full = false }); a:slash("gank")
    check("name " .. label .. ": refused, nothing recorded or sent",
      refused("The game won't say who that is right now. Try again out of combat."))
  end

  a.tgt = rogue(); a:slash("gank")
  local e = logs(a)[1]
  check("an enemy on another realm is logged by the full name (surname kept), realm from its -Realm",
    #logs(a) == 1 and e.who == "Nethergarde-Backstabz Dagger" and e.cls == "ROGUE"
    and e.lvl == 60 and e.zone == "Stranglethorn Vale" and e.by == K2 .. "Stromham Hamson"
    and e.at == "2026-11-04 23:00:00" and e.t == a.env.time())   -- F7: the stored t is the epoch
  check("the port rule: the realm never comes from UnitName's (or UnitFullName's) second value",
    not e.who:find("Dagger-", 1, true) and e.who:sub(1, 12) == "Nethergarde-")
  check("the confirmation line, exactly (R-P5: the name without realm)", #a.printed == 1
    and a.printed[1] == P .. "Noted: Backstabz Dagger (Rogue 60), Stranglethorn Vale. The crypt remembers.")
  w:advance(1)
  local s = ganksSent(a)[1]
  check("and it is sent as GANK", #ganksSent(a) == 1 and s.who == "Nethergarde-Backstabz Dagger" and s.cls == "ROGUE"
    and s.lvl == "60" and s.zone == "Stranglethorn Vale")
  w:advance(298); a:slash("gank")
  check("a second press at 299 s: already noted", #logs(a) == 1 and #ganksSent(a) == 1
    and a.printed[1] == P .. "Already noted. Grudges don't need two copies.")
  w:advance(2); a:slash("gank"); w:advance(1)
  check("at 301 s: a second log", #logs(a) == 2 and #ganksSent(a) == 2)

  a.tgt = rogue({ name = "Paladork", full = "Paladork Shield" }); a:slash("gank")
  check("an enemy on our realm (no -Realm): our realm key", logs(a)[3].who == K2 .. "Paladork Shield"
    and a:said("Noted: Paladork Shield (Rogue 60)") ~= nil)
  a.tgt = rogue({ name = "Shieldy", full = "Shieldy Wall-" }); a:slash("gank")
  check("an empty realm is our realm too", logs(a)[4].who == K2 .. "Shieldy Wall")
  a.tgt = rogue({ name = "Shorty", full = false, shown = "" }); a:slash("gank")
  check("GetUnitName empty: UnitName's name, our realm", logs(a)[5].who == K2 .. "Shorty")
  a.tgt = rogue({ name = "Skully", full = "Skully Bones", lvl = -1 }); a:slash("gank")
  w:advance(1)
  check("level -1 (a skull) is stored as -1 and shown as ??", logs(a)[6].lvl == -1 and a:said("(Rogue ??)") ~= nil
    and ganksSent(a)[6].lvl == "-1")
  a.tgt = rogue({ name = "Nolvl", full = "Nolvl X", lvl = "error" }); a:slash("gank")
  check("level unreadable: -1", logs(a)[7].lvl == -1)
  a.tgt = rogue({ name = "Noclass", full = "Noclass X", cls = "error" }); a:slash("gank")
  check("class unreadable: UNKNOWN", logs(a)[8].cls == "UNKNOWN" and a:said("(Unknown 60)") ~= nil)
  a.zone = nil
  a.tgt = rogue({ name = "Nowhere", full = "Nowhere X" }); a:slash("gank")
  check("zone unreadable: somewhere", logs(a)[9].zone == "somewhere")
  a.zone = string.rep("z", 60)
  a.tgt = rogue({ name = "Faraway", full = "Faraway X" }); a:slash("gank")
  check("a long zone is cut to 48 bytes", #logs(a)[10].zone == 48)

  local x = mk(w, { name = "Spy", full = "Spy Glass", guild = "Alliance Spies" })
  x:login()
  x.tgt = rogue(); x:slash("gank")
  check("a non-member: nothing printed, recorded or sent", #x.printed == 0 and #logs(x) == 0 and #x.sent == 0)
end

-- ---------------------------------------------------------------- R1: the target read only on /dt gank
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  local b = mk(w, { name = "Echo", full = "Echo Nightclaw" })
  a.tgt = rogue()
  a:login(); b:login()
  for _ = 1, 24 do
    a:fire("PLAYER_TARGET_CHANGED"); a:fire("PLAYER_ENTERING_WORLD", false, false); a:fire("ZONE_CHANGED_NEW_AREA")
    a:slash("ganks"); a:slash("ganks Backstabz"); a:slash("settings")
    w:advance(120)
  end
  check("R1: 24 rounds of logins, zoning, target changes and board views: the target never read", a.targetReads == 0)
  check("R1: and nothing logged or sent", #logs(a) == 0 and #ganksSent(a) == 0)
  local okCall = a.DT.gank()
  check("R1: DT.gank() called from anywhere but the typed verb reads nothing, logs nothing", okCall == false
    and a.targetReads == 0 and #logs(a) == 0)
  a.DT.after(1, function() a.DT.gank() end); w:advance(2)
  check("R1: ...from a timer too", a.targetReads == 0 and #logs(a) == 0)
  a:slash("gank")
  check("R1: /dt gank reads the target", a.targetReads > 0 and #logs(a) == 1)
end

-- ---------------------------------------------------------------- inbound
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  local b = mk(w, { name = "Echo", full = "Echo Nightclaw" })
  a:login(); b:login(); w:advance(5)
  b.printed = {}
  local bSent = #b.sent
  a.tgt = rogue(); a:slash("gank")
  w:advance(1)
  local e = logs(b)[1]
  check("a valid log is stored on the receiver, with by", #logs(b) == 1 and e.who == "Nethergarde-Backstabz Dagger"
    and e.cls == "ROGUE" and e.lvl == 60 and e.zone == "Stranglethorn Vale" and e.by == K2 .. "Stromham Hamson"
    and e.t == nil)
  check("nothing printed on the receiver", #b.printed == 0)
  check("nothing replied, nothing re-sent", #b.sent == bSent and #ganksSent(b) == 0 and #ganksSent(a) == 1)
  local G1 = K2 .. "Ghoul Grim"
  local bad = {
    { cls = "ROGUE", lvl = "60", zone = "Z" },                                         -- no who
    { cls = "ROGUE", lvl = "60", who = "NoRealm", zone = "Z" },                        -- who without a realm
    { cls = "ROGUE", lvl = "60", who = "Realm-", zone = "Z" },                         -- empty name
    { cls = "ROGUE", lvl = "60", who = string.rep("r", 60) .. "-Abcde", zone = "Z" },  -- 66 bytes
    { cls = "rogue", lvl = "60", who = "R-N", zone = "Z" },                            -- lower-case class
    { cls = "DEATHKNIGHTXX", lvl = "60", who = "R-N", zone = "Z" },                    -- 13 letters
    { lvl = "60", who = "R-N", zone = "Z" },                                           -- no class
    { cls = "ROGUE", lvl = "0", who = "R-N", zone = "Z" },
    { cls = "ROGUE", lvl = "101", who = "R-N", zone = "Z" },
    { cls = "ROGUE", lvl = "-2", who = "R-N", zone = "Z" },
    { cls = "ROGUE", lvl = "6.5", who = "R-N", zone = "Z" },
    { cls = "ROGUE", who = "R-N", zone = "Z" },                                        -- no level
    { cls = "ROGUE", lvl = "60", who = "R-N", zone = "" },
    { cls = "ROGUE", lvl = "60", who = "R-N" },
    { cls = "ROGUE", lvl = "60", who = "R-N", zone = string.rep("z", 49) },
  }
  for _, d in ipairs(bad) do inject(b, G1, d) end
  check("each invalid GANK is counted in badGank, not stored, not printed", b:db().gank.badGank == #bad
    and #logs(b) == 1 and #b.printed == 0)
  inject(b, G1, { cls = "DEATHKNIGHT", lvl = "-1", who = "R-N", zone = string.rep("z", 48) })
  check("the edges are valid: 11-letter class, level -1, 48-byte zone", #logs(b) == 2 and logs(b)[2].lvl == -1)
  inject(b, G1, { cls = "ROGUE", lvl = "60", who = "Argent Dawn-Sneaky Pete", zone = "Duskwood" })
  check("a received who in another spelling is stored in the one spelling", logs(b)[3].who == "ArgentDawn-Sneaky Pete")
  inject(b, G1, { cls = "ROGUE", lvl = "60", who = "R-Bar", zone = "The |TInterface|t Pit" })
  b:slash("ganks")
  local found
  for _, r in ipairs(boardRows(b)) do if r.last:find("The ||TInterface||t Pit", 1, true) then found = true end end
  check("a bar in a received zone shows safely on the board", found == true)

  local x = mk(w, { name = "Spy", full = "Spy Glass", guild = "Alliance Spies" })
  x:login()
  x.tgt = rogue({ name = "Someone", full = "Someone Else" }); x:slash("gank")
  w:advance(1)
  check("a non-member's log never arrives", #x.sent == 0 and logs(b)[5] == nil)
end

-- ---------------------------------------------------------------- the board (a viewport)
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  a:login()
  a:slash("ganks")
  local vp = a.DT._gank.vp()
  local L = a.DT._gank.list()
  check("/dt ganks opens the board viewport", vp ~= nil and vp:IsShown())
  check("the empty board: rc3's empty line in it", L.empty.shown and L.empty.text == "No grudges yet. Go and make some.")
  check("the closing line under the list", vp.note.text == CLOSING)
  check("the board is a DT viewport: Escape closes it (R-P2-2)", vp.name == "DeadTiredViewport_gank")
  local function ing(who, from, day, cls, lvl, zone)
    w:advance(301)   -- F6b: one GANK per sender and enemy per 300 s
    a.stampStr = day .. " 01:00:00"
    inject(a, K2 .. from, { cls = cls or "ROGUE", lvl = tostring(lvl or 60), who = "Nethergarde-" .. who, zone = zone or "Duskwood" })
  end
  ing("Backstabz Dagger", "Ghoul Grim", "2026-11-01")
  ing("Backstabz Dagger", "Wight Pale", "2026-11-02", "ROGUE", 59, "Arathi Highlands")
  ing("Backstabz Dagger", "Ghoul Grim", "2026-11-03", "ROGUE", 60, "Hillsbrad Foothills")
  ing("Healbot Light", "Ghoul Grim", "2026-11-02", "PRIEST", 58)
  ing("Healbot Light", "Ghoul Grim", "2026-11-02", "PRIEST", 58)
  ing("Archer Bow", "Ghoul Grim", "2026-11-01", "HUNTER", 40)
  ing("Zapper Spark", "Ghoul Grim", "2026-11-01", "MAGE", 40)
  local rows = boardRows(a)
  check("most frequent first; grouped and counted; distinct loggers; newest class, level, zone and date",
    rows[1].name == "Backstabz Dagger" and rows[1].what == "(Rogue 60)" and rows[1].by == "x3 by 2 guildies"
    and rows[1].last == "last Hillsbrad Foothills" and rows[1].full == "2026-11-03" and rows[1].day == "3 Nov")
  check("second by count; one logger is 'guildie'", rows[2].name == "Healbot Light" and rows[2].by == "x2 by 1 guildie"
    and rows[2].what == "(Priest 58)")
  check("a count tie goes to the newest", rows[3].name == "Zapper Spark" and rows[4].name == "Archer Bow")
  check("names without realm (R-P5)", not rows[1].name:find("Nethergarde", 1, true))
  a:slash("ganks")
  check("the board shows them; no empty line", not L.empty.shown and L.rows[1].shown and L.rows[1].row.name == "Backstabz Dagger")
  vp.search:SetText("priest"); vp.search.scripts.OnTextChanged(vp.search)
  local shown = 0
  for _, b in ipairs(L.rows) do if b.shown then shown = shown + 1 end end
  check("the board is searchable", shown == 1 and L.rows[1].row.name == "Healbot Light")
  vp.search:SetText(""); vp.search.scripts.OnTextChanged(vp.search)
  for i = 1, 520 do inject(a, K2 .. "Spammer N" .. i, { cls = "ROGUE", lvl = "60", who = "Nethergarde-Spam" .. (i % 2), zone = "Z" }) end
  check("the store is capped at 500, oldest dropped first", #logs(a) == 500 and logs(a)[1].who:find("Spam", 1, true))
  check("a printed /dt ganks line count: the board prints nothing in chat", (function()
    a:slash("ganks"); return #a.printed == 0 end)())
end
do
  -- equal counts: newest first even when its name sorts later
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  a:login()
  inject(a, K2 .. "Ghoul Grim", { cls = "MAGE", lvl = "1", who = "R-Aaa A", zone = "Z" })
  inject(a, K2 .. "Ghoul Grim", { cls = "MAGE", lvl = "1", who = "R-Bbb B", zone = "Z" })
  local rows = boardRows(a)
  check("equal counts: newest first even when its name sorts later", rows[1].name == "Bbb B" and rows[2].name == "Aaa A")
end

-- ---------------------------------------------------------------- one enemy (printed)
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  a:login()
  local function ing(who, from, day, zone)
    w:advance(301)
    a.stampStr = day .. " 01:00:00"
    inject(a, K2 .. from, { cls = "ROGUE", lvl = "60", who = who, zone = zone })
  end
  ing("Nethergarde-Backstabz Dagger", "Ghoul Grim", "2026-11-01", "Duskwood")
  ing("Nethergarde-Backstabz Dagger", "Wight Pale", "2026-11-02", "Arathi Highlands")
  for _, q in ipairs({ "Backstabz", "backstabz", "Backstabz Dagger", "BACKSTABZ DAGGER-Nethergarde", "Nethergarde-backstabz dagger",
      "backstabz-Nethergarde" }) do
    a:slash("ganks " .. q)
    check("/dt ganks " .. q .. ": newest first, then the closing line", #a.printed == 3
      and a.printed[1] == P .. "2026-11-02 Arathi Highlands (Rogue 60), by Wight Pale"
      and a.printed[2] == P .. "2026-11-01 Duskwood (Rogue 60), by Ghoul Grim" and a.printed[3] == P .. CLOSING)
  end
  a:slash("ganks Nobody")
  check("an unknown name", #a.printed == 1 and a.printed[1] == P .. "Never heard of them. Yet.")
  a:slash("ganks Backstabz-Stormrage")
  check("a wrong realm is unknown", a.printed[1] == P .. "Never heard of them. Yet.")
  ing("Stormrage-Backstabz Dagger", "Ghoul Grim", "2026-11-03", "Duskwood")
  a:slash("ganks backstabz")
  check("the same name on two realms asks for the realm", a:said("more than one backstabz") ~= nil
    and a:said("Add the realm.") ~= nil and a:said("Backstabz Dagger (Nethergarde)") ~= nil)
  for i = 1, 15 do ing("Nethergarde-Backstabz Dagger", "Ghoul Grim", "2026-11-04", "Zone" .. i) end
  a:slash("ganks Backstabz-Nethergarde")
  check("at most 10 lines for one enemy, newest first", #a.printed == 11 and a.printed[1]:find("Zone15", 1, true)
    and a.printed[10]:find("Zone6", 1, true) and a.printed[11] == P .. CLOSING)
end

-- ---------------------------------------------------------------- the whole addon
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  local b = mk(w, { name = "Echo", full = "Echo Nightclaw" })
  local x = mk(w, { name = "Spy", full = "Spy Glass", guild = "Alliance Spies" })
  a:login(); b:login(); x:login()
  w:advance(60)
  local function gankLines(c)
    local n = 0
    for _, m in ipairs(c.printed) do if m:find("gank", 1, true) or m:find("grudge", 1, true) then n = n + 1 end end
    return n
  end
  check("a login prints nothing from Gank", gankLines(a) == 0 and gankLines(b) == 0 and #x.printed == 0)
  a.printed, b.printed = {}, {}
  a.tgt = rogue(); a:slash("gank"); w:advance(1)
  check("a log on one appears on the other's board (H6)", #b.printed == 0 and boardRows(b)[1]
    and boardRows(b)[1].name == "Backstabz Dagger" and boardRows(b)[1].by == "x1 by 1 guildie")
  check("the non-member receives and prints nothing", #x.printed == 0 and #logs(x) == 0)
end

-- ---------------------------------------------------------------- fix round 1 (F7, F6b)
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  a:login()
  a.tgt = rogue(); a:slash("gank")
  check("F7 baseline: noted, and the stored t is the epoch, not uptime", #logs(a) == 1
    and logs(a)[1].t == a.env.time() and logs(a)[1].t > 1000000000)
  w:advance(100); a:slash("gank")
  check("F7: the 300 s window holds within a session", a:said("Already noted") ~= nil and #logs(a) == 1)
  local a2 = a:reload()
  a2.tgt = rogue(); a2.printed = {}
  a2:slash("gank")
  check("F7: the window is memory only: after a /reload the press is noted", a2:said("Noted: Backstabz Dagger") ~= nil
    and #logs(a2) == 2)
end
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  a:login()
  local function ing(who, from)
    inject(a, K2 .. from, { cls = "ROGUE", lvl = "60", who = who, zone = "Duskwood" })
  end
  ing("Nethergarde-Backstabz Dagger", "Ghoul Grim")
  for _ = 1, 9 do w:advance(10); ing("Nethergarde-Backstabz Dagger", "Ghoul Grim") end
  check("F6b: one sender's 10 GANKs on one enemy inside 300 s keep one", #logs(a) == 1)
  check("F6b: the rest are counted in gank.dropped", a:db().gank.dropped == 9)
  ing("Nethergarde-Healbot Light", "Ghoul Grim")
  ing("Nethergarde-Backstabz Dagger", "Wight Pale")
  check("F6b: per sender and enemy: another enemy, or another guildie, is kept", #logs(a) == 3)
  w:advance(210)
  ing("Nethergarde-Backstabz Dagger", "Ghoul Grim")
  check("F6b: at 300 s the same sender and enemy is kept again", #logs(a) == 4)
end

H.finish("gank")
