-- Dead Tired: the recruitment rotator. One typed command or macro click, one public line.
-- docs/COWORK_BRIEF_dt_prep.md (card 5; R1-R5 ratified 2026-11-02).
--
-- R1: the only public post in the addon. It happens synchronously inside the /dt recruit
--     handler and nowhere else: never from a timer, an event, a queue, a received message or a
--     retry. R2: one channel, 15 minutes per account between posts (alts share it).
-- A1 (rulings round, 2026-11-02): guild officers only (the game's own flag), and the channel is
--     General, found among the joined channels by name: exactly "General" or "General - <zone>".
-- The lines are Tim's (RecruitLines.lua, from docs/RECRUIT_lines.md) and are never edited here.
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local R = ns.Recruit or {}
local CHANNEL = type(R.RECRUIT_CHANNEL) == "string" and R.RECRUIT_CHANNEL or "General"
local MAX_CHANNELS = 20      -- ids scanned when only GetChannelName is there
local COOLDOWN = tonumber(R.COOLDOWN) or 900
local LINES = type(R.LINES) == "table" and R.LINES or {}
local COUNT = 5

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

local function store() return DT.prep() end

local function nextIndex()
  local i = store().recruitNext
  if type(i) ~= "number" or i < 1 or i > COUNT or i ~= math.floor(i) then return 1 end
  return i
end

-- Seconds of cooldown left, 0 when free, or nil when the clock can't be read.
local function left()
  local now = clean(try(time))
  if type(now) ~= "number" then return nil, nil end
  local at = store().recruitAt
  if type(at) == "number" and now - at < COOLDOWN then return COOLDOWN - (now - at), now end
  return 0, now
end

-- A1: the game's officer flag, and nothing else. false, nil, absent, secret or an error: no.
local function isOfficer()
  return try(C_GuildInfo and C_GuildInfo.IsGuildOfficer) == true
end

-- A1: "General" or "General - Orgrimmar", never "Generalists". The zone suffix means no fixed
-- channel number and no bare-name lookup: the joined channels are scanned.
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

local function post()
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
  local p = store()
  p.recruitAt = now
  p.recruitNext = i % COUNT + 1
  DT.out("Posted line " .. i .. " of " .. COUNT .. " to " .. CHANNEL .. ".")
end

local function peek()
  local wait = left()
  local cd = (wait == nil and "the clock can't be read") or (wait > 0 and (math.ceil(wait / 60) .. " min left"))
    or "ready"
  DT.out("Next up: line " .. nextIndex() .. " of " .. COUNT .. ". Cooldown: " .. cd .. ".")
end

-- For the offline tests only.
DT._recruit = { valid = function() return VALID end, linesValid = linesValid, lines = LINES, matches = matches }

DT.module({
  id = "recruit",
  init = function() store() end,
  ready = DT.errors,
  errorKey = "recruit", lastKey = "lastRecruit",
})
DT.verb("recruit", function(msg)
  if msg == "recruit next" then return peek() end
  if msg == "recruit" then return post() end
  return DT.out("/dt recruit posts the next line; /dt recruit next shows which.")
end, "recruit [next]")
