-- Offline checks for Alts.lua (card 1's alt registry, ported from rc3 in Port 1): rc3's checks,
-- re-pointed to full-name keys (RealmKey-Full Name), the main carried in HELLO, names without realm
-- (R-P5), the own short-name entry folded at login.  lua5.1 DeadTired/tests/test_alts.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local R2 = "CAMWOW EU4 Realm 2 PvP"
local function half() return 0.5 end

local function lastHello(c)
  for i = #c.sent, 1, -1 do
    local ok, p = c.DT._comms.decode(c.sent[i].text)
    if ok == "ok" and p.k == "HELLO" then return p.d end
  end
end

local w = H.world()
local timDB = nil
-- The guildie, on another account, online throughout.
local pal = w:client({ name = "Echo", full = "Echo Nightclaw", realm = R2, guild = G, random = half })
pal:login(); w:advance(30)

-- Tim on Stromham.
local strom = w:client({ name = "Stromham", full = "Stromham Hamson", realm = R2, guild = G, random = half })
strom:login(); w:advance(30)
timDB = strom:db()
strom:slash("alts")
check("no main yet: /dt alts says so", strom:said("you haven't named a main. /dt main on the one you love most.") ~= nil)
local n0 = #strom.sent
strom:slash("main")
check("/dt main sets the account's main, on the full-name key", timDB.alts.main == "CAMWOWEU4Realm2PvP-Stromham Hamson"
  and strom:said("Stromham Hamson is now your main. The rest are just alts.") ~= nil)
w:advance(1)
check("/dt main sends a fresh HELLO carrying the main", #strom.sent == n0 + 1
  and lastHello(strom).main == "CAMWOWEU4Realm2PvP-Stromham Hamson")
w:advance(30)
check("the guildie stores Stromham's main", pal.DT.roster()["CAMWOWEU4Realm2PvP-Stromham Hamson"].main == "CAMWOWEU4Realm2PvP-Stromham Hamson")
strom:logout()

-- Tim logs an alt on the same account: same SavedVariables, so the same main.
local alt = w:client({ name = "St", full = "St Ham", realm = R2, guild = G, random = half, db = timDB })
alt:login(); w:advance(30)
check("the alt's login HELLO reports the account's main", lastHello(alt).main == "CAMWOWEU4Realm2PvP-Stromham Hamson")
check("the alt is in the account's roster as one of its own, on its full key", timDB.alts.roster["CAMWOWEU4Realm2PvP-St Ham"].mine == true
  and timDB.alts.roster["CAMWOWEU4Realm2PvP-St Ham"].main == "CAMWOWEU4Realm2PvP-Stromham Hamson")
pal:slash("alts St Ham")
check("/dt alts <alt> on the other side names Stromham as main and the alt in the group",
  pal:said("Stromham Hamson's lot: main Stromham Hamson; alts (1): St Ham.") ~= nil)
pal:slash("alts st ham-camwoweu4realm2pvp")
check("name is case-insensitive, realm optional (Name-Realm)", pal:said("alts (1): St Ham") ~= nil)
pal:slash("alts CAMWOW EU4 Realm 2 PvP-ST HAM")
check("...or Realm-Name, the realm with spaces", pal:said("alts (1): St Ham") ~= nil)
pal:slash("alts stromham hamson")
check("/dt alts <main> prints the same group", pal:said("Stromham Hamson's lot: main Stromham Hamson; alts (1): St Ham.") ~= nil)
pal:slash("alts Nobody")
check("an unknown name says only addon users are known", pal:said("no Nobody in the crypt. Only guildies running the addon are known.") ~= nil)
pal:slash("alts St Ham-Nethergarde")
check("a wrong realm is not a match", pal:said("no St Ham-Nethergarde in the crypt") ~= nil)
pal:slash("alts St")
check("a short name alone is not a full name", pal:said("no St in the crypt") ~= nil)
alt:slash("alts")
check("/dt alts with no name: the player's own group, both characters of the account, the main once",
  alt:said("Stromham Hamson's lot: main Stromham Hamson; alts (1): St Ham.") ~= nil)
pal:slash("alts echo nightclaw")
check("someone with no main is alone in the dark", pal:said("Echo Nightclaw hasn't named a main. Alone in the dark.") ~= nil)

-- Clear.
alt:slash("main clear")
check("/dt main clear removes the main", timDB.alts.main == nil and alt:said("main cleared. Everyone's an alt now.") ~= nil)
w:advance(1)
check("and sends a fresh HELLO with no main", lastHello(alt).main == "")
w:advance(30)
pal:slash("alts st ham")
check("the other side sees the main gone", pal:said("St Ham hasn't named a main.") ~= nil)
check("the account's own entries lose the main too", timDB.alts.roster["CAMWOWEU4Realm2PvP-Stromham Hamson"].main == "")
alt:slash("main banana")
check("/dt main <anything else> explains itself and changes nothing", timDB.alts.main == nil
  and alt:said("/dt main makes this character your main; /dt main clear forgets it.") ~= nil)

-- Two of the same full name on different realms (R-P5: the realm then tells them apart).
local twin = w:client({ name = "St", full = "St Ham", realm = "CAMWOW EU5 Realm 8 PvP", guild = G, random = half })
twin:login(); w:advance(30)
pal:slash("alts st ham")
check("the same full name on two realms asks for the realm, each shown with it",
  pal:said("more than one st ham: St Ham (CAMWOW EU4 Realm 2 PvP), St Ham (CAMWOW EU5 Realm 8 PvP). Add the realm.") ~= nil)
pal:slash("alts st ham-CAMWOWEU5Realm8PvP")
check("and the realm picks one", pal:said("hasn't named a main.") ~= nil)

-- A HELLO with a bad main is counted, not stored.
pal.DT._comms.inbound("DEADTIRED", pal.DT._comms.encode("HELLO", { v = "0.2.0", main = string.rep("x", 90) .. "-y" },
  "CAMWOWEU4Realm2PvP-Bad Main"), "GUILD", "Bad Main")
check("a HELLO with a malformed main is counted, not stored", pal:db().comms.badHello == 1
  and pal.DT.roster()["CAMWOWEU4Realm2PvP-Bad Main"] == nil)

-- ---------------------------------------------------------------- the own short-name entry, folded at login
do
  local w2 = H.world()
  local db = { schema = 3, migrated = { port1 = true }, alts = { main = "CAMWOWEU4Realm2PvP-Jobbi", roster = {
    ["CAMWOWEU4Realm2PvP-Jobbi"] = { main = "CAMWOWEU4Realm2PvP-Jobbi", seen = "2026-11-08 20:00:00", mine = true },
    ["CAMWOWEU4Realm2PvP-Marvella"] = { main = "CAMWOWEU4Realm2PvP-Jobbi", seen = "2026-11-07 20:00:00", mine = true },
    ["CAMWOWEU4Realm2PvP-Jo"] = { main = "", seen = "2026-11-07 20:00:00" } } } }
  local j = w2:client({ name = "Jobbi", full = "Jobbi Bones", realm = R2, guild = G, db = db, random = half })
  j:login()
  local r = db.alts.roster
  check("login: this character's own short key folds into its full key", r["CAMWOWEU4Realm2PvP-Jobbi"] == nil
    and r["CAMWOWEU4Realm2PvP-Jobbi Bones"].mine == true)
  check("login: every main pointing at it follows, the account's main too", db.alts.main == "CAMWOWEU4Realm2PvP-Jobbi Bones"
    and r["CAMWOWEU4Realm2PvP-Marvella"].main == "CAMWOWEU4Realm2PvP-Jobbi Bones")
  check("login: other short keys are left alone (only this character's own, exactly)", r["CAMWOWEU4Realm2PvP-Marvella"] ~= nil
    and r["CAMWOWEU4Realm2PvP-Jo"] ~= nil)
  j:slash("alts")
  check("login: /dt alts shows the main once and the alt once", j:said("Jobbi Bones's lot: main Jobbi Bones; alts (1): Marvella.") ~= nil)
end

-- ---------------------------------------------------------------- outside the guild
do
  local w3 = H.world()
  local o = w3:client({ name = "Stromham", full = "Stromham Hamson", guild = "Somebody Else" })
  o:login(); w3:advance(20)
  o:slash("main")
  check("outside the guild: /dt main says nothing, sends nothing, stores nothing", #o.printed == 0 and #o.sent == 0
    and (o:db().alts == nil or o:db().alts.main == nil))
end

H.finish("alts")
