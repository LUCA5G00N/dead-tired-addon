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
--
-- PORT 2 (cards 4 and 6, and card 7's settings), once per account (DeadTiredDB.migrated.port2 =
-- true), keys by the same rule (the exactly-one short -> full merge, realm normalised):
--   gank:    legacy.gank[<guild>].logs -> gank.logs (who and by re-keyed; older than any new log;
--            capped at 500, oldest dropped)
--   played:  legacy.played[<guild>][key] -> played.board (on a key both hold, the newer t wins);
--            legacy.played.share -> settings.played.share
--   stash:   legacy.stash.chars[key] -> stash.chars (on a key both hold, the new store's lists stay,
--            the legacy bank list only fills an empty one); legacy.stash.share -> settings.stash.share
--   events:  legacy.events.remind -> settings.events.remind
--   logs:    legacy.logs.ask / .login -> settings.logs.ask / .login (the visit in progress is not
--            carried: it belongs to a session)
-- A setting already set in the new store is not overwritten.
--
-- FIX ROUND 4 (R-F4-4), once per account (DeadTiredDB.migrated.skin031 = true): a saved skin of
-- "deadtired", or none, becomes "clean" (the new default); "forever" is left alone. Silent. It
-- writes settings.core.skin and its own flag, nothing else.
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

-- ---------------------------------------------------------------- Port 2

-- Every character key the cards 4 and 6 legacy stores name.
local function legacyKeys2(L)
  local keys = {}
  local function add(k) k = norm(k) if k then keys[k] = true end end
  for _, g in pairs(type(L.gank) == "table" and L.gank or {}) do
    if type(g) == "table" and type(g.logs) == "table" then
      for _, e in ipairs(g.logs) do if type(e) == "table" then add(e.who); add(e.by) end end
    end
  end
  for k, b in pairs(type(L.played) == "table" and L.played or {}) do
    if type(k) == "string" and type(b) == "table" then for key in pairs(b) do add(key) end end
  end
  local st = type(L.stash) == "table" and L.stash or {}
  for key in pairs(type(st.chars) == "table" and st.chars or {}) do add(key) end
  return keys
end

local function run2()
  local db = DT.db()
  if type(db.migrated) ~= "table" then db.migrated = {} end
  local M = db.migrated
  if M.port2 then return false end                                       -- guard: Port 2 migration runs once
  local L = db.legacy
  M.port2 = true
  M.port2At = DT.stamp()
  if type(L) ~= "table" then M.port2Unmatched = 0; return true end

  local keys = legacyKeys2(L)
  local map, unmatched = DT.migrationMap(keys, DT.knownKeys())
  local function key(k)
    local n = norm(k)
    if not n then return nil end
    return map[n] or n
  end
  local S = db.settings
  local function put(id, k, v)
    if v == nil then return end
    if type(S[id]) ~= "table" then S[id] = {} end
    if S[id][k] == nil then S[id][k] = v end
  end

  -- gank: the legacy logs first (they are older), then any made since; the newest 500 kept
  local g, LG = DT.gankStore(), type(L.gank) == "table" and L.gank or {}
  local old = {}
  for _, t in pairs(LG) do
    if type(t) == "table" and type(t.logs) == "table" then
      for _, e in ipairs(t.logs) do
        if type(e) == "table" and type(e.who) == "string" then
          local ne = copy(e)
          ne.who = key(e.who) or e.who
          if type(e.by) == "string" then ne.by = key(e.by) or e.by end
          old[#old + 1] = ne
        end
      end
    end
  end
  for _, e in ipairs(g.logs) do old[#old + 1] = e end
  while #old > 500 do table.remove(old, 1) end
  g.logs = old

  -- played: the board, and the share setting
  local LP = type(L.played) == "table" and L.played or {}
  local b = DT.playedBoard()
  local merged = 0
  for gk, t in pairs(LP) do
    if type(gk) == "string" and type(t) == "table" then
      for k, e in pairs(t) do
        local nk = key(k)
        if nk and type(e) == "table" then
          local cur = b[nk]
          if cur == nil then b[nk] = copy(e)
          else
            merged = merged + 1
            if type(e.t) == "number" and (type(cur.t) ~= "number" or e.t > cur.t) then b[nk] = copy(e) end
          end
        end
      end
    end
  end
  if type(LP.share) == "boolean" then put("played", "share", LP.share) end

  -- stash: each character's lists, and the share setting
  local LS = type(L.stash) == "table" and L.stash or {}
  local chars = DT.stash().chars
  for k, e in pairs(type(LS.chars) == "table" and LS.chars or {}) do
    local nk = key(k)
    if nk and type(e) == "table" then
      local cur = chars[nk]
      if cur == nil then chars[nk] = copy(e)
      else
        merged = merged + 1
        if (type(cur.bank) ~= "table" or next(cur.bank) == nil) and type(e.bank) == "table" then
          cur.bank, cur.bankAt = copy(e.bank), e.bankAt
        end
      end
    end
  end
  if type(LS.share) == "boolean" then put("stash", "share", LS.share) end

  -- events and logs settings
  local LE = type(L.events) == "table" and L.events or {}
  if type(LE.remind) == "boolean" then put("events", "remind", LE.remind) end
  local LL = type(L.logs) == "table" and L.logs or {}
  if type(LL.ask) == "boolean" then put("logs", "ask", LL.ask) end
  if type(LL.login) == "boolean" then put("logs", "login", LL.login) end

  M.port2Unmatched = unmatched
  M.port2Merged = merged
  M.port2Mapped = 0
  for _ in pairs(map) do M.port2Mapped = M.port2Mapped + 1 end
  return true
end
DT.migratePort2 = run2

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

local function run3()
  local db = DT.db()
  if type(db.migrated) ~= "table" then db.migrated = {} end
  local M = db.migrated
  if M.skin031 then return false end                                     -- guard: the skin move runs once
  M.skin031 = true
  local core = db.settings.core
  local cur = type(core) == "table" and core.skin or nil
  if cur == nil or cur == "deadtired" then                               -- guard: forever left alone
    if type(core) ~= "table" then core = {}; db.settings.core = core end
    core.skin = "clean"
    DT.restyle()
  end
  return true
end
DT.migrateSkin = run3

DT.module({
  id = "migrate",
  title = "Legacy move",
  init = function() run(); run2(); run3() end,
})
