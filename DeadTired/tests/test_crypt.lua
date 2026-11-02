-- Offline checks for Crypt.lua (card 3: death notices, graveyard, bedtime nag).
--   lua5.1 DeadTired/tests/test_crypt.lua  (from the repo root)
-- Stubs added here, per client, on client.env (card 1's harness is not changed): UnitLevel,
-- GetRealZoneText, IsInInstance, C_GameRules.IsHardcoreActive, and date("*t") for the clock.
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local ALL = {}
for _, f in ipairs(H.FILES) do ALL[#ALL + 1] = f end
ALL[#ALL + 1] = "Crypt.lua"
local CLOSING = "Only guildies running the addon, and only deaths seen while you were online."

local function client(w, opts)
  opts.files = opts.files or ALL
  if opts.guild == nil and not opts.outside then opts.guild = G end
  local c = w:client(opts)
  c.lvl, c.zone, c.hc, c.itype, c.stampStr = 23, "Stranglethorn Vale", false, "none", "2026-11-04 23:00:00"
  c.clockBase = 12 * 60
  c.env.UnitLevel = function(u) if c.noLevel then error("no level") end return c.lvl end
  c.env.GetRealZoneText = function() if c.noZone then return nil end return c.zone end
  c.env.IsInInstance = function() return c.itype ~= "none", c.itype end
  c.env.C_GameRules = { IsHardcoreActive = function() return c.hc end }
  c.env.date = function(fmt)
    if fmt == "*t" then
      if c.noClock then return nil end
      local m = (c.clockBase + math.floor((w.t - 1000) / 60)) % 1440
      return { hour = math.floor(m / 60), min = m % 60 }
    end
    return c.stampStr
  end
  return c
end
local function setClock(w, c, hhmm)
  local h, m = hhmm:match("^(%d+):(%d+)$")
  c.clockBase = tonumber(h) * 60 + tonumber(m) - math.floor((w.t - 1000) / 60)
end
local function deathsSent(c)
  local n = 0
  for _, s in ipairs(c.sent) do if s.text:find("^1%^DEATH%^") then n = n + 1 end end
  return n
end
local function lastSent(c) return c.sent[#c.sent] and c.sent[#c.sent].text end
local function list(c) return c.DT.deaths() end

-- ---------------------------------------------------------------- the store and the verbs
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local cr = a:db().crypt
  check("store: DeadTiredDB.crypt, notices on, share unset, no bedtime", type(cr) == "table"
    and cr.rip == true and cr.share == nil and cr.bedtime == nil and cr.badDeath == 0)
  check("store: deaths per guild", type(list(a)) == "table" and cr["dead tired"].deaths == list(a))
  a:slash("rip")
  check("/dt rip alone shows both settings, share unset shown as off (A2)", a:said("notices on; sharing your deaths off.") ~= nil)
  a:slash("rip off"); check("/dt rip off", cr.rip == false and a:said("notices off") ~= nil)
  a:slash("rip on"); check("/dt rip on", cr.rip == true and a:said("notices on") ~= nil)
  a:slash("rip share on"); check("/dt rip share on", cr.share == true)
  a:slash("rip share off"); check("/dt rip share off", cr.share == false)
  a:slash("rip"); check("/dt rip shows share off once set", a:said("sharing your deaths off.") ~= nil)
  a:slash("rip sideways"); check("/dt rip <other> prints usage, changes nothing", cr.rip == true and a:said("/dt rip on/off") ~= nil)
  a:slash("bedtime"); check("/dt bedtime alone: off", a:said("bedtime is off.") ~= nil)
  a:slash("bedtime 1:05"); check("/dt bedtime H:MM stored zero-padded", cr.bedtime == "01:05")
  a:slash("bedtime 23:59"); check("/dt bedtime 23:59", cr.bedtime == "23:59")
  for _, bad in ipairs({ "25:00", "7", "ab:cd", "12:60", "12:5", "-1:00" }) do
    a:slash("bedtime " .. bad)
    check("/dt bedtime " .. bad .. " is refused", cr.bedtime == "23:59" and a:said("/dt bedtime HH:MM") ~= nil)
  end
  a:slash("bedtime"); check("/dt bedtime alone: the time", a:said("bedtime is 23:59.") ~= nil)
  a:slash("bedtime off"); check("/dt bedtime off", cr.bedtime == nil and a:said("bedtime off.") ~= nil)
  a:slash("")
  check("the help lists the new verbs, no bar characters in their usage", a:said("bedtime HH:MM/off")
    and a:said("graveyard") and a:said("rip [share] on/off"))
end

-- ---------------------------------------------------------------- own death
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local b = client(w, { name = "Graverobber" })
  a:fire("PLAYER_DEAD")
  local e = list(a)[1]
  check("a member's death is recorded locally", #list(a) == 1 and e.who == "Classic Beta PvP-Stromham"
    and e.lvl == 23 and e.zone == "Stranglethorn Vale" and e.hc == false and e.mine == true
    and e.at == "2026-11-04 23:00:00")
  check("a normal death is not sent by default", deathsSent(a) == 0)
  w:advance(0)
  check("so the guildie hears nothing and records nothing", #list(b) == 0 and #b.printed == 0)
  w:advance(59.9); a:fire("PLAYER_DEAD")
  check("a second death inside 60 s is ignored entirely", #list(a) == 1)
  w:advance(1.2); a:fire("PLAYER_DEAD")
  check("one 61 s later is handled", #list(a) == 2)
  a:db().crypt.share = true
  w:advance(61); a:fire("PLAYER_DEAD")
  check("share on: a normal death is sent", deathsSent(a) == 1 and lastSent(a) == "1^DEATH^hc~0^lvl~23^zone~Stranglethorn Vale")
  a.hc = true
  w:advance(61); a:fire("PLAYER_DEAD")
  check("share on: a hardcore death is sent", deathsSent(a) == 2 and lastSent(a):find("hc~1", 1, true))
  a:db().crypt.share = false
  w:advance(61); a:fire("PLAYER_DEAD")
  check("share off: a hardcore death is recorded but not sent", deathsSent(a) == 2 and list(a)[#list(a)].hc == true)
  a:db().crypt.share = nil
  w:advance(61); a:fire("PLAYER_DEAD")
  check("A2: share unset, a hardcore death is recorded but not sent", deathsSent(a) == 2
    and list(a)[#list(a)].hc == true)
  a:db().crypt.share = true
  a.itype = "pvp"
  w:advance(61); a:fire("PLAYER_DEAD")
  check("a battleground on a hardcore character counts as normal: sent as hc 0, not HC", deathsSent(a) == 3
    and lastSent(a):find("hc~0", 1, true) and list(a)[#list(a)].hc == false)
  a.itype = "arena"
  w:advance(61); a:fire("PLAYER_DEAD")
  check("an arena likewise", deathsSent(a) == 4 and lastSent(a):find("hc~0", 1, true) and list(a)[#list(a)].hc == false)
  a.itype = "party"
  w:advance(61); a:fire("PLAYER_DEAD")
  check("a dungeon on a hardcore character still counts", deathsSent(a) == 5 and lastSent(a):find("hc~1", 1, true))
  a.hc, a.itype = false, "none"
  a:db().crypt.share = true
  a.noLevel, a.noZone = true, true
  w:advance(61); a:fire("PLAYER_DEAD")
  check("no level and no zone: 0 and \"somewhere\"", lastSent(a) == "1^DEATH^hc~0^lvl~0^zone~somewhere"
    and list(a)[#list(a)].lvl == 0)
  a.noLevel, a.noZone = false, false
  a.lvl = "secretish"
  w:advance(61); a:fire("PLAYER_DEAD")
  check("a non-number level is 0", list(a)[#list(a)].lvl == 0)
  a.lvl = 23
  a.hc = true
  a.env.C_GameRules = nil
  a:db().crypt.share = nil
  local sent0 = deathsSent(a)
  w:advance(61); a:fire("PLAYER_DEAD")
  check("C_GameRules absent: not hardcore, not sent by default", deathsSent(a) == sent0 and list(a)[#list(a)].hc == false)
  a.env.C_GameRules = { IsHardcoreActive = function() error("nope") end }
  w:advance(61); a:fire("PLAYER_DEAD")
  check("IsHardcoreActive erroring: not hardcore", deathsSent(a) == sent0 and list(a)[#list(a)].hc == false)
  a.hc = false
  a.zone = string.rep("z", 60)
  a:db().crypt.share = true
  a.env.C_GameRules = { IsHardcoreActive = function() return false end }
  w:advance(61); a:fire("PLAYER_DEAD")
  check("a long zone is cut to 48 bytes", #list(a)[#list(a)].zone == 48)

  local x = client(w, { name = "Spy", guild = "Alliance Spies" })
  x.hc = true
  x:fire("PLAYER_DEAD")
  check("a non-member records nothing and sends nothing", #list(x) == 0 and #x.sent == 0)
end

-- ---------------------------------------------------------------- received deaths
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local b = client(w, { name = "Graverobber" })
  a.hc = true
  a:db().crypt.share = true
  a:fire("PLAYER_DEAD"); w:advance(0)
  check("hardcore notice, exactly", #b.printed == 1
    and b.printed[1] == "|cff7fa650Dead Tired|r Rest in Pieces: Stromham, level 23, Stranglethorn Vale. Hardcore. Gone for good.")
  local e = list(b)[1]
  check("the receiver records it, not as its own", #list(b) == 1 and e.who == "Classic Beta PvP-Stromham"
    and e.mine == false and e.hc == true and e.lvl == 23)
  check("nothing replies to a DEATH", deathsSent(b) == 0 and #b.sent == 0)
  w:advance(30)
  check("nothing is re-sent", deathsSent(a) == 1)
  b.printed = {}
  local function inject(text, from)
    b:fire("CHAT_MSG_ADDON", "DEADTIRED", text, "GUILD", (from or "Ghoul") .. "-ClassicBetaPvP")
  end
  inject("1^DEATH^hc~0^lvl~7^zone~Durotar")
  check("normal notice, exactly", b.printed[1] == "|cff7fa650Dead Tired|r Ghoul died at level 7 in Durotar. Again.")
  inject("1^DEATH^hc~0^lvl~0^zone~somewhere")
  check("level 0 (unknown at the sender) prints as ??", b.printed[2] == "|cff7fa650Dead Tired|r Ghoul died at level ?? in somewhere. Again.")
  inject("1^DEATH^hc~0^lvl~9^zone~The %7CTInterface%7Ct Crypt")
  check("a bar in a zone is printed safely", b.printed[3]:find("The ||TInterface||t Crypt", 1, true) ~= nil)
  local n = #list(b)
  local bad = { "1^DEATH^hc~0^lvl~101^zone~Z", "1^DEATH^hc~0^lvl~-1^zone~Z", "1^DEATH^hc~0^lvl~ab^zone~Z",
    "1^DEATH^hc~0^zone~Z", "1^DEATH^hc~0^lvl~5^zone~", "1^DEATH^hc~0^lvl~5", "1^DEATH^hc~0^lvl~5^zone~" .. string.rep("z", 49),
    "1^DEATH^hc~2^lvl~5^zone~Z", "1^DEATH^lvl~5^zone~Z", "1^DEATH^hc~0^lvl~1000^zone~Z", "1^DEATH^hc~0^lvl~5.5^zone~Z" }
  b.printed = {}
  for _, t in ipairs(bad) do inject(t) end
  check("each invalid DEATH is counted in badDeath, not recorded, not printed", b:db().crypt.badDeath == #bad
    and #list(b) == n and #b.printed == 0)
  b:slash("rip off"); b.printed = {}
  inject("1^DEATH^hc~1^lvl~60^zone~Naxxramas")
  check("rip off: recorded, nothing printed", #b.printed == 0 and #list(b) == n + 1 and list(b)[n + 1].zone == "Naxxramas")
end

-- ---------------------------------------------------------------- the graveyard
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  a:slash("graveyard")
  check("empty graveyard text, then the closing line", a.printed[1]:find("The graveyard's empty. Give it time.", 1, true)
    and a.printed[2]:find(CLOSING, 1, true) and #a.printed == 2)
  local function inject(name, lvl, z, hc, day)
    a.stampStr = day .. " 01:00:00"
    a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^DEATH^hc~" .. hc .. "^lvl~" .. lvl .. "^zone~" .. z, "GUILD", name .. "-ClassicBetaPvP")
  end
  inject("Ghoul", 7, "Durotar", 0, "2026-11-01")
  inject("Wight", 60, "Naxxramas", 1, "2026-11-02")
  a:slash("graveyard")
  check("newest first, date, name, level, zone, (HC) on hardcore", a.printed[1] == "|cff7fa650Dead Tired|r 2026-11-02 Wight 60 Naxxramas (HC)"
    and a.printed[2] == "|cff7fa650Dead Tired|r 2026-11-01 Ghoul 7 Durotar" and a.printed[3]:find(CLOSING, 1, true))
  for i = 1, 20 do inject("Zombie" .. string.char(64 + i), i, "Zone" .. i, 0, "2026-11-03") end
  a:slash("graveyard")
  check("at most 10 lines, then the closing line", #a.printed == 11 and a.printed[1]:find("ZombieT 20 Zone20", 1, true)
    and a.printed[10]:find("ZombieK 11 Zone11", 1, true) and a.printed[11]:find(CLOSING, 1, true))
  for i = 1, 100 do inject("Lich", 5, "Cap" .. i, 0, "2026-11-04") end
  check("the memorial is capped at 100, oldest dropped first", #list(a) == 100 and list(a)[1].zone == "Cap1"
    and list(a)[100].zone == "Cap100")
  -- the account's own deaths show too
  local w2 = H.world()
  local me = client(w2, { name = "Stromham" })
  me:fire("PLAYER_DEAD")
  me:slash("graveyard")
  check("the player's own deaths are in their graveyard", me.printed[1]:find("2026-11-04 Stromham 23 Stranglethorn Vale", 1, true) ~= nil)
end

-- ---------------------------------------------------------------- bedtime
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local function nags()
    local n = 0
    for _, m in ipairs(a.printed) do
      if m:find("Even the dead sleep", 1, true) or m:find("Still here. The crypt", 1, true)
        or m:find("Last call.", 1, true) then n = n + 1 end
    end
    return n
  end
  setClock(w, a, "00:50")
  a:login()
  w:advance(3600 * 7)
  check("off by default: no nag, ever", nags() == 0)
  a:slash("bedtime 01:00"); a.printed = {}
  setClock(w, a, "00:57")
  w:advance(60 * 2.5)
  check("not before bedtime", nags() == 0)
  w:advance(60)
  check("fires at the time, exactly as written", nags() == 1 and a:said("It's 01:00. Even the dead sleep.") ~= nil)
  w:advance(60 * 28)
  check("nothing more inside 30 minutes", nags() == 1)
  w:advance(60 * 2)
  check("the second at +30", nags() == 2 and a:said("Still here. The crypt has a bed with your name on it.") ~= nil)
  w:advance(60 * 30)
  check("the third at +60", nags() == 3 and a:said("Last call. Log off before the sun gets you.") ~= nil)
  w:advance(60 * 120)
  check("never a fourth, and not by erroring", nags() == 3 and (a:db().errors.crypt or 0) == 0)
  w:advance(3600 * 24)
  check("the next night starts again: 3 more, no more, no errors", nags() == 6 and (a:db().errors.crypt or 0) == 0)

  -- Across midnight.
  local w2 = H.world()
  local b = client(w2, { name = "Graverobber" })
  b:db().crypt.bedtime = "23:45"
  setClock(w2, b, "23:40")
  b:login(); b.printed = {}   -- drop card 1's welcome line
  w2:advance(60 * 6)
  local first = #b.printed
  w2:advance(60 * 30)
  check("bedtime 23:45 nags at 23:45, then at 00:15 across midnight", first == 1 and #b.printed == 2
    and b.printed[2]:find("Still here", 1, true))

  -- A login 2 h after bedtime: at once, then 30 minutes later, not on consecutive ticks.
  local w3 = H.world()
  local c = client(w3, { name = "Ghoul" })
  c:db().crypt.bedtime = "01:00"
  setClock(w3, c, "03:00")
  c:login(); c.printed = {}   -- drop card 1's welcome line
  w3:advance(61)
  check("a login at bedtime +2 h nags at once", #c.printed == 1 and c:said("It's 03:01.") ~= nil)
  w3:advance(60 * 5)
  check("not again on the next ticks", #c.printed == 1)
  w3:advance(60 * 25)
  check("then 30 minutes later", #c.printed == 2)

  -- Outside the 6-hour window: nothing.
  local w4 = H.world()
  local d = client(w4, { name = "Wight" })
  d:db().crypt.bedtime = "01:00"
  setClock(w4, d, "07:30")
  d:login(); d.printed = {}; w4:advance(60 * 60)
  check("more than 6 hours after bedtime: nothing", #d.printed == 0)

  -- A non-member, and no clock.
  local w5 = H.world()
  local x = client(w5, { name = "Spy", guild = "Alliance Spies" })
  x:db().crypt.bedtime = "01:00"
  setClock(w5, x, "01:00")
  x:login(); w5:advance(3600)
  check("nothing for a non-member", #x.printed == 0)
  local y = client(w5, { name = "Ghoul" })
  y:db().crypt.bedtime = "01:00"
  y.noClock = true
  setClock(w5, y, "01:00")
  y:login(); y.printed = {}; w5:advance(3600)
  check("no clock: the nag never fires, never errors", #y.printed == 0 and (y:db().errors.crypt or 0) == 0)
end

-- ---------------------------------------------------------------- A2: hardcore death opt-in, told once
do
  local HC = "|cff7fa650Dead Tired|r This one's hardcore. If it falls, the guild won't hear unless you /dt rip share on."
  local function told(c) local n = 0 for _, m in ipairs(c.printed) do if m == HC then n = n + 1 end end return n end

  -- A hardcore death with share unset sends nothing; the guildie hears nothing.
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local b = client(w, { name = "Graverobber" })
  a.hc = true
  a:fire("PLAYER_DEAD"); w:advance(1)
  check("A2: hardcore, share unset: nothing sent, the guildie hears and records nothing",
    deathsSent(a) == 0 and #b.printed == 0 and #list(b) == 0)
  a:slash("rip share on")
  w:advance(61); a:fire("PLAYER_DEAD"); w:advance(1)
  check("A2: hardcore, share on: sent, the guildie gets the Rest in Pieces line",
    deathsSent(a) == 1 and b:said("Rest in Pieces: Stromham, level 23") ~= nil)

  -- The line: a hardcore member's first login, once.
  local w2 = H.world()
  local db = {}
  local h = client(w2, { name = "Mortis", db = db })
  h.hc = true
  h:login()
  check("A2: first login of a hardcore member prints the line, once", told(h) == 1
    and db.crypt.hcTold["Classic Beta PvP-Mortis"] == true)
  check("A2: after card 1's welcome, and nothing else", #h.printed == 2 and h.printed[1]:find("Rest in Pieces, Mortis", 1, true))
  h:fire("PLAYER_ENTERING_WORLD", false, false)          -- a zone change in the same session
  h.DT.recheckGuild()
  check("A2: not again in the same session", told(h) == 1)
  h:logout()
  local h2 = client(w2, { name = "Mortis", db = db }); h2.hc = true
  h2:fire("PLAYER_ENTERING_WORLD", false, true)          -- /reload
  check("A2: not after a /reload", told(h2) == 0)
  h2:logout()
  local h3 = client(w2, { name = "Mortis", db = db }); h3.hc = true
  h3:login()
  check("A2: not on the second login", told(h3) == 0 and #h3.printed == 1)
  h3:logout()
  local h4 = client(w2, { name = "Vesper", db = db }); h4.hc = true
  h4:login()
  check("A2: another hardcore character on the account gets its own line", told(h4) == 1
    and db.crypt.hcTold["Classic Beta PvP-Vesper"] == true)

  -- Not on a normal character, not for a non-member, not once share is set.
  local w3 = H.world()
  local n = client(w3, { name = "Ghoul" })
  n:login()
  check("A2: not on a normal character", told(n) == 0 and next(n:db().crypt.hcTold) == nil)
  local x = client(w3, { name = "Spy", guild = "Alliance Spies" }); x.hc = true
  x:login(); w3:advance(1)
  check("A2: not for a non-member", told(x) == 0 and #x.printed == 0)
  for _, v in ipairs({ true, false }) do
    local s = client(w3, { name = "Lich" .. tostring(v), db = { crypt = { share = v } } }); s.hc = true
    s:login()
    check("A2: not once share has been set " .. (v and "on" or "off"), told(s) == 0)
  end
  local hcGone = client(w3, { name = "Wraith" })
  hcGone.hc = true; hcGone.env.C_GameRules = nil
  hcGone:login()
  check("A2: C_GameRules absent: no line", told(hcGone) == 0)

  -- Guild info late at login: the line comes when membership is known, still once.
  local w4 = H.world()
  local l = client(w4, { name = "Banshee" }); l.hc = true
  l.guildError = true
  l:login()
  check("A2: guild info not there yet: no line", told(l) == 0)
  l.guildError = false
  l:fire("PLAYER_GUILD_UPDATE", "player")
  check("A2: when membership arrives, the line, once", told(l) == 1)
  l:fire("PLAYER_GUILD_UPDATE", "player")
  check("A2: and not twice", told(l) == 1)
end

-- ---------------------------------------------------------------- byte budget
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local m = a.DT._comms.encode("DEATH", { lvl = "100", zone = string.rep("^", 48), hc = "1" })
  print("crypt: longest DEATH is " .. #m .. " bytes")
  check("the longest DEATH is at most 250 bytes (" .. #m .. ")", #m <= 250)
end

-- ---------------------------------------------------------------- the whole addon
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local b = client(w, { name = "Graverobber" })
  local x = client(w, { name = "Spy", guild = "Alliance Spies" })
  a:login(); b:login(); x:login()
  w:advance(60)
  check("a login prints nothing from Crypt: each member has only the welcome", #a.printed == 1 and #b.printed == 1
    and a:said("Rest in Pieces, Stromham.") and #x.printed == 0)
  a.printed, b.printed = {}, {}
  a:db().crypt.share = true
  a:fire("PLAYER_DEAD"); w:advance(1)
  check("a death on one prints exactly one line on the other", #b.printed == 1 and b:said("Stromham died at level 23") ~= nil)
  check("and nothing on the sender or the non-member", #a.printed == 0 and #x.printed == 0 and #list(x) == 0)
end

H.finish("crypt")
