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

-- ---------------------------------------------------------------- 0.3.4: my realm when the game gives "" (R-F7-1, R-F7-2)
local function guid(c0) rawset(c0.env, "UnitGUID", function(u) if u == "player" then return c0.guid end end) end
do
  local w2 = H.world()
  -- (1) the game, remembered for the character and the server
  local a = w2:client({ guild = G, name = "Stromham", full = "Stromham Hamson", realm = "CAMWOW EU4 Realm 2 PvP", setup = guid })
  a.guid = "Player-6842-001FEF8D"
  a:login()
  check("R-F7-1 (1): the game's realm when it gives one", a.DT.realmKey() == "CAMWOWEU4Realm2PvP" and a.DT.realmSource() == "game")
  local st = a:db().realms
  check("R-F7-2: remembered for the character and the server", st.byChar["stromham hamson"] == "CAMWOWEU4Realm2PvP"
    and st.byServer["6842"] == "CAMWOWEU4Realm2PvP")
  check("realmKey(<realm>) unchanged: normalised, nothing remembered", a.DT.realmKey("Some Realm") == "SomeRealm"
    and a.DT.realmKey("") == nil and st.byChar["some realm"] == nil)
  -- (2) the game goes quiet: the character's remembered realm
  a.realm = ""
  check("R-F7-1 (2): the game gives \"\": the character's realm", a.DT.realmKey() == "CAMWOWEU4Realm2PvP"
    and a.DT.realmSource() == "character" and a.DT.myKey() == "CAMWOWEU4Realm2PvP-Stromham Hamson")
  a.normRealm = false
  rawset(a.env, "GetRealmName", function() return nil end)
  check("R-F7-1 (2): and when the game gives nil", a.DT.realmKey() == "CAMWOWEU4Realm2PvP")
  rawset(a.env, "GetRealmName", function() return a.realm end); a.normRealm = nil
  check("DT.send sends again with a remembered key", a.DT.send("HELLO", { v = "x" }) == true)
  -- (3) a new character on a server DT knows
  local b = w2:client({ guild = G, name = "Newbie", full = "Newbie Toon", realm = "", db = a:db(), setup = guid })
  b.guid = "Player-6842-00ABCDEF"
  b:login()
  check("R-F7-1 (3): a new character on a known server: the server's realm (then kept as the character's)",
    b.DT.realmKey() == "CAMWOWEU4Realm2PvP" and (b.DT.realmSource() == "server" or b.DT.realmSource() == "character"))
  check("R-F7-1 (3): and it becomes that character's", b:db().realms.byChar["newbie toon"] == "CAMWOWEU4Realm2PvP")
  -- (4) a server DT has never seen
  local d = w2:client({ guild = G, name = "Far", full = "Far Away", realm = "", db = b:db(), setup = guid })
  d.guid = "Player-6950-001CCFF0"
  d:login()
  check("R-F7-1 (4): unknown server: S<server ID>", d.DT.realmKey() == "S6950" and d.DT.realmSource() == "server-id"
    and d.DT.myKey() == "S6950-Far Away")
  check("R-F7-1 (4): saved as the character's", d:db().realms.byChar["far away"] == "S6950")
  local d2 = d:reload()
  rawset(d2.env, "UnitGUID", function(u) if u == "player" then return "Player-6950-001CCFF0" end end)
  check("R-F7-1 (4): stable across a reload", d2.DT.myKey() == "S6950-Far Away")
  check("R-F7-2: (4) doesn't overwrite the server's memory", d2:db().realms.byServer["6950"] == nil)
  -- the game comes back: the real realm replaces the stand-in
  d2.realm = "CAMWOW EU4 Realm 4 PvP"
  check("R-F7-2: the game's realm replaces S<id>", d2.DT.realmKey() == "CAMWOWEU4Realm4PvP"
    and d2:db().realms.byChar["far away"] == "CAMWOWEU4Realm4PvP" and d2:db().realms.byServer["6950"] == "CAMWOWEU4Realm4PvP")
  -- a stand-in is replaced once the server's real realm is known
  local h = w2:client({ guild = G, name = "Stand", full = "Stand In", realm = "", db = d2:db(), setup = guid })
  h:db().realms.byChar["stand in"] = "S6950"
  h.guid = "Player-6950-00000009"
  h:login()
  check("R-F7-1 (3) beats a saved S<id>, and replaces it", h.DT.realmKey() == "CAMWOWEU4Realm4PvP"
    and h:db().realms.byChar["stand in"] == "CAMWOWEU4Realm4PvP")
  -- a GUID that doesn't parse
  local e = w2:client({ guild = G, name = "Odd", full = "Odd Guid", realm = "", db = d2:db(), setup = guid })
  e.guid = "Creature-0-1-2-3"
  e:login()
  check("GUID pattern: anything but Player-<n>- gives no server: no key", e.DT.realmKey() == nil and e.DT.myKey() == nil)
  check("and DT.send still refuses", e.DT.send("HELLO", { v = "x" }) == false)
  e.guid = nil
  check("no GUID at all: no key", e.DT.myKey() == nil)
  -- (2) isn't overwritten by (3)
  local f = w2:client({ guild = G, name = "Two", full = "Two Realms", realm = "", db = e:db(), setup = guid })
  f:db().realms.byChar["two realms"] = "HomeRealm"
  f.guid = "Player-6842-00000001"
  f:login()
  check("R-F7-2: the character's realm beats the server's, and isn't overwritten", f.DT.realmKey() == "HomeRealm"
    and f:db().realms.byChar["two realms"] == "HomeRealm")
  -- the cap
  local g = w2:client({ guild = G, name = "Cap", full = "Cap Test", realm = "", db = f:db(), setup = guid })
  for i = 1, 300 do g:db().realms.byChar["filler " .. i] = "R" end
  local function size() local n = 0 for _ in pairs(g:db().realms.byChar) do n = n + 1 end return n end
  local before = size()
  g.guid = "Player-7777-00000001"
  g:login()
  check("realms store capped: a full byChar takes no new entry (no key then)", size() == before
    and g:db().realms.byChar["cap test"] == nil and g.DT.myKey() == nil)
end

H.finish("keys")
