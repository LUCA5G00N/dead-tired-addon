-- WizardryLedger, Forever line: the profession recorder.
--
-- WHY. The operator wants the materials it takes to level a profession (not the gold: he
-- gathers most of them himself). That needs two facts the client states and nothing on disk
-- does: what each recipe takes, and what each craft gave. This file writes both down.
-- docs/COWORK_BRIEF_forever_profession_recorder.md is the brief.
--
-- WHAT THE CLIENT WAS SEEN TO DO (/probe recipes, Probe 0.9.0, build 70009, 2026-09-25):
--   * A recipe ID is the spell the craft casts. 3275 (Linen Bandage) and 3276 (Heavy Linen
--     Bandage) were the spells captured before 58 First Aid skill-ups.
--   * C_TradeSkillUI.GetRecipeSchematic(id, false) -> { outputItemID, quantityMin,
--     quantityMax, reagentSlotSchematics = { { quantityRequired, required,
--     reagents = { { itemID } } } } }.
--   * GetRecipeInfo(id) -> { name, learned, relativeDifficulty, maxTrivialLevel, categoryID }.
--     relativeDifficulty: 0 orange, 1 yellow, 2 green, 3 grey, matching the window.
--     **For an unlearned recipe it always reads 0**, so it is recorded only at a craft.
--   * GetRecipeRequirements(id) -> { { name, met, type } } (Cooking Fire, Runed Copper Rod).
--   * C_SkillInfo.GetSkillLineInfo(i) -> { name, rank, maxRank, isHeader,
--     skillLineCategoryID }: 11 professions, 9 secondary skills, 6 weapons. Each profession
--     is listed twice (parent and child ID) with the same name, so rows are keyed by name.
--
-- THE OBSERVER'S RULES, as in QuestRecorder.lua:
--   * Facts, never rates. What /ledger prof prints is computed when printed, never stored.
--   * A craft is the cast event; its skill-up is the CHAT_MSG_SKILL for the same profession
--     within ATTRIB seconds. Nothing is inferred from bag or skill diffs.
--
-- WHERE THINGS ARE KEPT. WizardryLedgerDB.forever.builds[<version-build>].professions:
--   catalogue[<profession>] = { count, skillLineID, complete, steps, readyTries,
--       recipes[<recipeID>] = { name, categoryID, trivial, out, qMin, qMax,
--                               reagents = { { item = id | { id, ... }, qty, required } },
--                               needs = { <tool or fire>, ... } } }
--   chars[<Realm-Name>] = {
--       skills[<profession>]  = { rank, max, cat },
--       learned[<recipeID>]   = true,
--       crafts[<recipeID>][<rank before the cast>] = { n, ups, rd, rdChanged },
--       other[<profession>][<spellID> | "none"]    = { ups } }
--
-- FIXED IN 0.15.1, both found by the first UAT session (2026-09-25, 4fab3b5):
--   * On opening a window the client can report the NEW profession from
--     GetBaseProfessionInfo while GetAllRecipeIDs still returns the PREVIOUS one's list.
--     0.15.0 filed recipes under the base name, so First Aid held smelting recipes and
--     Mining held cooking ones. Each recipe is now filed under the profession it reports
--     itself, GetTradeSkillLineForRecipe(id) -> (childLineID, name, parentLineID), which
--     the probe saw agree with the window on all 23 recipes it asked. The base profession
--     is no longer read. A stale list now fills the right profession, or nothing.
--   * At ADDON_LOADED on a cold login UnitName("player") answers "Unknown". The character
--     is now attached at PLAYER_LOGIN, and a name of "Unknown" is never used as a key.
--   A catalogue written before schema 2 is dropped at load; crafts are keyed by recipe
--   and survive.
--
-- EARLIER BUILDS' CATALOGUES (0.17.0, docs/COWORK_BRIEF_forever_ledger_save_hygiene.md).
--   Each build bucket gets its own catalogue, so every new build re-captures every window the
--   characters open. Measured 2026-10-01 with tools/ledger_sizes.py: the 70009 catalogue was
--   588,453 of a 1,417,293-byte save (41.5%), and 70124's another 494,959.
--   * At load, every OTHER build's professions table that still has a catalogue is marked
--     `stale = <current build key>`. Nothing is removed.
--   * /ledger prune lists what would go. /ledger prune confirm removes `catalogue` from every
--     non-current build's professions table, and NOTHING ELSE: chars, crafts, skills, learned
--     flags and every quest row stay. The table is marked `pruned = <current build key>`.
--     Crafts are keyed by recipe ID and the current catalogue still names them.
--   * /ledger size prints the save's largest subtrees, measured by an approximate walk (keys,
--     values and four characters per entry); tools/ledger_sizes.py is the exact measure.
--
-- A COMPLETE CATALOGUE NEVER SHRINKS (0.18.2, docs/COWORK_BRIEF_forever_ledger_catalogue_guard.md).
--   A window listing fewer recipes than a complete catalogue holds is counted in `shortLists`
--   (with `lastShort`, its size) and does not rebuild it. A longer list rebuilds, carrying every
--   row already held. So `count` and the rows only ever go up within a build.
--
-- UNOBSERVED ON THIS CLIENT, and so guarded: TRADE_SKILL_LIST_UPDATE (registered under
-- pcall), C_Item.GetItemNameByID (falls back to "item:<id>"), and whether GetRecipeInfo
-- answers with no profession window open (a craft then records rd = nil).

local ADDON, ns = ...
ns = ns or {}

local SCHEMA = 2
local ATTRIB = 1.0            -- seconds a skill-up may follow the cast it is credited to
local BATCH = 25              -- recipes read per frame step while building a catalogue
local READY_TRIES = 20        -- IsTradeSkillReady polls on opening a window
local READY_DELAY = 0.25
local SKILL_ROWS_MAX = 80
local PROFESSION_CATS = { [9] = true, [11] = true }
local COLOUR = { [0] = "orange", [1] = "yellow", [2] = "green", [3] = "grey" }
local SKILL_PATTERN = "^Your skill in (.+) has increased to (%d+)%.?$"

-- ---------------------------------------------------------------- guarded reads

local WZ = ns.WZ
local secret = WZ.secret
local try = WZ.try
local clean = WZ.clean
local now = WZ.now
local stamp = WZ.stamp
local build = WZ.build
local charKey = WZ.charKey
local after = WZ.after
local out = WZ.out

-- nil until the client knows who is playing (see the header: "Unknown" at ADDON_LOADED).

local function TS() return type(C_TradeSkillUI) == "table" and C_TradeSkillUI or nil end

-- ---------------------------------------------------------------- the store

local bucket, P, me
local index = {}    -- [recipeID] = profession name, rebuilt from the catalogue at load

local function initDB()
  if type(WizardryLedgerDB) ~= "table" then WizardryLedgerDB = {} end
  local f = WizardryLedgerDB.forever
  if type(f) ~= "table" then f = {}; WizardryLedgerDB.forever = f end
  f.builds = type(f.builds) == "table" and f.builds or {}
  local key = build()
  -- The quest recorder owns `sessions` and `quests`. If this file's ADDON_LOADED runs first,
  -- the bucket is created in the shape the quest recorder expects and it counts the session.
  local b = f.builds[key]
  if type(b) ~= "table" then b = { created = stamp(), sessions = 0, quests = {} }; f.builds[key] = b end
  b.professions = type(b.professions) == "table" and b.professions or {}
  P = b.professions
  if P.schema ~= SCHEMA then P.catalogue = {}; P.schema = SCHEMA end
  P.catalogue = type(P.catalogue) == "table" and P.catalogue or {}
  P.chars = type(P.chars) == "table" and P.chars or {}
  for other, ob in pairs(f.builds) do
    if other ~= key and type(ob) == "table" and type(ob.professions) == "table"
       and type(ob.professions.catalogue) == "table" then
      ob.professions.stale = key
    end
  end
  bucket = b
  index = {}
  for name, cat in pairs(P.catalogue) do
    if type(cat) == "table" and type(cat.recipes) == "table" then
      for id in pairs(cat.recipes) do index[id] = name end
    end
  end
  ns.PRbucket = b
  return b
end
ns.PRinit = initDB

-- Attach this character's table once the client can name the character. Returns true
-- when attached. Every handler that writes per-character facts checks `me` first.
local function attach()
  if me then return true end
  if not P then return false end
  local ck = charKey()
  if not ck then return false end
  me = type(P.chars[ck]) == "table" and P.chars[ck] or {}
  P.chars[ck] = me
  for _, k in ipairs({ "skills", "learned", "crafts", "other", "lines", "ups" }) do
    me[k] = type(me[k]) == "table" and me[k] or {}
  end
  return true
end
ns.PRattach = attach

-- ---------------------------------------------------------------- skill ranks

-- 0.26.0 (docs/COWORK_BRIEF_forever_ledger_skill_cohorts.md): every row that levels is also
-- kept in `lines`, grouped by ns.SKcohort (Cohorts.lua). `skills` is unchanged. Forever lists
-- each profession twice under two skill IDs with one name; they collapse to one `lines` row,
-- and if the two ever disagree both are kept in `twinMismatch` (a stop condition, not a fix).
local function readSkills()
  if not me and not attach() then return end
  if type(C_SkillInfo) ~= "table" then return end
  local n = tonumber((try(C_SkillInfo.GetNumSkillLines))) or 0
  local cohort = ns.SKcohort
  local lines, seen = {}, 0
  for i = 1, math.min(n, SKILL_ROWS_MAX) do
    local row = try(C_SkillInfo.GetSkillLineInfo, i)
    if type(row) == "table" then
      seen = seen + 1
      local header = clean(row.isHeader)
      local cat = clean(row.skillLineCategoryID)
      local name = clean(row.name)
      local rank, max = clean(row.rank), clean(row.maxRank)
      if not header and PROFESSION_CATS[cat] and type(name) == "string" and name ~= "" then
        me.skills[name] = { rank = rank, max = max, cat = cat }
      end
      local c, guess
      if type(cohort) == "function" then c, guess = cohort(name, cat, max, header) end
      if c then
        local had = lines[name]
        if had and (had.rank ~= rank or had.max ~= max) then
          me.twinMismatch = type(me.twinMismatch) == "table" and me.twinMismatch or {}
          me.twinMismatch[name] = { { rank = had.rank, max = had.max }, { rank = rank, max = max } }
        elseif not had then
          lines[name] = { rank = rank, max = max, cat = cat, cohort = c, guess = guess or nil }
        end
      end
    end
  end
  if seen > 0 and type(cohort) == "function" then me.lines = lines end
end

-- ---------------------------------------------------------------- the catalogue

local function recipeRow(T, id)
  local info = try(T.GetRecipeInfo, id)
  if type(info) ~= "table" then return nil, false end
  local row = { name = clean(info.name), categoryID = clean(info.categoryID),
                trivial = clean(info.maxTrivialLevel) }
  local sch = try(T.GetRecipeSchematic, id, false)
  if type(sch) == "table" then
    row.out = clean(sch.outputItemID)
    row.qMin, row.qMax = clean(sch.quantityMin), clean(sch.quantityMax)
    local reagents = {}
    if type(sch.reagentSlotSchematics) == "table" then
      for _, slot in ipairs(sch.reagentSlotSchematics) do
        local items = {}
        if type(slot) == "table" and type(slot.reagents) == "table" then
          for _, r in ipairs(slot.reagents) do
            local item = type(r) == "table" and clean(r.itemID)
            if type(item) == "number" then items[#items + 1] = item end
          end
        end
        if #items > 0 then
          reagents[#reagents + 1] = { item = (#items == 1) and items[1] or items,
                                      qty = clean(slot.quantityRequired), required = clean(slot.required) }
        end
      end
    end
    row.reagents = reagents
  end
  local req = try(T.GetRecipeRequirements, id)
  if type(req) == "table" then
    local needs = {}
    for _, r in ipairs(req) do
      local nm = type(r) == "table" and clean(r.name)
      if type(nm) == "string" and nm ~= "" then needs[#needs + 1] = nm end
    end
    if #needs > 0 then row.needs = needs end
  end
  return row, clean(info.learned) == true
end

local function learnedOnly(T, id)
  local info = try(T.GetRecipeInfo, id)
  return type(info) == "table" and clean(info.learned) == true
end

local scanning, rescan = false, false
local listUpdateSeen = false

-- The profession a recipe says it belongs to: name and parent line ID, e.g. First Aid, 129.
local function lineOf(T, id)
  local _, name, parent = try(T.GetTradeSkillLineForRecipe, id)
  name, parent = clean(name), clean(parent)
  if type(name) ~= "string" or name == "" then return nil end
  return name, parent
end

-- Two passes over the open window's recipe list, BATCH ids per frame step:
--   1. file every id under the profession it reports, and refresh this character's
--      learned set;
--   2. for each profession whose stored catalogue is missing, incomplete, of another
--      schema or a different size, build it afresh from its own ids.
-- Nothing in either pass depends on which profession the window claims to be.
local function scan(tries)
  local T = TS()
  if not T or not P then scanning = false return end
  if try(T.IsTradeSkillReady) ~= true then
    if tries < READY_TRIES and after(READY_DELAY, function() scan(tries + 1) end) then return end
    scanning = false
    return
  end
  local list = try(T.GetAllRecipeIDs)
  if type(list) ~= "table" then scanning = false return end
  local ids = {}
  for _, id in ipairs(list) do if type(clean(id)) == "number" then ids[#ids + 1] = id end end
  table.sort(ids)

  local groups, parents, order, unfiled = {}, {}, {}, 0
  local todo, t = {}, 1

  local function finish()
    scanning = false
    if rescan then rescan = false; ns.PRscan() end
  end

  local function build()
    if t > #todo then finish() return end
    local last = math.min(t + BATCH - 1, #todo)
    local touched = {}
    for j = t, last do
      local job = todo[j]
      local row = recipeRow(T, job.id)
      if row then job.cat.recipes[job.id] = row; index[job.id] = job.name end
      if job.extra and row then job.cat.count = (job.cat.count or 0) + 1 end
      touched[job.cat] = true
      job.cat.left = job.cat.left - 1
      if job.cat.left == 0 then job.cat.complete = true; job.cat.left = nil end
    end
    for cat in pairs(touched) do cat.steps = cat.steps + 1 end
    t = last + 1
    if t <= #todo then if not after(0, build) then build() end return end
    finish()
  end

  local i = 1
  local function file()
    local last = math.min(i + BATCH - 1, #ids)
    for j = i, last do
      local id = ids[j]
      local name, parent = lineOf(T, id)
      if name then
        if not groups[name] then groups[name] = {}; parents[name] = parent; order[#order + 1] = name end
        table.insert(groups[name], id)
        if me and learnedOnly(T, id) then me.learned[id] = true end
      else
        unfiled = unfiled + 1
      end
    end
    i = last + 1
    if i <= #ids then if not after(0, file) then file() end return end
    for _, name in ipairs(order) do
      local g, cat = groups[name], P.catalogue[name]
      local whole = type(cat) == "table" and cat.complete and type(cat.recipes) == "table"
      if whole and #g < (cat.count or 0) then
        -- 0.18.2: a complete catalogue never shrinks. On 2026-09-29 a window listing one
        -- Tailoring recipe replaced the 470-recipe catalogue. A shorter list is recorded
        -- and otherwise ignored; any ids it carries that the catalogue lacks are added.
        cat.shortLists = (cat.shortLists or 0) + 1
        cat.lastShort = #g
        local added = 0
        for _, id in ipairs(g) do
          index[id] = name
          if not cat.recipes[id] then
            todo[#todo + 1] = { id = id, name = name, cat = cat, extra = true }
            added = added + 1
          end
        end
        if added > 0 then cat.left = (cat.left or 0) + added; cat.complete = false end
      elseif not whole or cat.count ~= #g then
        -- New, incomplete, or longer: (re)build. Rows already held are carried over, so a
        -- rebuild adds to the catalogue and never loses a recipe it had.
        local keep = (type(cat) == "table" and type(cat.recipes) == "table") and cat.recipes or {}
        local before = 0
        for _ in pairs(keep) do before = before + 1 end
        cat = { count = #g, skillLineID = parents[name], recipes = keep, complete = false,
                steps = 0, left = #g, readyTries = tries, listUpdateSeen = listUpdateSeen or nil,
                unfiled = unfiled > 0 and unfiled or nil,
                shortLists = type(P.catalogue[name]) == "table" and P.catalogue[name].shortLists or nil }
        P.catalogue[name] = cat
        for _, id in ipairs(g) do todo[#todo + 1] = { id = id, name = name, cat = cat } end
      else
        for _, id in ipairs(g) do index[id] = name end
      end
    end
    build()
  end
  file()
end

function ns.PRscan()
  if scanning then rescan = true return end
  scanning = true
  scan(1)
end

-- ---------------------------------------------------------------- crafts and skill-ups

local lastCast   -- { at, spell, recipe, prof, row }

local function onCast(unit, _, spellID)
  if unit ~= "player" then return end
  if not me and not attach() then return end
  spellID = clean(spellID)
  if type(spellID) ~= "number" then return end
  local prof = index[spellID]
  if prof and me.learned[spellID] then
    local sk = me.skills[prof]
    local rank = sk and sk.rank or "?"
    local T = TS()
    local info = T and try(T.GetRecipeInfo, spellID)
    local rd = type(info) == "table" and clean(info.relativeDifficulty) or nil
    local byRank = me.crafts[spellID]
    if type(byRank) ~= "table" then byRank = {}; me.crafts[spellID] = byRank end
    local row = byRank[rank]
    if type(row) ~= "table" then row = { n = 0, ups = 0, rd = rd }; byRank[rank] = row end
    row.n = row.n + 1
    if row.rd == nil then row.rd = rd
    elseif rd ~= nil and rd ~= row.rd then row.rdChanged = true end
    lastCast = { at = now(), spell = spellID, recipe = spellID, prof = prof, row = row }
  else
    lastCast = { at = now(), spell = spellID }
  end
end

-- ---------------------------------------------------------------- skill-up rows
-- 0.27.0 (docs/COWORK_BRIEF_forever_ledger_skillup_rows.md): one row per skill-up chat line
-- for any line `lines` holds: { t, l, c, r, map, x, y, z, s, src, rp }. Absent means the client
-- did not say. GetRealZoneText / GetSubZoneText are unobserved on this client (0012): guarded,
-- and anything but a non-empty string is stored as nothing.
local place = WZ.place   -- 0.28.0: map, x, y, zone, subzone (Core.lua)

local topRank   -- [line] = highest r in ups, seeded from the save on first use this session

local function addRow(name, line, to, src)
  if type(me.ups) ~= "table" then me.ups = {} end
  if not topRank then
    topRank = {}
    for _, row in ipairs(me.ups) do
      if type(row) == "table" and row.l and type(row.r) == "number"
         and (topRank[row.l] or -1) < row.r then topRank[row.l] = row.r end
    end
  end
  local r = tonumber(to)
  local map, x, y, z, s = place()
  local row = { t = stamp(), l = name, c = line.cohort, r = r, map = map, x = x, y = y,
    z = z, s = s, src = src }
  if r and topRank[name] and r <= topRank[name] then row.rp = true end
  if r and (topRank[name] or -1) < r then topRank[name] = r end
  me.ups[#me.ups + 1] = row
end

local function onSkill(text)
  if not me and not attach() then return end
  text = clean(text)
  if type(text) ~= "string" then return end
  local name, to = text:match(SKILL_PATTERN)
  if not name then return end
  if not me.skills[name] then readSkills() end
  local sk = me.skills[name]
  local line = type(me.lines) == "table" and me.lines[name] or nil
  if line then line.rank = tonumber(to) or line.rank end
  local lc = lastCast
  local fresh = lc and not lc.credited and (now() - lc.at) <= ATTRIB
  if not sk then                                    -- a weapon skill: its rank and a row only
    if line then addRow(name, line, to, fresh and lc.spell or nil) end
    return
  end
  if line then addRow(name, line, to, fresh and lc.spell or nil) end
  if fresh and lc.recipe and lc.prof == name then
    lc.row.ups = lc.row.ups + 1
    lc.credited = true
  else
    local o = me.other[name]
    if type(o) ~= "table" then o = {}; me.other[name] = o end
    local key = fresh and lc.spell or "none"
    if fresh then lc.credited = true end
    o[key] = o[key] or { ups = 0 }
    o[key].ups = o[key].ups + 1
  end
  sk.rank = tonumber(to) or sk.rank
end

-- ---------------------------------------------------------------- /ledger prof

local function itemName(id)
  local n = C_Item and clean(try(C_Item.GetItemNameByID, id))
  return (type(n) == "string" and n ~= "") and n or ("item:" .. tostring(id))
end

local function sortedKeys(t, cmp)
  local k = {}
  for key in pairs(t) do k[#k + 1] = key end
  table.sort(k, cmp or function(a, b) return tostring(a) < tostring(b) end)
  return k
end

-- Totals for one profession, computed here and never stored.
function ns.PRtotals(prof)
  local tot = { crafts = 0, ups = 0, other = 0, used = {}, recipes = {} }
  if not me and not attach() then return tot end
  local cat = P.catalogue[prof]
  for id, byRank in pairs(me.crafts) do
    if index[id] == prof and type(byRank) == "table" then
      local made = 0
      for _, row in pairs(byRank) do
        tot.crafts = tot.crafts + (row.n or 0)
        tot.ups = tot.ups + (row.ups or 0)
        made = made + (row.n or 0)
      end
      tot.recipes[#tot.recipes + 1] = id
      local r = cat and cat.recipes and cat.recipes[id]
      for _, rg in ipairs(r and r.reagents or {}) do
        local item = type(rg.item) == "table" and rg.item[1] or rg.item
        if item then tot.used[item] = (tot.used[item] or 0) + made * (rg.qty or 1) end
      end
    end
  end
  for _, e in pairs(me.other[prof] or {}) do tot.other = tot.other + (e.ups or 0) end
  table.sort(tot.recipes)
  return tot
end

-- ---------------------------------------------------------------- prune and size

local function builds()
  local f = type(WizardryLedgerDB) == "table" and WizardryLedgerDB.forever
  return type(f) == "table" and type(f.builds) == "table" and f.builds or {}
end

-- Approximate serialised size: keys, values, and four characters of overhead per entry.
local function approx(v, depth)
  depth = depth or 0
  if type(v) == "string" then return #v + 2 end
  if type(v) ~= "table" then return #tostring(v) end
  if depth > 40 then return 0 end
  local n = 2
  for k, child in pairs(v) do
    n = n + approx(k, depth + 1) + approx(child, depth + 1) + 4
  end
  return n
end
ns.PRapprox = approx

-- The non-current builds whose professions table still holds a catalogue.
function ns.PRprunable()
  local cur, list = build(), {}
  for key, b in pairs(builds()) do
    if key ~= cur and type(b) == "table" and type(b.professions) == "table"
       and type(b.professions.catalogue) == "table" then
      list[#list + 1] = key
    end
  end
  table.sort(list)
  return list
end

function ns.PRprune(confirm)
  local list = ns.PRprunable()
  if #list == 0 then out("prune: no earlier build holds a recipe catalogue.") return 0 end
  local all = builds()
  local removed = 0
  for _, key in ipairs(list) do
    local pt = all[key].professions
    local n, bytes = 0, approx(pt.catalogue)
    for _ in pairs(pt.catalogue) do n = n + 1 end
    if confirm then
      pt.catalogue = nil
      pt.stale = nil
      pt.pruned = build()
      removed = removed + 1
      out(string.format("prune: removed build %s's catalogue (%d professions, ~%d bytes).", key, n, bytes))
    else
      out(string.format("prune: would remove build %s's catalogue (%d professions, ~%d bytes). Nothing else.", key, n, bytes))
    end
  end
  if not confirm then out("prune: nothing changed. /ledger prune confirm to remove them.") end
  return removed
end

function ns.PRsize()
  local rows = {}
  local total = approx(WizardryLedgerDB)
  for key, b in pairs(builds()) do
    if type(b) == "table" then
      rows[#rows + 1] = { name = key, n = approx(b) }
      for _, part in ipairs({ "quests", "professions", "levels", "loot", "log" }) do
        if type(b[part]) == "table" then
          rows[#rows + 1] = { name = key .. "." .. part, n = approx(b[part]) }
        end
      end
      if type(b.professions) == "table" and type(b.professions.catalogue) == "table" then
        rows[#rows + 1] = { name = key .. ".professions.catalogue", n = approx(b.professions.catalogue) }
      end
    end
  end
  table.sort(rows, function(a, c) if a.n ~= c.n then return a.n > c.n end return a.name < c.name end)
  out(string.format("size: the Ledger's table is ~%d bytes (approximate; tools/ledger_sizes.py is exact).", total))
  for i = 1, math.min(12, #rows) do
    out(string.format("  ~%d  %s", rows[i].n, rows[i].name))
  end
end

local function upsSlash(arg)
  local rows = type(me.ups) == "table" and me.ups or {}
  local pick = {}
  for i = #rows, 1, -1 do
    local r = rows[i]
    if type(r) == "table" and (arg == "" or tostring(r.l or ""):lower() == arg) then
      pick[#pick + 1] = r
      if #pick == 10 then break end
    end
  end
  if #pick == 0 then
    out(arg == "" and "ups: no skill-up rows yet." or ("ups: no rows for '" .. arg .. "'."))
    return
  end
  for i = #pick, 1, -1 do
    local r = pick[i]
    local t = tostring(r.t or "?")
    local where = r.z and (r.z .. (r.s and r.s ~= r.z and (" (" .. r.s .. ")") or "")) or
      (r.map and ("map " .. r.map) or "no place")
    local xy = (r.x and r.y) and string.format(" %.1f, %.1f", r.x * 100, r.y * 100) or ""
    out(string.format("%s %s · %s %s · %s%s%s", tostring(r.l), tostring(r.r), t:sub(12, 16),
      t:sub(1, 10), where, xy, r.rp and " (replay)" or ""))
  end
end

function ns.PRslash(msg)
  msg = msg or ""
  if msg:find("^prune") then return ns.PRprune(msg:match("^prune%s+confirm%s*$") ~= nil) end
  if msg:find("^size") then return ns.PRsize() end
  if not me and not attach() then out("the character isn't known yet.") return end
  if msg:find("^ups") then return upsSlash((msg:match("^ups%s*(.*)$") or ""):lower()) end
  local arg = (msg or ""):match("^prof%s*(.*)$") or ""
  if arg == "" then
    readSkills()
    local function profLine(prof)
      local sk, t = me.skills[prof], ns.PRtotals(prof)
      local used = {}
      for _, item in ipairs(sortedKeys(t.used)) do
        used[#used + 1] = string.format("%d %s", t.used[item], itemName(item))
      end
      return string.format("%s %s/%s: %d crafts, %d skill-ups%s.%s", prof, tostring(sk.rank),
        tostring(sk.max), t.crafts, t.ups,
        t.other > 0 and string.format(" (+%d from other spells)", t.other) or "",
        #used > 0 and (" Used: " .. table.concat(used, ", ") .. ".") or "")
    end
    local lines = type(me.lines) == "table" and me.lines or {}
    if next(lines) == nil or type(ns.SKCOHORTS) ~= "table" then
      -- No groups yet (no skill rows read, or Cohorts.lua absent): the 0.25 printout.
      local names = sortedKeys(me.skills)
      if #names == 0 then out("no professions seen on this character yet.") return end
      for _, prof in ipairs(names) do out(profLine(prof)) end
      return
    end
    for _, c in ipairs(ns.SKCOHORTS) do
      local names = {}
      for name, l in pairs(lines) do if l.cohort == c then names[#names + 1] = name end end
      table.sort(names)
      out((ns.SKCOHORT_TITLE[c] or c) .. ":" .. (#names == 0 and " none" or ""))
      for _, name in ipairs(names) do
        local l = lines[name]
        local text = me.skills[name] and profLine(name)
          or string.format("%s %s/%s", name, tostring(l.rank), tostring(l.max))
        if l.guess then text = text .. string.format(" (group guessed from category %s)", tostring(l.cat)) end
        out("  " .. text)
      end
    end
    return
  end
  local prof
  for name in pairs(me.skills) do if name:lower() == arg then prof = name end end
  for name in pairs(P.catalogue) do if not prof and name:lower() == arg then prof = name end end
  if not prof then out("no profession called '" .. arg .. "'. /ledger prof lists yours.") return end
  local t = ns.PRtotals(prof)
  local cat = P.catalogue[prof]
  out(string.format("%s: %d recipe(s) in the catalogue, %d crafted.", prof,
    cat and cat.count or 0, #t.recipes))
  for _, id in ipairs(t.recipes) do
    local r = cat and cat.recipes[id]
    local parts = {}
    for _, rank in ipairs(sortedKeys(me.crafts[id], function(a, b)
        return (tonumber(a) or -1) < (tonumber(b) or -1) end)) do
      local row = me.crafts[id][rank]
      parts[#parts + 1] = string.format("%s: %d made, %d up, %s%s", tostring(rank), row.n or 0,
        row.ups or 0, COLOUR[row.rd] or "?", row.rdChanged and " (changed)" or "")
    end
    out(string.format("  %s (%d, grey at %s): %s", tostring(r and r.name or id), id,
      tostring(r and r.trivial or "?"), table.concat(parts, "; ")))
  end
end

-- ---------------------------------------------------------------- wiring

local handlers = {
  TRADE_SKILL_SHOW = function() ns.PRscan() end,
  TRADE_SKILL_LIST_UPDATE = function() listUpdateSeen = true; ns.PRscan() end,
  SKILL_LINES_CHANGED = readSkills,
  PLAYER_LOGIN = readSkills,
  PLAYER_ENTERING_WORLD = readSkills,
  UNIT_SPELLCAST_SUCCEEDED = onCast,
  CHAT_MSG_SKILL = onSkill,
}
ns.PRhandlers = handlers

-- Wiring: Core.lua (docs/COWORK_BRIEF_forever_wizardry_core.md).
ns.PRframe = WZ.module({
  id = "professions",
  events = handlers,
  init = function() initDB(); readSkills() end,
  ready = function() return bucket end,
  errorKey = "professionErrors", lastKey = "lastProfessionError",
  slash = { prof = ns.PRslash, prune = ns.PRslash, size = ns.PRslash, ups = ns.PRslash },
})
