-- Dead Tired: raid prep. Your own bags against PrepList.lua, and an opt-in guild roll call.
-- docs/COWORK_BRIEF_dt_prep.md (card 5; R1-R5 ratified 2026-11-02).
--
-- R3: the list is data (PrepList.lua). R4: sharing is opt-in and sends a verdict only (ready
-- yes/no and how many entries are short), never item names or counts. Bags only, never the bank.
-- Fix round 1: F8a, the question id is time() % 1000000, not a per-session counter; F6c, one
-- roll call per asker per 60 s is answered.
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local CHECK_WINDOW = 60     -- seconds between roll calls from one client
local ANSWER_WAIT = 10      -- seconds the asker collects answers
local DELAY_MIN, DELAY_SPREAD = 1, 4
local MAX_SHORT = 50
local CLOSING = "Only guildies running the addon with sharing on answer."

local function prep()
  local db = DT.db()
  if type(db.prep) ~= "table" then db.prep = {} end
  local p = db.prep
  if p.share == nil then p.share = false end
  if type(p.badPrep) ~= "number" then p.badPrep = 0 end
  return p
end
DT.prep = prep

-- ---------------------------------------------------------------- the check

local function myClass()
  local c = clean(select(2, try(UnitClass, "player")))
  return type(c) == "string" and c or nil
end

local function entries()
  local cls, out = myClass(), {}
  for _, e in ipairs(ns.PrepList or {}) do
    if type(e) == "table" and type(e.id) == "number" then
      if e.class == nil or (cls and e.class == cls) then out[#out + 1] = e end   -- guard: class filter
    end
  end
  return out
end

local function have(id)
  local f = C_Item and C_Item.GetItemCount
  local n = clean(try(f, id, false))
  return type(n) == "number" and n or 0
end

-- ready (bool), short = { { entry, have }, ... }
local function assess()
  local short = {}
  for _, e in ipairs(entries()) do
    local n = have(e.id)
    if n < (tonumber(e.need) or 0) then short[#short + 1] = { e = e, n = n } end
  end
  return #short == 0, short
end
DT.assessPrep = assess

local function report()
  local ok, short = assess()
  if ok then return DT.out("Ready. Bags packed, coffin optional.") end
  local parts = {}
  for _, s in ipairs(short) do parts[#parts + 1] = tostring(s.e.name) .. " " .. s.n .. "/" .. tostring(s.e.need) end
  DT.out("Short: " .. table.concat(parts, ", ") .. ".")
end

local function list()
  local got = false
  for _, e in ipairs(entries()) do
    got = true
    local name = clean(try(C_Item and C_Item.GetItemNameByID, e.id))
    local line = e.id .. " " .. tostring(e.name) .. " x" .. tostring(e.need) .. " — client: "
    if type(name) ~= "string" or name == "" then
      try(C_Item and C_Item.RequestLoadItemDataByID, e.id)
      line = line .. "not loaded yet"
    else
      line = line .. DT.safe(name, 64)
      if name:lower() ~= tostring(e.name):lower() then line = line .. "  <- check this ID" end
    end
    DT.out(line)
  end
  if not got then DT.out("Nothing on the list for you. Travel light.") end
end

-- ---------------------------------------------------------------- the roll call

local qid, lastCheck, open = 0, nil, nil
local answered = {}            -- [asker .. "#" .. q] = true

local function summary()
  local o = open
  open = nil
  if not o then return end
  local ready, short = {}, {}
  for _, k in ipairs(o.order) do
    local a = o.answers[k]
    if a.ok then ready[#ready + 1] = DT.display(k)
    else short[#short + 1] = DT.display(k) .. " (" .. a.short .. " short)" end
  end
  DT.out("Ready (" .. #ready .. "): " .. (#ready > 0 and table.concat(ready, ", ") or "none")
    .. ". Short (" .. #short .. "): " .. (#short > 0 and table.concat(short, ", ") or "none") .. ".")
  DT.out(CLOSING)
end

local function check()
  local t = DT.now()
  if lastCheck and t - lastCheck < CHECK_WINDOW then                  -- guard: check window
    return DT.out("Patience. The last roll call is still out.")
  end
  lastCheck = t
  -- Fix round 1 (F8a): the question id comes from the clock, so a /reload doesn't reuse ids the
  -- guild has already answered. 1-6 digits as before; the 60 s window keeps it unique.
  local now = clean(try(time))
  if type(now) == "number" then qid = math.floor(now) % 1000000 else qid = qid + 1 end
  open = { q = qid, answers = {}, order = {} }
  DT.send("PREPQ", { q = tostring(qid) })
  DT.out("Roll call sent. Answers in 10 seconds.")
  DT.after(ANSWER_WAIT, summary)
end

local function isKey(s) return type(s) == "string" and #s >= 1 and #s <= 64 and s:match("^.+%-[^%-]+$") ~= nil end
local function isQ(s) return type(s) == "string" and s:match("^%d%d?%d?%d?%d?%d?$") ~= nil end

-- Fix round 1 (F6c): at most one roll call per asker per 60 s is answered (the asker's own window).
local lastAsk = {}

DT.on("PREPQ", function(from, f)
  local p = prep()
  if not isQ(f.q) then p.badPrep = p.badPrep + 1 return end
  if not p.share then return end                                      -- guard: share gate
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
    if not prep().share then return end                               -- guard: share gate at answer time
    local ok, short = assess()
    DT.send("PREP", { q = q, to = from, ok = ok and "1" or "0", short = tostring(math.min(#short, MAX_SHORT)) })
  end)
end)

local function validPrep(f)
  if not isQ(f.q) or not isKey(f.to) or (f.ok ~= "0" and f.ok ~= "1") then return false end
  local n = type(f.short) == "string" and f.short:match("^%d%d?$") and tonumber(f.short)
  if not n or n > MAX_SHORT then return false end
  return (f.ok == "1") == (n == 0)
end

DT.on("PREP", function(from, f)
  if not validPrep(f) then                                            -- guard: PREP validation
    local p = prep()
    p.badPrep = p.badPrep + 1
    return
  end
  if DT.normKey(f.to) ~= DT.charKey() then return end                 -- guard: addressed to someone else (AUD-06: one spelling)
  if not open or tostring(open.q) ~= f.q then return end              -- guard: late answers
  if open.answers[from] then return end
  open.answers[from] = { ok = f.ok == "1", short = tonumber(f.short) }
  open.order[#open.order + 1] = from
end)

-- ---------------------------------------------------------------- the verb

local function verb(msg)
  local rest = msg:match("^prep%s+(.-)%s*$") or ""
  local p = prep()
  if rest == "" then return report()
  elseif rest == "list" then return list()
  elseif rest == "check" then return check()
  elseif rest == "share on" then p.share = true; return DT.out("sharing on. You'll answer roll calls: ready or not, and how many short.")
  elseif rest == "share off" then p.share = false; return DT.out("sharing off. Your bags are your own business.")
  elseif rest == "share" then return DT.out("sharing is " .. (p.share and "on" or "off") .. ". /dt prep share on/off")
  end
  return DT.out("/dt prep, /dt prep list, /dt prep check, /dt prep share on/off")
end

-- For the offline tests only.
DT._prep = { open = function() return open end, answered = function() return answered end }

DT.module({
  id = "prep",
  init = function() prep() end,
  ready = DT.errors,
  errorKey = "prep", lastKey = "lastPrep",
})
DT.verb("prep", verb, "prep [list/check/share on/off]")
