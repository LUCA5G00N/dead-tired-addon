-- Offline checks for Migrate.lua: the legacy move (Port 1), on a fixture built from Tim's real rc3
-- shape. Evidence for the shape: the rc3 walk (docs/UAT_dt_fixes3_results.md, H3/H4, 10 Nov):
-- `/dt alts` on Stromham gave "main Stromham; alts (5): Gizzardthe, Jobbi, Marvella, St, Stromham
-- Hamson" (rc3 keyed the account's own characters by the short name, UnitName, and its own HELLO
-- echo by the full name), and "Lilbit High" (CAMWOW EU4 Realm 4 PvP) was heard as a sender without
-- a realm, so rc3 filed him under Realm 2. rc3's store: roster[<guild>][key], account.main,
-- crypt[<guild>].deaths + rip/share/bedtime/hcTold, prep.share/recruitNext/recruitAt/recruitNudge,
-- keysV = 2 (fix round 3's realm spelling).  lua5.1 DeadTired/tests/test_migrate.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local R2, R4 = "CAMWOW EU4 Realm 2 PvP", "CAMWOW EU4 Realm 4 PvP"
local K2 = "CAMWOWEU4Realm2PvP-"

-- A stable dump of a table, to prove legacy is untouched.
local function dump(v, seen)
  if type(v) ~= "table" then return type(v) .. ":" .. tostring(v) end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local out = {}
  for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. dump(v[k]) end
  return "{" .. table.concat(out, ",") .. "}"
end

-- rc3's DeadTiredDB as Tim's was (no schema field: the framework moves it under legacy).
local function timRc3()
  return {
    keysV = 2, welcome = true, errors = {}, comms = { dropped = 0, unknownVersion = 0, malformed = 0, stale = 0 },
    account = { main = K2 .. "Stromham" },
    roster = { ["dead tired"] = {
      [K2 .. "Stromham"]        = { v = "0.1.0", main = K2 .. "Stromham", seen = "2026-11-10 11:17:00", mine = true },
      [K2 .. "Stromham Hamson"] = { v = "0.1.0", main = K2 .. "Stromham", seen = "2026-11-10 11:18:45" },
      [K2 .. "Gizzardthe"]      = { v = "0.1.0", main = K2 .. "Stromham", seen = "2026-11-06 19:23:00", mine = true },
      [K2 .. "Jobbi"]           = { v = "0.1.0", main = K2 .. "Stromham", seen = "2026-11-07 00:03:00", mine = true },
      [K2 .. "Marvella"]        = { v = "0.1.0", main = K2 .. "Stromham", seen = "2026-11-07 00:00:00", mine = true },
      [K2 .. "St"]              = { v = "0.1.0", main = K2 .. "Stromham", seen = "2026-11-09 21:00:00", mine = true },
      [K2 .. "Lilbit High"]     = { v = "0.1.0", main = "", seen = "2026-11-10 11:18:12" },   -- really on Realm 4
    } },
    crypt = { rip = true, share = true, bedtime = "23:30", keysV = 2, badDeath = 0,
      hcTold = { [K2 .. "Jobbi"] = true, [K2 .. "Lilbit High"] = true },
      ["dead tired"] = { deaths = {
        { who = K2 .. "Jobbi", lvl = 1, zone = "Zephras Isle", hc = true, at = "2026-11-07 00:03:10", mine = true },
        { who = K2 .. "Lilbit High", lvl = 9, zone = "Durotar", hc = false, at = "2026-11-09 20:00:00", mine = false },
        { who = K2 .. "Stromham", lvl = 14, zone = "The Barrens", hc = false, at = "2026-11-09 21:00:00", mine = true },
      } } },
    prep = { share = true, badPrep = 0, recruitNext = 2, recruitAt = 1794000000 - 3600, recruitNudge = false },
  }
end

-- The fw1 store over it: what Tim's SavedVariables holds today (fw1 moved rc3 under legacy).
local function timFw1()
  return { schema = 3, legacy = timRc3(), legacySaid = true, barIntroSaid = true,
    who = { seen = { ["CAMWOWEU4Realm4PvP-Lilbit High"] = { v = "0.2.0-fw1", rn = R4 },
                     [K2 .. "Echo Nightclaw"] = { v = "0.2.0-fw1" } } } }
end

local function mk(w, o)
  o.guild = o.guild or G
  o.realm = o.realm or R2
  o.random = function() return 0.5 end
  return w:client(o)
end

-- ---------------------------------------------------------------- Tim logs in on Stromham
local w = H.world()
local db = timFw1()
local snap = dump(db.legacy)
local tim = mk(w, { name = "Stromham", full = "Stromham Hamson", db = db })
tim:login()
local D = tim:db()
local roster = D.alts.roster
check("runs once: migrated.port1 set", D.migrated.port1 == true)
check("legacy untouched", dump(D.legacy) == snap)
check("merge: the short key with exactly one full key on its realm merges into it", roster[K2 .. "Stromham"] == nil
  and roster[K2 .. "Stromham Hamson"] ~= nil)
check("merge: newest seen wins, and it stays one of the account's own", roster[K2 .. "Stromham Hamson"].mine == true
  and (roster[K2 .. "Stromham Hamson"].seen >= "2026-11-10 11:18:45"))
check("merge: every main and the account's main follow", D.alts.main == K2 .. "Stromham Hamson"
  and roster[K2 .. "Jobbi"].main == K2 .. "Stromham Hamson" and roster[K2 .. "St"].main == K2 .. "Stromham Hamson")
check("unmatched: short keys with no full key are kept as they are", roster[K2 .. "Gizzardthe"] and roster[K2 .. "Jobbi"]
  and roster[K2 .. "Marvella"] and roster[K2 .. "St"])
check("unmatched: counted (Gizzardthe, Jobbi, Marvella, St)", D.migrated.unmatched == 4)
check("the merge count", D.migrated.mapped == 1)
tim:slash("alts")
check("/dt alts: the main once, each alt once, no short/full doubles",
  tim:said("Stromham Hamson's lot: main Stromham Hamson; alts (4): Gizzardthe, Jobbi, Marvella, St.") ~= nil)
check("crypt: the graveyard moved, keys rewritten", #D.crypt.deaths == 3 and D.crypt.deaths[1].who == K2 .. "Jobbi"
  and D.crypt.deaths[3].who == K2 .. "Stromham Hamson")
check("crypt: settings moved (rip, share, bedtime)", tim.DT.get("crypt", "rip") == true and tim.DT.get("crypt", "share") == true
  and tim.DT.get("crypt", "bedtime") == "23:30")
check("crypt: hcTold moved", D.crypt.hcTold[K2 .. "Jobbi"] == true)
check("recruit: next line, last post time and the nudge moved", D.recruit.next == 2 and D.recruit.at == 1794000000 - 3600
  and tim.DT.get("recruit", "nudge") == false)
check("prep: roll-call sharing moved", tim.DT.get("prep", "share") == true)
check("the connected-realm guildie stays under Realm 2 until a HELLO says otherwise (never guessed)",
  roster[K2 .. "Lilbit High"] ~= nil and roster[K2 .. "Lilbit High"].fromLegacy == true and roster["CAMWOWEU4Realm4PvP-Lilbit High"] == nil)

-- Lilbit logs in on Realm 4: his HELLO supplies the realm.
local lil = mk(w, { name = "Lilbit", full = "Lilbit High", realm = R4 })
lil:login(); w:advance(20)
check("refile: a current HELLO moves the entry to its real realm", roster[K2 .. "Lilbit High"] == nil
  and roster["CAMWOWEU4Realm4PvP-Lilbit High"] ~= nil and D.migrated.refiled == 1)
check("refile: the deaths and the hcTold record follow", D.crypt.deaths[2].who == "CAMWOWEU4Realm4PvP-Lilbit High"
  and D.crypt.hcTold["CAMWOWEU4Realm4PvP-Lilbit High"] == true and D.crypt.hcTold[K2 .. "Lilbit High"] == nil)
check("refile: legacy still untouched", dump(D.legacy) == snap)

-- St Ham logs in on 0.2.0: his own short key folds into his full key (Alts.lua at login).
local st = mk(w, { name = "St", full = "St Ham", db = D })
st:login(); w:advance(20)
check("St Ham's first login: the short St entry folds into St Ham", roster[K2 .. "St"] == nil and roster[K2 .. "St Ham"].mine == true)
st:slash("alts")
check("/dt alts then: St Ham once, no St", st:said("alts (4): Gizzardthe, Jobbi, Marvella, St Ham.") ~= nil)

-- Runs once. After it, the player's own changes stand: a second load must not copy legacy again.
roster[K2 .. "Stromham"] = { main = "", seen = "x" }
roster[K2 .. "Gizzardthe"] = nil                       -- gone since (say, deleted)
local nDeaths = #D.crypt.deaths
D.settings.crypt.bedtime = "off"
local again = mk(w, { name = "Stromham", full = "Stromham Hamson", db = D })
again:login()
check("runs once: a second load doesn't migrate again", roster[K2 .. "Stromham"] ~= nil and D.migrated.port1 == true
  and dump(D.legacy) == snap)
check("runs once: nothing copied twice (no second set of legacy deaths, no entry brought back, no setting reset)",
  #D.crypt.deaths == nDeaths and roster[K2 .. "Gizzardthe"] == nil and again.DT.get("crypt", "bedtime") == "off")

-- ---------------------------------------------------------------- the exactly-one rule
do
  local map, unmatched = tim.DT.migrationMap({
    ["R2-St"] = true, ["R2-St Ham"] = true, ["R2-St Hamish"] = true,     -- two full keys start "St ": no merge
    ["R2-Jo"] = true, ["R2-Jobbi Bones"] = true,                          -- "Jo " is no prefix of "Jobbi Bones"
    ["R2-Echo"] = true, ["R4-Echo Nightclaw"] = true,                     -- another realm doesn't count
    ["R2-Vex"] = true, ["R2-vex grimm"] = true,                           -- case-insensitive
  })
  check("exactly one: two full keys starting with the short name: kept, counted", map["R2-St"] == nil)
  check("exactly one: a prefix without the space is no match", map["R2-Jo"] == nil)
  check("exactly one: only the same realm", map["R2-Echo"] == nil)
  check("exactly one: case-insensitive", map["R2-Vex"] == "R2-vex grimm")
  check("exactly one: the unmatched count", unmatched == 3)
end

-- ---------------------------------------------------------------- straight from rc3 (no fw1 in between)
do
  local w2 = H.world()
  local rc3 = timRc3()
  local c = mk(w2, { name = "Stromham", full = "Stromham Hamson", db = rc3 })
  c:login()
  local d = c:db()
  check("from rc3 directly: rc3 moved under legacy, then migrated", d.legacy == rc3 and d.migrated.port1 == true
    and d.alts.main == K2 .. "Stromham Hamson" and d.migrated.unmatched == 4)
  check("from rc3 directly: the old-records line said once", c:count("Your old crypt records are kept for the move.") == 1)
end

-- ---------------------------------------------------------------- nothing to move
do
  local w2 = H.world()
  local c = mk(w2, { name = "New", full = "New Bones" })
  c:login()
  check("a fresh account: marked done, nothing moved", c:db().migrated.port1 == true and c:db().migrated.unmatched == 0
    and next(c:db().alts.roster) ~= nil)
end

-- ---------------------------------------------------------------- an existing entry merges, newest wins
do
  local w2 = H.world()
  local d = timFw1()
  d.alts = { roster = { [K2 .. "Stromham Hamson"] = { main = "", seen = "2026-11-11 09:00:00", mine = true } } }
  local c = mk(w2, { name = "Stromham", full = "Stromham Hamson", db = d })
  c:login()
  check("an entry already in the new store: merged, the newest seen kept", c:db().alts.roster[K2 .. "Stromham Hamson"].seen >= "2026-11-11 09:00:00"
    and c:db().migrated.merged >= 1)
end

H.finish("migrate")
