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
-- R-P5 (Port 1): the full name only, the realm only on a collision among the shown keys.
check("R-P5: a connected realm shows the full name only", DT.display("CAMWOWEU4Realm4PvP-Lilbit High") == "Lilbit High")
check("R-P5: the realm label for the tooltip", DT.realmLabel("CAMWOWEU4Realm4PvP-Lilbit High") == "CAMWOWEU4Realm4PvP")
DT.realmNames["CAMWOWEU4Realm4PvP"] = "CAMWOW EU4 Realm 4 PvP"
check("R-P5: the realm's own spelling once a HELLO has told us", DT.realmLabel("CAMWOWEU4Realm4PvP-Lilbit High")
  == "CAMWOW EU4 Realm 4 PvP")
local shown = { "CAMWOWEU4Realm4PvP-Lilbit High", "CAMWOWEU5Realm8PvP-Lilbit High", "CAMWOWEU4Realm2PvP-Echo Nightclaw" }
local nm = DT.namer(shown)
check("R-P5 collision: two shown entries sharing a full name both get (Realm)",
  nm(shown[1]) == "Lilbit High (CAMWOW EU4 Realm 4 PvP)" and nm(shown[2]) == "Lilbit High (CAMWOWEU5Realm8PvP)")
check("R-P5 collision: the others keep the plain name", nm(shown[3]) == "Echo Nightclaw")
check("R-P5 collision: case and spacing don't hide one", DT.namer({ "R1-Lilbit High", "R2-lilbit  high" })("R1-Lilbit High") == "Lilbit High (R1)")
check("R-P5: the same key twice is no collision", DT.namer({ "R1-Lilbit High", "R1-Lilbit High" })("R1-Lilbit High") == "Lilbit High")
check("R-P5: display among a shown set", DT.display(shown[1], shown) == "Lilbit High (CAMWOW EU4 Realm 4 PvP)"
  and DT.display(shown[1], { shown[1], shown[3] }) == "Lilbit High")
check("display: UI escapes made safe (| doubled)", DT.display("Realm4-|cffff0000Red|r"):find("||cffff0000Red||r", 1, true) ~= nil)

check("sameKey ignores case and spacing", DT.sameKey("CAMWOWEU4Realm2PvP-Stromham Hamson", "camwoweu4realm2pvp-stromham  hamson")
  and not DT.sameKey("CAMWOWEU4Realm2PvP-Stromham Hamson", "CAMWOWEU4Realm4PvP-Stromham Hamson"))
check("the same full name on two realms is two keys", DT.keyOf("Lilbit High", "CAMWOW EU4 Realm 4 PvP")
  ~= DT.keyOf("Lilbit High", "CAMWOW EU4 Realm 2 PvP"))

-- Port 2: DT.normKey, the one spelling for a key from another client or an old store
do
  local w = H.world()
  local c = w:client({ guild = "DEAD TIRED" })
  local N = c.DT.normKey
  check("normKey: realm normalised, name tidied", N("CAMWOW EU4 Realm 2 PvP-Stromham  Hamson") == "CAMWOWEU4Realm2PvP-Stromham Hamson")
  check("normKey: not a key is nil", N("NoRealm") == nil and N("Realm-") == nil and N(nil) == nil)
end

H.finish("keys")
