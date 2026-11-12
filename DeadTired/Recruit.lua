-- Dead Tired: the recruitment rotator. One typed command or one click, one public line.
-- Card 5 (docs/COWORK_BRIEF_dt_prep.md on card/dt_prep; R1-R5 ratified 2026-11-02, A1 rulings
-- round), ported from rc3's Recruit.lua in Port 1. Logic and lines are rc3's.
--
-- R1: the only public post in the addon. It happens synchronously inside the /dt recruit handler or
--     the Recruit button's click (R-P1, Port 1) and nowhere else: never from a timer, an event, a
--     queue, a received message or a retry. post() itself refuses unless a typed command or the
--     button's click is running it. R2: one channel, 15 minutes per account between posts (alts
--     share it).
-- A1: guild officers only (the game's own flag), and the channel is General, found among the
--     joined channels by name: exactly "General" or "General - <zone>".
-- The nudge (fix round 3, a ruled "prints unasked" exception): after a post this session, one
--     line when the cooldown ends, once, only if still an officer and a member and nothing was
--     posted since. It prints; it never posts. Setting recruit.nudge (account-wide, default on);
--     /dt recruit nudge off|on answers with R-P2's two lines.
--     Port 2 (the Port 1 walk's defect 1): /dt recruit nudge on while a post's cooldown is still
--     running arms the nudge for the time left, so off then on keeps it; it still comes once (a
--     new arming replaces the old, and a nudge already said for that post is never said again).
-- R-P1: the Recruit object on the bar (officers only): text "Recruit" or "Recruit m:ss" while the
--     cooldown runs; left-click posts exactly as /dt recruit; right-click its settings; the tooltip
--     shows the next line. A 1 s ticker redraws the text while the cooldown runs; it never posts.
-- State: DeadTiredDB.recruit = { next, at } (account-wide).
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local R = ns.Recruit or {}
local CHANNEL = type(R.RECRUIT_CHANNEL) == "string" and R.RECRUIT_CHANNEL or "General"
local MAX_CHANNELS = 20      -- ids scanned when only GetChannelName is there
local COOLDOWN = tonumber(R.COOLDOWN) or 900
local LINES = type(R.LINES) == "table" and R.LINES or {}
local COUNT = 5
local NUDGE = "The crypt door creaks open: you can recruit again (/dt recruit)."
local NUDGE_OFF = "Nudge off. The crypt keeps its own counsel."
local NUDGE_ON = "Nudge on. The crypt will knock."
local ICON = [[Interface\Icons\INV_Misc_Note_02]]

-- Checked once, at load: exactly five non-empty lines, each at most 255 bytes, no "|" (the chat
-- escape character) and no control bytes.
local function linesValid(t)
  if #t ~= COUNT then return false end
  for i = 1, COUNT do
    local s = t[i]
    if type(s) ~= "string" or s == "" or #s > 255 or s:find("[|%z\1-\31]") then return false end
  end
  return true
end
local VALID = linesValid(LINES)

local function store()
  local db = DT.db()
  if type(db.recruit) ~= "table" then db.recruit = {} end
  return db.recruit
end

local function nextIndex()
  local i = store().next
  if type(i) ~= "number" or i < 1 or i > COUNT or i ~= math.floor(i) then return 1 end
  return i
end

-- Seconds of cooldown left, 0 when free, or nil when the clock can't be read.
local function left()
  local now = clean(try(time))
  if type(now) ~= "number" then return nil, nil end
  local at = store().at
  if type(at) == "number" and now - at < COOLDOWN then return COOLDOWN - (now - at), now end
  return 0, now
end

-- A1: the game's officer flag, and nothing else. false, nil, absent, secret or an error: no.
local function isOfficer()
  return try(C_GuildInfo and C_GuildInfo.IsGuildOfficer) == true
end
DT.isOfficer = isOfficer

-- A1: "General" or "General - Orgrimmar", never "Generalists".
local function matches(name)
  if type(name) ~= "string" then return false end
  return name == CHANNEL or name:sub(1, #CHANNEL + 3) == CHANNEL .. " - "   -- guard: General name match
end

local function pack(...) return { n = select("#", ...), ... } end

-- The joined channel's number, or nil. GetChannelList (id, name, disabled, ...) if it is there,
-- then GetChannelName(id) over the channel numbers. Both are globals: every call guarded.
local function findChannel()
  local list = pack(try(GetChannelList))
  for i = 1, list.n, 3 do
    local id, name = clean(list[i]), clean(list[i + 1])
    if type(id) == "number" and id > 0 and matches(name) then return id end
  end
  local max = clean(MAX_WOW_CHAT_CHANNELS)
  if type(max) ~= "number" or max < 1 or max > 100 then max = MAX_CHANNELS end
  for n = 1, max do
    local id, name = try(GetChannelName, n)
    id, name = clean(id), clean(name)
    if type(id) == "number" and id > 0 and matches(name) then return id end
  end
end

-- ---------------------------------------------------------------- the button's text

local function clock(s)
  s = math.ceil(s)
  return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local ticking = false
local function redraw()
  local wait = left()
  DT.update("recruit", "text", (wait and wait > 0) and ("Recruit " .. clock(wait)) or "Recruit")
  return wait
end

-- Redraws the text once a second while the cooldown runs. It only ever redraws.
local function tickText()
  if ticking then return end
  ticking = true
  local function step()
    local wait = redraw()
    if wait and wait > 0 then DT.after(1, step) else ticking = false end
  end
  step()
end

-- ---------------------------------------------------------------- the nudge

local posts = 0
local nudged = nil            -- the post (its recruit.at) whose nudge was said
local function nudgeOn() return DT.get("recruit", "nudge") ~= false end

-- Arm the nudge for the post stamped `at`, due in `delay` seconds. The latest arming wins.
local function schedule(at, delay)
  posts = posts + 1
  local mine = posts
  DT.after(delay, function()
    if mine ~= posts then return end                                  -- guard: nothing posted since (nudge)
    if store().at ~= at or nudged == at then return end               -- guard: once per post (nudge)
    if not nudgeOn() then return end                                  -- guard: nudge switched off
    if not DT.isMember() or not isOfficer() then return end           -- guard: still an officer (nudge)
    nudged = at
    DT.out(NUDGE)
  end)
end

-- Port 2: nudge on (typed, /dt set or the card) with a post's cooldown still running re-arms it
-- for the time left.
local function rearm()
  local wait = left()
  local at = store().at
  if wait and wait > 0 and type(at) == "number" then
    schedule(at, wait)                                                -- guard: nudge re-armed (Port 2)
  end
end

-- ---------------------------------------------------------------- the post

local clicking = false        -- true only inside the Recruit button's OnClick

local function post()
  if not (DT.inCommand or clicking) then                              -- guard: typed or clicked only (R1)
    local r = store()
    r.refusedUnasked = (r.refusedUnasked or 0) + 1
    return false
  end
  if not isOfficer() then                                             -- guard: officer gate (A1)
    return DT.out("Officers only. The rest of us just haunt the place.")
  end
  if not VALID then                                                   -- guard: lines check
    return DT.out("No recruitment lines loaded. Tell an officer.")
  end
  local wait, now = left()
  if not wait then return DT.out("Can't read the clock. Not posting.") end
  if wait > 0 then                                                    -- guard: cooldown
    return DT.out("Too soon. Next post in " .. math.ceil(wait / 60) .. " min. Even necromancers pace themselves.")
  end
  if try(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown) == true then   -- guard: lockdown
    return DT.out("Chat's locked right now (an encounter?). Try after.")
  end
  local id = findChannel()
  if not id then                                                      -- guard: channel
    return DT.out("You're not in " .. CHANNEL .. ". /join " .. CHANNEL .. " first.")
  end
  local i = nextIndex()
  local say = C_ChatInfo and C_ChatInfo.SendChatMessage
  local ok = type(say) == "function" and pcall(say, LINES[i], "CHANNEL", nil, id)
  if not ok then                                                      -- guard: failed post moves nothing
    return DT.out("The channel didn't take it. Nothing posted.")
  end
  local r = store()
  r.at = now
  r.next = i % COUNT + 1
  DT.out("Posted line " .. i .. " of " .. COUNT .. " to " .. CHANNEL .. ".")
  schedule(now, COOLDOWN)
  tickText()
  return true
end

local function peekLine()
  local wait = left()
  local cd = (wait == nil and "the clock can't be read") or (wait > 0 and (math.ceil(wait / 60) .. " min left"))
    or "ready"
  return "Next up: line " .. nextIndex() .. " of " .. COUNT .. ". Cooldown: " .. cd .. "."
end

local function verb(args)
  local w = (args or ""):lower():gsub("%s+", " ")
  if w == "next" then return DT.out(peekLine()) end
  if w == "nudge off" then DT.set("recruit", "nudge", false); return DT.out(NUDGE_OFF) end
  if w == "nudge on" then DT.set("recruit", "nudge", true); return DT.out(NUDGE_ON) end
  if w == "" then return post() end
  return DT.out("/dt recruit posts the next line; /dt recruit next shows which.")
end

-- R-P1: the click is the hardware event; the flag is up for that call only.
local function click(_, which)
  if which == "RightButton" then return DT.openSettings("recruit") end
  clicking = true
  local ok, err = pcall(post)
  clicking = false
  if not ok then DT.fail("recruit", "click", err); error(err, 0) end
end

local function tooltip(tt)
  tt:AddLine("Recruit")
  tt:AddLine(peekLine(), 1, 1, 1)
  if VALID then tt:AddLine(LINES[nextIndex()], 0.8, 0.8, 0.8, true) end
end

-- Officers, inside the guild, see the button; nobody else does.
local function visible() return DT.isMember() and isOfficer() end

-- For the offline tests only.
DT._recruit = { valid = function() return VALID end, linesValid = linesValid, lines = LINES, matches = matches,
  NUDGE = NUDGE, NUDGE_OFF = NUDGE_OFF, NUDGE_ON = NUDGE_ON, post = post, click = click, clock = clock,
  ticking = function() return ticking end }

DT.module({
  id = "recruit",
  title = "Recruit",
  settings = {
    { key = "nudge", type = "bool", default = true, label = "Nudge", verb = "recruit nudge on|off",
      onChange = function(on) if on then rearm() end end,
      desc = "After you post, one line in chat when the 15 minutes are up. It never posts anything itself." },
  },
  verbs = { { verb = "recruit", usage = "recruit [next]", fn = verb } },
  ldb = { type = "launcher", text = "Recruit", icon = ICON, visible = visible, OnClick = click,
    OnTooltipShow = tooltip },
  init = function() store() end,
  events = {
    PLAYER_ENTERING_WORLD = function() DT.barRefresh(); local w = left() if w and w > 0 then tickText() end end,
    PLAYER_GUILD_UPDATE = function() DT.barRefresh() end,
    GUILD_ROSTER_UPDATE = function() DT.barRefresh() end,
  },
})
