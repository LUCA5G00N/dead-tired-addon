-- Dead Tired: character keys. Built here and nowhere else (rebuild requirement 1).
--
--   key = RealmKey .. "-" .. Full Name
--   RealmKey: the realm with spaces and hyphens removed (AUD-06): "CAMWOW EU4 Realm 2 PvP" ->
--             "CAMWOWEU4Realm2PvP", as GetNormalizedRealmName and CHAT_MSG_ADDON spell it.
--   Full Name: the name with its surname, as GetUnitName(unit, true) gives it on Forever
--             ("Stromham Hamson"), trimmed, inner runs of spaces made one. Case kept as given.
-- A realm key has no hyphen, so the first "-" in a key always ends the realm.
-- DT.display(key): the full name; the realm only to tell two same-named characters apart (R-P5).
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local function str(v)
  v = clean(v)
  if type(v) ~= "string" or v == "" then return nil end
  return v
end

-- The realm key. With no realm: the player's own (GetNormalizedRealmName, else GetRealmName).
function DT.realmKey(realm)
  if realm == nil then
    realm = str((try(GetNormalizedRealmName))) or str((try(GetRealmName)))
  end
  if type(realm) ~= "string" then return nil end
  realm = realm:gsub("[%s%-]", "")                                       -- guard: realm normalise (AUD-06)
  if realm == "" then return nil end
  return realm
end

-- A full name in the one spelling: trimmed, one space between parts, no "-Realm" suffix.
function DT.fullName(name)
  if type(name) ~= "string" then return nil end
  name = name:gsub("%-.*$", "")
  name = DT.trim(name:gsub("%s+", " "))
  if name == "" or name == "Unknown" or (UNKNOWNOBJECT and name == UNKNOWNOBJECT) then return nil end
  return name
end

function DT.keyOf(fullName, realm)
  local n = DT.fullName(clean(fullName))
  if not n then return nil end
  local r = DT.realmKey(realm)
  if not r then return nil end
  return r .. "-" .. n
end

-- realmKey, name of a key (nil, nil if it isn't one).
function DT.splitKey(key)
  if type(key) ~= "string" then return nil, nil end
  local r, n = key:match("^([^%-]+)%-(.+)$")
  return r, n
end

function DT.nameOf(key)
  local _, n = DT.splitKey(key)
  return n or "?"
end

-- Two keys for one character, ignoring case and spacing.
function DT.sameKey(a, b)
  if type(a) ~= "string" or type(b) ~= "string" then return false end
  local function norm(k) return (k:lower():gsub("%s+", " ")) end
  return norm(a) == norm(b)
end

-- The player's full name: GetUnitName("player", true) (with the surname on Forever), else UnitName.
-- nil until the client can name the character ("Unknown" on a cold login).
function DT.myName()
  return DT.fullName(str((try(GetUnitName, "player", true)))) or DT.fullName(str((try(UnitName, "player"))))
end

function DT.myKey()
  local n = DT.myName()
  if not n then return nil end
  return DT.keyOf(n)
end

-- Realm display names learnt from HELLOs (Who.lua): realmKey -> "CAMWOW EU4 Realm 4 PvP".
DT.realmNames = {}

-- The realm as people read it, for tooltips: the display name a HELLO taught us, else the key.
function DT.realmLabel(key)
  local r = DT.splitKey(key)
  if not r then return "?" end
  return DT.safe(DT.realmNames[r] or r, 40)
end

-- Every key DT knows of, for the collision rule when no shown set is given. Modules add a source:
-- DT.keySource(fn), fn() -> a table whose keys (or, for an array, whose values) are character keys.
DT.keySources = {}
function DT.keySource(fn) DT.keySources[#DT.keySources + 1] = fn end

function DT.knownKeys()
  local out, done = {}, {}
  local function add(k)
    if type(k) == "string" and DT.splitKey(k) and not done[k] then done[k] = true; out[#out + 1] = k end
  end
  for _, fn in ipairs(DT.keySources) do
    local ok, t = pcall(fn)
    if ok and type(t) == "table" then
      for k, v in pairs(t) do
        if type(k) == "number" then add(v) else add(k) end
      end
    end
  end
  add(DT.myKey())
  return out
end

-- R-P5 (Port 1, ruled 11 Nov): a name is shown as the full name only ("Vespera Grimm"); the realm
-- goes in the tooltip (DT.realmLabel). Only when two shown entries share a full name on different
-- realms do both get "(Realm)". Keys keep the realm.
-- DT.namer(keys) -> fn(key): the display of each key among that shown set.
function DT.namer(keys)
  local realms = {}                     -- lower full name -> { [lower realm] = true }, count
  for _, k in ipairs(keys or {}) do
    local r, n = DT.splitKey(k)
    if r then
      local ln = n:lower():gsub("%s+", " ")
      local e = realms[ln]
      if not e then e = { n = 0, seen = {} }; realms[ln] = e end
      local lr = r:lower()
      if not e.seen[lr] then e.seen[lr] = true; e.n = e.n + 1 end
    end
  end
  return function(key)
    local r, n = DT.splitKey(key)
    if not r then return DT.safe(key, 48) end
    local e = realms[n:lower():gsub("%s+", " ")]
    if e and e.n > 1 then                                                  -- guard: R-P5 collision
      return DT.safe(n, 48) .. " (" .. DT.realmLabel(key) .. ")"
    end
    return DT.safe(n, 48)
  end
end

-- DT.display(key [, among]): the full name; "(Realm)" added only on a collision among `among`
-- (the keys shown with it), or among every key DT knows of when `among` isn't given.
function DT.display(key, among)
  local list = among or DT.knownKeys()
  local found = false
  for _, k in ipairs(list) do if k == key then found = true break end end
  if not found then
    local copy = { key }
    for _, k in ipairs(list) do copy[#copy + 1] = k end
    list = copy
  end
  return DT.namer(list)(key)
end
