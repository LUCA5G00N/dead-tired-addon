-- Offline checks for Debug.lua: /dt debug names (player and target), /dt debug senders,
-- /dt debug errors.  lua5.1 DeadTired/tests/test_debug.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"

local w = H.world()
local c = w:client({ guild = G, target = { name = "Lilbit", full = "Lilbit High", realm = "CAMWOWEU4Realm4PvP" } })
c:login()
c:slash("debug names")
check("player: every name function", c:said('player: UnitName "Stromham", UnitFullName "Stromham" / "CAMWOWEU4Realm2PvP", GetUnitName(true) "Stromham Hamson"'))
check("target: the same functions", c:said('target: UnitName "Lilbit", UnitFullName "Lilbit" / "CAMWOWEU4Realm4PvP", GetUnitName(true) "Lilbit High"'))
check("realm functions and the key built from them", c:said('realm: GetRealmName "CAMWOW EU4 Realm 2 PvP", GetNormalizedRealmName "CAMWOWEU4Realm2PvP", key "CAMWOWEU4Realm2PvP-Stromham Hamson"'))
c.target = nil
c:slash("debug names")
check("no target: nil, not an error", c:said('target: UnitName nil, UnitFullName nil / nil, GetUnitName(true) nil'))
c.secrets["Stromham"] = true
c:slash("debug names")
check("a secret value is not printed", not c:said('UnitName "Stromham"') and c:said("player: UnitName nil"))
c.secrets["Stromham"] = nil

c:fire("CHAT_MSG_ADDON", "DEADTIRED", "junk", "GUILD", "Ghoul Grim-Somewhere")
c:fire("CHAT_MSG_ADDON", "DEADTIRED", "junk", "GUILD", "|cffff0000Evil|r")
c:slash("debug senders")
check("senders: the count", c:said("senders: 2 (cap 50, over cap 0), key mismatches 0") ~= nil)
check("senders: each raw string, safely", c:said('"Ghoul Grim-Somewhere" x1 GUILD') and c:said('"||cffff0000Evil||r" x1'))

c:slash("debug errors")
check("errors: none recorded", c:said("errors: none") and c:said("comms: sent ") and c:said('restricted flag "true"'))
c.DT.fail("who", "TEST", "it broke")
c:slash("debug errors")
check("errors: each module's count and last text", c:said('errors who: 1 "TEST: it broke"') ~= nil)
check("each debug line goes through DT.out (silent outside the guild)", (function()
  c.guild = nil
  c:slash("debug names")
  return #c.printed == 0
end)())

H.finish("debug")
