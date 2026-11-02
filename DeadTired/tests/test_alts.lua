-- Offline checks for Alts.lua, two accounts on one fake GUILD bus.
--   lua5.1 DeadTired/tests/test_alts.lua  (from the repo root)
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local FILES = { "Config.lua", "Core.lua", "Guild.lua", "Comms.lua", "Roster.lua", "Alts.lua" }
local G = "DEAD TIRED"
local function half() return 0.5 end

local function lastHello(c)
  for i = #c.sent, 1, -1 do if c.sent[i].text:find("^1%^HELLO") then return c.sent[i] end end
end

local w = H.world()
local timDB, pal = {}, nil
-- The guildie, on another account, online throughout.
pal = w:client({ name = "Graverobber", guild = G, files = FILES, random = half })
pal:login(); w:advance(30)

-- Tim on Stromham.
local strom = w:client({ name = "Stromham", guild = G, files = FILES, random = half, db = timDB })
strom:login(); w:advance(30)
strom:slash("alts")
check("no main yet: /dt alts says so", strom:said("you haven't named a main") ~= nil)
local n0 = #strom.sent
strom:slash("main")
check("/dt main sets the account's main", timDB.account.main == "Classic Beta PvP-Stromham"
  and strom:said("Stromham is now your main") ~= nil)
check("/dt main sends a fresh HELLO carrying the main", #strom.sent == n0 + 1
  and lastHello(strom).text == "1^HELLO^main~Classic Beta PvP-Stromham^v~0.1.0")
w:advance(30)
check("the guildie stores Stromham's main", pal.DT.roster()["Classic Beta PvP-Stromham"].main == "Classic Beta PvP-Stromham")
check("and does not reply to a HELLO from someone already answered", #pal.sent == 2)
strom:logout()

-- Tim logs an alt on the same account: same SavedVariables, so the same main.
local alt = w:client({ name = "Bonechill", guild = G, files = FILES, random = half, db = timDB })
alt:login(); w:advance(30)
check("the alt's login HELLO reports the account's main", lastHello(alt).text:find("main~Classic Beta PvP-Stromham", 1, true) ~= nil)
pal:slash("alts Bonechill")
check("/dt alts <alt> on the other side names Stromham as main and the alt in the group",
  pal:said("Stromham's lot: main Stromham; alts (1): Bonechill.") ~= nil)
pal:slash("alts bonechill-classicbetapvp")
check("name is case-insensitive, realm optional (Name-Realm)", pal:said("alts (1): Bonechill") ~= nil)
pal:slash("alts Classic Beta PvP-BONECHILL")
check("...or Realm-Name", pal:said("alts (1): Bonechill") ~= nil)
pal:slash("alts stromham")
check("/dt alts <main> prints the same group", pal:said("Stromham's lot: main Stromham; alts (1): Bonechill.") ~= nil)
pal:slash("alts Nobody")
check("an unknown name says only addon users are known", pal:said("Only guildies running the addon are known.") ~= nil)
pal:slash("alts Bonechill-Nethergarde")
check("a wrong realm is not a match", pal:said("no bonechill-nethergarde") ~= nil or pal:said("no Bonechill-Nethergarde") ~= nil)
alt:slash("alts")
check("/dt alts with no name: the player's own group, both characters of the account",
  alt:said("Stromham's lot: main Stromham; alts (1): Bonechill.") ~= nil)
pal:slash("alts graverobber")
check("someone with no main is alone in the dark", pal:said("Graverobber hasn't named a main.") ~= nil)

-- Clear.
alt:slash("main clear")
check("/dt main clear removes the main", timDB.account.main == nil and alt:said("main cleared") ~= nil)
check("and sends a fresh HELLO with no main", lastHello(alt).text == "1^HELLO^main~^v~0.1.0")
w:advance(30)
pal:slash("alts bonechill")
check("the other side sees the main gone", pal:said("Bonechill hasn't named a main.") ~= nil)
check("the account's own entries lose the main too", timDB.roster["dead tired"]["Classic Beta PvP-Stromham"].main == "")
alt:slash("main banana")
check("/dt main <anything else> explains itself and changes nothing", timDB.account.main == nil
  and alt:said("/dt main clear forgets it") ~= nil)

-- Two of the same name on different realms.
pal:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^HELLO^main~^v~0.1.0", "GUILD", "Bonechill-Nethergarde")
pal:slash("alts bonechill")
check("the same name on two realms asks for the realm", pal:said("more than one bonechill") ~= nil)
pal:slash("alts bonechill-nethergarde")
check("and the realm picks one", pal:said("Bonechill-Nethergarde hasn't named a main.") ~= nil)

H.finish("alts")
