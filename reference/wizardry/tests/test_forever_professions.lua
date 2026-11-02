-- Stub-driven checks for Forever/ProfessionRecorder.lua.
--   lua5.1 addons/WizardryLedger/tests/test_forever_professions.lua     (from the repo root)
--
-- 0012: stubs model only what the client was seen to do. Every return below comes from
-- tests/fixture_recipes_70009.lua, generated from the /probe recipes capture of 2026-09-25
-- (Probe 0.9.0, e142ad5, build 1.60.1-70009). Where the capture has nothing (a schematic
-- for a recipe the probe did not dump in full), the stub answers nothing.
-- Chat text: "Your skill in X has increased to N." is the line Probe's skill-up capture has
-- recorded since 2026-09-19. UNIT_SPELLCAST_SUCCEEDED("player", castGUID, spellID): the
-- argument order Probe's casts list records (args[2] is the spell).
-- UNOBSERVED, and so not stubbed: C_Item.GetItemNameByID (it answered "Linen Cloth" in the
-- first UAT session, but its absence path is the one tested here).
-- OBSERVED IN THE FIRST UAT SESSION (4fab3b5, 2026-09-25), and modelled from 0.15.1:
--   * TRADE_SKILL_LIST_UPDATE fires (listUpdateSeen = true on every catalogue).
--   * GetAllRecipeIDs can return the previous profession's list after the window has
--     switched: the save filed smelting recipes under First Aid and cooking ones under
--     Mining. S.list and S.prof are separate here for that reason.
--   * UnitName("player") answers "Unknown" at ADDON_LOADED on a cold login: 16 accepts and
--     5 turn-ins in that save are keyed "Classic Beta PvP-Unknown".

local root = (arg and arg[0] or ""):match("^(.*)[/\\]addons[/\\]WizardryLedger[/\\]tests[/\\]") or "."
local addonDir = root .. "/addons/WizardryLedger"
local fails, passes = 0, 0
local function check(name, cond)
  if cond then passes = passes + 1 else fails = fails + 1; print("FAIL " .. name) end
end

local FX = dofile(addonDir .. "/tests/fixture_recipes_70009.lua")

-- ---------------------------------------------------------------- stubs
local S = { t = 1000, timers = {}, prof = "First Aid", list = "First Aid", secrets = {}, rdOverride = {},
            printed = {}, loggedIn = false }
function GetTime() return S.t end
function date() return "2026-09-25 14:00:00" end
function GetBuildInfo() return "1.60.1", "70009" end
function GetRealmName() return "Classic Beta PvP" end
function UnitName(u) if u == "player" then return S.loggedIn and "Bloodandt" or "Unknown" end end
function UnitLevel() return 10 end
function UnitClass() return "Warlock", "WARLOCK" end
function issecretvalue(v) return S.secrets[v] == true end
C_Timer = { After = function(d, fn) table.insert(S.timers, { at = S.t + d, fn = fn }) end }
local function drain()
  local guard = 0
  while #S.timers > 0 and guard < 1000 do
    guard = guard + 1
    table.sort(S.timers, function(a, b) return a.at < b.at end)
    local e = table.remove(S.timers, 1)
    if e.at > S.t then S.t = e.at end
    e.fn()
  end
  return guard
end
local function advance(d) S.t = S.t + d end

local function P_() return FX[S.prof] end
C_TradeSkillUI = {
  IsTradeSkillReady = function() return true end,           -- observed: ready=true on all three
  GetBaseProfessionInfo = function() return P_().base end,
  GetAllRecipeIDs = function() local c = {} for i, id in ipairs(FX[S.list].ids) do c[i] = id end return c end,
  GetTradeSkillLineForRecipe = function(id)
    for _, name in ipairs({ "First Aid", "Enchanting" }) do
      if FX[name].info[id] then return unpack(FX[name].line) end
    end
  end,
  GetRecipeInfo = function(id)
    for _, name in ipairs({ "First Aid", "Enchanting" }) do
      local info = FX[name].info[id]
      if info then
        local copy = {}
        for k, v in pairs(info) do copy[k] = v end
        if S.rdOverride[id] then copy.relativeDifficulty = S.rdOverride[id] end
        return copy
      end
    end
  end,
  GetRecipeSchematic = function(id)
    for _, name in ipairs({ "First Aid", "Enchanting" }) do
      if FX[name].schematic[id] then return FX[name].schematic[id] end
    end
  end,
  GetRecipeRequirements = function(id)
    for _, name in ipairs({ "First Aid", "Enchanting" }) do
      if FX[name].requirements[id] then return FX[name].requirements[id] end
    end
  end,
}
-- Ranks by name after a skill-up. The client's skill lines move with a skill-up (Probe saw
-- SKILL_LINES_CHANGED 123 times beside 109 CHAT_MSG_SKILL on 70009); the stub follows.
local skillRank = {}
C_SkillInfo = {
  GetNumSkillLines = function() return #FX.skillLines end,
  GetSkillLineInfo = function(i)
    local r = FX.skillLines[i]
    if not r then return nil end
    local c = {}
    for k, v in pairs(r) do c[k] = v end
    if skillRank[c.name] then c.rank = skillRank[c.name] end
    return c
  end,
}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(S.printed, m) end }
SlashCmdList = {}

local frames = {}
function CreateFrame()
  local f = { events = {}, scripts = {} }
  function f:RegisterEvent(e) self.events[e] = true end
  function f:UnregisterEvent(e) self.events[e] = nil end
  function f:SetScript(k, fn) self.scripts[k] = fn end
  table.insert(frames, f)
  return f
end
local function fire(ev, ...)
  for _, f in ipairs(frames) do
    if ev == "ADDON_LOADED" or f.events[ev] then f.scripts.OnEvent(f, ev, ...) end
  end
end
local function printed(needle)
  for _, m in ipairs(S.printed) do if m:find(needle, 1, true) then return m end end
end

local ns = {}
assert(loadfile(addonDir .. "/Forever/Core.lua"))("WizardryLedger", ns)
assert(loadfile(addonDir .. "/Forever/QuestRecorder.lua"))("WizardryLedger", ns)
assert(loadfile(addonDir .. "/Forever/ProfessionRecorder.lua"))("WizardryLedger", ns)

-- ---------------------------------------------------------------- load
-- A 0.15.0 save: a contaminated catalogue (smelting filed under First Aid) and one real
-- craft row. The catalogue must go; the craft must stay.
WizardryLedgerDB = { forever = { schema = 1, builds = { ["1.60.1-70009"] = { created = "x", sessions = 3,
  quests = {}, professions = {
    catalogue = { ["First Aid"] = { count = 32, complete = true, recipes = { [2657] = { name = "Smelt Copper" } } } },
    chars = { ["Classic Beta PvP-Bloodandt"] = { skills = {}, learned = { [3276] = true }, other = {},
      crafts = { [3276] = { [59] = { n = 1, ups = 1, rd = 1 } } } } } } } } } }
fire("ADDON_LOADED", "WizardryLedger")
check("a pre-schema-2 catalogue is dropped at load", next(WizardryLedgerDB.forever.builds["1.60.1-70009"].professions.catalogue) == nil
  and WizardryLedgerDB.forever.builds["1.60.1-70009"].professions.schema == 2)
check("no character is attached while the client answers 'Unknown'",
  WizardryLedgerDB.forever.builds["1.60.1-70009"].professions.chars["Classic Beta PvP-Unknown"] == nil)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-early", 3276)
check("nothing is written before the character is known",
  WizardryLedgerDB.forever.builds["1.60.1-70009"].professions.chars["Classic Beta PvP-Unknown"] == nil)
S.loggedIn = true
fire("PLAYER_LOGIN")
local B = WizardryLedgerDB.forever.builds["1.60.1-70009"]
check("the build bucket is reused and the quest recorder counts the session", B and B.sessions == 4 and type(B.quests) == "table")
local PR = B.professions
local ME = PR and PR.chars["Classic Beta PvP-Bloodandt"]
check("the character is attached at PLAYER_LOGIN, not as 'Unknown'", PR and ME and ME.skills and ME.crafts
  and PR.chars["Classic Beta PvP-Unknown"] == nil)
check("its earlier craft rows survive the catalogue reset", ME.crafts[3276] and ME.crafts[3276][59]
  and ME.crafts[3276][59].n == 1)
check("profession events registered", frames[2].events.UNIT_SPELLCAST_SUCCEEDED and frames[2].events.CHAT_MSG_SKILL
  and frames[2].events.TRADE_SKILL_SHOW and frames[2].events.SKILL_LINES_CHANGED)

-- ---------------------------------------------------------------- skills
check("First Aid read as a secondary skill at 59/75", ME.skills["First Aid"] and ME.skills["First Aid"].rank == 59
  and ME.skills["First Aid"].max == 75 and ME.skills["First Aid"].cat == 9)
check("Enchanting read as a profession", ME.skills.Enchanting and ME.skills.Enchanting.rank == 24 and ME.skills.Enchanting.cat == 11)
check("weapon skills are not professions", ME.skills.Wands == nil and ME.skills.Defense == nil)
check("headers are skipped", ME.skills.Professions == nil and ME.skills["Secondary Skills"] == nil)

-- ---------------------------------------------------------------- the First Aid catalogue
S.prof = "First Aid"
fire("TRADE_SKILL_SHOW")
drain()
local FA = PR.catalogue["First Aid"]
check("First Aid catalogue: 32 recipes, complete", FA and FA.count == 32 and FA.complete == true)
check("the catalogue was built in 2 steps (32 at 25 a step)", FA and FA.steps == 2)
check("skill line id kept", FA and FA.skillLineID == 129)
local n = 0
for _ in pairs(FA.recipes) do n = n + 1 end
check("every listed recipe has a row", n == 32)
local lb = FA.recipes[3275]
check("Linen Bandage: 1 Linen Cloth, makes 1, grey at 60",
  lb and lb.reagents and #lb.reagents == 1 and lb.reagents[1].item == 2589 and lb.reagents[1].qty == 1
  and lb.out == 1251 and lb.qMin == 1 and lb.trivial == 60)
local kit = FA.recipes[1230117]
check("First Aid Kit: 3 Linen Bandage and 1 Refreshing Spring Water",
  kit and #kit.reagents == 2 and kit.reagents[1].item == 1251 and kit.reagents[1].qty == 3
  and kit.reagents[2].item == 159 and kit.reagents[2].qty == 1)
do
  local undumped
  for _, id in ipairs(FX["First Aid"].ids) do
    if not FX["First Aid"].schematic[id] then undumped = id break end
  end
  check("a recipe with no schematic has a row and no invented reagents",
    undumped and FA.recipes[undumped] and FA.recipes[undumped].reagents == nil)
end
check("the catalogue stores no colour (unlearned recipes always read 0)", lb.relativeDifficulty == nil and lb.rd == nil)
local learned = 0
for _ in pairs(ME.learned) do learned = learned + 1 end
check("five First Aid recipes learned", learned == 5 and ME.learned[3275] and ME.learned[3276]
  and ME.learned[1244432] and not ME.learned[3277])

-- ---------------------------------------------------------------- crafts
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-6783-1-178-3275-000435B3A5", 3275)
advance(0.3)
fire("CHAT_MSG_SKILL", "Your skill in First Aid has increased to 60."); skillRank["First Aid"] = 60
local row = ME.crafts[3275] and ME.crafts[3275][59]
check("craft of 3275 at 59: n=1, ups=1, rd=2 (green)", row and row.n == 1 and row.ups == 1 and row.rd == 2)
check("the skill-up moves the rank", ME.skills["First Aid"].rank == 60)

advance(5)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-b", 3275)
local r60 = ME.crafts[3275][60]
check("a craft with no skill-up counts n only", r60 and r60.n == 1 and r60.ups == 0)

advance(5)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-c", 3275)
advance(1.5)
fire("CHAT_MSG_SKILL", "Your skill in First Aid has increased to 61."); skillRank["First Aid"] = 61
check("a skill-up 1.5 s after a craft is not credited to it", ME.crafts[3275][60].n == 2 and ME.crafts[3275][60].ups == 0)
check("it is kept as an unattributed First Aid skill-up", ME.other["First Aid"] and ME.other["First Aid"].none
  and ME.other["First Aid"].none.ups == 1)

advance(5)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-d", 3275)
advance(5)
S.rdOverride[3275] = 3
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-d2", 3275)
local r61 = ME.crafts[3275][61]
check("a different colour at the same rank marks the row rather than overwriting it",
  r61 and r61.n == 2 and r61.rd == 2 and r61.rdChanged == true)
S.rdOverride[3275] = nil

advance(5)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-e", 3277)     -- Wool Bandage, not learned
check("a cast of an unlearned recipe id is not a craft", ME.crafts[3277] == nil)

advance(5)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-f", 13262)    -- Disenchant
advance(0.2)
fire("CHAT_MSG_SKILL", "Your skill in Enchanting has increased to 25."); skillRank.Enchanting = 25
check("Disenchant's skill-up goes to other, by spell", ME.other.Enchanting and ME.other.Enchanting[13262]
  and ME.other.Enchanting[13262].ups == 1)

advance(5)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-g", 5019)     -- Shoot
advance(0.2)
fire("CHAT_MSG_SKILL", "Your skill in Wands has increased to 46.")
check("a weapon skill-up is recorded nowhere", ME.other.Wands == nil and ME.skills.Wands == nil)

advance(5)
fire("UNIT_SPELLCAST_SUCCEEDED", "target", "Cast-h", 3275)
check("another unit's cast is ignored", ME.crafts[3275][61].n == 2)

advance(5)
S.secrets[3276] = true
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-i", 3276)
local rows3276 = 0
for _ in pairs(ME.crafts[3276]) do rows3276 = rows3276 + 1 end
check("a secret spell id is dropped, not stored", rows3276 == 1 and ME.crafts[3276][59].n == 1)
S.secrets[3276] = nil
local secretText = "Your skill in First Aid has increased to 62."
S.secrets[secretText] = true
local before = ME.skills["First Aid"].rank
fire("CHAT_MSG_SKILL", secretText)
check("a secret skill line is dropped", ME.skills["First Aid"].rank == before)

-- ---------------------------------------------------------------- the Enchanting catalogue
S.prof, S.list = "Enchanting", "Enchanting"
fire("TRADE_SKILL_SHOW")
drain()
local EN = PR.catalogue.Enchanting
check("Enchanting catalogue: 261 recipes, complete", EN and EN.count == 261 and EN.complete == true)
check("built in 11 steps of at most 25", EN and EN.steps == 11)
n = 0
for _ in pairs(EN.recipes) do n = n + 1 end
check("every Enchanting recipe has a row", n == 261)
check("a tool requirement is kept by name", EN.recipes[7418] and EN.recipes[7418].needs
  and EN.recipes[7418].needs[1] == "Runed Copper Rod")
check("Dust to Motes makes 3", EN.recipes[1245320] and EN.recipes[1245320].qMin == 3)
check("First Aid's catalogue is untouched by the second profession", PR.catalogue["First Aid"].count == 32)

-- A second opening of an unchanged profession refreshes learned flags only.
fire("TRADE_SKILL_SHOW")
drain()
check("reopening does not rebuild", PR.catalogue.Enchanting.steps == 11)

-- The window says Enchanting but the list is still First Aid's (seen in the UAT session).
PR.catalogue.Enchanting = nil
S.prof, S.list = "Enchanting", "First Aid"
fire("TRADE_SKILL_SHOW")
drain()
check("a stale list files nothing under the profession the window claims", PR.catalogue.Enchanting == nil)
check("and leaves the profession it belongs to intact", PR.catalogue["First Aid"].count == 32
  and PR.catalogue["First Aid"].recipes[3275] ~= nil and PR.catalogue["First Aid"].recipes[7418] == nil)
S.list = "Enchanting"
fire("TRADE_SKILL_LIST_UPDATE")
drain()
check("the list update that follows builds the right one", PR.catalogue.Enchanting
  and PR.catalogue.Enchanting.complete == true and PR.catalogue.Enchanting.count == 261)
check("no recipe is filed under two professions", PR.catalogue["First Aid"].recipes[7418] == nil
  and PR.catalogue.Enchanting.recipes[3275] == nil)

-- A list update arriving mid-scan is not lost: the scan runs again when it finishes.
PR.catalogue.Enchanting = nil
S.list = "First Aid"
fire("TRADE_SKILL_SHOW")                 -- starts on First Aid's list, first step runs now
S.list = "Enchanting"
fire("TRADE_SKILL_LIST_UPDATE")          -- arrives while that scan is still stepping
drain()
check("a list update during a scan is queued and run after it", PR.catalogue.Enchanting
  and PR.catalogue.Enchanting.complete == true)

-- ---------------------------------------------------------------- /ledger prof
SlashCmdList.WIZARDRYLEDGERFOREVER("prof")
local line = printed("First Aid 61/75")
check("/ledger prof: rank, crafts and skill-ups", line and line:find("6 crafts, 2 skill-ups", 1, true))
check("/ledger prof: reagents used, with the item fallback", line and line:find("Used: 7 item:2589", 1, true))
check("/ledger prof: skill-ups from other spells shown", printed("(+1 from other spells)") ~= nil)
S.printed = {}
SlashCmdList.WIZARDRYLEDGERFOREVER("prof first aid")
check("/ledger prof <name>: per-recipe rank rows", printed("Linen Bandage (3275, grey at 60)")
  and printed("59: 1 made, 1 up, green") and printed("(changed)"))
S.printed = {}
SlashCmdList.WIZARDRYLEDGERFOREVER("quests")
check("/ledger quests still answers", printed("quests seen") ~= nil)
S.printed = {}
SlashCmdList.WIZARDRYLEDGERFOREVER("prof alchemy")
check("an unknown profession is said so", printed("no profession called 'alchemy'") ~= nil)

-- ---------------------------------------------------------------- guards
check("no profession errors recorded", B.professionErrors == nil)
local savedTS = C_TradeSkillUI
C_TradeSkillUI = nil
check("no profession namespace: opening a window is a no-op", pcall(fire, "TRADE_SKILL_SHOW"))
C_TradeSkillUI = savedTS
local savedReady = C_TradeSkillUI.IsTradeSkillReady
C_TradeSkillUI.IsTradeSkillReady = nil
PR.catalogue.Cooking = nil
S.prof = "First Aid"
fire("TRADE_SKILL_SHOW")
local polls = drain()
check("a client without IsTradeSkillReady stops polling after its tries", polls <= 25)
C_TradeSkillUI.IsTradeSkillReady = savedReady

-- ---------------------------------------------------------------- earlier builds: stale, prune, size
-- docs/COWORK_BRIEF_forever_ledger_save_hygiene.md. The older bucket's shape is the 70009
-- bucket as the 1 Oct save holds it (tools/ledger_sizes.py, 2026-10-01): quests, and a
-- professions table with catalogue and chars.
local function ser(v)
  if type(v) ~= "table" then return tostring(v) end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. ser(v[k]) end
  return "{" .. table.concat(parts, ",") .. "}"
end
local OLD = "1.60.1-69977"
WizardryLedgerDB.forever.builds[OLD] = { created = "y", sessions = 9,
  quests = { [443] = { band = "legacy", title = "Rot Hide Ichor",
    turnins = { ["Classic Beta PvP-Bloodandt"] = { xp = 1250, money = 900 } } } },
  professions = { schema = 2,
    catalogue = { ["First Aid"] = { count = 32, complete = true, recipes = { [3275] = { name = "Linen Bandage" } } } },
    chars = { ["Classic Beta PvP-Bloodandt"] = { skills = { ["First Aid"] = { rank = 40 } },
      learned = { [3275] = true }, other = {}, crafts = { [3275] = { [40] = { n = 3, ups = 2 } } } } } } }
ns.PRinit()
local OB = WizardryLedgerDB.forever.builds[OLD]
check("at load an earlier build's catalogue is marked stale, and kept",
  OB.professions.stale == "1.60.1-70009" and OB.professions.catalogue ~= nil)
check("the current build is not marked stale", B.professions.stale == nil)
local quests0, chars0, curCat0 = ser(OB.quests), ser(OB.professions.chars), ser(B.professions.catalogue)
S.printed = {}
SlashCmdList.WIZARDRYLEDGERFOREVER("prune")
check("/ledger prune without confirm lists and changes nothing", OB.professions.catalogue ~= nil
  and printed("would remove build 1.60.1-69977") and printed("nothing changed"))
S.printed = {}
SlashCmdList.WIZARDRYLEDGERFOREVER("prune confirm")
check("/ledger prune confirm removes the earlier build's catalogue", OB.professions.catalogue == nil
  and OB.professions.pruned == "1.60.1-70009" and OB.professions.stale == nil and printed("removed build 1.60.1-69977"))
check("the current build's catalogue is untouched", ser(B.professions.catalogue) == curCat0)
check("the earlier build's quests are identical", ser(OB.quests) == quests0)
check("the earlier build's chars (crafts, skills, learned) are identical", ser(OB.professions.chars) == chars0)
S.printed = {}
SlashCmdList.WIZARDRYLEDGERFOREVER("prune confirm")
check("a second prune finds nothing to do", printed("no earlier build holds a recipe catalogue") ~= nil)
S.printed = {}
SlashCmdList.WIZARDRYLEDGERFOREVER("size")
check("/ledger size prints the largest subtrees", printed("size: the Ledger's table is ~")
  and printed("1.60.1-70009.professions.catalogue"))
check("/ledger prof still answers after a prune", (function() S.printed = {}
  SlashCmdList.WIZARDRYLEDGERFOREVER("prof"); return printed("First Aid 61/75") ~= nil end)())

-- ---------------------------------------------------------------- a complete catalogue never shrinks
-- 0.18.2 (docs/COWORK_BRIEF_forever_ledger_catalogue_guard.md). On 2026-09-29 the 70009 save's
-- Tailoring catalogue went from 470 recipes to 1 between two history copies
-- (tools/ledger_sizes.py, 2026-10-01). The shape here: the window reports First Aid but lists a
-- subset of its recipes.
do
  local FA0 = PR.catalogue["First Aid"]
  local rows0 = 0
  for _ in pairs(FA0.recipes) do rows0 = rows0 + 1 end
  FX.Short = { ids = { FX["First Aid"].ids[1], FX["First Aid"].ids[2], FX["First Aid"].ids[3] } }
  S.prof, S.list = "First Aid", "Short"
  fire("TRADE_SKILL_SHOW"); drain()
  local FA = PR.catalogue["First Aid"]
  local rows = 0
  for _ in pairs(FA.recipes) do rows = rows + 1 end
  check("a shorter list does not shrink a complete catalogue", FA.count == 32 and rows == rows0 and FA.complete == true)
  check("the short list is counted", FA.shortLists == 1 and FA.lastShort == 3)

  -- an older, smaller catalogue meets the full list: it grows, and keeps a row the list lacks
  local gone = FX["First Aid"].ids[4]
  FA.recipes[gone] = nil
  FA.count = 31
  FA.recipes[999999] = { name = "kept from an earlier window" }
  S.list = "First Aid"
  fire("TRADE_SKILL_SHOW"); drain()
  FA = PR.catalogue["First Aid"]
  check("a longer list rebuilds the catalogue", FA.count == 32 and FA.complete == true and FA.recipes[gone] ~= nil)
  check("a rebuild keeps rows already held", FA.recipes[999999] ~= nil and FA.shortLists == 1)
  FA.recipes[999999] = nil
  FX.Short = nil
end

-- ---------------------------------------------------------------- forbidden keys
local bad = {}
local function scan(t, path)
  for k, v in pairs(t) do
    if type(k) == "string" then
      local lk = k:lower()
      for _, word in ipairs({ "rate", "ratio", "delta", "per" }) do
        if lk == word or lk:find("^" .. word .. "[_A-Z]") or lk:find("_" .. word .. "$") then
          table.insert(bad, path .. "." .. k)
        end
      end
    end
    if type(v) == "table" then scan(v, path .. "." .. tostring(k)) end
  end
end
scan(WizardryLedgerDB, "db")
check("no rate/ratio/delta/per keys (" .. table.concat(bad, ",") .. ")", #bad == 0)

-- ---------------------------------------------------------------- files
local function read(p) local f = io.open(p, "rb"); if not f then return nil end local s = f:read("*a"); f:close(); return s end
local camelot = read(addonDir .. "/WizardryLedger_Camelot.toc") or ""
-- The version is no longer pinned here: each later Forever round bumps it, and its own test
-- checks it (forever_ledger_levels_loot, 2026-10-01). The order of these two lines still is.
check("camelot toc: the quest recorder then the profession recorder",
  camelot:find("\nForever\\QuestRecorder.lua\r?\nForever\\ProfessionRecorder.lua") ~= nil)
local tbc = read(addonDir .. "/WizardryLedger.toc") or ""
check("TBC toc still 20506 and lists no Forever file", tbc:find("## Interface: 20506", 1, true) ~= nil
  and not tbc:find("Forever", 1, true))

print(string.format("%d passed, %d failed", passes, fails))
os.exit(fails == 0 and 0 or 1)
