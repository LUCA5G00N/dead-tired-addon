-- Dead Tired: guild quests, the first two arcs (dt_guildquests, 0.8.0; docs/COWORK_BRIEF_dt_guildquests.md,
-- rulings Q1-Q9, ratified by Tim's merge of PR #39, 24 Nov; version per PR #42). Tim's "Sweaty SoD
-- Achievement", 22 Nov; the Restless Dead Pilgrimage's first round.
--
-- Q1  Progress is the game's own: C_QuestLog.IsQuestFlaggedCompleted(<ID>), read guarded. A secret or failed
--     read is not done, shown as "...". Your own progress is never stored: it's read from the game each time.
-- Q2  The Sleeping Bag Pilgrimage: one quest, seven steps (QuestArcs.lua). Finished when step 7 is done.
--     Rekindle is optional: shown, never counted against finishing, skipped by Next step.
-- Q3  Friends of the Library: book by book over DT.WAY_BOOKS, with the next reward tier.
-- Q4  Shared by default, with an opt-out (a ruled exception to rule 5: CLAUDE.md). QUESTS { bag, lib }
--     15 s after login and after one of our quests is turned in; share off sends QUESTS {off=1}.
-- Q5  The Waypointer hand-off: DT.waySet, as /dt way list does. Way.lua is not changed.
-- Q6  The guild board, first-to-the-bag footer. Q7 One window, two tabs. Q8 Quiet. Q9 0.8.0.
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local LOGIN_WAIT = 15
local BOARD_CAP = 200
local MAX_AGE = 30 * 86400
local NAME_MAX = 48
local BAG_TOTAL = 7

local TITLE = "Guild quests"
local TAB_BAG, TAB_LIB = "The Sleeping Bag", "The Library"
local BOARD_EMPTY = "Nobody's sharing yet. Be the first fool on the road."
local CLOSING = "Only guildies running the addon who share their quests."
local FIRST = "First to the bag: %s."
local NO_CONTINENT = "No unread books on this continent."
local OFF = "quests.enabled = off"
local USAGE = "/dt quests [share on|off]"
local UNKNOWN = "\226\128\166"                -- "…"
local BAG_ICON = "|TInterface\\Icons\\INV_Misc_Bag_10:0|t "

-- ---------------------------------------------------------------- the store

local function store()
  local db = DT.db()
  if type(db.quests) ~= "table" then db.quests = {} end
  local s = db.quests
  if type(s.board) ~= "table" then s.board = {} end
  if type(s.bad) ~= "number" then s.bad = 0 end
  return s
end
local function board() return store().board end
local function bad() local s = store(); s.bad = s.bad + 1 end

local function epoch()
  local t = clean(try(time))
  return type(t) == "number" and t or nil
end

local function shareOn() return DT.get("quests", "share") == true end

-- ---------------------------------------------------------------- the game's own reads (Q1)

-- "done", "no", or "unknown" (a failed or secret read).
local function flag(id)
  local v = clean(try(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted, id))
  if v == true then return "done" end                                      -- guard: a failed read is not done
  if v == false then return "no" end
  return "unknown"
end
DT.questFlag = flag

local function onQuest(id)
  return clean(try(C_QuestLog and C_QuestLog.IsOnQuest, id)) == true
end

local function alliance()
  return clean(try(UnitFactionGroup, "player")) == "Alliance"              -- guard: the faction picks step 1's ID
end

local function stepId(s) return (alliance() and s[4]) or s[3] end

-- Our quest IDs: the bag's (both factions), the books, the tiers' rewards. Only these are ever read or sent.
local ours, bookIds
local function ids()
  if ours then return ours, bookIds end
  ours, bookIds = {}, {}
  for _, s in ipairs(DT.QUEST_BAG or {}) do
    ours[s[3]] = true
    if s[4] then ours[s[4]] = true end
  end
  for _, b in ipairs(DT.WAY_BOOKS or {}) do
    if type(b[5]) == "number" then ours[b[5]] = true; bookIds[b[5]] = true end
  end
  for _, t in ipairs(DT.QUEST_LIB_TIERS or {}) do ours[t[2]] = true end
  return ours, bookIds
end

-- The bag arc, as the game says it stands now.
function DT.questBag()
  local steps = {}
  for _, s in ipairs(DT.QUEST_BAG or {}) do
    local id = stepId(s)
    local st = { n = s[1], name = s[2], id = id, zone = s[5], x = s[6], y = s[7], optional = s[8], note = s[9],
      state = flag(id) }
    if s[1] == 1 and st.state ~= "done" and onQuest(id) then              -- on step 1: its hand-in, not its start
      local h = DT.QUEST_BAG_HANDIN
      st.zone, st.x, st.y, st.handin = h[1], h[2], h[3], true
    end
    steps[#steps + 1] = st
  end
  local finished = steps[BAG_TOTAL] and steps[BAG_TOTAL].state == "done" or false
  local nextStep
  for _, st in ipairs(steps) do
    if not st.optional and st.state ~= "done" then nextStep = st; break end   -- guard: Rekindle never next
  end
  return steps, finished, nextStep
end

local function levelOf(text)
  local n = tonumber((text or ""):match("^(%d+)"))
  if n then return n end
  if text == "any" then return 0 end
  return 99
end

-- The library, book by book, as the game says it stands now.
function DT.questBooks()
  local books, count = {}, 0
  for i, b in ipairs(DT.WAY_BOOKS or {}) do
    local st = flag(b[5])
    if st == "done" then count = count + 1 end
    books[#books + 1] = { i = i, name = b[1], zone = b[2], x = b[3], y = b[4], id = b[5], lvl = b[6] ~= "" and b[6] or "-",
      level = levelOf(b[6]), note = b[7], state = st }
  end
  table.sort(books, function(a, c)
    if (a.state == "done") ~= (c.state == "done") then return c.state == "done" end   -- not done first
    if a.level ~= c.level then return a.level < c.level end
    return a.name:lower() < c.name:lower()
  end)
  return books, count
end

-- "14 books. 6 more to Greater Friend of the Library (20). Claimed: 10."
function DT.questTierLine(count, claimed)
  local parts = { count .. (count == 1 and " book." or " books.") }
  local nextTier
  for _, t in ipairs(DT.QUEST_LIB_TIERS or {}) do
    if count < t[1] then nextTier = t; break end                           -- guard: tier thresholds
  end
  if nextTier then
    parts[#parts + 1] = string.format("%d more to %s (%d).", nextTier[1] - count, nextTier[3], nextTier[1])
  else
    parts[#parts + 1] = "Every reward reached."
  end
  if claimed and #claimed > 0 then parts[#parts + 1] = "Claimed: " .. table.concat(claimed, ", ") .. "." end
  return table.concat(parts, " ")
end

local function claimedTiers()
  local out = {}
  for _, t in ipairs(DT.QUEST_LIB_TIERS or {}) do
    if flag(t[2]) == "done" then out[#out + 1] = t[1] end
  end
  return out
end

-- ---------------------------------------------------------------- sharing (Q4)

local function myPayload()
  local steps = DT.questBag()
  local bag = {}
  for _, st in ipairs(steps) do if st.state == "done" then bag[#bag + 1] = tostring(st.n) end end
  local lib = {}
  for _, b in ipairs(DT.WAY_BOOKS or {}) do
    if flag(b[5]) == "done" then lib[#lib + 1] = tostring(b[5]) end
  end
  return table.concat(bag), table.concat(lib, ",")
end

local redrawBoard

local function noteFirst(key, bag)
  local s = store()
  if s.first == nil and type(bag) == "string" and bag:find("7", 1, true) then   -- guard: first finisher kept once seen
    s.first = { key = key, at = epoch() }
  end
end

local function libList(text)
  local out = {}
  for id in (text or ""):gmatch("[^,]+") do out[#out + 1] = tonumber(id) end
  return out
end

local function send()
  if not shareOn() then return false end                                   -- guard: share switch (send)
  if not DT.enabled("quests") or not DT.isMember() then return false end   -- guard: module switch (send)
  local bag, lib = myPayload()
  if bag == "" and lib == "" then return false end                         -- nothing done yet: nothing to share
  local me = DT.myKey()
  if me then
    board()[me] = { bag = bag, lib = libList(lib), seen = epoch() }
    noteFirst(me, bag)
  end
  DT.send("QUESTS", { bag = bag, lib = lib })
  if redrawBoard then redrawBoard() end
  return true
end

local function withdraw()
  local me = DT.myKey()
  if me then board()[me] = nil end
  DT.send("QUESTS", { off = "1" })                                         -- guard: withdraw on share off
  if redrawBoard then redrawBoard() end
end

local function size(t) local k = 0 for _ in pairs(t) do k = k + 1 end return k end

local function makeRoom(t)
  while size(t) >= BOARD_CAP do
    local oldK, oldT
    for k, e in pairs(t) do
      local at = type(e) == "table" and type(e.seen) == "number" and e.seen or -1
      if not oldK or at < oldT or (at == oldT and k < oldK) then oldK, oldT = k, at end
    end
    if not oldK then return end
    t[oldK] = nil
  end
end

-- Inbound QUESTS: bag only digits 1-7, each once; lib only book IDs we know, each once.
local function validQuests(f)
  local bag, lib = f.bag, f.lib
  if type(bag) ~= "string" or #bag > BAG_TOTAL or not bag:match("^[1-7]*$") then return nil end
  local seenD = {}
  for d in bag:gmatch(".") do
    if seenD[d] then return nil end
    seenD[d] = true
  end
  if type(lib) ~= "string" or #lib > 400 then return nil end
  local _, books = ids()
  local list, seenI = {}, {}
  if lib ~= "" then
    for part in (lib .. ","):gmatch("([^,]*),") do
      local n = tonumber(part)
      if not n or not part:match("^%d+$") or not books[n] or seenI[n] then return nil end   -- guard: only known book IDs
      seenI[n] = true
      list[#list + 1] = n
    end
  end
  return { bag = bag, lib = list }
end
DT._questsValid = validQuests

DT.on("QUESTS", function(from, f)
  if not DT.enabled("quests") then return end                              -- guard: module switch (inbound)
  if f.off ~= nil then
    if f.off == "1" and f.bag == nil and f.lib == nil then board()[from] = nil else bad() end
    if redrawBoard then redrawBoard() end
    return
  end
  local v = validQuests(f)
  if not v then bad() return end                                           -- guard: QUESTS validation
  local b = board()
  if b[from] == nil then makeRoom(b) end                                   -- guard: board cap
  v.seen = epoch()
  b[from] = v
  noteFirst(from, v.bag)
  if redrawBoard then redrawBoard() end
end)

local function prune()
  local now = epoch()
  if not now then return end
  local b = board()
  for k, e in pairs(b) do
    if type(e) ~= "table" or type(e.seen) ~= "number" or now - e.seen > MAX_AGE then b[k] = nil end   -- guard: 30 days
  end
end

-- ---------------------------------------------------------------- the board (Q6)

local function bagText(bag)
  if type(bag) == "string" and bag:find("7", 1, true) then return BAG_ICON .. "Bag: done" end
  return "Bag: " .. #(bag or "") .. "/" .. BAG_TOTAL
end

function DT.questBoardRows()
  prune()
  local b = board()
  local keys = {}
  for k in pairs(b) do keys[#keys + 1] = k end
  local name = DT.namer(keys)
  local roster = DT.rosterClasses()
  local rows = {}
  for k, e in pairs(b) do
    if type(e) == "table" and type(e.bag) == "string" and type(e.lib) == "table" then
      local cr, cg, cb = DT.classColour(k, roster)
      local nm = name(k)
      local done = e.bag:find("7", 1, true) ~= nil
      rows[#rows + 1] = { key = k, name = nm, nameRGB = cr and { cr, cg, cb } or nil, books = #e.lib, steps = #e.bag,
        done = done, bag = bagText(e.bag), lib = "Books: " .. #e.lib, search = nm }
    end
  end
  table.sort(rows, function(a, c)
    if a.books ~= c.books then return a.books > c.books end
    local ab, cb = a.done and 99 or a.steps, c.done and 99 or c.steps
    if ab ~= cb then return ab > cb end
    if a.name:lower() ~= c.name:lower() then return a.name:lower() < c.name:lower() end
    return a.key < c.key
  end)
  return rows
end

function DT.questFooter(tab)
  local parts = {}
  local f = store().first
  if tab ~= "lib" and type(f) == "table" and type(f.key) == "string" then
    parts[#parts + 1] = FIRST:format(DT.nameOf(f.key) or f.key)
  end
  parts[#parts + 1] = CLOSING
  return table.concat(parts, " ")
end

-- Who has handed in book `id`, by name.
local function holders(id)
  local out = {}
  for k, e in pairs(board()) do
    if type(e) == "table" and type(e.lib) == "table" then
      for _, n in ipairs(e.lib) do if n == id then out[#out + 1] = DT.nameOf(k) or k; break end end
    end
  end
  table.sort(out)
  return out
end

-- ---------------------------------------------------------------- the Waypointer hand-off (Q5)

local function goTo(zone, x, y, label)
  local map = DT.wayZone(zone)
  if not map then DT.out(zone .. ": zone not found.") return false end
  if DT.waySet(map, x / 100, y / 100, label) then
    DT.out("Waypoint: " .. DT.safe(label, NAME_MAX) .. ", " .. DT.safe(zone, 32) .. string.format(" %.1f, %.1f.", x, y))
    return true
  end
  return false
end

function DT.questNextStep()
  local _, finished, st = DT.questBag()
  if finished or not st then return DT.out("The bag is yours. Nowhere left to go but to sleep.") end
  return goTo(st.zone, st.x, st.y, st.name)
end

function DT.questNearestBook()
  local books = DT.questBooks()
  local best, bestD
  for _, b in ipairs(books) do
    if b.state ~= "done" then
      local map = DT.wayZone(b.zone)
      if map then
        local d, _, state = DT.wayReading({ map = map, x = b.x / 100, y = b.y / 100 })
        if state == "ok" and type(d) == "number" and (not bestD or d < bestD) then best, bestD = b, d end   -- guard: this continent only
      end
    end
  end
  if not best then return DT.out(NO_CONTINENT) end
  return goTo(best.zone, best.x, best.y, best.name)
end

-- ---------------------------------------------------------------- the window (Q7)

local vp, tabs, tab, parts = nil, nil, "bag", {}

local function holder(parent, top, h)
  local f = CreateFrame("Frame", nil, parent)
  f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -top)
  f:SetSize(parent.dtWidth, h)
  f.dtWidth, f.dtHeight = parent.dtWidth, h
  return f
end

local function tabButton(label, which)
  local b = CreateFrame("Button", nil, vp.body, "UIPanelButtonTemplate")
  b:SetText(label)
  local w = math.ceil((DT.measure(label, "body") or (#label * 7)) * 1.15) + 24
  b:SetSize(w, 22)
  b.dtWidth = w
  b:SetScript("OnClick", function() tab = which; DT.questsView() end)
  return b
end

local function actionButton(parent, label, fn)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetText(label)
  local w = math.ceil((DT.measure(label, "body") or (#label * 7)) * 1.15) + 24
  b:SetSize(w, 22)
  b.dtWidth = w
  b:SetScript("OnClick", function()
    local ok, err = pcall(fn)
    if not ok then DT.fail("quests", "click " .. label, err) end
  end)
  return b
end

local function fillBag()
  local steps, finished, nextStep = DT.questBag()
  local rows = {}
  for _, st in ipairs(steps) do
    rows[#rows + 1] = { st = st, n = tostring(st.n), name = st.name .. (st.optional and " (optional)" or ""),
      state = st.state == "done" and "done" or st.state == "unknown" and UNKNOWN or "-",
      nameRGB = st.state == "done" and { 0.5, 0.75, 0.4 } or nil, search = st.name }
  end
  parts.bagModel:set(rows)
  parts.bagList:refresh()
  local head = finished and "Done. The Cozy Sleeping Bag is yours."
    or ("Next: step " .. nextStep.n .. ", " .. nextStep.name .. (nextStep.handin and " (hand it in at Westfall)." or "."))
  DT.setText(parts.bagHead, head)
  parts.next:SetShown(not finished)
  parts.bagBoardModel:set(DT.questBoardRows())
  parts.bagBoard:refresh()
end

local function fillLib()
  local books, count = DT.questBooks()
  local rows = {}
  for _, b in ipairs(books) do
    rows[#rows + 1] = { book = b, name = b.name, zone = b.zone, lvl = b.lvl,
      state = b.state == "done" and "done" or b.state == "unknown" and UNKNOWN or "-",
      nameRGB = b.state == "done" and { 0.5, 0.75, 0.4 } or nil, search = table.concat({ b.name, b.zone, b.note or "" }, " ") }
  end
  parts.libModel:set(rows)
  parts.libList:refresh()
  DT.setText(parts.libHead, DT.questTierLine(count, claimedTiers()))
  DT.textHeight(parts.libHead, vp.body.dtWidth)
  parts.libBoardModel:set(DT.questBoardRows())
  parts.libBoard:refresh()
end

local function fill()
  local isBag = tab == "bag"
  for _, f in ipairs(parts.bagFrames) do f:SetShown(isBag) end
  for _, f in ipairs(parts.libFrames) do f:SetShown(not isBag) end
  if isBag then fillBag() else fillLib() end
  vp:setFooter(DT.questFooter(isBag and "bag" or "lib"))
end

redrawBoard = function() if vp and vp:IsShown() then fill() end end

local function boardList(parent, top, count, col)
  local model = DT.listModel()
  local h = holder(parent, top, count * 20 + 4)
  local L = DT.list(h, model, { count = count, tipCovers = { "name" },
    empty = function(m) if #m.rows == 0 then return BOARD_EMPTY end end,
    tip = function(row, tt) tt:AddLine(DT.safe(DT.nameOf(row.key) or row.name, NAME_MAX)) end,
    columns = { { key = "name", flex = true, rgb = "nameRGB" }, { key = col, fixed = true } } })
  return model, L, h
end

local function build()
  if vp then return end
  vp = DT.viewport({ id = "quests", title = TITLE, search = true, width = 520, height = 470, footer = CLOSING,
    onSearch = function(text)
      if parts.libModel then parts.libModel:filter(text); parts.libList.offset = 0; parts.libList:refresh() end
    end })
  local body = vp.body
  tabs = { bag = tabButton(TAB_BAG, "bag"), lib = tabButton(TAB_LIB, "lib") }
  tabs.bag:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
  tabs.lib:SetPoint("TOPLEFT", body, "TOPLEFT", tabs.bag.dtWidth + 6, 0)
  parts.bagFrames, parts.libFrames = {}, {}

  -- The Sleeping Bag
  local bagTop = holder(body, 28, 20)
  parts.bagHead = DT.text(bagTop, "line", { width = body.dtWidth, window = "quests" })
  parts.bagHead:SetPoint("TOPLEFT", bagTop, "TOPLEFT", 0, 0)
  parts.bagModel = DT.listModel()
  local bh = holder(body, 50, 7 * 20 + 4)
  parts.bagList = DT.list(bh, parts.bagModel, { count = 7, tipCovers = { "name" },
    onClick = function(row) goTo(row.st.zone, row.st.x, row.st.y, row.st.name) end,
    tip = function(row, tt)
      tt:AddLine(DT.safe(row.st.name, 64))
      if row.st.note then tt:AddLine(DT.safe(row.st.note, 100), 0.8, 0.8, 0.8, true) end
      tt:AddLine("Click to set the waypoint.", 0.6, 0.6, 0.6)
    end,
    columns = { { key = "n", fixed = true, colour = "muted" }, { key = "name", flex = true, rgb = "nameRGB" },
      { key = "state", fixed = true } } })
  parts.next = actionButton(bh, "Next step", function() DT.questNextStep() end)
  parts.next:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -200)
  local bagGuild = holder(body, 228, 20)
  local g1 = DT.text(bagGuild, "line", { width = body.dtWidth, window = "quests" })
  g1:SetPoint("TOPLEFT", bagGuild, "TOPLEFT", 0, 0)
  DT.setText(g1, "The guild")
  local bm, bl, bbh = boardList(body, 248, 4, "bag")
  parts.bagBoardModel, parts.bagBoard = bm, bl
  parts.bagFrames = { bagTop, bh, bagGuild, bbh }

  -- The Library
  local libTop = holder(body, 28, 34)
  parts.libHead = DT.text(libTop, "block", { width = body.dtWidth, window = "quests" })
  parts.libHead:SetPoint("TOPLEFT", libTop, "TOPLEFT", 0, 0)
  parts.libModel = DT.listModel()
  local lh = holder(body, 64, 7 * 20 + 4)
  parts.libList = DT.list(lh, parts.libModel, { count = 7, tipCovers = { "name" },
    empty = function(m) if #m:visible() == 0 then return "No book by that name." end end,
    onClick = function(row) local b = row.book; goTo(b.zone, b.x, b.y, b.name) end,
    tip = function(row, tt)
      tt:AddLine(DT.safe(row.book.name, 64))
      if row.book.note and row.book.note ~= "" then tt:AddLine(DT.safe(row.book.note, 80), 0.8, 0.8, 0.8, true) end
      local who = holders(row.book.id)
      tt:AddLine(#who > 0 and ("Handed in by: " .. table.concat(who, ", ")) or "No guildie sharing has handed it in.",
        0.7, 0.7, 0.7, true)
      tt:AddLine("Click to set the waypoint.", 0.6, 0.6, 0.6)
    end,
    columns = { { key = "name", flex = true, rgb = "nameRGB" }, { key = "zone", fixed = true, colour = "muted" },
      { key = "lvl", fixed = true, colour = "muted" }, { key = "state", fixed = true } } })
  parts.nearest = actionButton(lh, "Nearest book", function() DT.questNearestBook() end)
  parts.nearest:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -212)
  local libGuild = holder(body, 240, 20)
  local g2 = DT.text(libGuild, "line", { width = body.dtWidth, window = "quests" })
  g2:SetPoint("TOPLEFT", libGuild, "TOPLEFT", 0, 0)
  DT.setText(g2, "The guild")
  local lm, ll, lbh = boardList(body, 260, 4, "lib")
  parts.libBoardModel, parts.libBoard = lm, ll
  parts.libFrames = { libTop, lh, libGuild, lbh }
end

function DT.questsView(which)
  if not DT.isMember() then return end
  build()
  if which then tab = which end
  fill()
  vp:Show()
end

-- ---------------------------------------------------------------- the verb, the events

local function verb(args)
  if not DT.enabled("quests") then return DT.out(OFF) end                  -- guard: off verbs do nothing else
  local a = (DT.trim(args) or ""):lower()
  if a == "" then return DT.questsView() end
  if a == "bag" then return DT.questsView("bag") end
  if a == "library" or a == "books" then return DT.questsView("lib") end
  local sw = a:match("^share%s+(%a+)$")
  if sw == "on" or sw == "off" then
    DT.set("quests", "share", sw == "on")
    return DT.out(sw == "on" and "Your quests are on the guild's board." or "Your quests are your own again.")
  end
  return DT.out(USAGE)
end

DT.listen("setting", function(id, key, v)
  if id ~= "quests" or key ~= "share" then return end
  local ok, err = pcall(function()
    if v == false then withdraw() elseif v == true then send() end
  end)
  if not ok then DT.fail("quests", "share", err) end
end)

local sentLogin = false
DT.listen("greeted", function()
  if sentLogin then return end
  sentLogin = true
  DT.after(LOGIN_WAIT, function()
    local ok, err = pcall(send)
    if not ok then DT.fail("quests", "login", err) end
  end)
end)

DT.keySource(function() return board() end)

DT.module({
  id = "quests",
  title = TITLE,
  optional = true,
  switchDesc = "Guild quests: the sleeping bag arc and the library books, read from your own quest log. /dt quests. Off, it reads, sends and hears nothing.",
  settings = {
    { key = "share", type = "bool", default = true, label = "Share my quests", verb = "quests share on|off",
      desc = "Which sleeping-bag steps and library books you've done, for guildies running the addon. On by default (ruled 23 Nov); off takes you off every board." },
  },
  verbs = {
    { verb = "quests", usage = "quests [bag|library|share on|off]", fn = verb },
  },
  events = {
    QUEST_TURNED_IN = function(questId)
      local o = ids()
      if type(questId) ~= "number" or not o[questId] then return end       -- guard: only our quests trigger a send
      DT.after(1, function()
        local ok, err = pcall(send)
        if not ok then DT.fail("quests", "turn-in", err) end
        if redrawBoard then redrawBoard() end
      end)
    end,
  },
  init = function() store(); prune() end,
  fit = function()
    build()
    parts.bagModel:set({ { st = DT.questBag(), n = "7", name = "This Must Be The Place, with a very long name indeed (optional)", state = UNKNOWN } })
    parts.bagList:refresh()
    DT.setText(parts.bagHead, "Next: step 1, ...and that note you found (hand it in at Westfall).")
    DT.setText(parts.libHead, DT.questTierLine(34, { 10, 20, 25 }))
    DT.textHeight(parts.libHead, vp.body.dtWidth)
    parts.libModel:set({ { book = {}, name = "A Luddite's Guide to Caring for Your Demonic Pet", zone = "Swamp of Sorrows", lvl = "35-45", state = UNKNOWN } })
    parts.libList:refresh()
    local long = { { key = "x", name = "Bartholomew Longname-Grimshaw", bag = BAG_ICON .. "Bag: done", lib = "Books: 39" } }
    parts.bagBoardModel:set(long); parts.bagBoard:refresh()
    parts.libBoardModel:set(long); parts.libBoard:refresh()
  end,
})

-- For the offline tests only.
DT._quests = { store = store, vp = function() return vp end, parts = function() return parts end, tabs = function() return tabs end,
  ids = ids, BOARD_EMPTY = BOARD_EMPTY, CLOSING = CLOSING, NO_CONTINENT = NO_CONTINENT, OFF = OFF, UNKNOWN = UNKNOWN,
  BAG_ICON = BAG_ICON }
