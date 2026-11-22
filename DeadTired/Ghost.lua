-- Dead Tired: the pretend guildie (U2; dt_selftest, R-F8-3 to R-F8-6). A debug-only stand-in for a
-- second player, so shared features can be walked alone.
--   Restless Ghost, on the reserved realm DTGHOST (key "DTGHOST-Restless Ghost").
--   /dt debug ghost on|off             answer your STASHQ, PREPQ and WHO for this session (never saved)
--   /dt debug ghost hello|death|gank|played|stash|prep|all   the ghost sends one message of that kind
-- A ghost message is built with Comms' own encode and handed to Comms' own inbound with the sender
-- string "Restless Ghost-DTGHOST": decoding, the key check and every handler run as for a real
-- message. It never reaches AceComm, ChatThrottleLib or SendAddonMessage. While one is delivered,
-- DT.send records and refuses (a ghost can never make DT talk to the guild), and the comms counters
-- are put back as they were.
-- Never saved (R-F8-5): DT.ghostPurge removes every saved entry naming DTGHOST, and the ghost from
-- Who's session list. Called by ghost off, PLAYER_LOGOUT, Migrate at every load, and the self-test.
-- The ghost only ever sends answer kinds and a HELLO without "login", so no handler is asked to reply.
local ADDON, ns = ...
local DT = ns.DT

local REALM = "DTGHOST"
local NAME = "Restless Ghost"
local KEY = REALM .. "-" .. NAME
local SENDER = NAME .. "-" .. REALM
local ANSWER_WAIT = 1
local DEPTH = 8

DT.GHOST = { realm = REALM, name = NAME, key = KEY, sender = SENDER }

local on = false                       -- this session only (R-F8-4)
local lastQ = {}                       -- [kind] = data of DT's last STASHQ/PREPQ/WHO, in memory

-- ---------------------------------------------------------------- the purge (R-F8-5)

local function has(s) return type(s) == "string" and s:find(REALM, 1, true) ~= nil end

-- A record in a list that names the ghost in any of its own fields (a death's who, a gank's by).
local function record(t)
  for k, v in pairs(t) do if has(k) or has(v) then return true end end
  return false
end

local function purge(t, depth)
  if depth > DEPTH then return 0 end
  local n = 0
  local len = #t
  for i = len, 1, -1 do                                                   -- lists: records naming the ghost
    local v = t[i]
    if has(v) or (type(v) == "table" and record(v)) then
      table.remove(t, i); n = n + 1
    elseif type(v) == "table" then
      n = n + purge(v, depth + 1)
    end
  end
  for k, v in pairs(t) do                                                 -- maps: entries keyed on, or naming, the ghost
    if not (type(k) == "number" and k >= 1 and k <= len) then
      if has(k) or has(v) then                                            -- guard: only entries naming DTGHOST
        t[k] = nil; n = n + 1
      elseif type(v) == "table" then
        n = n + purge(v, depth + 1)
      end
    end
  end
  return n
end

function DT.ghostPurge()
  local n = 0
  n = purge(DT.db(), 1)
  if DT.realmNames then DT.realmNames[REALM] = nil end
  local session = DT._who and DT._who.session and DT._who.session()
  if type(session) == "table" then
    for k in pairs(session) do if has(k) then session[k] = nil; n = n + 1 end end
    if DT.whoCount and DT.update then DT.update("who", "text", "DT: " .. DT.whoCount() .. " online") end
  end
  return n
end

-- ---------------------------------------------------------------- delivery (R-F8-3)

-- Deliver one ghost message through Comms' inbound. Returns ok, sends (the kinds a handler tried to
-- send while it ran: recorded, never sent), err.
function DT.ghostDeliver(kind, data)
  if not DT.isMember() then return false, {}, "not in the guild" end      -- guard: guild gate (ghost)
  local C = DT._comms
  local wire = C and C.encode(kind, data, KEY)
  if not wire then return false, {}, "could not encode" end
  local s = DT.db().comms
  local keep = { received = s.received, malformed = s.malformed, unknownVersion = s.unknownVersion,
    keyMismatch = s.keyMismatch, mismatches = #s.mismatches }
  local realSend, sends = DT.send, {}
  DT.send = function(k) sends[#sends + 1] = tostring(k); return false end -- guard: a ghost never makes DT send
  local ok, err = pcall(C.inbound, C.PREFIX, wire, "GUILD", SENDER)        -- guard: inbound only, never AceComm
  DT.send = realSend
  for k, v in pairs(keep) do if k ~= "mismatches" then s[k] = v end end   -- guard: comms counters left alone
  while #s.mismatches > keep.mismatches do table.remove(s.mismatches) end
  return ok, sends, err
end

-- ---------------------------------------------------------------- what the ghost says

local function myKey() return DT.myKey() end

local SAY = {
  hello = function() return "HELLO", { v = DT.VERSION, main = "", pl = "999999" } end,
  death = function() return "DEATH", { lvl = "13", zone = "The Barrens", hc = "0" } end,
  gank = function() return "GANK", { who = REALM .. "-Hapless Gnome", cls = "MAGE", lvl = "14", zone = "The Barrens" } end,
  played = function() return "PLAYED", { lvl = "13", h = "666.0" } end,
  stash = function()
    local q, me = lastQ.STASHQ, myKey()
    if not q or not me then return nil end
    return "STASH", { q = q.q, to = me, hits = "2589:20:" .. NAME }
  end,
  prep = function()
    local q, me = lastQ.PREPQ, myKey()
    if not q or not me then return nil end
    return "PREP", { q = q.q, to = me, ok = "1", short = "0" }
  end,
}
local ORDER = { "hello", "death", "gank", "played", "stash", "prep" }
DT._ghost = { SAY = SAY, ORDER = ORDER }

local function say(what)
  local kind, data = SAY[what]()
  if not kind then return false end
  return (DT.ghostDeliver(kind, data))
end

-- R-F8-4: answers while on. WHO gets a HELLO; STASHQ and PREPQ get an answer from the ghost.
local ANSWERS = { STASHQ = "stash", PREPQ = "prep", WHO = "hello" }
DT.listen("sent", function(kind, data)
  if not ANSWERS[kind] then return end
  if kind ~= "WHO" and type(data) == "table" then lastQ[kind] = { q = data.q } end
  if not on then return end                                               -- guard: answers only while on
  DT.after(ANSWER_WAIT, function()
    if on and DT.enabled("ghost") then say(ANSWERS[kind]) end
  end)
end)

-- ---------------------------------------------------------------- the verb

local function verb(args)
  if not DT.isMember() then return end
  if not DT.enabled("ghost") then return DT.out("ghost.enabled = off") end
  local w = (DT.trim(args) or ""):lower()
  if w == "on" then
    on = true                                                             -- guard: memory only, never saved
    return DT.out("The Restless Ghost is up. It answers your stash, prep and who until you say off.")
  elseif w == "off" then
    on = false
    DT.ghostPurge()
    return DT.out("The Restless Ghost is laid to rest. Nothing of it was kept.")
  elseif w == "all" then
    local n = 0
    for _, k in ipairs(ORDER) do if say(k) then n = n + 1 end end
    return DT.out("The Restless Ghost said " .. n .. " things.")
  elseif SAY[w] then
    if say(w) then return DT.out("The Restless Ghost: " .. w .. ".") end
    if w == "stash" then return DT.out("Ask first: /dt stash <item>.") end
    if w == "prep" then return DT.out("Ask first: /dt prep roll.") end
    return DT.out("The ghost couldn't say that.")
  end
  return DT.out("/dt debug ghost on|off|hello|death|gank|played|stash|prep|all")
end

DT.module({
  id = "ghost",
  title = "Ghost",
  optional = true,
  switchDesc = "A pretend guildie for testing. Off, /dt debug ghost does nothing.",
  verbs = { { verb = "debug ghost", usage = "debug ghost", fn = verb } },
  events = { PLAYER_LOGOUT = function() DT.ghostPurge() end },
  onDisable = function() on = false; DT.ghostPurge() end,
})

-- For the offline tests only.
DT._ghost.isOn = function() return on end
DT._ghost.lastQ = function() return lastQ end
