-- Dead Tired: the legacy move (Port 1). rc3's DeadTiredDB was put, untouched, under
-- DeadTiredDB.legacy by the framework (Core.lua). Once per account (DeadTiredDB.migrated.port1 =
-- true) the data of the ported cards is copied out of it into the new stores:
--   roster / alts:  legacy.roster[<guild>][key] = { v, main, seen, mine } -> alts.roster, and
--                   legacy.account.main -> alts.main
--   crypt:          legacy.crypt[<guild>].deaths -> crypt.deaths; rip, share, bedtime ->
--                   settings.crypt; hcTold -> crypt.hcTold
--   recruit:        legacy.prep.recruitNext / recruitAt / recruitNudge -> recruit.next / .at and
--                   settings.recruit.nudge
--   prep:           legacy.prep.share -> settings.prep.share
-- KEYS. Every key becomes RealmKey-Full Name (realm normalised, AUD-06). rc3 keyed its own
-- characters by the short name (UnitName) and heard guildies by the full name, so one character
-- can have both. A short-name key merges into the full-name key of the same realm only when
-- exactly ONE full-name key (among the legacy keys and the keys already in the new stores) starts
-- with that short name plus a space; otherwise it is kept as it is and counted in
-- migrated.unmatched. On a merge the newest `seen` wins. rc3 also filed a connected-realm guildie
-- under the local realm; that entry is marked fromLegacy and moved to its real realm only when a
-- current HELLO from that full name supplies one (never guessed; counted in migrated.refiled).
-- legacy itself is never written: everything is copied.
local ADDON, ns = ...
local DT = ns.DT

local function copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[copy(k)] = copy(x) end
  return t
end

local function norm(key)
  local r, n = DT.splitKey(key)
  if not r then return nil end
  local rk, fn = DT.realmKey(r), DT.fullName(n)
  if not rk or not fn then return nil end
  return rk .. "-" .. fn
end

local function isShort(key)
  local _, n = DT.splitKey(key)
  return n ~= nil and not n:find(" ", 1, true)
end

-- Every character key the legacy store names.
local function legacyKeys(L)
  local keys = {}
  local function add(k) k = norm(k) if k then keys[k] = true end end
  for _, g in pairs(type(L.roster) == "table" and L.roster or {}) do
    if type(g) == "table" then
      for k, e in pairs(g) do add(k); if type(e) == "table" then add(e.main) end end
    end
  end
  if type(L.account) == "table" then add(L.account.main) end
  local c = type(L.crypt) == "table" and L.crypt or {}
  for _, g in pairs(c) do
    if type(g) == "table" and type(g.deaths) == "table" then
      for _, e in ipairs(g.deaths) do if type(e) == "table" then add(e.who) end end
    end
  end
  for k in pairs(type(c.hcTold) == "table" and c.hcTold or {}) do add(k) end
  return keys
end

-- The short -> full map, by the rule above. Returns map (old key -> new key), unmatched count.
function DT.migrationMap(keys, more)
  local fulls = {}
  local function addFull(k)
    k = norm(k)
    if k and not isShort(k) then fulls[k] = true end
  end
  for k in pairs(keys) do addFull(k) end
  for _, k in ipairs(more or {}) do addFull(k) end
  local map, unmatched = {}, 0
  for k in pairs(keys) do
    if isShort(k) then
      local r, n = DT.splitKey(k)
      local want, hit, hits = n:lower() .. " ", nil, 0
      for f in pairs(fulls) do
        local fr, fn = DT.splitKey(f)
        if fr == r and fn:lower():sub(1, #want) == want then hit = f; hits = hits + 1 end
      end
      if hits == 1 then map[k] = hit                                      -- guard: exactly one full key
      else unmatched = unmatched + 1 end
    end
  end
  return map, unmatched
end

local function run()
  local db = DT.db()
  if type(db.migrated) ~= "table" then db.migrated = {} end
  local M = db.migrated
  if M.port1 then return false end                                       -- guard: migration runs once
  local L = db.legacy
  M.port1 = true
  M.at = DT.stamp()
  if type(L) ~= "table" then M.unmatched = 0; M.merged = 0; return true end

  local keys = legacyKeys(L)
  local more = DT.knownKeys()
  local map, unmatched = DT.migrationMap(keys, more)
  local function key(k)
    local n = norm(k)
    if not n then return nil end
    return map[n] or n
  end
  local merged = 0

  -- roster and mains
  local alts = DT.altsStore()
  local roster = alts.roster
  for _, g in pairs(type(L.roster) == "table" and L.roster or {}) do
    if type(g) == "table" then
      for k, e in pairs(g) do
        local nk = key(k)
        if nk and type(e) == "table" then
          local ne = copy(e)
          ne.main = (type(e.main) == "string" and e.main ~= "") and (key(e.main) or e.main) or ""
          if not ne.mine then ne.fromLegacy = true end
          local old = roster[nk]
          if old == nil then roster[nk] = ne
          else
            merged = merged + 1
            local keep = DT.newerSeen(ne, old) and ne or old
            if ne.mine or old.mine then keep.mine = true; keep.fromLegacy = nil end
            roster[nk] = keep
          end
        end
      end
    end
  end
  if alts.main == nil and type(L.account) == "table" and type(L.account.main) == "string" and L.account.main ~= "" then
    alts.main = key(L.account.main)
  end

  -- crypt
  local c, LC = DT.crypt(), type(L.crypt) == "table" and L.crypt or {}
  local old = {}
  for _, g in pairs(LC) do
    if type(g) == "table" and type(g.deaths) == "table" then
      for _, e in ipairs(g.deaths) do
        if type(e) == "table" then
          local ne = copy(e)
          ne.who = key(e.who) or e.who
          old[#old + 1] = ne
        end
      end
    end
  end
  for _, e in ipairs(c.deaths) do old[#old + 1] = e end
  while #old > 100 do table.remove(old, 1) end
  c.deaths = old
  for k, v in pairs(type(LC.hcTold) == "table" and LC.hcTold or {}) do
    local nk = key(k)
    if nk and v then c.hcTold[nk] = true end
  end
  local S = db.settings
  local function put(id, k, v)
    if v == nil then return end
    if type(S[id]) ~= "table" then S[id] = {} end
    if S[id][k] == nil then S[id][k] = v end
  end
  if type(LC.rip) == "boolean" then put("crypt", "rip", LC.rip) end
  if type(LC.share) == "boolean" then put("crypt", "share", LC.share) end
  if type(LC.bedtime) == "string" and LC.bedtime:match("^%d%d:%d%d$") then put("crypt", "bedtime", LC.bedtime) end

  -- recruit and prep
  local LP = type(L.prep) == "table" and L.prep or {}
  local r = DT.db().recruit
  if type(r) ~= "table" then r = {}; DT.db().recruit = r end
  if r.next == nil and type(LP.recruitNext) == "number" then r.next = LP.recruitNext end
  if r.at == nil and type(LP.recruitAt) == "number" then r.at = LP.recruitAt end
  if LP.recruitNudge == false then put("recruit", "nudge", false) end
  if type(LP.share) == "boolean" then put("prep", "share", LP.share) end

  M.unmatched = unmatched
  M.merged = merged
  M.mapped = 0
  for _ in pairs(map) do M.mapped = M.mapped + 1 end
  return true
end
DT.migratePort1 = run

-- The connected-realm refile: a HELLO from Realm'-Full Name, while the roster holds the same full
-- name under our own realm marked fromLegacy, moves that entry (and its deaths, its hcTold record
-- and every main pointing at it) to the key the HELLO supplied.
DT.on("HELLO", function(from)
  local fr, fn = DT.splitKey(from)
  local mine = DT.realmKey()
  if not fr or not mine or fr == mine then return end
  local old = mine .. "-" .. fn
  local roster = DT.altsStore().roster
  local e = roster[old]
  if type(e) ~= "table" or not e.fromLegacy or e.mine then return end      -- guard: refile only from a HELLO
  e.fromLegacy = nil
  DT.mergeEntry(roster, old, from)
  for _, d in ipairs(DT.crypt().deaths) do if type(d) == "table" and d.who == old then d.who = from end end
  local told = DT.crypt().hcTold
  if told[old] then told[old] = nil; told[from] = true end
  local M = DT.db().migrated
  if type(M) == "table" then M.refiled = (M.refiled or 0) + 1 end
end)

DT.module({
  id = "migrate",
  title = "Legacy move",
  init = function() run() end,
})
