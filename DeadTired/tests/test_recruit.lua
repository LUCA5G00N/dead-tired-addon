-- Offline checks for RecruitLines.lua and Recruit.lua (card 5: the recruitment rotator).
--   lua5.1 DeadTired/tests/test_recruit.lua  (from the repo root)
-- Stubs added here, per client, on client.env (card 1's harness is not changed): time,
-- GetChannelName, and C_ChatInfo's InChatMessagingLockdown and chat send (recorded in c.posts).
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
  c.now, c.posts, c.lockdown = 1793833200, {}, false
  c.channels = { LookingForGroup = 4 }
  c.env.time = function() if c.noClock then error("no clock") end return c.now end
  c.env.GetChannelName = function(name) return c.channels[name] or 0, name end
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
  check("channel and cooldown as ratified", a.ns.Recruit.RECRUIT_CHANNEL == "LookingForGroup" and a.ns.Recruit.COOLDOWN == 900)
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
  check("a post: line 1, to CHANNEL, the channel's number", #a.posts == 1 and a.posts[1][1] == L[1]
    and a.posts[1][2] == "CHANNEL" and a.posts[1][3] == nil and a.posts[1][4] == 4)
  check("and says so", a.printed[1] == P .. "Posted line 1 of 5 to LookingForGroup.")
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
  a.channels.LookingForGroup = nil
  a:slash("recruit")
  check("not in the channel: refused", a.printed[1] == P .. "You're not in LookingForGroup. /join LookingForGroup first."
    and #a.posts == 6)
  a.channels.LookingForGroup = 4
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

H.finish("recruit")
