-- Dead Tired: guild addon messaging. GUILD channel only, in and out; members only.
--
-- Wire format (docs/COWORK_BRIEF_dt_foundation.md, "Wire format"):
--   <PROTOCOL>^<KIND>^<key>~<value>^<key>~<value>...      KIND: upper-case letters only
--   keys and values escaped: % ^ ~ | and every byte below 32 become %XX (upper-case hex)
--   over 250 bytes: chunks <PROTOCOL>^+^<msgid>^<i>^<n>^<slice>, slice at most 200 bytes
-- Outbound: token bucket (5, +1/s) feeding a FIFO queue; held only while the client is in chat
-- messaging lockdown (boss fights, M+, PvP matches), retried every 5 s (fix round 3, R-1: the
-- AreOutgoingAddonChatMessagesRestricted flag reads true on Forever while messages get through,
-- so it is recorded once per login for diagnostics and never gates a send). A send the game
-- refuses goes back to the front of the queue and is retried after at least 1 s; after 3
-- refusals it is dropped and counted (AUD-10). Queue cap 50, oldest dropped and counted.
-- Inbound: counted and dropped when malformed or of an unknown protocol; never raises on bad
-- input. Inbound data is handed to DT.on handlers as plain strings, never executed.
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local PREFIX = DT.Config.PREFIX or "DEADTIRED"
local PROTOCOL = DT.Config.PROTOCOL or 1
local CHANNEL = "GUILD"

local MAX_WHOLE = 250     -- longest message sent in one piece
local SLICE = 200         -- longest chunk slice
local MAX_CHUNKS = 32     -- refuse (outbound) or call malformed (inbound) anything bigger
local STALE = 30          -- seconds an incomplete chunk set is kept
local BUCKET, RATE = 5, 1 -- token bucket: capacity, tokens per second
local RETRY = 5           -- seconds between tries while in lockdown
local REFUSE_WAIT = 1     -- least wait after a refused send (AUD-10)
local MAX_REFUSALS = 3    -- refusals of one message before it is dropped (AUD-10)
local HELD_LINE = "The dead are gagged for this fight. Your message goes when it's over."
local QUEUE_CAP = 50
local MAX_FIELDS = 32

-- ---------------------------------------------------------------- escaping

local function esc(s)
  return (tostring(s):gsub("[%%%^~|%z\1-\31]", function(ch) return string.format("%%%02X", ch:byte()) end))
end

-- nil for anything that is not a valid escaped string.
local function unesc(s)
  local rest = s:gsub("%%%x%x", "")
  if rest:find("[%%%^~|%z\1-\31]") then return nil end
  return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function encode(kind, fields)
  local keys = {}
  for k, v in pairs(fields or {}) do
    if v ~= nil then keys[#keys + 1] = tostring(k) end
  end
  table.sort(keys)
  local parts = { tostring(PROTOCOL), kind }
  for _, k in ipairs(keys) do parts[#parts + 1] = esc(k) .. "~" .. esc(fields[k]) end
  return table.concat(parts, "^")
end

-- A whole (unchunked) message after its protocol: "KIND^k~v^k~v". Returns kind, fields, or nil.
local function parseBody(rest)
  local kind, body = rest:match("^([A-Z]+)(.*)$")
  if not kind then return nil end
  if body:gsub("%^[^%^]*", "") ~= "" then return nil end
  local fields, n = {}, 0
  for seg in body:gmatch("%^([^%^]*)") do
    n = n + 1
    if n > MAX_FIELDS then return nil end
    local k, v = seg:match("^([^~]+)~([^~]*)$")
    if not k then return nil end
    k, v = unesc(k), unesc(v)
    if not k or not v then return nil end
    fields[k] = v
  end
  return kind, fields
end

-- ---------------------------------------------------------------- state

local queue = {}
local tokens, lastRefill = BUCKET, nil
local pending = false
local refusals = 0        -- AUD-10: refusals of the message at the head of the queue
local notBefore = nil     -- AUD-10: after a refusal, the clock time the next try may go
local holding = false     -- the pump is holding for lockdown
local heldSaid = false    -- the held line has been printed for this hold
-- Fix round 1 (F5): chunk ids start from the clock, so a /reload doesn't reuse the ids of the
-- session before it (receivers keep partial sets for 30 s, keyed sender#msgid).
local msgid = 0
do
  local t = clean(try(time))
  if type(t) == "number" then msgid = math.floor(t) % 100000 end
end
local partial = {}        -- [senderKey .. "#" .. msgid] = { n, got = {}, count, t }
local handlers = {}

local function stats() return DT.db().comms end

-- R-1: hold only in lockdown. Absent, erroring or secret: not in lockdown (the throttle and
-- the refusal retry still protect the send).
local function lockdown()
  local f = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
  return (try(f)) == true
end

-- R-1: the restricted flag, read once per login and recorded; nothing reads it back.
local flagRead = false
local function recordFlag()
  if flagRead then return end
  flagRead = true
  local s = stats()
  local f = C_ChatInfo and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted
  s.flagRestricted = clean(try(f))
  s.flagReads = (s.flagReads or 0) + 1
end

-- AUD-10: what SendAddonMessage answered. Success is Enum.SendAddonMessageResult.Success (0
-- when that table is absent), or true / nil on clients that answer those. Anything else, or a
-- raised error, is a refusal.
local function succeeded(ok, r)
  if not ok then return false end
  r = clean(r)
  if r == nil or r == true then return true end
  local E = Enum and Enum.SendAddonMessageResult
  local code = type(E) == "table" and type(E.Success) == "number" and E.Success or 0
  return r == code                                                       -- guard: success test (AUD-10)
end

-- ---------------------------------------------------------------- outbound

local pump
local function wake(d)
  if pending then return end
  pending = true
  if not DT.after(d, function() pending = false; pump() end) then pending = false end
end

local function refill()
  local t = DT.now()
  if lastRefill then tokens = math.min(BUCKET, tokens + (t - lastRefill) * RATE) end
  lastRefill = t
end

pump = function()
  while #queue > 0 do
    if lockdown() then holding = true; wake(RETRY) return end            -- guard: lockdown hold (R-1)
    holding, heldSaid = false, false
    if notBefore then
      local t = DT.now()
      if t < notBefore then wake(notBefore - t) return end                -- the refusal wait
      notBefore = nil
    end
    refill()
    if tokens < 1 then wake(math.max(0.05, (1 - tokens) / RATE)) return end -- guard: throttle
    local m = table.remove(queue, 1)
    tokens = tokens - 1
    local send = C_ChatInfo and C_ChatInfo.SendAddonMessage
    local ok, r = false, "absent"
    if type(send) == "function" then ok, r = pcall(send, PREFIX, m, CHANNEL) end
    local s = stats()
    if succeeded(ok, r) then
      refusals = 0
      s.sent = (s.sent or 0) + 1
      if #m > (s.longest or 0) then s.longest = #m end
    else
      s.sendRefused = (s.sendRefused or 0) + 1
      s.lastRefusal = DT.safe(clean(r) == nil and "?" or r, 64)
      refusals = refusals + 1
      if refusals >= MAX_REFUSALS then                                   -- guard: 3-refusal limit (AUD-10)
        refusals = 0
        s.refusedDropped = (s.refusedDropped or 0) + 1
      else
        table.insert(queue, 1, m)                                        -- guard: front-of-queue requeue (AUD-10)
        refill()
        local d = math.max(REFUSE_WAIT, (1 - tokens) / RATE)
        notBefore = DT.now() + d
        wake(d)
        return
      end
    end
  end
end

local function enqueue(m)
  if #queue >= QUEUE_CAP then
    table.remove(queue, 1)
    refusals = 0
    local s = stats()
    s.dropped = s.dropped + 1
  end
  queue[#queue + 1] = m
end

-- DT.send(kind, fields): true when queued. Sends nothing outside the guild.
function DT.send(kind, fields)
  if not DT.isMember() then return false end                            -- guard: send member gate
  if type(kind) ~= "string" or not kind:match("^[A-Z]+$") then return false end
  local m = encode(kind, fields)
  if #m <= MAX_WHOLE then
    enqueue(m)
  else
    local n = math.ceil(#m / SLICE)
    if n > MAX_CHUNKS then return false end
    msgid = msgid + 1
    for i = 1, n do
      enqueue(PROTOCOL .. "^+^" .. msgid .. "^" .. i .. "^" .. n .. "^" .. m:sub((i - 1) * SLICE + 1, i * SLICE))
    end
  end
  pump()
  -- The held line: a typed command's message waits for lockdown; said once per hold.
  if holding and DT.inCommand and not heldSaid then                       -- guard: held line once per hold
    heldSaid = true
    DT.out(HELD_LINE)
  end
  return true
end

-- DT.on(kind, fn(senderKey, fields))
function DT.on(kind, fn)
  handlers[kind] = handlers[kind] or {}
  table.insert(handlers[kind], fn)
end

-- ---------------------------------------------------------------- inbound

-- "Name-Realm" (as CHAT_MSG_ADDON names it) or a bare "Name" (the player's own realm) ->
-- the one key spelling, DT.keyOf (fix round 3, AUD-06).
local function senderKey(sender)
  sender = clean(sender)
  if type(sender) ~= "string" or sender == "" then return nil end
  local name, realm = sender:match("^([^%-]+)%-(.+)$")
  if not name then name = sender end
  return DT.keyOf(name, realm)
end
DT.senderKey = senderKey

local function sweep()
  local t = DT.now()
  for id, p in pairs(partial) do
    if t - p.t > STALE then
      partial[id] = nil
      local s = stats()
      s.stale = s.stale + 1
    end
  end
end

-- Returns "ok", kind, fields | "chunk" (held for more) | "unknown" | "malformed".
local function parse(key, text)
  if type(text) ~= "string" then return "malformed" end
  local pv, rest = text:match("^(%d+)%^(.*)$")
  if not pv then return "malformed" end
  if tonumber(pv) ~= PROTOCOL then return "unknown" end
  if rest:sub(1, 2) == "+^" then
    local id, i, n, slice = rest:match("^%+%^(%d+)%^(%d+)%^(%d+)%^(.+)$")
    i, n = tonumber(i), tonumber(n)
    if not id or not i or not n or i < 1 or n < 2 or i > n or n > MAX_CHUNKS then return "malformed" end
    local pid = key .. "#" .. id
    local p = partial[pid]
    if p and p.n ~= n then partial[pid] = nil return "malformed" end
    if not p then
      p = { n = n, got = {}, count = 0, t = DT.now() }
      partial[pid] = p
      DT.after(STALE + 1, sweep)
    end
    if not p.got[i] then p.count = p.count + 1 end
    p.got[i] = slice
    if p.count < n then return "chunk" end
    partial[pid] = nil
    local whole = table.concat(p.got, "", 1, n)
    local wpv, wrest = whole:match("^(%d+)%^(.*)$")
    if not wpv or tonumber(wpv) ~= PROTOCOL or wrest:sub(1, 2) == "+^" then return "malformed" end
    rest = wrest
  end
  local kind, fields = parseBody(rest)
  if not kind then return "malformed" end
  return "ok", kind, fields
end

local function inbound(prefix, text, channel, sender)
  if prefix ~= PREFIX or channel ~= CHANNEL then return end
  if not DT.isMember() then return end                                  -- guard: inbound member gate
  sweep()
  local s = stats()
  local key = senderKey(sender)
  if not key then s.malformed = s.malformed + 1 return end
  if key == DT.charKey() then return end                                -- guard: own-message ignore
  local ok, res, kind, fields = pcall(parse, key, clean(text))          -- guard: malformed pcall
  if not ok or res == "malformed" then s.malformed = s.malformed + 1 return end
  if res == "unknown" then s.unknownVersion = s.unknownVersion + 1 return end
  if res ~= "ok" then return end
  s.received = (s.received or 0) + 1
  for _, fn in ipairs(handlers[kind] or {}) do fn(key, fields) end
end

-- For the offline tests only.
DT._comms = { encode = encode, esc = esc, unesc = unesc, parseBody = parseBody, senderKey = senderKey,
  queue = function() return queue end, partial = function() return partial end,
  tokens = function() return tokens end, holding = function() return holding end,
  refusals = function() return refusals end, HELD_LINE = HELD_LINE }

DT.module({
  id = "comms",
  init = function()
    DT.db()
    local reg = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix
    try(reg, PREFIX)
  end,
  events = { CHAT_MSG_ADDON = inbound, PLAYER_ENTERING_WORLD = recordFlag },
  ready = DT.errors,
  errorKey = "comms", lastKey = "lastComms",
})
