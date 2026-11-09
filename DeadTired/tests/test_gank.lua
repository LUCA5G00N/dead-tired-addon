-- Offline checks for Gank.lua (card 4: the gank diary and its board).
--   lua5.1 DeadTired/tests/test_gank.lua  (from the repo root)
-- Target stubs added here, per client, on client.env (card 1's harness is not changed):
-- UnitExists, UnitIsPlayer, UnitFactionGroup, UnitName (the player still answers), UnitClass,
-- UnitLevel, GetRealZoneText. c.tgt = { name, realm, faction, cls, lvl, npc } or nil.
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local ALL = {}
for _, f in ipairs(H.FILES) do ALL[#ALL + 1] = f end
ALL[#ALL + 1] = "Gank.lua"
local CLOSING = "Only logs from guildies running the addon, seen while you were online."
local P = "|cff7fa650Dead Tired|r "

local stub
local function client(w, opts)
  opts.files = opts.files or ALL
  if opts.guild == nil and not opts.outside then opts.guild = G end
  opts.setup = function(c) stub(c) end   -- kept across c:reload() / c:reboot() (fix round 1, F3)
  return w:client(opts)
end

function stub(c)
  c.faction, c.zone, c.stampStr = "Horde", "Stranglethorn Vale", "2026-11-04 23:00:00"
  local env = c.env
  env.UnitExists = function(u) if u == "player" then return true end return u == "target" and c.tgt ~= nil end
  env.UnitIsPlayer = function(u) if u == "player" then return true end return u == "target" and c.tgt ~= nil and not c.tgt.npc end
  env.UnitFactionGroup = function(u)
    if u == "player" then return c.faction end
    if u == "target" and c.tgt then return c.tgt.faction end
  end
  env.UnitName = function(u)
    if u == "player" then return c.name end
    if u == "target" and c.tgt then return c.tgt.name, c.tgt.realm end
  end
  env.UnitClass = function(u)
    if u == "target" and c.tgt and c.tgt.cls then
      if c.tgt.cls == "error" then error("no class") end
      return c.tgt.cls:sub(1, 1) .. c.tgt.cls:sub(2):lower(), c.tgt.cls, 4
    end
  end
  env.UnitLevel = function(u)
    if u == "target" and c.tgt then
      if c.tgt.lvl == "error" then error("no level") end
      return c.tgt.lvl
    end
  end
  env.GetRealZoneText = function() return c.zone end
  env.date = function() return c.stampStr end
end
local function rogue(over)
  local t = { name = "Backstabz", realm = "Nethergarde", faction = "Alliance", cls = "ROGUE", lvl = 60 }
  for k, v in pairs(over or {}) do if v == false then t[k] = nil else t[k] = v end end   -- false: absent
  return t
end
local function ganksSent(c)
  local n = 0
  for _, s in ipairs(c.sent) do if s.text:find("^1%^GANK%^") then n = n + 1 end end
  return n
end
local function logs(c) return c.DT.ganks() end

-- ---------------------------------------------------------------- the store and the verbs
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local g = a:db().gank
  check("store: DeadTiredDB.gank, badGank 0, logs per guild", type(g) == "table" and g.badGank == 0
    and type(logs(a)) == "table" and g["dead tired"].logs == logs(a))
  a:slash("")
  check("the help lists gank and ganks [name], no bar in their usage", a:said(" gank ") and a:said("ganks [name]"))
end

-- ---------------------------------------------------------------- logging
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local function refused(line)
    return #a.printed == 1 and a.printed[1] == P .. line and #logs(a) == 0 and #a.sent == 0
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
  for label, nm in pairs({ secret = hidden, empty = "", ["nil"] = false }) do
    a.tgt = rogue({ name = nm }); a:slash("gank")
    check("name " .. label .. ": refused, nothing recorded or sent",
      refused("The game won't say who that is right now. Try again out of combat."))
  end

  a.tgt = rogue(); a:slash("gank")
  local e = logs(a)[1]
  check("an enemy on another realm is logged", #logs(a) == 1 and e.who == "Nethergarde-Backstabz" and e.cls == "ROGUE"
    and e.lvl == 60 and e.zone == "Stranglethorn Vale" and e.by == "ClassicBetaPvP-Stromham"
    and e.at == "2026-11-04 23:00:00" and e.t == a.env.time())   -- F7: the stored t is the epoch
  check("the confirmation line, exactly", #a.printed == 1
    and a.printed[1] == P .. "Noted: Backstabz-Nethergarde (Rogue 60), Stranglethorn Vale. The crypt remembers.")
  check("and it is sent as GANK", ganksSent(a) == 1
    and a.sent[1].text == "1^GANK^cls~ROGUE^lvl~60^who~Nethergarde-Backstabz^zone~Stranglethorn Vale")
  w:advance(299); a:slash("gank")
  check("a second press at 299 s: already noted", #logs(a) == 1 and ganksSent(a) == 1
    and a.printed[1] == P .. "Already noted. Grudges don't need two copies.")
  w:advance(2); a:slash("gank")
  check("at 301 s: a second log", #logs(a) == 2 and ganksSent(a) == 2)

  a.tgt = rogue({ name = "Paladork", realm = false }); a:slash("gank")
  check("an enemy on our realm: the realm in the one key spelling (fix round 3, AUD-06)", logs(a)[3].who == "ClassicBetaPvP-Paladork"
    and a:said("Noted: Paladork (Rogue 60)") ~= nil)
  a.tgt = rogue({ name = "Shieldy", realm = "" }); a:slash("gank")
  check("an empty realm is our realm too", logs(a)[4].who == "ClassicBetaPvP-Shieldy")
  a.tgt = rogue({ name = "Skully", lvl = -1 }); a:slash("gank")
  check("level -1 (a skull) is stored as -1 and shown as ??", logs(a)[5].lvl == -1 and a:said("(Rogue ??)") ~= nil
    and a.sent[#a.sent].text:find("lvl~-1", 1, true))
  a.tgt = rogue({ name = "Nolvl", lvl = "error" }); a:slash("gank")
  check("level unreadable: -1", logs(a)[6].lvl == -1)
  a.tgt = rogue({ name = "Noclass", cls = "error" }); a:slash("gank")
  check("class unreadable: UNKNOWN", logs(a)[7].cls == "UNKNOWN" and a:said("(Unknown 60)") ~= nil)
  a.zone = nil
  a.tgt = rogue({ name = "Nowhere" }); a:slash("gank")
  check("zone unreadable: somewhere", logs(a)[8].zone == "somewhere")
  a.zone = string.rep("z", 60)
  a.tgt = rogue({ name = "Faraway" }); a:slash("gank")
  check("a long zone is cut to 48 bytes", #logs(a)[9].zone == 48)

  local x = client(w, { name = "Spy", guild = "Alliance Spies" })
  x.tgt = rogue(); x:slash("gank")
  check("a non-member: the router's line, nothing recorded or sent", #x.printed == 1
    and x:said("only stirs inside") ~= nil and #logs(x) == 0 and #x.sent == 0)
end

-- ---------------------------------------------------------------- inbound
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local b = client(w, { name = "Graverobber" })
  a.tgt = rogue(); a:slash("gank")
  w:advance(1)
  local e = logs(b)[1]
  check("a valid log is stored on the receiver, with by", #logs(b) == 1 and e.who == "Nethergarde-Backstabz"
    and e.cls == "ROGUE" and e.lvl == 60 and e.zone == "Stranglethorn Vale" and e.by == "ClassicBetaPvP-Stromham"
    and e.t == nil)
  check("nothing printed on the receiver", #b.printed == 0)
  check("nothing replied, nothing re-sent", #b.sent == 0 and ganksSent(a) == 1)
  local function inject(text) b:fire("CHAT_MSG_ADDON", "DEADTIRED", text, "GUILD", "Ghoul-ClassicBetaPvP") end
  local bad = {
    "1^GANK^cls~ROGUE^lvl~60^zone~Z",                                   -- no who
    "1^GANK^cls~ROGUE^lvl~60^who~NoRealm^zone~Z",                       -- who without a realm
    "1^GANK^cls~ROGUE^lvl~60^who~Realm-^zone~Z",                        -- empty name
    "1^GANK^cls~ROGUE^lvl~60^who~" .. string.rep("r", 60) .. "-Abcde^zone~Z", -- 66 bytes
    "1^GANK^cls~rogue^lvl~60^who~R-N^zone~Z",                           -- lower-case class
    "1^GANK^cls~DEATHKNIGHTXX^lvl~60^who~R-N^zone~Z",                   -- 13 letters
    "1^GANK^lvl~60^who~R-N^zone~Z",                                     -- no class
    "1^GANK^cls~ROGUE^lvl~0^who~R-N^zone~Z",
    "1^GANK^cls~ROGUE^lvl~101^who~R-N^zone~Z",
    "1^GANK^cls~ROGUE^lvl~-2^who~R-N^zone~Z",
    "1^GANK^cls~ROGUE^lvl~6.5^who~R-N^zone~Z",
    "1^GANK^cls~ROGUE^who~R-N^zone~Z",                                  -- no level
    "1^GANK^cls~ROGUE^lvl~60^who~R-N^zone~",
    "1^GANK^cls~ROGUE^lvl~60^who~R-N",
    "1^GANK^cls~ROGUE^lvl~60^who~R-N^zone~" .. string.rep("z", 49),
  }
  for _, t in ipairs(bad) do inject(t) end
  check("each invalid GANK is counted in badGank, not stored, not printed", b:db().gank.badGank == #bad
    and #logs(b) == 1 and #b.printed == 0)
  inject("1^GANK^cls~DEATHKNIGHT^lvl~-1^who~R-N^zone~" .. string.rep("z", 48))
  check("the edges are valid: 11-letter class, level -1, 48-byte zone", #logs(b) == 2 and logs(b)[2].lvl == -1)
  inject("1^GANK^cls~ROGUE^lvl~60^who~R-Bar^zone~The %7CTInterface%7Ct Pit")   -- another enemy: F6b
  b:slash("ganks")
  check("a bar in a received zone prints safely on the board", b:said("The ||TInterface||t Pit") ~= nil)

  local x = client(w, { name = "Spy", guild = "Alliance Spies" })
  x.tgt = rogue({ name = "Someone" }); x:slash("gank")
  w:advance(1)
  check("a non-member's log never arrives", #x.sent == 0 and logs(b)[4] == nil)
end

-- ---------------------------------------------------------------- the board
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  a:slash("ganks")
  check("the empty board, then the closing line", #a.printed == 2 and a.printed[1] == P .. "No grudges yet. Go and make some."
    and a.printed[2] == P .. CLOSING)
  local n = 0
  local function inject(who, from, day, cls, lvl, zone)
    w:advance(301)   -- F6b: one GANK per sender and enemy per 300 s
    a.stampStr = day .. " 01:00:00"
    a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^GANK^cls~" .. (cls or "ROGUE") .. "^lvl~" .. (lvl or 60)
      .. "^who~Nethergarde-" .. who .. "^zone~" .. (zone or "Duskwood"), "GUILD", from .. "-ClassicBetaPvP")
  end
  inject("Backstabz", "Ghoul", "2026-11-01")
  inject("Backstabz", "Wight", "2026-11-02", "ROGUE", 59, "Arathi Highlands")
  inject("Backstabz", "Ghoul", "2026-11-03", "ROGUE", 60, "Hillsbrad Foothills")
  inject("Healbot", "Ghoul", "2026-11-02", "PRIEST", 58)
  inject("Healbot", "Ghoul", "2026-11-02", "PRIEST", 58)
  inject("Archer", "Ghoul", "2026-11-01", "HUNTER", 40)
  inject("Zapper", "Ghoul", "2026-11-01", "MAGE", 40)
  a:slash("ganks")
  check("grouped and counted; distinct loggers; newest class, level, zone and date",
    a.printed[1] == P .. "1. Backstabz-Nethergarde (Rogue 60) x3 by 2 guildies, last Hillsbrad Foothills 2026-11-03")
  check("second by count; one logger is 'guildie'", a.printed[2] == P .. "2. Healbot-Nethergarde (Priest 58) x2 by 1 guildie, last Duskwood 2026-11-02")
  check("a count tie goes to the newest", a.printed[3]:find("3. Zapper", 1, true) and a.printed[4]:find("4. Archer", 1, true))
  check("the closing line", a.printed[#a.printed] == P .. CLOSING and #a.printed == 5)
  for i = 1, 12 do inject("Mob" .. string.char(64 + i), "Ghoul", "2026-11-04") end
  a:slash("ganks")
  check("at most 10 lines, then the closing line", #a.printed == 11 and a.printed[11] == P .. CLOSING)
  for i = 1, 520 do inject("Spam", "Ghoul", "2026-11-04") end
  check("the store is capped at 500, oldest dropped first", #logs(a) == 500 and logs(a)[1].who == "Nethergarde-Spam")
end
do
  -- The brief's third key (name) is unreachable: every log has its own position in the list, so
  -- two enemies never share a newest log and recency always decides a count tie. Proved here
  -- the other way round: a count tie goes to the newer one even when its name sorts first.
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^GANK^cls~MAGE^lvl~1^who~R-Aaa^zone~Z", "GUILD", "Ghoul-ClassicBetaPvP")
  a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^GANK^cls~MAGE^lvl~1^who~R-Bbb^zone~Z", "GUILD", "Ghoul-ClassicBetaPvP")
  a:slash("ganks")
  check("equal counts: newest first even when its name sorts later", a.printed[1]:find("1. Bbb", 1, true)
    and a.printed[2]:find("2. Aaa", 1, true))
end

-- ---------------------------------------------------------------- one enemy
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local function inject(who, from, day, zone)
    w:advance(301)   -- F6b: one GANK per sender and enemy per 300 s
    a.stampStr = day .. " 01:00:00"
    a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^GANK^cls~ROGUE^lvl~60^who~" .. who .. "^zone~" .. zone, "GUILD", from .. "-ClassicBetaPvP")
  end
  inject("Nethergarde-Backstabz", "Ghoul", "2026-11-01", "Duskwood")
  inject("Nethergarde-Backstabz", "Wight", "2026-11-02", "Arathi Highlands")
  for _, q in ipairs({ "Backstabz", "backstabz", "BACKSTABZ-Nethergarde", "Nethergarde-backstabz" }) do
    a:slash("ganks " .. q)
    check("/dt ganks " .. q .. ": newest first, then the closing line", #a.printed == 3
      and a.printed[1] == P .. "2026-11-02 Arathi Highlands (Rogue 60), by Wight"
      and a.printed[2] == P .. "2026-11-01 Duskwood (Rogue 60), by Ghoul" and a.printed[3] == P .. CLOSING)
  end
  a:slash("ganks Nobody")
  check("an unknown name", #a.printed == 1 and a.printed[1] == P .. "Never heard of them. Yet.")
  a:slash("ganks Backstabz-Stormrage")
  check("a wrong realm is unknown", a.printed[1] == P .. "Never heard of them. Yet.")
  inject("Stormrage-Backstabz", "Ghoul", "2026-11-03", "Duskwood")
  a:slash("ganks backstabz")
  check("the same name on two realms asks for the realm", a:said("more than one backstabz") ~= nil
    and a:said("Add the realm.") ~= nil)
  for i = 1, 15 do inject("Nethergarde-Backstabz", "Ghoul", "2026-11-04", "Zone" .. i) end
  a:slash("ganks Backstabz-Nethergarde")
  check("at most 10 lines for one enemy, newest first", #a.printed == 11 and a.printed[1]:find("Zone15", 1, true)
    and a.printed[10]:find("Zone6", 1, true) and a.printed[11] == P .. CLOSING)
end

-- ---------------------------------------------------------------- byte budget
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local who = string.rep("r", 58) .. "-Abcde"
  local m = a.DT._comms.encode("GANK", { who = who, cls = "ABCDEFGHIJKL", lvl = "100", zone = string.rep("^", 48) })
  print("gank: longest GANK is " .. #m .. " bytes")
  check("the longest GANK is at most 250 bytes (" .. #m .. ")", #who == 64 and #m <= 250)
end

-- ---------------------------------------------------------------- the whole addon
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local b = client(w, { name = "Graverobber" })
  local x = client(w, { name = "Spy", guild = "Alliance Spies" })
  a:login(); b:login(); x:login()
  w:advance(60)
  check("a login prints nothing from Gank: each member has only the welcome", #a.printed == 1 and #b.printed == 1
    and #x.printed == 0)
  a.printed, b.printed = {}, {}
  a.tgt = rogue(); a:slash("gank"); w:advance(1)
  check("a log on one appears on the other's board", #b.printed == 0 and (function()
    b:slash("ganks"); return b:said("1. Backstabz-Nethergarde (Rogue 60) x1 by 1 guildie") ~= nil end)())
  check("the non-member receives and prints nothing", #x.printed == 0 and #logs(x) == 0)
end

-- ---------------------------------------------------------------- fix round 1 (F7, F6b)
do
  local w = H.world()
  w.t = 500000                       -- the machine has been up ~5.8 days
  local a = client(w, { name = "Stromham" })
  a.tgt = rogue(); a:slash("gank")
  check("F7 baseline: noted, and the stored t is the epoch, not uptime", #logs(a) == 1
    and logs(a)[1].t == a.env.time() and logs(a)[1].t > 1000000000)
  -- a restart: GetTime() starts again at 20 minutes, time() carries on; the enemy is back
  w:advance(86400)
  local a2 = a:reboot(1200)
  a2.tgt = rogue(); a2.printed = {}
  a2:slash("gank")
  check("F7: after a restart, the same enemy a day later is noted, not 'already noted'",
    a2:said("Noted: Backstabz") ~= nil and #logs(a2) == 2)
  a2.printed = {}
  w:advance(100); a2:slash("gank")
  check("F7: the 300 s window still holds within a session", a2:said("Already noted") ~= nil and #logs(a2) == 2)
  -- a reload inside the window forgets it: the press is recorded again (memory only, by design)
  local a3 = a2:reload()
  a3.tgt = rogue(); a3.printed = {}
  a3:slash("gank")
  check("F7: the window is memory only: after a /reload the press is noted", a3:said("Noted: Backstabz") ~= nil)
end

do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local function inject(who, from)
    a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^GANK^cls~ROGUE^lvl~60^who~" .. who .. "^zone~Duskwood", "GUILD",
      from .. "-ClassicBetaPvP")
  end
  inject("Nethergarde-Backstabz", "Ghoul")
  for i = 1, 9 do w:advance(10); inject("Nethergarde-Backstabz", "Ghoul") end
  check("F6b: one sender's 10 GANKs on one enemy inside 300 s keep one", #logs(a) == 1)
  check("F6b: the rest are counted in gank.dropped", a:db().gank.dropped == 9)
  inject("Nethergarde-Healbot", "Ghoul")
  inject("Nethergarde-Backstabz", "Wight")
  check("F6b: per sender and enemy: another enemy, or another guildie, is kept", #logs(a) == 3)
  w:advance(210)    -- 300 s after Ghoul's first on Backstabz
  inject("Nethergarde-Backstabz", "Ghoul")
  check("F6b: at 300 s the same sender and enemy is kept again", #logs(a) == 4)
end

-- ---------------------------------------------------------------- fix round 3 (AUD-06)
do
  local w = H.world()
  local db = { gank = { ["dead tired"] = { logs = {
    { who = "Classic Beta PvP-Paladork", cls = "PALADIN", lvl = 40, zone = "Duskwood", by = "Classic Beta PvP-Stromham", at = "2026-11-01 20:00:00" },
    { who = "Nethergarde-Backstabz", cls = "ROGUE", lvl = 60, zone = "Duskwood", by = "Argent Dawn-Ghoul", at = "2026-11-01 21:00:00" },
  } } } }
  local a = client(w, { name = "Stromham", db = db })
  local l = db.gank["dead tired"].logs
  check("AUD-06: an old spaced key in the gank log is rewritten (who and by)", l[1].who == "ClassicBetaPvP-Paladork"
    and l[1].by == "ClassicBetaPvP-Stromham" and l[2].by == "ArgentDawn-Ghoul" and l[2].who == "Nethergarde-Backstabz"
    and db.gank.keysV == 2)
  a.tgt = rogue({ name = "Paladork", realm = false }); w:advance(400); a:slash("gank")
  a:slash("ganks")
  check("AUD-06: a new log of the same enemy groups with the migrated one", a:said("Paladork (Rogue 60) x2") ~= nil)
  l[1].who = "Classic Beta PvP-Paladork"
  client(w, { name = "Stromham", db = db })
  check("AUD-06: the gank migration runs once", l[1].who == "Classic Beta PvP-Paladork")
  a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^GANK^cls~ROGUE^lvl~60^who~Argent Dawn-Sneaky^zone~Duskwood", "GUILD", "Ghoul-ClassicBetaPvP")
  check("AUD-06: a received who in the old spelling is stored in the new", l[#l].who == "ArgentDawn-Sneaky")
end

H.finish("gank")
