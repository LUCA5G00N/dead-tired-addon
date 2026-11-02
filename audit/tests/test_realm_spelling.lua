-- AUD-06 (cards 1, 5, 6): a guildie on another realm (connected realms) is keyed two ways.
--   lua5.1 audit/tests/test_realm_spelling.lua   (from the repo root, after setup.sh)
-- Comms keys a sender by CHAT_MSG_ADDON's realm, which has no spaces ("ArgentDawn-Stromham"),
-- unless it is the receiver's own realm. charKey() and every key a client sends about itself
-- ("main", and the asker's own check of "to") use GetRealmName, with spaces ("Argent Dawn-...").
-- Red now: prep answers to an asker on a spaced foreign realm are dropped, and /dt alts can't
-- group a main from such a realm.
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local L = dofile(dir .. "/lib.lua")
local H = L.harness("dt_prep")
local check = H.check
local FILES = { "Config.lua", "Core.lua", "Guild.lua", "Comms.lua", "Roster.lua", "Alts.lua", "Welcome.lua",
  "PrepList.lua", "Prep.lua" }
local function stubs(c)
  c.env.UnitClass = function() return "Warrior", "WARRIOR" end
  c.env.C_Item = { GetItemCount = function() return 99 end }
end

do
  local w = H.world()
  local a = w:client({ name = "Stromham", realm = "Argent Dawn", guild = L.G, files = FILES, random = L.half })
  local b = w:client({ name = "Graverobber", realm = "Classic Beta PvP", guild = L.G, files = FILES, random = L.half })
  stubs(a); stubs(b)
  a:login(); b:login()
  w:advance(60)
  b:slash("prep share on")
  a:slash("prep check")
  w:advance(11)
  check("an asker on a realm with a space in its name gets a connected-realm guildie's answer",
    a:said("Ready (1)") ~= nil)

  -- Stromham names a main; a guildie on another realm asks for Stromham's group.
  a:slash("main")
  w:advance(30)
  b:slash("alts Stromham")
  check("/dt alts on the other realm shows Stromham as a main with no alts, not as its own alt (it says: "
    .. tostring(b.printed[1]) .. ")", b:said("is a main with no known alts") ~= nil)
end

H.finish("audit realm_spelling")
