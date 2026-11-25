-- Offline checks for QuestArcs.lua (dt_guildquests Q2, 0.8.0): the bag arc's data, as the brief's table gives it.
--   lua5.1 DeadTired/tests/test_questarcs.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local w = H.world()
local c = w:client({ guild = "DEAD TIRED" })
local DT = c.DT
local B = DT.QUEST_BAG
check("seven steps, numbered in order", #B == 7 and B[1][1] == 1 and B[7][1] == 7)
local want = { 79007, 79192, 80001, 79980, 79974, 79975, 79976 }
local ok = true
for i, s in ipairs(B) do if s[3] ~= want[i] then ok = false end end
check("the Horde quest IDs, as the brief's table", ok)
check("step 1's Alliance ID is 79008; no other step has one", B[1][4] == 79008 and (function()
  for i = 2, 7 do if B[i][4] ~= nil then return false end end return true end)())
check("Rekindle (3) is the only optional step", B[3][8] == true and (function()
  for i, s in ipairs(B) do if i ~= 3 and s[8] then return false end end return true end)())
check("step 5 carries the dwarf-country note", B[5][9] == "Dwarf country. Bring a friend.")
check("places: the Barrens 46, 74; Stonetalon 40.6, 52.4; Hillsbrad 87.3, 49.6",
  B[1][5] == "The Barrens" and B[1][6] == 46 and B[1][7] == 74 and B[2][5] == "Stonetalon Mountains" and B[2][6] == 40.6
  and B[7][5] == "Hillsbrad Foothills" and B[7][6] == 87.3 and B[7][7] == 49.6)
check("step 1's hand-in: Westfall 37, 50", DT.QUEST_BAG_HANDIN[1] == "Westfall" and DT.QUEST_BAG_HANDIN[2] == 37 and DT.QUEST_BAG_HANDIN[3] == 50)
local T = DT.QUEST_LIB_TIERS
check("four library tiers: 10, 20, 25, 35 with their reward quests",
  #T == 4 and T[1][1] == 10 and T[1][2] == 78150 and T[2][1] == 20 and T[2][2] == 79536 and T[3][1] == 25 and T[3][2] == 82208
  and T[4][1] == 35 and T[4][2] == 84394)
check("the source is cited", type(DT.QUEST_BAG_SOURCE) == "string" and DT.QUEST_BAG_SOURCE:find("Wowhead", 1, true) ~= nil)
check("no second book list: the library is DT.WAY_BOOKS, 39 books with quest IDs", #DT.WAY_BOOKS == 39 and (function()
  for _, b in ipairs(DT.WAY_BOOKS) do if type(b[5]) ~= "number" then return false end end return true end)())
H.finish("questarcs")
