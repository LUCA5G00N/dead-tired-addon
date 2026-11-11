-- Dead Tired: character keys. Built here and nowhere else (rebuild requirement 1).
--
--   key = RealmKey .. "-" .. Full Name
--   RealmKey: the realm with spaces and hyphens removed (AUD-06): "CAMWOW EU4 Realm 2 PvP" ->
--             "CAMWOWEU4Realm2PvP", as GetNormalizedRealmName and CHAT_MSG_ADDON spell it.
--   Full Name: the name with its surname, as GetUnitName(unit, true) gives it on Forever
--             ("Stromham Hamson"), trimmed, inner runs of spaces made one. Case kept as given.
-- A realm key has no hyphen, so the first "-" in a key always ends the realm.
-- DT.display(key): the name alone on your own realm, else "Name (Realm)".
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

function DT.display(key)
  local r, n = DT.splitKey(key)
  if not r then return DT.safe(key, 48) end
  local mine = DT.realmKey()
  if mine and r:lower() == mine:lower() then return DT.safe(n, 48) end
  return DT.safe(n, 48) .. " (" .. DT.safe(DT.realmNames[r] or r, 40) .. ")"
end
