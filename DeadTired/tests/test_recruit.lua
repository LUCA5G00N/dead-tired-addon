-- Offline checks for Recruit.lua (card 5's rotator, ported from rc3 in Port 1): rc3's checks, the
-- Recruit button on the bar (R-P1), the nudge replies (R-P2), the click-only post.
--   lua5.1 DeadTired/tests/test_recruit.lua
-- Stubs per client (c.env): time (c.now; c.noClock), GetChannelList / GetChannelName (over c.chans),
-- C_GuildInfo.IsGuildOfficer (c.officer), C_ChatInfo's lockdown and chat send (recorded in c.posts).
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local SEND = "Send" .. "ChatMessage"

local function stub(c)
  c.now, c.posts, c.officer = 1793833200, {}, true
  c.chans = { { 1, "General - Orgrimmar" }, { 2, "Trade - City" }, { 4, "LookingForGroup" } }
  local env = c.env
  rawset(env, "time", function() if c.noClock then error("no clock") end return c.now end)
  rawset(env, "GetChannelList", function()
    if c.listError then error("no list") end
    if c.noList then return end
    local out = {}
    for _, ch in ipairs(c.chans) do out[#out + 1] = ch[1]; out[#out + 1] = ch[2]; out[#out + 1] = false end
    return unpack(out)
  end)
  rawset(env, "GetChannelName", function(x)
    if c.nameError then error("no name") end
    for _, ch in ipairs(c.chans) do if ch[1] == x then return ch[1], ch[2], 0 end end
    return 0, nil, 0
  end)
  rawset(env, "C_GuildInfo", { IsGuildOfficer = function()
    if c.officer == "error" then error("not yet") end
    return c.officer
  end })
  env.C_ChatInfo[SEND] = function(...)
    if c.postFail then error("rejected") end
    c.posts[#c.posts + 1] = { ... }
  end
end

local function mk(w, o)
  if o.guild == nil then o.guild = G end
  local setup = o.setup
  o.setup = function(c) stub(c); if setup then setup(c) end end
  o.full = o.full or (o.name .. " Hamson")
  o.random = function() return 0.5 end
  return w:client(o)
end

-- ---------------------------------------------------------------- the lines
do
  local w = H.world()
  local a = mk(w, { name = "Stromham" })
  check("the lines pass the lines check", a.DT._recruit.valid() == true)
  check("channel and cooldown as ratified (A1: General)", a.ns.Recruit.RECRUIT_CHANNEL == "General" and a.ns.Recruit.COOLDOWN == 900)
  local V = a.DT._recruit.linesValid
  check("lines check: five plain lines pass", V({ "a", "b", "c", "d", "e" }))
  check("lines check: four lines fail", not V({ "a", "b", "c", "d" }))
  check("lines check: six lines fail", not V({ "a", "b", "c", "d", "e", "f" }))
  check("lines check: an empty line fails", not V({ "a", "", "c", "d", "e" }))
  check("lines check: a bar fails", not V({ "a", "b", "|cffff0000c", "d", "e" }))
  check("lines check: a control byte fails", not V({ "a", "b", "c\n", "d", "e" }))
  check("lines check: 255 bytes pass, 256 fail", V({ string.rep("x", 255), "b", "c", "d", "e" })
    and not V({ string.rep("x", 256), "b", "c", "d", "e" }))
  local files = {}
  for _, f in ipairs(H.tocFiles()) do if f ~= "RecruitLines.lua" then files[#files + 1] = f end end
  local n = mk(w, { name = "Nolines", files = files })
  n:login()
  n:slash("recruit")
  check("no lines: refused, nothing posted", n:said("No recruitment lines loaded. Tell an officer.") ~= nil and #n.posts == 0)
end

-- ---------------------------------------------------------------- posting
local w = H.world()
local a = mk(w, { name = "Stromham" })
a:login()
local DT = a.DT
local L = a.ns.Recruit.LINES
a:slash("help")
check("the help lists recruit [next]", a:said("recruit [next]") ~= nil)
a:slash("recruit next")
check("/dt recruit next before any post", a:said("Next up: line 1 of 5. Cooldown: ready.") ~= nil)
local sentBefore = #a.sent
a:slash("recruit")
check("a post: line 1, to CHANNEL, General - Orgrimmar's number", #a.posts == 1 and a.posts[1][1] == L[1]
  and a.posts[1][2] == "CHANNEL" and a.posts[1][3] == nil and a.posts[1][4] == 1)
check("and says so", a:said("Posted line 1 of 5 to General.") ~= nil)
check("the cooldown and rotation are stored", a:db().recruit.at == 1793833200 and a:db().recruit.next == 2)
w:advance(1)
check("no addon message is sent for a post", #a.sent == sentBefore)
a.now = a.now + 60
a:slash("recruit")
check("inside the cooldown: refused, minutes rounded up", #a.posts == 1 and a:said("Too soon. Next post in 14 min. Even necromancers pace themselves.") ~= nil)
a.now = 1793833200 + 121
a:slash("recruit")
check("rounded up: 779 s left is 13 min", a:said("Next post in 13 min") ~= nil)
a:slash("recruit next")
check("/dt recruit next shows the line and the wait", a:said("Next up: line 2 of 5. Cooldown: 13 min left.") ~= nil)
a.now = 1793833200 + 900
a:slash("recruit")
check("at 15 minutes: line 2", #a.posts == 2 and a.posts[2][1] == L[2])
for i = 3, 6 do a.now = a.now + 900; a:slash("recruit") end
check("the rotation runs 1 to 5 and back to 1", #a.posts == 6 and a.posts[5][1] == L[5] and a.posts[6][1] == L[1])
a.now = a.now + 900
a.noClock = true
a:slash("recruit")
check("clock unreadable: refused", a:said("Can't read the clock. Not posting.") ~= nil and #a.posts == 6)
a.noClock = false
a.lockdown = true
a:slash("recruit")
check("chat lockdown: refused", a:said("Chat's locked right now (an encounter?). Try after.") ~= nil and #a.posts == 6)
a.lockdown = false
a.chans = { { 2, "Trade - City" } }
a:slash("recruit")
check("not in General: refused", a:said("You're not in General. /join General first.") ~= nil and #a.posts == 6)
a.chans = { { 1, "General - Orgrimmar" } }
a.postFail = true
local at, nx = a:db().recruit.at, a:db().recruit.next
a:slash("recruit")
check("a failed post: refused, cooldown and rotation unmoved", a:said("The channel didn't take it. Nothing posted.") ~= nil
  and a:db().recruit.at == at and a:db().recruit.next == nx)
a.postFail = false
local saved = a.env.C_ChatInfo[SEND]
a.env.C_ChatInfo[SEND] = nil
a:slash("recruit")
check("the chat function absent: nothing posted, nothing moved", a:db().recruit.at == at and #a.posts == 6)
a.env.C_ChatInfo[SEND] = saved
a:slash("recruit sideways")
check("/dt recruit <other> explains itself, posts nothing", a:said("/dt recruit posts the next line; /dt recruit next shows which.") ~= nil and #a.posts == 6)

-- ---------------------------------------------------------------- A1: officers, General
do
  local w2 = H.world()
  local m = mk(w2, { name = "Marvella" })
  m.officer = false
  m:login()
  m:slash("recruit")
  check("A1: IsGuildOfficer false: refused, nothing posted", m:said("Officers only. The rest of us just haunt the place.") ~= nil and #m.posts == 0)
  m.officer = nil; m:slash("recruit")
  m.officer = "error"; m:slash("recruit")
  check("A1: nil or an error is not an officer either", #m.posts == 0 and m:count("Officers only.") == 1)
  m:slash("recruit next")
  check("A1: /dt recruit next still answers a non-officer, posts nothing", m:said("Next up: line 1 of 5.") ~= nil and #m.posts == 0)
  m.officer = true
  m.chans = { { 3, "General - Durotar" } }
  m:slash("recruit")
  check("A1: an officer posts; General - <zone> is matched, by its own number", #m.posts == 1 and m.posts[1][4] == 3)
  local M = m.DT._recruit.matches
  check("A1: Generalists is not General", not M("Generalists") and not M("General-Durotar") and not M("general - Durotar")
    and not M("General -") and M("General") and M("General - X"))
  local w3 = H.world()
  local q = mk(w3, { name = "Quill" }); q:login()
  q.chans = { { 5, "Generalists" } }; q:slash("recruit")
  check("A1: Generalists: refused, nothing posted", #q.posts == 0 and q:said("You're not in General.") ~= nil)
  q.chans = {}; q:slash("recruit")
  check("A1: no channels joined: refused", #q.posts == 0)
  q.chans = { { 0, "General" } }; q:slash("recruit")
  check("A1: a channel number of 0 is not joined", #q.posts == 0)
  q.chans = { { 6, "General" } }; q.noList = true; q:slash("recruit")
  check("A1: GetChannelList absent: GetChannelName by number finds it", #q.posts == 1 and q.posts[1][4] == 6)
  q.now = q.now + 900; q.noList = false; q.listError = true; q:slash("recruit")
  check("A1: GetChannelList erroring: GetChannelName finds it", #q.posts == 2)
  q.now = q.now + 900; q.listError = false; q.nameError = true; q:slash("recruit")
  check("A1: GetChannelName erroring: GetChannelList finds it", #q.posts == 3)
  q.now = q.now + 900; q.listError = true; q:slash("recruit")
  check("A1: both erroring: refused, nothing posted", #q.posts == 3)
  q.listError, q.nameError = false, false
  q.now = q.now + 900
  q.secrets["General"] = true
  q:slash("recruit")
  check("A1: a secret channel name is not matched", #q.posts == 3)
end

do
  local w2 = H.world()
  local o = mk(w2, { name = "Outsider", guild = "Other" })
  o:login()
  o:slash("recruit")
  check("a non-member: nothing printed, nothing posted", #o.printed == 0 and #o.posts == 0)
end

-- ---------------------------------------------------------------- the account shares it
do
  local w2 = H.world()
  local s = mk(w2, { name = "Stromham" })
  s:login(); s:slash("recruit")
  local alt = mk(w2, { name = "Gizzardthe", db = s:db() })
  alt.now = s.now + 300
  alt:login(); alt:slash("recruit")
  check("an alt on the same account shares the cooldown", #alt.posts == 0 and alt:said("Too soon.") ~= nil)
  alt.now = s.now + 900; alt:slash("recruit")
  check("and the rotation: the alt posts line 2", #alt.posts == 1 and alt.posts[1][1] == s.ns.Recruit.LINES[2])
end

-- ---------------------------------------------------------------- R1: never unasked
do
  local w2 = H.world()
  local s = mk(w2, { name = "Stromham" })
  local g = mk(w2, { name = "Ghoul" })
  s:login(); g:login()
  for _ = 1, 24 * 6 do
    s:fire("PLAYER_ENTERING_WORLD", false, false); s:fire("PLAYER_GUILD_UPDATE"); s:fire("GUILD_ROSTER_UPDATE")
    s:fire("ZONE_CHANGED_NEW_AREA"); s:fire("PLAYER_DEAD")
    g:slash("prep roll"); g:slash("who")
    s.now = s.now + 600
    w2:advance(600)
  end
  check("24 hours of logins, zoning, guild updates, roll calls, messages and the button's ticker: no post, ever", #s.posts == 0)
  s:slash("recruit")
  check("and the next press still posts line 1", #s.posts == 1 and s.posts[1][1] == s.ns.Recruit.LINES[1])
  s.now = s.now + 900
  local ok = s.DT._recruit.post()
  check("R1: post() called from anywhere but a typed command or the click refuses, silently", ok == false and #s.posts == 1
    and s:db().recruit.refusedUnasked == 1)
  s.DT.after(1, function() s.DT._recruit.post() end)
  w2:advance(2)
  check("R1: ...from a timer too", #s.posts == 1 and s:db().recruit.refusedUnasked == 2)
end

-- ---------------------------------------------------------------- R-P1: the Recruit button
do
  local w2 = H.world()
  local s = mk(w2, { name = "Stromham" })
  s:login()
  local function btn(c)
    for _, b in ipairs(c.DT._bar.buttons()) do if b.shown and b.entry and b.entry.name == "recruit" then return b end end
  end
  local b = btn(s)
  check("R-P1: an officer sees the Recruit button, ticked from the start", b ~= nil and b.text.text == "Recruit")
  b.scripts.OnEnter(b)
  local tt = s:frame("DeadTiredTooltip")
  check("R-P1: the tooltip shows the next line", tt.lines[#tt.lines - 2] == "Recruit" and tt.lines[#tt.lines - 1] == "Next up: line 1 of 5. Cooldown: ready."
    and tt.lines[#tt.lines] == s.ns.Recruit.LINES[1])
  b.scripts.OnClick(b, "LeftButton")
  check("R-P1: a left-click posts, exactly as /dt recruit", #s.posts == 1 and s.posts[1][1] == s.ns.Recruit.LINES[1]
    and s.posts[1][4] == 1 and s:said("Posted line 1 of 5 to General.") ~= nil)
  check("R-P1: the text shows the cooldown", b.text.text == "Recruit 15:00")
  s.now = s.now + 1; w2:advance(1)
  check("R-P1: the text counts down", b.text.text == "Recruit 14:59")
  b.scripts.OnClick(b, "LeftButton")
  check("R-P1: a second click inside 15 min doesn't post", #s.posts == 1 and s:said("Too soon. Next post in 15 min.") ~= nil)
  b.scripts.OnClick(b, "RightButton")
  check("R-P1: right-click opens its settings, posts nothing", s:frame("DeadTiredViewport_settings").shown and #s.posts == 1)
  for _ = 1, 899 do s.now = s.now + 1; w2:advance(1) end
  check("R-P1: back to Recruit when the cooldown ends; the ticker stops", b.text.text == "Recruit" and not s.DT._recruit.ticking())
  check("the nudge came once 15 min later", s:count("The crypt door creaks open: you can recruit again (/dt recruit).") == 1)
  check("R-P1: the ticker never posted", #s.posts == 1)
  s.chans = { { 9, "Trade - City" } }
  b.scripts.OnClick(b, "LeftButton")
  check("R-P1: the click keeps the General check", #s.posts == 1 and s:said("You're not in General.") ~= nil)
  s.chans = { { 1, "General - Orgrimmar" } }
  s.lockdown = true
  b.scripts.OnClick(b, "LeftButton")
  check("R-P1: and the lockdown check", #s.posts == 1 and s:said("Chat's locked right now") ~= nil)
  s.lockdown = false
  -- not an officer: no button
  local w3 = H.world()
  local m = mk(w3, { name = "Marvella", setup = function(c) end })
  m.officer = false
  m:login()
  check("R-P1: a non-officer sees no Recruit button, nor its row in the list", btn(m) == nil and (function()
    for _, e in ipairs(m.DT.barList()) do if e.name == "recruit" then return false end end return true end)())
  m.officer = true
  m:fire("PLAYER_GUILD_UPDATE")
  check("R-P1: promoted, the button appears", btn(m) ~= nil)
  m.officer = false
  m:fire("GUILD_ROSTER_UPDATE")
  check("R-P1: demoted, it goes", btn(m) == nil)
  -- a reload inside the cooldown keeps counting
  local r = s:reload()
  check("a reload inside a cooldown (the new client's clock reads the post's time): the countdown runs", btn(r) and btn(r).text.text == "Recruit 15:00")
  r.now = s.now; w2:advance(1)
  check("a reload: the text reads ready once the cooldown is over", btn(r) and btn(r).text.text == "Recruit")
end

-- ---------------------------------------------------------------- the nudge and R-P2
do
  local w2 = H.world()
  local s = mk(w2, { name = "Stromham" })
  s:login()
  local NUDGE = "The crypt door creaks open: you can recruit again (/dt recruit)."
  check("nudge: the brief's wording", s.DT._recruit.NUDGE == NUDGE)
  s:slash("recruit")
  check("nudge: the post goes", #s.posts == 1)
  w2:advance(899)
  check("nudge: nothing before the cooldown ends", s:count(NUDGE) == 0)
  w2:advance(2)
  check("nudge: after 900 s, exactly one line", s:count(NUDGE) == 1)
  w2:advance(3600)
  check("nudge: once only", s:count(NUDGE) == 1)
  check("nudge: it never posts anything", #s.posts == 1)
  s.now = s.now + 900
  s:slash("recruit")
  check("nudge: the second post goes", #s.posts == 2)
  w2:advance(400)
  s.now = s.now + 900
  s.printed = {}
  s:slash("set recruit nudge on")
  w2:advance(501)
  check("nudge: no line for the first post when a second came since (and not yet for the second)", s:count(NUDGE) == 1)
  s.officer = false
  w2:advance(400)
  check("nudge: no line if not an officer at the time", s:count(NUDGE) == 1)
  s.officer = true
  s.printed = {}
  s:slash("recruit nudge off")
  check("R-P2: /dt recruit nudge off replies", s:said("Nudge off. The crypt keeps its own counsel.") ~= nil and #s.printed == 1)
  check("nudge off: saved account-wide", s.DT.get("recruit", "nudge") == false and s:db().settings.recruit.nudge == false)
  s.now = s.now + 900; s:slash("recruit"); w2:advance(901)
  check("nudge off: no line", s:count(NUDGE) == 0)
  local alt = mk(w2, { name = "Jobbi", db = s:db() })
  alt:login()
  check("nudge off: still off on another character after a login", alt.DT.get("recruit", "nudge") == false)
  s:slash("recruit nudge on")
  check("R-P2: /dt recruit nudge on replies", s:said("Nudge on. The crypt will knock.") ~= nil)
  check("nudge on: saved", s.DT.get("recruit", "nudge") == true)
  s.now = s.now + 900; s:slash("recruit"); w2:advance(901)
  check("nudge on: the line is back", s:count(NUDGE) == 1)
  local fresh = mk(w2, { name = "Fresh", db = s:db() })
  fresh:login(); w2:advance(1000)
  check("nudge: no line at login without a post this session", fresh:count(NUDGE) == 0)
  s.chans = {}
  s.now = s.now + 900
  s.printed = {}
  s:slash("recruit"); w2:advance(1000)
  check("nudge: a refused post schedules nothing", s:count(NUDGE) == 0)
  check("the nudge is a settings card with a typed path", s.DT.setting("recruit", "nudge").verb == "recruit nudge on|off")
end

H.finish("recruit")
