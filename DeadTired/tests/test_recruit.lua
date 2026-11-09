-- Offline checks for RecruitLines.lua and Recruit.lua (card 5: the recruitment rotator).
--   lua5.1 DeadTired/tests/test_recruit.lua  (from the repo root)
-- Stubs added here, per client, on client.env (card 1's harness is not changed): time,
-- GetChannelList / GetChannelName (over c.chans, the joined channels), C_GuildInfo.IsGuildOfficer
-- (c.officer), and C_ChatInfo's InChatMessagingLockdown and chat send (recorded in c.posts).
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local ALL = {}
for _, f in ipairs(H.FILES) do ALL[#ALL + 1] = f end
for _, f in ipairs({ "PrepList.lua", "Prep.lua", "RecruitLines.lua", "Recruit.lua" }) do ALL[#ALL + 1] = f end
local P = "|cff7fa650Dead Tired|r "
local SEND = "Send" .. "ChatMessage"   -- spelt so that G3's count of the real call site stays one

local function client(w, opts)
  opts.files = opts.files or ALL
  if opts.guild == nil and not opts.outside then opts.guild = G end
  local c = w:client(opts)
  c.now, c.posts, c.lockdown, c.officer = 1793833200, {}, false, true
  -- The joined channels, in order: { id, name }. General carries the zone, as on the live client.
  c.chans = { { 1, "General - Orgrimmar" }, { 2, "Trade - City" }, { 4, "LookingForGroup" } }
  c.env.time = function() if c.noClock then error("no clock") end return c.now end
  c.env.GetChannelList = function()
    if c.listError then error("no list") end
    local out = {}
    for _, ch in ipairs(c.chans) do out[#out + 1] = ch[1]; out[#out + 1] = ch[2]; out[#out + 1] = false end
    return unpack(out)
  end
  c.env.GetChannelName = function(x)
    if c.nameError then error("no name") end
    for _, ch in ipairs(c.chans) do
      if ch[1] == x or ch[2] == x then return ch[1], ch[2], 0 end
    end
    return 0, nil, 0
  end
  c.env.C_GuildInfo = { IsGuildOfficer = function()
    if c.officer == "error" then error("not yet") end
    return c.officer
  end }
  c.env.C_ChatInfo.InChatMessagingLockdown = function() return c.lockdown end
  c.env.C_ChatInfo[SEND] = function(...)
    if c.postFail then error("rejected") end
    c.posts[#c.posts + 1] = { ... }
  end
  return c
end

-- ---------------------------------------------------------------- the lines
do
  local f = assert(io.open(H.addonDir .. "/../docs/RECRUIT_lines.md", "rb"))
  local doc = {}
  for line in f:read("*a"):gmatch("[^\n]+") do
    local n, text = line:match("^(%d)%. (.+)$")
    if n then doc[tonumber(n)] = text end
  end
  f:close()
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local L = a.ns.Recruit.LINES
  local same = #L == 5
  for i = 1, 5 do same = same and L[i] == doc[i] end
  check("RecruitLines.lua holds docs/RECRUIT_lines.md's five lines, byte-identical", same and doc[5] ~= nil)
  for i = 1, 5 do print(string.format("recruit: line %d is %d bytes", i, #L[i])) end
  check("the lines pass the lines check", a.DT._recruit.valid() == true)
  check("channel and cooldown as ratified (A1: General)", a.ns.Recruit.RECRUIT_CHANNEL == "General" and a.ns.Recruit.COOLDOWN == 900)
  local V = a.DT._recruit.linesValid
  local five = { "a", "b", "c", "d", "e" }
  check("lines check: five plain lines pass", V(five))
  check("lines check: four lines fail", not V({ "a", "b", "c", "d" }))
  check("lines check: six lines fail", not V({ "a", "b", "c", "d", "e", "f" }))
  check("lines check: an empty line fails", not V({ "a", "", "c", "d", "e" }))
  check("lines check: a bar fails", not V({ "a", "b", "|cffff0000c", "d", "e" }))
  check("lines check: a control byte fails", not V({ "a", "b", "c\n", "d", "e" }))
  check("lines check: 255 bytes pass, 256 fail", V({ string.rep("x", 255), "b", "c", "d", "e" })
    and not V({ string.rep("x", 256), "b", "c", "d", "e" }))
  -- A build with no lines file loaded refuses to post.
  local files = {}
  for _, f in ipairs(ALL) do if f ~= "RecruitLines.lua" then files[#files + 1] = f end end
  local n = client(w, { name = "Nolines", files = files })
  n:slash("recruit")
  check("no lines: refused, nothing posted", n.printed[1] == P .. "No recruitment lines loaded. Tell an officer." and #n.posts == 0)
end

-- ---------------------------------------------------------------- posting
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local L = a.ns.Recruit.LINES
  a:slash("")
  check("the help lists recruit [next]", a:said("recruit [next]") ~= nil)
  a:slash("recruit next")
  check("/dt recruit next before any post", a.printed[1] == P .. "Next up: line 1 of 5. Cooldown: ready." and #a.posts == 0)
  a:slash("recruit")
  check("a post: line 1, to CHANNEL, General - Orgrimmar's number", #a.posts == 1 and a.posts[1][1] == L[1]
    and a.posts[1][2] == "CHANNEL" and a.posts[1][3] == nil and a.posts[1][4] == 1)
  check("and says so", a.printed[1] == P .. "Posted line 1 of 5 to General.")
  check("the cooldown and rotation are stored", a:db().prep.recruitAt == a.now and a:db().prep.recruitNext == 2)
  check("no addon message is sent for a post", #a.sent == 0)
  a.now = a.now + 60
  a:slash("recruit")
  check("inside the cooldown: refused, minutes rounded up", #a.posts == 1
    and a.printed[1] == P .. "Too soon. Next post in 14 min. Even necromancers pace themselves.")
  a.now = a.now + 61
  a:slash("recruit")
  check("rounded up: 779 s left is 13 min", a.printed[1] == P .. "Too soon. Next post in 13 min. Even necromancers pace themselves.")
  a:slash("recruit next")
  check("/dt recruit next shows the line and the wait", a.printed[1] == P .. "Next up: line 2 of 5. Cooldown: 13 min left.")
  a.now = a:db().prep.recruitAt + 900
  a:slash("recruit")
  check("at 15 minutes: line 2", #a.posts == 2 and a.posts[2][1] == L[2])
  for i = 3, 6 do a.now = a.now + 900; a:slash("recruit") end
  check("the rotation runs 1 to 5 and back to 1", #a.posts == 6 and a.posts[5][1] == L[5] and a.posts[6][1] == L[1]
    and a:db().prep.recruitNext == 2)

  -- the refusals, in order
  a.now = a.now + 900
  a.noClock = true
  a:slash("recruit")
  check("clock unreadable: refused", a.printed[1] == P .. "Can't read the clock. Not posting." and #a.posts == 6)
  a.noClock = false
  a.lockdown = true
  a:slash("recruit")
  check("chat lockdown: refused", a.printed[1] == P .. "Chat's locked right now (an encounter?). Try after." and #a.posts == 6)
  a.lockdown = false
  local joined = a.chans
  a.chans = { { 2, "Trade - City" }, { 4, "LookingForGroup" } }
  a:slash("recruit")
  check("not in General: refused", a.printed[1] == P .. "You're not in General. /join General first."
    and #a.posts == 6)
  a.chans = joined
  local at, nxt = a:db().prep.recruitAt, a:db().prep.recruitNext
  a.postFail = true
  a:slash("recruit")
  check("a failed post: refused, cooldown and rotation unmoved", a.printed[1] == P .. "The channel didn't take it. Nothing posted."
    and a:db().prep.recruitAt == at and a:db().prep.recruitNext == nxt)
  a.postFail = false
  a.env.C_ChatInfo[SEND] = nil
  a:slash("recruit")
  check("the chat function absent: nothing posted, nothing moved", a.printed[1] == P .. "The channel didn't take it. Nothing posted."
    and a:db().prep.recruitNext == nxt)
  a:slash("recruit please")
  check("/dt recruit <other> explains itself, posts nothing", a:said("/dt recruit next shows which.") ~= nil)

  local x = client(w, { name = "Spy", guild = "Alliance Spies" })
  x:slash("recruit")
  check("a non-member: the router's line, nothing posted", x:said("only stirs inside") ~= nil and #x.posts == 0)
end

-- ---------------------------------------------------------------- A1: officers only
do
  local w = H.world()
  local function refused(c) return c.printed[1] == P .. "Officers only. The rest of us just haunt the place." and #c.posts == 0
    and c:db().prep.recruitAt == nil end
  local cases = {
    { "false", function(c) c.officer = false end },
    { "nil", function(c) c.officer = nil end },
    { "a string, not true", function(c) c.officer = "yes" end },
    { "erroring", function(c) c.officer = "error" end },
    { "C_GuildInfo absent", function(c) c.env.C_GuildInfo = nil end },
    { "IsGuildOfficer absent", function(c) c.env.C_GuildInfo = {} end },
    { "secret", function(c) local t = {}; c.secrets[t] = true; c.officer = t end },
  }
  for i, case in ipairs(cases) do
    local c = client(w, { name = "Grunt" .. string.char(64 + i) })
    case[2](c)
    c:slash("recruit")
    check("A1: IsGuildOfficer " .. case[1] .. ": refused, nothing posted, cooldown unmoved", refused(c))
  end
  local o = client(w, { name = "Stromham" })
  o:slash("recruit")
  check("A1: an officer posts", #o.posts == 1)
  local n = client(w, { name = "Peon" }); n.officer = false
  n.now = o.now + 3600
  n:slash("recruit next")
  check("A1: /dt recruit next still answers a non-officer, posts nothing", n.printed[1]:find("Next up: line", 1, true) ~= nil
    and #n.posts == 0)
end

-- ---------------------------------------------------------------- A1: finding General
do
  local w = H.world()
  local function try(chans, setup)
    local c = client(w, { name = "Stromham" })
    c.chans = chans
    if setup then setup(c) end
    c:slash("recruit")
    return c
  end
  local c = try({ { 3, "Generalists" }, { 5, "General - Durotar" } })
  check("A1: General - <zone> is matched, by its own number", #c.posts == 1 and c.posts[1][4] == 5)
  c = try({ { 3, "Generalists" } })
  check("A1: Generalists is not General: refused, nothing posted", #c.posts == 0
    and c.printed[1] == P .. "You're not in General. /join General first.")
  c = try({ { 3, "General-Orgrimmar" }, { 6, "general - orgrimmar" }, { 7, "GeneralChat" } })
  check("A1: no near misses (no space, lower case, longer name)", #c.posts == 0)
  c = try({ { 7, "General" } })
  check("A1: a bare General is matched", #c.posts == 1 and c.posts[1][4] == 7)
  c = try({})
  check("A1: no channels joined: refused", #c.posts == 0 and c:said("/join General first") ~= nil)
  c = try({ { 0, "General - Orgrimmar" } })
  check("A1: a channel number of 0 is not joined", #c.posts == 0)
  c = try({ { 2, "General - Orgrimmar" } }, function(x) x.env.GetChannelList = nil end)
  check("A1: GetChannelList absent: GetChannelName by number finds it", #c.posts == 1 and c.posts[1][4] == 2)
  c = try({ { 2, "General - Orgrimmar" } }, function(x) x.listError = true end)
  check("A1: GetChannelList erroring: GetChannelName finds it", #c.posts == 1 and c.posts[1][4] == 2)
  c = try({ { 2, "General - Orgrimmar" } }, function(x) x.env.GetChannelName = nil end)
  check("A1: GetChannelName absent: GetChannelList finds it", #c.posts == 1 and c.posts[1][4] == 2)
  c = try({ { 2, "General - Orgrimmar" } }, function(x) x.env.GetChannelList = nil; x.env.GetChannelName = nil end)
  check("A1: both absent: refused, nothing posted", #c.posts == 0 and c:said("/join General first") ~= nil)
  c = try({ { 2, "General - Orgrimmar" } }, function(x) x.listError = true; x.nameError = true end)
  check("A1: both erroring: refused, nothing posted", #c.posts == 0 and c:said("/join General first") ~= nil)
  c = try({ { 2, "General - Orgrimmar" } }, function(x)
    local list = x.env.GetChannelList
    x.env.GetChannelList = function() local id, name = list(); x.secrets[name] = true; return id, name, false end
    x.env.GetChannelName = nil
    x.secrets["General - Orgrimmar"] = true
  end)
  check("A1: a secret channel name is not matched", #c.posts == 0)
  local M = c.DT._recruit.matches
  check("A1: the match rule", M("General") and M("General - Orgrimmar") and not M("Generalists")
    and not M("General -") and not M("Trade - City") and not M(nil) and not M(4))
end

-- ---------------------------------------------------------------- one account, two characters
do
  local w = H.world()
  local db = {}
  local a = client(w, { name = "Stromham", db = db })
  a:slash("recruit")
  a:logout()
  local alt = client(w, { name = "Bonechill", db = db })
  alt.now = a.now + 300
  alt:slash("recruit")
  check("an alt on the same account shares the cooldown", #alt.posts == 0 and alt:said("Next post in 10 min") ~= nil)
  alt.now = a.now + 900
  alt:slash("recruit")
  check("and the rotation: the alt posts line 2", #alt.posts == 1 and alt.posts[1][1] == alt.ns.Recruit.LINES[2])
end

-- ---------------------------------------------------------------- no post without a command
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local b = client(w, { name = "Graverobber" })
  a:db().prep.share = true
  a:login(); b:login()
  for hour = 1, 24 do
    a.now = a.now + 3600
    a:fire("PLAYER_ENTERING_WORLD", false, false)
    a:fire("PLAYER_GUILD_UPDATE", "player")
    b:slash("prep check")
    a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^RECRUIT^go~1", "GUILD", "Lich-ClassicBetaPvP")
    a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^HELLO^main~^v~0.1.0", "GUILD", "Wight" .. hour .. "-ClassicBetaPvP")
    w:advance(3600)
    if hour == 12 then a:slash("prep"); a:slash("recruit next"); a:slash("who") end
  end
  check("24 hours of logins, zoning, guild updates, roll calls and messages: no post, ever", #a.posts == 0 and #b.posts == 0)
  a:slash("recruit")
  check("and the next press still posts line 1", #a.posts == 1 and a.posts[1][1] == a.ns.Recruit.LINES[1])
end

-- ---------------------------------------------------------------- fix round 3: the nudge
do
  local NUDGE = P .. "The crypt door creaks open: you can recruit again (/dt recruit)."
  local function nudges(c) local n = 0 for _, m in ipairs(c.printed) do if m == NUDGE then n = n + 1 end end return n end
  local function sends(c) local n = 0 for _, p in ipairs(c.posts) do n = n + 1 end return n end
  local function fresh(w, opts) local c = client(w, opts or { name = "Stromham" }); c:login(); return c end

  local w = H.world()
  local a = fresh(w)
  check("nudge: the brief's wording", a.DT._recruit.NUDGE == "The crypt door creaks open: you can recruit again (/dt recruit).")
  a:slash("recruit")
  check("nudge: the post goes", #a.posts == 1)
  a.printed = {}
  w:advance(899)
  a.now = a.now + 899
  check("nudge: nothing before the cooldown ends", nudges(a) == 0)
  w:advance(1)
  a.now = a.now + 1
  check("nudge: after 900 s, exactly one line", nudges(a) == 1 and #a.printed == 1)
  w:advance(3600)
  check("nudge: once only", nudges(a) == 1)
  check("nudge: it never posts anything", sends(a) == 1)

  -- A second post: the first post's nudge is cancelled, the second's comes 900 s after it.
  local w2 = H.world()
  local b = fresh(w2)
  b:slash("recruit")
  w2:advance(600); b.now = b.now + 900   -- (an alt's clock moved on; the cooldown has ended)
  b:slash("recruit")
  check("nudge: the second post goes", #b.posts == 2)
  b.printed = {}
  w2:advance(300)
  check("nudge: no line for the first post when a second came since", nudges(b) == 0)
  w2:advance(599)
  check("nudge: ...not yet for the second", nudges(b) == 0)
  w2:advance(1)
  check("nudge: the second post's own nudge 900 s after it", nudges(b) == 1)

  -- Not an officer any more when it falls due; or out of the guild.
  local w3 = H.world()
  local c = fresh(w3)
  c:slash("recruit")
  c.officer = false
  c.printed = {}
  w3:advance(900)
  check("nudge: no line if not an officer at the time", nudges(c) == 0)
  local d = fresh(w3, { name = "Bonechill" })
  d:slash("recruit")
  d.guild = nil
  d.printed = {}
  w3:advance(900)
  check("nudge: no line if out of the guild at the time", nudges(d) == 0)

  -- Switched off (saved, account-wide), then on.
  local w4 = H.world()
  local db = {}
  local e = fresh(w4, { name = "Stromham", db = db })
  e:slash("recruit nudge off")
  check("nudge off: saved account-wide, nothing printed", db.prep.recruitNudge == false and #e.printed == 0)
  e:slash("recruit")
  e.printed = {}
  w4:advance(900)
  check("nudge off: no line", nudges(e) == 0)
  e:logout()
  local e2 = fresh(w4, { name = "Bonechill", db = db })
  e2.now = e2.now + 1000
  e2:slash("recruit")
  e2.printed = {}
  w4:advance(900)
  check("nudge off: still off on another character after a login", nudges(e2) == 0 and #e2.posts == 1)
  e2:slash("recruit nudge on")
  check("nudge on: saved", db.prep.recruitNudge == true)
  e2.now = e2.now + 1000
  e2:slash("recruit")
  e2.printed = {}
  w4:advance(900)
  check("nudge on: the line is back", nudges(e2) == 1)
  e2:logout()

  -- No post this session: nothing at login, even with the cooldown still running from the last.
  local f = fresh(w4, { name = "Stromham", db = db })
  f.printed = {}
  w4:advance(3600)
  check("nudge: no line at login without a post this session", nudges(f) == 0 and #f.printed == 0)
  -- A refused post (not an officer) schedules nothing.
  f.officer = false
  f.now = f.now + 1000
  f:slash("recruit")
  f.officer = true
  f.printed = {}
  w4:advance(900)
  check("nudge: a refused post schedules nothing", nudges(f) == 0 and #f.posts == 0)
end

H.finish("recruit")
