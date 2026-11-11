-- Dead Tired: the alt registry (card 1, ported from rc3's Alts.lua onto full-name keys in Port 1).
-- Honour system: nothing checks that alts belong to one person.
--
-- /dt main          this character is the account's main (DeadTiredDB.alts.main; the store is
--                   account-wide, so every character on the account reports the same main)
-- /dt main clear    no main
-- /dt alts [name]   a character's main and everyone sharing it; with no name, the player's own
-- The main travels in every HELLO (Who.lua, DT.helloField "main"); both main verbs send a fresh one.
-- The roster (DeadTiredDB.alts.roster[key] = { main, seen, mine, v }) holds every guildie heard
-- from and each of the account's own characters, under full-name keys (RealmKey-Full Name).
-- Port 1: names shown without realm (R-P5); a name typed with or without its realm, in either order
-- (rc3); the account's own short-name entry for this character (rc3 keyed its own characters by
-- UnitName) is folded into the full-name entry when this character logs in, exactly that one key,
-- never a guess (the legacy migration in Migrate.lua does the rest).
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local function store()
  local db = DT.db()
  if type(db.alts) ~= "table" then db.alts = {} end
  local a = db.alts
  if type(a.roster) ~= "table" then a.roster = {} end
  if a.main ~= nil and type(a.main) ~= "string" then a.main = nil end
  return a
end
DT.altsStore = store
function DT.roster() return store().roster end

-- ---------------------------------------------------------------- own entry

-- Newer `seen` (stamps "YYYY-MM-DD HH:MM:SS" compare as strings) wins; a missing one loses.
function DT.newerSeen(a, b)
  local sa = type(a) == "table" and a.seen or nil
  local sb = type(b) == "table" and b.seen or nil
  if type(sa) ~= "string" then return false end
  if type(sb) ~= "string" then return true end
  return sa > sb
end

-- Rewrite every pointer to `old` (each entry's main, the account's main) as `new`.
function DT.repointMain(old, new)
  local a = store()
  if a.main == old then a.main = new end
  for _, e in pairs(a.roster) do
    if type(e) == "table" and e.main == old then e.main = new end
  end
end

-- Merge roster entry `old` into `new` (newest seen wins; mine kept if either was mine).
function DT.mergeEntry(roster, old, new)
  local eo, en = roster[old], roster[new]
  roster[old] = nil
  if en == nil then roster[new] = eo
  elseif type(eo) == "table" and type(en) == "table" then
    local keep = DT.newerSeen(eo, en) and eo or en
    if eo.mine or en.mine then keep.mine = true end
    roster[new] = keep
  end
  DT.repointMain(old, new)
end

local function recordMe()
  local me = DT.myKey()
  if not me then return end
  local a = store()
  -- rc3 keyed this character by its short name: fold exactly that key into the full one.
  local short = DT.keyOf(clean((try(UnitName, "player"))))
  if short and short ~= me and type(a.roster[short]) == "table" and a.roster[short].mine then  -- guard: own short key only
    DT.mergeEntry(a.roster, short, me)
  end
  local e = a.roster[me]
  if type(e) ~= "table" then e = {}; a.roster[me] = e end
  e.mine, e.main, e.seen, e.v = true, a.main or "", DT.stamp(), DT.VERSION
end

local function setMain(key)
  local a = store()
  a.main = key
  for _, e in pairs(a.roster) do
    if type(e) == "table" and e.mine then e.main = key or "" end
  end
  recordMe()
  DT.sayHello()
end

-- ---------------------------------------------------------------- HELLO

DT.helloField("main", function() return store().main or "" end)

local function validMain(s) return s == "" or (type(s) == "string" and #s <= 80 and DT.splitKey(s) ~= nil) end

DT.on("HELLO", function(from, d)
  if not DT.enabled("who") then return end
  local main = d.main
  if main == nil then main = "" end
  if not validMain(main) then                                              -- guard: main validation
    local c = DT.db().comms
    c.badHello = (c.badHello or 0) + 1
    return
  end
  local r = store().roster
  local e = r[from]
  if type(e) ~= "table" then e = {}; r[from] = e end
  e.main, e.seen, e.v = main, DT.stamp(), type(d.v) == "string" and DT.safe(d.v, 16) or e.v
end)

-- ---------------------------------------------------------------- /dt alts

local function squash(s) return (tostring(s or ""):gsub("[%s%-]", ""):lower()) end
local function lowName(s) return (DT.fullName(s) or ""):lower() end

-- Roster keys matching `arg`: "Full Name", "Full Name-Realm" or "Realm-Full Name", case-insensitive.
local function find(arg)
  arg = DT.trim(arg) or ""
  local tries = { { name = lowName(arg) } }
  local n1, r1 = arg:match("^([^%-]+)%-(.+)$")          -- Name-Realm
  local r2, n2 = arg:match("^(.+)%-([^%-]+)$")          -- Realm-Name
  if n1 then
    tries = { { name = lowName(n1), realm = squash(r1) }, { name = lowName(n2), realm = squash(r2) } }
  end
  local hits, seen = {}, {}
  for key in pairs(store().roster) do
    local realm, name = DT.splitKey(key)
    if realm then
      for _, t in ipairs(tries) do
        if name:lower():gsub("%s+", " ") == t.name and (not t.realm or t.realm == realm:lower()) and not seen[key] then
          seen[key] = true
          hits[#hits + 1] = key
        end
      end
    end
  end
  table.sort(hits)
  return hits
end

local function list(keys, name)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = name(k) end
  return table.concat(parts, ", ")
end

local function group(main)
  local alts = {}
  for key, e in pairs(store().roster) do
    if type(e) == "table" and e.main == main and not DT.sameKey(key, main) then alts[#alts + 1] = key end
  end
  local shown = { main }
  for _, k in ipairs(alts) do shown[#shown + 1] = k end
  local name = DT.namer(shown)
  table.sort(alts, function(x, y) return name(x):lower() < name(y):lower() end)
  local who = name(main)
  if #alts == 0 then
    DT.out(who .. " is a main with no known alts.")
  else
    DT.out(who .. "'s lot: main " .. who .. "; alts (" .. #alts .. "): " .. list(alts, name) .. ".")
  end
end

function DT.alts(arg)
  if not arg or arg == "" then
    local main = store().main
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
    return DT.out("more than one " .. DT.safe(arg, 48) .. ": " .. list(hits, DT.namer(hits)) .. ". Add the realm.")
  end
  local key = hits[1]
  local e = store().roster[key]
  if type(e) ~= "table" or type(e.main) ~= "string" or e.main == "" then
    return DT.out(DT.display(key) .. " hasn't named a main. Alone in the dark.")
  end
  return group(e.main)
end

local function mainVerb(args)
  local rest = (args or ""):lower()
  if rest == "clear" then
    setMain(nil)
    return DT.out("main cleared. Everyone's an alt now.")
  elseif rest ~= "" then
    return DT.out("/dt main makes this character your main; /dt main clear forgets it.")
  end
  local me = DT.myKey()
  if not me then return DT.out("can't tell who you are yet. Try again in a moment.") end
  setMain(me)
  return DT.out(DT.display(me) .. " is now your main. The rest are just alts.")
end

DT.keySource(function() return store().roster end)

DT.module({
  id = "alts",
  title = "Alts",
  init = function() store() end,
  verbs = {
    { verb = "main", usage = "main [clear]", fn = mainVerb },
    { verb = "alts", usage = "alts [name]", fn = function(args) DT.alts(args) end },
  },
  events = {
    PLAYER_ENTERING_WORLD = function() if DT.isMember() then recordMe() end end,
  },
})
DT.listen("member", function(isMember) if isMember then recordMe() end end)

-- For the offline tests only.
DT._alts = { find = find, recordMe = recordMe }
