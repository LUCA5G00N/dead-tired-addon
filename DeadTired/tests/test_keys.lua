-- Offline checks for Keys.lua: one character key from the full name; own realm vs connected realm;
-- display; case and spacing.  lua5.1 DeadTired/tests/test_keys.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"

local w = H.world()
local c = w:client({ guild = G, name = "Stromham", full = "Stromham Hamson", realm = "CAMWOW EU4 Realm 2 PvP" })
local DT = c.DT

check("realmKey: spaces and hyphens go", DT.realmKey("CAMWOW EU4 Realm 4 PvP") == "CAMWOWEU4Realm4PvP"
  and DT.realmKey("Argent-Dawn") == "ArgentDawn" and DT.realmKey("") == nil and DT.realmKey("  ") == nil)
check("realmKey(): the player's own, from GetNormalizedRealmName", DT.realmKey() == "CAMWOWEU4Realm2PvP")
c.normRealm = false
check("realmKey(): GetRealmName when the normalised name is missing", DT.realmKey() == "CAMWOWEU4Realm2PvP")
c.normRealm = nil

check("keyOf: two-part name, realm normalised", DT.keyOf("Stromham Hamson", "CAMWOW EU4 Realm 2 PvP")
  == "CAMWOWEU4Realm2PvP-Stromham Hamson")
check("keyOf: no realm means my realm", DT.keyOf("Lilbit High") == "CAMWOWEU4Realm2PvP-Lilbit High")
check("keyOf: spacing tidied", DT.keyOf("  Lilbit   High ", "CAMWOW EU4 Realm 4 PvP") == "CAMWOWEU4Realm4PvP-Lilbit High")
check("keyOf: a -Realm suffix on the name is dropped", DT.keyOf("Lilbit High-CAMWOWEU4Realm4PvP", "CAMWOW EU4 Realm 4 PvP")
  == "CAMWOWEU4Realm4PvP-Lilbit High")
check("keyOf: case kept as given", DT.keyOf("stromham hamson") == "CAMWOWEU4Realm2PvP-stromham hamson")
check("keyOf: nothing for no name or Unknown", DT.keyOf("") == nil and DT.keyOf(nil) == nil and DT.keyOf("Unknown") == nil)

check("myKey: the full name (GetUnitName(\"player\", true)), not UnitName",
  DT.myKey() == "CAMWOWEU4Realm2PvP-Stromham Hamson" and DT.myName() == "Stromham Hamson")
c.unknown = true
check("myKey: nil while the client says Unknown", DT.myKey() == nil)
c.unknown = nil
local keep = rawget(c.env, "GetUnitName")
rawset(c.env, "GetUnitName", nil)
check("myKey: falls back to UnitName when GetUnitName is absent", DT.myKey() == "CAMWOWEU4Realm2PvP-Stromham")
rawset(c.env, "GetUnitName", keep)
c.secrets["Stromham Hamson"] = true
check("myKey: a secret full name is not used", DT.myKey() == "CAMWOWEU4Realm2PvP-Stromham")
c.secrets["Stromham Hamson"] = nil

check("splitKey / nameOf", select(1, DT.splitKey("CAMWOWEU4Realm4PvP-Lilbit High")) == "CAMWOWEU4Realm4PvP"
  and DT.nameOf("CAMWOWEU4Realm4PvP-Lilbit High") == "Lilbit High" and DT.splitKey("NoKey") == nil)

check("display: own realm shows the name only", DT.display("CAMWOWEU4Realm2PvP-Lilbit High") == "Lilbit High")
check("display: own realm in another case still the name only", DT.display("camwoweu4realm2pvp-Lilbit High") == "Lilbit High")
check("display: a connected realm shows Name (Realm)", DT.display("CAMWOWEU4Realm4PvP-Lilbit High")
  == "Lilbit High (CAMWOWEU4Realm4PvP)")
DT.realmNames["CAMWOWEU4Realm4PvP"] = "CAMWOW EU4 Realm 4 PvP"
check("display: the realm's own spelling once a HELLO has told us", DT.display("CAMWOWEU4Realm4PvP-Lilbit High")
  == "Lilbit High (CAMWOW EU4 Realm 4 PvP)")
check("display: UI escapes made safe (| doubled)", DT.display("Realm4-|cffff0000Red|r"):find("||cffff0000Red||r", 1, true) ~= nil)

check("sameKey ignores case and spacing", DT.sameKey("CAMWOWEU4Realm2PvP-Stromham Hamson", "camwoweu4realm2pvp-stromham  hamson")
  and not DT.sameKey("CAMWOWEU4Realm2PvP-Stromham Hamson", "CAMWOWEU4Realm4PvP-Stromham Hamson"))
check("the same full name on two realms is two keys", DT.keyOf("Lilbit High", "CAMWOW EU4 Realm 4 PvP")
  ~= DT.keyOf("Lilbit High", "CAMWOW EU4 Realm 2 PvP"))

H.finish("keys")
