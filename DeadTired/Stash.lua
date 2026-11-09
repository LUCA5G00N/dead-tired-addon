-- Dead Tired: guild stash search. "Who has linen?" answered by guildies who opted in.
-- docs/COWORK_BRIEF_dt_stretch.md (card 6; R1-R6 ratified 2026-11-02).
--
-- A4 (rulings round, 2026-11-02): an item is listed only when it is known not to be bound:
-- isBound == false, or isBound nil and C_Item.IsBound for the slot false. Unknown: not listed.
-- R2: off until /dt stash share on. Tradeable items only (bound items never listed), bags and
-- (when opened) bank, for every character on the account that has run with sharing on. Nothing
-- is sent except an answer to a guildie's search: matching items only, at most 4. A search term
-- is matched as plain text, never as a Lua pattern. Switching sharing off deletes the list.
-- Fix round 1: F8b, the search id is time() % 1000000, not a per-session counter; F6d, one
-- search per asker per 30 s is answered.
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local SCAN_GAP = 5          -- seconds between bag scans
local SEARCH_WINDOW = 30    -- seconds between searches from one client
local WAIT = 10             -- seconds the asker collects answers
local DELAY_MIN, DELAY_SPREAD = 1, 4
local MAX_HITS = 4          -- 4, not 5 (Tim, 2026-11-02): room for 24-byte holder names in 250 bytes
local HOLDER_MAX = 24       -- bytes: a 12-letter name with every letter accented
local CLOSING = "Only guildies running the addon with stash sharing on answer."

local function store()
  local db = DT.db()
  if type(db.stash) ~= "table" then db.stash = {} end
  local s = db.stash
  if s.share == nil then s.share = false end
  if type(s.badStash) ~= "number" then s.badStash = 0 end
  if type(s.chars) ~= "table" then s.chars = {} end
  return s
end
DT.stash = store

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
          if bound == false then                                                 -- guard: bound unknown, not listed (A4)
            items[info.itemID] = (items[info.itemID] or 0) + info.stackCount
          end
        end
      end
    end
  end
  return items
end

local function canScan()
  if not store().share then return false end                                     -- guard: share gate on scanning
  return DT.isMember()
end

local function entry()
  local k = DT.charKey()
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
      DT.after(SCAN_GAP - (t - lastScan), function() pendingScan = false; lastScan = DT.now(); scanBags() end)
    end
    return
  end
  lastScan = t
  scanBags()
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
local function isKey(s) return type(s) == "string" and #s >= 1 and #s <= 64 and s:match("^.+%-[^%-]+$") ~= nil end
local function isTerm(s) return type(s) == "string" and #s >= 3 and #s <= 32 end

-- Fix round 1 (F6d): at most one search per asker per 30 s is answered (the asker's own window).
local lastAsk = {}

DT.on("STASHQ", function(from, f)
  local s = store()
  if not isQ(f.q) or not isTerm(f.term) then s.badStash = s.badStash + 1 return end
  if not s.share then return end                                                 -- guard: share gate on answering
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
    if not store().share then return end                                         -- guard: share gate at answer time
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
  local hits = isQ(f.q) and isKey(f.to) and parseHits(f.hits)
  if not hits then                                                               -- guard: STASH validation
    local s = store()
    s.badStash = s.badStash + 1
    return
  end
  if DT.normKey(f.to) ~= DT.charKey() then return end                            -- guard: addressed to someone else (AUD-06: one spelling)
  if not open or tostring(open.q) ~= f.q then return end                         -- late answers
  if open.answers[from] then return end
  open.answers[from] = hits
  open.order[#open.order + 1] = from
end)

local function summary()
  local o = open
  open = nil
  if not o then return end
  local lines = 0
  for _, from in ipairs(o.order) do
    local byHolder, holders = {}, {}
    for _, h in ipairs(o.answers[from]) do
      if not byHolder[h.holder] then byHolder[h.holder] = {}; holders[#holders + 1] = h.holder end
      local name = itemName(h.id)
      if not name then try(C_Item and C_Item.RequestLoadItemDataByID, h.id); name = "item " .. h.id end
      table.insert(byHolder[h.holder], DT.safe(name, 48) .. " x" .. h.count)
    end
    for _, holder in ipairs(holders) do
      DT.out(DT.safe(holder, 24) .. ": " .. table.concat(byHolder[holder], ", "))
      lines = lines + 1
    end
  end
  if lines == 0 then DT.out("Nobody's got it. Or nobody's sharing.") end
  DT.out(CLOSING)
end

local function search(term)
  if #term < 3 or #term > 32 then return DT.out("/dt stash <item, 3-32 letters>, or /dt stash share on/off") end
  local t = DT.now()
  if lastSearch and t - lastSearch < SEARCH_WINDOW then                          -- guard: search window
    return DT.out("One search at a time. The crypt echoes.")
  end
  lastSearch = t
  -- Fix round 1 (F8b): the search id comes from the clock, so a /reload doesn't reuse ids the
  -- guild has already answered. 1-6 digits as before; the 30 s window keeps it unique.
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
  if not s.share then return DT.out("Sharing off. Nothing offered.") end
  local chars, ids = 0, {}
  for _, e in pairs(s.chars) do if type(e) == "table" then chars = chars + 1 end end
  local n = 0
  for _, o in ipairs(offers()) do if not ids[o.id] then ids[o.id] = true; n = n + 1 end end
  local e = s.chars[DT.charKey() or ""]
  local bank = (not bankIDs() and "not read on this client")
    or (type(e) == "table" and e.bankAt and ("read " .. tostring(e.bankAt):sub(1, 10))) or "not read yet"
  DT.out("Your account offers " .. n .. (n == 1 and " item" or " items") .. " across " .. chars
    .. (chars == 1 and " character" or " characters") .. " (bank " .. bank .. "). Sharing on.")
end

local function verb(msg)
  local raw = (DT.raw or msg):gsub("^%S+%s*", "")
  local s = store()
  local low = raw:lower()
  if raw == "" then return overview() end
  if low == "share on" then
    s.share = true
    scanBags()
    return DT.out("stash sharing on. Guildies' searches see your tradeable items, four at a time, and which character holds them.")
  elseif low == "share off" then
    s.share = false
    s.chars = {}
    return DT.out("stash sharing off. Your list is gone; your bags are your own again.")
  elseif low == "share" then
    return DT.out("stash sharing is " .. (s.share and "on" or "off") .. ". /dt stash share on/off")
  end
  return search(raw)
end

-- For the offline tests only.
DT._stash = { open = function() return open end, answered = function() return answered end,
  scanBags = scanBags, bankIDs = bankIDs }

-- Fix round 3 (AUD-06): the account's per-character lists move to the one key spelling, once per
-- account (DeadTiredDB.stash.keysV = 2). Two old keys can't name one character (one realm has
-- one GetRealmName spelling), so nothing collapses here in practice; if it did, the entry already
-- under the new key stays.
local function migrate()
  local s = store()
  if s.keysV == 2 then return end                                      -- guard: stash migration once
  DT.migrateKeys(s.chars, {})
  s.keysV = 2
end

local entered = false
DT.module({
  id = "stash",
  init = function() store(); migrate() end,
  events = {
    PLAYER_ENTERING_WORLD = function()
      if entered then return end
      entered = true
      lastScan = DT.now()
      scanBags()
    end,
    BAG_UPDATE_DELAYED = bagUpdate,
    BANKFRAME_OPENED = scanBank,
  },
  ready = DT.errors,
  errorKey = "stash", lastKey = "lastStash",
})
DT.verb("stash", verb, "stash [item/share on/off]")
