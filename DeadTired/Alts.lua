-- Dead Tired: the alt registry. Honour system: nothing checks that alts belong to one person.
--
-- /dt main          this character is the account's main (DeadTiredDB.account.main; the store is
--                   account-wide, so every character on the account reports the same main)
-- /dt main clear    no main
-- /dt alts [name]   a character's main and everyone sharing it; with no name, the player's own
-- Both main verbs send a fresh HELLO, which carries the main to the guild.
local ADDON, ns = ...
local DT = ns.DT

local function setMain(key)
  local db = DT.db()
  db.account.main = key
  for _, e in pairs(DT.roster()) do
    if type(e) == "table" and e.mine then e.main = key or "" end
  end
  DT.hello()
end

local function squash(s) return (s or ""):gsub("[%s%-]", ""):lower() end

-- Roster keys matching `arg`: "name", "name-realm" or "realm-name", case-insensitive.
local function find(arg)
  arg = arg:lower():gsub("^%s+", ""):gsub("%s+$", "")
  local tries = { { name = arg } }
  local n1, r1 = arg:match("^([^%-]+)%-(.+)$")          -- Name-Realm
  local r2, n2 = arg:match("^(.+)%-([^%-]+)$")          -- Realm-Name
  if n1 then tries = { { name = n1, realm = squash(r1) }, { name = n2, realm = squash(r2) } } end
  local hits, seen = {}, {}
  for key in pairs(DT.roster()) do
    local name = DT.nameOf(key)
    local realm = squash(key:sub(1, #key - #name - 1))
    for _, t in ipairs(tries) do
      if name:lower() == t.name and (not t.realm or t.realm == realm) and not seen[key] then
        seen[key] = true
        hits[#hits + 1] = key
      end
    end
  end
  table.sort(hits)
  return hits
end

local function list(keys)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = DT.display(k) end
  return table.concat(parts, ", ")
end

local function group(main)
  local alts = {}
  for key, e in pairs(DT.roster()) do
    if type(e) == "table" and e.main == main and key ~= main then alts[#alts + 1] = key end
  end
  table.sort(alts, function(x, y) return DT.display(x):lower() < DT.display(y):lower() end)
  local who = DT.display(main)
  if #alts == 0 then
    DT.out(who .. " is a main with no known alts.")
  else
    DT.out(who .. "'s lot: main " .. who .. "; alts (" .. #alts .. "): " .. list(alts) .. ".")
  end
end

function DT.alts(arg)
  if not arg or arg == "" then
    local main = DT.db().account.main
    if type(main) ~= "string" or main == "" then
      return DT.out("you haven't named a main. /dt main on the one you love most.")
    end
    return group(main)
  end
  local hits = find(arg)
  if #hits == 0 then
    return DT.out("no " .. DT.safe(arg, 48) .. " in the crypt. Only guildies running the addon are known.")
  end
  if #hits > 1 then
    return DT.out("more than one " .. DT.safe(arg, 48) .. ": " .. list(hits) .. ". Add the realm.")
  end
  local key = hits[1]
  local e = DT.roster()[key]
  if type(e.main) ~= "string" or e.main == "" then
    return DT.out(DT.display(key) .. " hasn't named a main. Alone in the dark.")
  end
  return group(e.main)
end

local function main(msg)
  local rest = msg:match("^main%s+(.-)%s*$")
  if rest == "clear" then
    setMain(nil)
    return DT.out("main cleared. Everyone's an alt now.")
  elseif rest and rest ~= "" then
    return DT.out("/dt main makes this character your main; /dt main clear forgets it.")
  end
  local me = DT.charKey()
  if not me then return DT.out("can't tell who you are yet. Try again in a moment.") end
  setMain(me)
  return DT.out(DT.display(me) .. " is now your main. The rest are just alts.")
end

DT.module({
  id = "alts",
  init = function() DT.db() end,
  ready = DT.errors,
  errorKey = "alts", lastKey = "lastAlts",
})
DT.verb("main", main, "main [clear]")
DT.verb("alts", function(msg)
  local raw = (DT.raw or msg):match("^%S+%s+(.+)$")
  return DT.alts(raw)
end, "alts [name]")
