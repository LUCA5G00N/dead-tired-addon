-- Dead Tired: guild stash search. "Who has linen?" answered by guildies who opted in.
-- Card 6 (docs/COWORK_BRIEF_dt_stretch.md on card/dt_stretch; R1-R6 ratified 2026-11-02), ported
-- from rc3's Stash.lua onto the framework in Port 2. Logic and lines are rc3's; what changed:
-- full-name keys, the setting stash.share as a card (typed: /dt stash share on|off), the answers
-- shown in a searchable viewport (rc3 printed them), holder names up to 48 bytes (full names have
-- a surname; AceComm splits a long answer, so rc3's 24-byte wire limit no longer binds).
--
-- A4 (rulings round, 2026-11-02): an item is listed only when it is known not to be bound:
-- isBound == false, or isBound nil and C_Item.IsBound for the slot false. Unknown: not listed.
-- R2: off until /dt stash share on. Tradeable items only (bound items never listed), bags and
-- (when opened) bank, for every character on the account that has run with sharing on. Nothing
-- is sent except an answer to a guildie's search: matching items only, at most 4. A search term
-- is matched as plain text, never as a Lua pattern. Switching sharing off deletes the list.
-- Fix round 1: F8b, the search id is time() % 1000000; F6d, one search per asker per 30 s.
-- Fix round 4 (R-F4-5): a master switch (optional = true, the framework's On card, default on).
-- Off: no events (the framework), inbound messages ignored, nothing sent, nothing printed unasked,
-- and each verb answers "stash.enabled = off" and does nothing else. Off is not a withdrawal.
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local SCAN_GAP = 5          -- seconds between bag scans
local SEARCH_WINDOW = 30    -- seconds between searches from one client
local WAIT = 10             -- seconds the asker collects answers
local DELAY_MIN, DELAY_SPREAD = 1, 4
local MAX_HITS = 4          -- 4, not 5 (Tim, 2026-11-02)
local HOLDER_MAX = 48       -- bytes: a full name with its surname (rc3: 24, the old wire limit)
local CLOSING = "Only guildies running the addon with stash sharing on answer."
local NOBODY = "Nobody's got it. Or nobody's sharing."

local function store()
  local db = DT.db()
  if type(db.stash) ~= "table" then db.stash = {} end
  local s = db.stash
  if type(s.badStash) ~= "number" then s.badStash = 0 end
  if type(s.chars) ~= "table" then s.chars = {} end
  return s
end
DT.stash = store
local function sharing() return DT.get("stash", "share") == true end

-- ---------------------------------------------------------------- scanning

local function bagIDs()
  local E = type(Enum) == "table" and Enum.BagIndex
  if type(E) == "table" and type(E.Backpack) == "number" then
    local t = { E.Backpack }
    for i = 1, 4 do if type(E["Bag_" .. i]) == "number" then t[#t + 1] = E["Bag_" .. i] end end
    return t
  end
  return { 0, 1, 2, 3, 4 }
end

-- nil when the client doesn't name its bank containers: then the bank is never read.
local function bankIDs()
  local E = type(Enum) == "table" and Enum.BagIndex
  if type(E) ~= "table" or type(E.Bank) ~= "number" then return nil end         -- guard: bank constant
  local t = { E.Bank }
  for i = 1, 12 do if type(E["BankBag_" .. i]) == "number" then t[#t + 1] = E["BankBag_" .. i] end end
  return t
end

-- A4: C_Item.IsBound takes an item location, built from the bag and slot through the client's
-- ItemLocation (a global, guarded). Returns true, false, or nil when it can't be told.
local function slotBound(bag, slot)
  local L = ItemLocation
  if type(L) ~= "table" then return nil end
  local loc = clean(try(L.CreateFromBagAndSlot, L, bag, slot))
  if loc == nil then return nil end
  local b = clean((try(C_Item and C_Item.IsBound, loc)))
  if type(b) ~= "boolean" then return nil end
  return b
end

local function scan(ids)
  local items, C = {}, C_Container
  for _, bag in ipairs(ids) do
    local n = clean(try(C and C.GetContainerNumSlots, bag))
    if type(n) == "number" then
      for slot = 1, n do
        local info = clean(try(C.GetContainerItemInfo, bag, slot))
        if type(info) == "table" and type(info.itemID) == "number" and type(info.stackCount) == "number"
           and info.stackCount >= 1 then
          local bound = clean(info.isBound)
          if bound == nil then bound = slotBound(bag, slot) end
          if bound == false then                                                 -- guard: only known unbound listed (A4)
            items[info.itemID] = (items[info.itemID] or 0) + info.stackCount
          end
        end
      end
    end
  end
  return items
end

local function canScan()
  if not DT.enabled("stash") then return false end                               -- off: the bags aren't read
  if not sharing() then return false end                                         -- guard: share gate on scanning
  return DT.isMember()
end

local function entry()
  local k = DT.myKey()
  if not k then return nil end
  local chars = store().chars
  if type(chars[k]) ~= "table" then chars[k] = { bags = {}, bank = {} } end
  return chars[k]
end

local function scanBags()
  if not canScan() then return end
  local e = entry()
  if not e then return end
  e.bags, e.at = scan(bagIDs()), DT.stamp()
end

local function scanBank()
  if not canScan() then return end
  local ids, e = bankIDs(), entry()
  if not ids or not e then return end
  e.bank, e.bankAt = scan(ids), DT.stamp()
end

local lastScan, pendingScan = nil, false
local function bagUpdate()
  local t = DT.now()
  if lastScan and t - lastScan < SCAN_GAP then
    if not pendingScan then
      pendingScan = true
      DT.after(SCAN_GAP - (t - lastScan), function()
        pendingScan = false
        if not DT.enabled("stash") then return end
        lastScan = DT.now(); scanBags()
      end)
    end
    return
  end
  lastScan = t
  scanBags()
end

-- This character's own rc3 entry, filed by the short name (RealmKey-UnitName), joins its full-name
-- entry the first time it logs in on 0.3.0 (as Alts does for the roster), so one character never
-- answers twice. The bank list moves over only if the full entry has none yet.
local function foldShort()
  local me = DT.myKey()
  local short = DT.keyOf(clean((try(UnitName, "player"))))
  if not me or not short or short == me then return end
  local chars = store().chars
  local old = chars[short]
  if type(old) ~= "table" then return end
  local e = entry()
  if type(old.bank) == "table" and next(old.bank) ~= nil and (type(e.bank) ~= "table" or next(e.bank) == nil) then
    e.bank, e.bankAt = old.bank, old.bankAt
  end
  chars[short] = nil
end

-- Every character's offer, summed bags + bank: { { key, id, count }, ... }
local function offers()
  local out = {}
  for key, e in pairs(store().chars) do
    if type(e) == "table" then
      local sum = {}
      for _, part in ipairs({ e.bags, e.bank }) do
        if type(part) == "table" then
          for id, n in pairs(part) do
            if type(id) == "number" and type(n) == "number" then sum[id] = (sum[id] or 0) + n end
          end
        end
      end
      for id, n in pairs(sum) do out[#out + 1] = { key = key, id = id, count = n } end
    end
  end
  return out
end

-- ---------------------------------------------------------------- answering

local function itemName(id)
  local n = clean(try(C_Item and C_Item.GetItemNameByID, id))
  if type(n) == "string" and n ~= "" then return n end
  return nil
end

local function matches(term)
  local want, hits = term:lower(), {}
  for _, o in ipairs(offers()) do
    local name = itemName(o.id)
    local holder = DT.nameOf(o.key)
    if name and name:lower():find(want, 1, true) and #holder <= HOLDER_MAX then  -- guard: plain matching
      hits[#hits + 1] = { id = o.id, count = math.min(o.count, 99999), holder = holder }
    end
  end
  table.sort(hits, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    if a.id ~= b.id then return a.id < b.id end
    return a.holder < b.holder
  end)
  while #hits > MAX_HITS do table.remove(hits) end                                -- guard: 4-hit cap
  return hits
end
DT._stashMatches = matches

local answered = {}
local function isQ(s) return type(s) == "string" and s:match("^%d%d?%d?%d?%d?%d?$") ~= nil end
local function isKey(s) return type(s) == "string" and #s >= 1 and #s <= 80 and DT.normKey(s) ~= nil end
local function isTerm(s) return type(s) == "string" and #s >= 3 and #s <= 32 end

-- F6d: at most one search per asker per 30 s is answered (the asker's own window).
local lastAsk = {}

DT.on("STASHQ", function(from, f)
  if not DT.enabled("stash") then return end                                     -- guard: off ignores inbound (stash)
  local s = store()
  if not isQ(f.q) or not isTerm(f.term) then s.badStash = s.badStash + 1 return end
  if not sharing() then return end                                               -- guard: share gate on answering (opt-in)
  local t = DT.now()
  if lastAsk[from] and t - lastAsk[from] < SEARCH_WINDOW then                    -- guard: per-asker limit (F6d)
    s.dropped = (s.dropped or 0) + 1
    return
  end
  lastAsk[from] = t
  local key = from .. "#" .. f.q
  if answered[key] then return end                                               -- guard: one answer per search
  answered[key] = true
  local q, term = f.q, f.term
  DT.after(DELAY_MIN + math.random() * DELAY_SPREAD, function()
    if not DT.enabled("stash") then return end                                   -- guard: off sends nothing (stash)
    if not sharing() then return end                                             -- guard: share gate at answer time
    local hits = matches(term)
    if #hits == 0 then return end
    local parts = {}
    for _, h in ipairs(hits) do parts[#parts + 1] = h.id .. ":" .. h.count .. ":" .. h.holder end
    DT.send("STASH", { q = q, to = from, hits = table.concat(parts, ",") })
  end)
end)

-- ---------------------------------------------------------------- searching

local qid, lastSearch, open = 0, nil, nil

local function parseHits(s)
  if type(s) ~= "string" or s == "" then return nil end
  local out = {}
  for part in (s .. ","):gmatch("([^,]*),") do
    local id, n, holder = part:match("^(%d+):(%d+):([^:,]+)$")
    if not id or #id > 7 or #holder > HOLDER_MAX then return nil end
    n = tonumber(n)
    if n < 1 or n > 99999 then return nil end
    out[#out + 1] = { id = tonumber(id), count = n, holder = holder }
    if #out > MAX_HITS then return nil end
  end
  return #out >= 1 and out or nil
end

DT.on("STASH", function(from, f)
  if not DT.enabled("stash") then return end                                     -- guard: off ignores answers (stash)
  local hits = isQ(f.q) and isKey(f.to) and parseHits(f.hits)
  if not hits then                                                               -- guard: STASH validation
    local s = store()
    s.badStash = s.badStash + 1
    return
  end
  if not DT.sameKey(DT.normKey(f.to), DT.myKey()) then return end                -- guard: addressed to someone else
  if not open or tostring(open.q) ~= f.q then return end                         -- late answers
  if open.answers[from] then return end
  open.answers[from] = hits
  open.order[#open.order + 1] = from
end)

-- The answers as rows: one per holder, in arrival order, "Linen Cloth x60, ...".
local function answerRows(o)
  local rows = {}
  for _, from in ipairs(o.order) do
    local byHolder, holders = {}, {}
    for _, h in ipairs(o.answers[from]) do
      if not byHolder[h.holder] then byHolder[h.holder] = {}; holders[#holders + 1] = h.holder end
      local name = itemName(h.id)
      if not name then try(C_Item and C_Item.RequestLoadItemDataByID, h.id); name = "item " .. h.id end
      table.insert(byHolder[h.holder], DT.safe(name, 48) .. " x" .. h.count)
    end
    for _, holder in ipairs(holders) do
      local items = table.concat(byHolder[holder], ", ")
      rows[#rows + 1] = { holder = DT.safe(holder, HOLDER_MAX), items = items, from = from,
        search = holder .. " " .. items }
    end
  end
  return rows
end

local vp, list, model

-- Fix round 4: the closing line is the viewport's footer; the items take the rest of the width
-- (cut with "…", in full in the tooltip).
local function build()
  if vp then return end
  model = DT.listModel()
  vp = DT.viewport({ id = "stash", title = "Who has it", search = true, width = 420, height = 300, footer = CLOSING,
    onSearch = function(text) model:filter(text); list.offset = 0; list:refresh() end })
  list = DT.list(vp.body, model, { count = 12, detail = { key = "items" }, tipCovers = { "holder" },
    empty = function(m) if #m.rows == 0 then return NOBODY end end,
    tip = function(row, tt)
      tt:AddLine(row.holder)
      tt:AddLine(DT.display(row.from), 1, 1, 1)
    end,
    columns = { { key = "holder", flex = true } } })
end

local function view(rows)
  build()
  model:set(rows)
  list:refresh()
  vp:Show()
end

local function summary()
  local o = open
  open = nil
  if not o or not DT.enabled("stash") then return end
  view(answerRows(o))
end

local function search(term)
  if #term < 3 or #term > 32 then return DT.out("/dt stash <item, 3-32 letters>, or /dt stash share on/off") end
  local t = DT.now()
  if lastSearch and t - lastSearch < SEARCH_WINDOW then                          -- guard: search window
    return DT.out("One search at a time. The crypt echoes.")
  end
  lastSearch = t
  -- F8b: the search id comes from the clock, so a /reload doesn't reuse ids already answered.
  local now = clean(try(time))
  if type(now) == "number" then qid = math.floor(now) % 1000000 else qid = qid + 1 end
  open = { q = qid, answers = {}, order = {} }
  DT.send("STASHQ", { q = tostring(qid), term = term })
  DT.out("Asking the guild. Answers in 10 seconds.")
  DT.after(WAIT, summary)
end

-- ---------------------------------------------------------------- the verb

local function overview()
  local s = store()
  if not sharing() then return DT.out("Sharing off. Nothing offered.") end
  local chars, ids = 0, {}
  for _, e in pairs(s.chars) do if type(e) == "table" then chars = chars + 1 end end
  local n = 0
  for _, o in ipairs(offers()) do if not ids[o.id] then ids[o.id] = true; n = n + 1 end end
  local e = s.chars[DT.myKey() or ""]
  local bank = (not bankIDs() and "not read on this client")
    or (type(e) == "table" and e.bankAt and ("read " .. tostring(e.bankAt):sub(1, 10))) or "not read yet"
  DT.out("Your account offers " .. n .. (n == 1 and " item" or " items") .. " across " .. chars
    .. (chars == 1 and " character" or " characters") .. " (bank " .. bank .. "). Sharing on.")
end

local function verb(args)
  if not DT.enabled("stash") then return DT.out("stash.enabled = off") end       -- guard: off verbs do nothing else (stash)
  local raw = DT.trim(args) or ""
  local low = raw:lower():gsub("%s+", " ")
  if raw == "" then return overview() end
  if low == "share on" then
    DT.set("stash", "share", true)
    return DT.out("stash sharing on. Guildies' searches see your tradeable items, four at a time, and which character holds them.")
  elseif low == "share off" then
    DT.set("stash", "share", false)
    return DT.out("stash sharing off. Your list is gone; your bags are your own again.")
  elseif low == "share" then
    return DT.out("stash sharing is " .. (sharing() and "on" or "off") .. ". /dt stash share on/off")
  end
  return search(raw)
end

-- On: scan the bags at once. Off (typed, /dt set or the card): the account's list is deleted.
local function shareChanged(on)
  if on then foldShort(); scanBags()
  else store().chars = {} end                                                    -- guard: list deleted when sharing off
end

local entered = false
DT.module({
  id = "stash",
  title = "Stash",
  optional = true,
  fit = function() build(); list:refresh() end,
  settings = {
    { key = "share", type = "bool", default = false, label = "Share my stash", verb = "stash share on|off",
      onChange = shareChanged,
      desc = "Answers guildies' /dt stash searches with your tradeable items (never bound ones), four at a time, and which character holds them. Off until you switch it on; switching it off deletes the list." },
  },
  verbs = { { verb = "stash", usage = "stash [item/share on/off]", fn = verb } },
  init = function() store() end,
  events = {
    PLAYER_ENTERING_WORLD = function()
      if entered then return end
      entered = true
      lastScan = DT.now()
      if canScan() then foldShort() end
      scanBags()
    end,
    BAG_UPDATE_DELAYED = bagUpdate,
    BANKFRAME_OPENED = scanBank,
  },
})

-- For the offline tests only.
DT._stash = { open = function() return open end, answered = function() return answered end,
  scanBags = scanBags, bankIDs = bankIDs, CLOSING = CLOSING, NOBODY = NOBODY, vp = function() return vp end,
  list = function() return list end, HOLDER_MAX = HOLDER_MAX }
