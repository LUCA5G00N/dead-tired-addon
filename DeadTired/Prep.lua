-- Dead Tired: raid prep, the officers' raid-night list (R-P3, ruled 11 Nov for Port 1).
-- Card 5's /dt prep (docs/COWORK_BRIEF_dt_prep.md on card/dt_prep; R1-R5 ratified 2026-11-02)
-- reshaped: rc3 checked your bags against a built-in list (PrepList.lua); now officers set the
-- list and Dead Tired shares it.
--
--   Officers: /dt prep add <item> <count>, /dt prep remove <item>, /dt prep clear, and the list in
--     the Raid prep settings card. <item> is an item ID, a shift-clicked item link, or a name the
--     client knows. Every change is stamped with the time and sent to the guild (PREPLIST).
--   Everyone: /dt prep check (or /dt prep) checks your own bags against it, never the bank;
--     /dt prep list shows it.
--   Sharing the list: PREPLIST { ver, items }. Last writer wins by time (ver; a tie goes to the
--     greater sender key). Accepted only from a guild officer: the sender's guild rank, read from
--     the guild roster, at most Config.OFFICER_MAX_RANK; a sender not found there is refused
--     (counted in prep.notOfficer). Every HELLO carries the list's version (pl); an officer who
--     hears an older one sends the list again (at most once a minute).
--   The roll call (rc3, R4, unchanged in what it shares): /dt prep roll asks; members with
--     /dt prep share on answer with a verdict only, ready yes/no and how many entries are short,
--     never item names or counts. One roll call per asker per 60 s is answered (F6c); the question
--     id comes from the clock (F8a).
-- Only guildies running Dead Tired get the list or answer, and the lines say so.
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local CHECK_WINDOW = 60     -- seconds between roll calls from one client
local ANSWER_WAIT = 10      -- seconds the asker collects answers
local DELAY_MIN, DELAY_SPREAD = 1, 4
local MAX_SHORT = 50
local MAX_ITEMS = 30
local MAX_NEED = 1000
local NAME_MAX = 48
local RESEND_GAP = 60
local CLOSING = "Only guildies running the addon with sharing on answer."
local OFFICERS = "Officers only. The rest of us just haunt the place."

local function prep()
  local db = DT.db()
  if type(db.prep) ~= "table" then db.prep = {} end
  local p = db.prep
  if type(p.badPrep) ~= "number" then p.badPrep = 0 end
  if type(p.list) ~= "table" then p.list = { ver = 0, items = {} } end
  if type(p.list.items) ~= "table" then p.list.items = {} end
  if type(p.list.ver) ~= "number" then p.list.ver = 0 end
  return p
end
DT.prep = prep

local function isOfficer() return try(C_GuildInfo and C_GuildInfo.IsGuildOfficer) == true end

-- ---------------------------------------------------------------- who is an officer (receiving)

-- The sender's guild rank from the roster (globals GetNumGuildMembers / GetGuildRosterInfo, both
-- guarded). The roster's name may carry "-Realm"; when it does, the realm must match the key's.
function DT.rankOf(key)
  local realm, name = DT.splitKey(key)
  if not realm then return nil end
  local n = clean(try(GetNumGuildMembers))
  if type(n) ~= "number" or n < 1 then return nil end
  for i = 1, math.min(n, 1000) do
    local rn, _, rank = try(GetGuildRosterInfo, i)
    rn, rank = clean(rn), clean(rank)
    if type(rn) == "string" and type(rank) == "number" then
      local full = DT.fullName(rn)
      local rr = rn:match("%-(.+)$")
      if full and full:lower() == name:lower() and (not rr or DT.realmKey(rr) == realm) then return rank end
    end
  end
  return nil
end

local function senderIsOfficer(key)
  local max = tonumber(DT.Config.OFFICER_MAX_RANK) or 1
  local rank = DT.rankOf(key)
  return type(rank) == "number" and rank <= max
end
DT._senderIsOfficer = senderIsOfficer

-- ---------------------------------------------------------------- the list

local function itemName(id)
  local n = clean(try(C_Item and C_Item.GetItemNameByID, id))
  if type(n) == "string" and n ~= "" then return n end
  try(C_Item and C_Item.RequestLoadItemDataByID, id)
  return nil
end

-- <item> as typed: a link (|Hitem:ID...|h[Name]|h), an ID, or a name the client knows.
local function parseItem(s)
  s = DT.trim(s) or ""
  local id = tonumber(s:match("|Hitem:(%d+)"))
  if id then return id, s:match("|h%[(.-)%]|h") end
  if s:match("^%d+$") then return tonumber(s), nil end
  if s == "" then return nil end
  local got = clean(try(C_Item and C_Item.GetItemInfoInstant, s))
  if type(got) == "number" then return got, s end
  return nil
end

local function cleanName(n, id)
  n = type(n) == "string" and n:gsub("[%z\1-\31|%[%]]", "") or ""
  if n == "" then n = itemName(id) or ("item " .. id) end
  return n:sub(1, NAME_MAX)
end

local function share()
  local p = prep()
  local items = {}
  for _, e in ipairs(p.list.items) do items[#items + 1] = { id = e.id, need = e.need, name = e.name } end
  p.lastSent = DT.now()
  return DT.send("PREPLIST", { ver = tostring(p.list.ver), items = items })
end

local listChanged

-- An officer's change: stamped with the time, kept, sent.
local function changed()
  local p = prep()
  local t = DT.epoch()
  if t <= p.list.ver then t = p.list.ver + 1 end
  p.list.ver = t
  p.list.by = DT.myKey()
  share()
  if listChanged then listChanged() end
end

local function find(id)
  for i, e in ipairs(prep().list.items) do if e.id == id then return i, e end end
end

local function describe(e) return DT.safe(e.name, NAME_MAX) .. " x" .. e.need end

local function add(args)
  if not isOfficer() then return DT.out(OFFICERS) end                 -- guard: officers set the list
  local item, count = (args or ""):match("^(.-)%s+(%d+)%s*$")
  local id, name = parseItem(item)
  count = tonumber(count)
  if not id or not count or count < 1 or count > MAX_NEED then
    return DT.out("/dt prep add <item> <count>: an item ID or a shift-clicked item, then how many.")
  end
  local list = prep().list.items
  local _, e = find(id)
  if e then e.need = count
  else
    if #list >= MAX_ITEMS then return DT.out("prep.list: full (" .. MAX_ITEMS .. ").") end
    e = { id = id, need = count, name = cleanName(name, id) }
    list[#list + 1] = e
  end
  changed()
  return DT.out("prep.list: " .. describe(e) .. " (" .. #list .. " on the list)")
end

local function removeId(id)
  local i, e = find(id)
  if not i then return nil end
  table.remove(prep().list.items, i)
  changed()
  return e
end

local function remove(args)
  if not isOfficer() then return DT.out(OFFICERS) end                 -- guard: officers set the list
  local id = parseItem(args)
  if not id then
    local want = (DT.trim(args) or ""):lower()
    for _, e in ipairs(prep().list.items) do if e.name:lower() == want then id = e.id end end
  end
  local e = id and removeId(id)
  if not e then return DT.out("prep.list: no " .. DT.safe(args, 48) .. " on it. /dt prep list") end
  return DT.out("prep.list: " .. DT.safe(e.name, NAME_MAX) .. " removed (" .. #prep().list.items .. " on the list)")
end

local function clear()
  if not isOfficer() then return DT.out(OFFICERS) end                 -- guard: officers set the list
  prep().list.items = {}
  changed()
  return DT.out("prep.list: cleared")
end

-- ---------------------------------------------------------------- receiving the list

local function validList(d)
  local ver = type(d.ver) == "string" and d.ver:match("^%d%d?%d?%d?%d?%d?%d?%d?%d?%d?%d?$") and tonumber(d.ver)
  if not ver or type(d.items) ~= "table" or #d.items > MAX_ITEMS then return nil end
  local out = {}
  for _, e in ipairs(d.items) do
    if type(e) ~= "table" then return nil end
    local id, need = tonumber(e.id), tonumber(e.need)
    if not id or id < 1 or id > 9999999 or id ~= math.floor(id) then return nil end
    if not need or need < 1 or need > MAX_NEED or need ~= math.floor(need) then return nil end
    if type(e.name) ~= "string" or #e.name > NAME_MAX then return nil end
    out[#out + 1] = { id = id, need = need, name = cleanName(e.name, id) }
  end
  return ver, out
end

DT.on("PREPLIST", function(from, d)
  if not DT.enabled("prep") then return end
  local p = prep()
  local ver, items = validList(d)
  if not ver then p.badPrep = p.badPrep + 1 return end                 -- guard: PREPLIST validation
  if not senderIsOfficer(from) then                                    -- guard: officers only accepted
    p.notOfficer = (p.notOfficer or 0) + 1
    return
  end
  local mine = p.list
  if ver < mine.ver or (ver == mine.ver and tostring(from) <= tostring(mine.by or "")) then return end  -- last writer wins
  p.list = { ver = ver, by = from, items = items }
  if listChanged then listChanged() end
end)

DT.helloField("pl", function() return tostring(prep().list.ver) end)

DT.on("HELLO", function(from, d)
  if not DT.enabled("prep") or not isOfficer() then return end
  local p = prep()
  if p.list.ver == 0 then return end
  local theirs = tonumber(d.pl) or 0
  if theirs >= p.list.ver then return end
  local t = DT.now()
  if p.lastSent and t - p.lastSent < RESEND_GAP then return end        -- guard: resend at most once a minute
  share()
end)

-- ---------------------------------------------------------------- the check (your own bags)

local function have(id)
  local f = C_Item and C_Item.GetItemCount
  local n = clean(try(f, id, false))                                   -- false: bags only, never the bank
  return type(n) == "number" and n or 0
end

-- ready (bool), short = { { e = entry, n = have }, ... }
local function assess()
  local short = {}
  for _, e in ipairs(prep().list.items) do
    local n = have(e.id)
    if n < (tonumber(e.need) or 0) then short[#short + 1] = { e = e, n = n } end
  end
  return #short == 0, short
end
DT.assessPrep = assess

local function report()
  if #prep().list.items == 0 then return DT.out("Nothing on the list for you. Travel light.") end
  local ok, short = assess()
  if ok then return DT.out("Ready. Bags packed, coffin optional.") end
  local parts = {}
  for _, s in ipairs(short) do parts[#parts + 1] = DT.safe(s.e.name, NAME_MAX) .. " " .. s.n .. "/" .. tostring(s.e.need) end
  DT.out("Short: " .. table.concat(parts, ", ") .. ".")
end

local function list()
  local got = false
  for _, e in ipairs(prep().list.items) do
    got = true
    local name = itemName(e.id)
    local line = e.id .. " " .. DT.safe(e.name, NAME_MAX) .. " x" .. tostring(e.need) .. " — client: "
    if type(name) ~= "string" or name == "" then
      line = line .. "not loaded yet"
    else
      line = line .. DT.safe(name, 64)
      if name:lower() ~= tostring(e.name):lower() then line = line .. "  <- check this ID" end
    end
    DT.out(line)
  end
  if not got then DT.out("Nothing on the list for you. Travel light.") end
end

-- ---------------------------------------------------------------- the roll call (rc3)

local qid, lastCheck, open = 0, nil, nil
local answered = {}            -- [asker .. "#" .. q] = true

local function summary()
  local o = open
  open = nil
  if not o then return end
  local name = DT.namer(o.order)
  local ready, short = {}, {}
  for _, k in ipairs(o.order) do
    local a = o.answers[k]
    if a.ok then ready[#ready + 1] = name(k)
    else short[#short + 1] = name(k) .. " (" .. a.short .. " short)" end
  end
  DT.out("Ready (" .. #ready .. "): " .. (#ready > 0 and table.concat(ready, ", ") or "none")
    .. ". Short (" .. #short .. "): " .. (#short > 0 and table.concat(short, ", ") or "none") .. ".")
  DT.out(CLOSING)
end

local function roll()
  local t = DT.now()
  if lastCheck and t - lastCheck < CHECK_WINDOW then                  -- guard: check window
    return DT.out("Patience. The last roll call is still out.")
  end
  lastCheck = t
  local now = clean(try(time))
  if type(now) == "number" then qid = math.floor(now) % 1000000 else qid = qid + 1 end
  open = { q = qid, answers = {}, order = {} }
  DT.send("PREPQ", { q = tostring(qid) })
  DT.out("Roll call sent. Answers in 10 seconds.")
  DT.after(ANSWER_WAIT, summary)
end

local function isQ(s) return type(s) == "string" and s:match("^%d%d?%d?%d?%d?%d?$") ~= nil end

local lastAsk = {}

DT.on("PREPQ", function(from, f)
  if not DT.enabled("prep") then return end
  local p = prep()
  if not isQ(f.q) then p.badPrep = p.badPrep + 1 return end
  if not DT.get("prep", "share") then return end                      -- guard: share gate
  local t = DT.now()
  if lastAsk[from] and t - lastAsk[from] < CHECK_WINDOW then          -- guard: per-asker limit (F6c)
    p.dropped = (p.dropped or 0) + 1
    return
  end
  lastAsk[from] = t
  local key = from .. "#" .. f.q
  if answered[key] then return end                                    -- guard: one answer per question
  answered[key] = true
  local q = f.q
  DT.after(DELAY_MIN + math.random() * DELAY_SPREAD, function()
    if not DT.get("prep", "share") then return end                    -- guard: share gate at answer time
    local ok, short = assess()
    -- the verdict only: ready or not, and how many entries are short; never names or counts
    DT.send("PREP", { q = q, to = from, ok = ok and "1" or "0", short = tostring(math.min(#short, MAX_SHORT)) })  -- guard: verdict only
  end)
end)

local function validPrep(f)
  if not isQ(f.q) or type(f.to) ~= "string" or not DT.splitKey(f.to) or #f.to > 80 or (f.ok ~= "0" and f.ok ~= "1") then return false end
  local n = type(f.short) == "string" and f.short:match("^%d%d?$") and tonumber(f.short)
  if not n or n > MAX_SHORT then return false end
  for k in pairs(f) do if k ~= "q" and k ~= "to" and k ~= "ok" and k ~= "short" then return false end end
  return (f.ok == "1") == (n == 0)
end

DT.on("PREP", function(from, f)
  if not DT.enabled("prep") then return end
  if not validPrep(f) then                                            -- guard: PREP validation
    local p = prep()
    p.badPrep = p.badPrep + 1
    return
  end
  if not DT.sameKey(f.to, DT.myKey()) then return end                 -- guard: addressed to someone else
  if not open or tostring(open.q) ~= f.q then return end              -- guard: late answers
  if open.answers[from] then return end
  open.answers[from] = { ok = f.ok == "1", short = tonumber(f.short) }
  open.order[#open.order + 1] = from
end)

-- ---------------------------------------------------------------- the verb

local function verb(args)
  local raw = DT.trim(args) or ""
  local w = raw:lower():gsub("%s+", " ")
  if w == "" or w == "check" then return report()
  elseif w == "list" then return list()
  elseif w == "roll" then return roll()
  elseif w == "clear" then return clear()
  elseif w:match("^add ") then return add(raw:gsub("^%S+%s+", "", 1))
  elseif w:match("^remove ") then return remove(raw:gsub("^%S+%s+", "", 1))
  elseif w == "share on" then DT.set("prep", "share", true); return DT.out("sharing on. You'll answer roll calls: ready or not, and how many short.")
  elseif w == "share off" then DT.set("prep", "share", false); return DT.out("sharing off. Your bags are your own business.")
  elseif w == "share" then return DT.out("sharing is " .. (DT.get("prep", "share") and "on" or "off") .. ". /dt prep share on/off")
  end
  return DT.out("/dt prep, /dt prep list, /dt prep check, /dt prep roll, /dt prep share on/off; officers: /dt prep add|remove|clear")
end

DT.module({
  id = "prep",
  title = "Raid prep",
  optional = true,
  switchDesc = "The officers' raid-night list and the roll call. Off, Dead Tired neither takes the list nor answers.",
  settings = {
    { key = "share", type = "bool", default = false, label = "Answer roll calls", verb = "prep share on|off",
      desc = "When someone calls /dt prep roll, tells them whether your bags meet the raid list and how many entries are short. Never which items or how many you carry." },
    { key = "list", type = "list", label = "Raid-night list",
      desc = "The officers' list for raid night, shared to every guildie running Dead Tired. /dt prep check holds your own bags against it (never the bank). Only officers change it.",
      noVerb = "typed as /dt prep add <item> <count>, /dt prep remove <item>, /dt prep clear",
      empty = "Nothing on the list for you. Travel light.",
      items = function()
        local out = {}
        for _, e in ipairs(prep().list.items) do
          out[#out + 1] = { name = tostring(e.id), label = describe(e), tip = "Item " .. e.id }
        end
        return out
      end,
      remove = function(id)
        if not isOfficer() then return DT.out(OFFICERS) end           -- guard: officers set the list
        removeId(tonumber(id))
      end },
  },
  verbs = { { verb = "prep", usage = "prep [check/list/roll/share on/off/add/remove/clear]", fn = verb } },
  init = function() prep() end,
  events = {
    PLAYER_ENTERING_WORLD = function() try(C_GuildInfo and C_GuildInfo.GuildRoster) end,
  },
})

listChanged = function() DT.signal("setting", "prep", "list") end

-- For the offline tests only.
DT._prep = { open = function() return open end, answered = function() return answered end, validList = validList,
  parseItem = parseItem, share = share }
