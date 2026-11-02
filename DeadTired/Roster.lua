-- Dead Tired: who runs the addon. The HELLO handshake and /dt who.
--
-- 10 s after the first PLAYER_ENTERING_WORLD of a login, a member sends HELLO {v, main} once.
-- A HELLO from someone not yet answered this session gets one HELLO back after 2-8 s, marked
-- r=1; a reply is never replied to, and nobody gets a second reply in a session, so two clients
-- settle after one exchange (HELLO, then one reply). The login HELLO is always a plain one, even
-- if a reply already went out, so a third client that only heard the reply still answers it. Everyone heard is kept in DeadTiredDB.roster[<guild>][<Realm-Name>].
-- Only guildies running the addon can ever show up: the list says so every time.
local ADDON, ns = ...
local DT = ns.DT

local HELLO_DELAY = 10
local REPLY_MIN, REPLY_SPREAD = 2, 6

local heard = {}          -- this session: [key] = DT.now() of the latest HELLO
local answered = {}       -- this session: [key] = true once a reply to them is scheduled
local loggedIn, loginSent, wantHello = false, false, false

local function store()
  local db = DT.db()
  local g = DT.guildKey() or "?"
  if type(db.roster[g]) ~= "table" then db.roster[g] = {} end
  return db.roster[g]
end
DT.roster = store

-- A key as people read it: the name alone on the player's own realm, Name-Realm elsewhere.
function DT.display(key)
  if type(key) ~= "string" or key == "" then return "?" end
  local name = DT.nameOf(key)
  local realm = key:sub(1, #key - #name - 1)
  local own = DT.clean(DT.try(GetRealmName))
  if realm == "" or realm == own then return DT.safe(name, 24) end
  return DT.safe(name .. "-" .. realm, 48)
end

-- Send HELLO (reply = true marks it r=1) and record this character in the roster as one of
-- the account's own.
function DT.hello(reply)
  if not DT.isMember() then return false end
  local main = DT.db().account.main or ""
  local me = DT.charKey()
  if me then store()[me] = { v = DT.VERSION, main = main, seen = DT.stamp(), mine = true } end
  local fields = { v = DT.VERSION, main = main }
  if reply then fields.r = "1" end
  return DT.send("HELLO", fields)
end

local function validKey(s) return s == "" or (#s <= 80 and s:match("^.+%-[^%-]+$") ~= nil) end

DT.on("HELLO", function(from, f)
  local v, main = f.v, f.main or ""
  if type(v) ~= "string" or v == "" or #v > 16 or not validKey(main) then
    local c = DT.db().comms
    c.badHello = (c.badHello or 0) + 1
    return
  end
  store()[from] = { v = v, main = main, seen = DT.stamp() }
  heard[from] = DT.now()
  if f.r == "1" then return end                 -- a reply is never replied to
  if answered[from] then return end             -- guard: reply-once
  answered[from] = true
  DT.after(REPLY_MIN + math.random() * REPLY_SPREAD, function() DT.hello(true) end)
end)

DT.listen("member", function(isMember)
  if isMember and wantHello and not loginSent then wantHello = false; loginSent = true; DT.hello() end
end)

local function sorted(keys)
  table.sort(keys, function(x, y) return DT.display(x):lower() < DT.display(y):lower() end)
  return keys
end

local function describe(key, e)
  local s = DT.display(key)
  if type(e) == "table" then
    if e.main == key then s = s .. " (main)"
    elseif type(e.main) == "string" and e.main ~= "" then s = s .. " (alt of " .. DT.display(e.main) .. ")" end
    if type(e.v) == "string" then s = s .. " " .. DT.safe(e.v, 16) end
  end
  return s
end

local SEEN_CAP = 20

function DT.who()
  local r, me = store(), DT.charKey()
  local now = {}
  for k in pairs(heard) do if k ~= me then now[#now + 1] = k end end
  sorted(now)
  if #now == 0 then
    DT.out("this session: nobody yet. Give the dead a minute to rise.")
  else
    local parts = {}
    for _, k in ipairs(now) do parts[#parts + 1] = describe(k, r[k]) end
    DT.out("this session (" .. #now .. "): " .. table.concat(parts, ", "))
  end
  local before = {}
  for k, e in pairs(r) do
    if not heard[k] and k ~= me and not (type(e) == "table" and e.mine) then before[#before + 1] = k end
  end
  sorted(before)
  if #before > 0 then
    local parts = {}
    for i = 1, math.min(#before, SEEN_CAP) do parts[#parts + 1] = describe(before[i], r[before[i]]) end
    local more = #before > SEEN_CAP and (" and " .. (#before - SEEN_CAP) .. " more") or ""
    DT.out("seen before (" .. #before .. "): " .. table.concat(parts, ", ") .. more)
  end
  DT.out("Only guildies running the addon show up here.")
end

-- For the offline tests only.
DT._roster = { heard = function() return heard end, answered = function() return answered end }

DT.module({
  id = "roster",
  init = function() DT.db() end,
  events = {
    PLAYER_ENTERING_WORLD = function()
      if loggedIn then return end
      loggedIn = true
      DT.after(HELLO_DELAY, function()
        if loginSent then return end
        if DT.isMember() then loginSent = true; DT.hello() else wantHello = true end
      end)
    end,
  },
  ready = DT.errors,
  errorKey = "roster", lastKey = "lastRoster",
  slash = { who = function() DT.who() end },
})
