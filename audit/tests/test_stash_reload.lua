-- AUD-03 (card 6, Stash.lua): after the asker's /reload, sharing guildies ignore its searches.
--   lua5.1 audit/tests/test_stash_reload.lua   (from the repo root, after setup.sh)
-- Red now: same shape as AUD-02. `qid` restarts at 1 after a /reload; answerers keep
-- answered[asker .. "#" .. q] for their session and stay silent on a reused id.
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local L = dofile(dir .. "/lib.lua")
local H = L.harness("dt_stretch")
local check = H.check
local FILES = { "Config.lua", "Core.lua", "Guild.lua", "Comms.lua", "Roster.lua", "Alts.lua", "Welcome.lua",
  "Stash.lua" }
local LINEN = 2589

local function stubs(c)
  c.env.C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end,
    GetContainerItemInfo = function(bag, slot)
      if bag == 0 and slot == 1 then return { itemID = LINEN, stackCount = 20, isBound = false } end
    end,
  }
  c.env.C_Item = { GetItemNameByID = function(id) if id == LINEN then return "Linen Cloth" end end,
    RequestLoadItemDataByID = function() end }
end

do
  local w = H.world()
  local a = w:client({ name = "Stromham", guild = L.G, files = FILES, random = L.half })
  local b = w:client({ name = "Graverobber", guild = L.G, files = FILES, random = L.half })
  stubs(a); stubs(b)
  a:login(); b:login()
  w:advance(60)
  b:slash("stash share on")
  a:slash("stash linen")
  w:advance(11)
  check("baseline: the first search gets B's answer", a:said("Graverobber: Linen Cloth x20") ~= nil)

  w:advance(120)
  local a2 = L.reload(w, a, { random = L.half, files = FILES, stubs = stubs })
  w:advance(30)
  a2:slash("stash linen")
  w:advance(11)
  check("after the asker's /reload, B answers the new search (A printed: "
    .. tostring(a2.printed[#a2.printed - 1]) .. ")", a2:said("Graverobber: Linen Cloth x20") ~= nil)
end

H.finish("audit stash_reload")
