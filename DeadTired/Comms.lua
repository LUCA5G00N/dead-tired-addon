-- Dead Tired: guild addon messages. GUILD channel only, in and out; members only.
--
-- Wire (protocol 2): "<PROTOCOL>:" .. LibDeflate:EncodeForWoWAddonChannel(
--                        LibDeflate:CompressDeflate(LibSerialize:Serialize(payload)))
--   payload = { k = KIND (upper-case letters), f = the sender's own key (DT.myKey()), d = data table }
-- The version sits in front of the encoding, so a message of an unknown version is counted and
-- ignored without being decoded. AceComm-3.0 splits and joins messages over 255 bytes;
-- ChatThrottleLib paces them. DT's gate sits on top and changes nothing inside either library:
--   * R-1: held only while C_ChatInfo.InChatMessagingLockdown() is true (boss fights, M+, PvP
--     matches), rechecked every 5 s. AreOutgoingAddonChatMessagesRestricted reads true on Forever
--     while messages get through: it is read once per login for diagnostics and gates nothing.
--   * The held line, once per hold, only for a typed /dt command's message.
--   * AUD-10: a message any of whose chunks the game refused is sent again after at least 1 s; after
--     3 tries it is dropped and counted. ChatThrottleLib itself keeps and retries a chunk only on
--     AddonMessageThrottle (result 3) and reports every other refusal to AceComm's callback as
--     didSend = false; that callback is where DT counts. A refusal while in lockdown is held, not
--     counted as a try.
--   * Requirement 2: the receiver takes the payload key when its name part matches the sender
--     string's name part (case-insensitive, with or without "-Realm"); a mismatch is counted and
--     kept (last 10) instead of guessed. Every distinct raw sender string is kept for
--     /dt debug senders (capped at 50).
-- Inbound data is handed to DT.on handlers as plain values, never executed or printed raw.
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local PREFIX = DT.Config.PREFIX or "DEADTIRED"
local PROTOCOL = DT.Config.PROTOCOL or 2
local CHANNEL = "GUILD"
local RETRY = 5           -- seconds between lockdown checks while holding
local REFUSE_WAIT = 1     -- least wait after a refused send (AUD-10)
local MAX_TRIES = 3       -- tries of one message before it is dropped (AUD-10)
local QUEUE_CAP = 50
local MAX_WIRE = 2048     -- longest accepted message, before decoding
local MAX_SENDERS = 50
local MAX_MISMATCHES = 10
local HELD_LINE = "The dead are gagged for this fight. Your message goes when it's over."

local LS = LibStub
local AceComm = LS and LS("AceComm-3.0", true)
local Serializer = LS and LS("LibSerialize", true)
local Deflate = LS and LS("LibDeflate", true)

local function stats() return DT.db().comms end

-- ---------------------------------------------------------------- encoding

local function encode(kind, data, from)
  local ok, ser = pcall(Serializer.Serialize, Serializer, { k = kind, f = from, d = data })
  if not ok or type(ser) ~= "string" then return nil end
  local comp = Deflate:CompressDeflate(ser)
  return PROTOCOL .. ":" .. Deflate:EncodeForWoWAddonChannel(comp)
end

-- "ok", payload | "unknown" | "malformed"
local function decode(text)
  if type(text) ~= "string" then return "malformed" end
  local pv, body = text:match("^(%d+):(.+)$")
  if not pv then return "malformed" end
  if tonumber(pv) ~= PROTOCOL then return "unknown" end                    -- guard: protocol version
  if #text > MAX_WIRE then return "malformed" end
  local comp = Deflate:DecodeForWoWAddonChannel(body)
  if type(comp) ~= "string" then return "malformed" end
  local ser = Deflate:DecompressDeflate(comp)
  if type(ser) ~= "string" then return "malformed" end
  local ok, p = Serializer:Deserialize(ser)
  if not ok or type(p) ~= "table" then return "malformed" end
  if type(p.k) ~= "string" or not p.k:match("^[A-Z]+$") then return "malformed" end
  if type(p.f) ~= "string" or not DT.splitKey(p.f) then return "malformed" end
  if p.d ~= nil and type(p.d) ~= "table" then return "malformed" end
  return "ok", p
end

-- ---------------------------------------------------------------- sender and payload key

-- The name part of a sender string: "Stromham Hamson-CAMWOWEU4Realm2PvP" or "Stromham Hamson".
local function senderName(sender)
  if type(sender) ~= "string" then return nil end
  return DT.fullName(sender)
end

local function keyMatchesSender(key, sender)
  local _, kn = DT.splitKey(key)
  local sn = senderName(sender)
  if not kn or not sn then return false end
  return DT.fullName(kn):lower() == sn:lower()                             -- guard: payload-key name match
end

local function recordSender(sender, channel)
  sender = clean(sender)
  if type(sender) ~= "string" then return end
  local s = stats()
  local e = s.senders[sender]
  if not e then
    local n = 0
    for _ in pairs(s.senders) do n = n + 1 end
    if n >= MAX_SENDERS then s.sendersOverflow = (s.sendersOverflow or 0) + 1 return end
    e = { n = 0 }
    s.senders[sender] = e
  end
  e.n = e.n + 1
  e.last = DT.stamp()
  e.chan = type(channel) == "string" and channel or "?"
end

local function recordMismatch(sender, key)
  local m = stats().mismatches
  table.insert(m, { sender = DT.safe(sender, 80), key = DT.safe(key, 80), t = DT.stamp() })
  while #m > MAX_MISMATCHES do table.remove(m, 1) end
end

-- ---------------------------------------------------------------- outbound

local queue = {}
local pending = false
local notBefore = nil
local holding = false     -- the gate is holding for lockdown
local heldSaid = false    -- the held line has been printed for this hold

-- R-1: hold only in lockdown. Absent, erroring or secret: not in lockdown.
local function lockdown()
  local f = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
  return (try(f)) == true
end

local flagRead = false
local function recordFlag()
  if flagRead then return end
  flagRead = true
  local s = stats()
  local f = C_ChatInfo and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted
  s.flagRestricted = clean(try(f))
  s.flagReads = (s.flagReads or 0) + 1
end

local pump
local function wake(d)
  if pending then return end
  pending = true
  if not DT.after(d, function() pending = false; pump() end) then pending = false end
end

-- AceComm calls this once per chunk: (item, bytes sent so far, total bytes, didSend).
local function done(item, sent, total, didSend)
  if not (didSend == true or didSend == 0) then item.failed = true end      -- guard: success test (AUD-10)
  if type(sent) == "number" and type(total) == "number" and sent < total then return end
  local s = stats()
  if not item.failed then
    s.sent = s.sent + 1
    if #item.wire > (s.longest or 0) then s.longest = #item.wire end
    return
  end
  s.sendRefused = s.sendRefused + 1
  if lockdown() then
    item.tries = item.tries - 1                                            -- held, not a try
    table.insert(queue, 1, item)
    pump()
    return
  end
  if item.tries >= MAX_TRIES then                                          -- guard: 3-try limit (AUD-10)
    s.refusedDropped = s.refusedDropped + 1
    return
  end
  table.insert(queue, 1, item)
  notBefore = DT.now() + REFUSE_WAIT
  wake(REFUSE_WAIT)
end

pump = function()
  while #queue > 0 do
    if lockdown() then                                                     -- guard: lockdown hold (R-1)
      if not holding then holding = true; stats().held = stats().held + 1 end
      wake(RETRY)
      return
    end
    holding, heldSaid = false, false
    if notBefore then
      local t = DT.now()
      if t < notBefore then wake(notBefore - t) return end
      notBefore = nil
    end
    local item = table.remove(queue, 1)
    item.failed = false
    item.tries = item.tries + 1
    AceComm:SendCommMessage(PREFIX, item.wire, CHANNEL, nil, "NORMAL", done, item)
  end
end

local function enqueue(item)
  if #queue >= QUEUE_CAP then
    table.remove(queue, 1)
    local s = stats()
    s.dropped = s.dropped + 1
  end
  queue[#queue + 1] = item
end

-- DT.send(kind, data): true when queued. Sends nothing outside the guild.
function DT.send(kind, data)
  if not DT.isMember() then return false end                              -- guard: guild gate (send)
  if not (AceComm and Serializer and Deflate) then return false end
  if type(kind) ~= "string" or not kind:match("^[A-Z]+$") then return false end
  if data ~= nil and type(data) ~= "table" then return false end
  local me = DT.myKey()
  if not me then return false end
  local wire = encode(kind, data, me)
  if not wire then return false end
  enqueue({ wire = wire, kind = kind, tries = 0 })
  pump()
  if holding and DT.inCommand and not heldSaid then                        -- guard: held line once per hold
    heldSaid = true
    DT.out(HELD_LINE)
  end
  return true
end

-- ---------------------------------------------------------------- inbound

local handlers = {}
function DT.on(kind, fn)
  handlers[kind] = handlers[kind] or {}
  table.insert(handlers[kind], fn)
end

local function inbound(prefix, text, distribution, sender)
  if prefix ~= PREFIX or distribution ~= CHANNEL then return end
  if not DT.isMember() then return end                                    -- guard: guild gate (inbound)
  local s = stats()
  local res, p = decode(clean(text))
  if res == "unknown" then s.unknownVersion = s.unknownVersion + 1 return end
  if res ~= "ok" then s.malformed = s.malformed + 1 return end
  if not keyMatchesSender(p.f, clean(sender)) then
    s.keyMismatch = s.keyMismatch + 1
    recordMismatch(clean(sender), p.f)
    return
  end
  local me = DT.myKey()
  if me and DT.sameKey(p.f, me) then return end                            -- the GUILD echo of our own
  s.received = s.received + 1
  local first
  for _, fn in ipairs(handlers[p.k] or {}) do
    local ok, err = pcall(fn, p.f, p.d or {}, clean(sender))
    if not ok then DT.fail("comms", "on " .. p.k, err); first = first or err end
  end
  if first then error(first, 0) end
end

local receiver = {}

DT.module({
  id = "comms",
  title = "Comms",
  init = function()
    if AceComm then AceComm.RegisterComm(receiver, PREFIX, inbound) end
  end,
  events = {
    CHAT_MSG_ADDON = function(prefix, text, channel, sender)
      if prefix == PREFIX then recordSender(sender, channel) end
    end,
    PLAYER_ENTERING_WORLD = recordFlag,
  },
})

-- For the offline tests only.
DT._comms = { encode = encode, decode = decode, keyMatchesSender = keyMatchesSender, inbound = inbound,
  queue = function() return queue end, holding = function() return holding end,
  HELD_LINE = HELD_LINE, PREFIX = PREFIX, MAX_SENDERS = MAX_SENDERS }
