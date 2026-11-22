-- Dead Tired: the death leaderboard (dt_deathboard, 0.4.0; docs/COWORK_BRIEF_dt_deathboard.md,
-- rulings L1-L6 agreed 22 Nov 2026). Liliac's idea, design block G. Who dies most, from guildies who
-- share their deaths.
--
-- L1: each guildie who shares their deaths (crypt.share, no new switch) keeps their own tally and
--     sends it as TALLY { n = total, w = this week, we = epoch the week ends, hc = "1"|"0" }: after
--     each of their deaths, 10 s after login, and when sharing is switched on. Switching crypt.share
--     off sends TALLY { off = "1" }, and receivers delete the entry; that send happens even while
--     this module is off (as Played's does, Tim 12 Nov).
-- L2: the first time a character needs its tally, it starts from that character's own deaths
--     already in the graveyard (mine = true, who = its key); w counts those since the last reset.
--     The footer says older deaths may not be counted.
-- L3: a week ends at the game's weekly reset (C_DateAndTime.GetSecondsUntilWeeklyReset, guarded).
--     Past a tally's we, its w reads 0, own and received. Unreadable: we = 0 and w is never zeroed.
-- L4: one footer line, "<zone> claimed <n> this week.", from the graveyard's deaths since the last
--     reset (yours and the ones you heard); left out with none. No killer of any kind: no combat data.
-- L5: /dt deaths. Rows: skull (hardcore), name (class colour, no realm), total, this week; sorted by
--     this week, then total, then name; entries not heard for 30 days drop off; capped at 200.
-- Deaths are not detected here: Crypt signals "mydeath" after it records your own.
-- The On card governs the window and receiving. Your own count keeps going while the module is off
-- (nothing is sent or printed then), so it is right when you switch the board back on.
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local WEEK = 7 * 86400
local MAX_AGE = 30 * 86400
local CAP = 200
local MAXN = 100000
local LOGIN_WAIT = 10
local ZONE_MAX = 48
local SKULL = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t"
local TITLE = "Body Count"
local EMPTY = "No deaths shared yet. /dt rip share on to join the board."
local OLDER = "Older deaths may not be counted."
local CLOSING = "Only guildies running the addon who share their deaths."
local ZONE_LINE = "%s claimed %d this week."
local OFF = "deathboard.enabled = off"

-- ---------------------------------------------------------------- the store

local function store()
  local db = DT.db()
  if type(db.deathboard) ~= "table" then db.deathboard = {} end
  local s = db.deathboard
  if type(s.mine) ~= "table" then s.mine = {} end
  if type(s.board) ~= "table" then s.board = {} end
  if type(s.badTally) ~= "number" then s.badTally = 0 end
  return s
end
local function board() return store().board end
DT.deathBoard = board

local function epoch()
  local t = clean(try(time))
  return type(t) == "number" and t or nil
end

-- ---------------------------------------------------------------- the week (L3)

local function untilReset()
  local f = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
  local s = clean(try(f))
  if type(s) ~= "number" or s < 0 or s > WEEK + 3600 then return nil end
  return s
end

-- The epoch this week ends, or nil when the clock or the reset can't be read.
function DT.weekEnd()
  local now, s = epoch(), untilReset()
  if not now or not s then return nil end
  return math.floor(now + s)
end

-- The week's start as the graveyard writes its dates (DT.stamp: local "%Y-%m-%d %H:%M:%S").
local function weekStartStamp()
  local we = DT.weekEnd()
  if not we then return nil end
  local s = clean(try(date, "%Y-%m-%d %H:%M:%S", we - WEEK))
  return type(s) == "string" and s or nil
end

local function since(e, start)
  return start and type(e) == "table" and type(e.at) == "string" and e.at >= start
end

-- A tally's this-week count as it reads now.
local function weekOf(e, now)
  if type(e.we) == "number" and e.we > 0 and now and now >= e.we then return 0 end   -- guard: week zeroing (received)
  return e.w
end

-- ---------------------------------------------------------------- your own tally (L2, L3)

local function seed(me)
  if DT.cryptRepair then DT.cryptRepair() end
  local start = weekStartStamp()
  local n, w = 0, 0
  for _, e in ipairs(DT.deaths and DT.deaths() or {}) do
    if type(e) == "table" and e.mine == true and e.who == me then            -- guard: own deaths only (L2)
      n = n + 1
      if since(e, start) then w = w + 1 end
    end
  end
  return { n = n, w = w, we = DT.weekEnd() or 0 }
end

-- This character's tally, seeded the first time, rolled to this week. nil without a key.
local function own()
  local me = DT.myKey()
  if not me then return nil end
  local m = store().mine
  if type(m[me]) ~= "table" then m[me] = seed(me) end                      -- guard: seed once per character
  local t = m[me]
  local now, we = epoch(), DT.weekEnd()
  if t.we > 0 and now and now >= t.we then                                 -- guard: week zeroing (own)
    t.w = 0
    t.we = 0
  end
  if we then t.we = we end
  return t, me
end
DT.deathTally = own

local function hardcore()
  return (try(C_GameRules and C_GameRules.IsHardcoreActive)) == true
end

local function sharing() return DT.get("crypt", "share") == true end

-- ---------------------------------------------------------------- sending (L1)

local redraw

local function mineEntry(t)
  return { n = t.n, w = t.w, we = t.we, hc = hardcore(), at = DT.stamp(), t = epoch() }
end

local function sendTally()
  if not sharing() then return false end                                   -- guard: share gate
  if not DT.enabled("deathboard") or not DT.enabled("crypt") then return false end   -- guard: module switch (send)
  if not DT.isMember() then return false end
  local t, me = own()
  if not t then return false end
  local e = mineEntry(t)
  board()[me] = e
  DT.send("TALLY", { n = tostring(t.n), w = tostring(t.w), we = tostring(t.we), hc = e.hc and "1" or "0" })
  if redraw then redraw() end
  return true
end

local function withdraw()
  local me = DT.myKey()
  if me then board()[me] = nil end
  DT.send("TALLY", { off = "1" })                                          -- guard: withdrawn when sharing off
  if redraw then redraw() end
end

DT.listen("setting", function(id, key, v)
  if id ~= "crypt" or key ~= "share" then return end
  local ok, err = pcall(function()
    if v == false then withdraw()                                          -- guard: withdraws even while off
    elseif v == true then sendTally() end
  end)
  if not ok then DT.fail("deathboard", "share", err) end
end)

-- Crypt.lua's one line: after onDead records your death.
DT.listen("mydeath", function()
  local ok, err = pcall(function()
    local me = DT.myKey()
    if not me then return end
    local fresh = type(store().mine[me]) ~= "table"
    local t = own()
    if not fresh then                                                      -- a fresh seed already counted this death
      t.n = math.min(MAXN, t.n + 1)
      t.w = math.min(t.n, t.w + 1)
    end
    sendTally()
  end)
  if not ok then DT.fail("deathboard", "mydeath", err) end
end)

local sentLogin = false
DT.listen("greeted", function()
  if sentLogin then return end
  sentLogin = true
  DT.after(LOGIN_WAIT, function()
    local ok, err = pcall(function() own(); sendTally() end)
    if not ok then DT.fail("deathboard", "login", err) end
  end)
end)

-- ---------------------------------------------------------------- receiving

local function int(s, digits)
  if type(s) ~= "string" or #s > digits or not s:match("^%d+$") then return nil end
  return tonumber(s)
end

local function valid(f)
  local n, w, we = int(f.n, 6), int(f.w, 6), int(f.we, 12)
  if not n or not w or not we then return nil end
  if w > n or n > MAXN then return nil end
  if f.hc ~= "0" and f.hc ~= "1" then return nil end
  return { n = n, w = w, we = we, hc = f.hc == "1" }
end

local function bad() local s = store(); s.badTally = s.badTally + 1 end

local function size(b) local k = 0 for _ in pairs(b) do k = k + 1 end return k end

-- Room for one more entry: the one heard longest ago goes.
local function makeRoom(b)
  while size(b) >= CAP do
    local oldKey, oldT
    for key, e in pairs(b) do
      local t = type(e) == "table" and type(e.t) == "number" and e.t or -1
      if not oldKey or t < oldT or (t == oldT and key < oldKey) then oldKey, oldT = key, t end
    end
    b[oldKey] = nil
  end
end

DT.on("TALLY", function(from, f)
  if not DT.enabled("deathboard") then return end                          -- guard: off ignores inbound (deathboard)
  if f.off ~= nil then
    if f.off == "1" and f.n == nil and f.w == nil and f.we == nil and f.hc == nil then
      board()[from] = nil                                                  -- guard: delete on off=1
    else
      bad()
    end
    if redraw then redraw() end
    return
  end
  local v = valid(f)
  if not v then bad() return end                                           -- guard: TALLY validation
  local b = board()
  if b[from] == nil then makeRoom(b) end                                   -- guard: board cap
  v.at, v.t = DT.stamp(), epoch()
  b[from] = v
  if redraw then redraw() end
end)

-- ---------------------------------------------------------------- the board

local function prune()
  local now = epoch()
  if not now then return end
  local b = board()
  for key, e in pairs(b) do
    if type(e) ~= "table" or type(e.t) ~= "number" or now - e.t > MAX_AGE then b[key] = nil end   -- guard: 30-day drop
  end
end
DT._deathPrune = prune

function DT.deathRows()
  prune()
  local b = board()
  if sharing() then                                                        -- your own row as it is now
    local t, me = own()
    if t then b[me] = mineEntry(t) end
  end
  local keys = {}
  for key in pairs(b) do keys[#keys + 1] = key end
  local name = DT.namer(keys)
  local roster = DT.rosterClasses()
  local now = epoch()
  local rows = {}
  for key, e in pairs(b) do
    if type(e) == "table" and type(e.n) == "number" and type(e.w) == "number" then
      local wk = weekOf(e, now)
      local cr, cg, cb = DT.classColour(key, roster)
      local nm = name(key)
      rows[#rows + 1] = { key = key, n = e.n, w = wk, name = nm, hc = e.hc and SKULL or "",
        nameRGB = cr and { cr, cg, cb } or nil, total = e.n .. " total", week = wk .. " this week",
        search = table.concat({ nm, key, e.hc and "hardcore" or "" }, " ") }
    end
  end
  table.sort(rows, function(a, c)
    if a.w ~= c.w then return a.w > c.w end
    if a.n ~= c.n then return a.n > c.n end
    if a.name:lower() ~= c.name:lower() then return a.name:lower() < c.name:lower() end
    return a.key < c.key
  end)
  return rows
end

-- L4: this week's deadliest zone from the graveyard (yours and the deaths you heard), or nil.
function DT.deadliestZone()
  local start = weekStartStamp()
  if not start then return nil end
  local counts = {}
  for _, e in ipairs(DT.deaths and DT.deaths() or {}) do
    if since(e, start) and type(e.zone) == "string" and e.zone ~= "" then
      counts[e.zone] = (counts[e.zone] or 0) + 1
    end
  end
  local best, bn
  for z, k in pairs(counts) do
    if not best or k > bn or (k == bn and z < best) then best, bn = z, k end
  end
  return best, bn
end

function DT.deathFooter()
  local z, k = DT.deadliestZone()
  local parts = {}
  if z then parts[#parts + 1] = ZONE_LINE:format(DT.safe(z, ZONE_MAX), k) end
  parts[#parts + 1] = OLDER
  parts[#parts + 1] = CLOSING
  return table.concat(parts, " ")
end

local vp, list, model

local function fill()
  model:set(DT.deathRows())
  vp:setFooter(DT.deathFooter())
  list:refresh()
end

redraw = function()
  if model and vp and vp:IsShown() then fill() end
end

local function build()
  if vp then return end
  model = DT.listModel()
  vp = DT.viewport({ id = "deaths", title = TITLE, search = true, width = 400, height = 380, footer = CLOSING,
    onSearch = function(text) model:filter(text); list.offset = 0; list:refresh() end })
  list = DT.list(vp.body, model, { count = 12, tipCovers = { "name" },
    empty = function(m) if #m.rows == 0 then return EMPTY end end,
    tip = function(row, tt)
      tt:AddLine(DT.safe(DT.nameOf(row.key), 48))
      if row.hc ~= "" then tt:AddLine("Hardcore", 0.8, 0.8, 0.8) end
    end,
    columns = { { key = "hc", fixed = true, raw = true }, { key = "name", flex = true, rgb = "nameRGB" },
      { key = "total", fixed = true, colour = "muted" }, { key = "week", fixed = true } } })
end

function DT.deathsView()
  if not DT.isMember() then return end
  build()
  fill()
  vp:Show()
end

DT.keySource(function() return board() end)

DT.module({
  id = "deathboard",
  title = TITLE,
  optional = true,
  switchDesc = "The death leaderboard, /dt deaths. Off, it shows nothing and hears no tallies. Sharing your own count follows /dt rip share.",
  verbs = {
    { verb = "deaths", usage = "deaths", fn = function()
        if not DT.enabled("deathboard") then return DT.out(OFF) end        -- guard: off verbs do nothing else (deaths)
        DT.deathsView()
      end },
  },
  init = function() store(); prune() end,
  fit = function() build(); fill() end,
})

-- For the offline tests only.
DT._deathboard = { EMPTY = EMPTY, CLOSING = CLOSING, OLDER = OLDER, ZONE_LINE = ZONE_LINE, SKULL = SKULL, OFF = OFF,
  TITLE = TITLE, CAP = CAP, vp = function() return vp end, list = function() return list end, valid = valid,
  sendTally = sendTally }
