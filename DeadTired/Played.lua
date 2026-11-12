-- Dead Tired: the slowest-leveller award. Hours played per level, from guildies who share it.
-- Card 6 (docs/COWORK_BRIEF_dt_stretch.md on card/dt_stretch; R1-R6 ratified 2026-11-02), ported
-- from rc3's Played.lua onto the framework in Port 2. Logic and lines are rc3's; what changed:
-- full-name keys, the setting played.share as a card (typed: /dt slowest share on|off), the board
-- in a viewport (the award line still printed by /dt slowest), one board instead of per guild, and
-- R-P2-1 below in place of rc3's hook.
--
-- R-P2-1 (Port 2, ruled 11 Nov): play time is recorded and (with /dt slowest share on) shared only
-- after the player types /dt played. That verb calls the client's RequestTimePlayed() (a global,
-- guarded) and takes the next TIME_PLAYED_MSG within 10 s, once. A plain /played, another addon's
-- request, or any other TIME_PLAYED_MSG is ignored. No hook on any Blizzard function (rc3 hooked
-- SlashCmdList.PLAYED with hooksecurefunc; that is gone). The client prints its own played lines
-- in chat, as /played does; DT prints nothing over them.
-- Fix round 1 (F9): /dt slowest share off sends PLAYED {off=1}, and receivers delete the sender's
-- entry; entries carry t = time() and are dropped after 30 days.
-- Fix round 4 (R-F4-5): a master switch (optional = true, the framework's On card, default on).
-- Off: no events (the framework), inbound messages ignored, nothing sent, nothing printed unasked,
-- and each verb answers "played.enabled = off" and does nothing else. Off is not a withdrawal.
-- Fix round 4 (R-F4-7): /dt played with sharing off asks the client as before, then says how to
-- share; nothing is recorded or sent.
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local SEND_WINDOW = 60
local ASKED_WINDOW = 10      -- seconds from /dt played to its TIME_PLAYED_MSG (R-P2-1)
local SHOW = 5
local MAX_AGE = 30 * 86400
local CLOSING = "Only guildies running the addon who share their /played. Type /dt played to update yours."
local NO_CLIENT = "The client won't say how long you've played. Nothing recorded."
local HINT = "Sharing's off. /dt slowest share on"
local OFF = "played.enabled = off"
local EMPTY = "No contenders. Everyone's either fast or shy."

local function store()
  local db = DT.db()
  if type(db.played) ~= "table" then db.played = {} end
  local p = db.played
  if type(p.badPlayed) ~= "number" then p.badPlayed = 0 end
  if type(p.board) ~= "table" then p.board = {} end
  return p
end
local function board() return store().board end
DT.playedBoard = board
local function sharing() return DT.get("played", "share") == true end

-- F9: entries older than 30 days, or with no readable t, are dropped at load and whenever the
-- board is shown. If the clock can't be read, nothing is dropped.
local function epoch()
  local t = clean(try(time))
  return type(t) == "number" and t or nil
end
local function prune()
  local now = epoch()
  if not now then return end
  local b = board()
  for key, e in pairs(b) do
    if type(e) ~= "table" or type(e.t) ~= "number" or now - e.t > MAX_AGE then b[key] = nil end   -- guard: 30-day drop (F9)
  end
end
DT._playedPrune = prune

-- ---------------------------------------------------------------- /dt played (R-P2-1)

local askedAt = nil          -- DT.now() of the last /dt played, cleared by the report it asked for
local lastSend

local function ask()
  if type(RequestTimePlayed) ~= "function" then return DT.out(NO_CLIENT) end
  askedAt = DT.now()
  if not pcall(RequestTimePlayed) then askedAt = nil; return DT.out(NO_CLIENT) end
end

local function onPlayed(total)
  local at = askedAt
  askedAt = nil                                                        -- guard: one report per /dt played
  if not at or DT.now() - at >= ASKED_WINDOW then return end           -- guard: only after /dt played (R-P2-1)
  if not sharing() then return end                                     -- guard: share gate on sending
  if not DT.isMember() then return end
  local lvl = clean(try(UnitLevel, "player"))
  total = clean(total)
  if type(lvl) ~= "number" or lvl < 1 or lvl > 100 or lvl ~= math.floor(lvl) then return end
  if type(total) ~= "number" or total < 0 then return end
  local t = DT.now()
  if lastSend and t - lastSend < SEND_WINDOW then return end           -- guard: 60 s window
  lastSend = t
  local hours = math.floor(total / 360) / 10
  local me = DT.myKey()
  if me then board()[me] = { lvl = lvl, hours = hours, at = DT.stamp(), t = epoch() } end
  DT.send("PLAYED", { lvl = tostring(lvl), h = string.format("%.1f", hours) })
  if DT.slowestRedraw then DT.slowestRedraw() end
end

-- ---------------------------------------------------------------- inbound

local function valid(f)
  local lvl = type(f.lvl) == "string" and f.lvl:match("^%d%d?%d?$") and tonumber(f.lvl)
  if not lvl or lvl < 1 or lvl > 100 then return false end
  local h = type(f.h) == "string" and f.h:match("^%d+%.?%d?$") and tonumber(f.h)
  return h and h <= 100000
end

DT.on("PLAYED", function(from, f)
  if not DT.enabled("played") then return end                          -- guard: off ignores inbound (played)
  -- F9: a withdrawal is PLAYED {off=1} and nothing else; it deletes the sender's entry.
  if f.off ~= nil then
    if f.off == "1" and f.lvl == nil and f.h == nil then
      board()[from] = nil                                              -- guard: delete on off~1 (F9)
    else
      local p = store()
      p.badPlayed = p.badPlayed + 1
    end
    if DT.slowestRedraw then DT.slowestRedraw() end
    return
  end
  if not valid(f) then                                                 -- guard: PLAYED validation
    local p = store()
    p.badPlayed = p.badPlayed + 1
    return
  end
  board()[from] = { lvl = tonumber(f.lvl), hours = tonumber(f.h), at = DT.stamp(), t = epoch() }
  if DT.slowestRedraw then DT.slowestRedraw() end
end)

-- ---------------------------------------------------------------- the board

local function h1(x) return string.format("%.1f", x) end

-- Rows, slowest first (hours per level), a tie by name; level 1 left out.
function DT.slowestRows()
  prune()
  local keys, rows = {}, {}
  for key in pairs(board()) do keys[#keys + 1] = key end
  local name = DT.namer(keys)
  for key, e in pairs(board()) do
    if type(e) == "table" and type(e.lvl) == "number" and type(e.hours) == "number" then
      if e.lvl >= 2 then                                               -- guard: level-1 exclusion
        rows[#rows + 1] = { key = key, lvl = e.lvl, hours = e.hours, rate = e.hours / e.lvl, name = name(key) }
      end
    end
  end
  table.sort(rows, function(a, b)
    if a.rate ~= b.rate then return a.rate > b.rate end
    return a.name:lower() < b.name:lower()
  end)
  for i, r in ipairs(rows) do
    r.n = i .. "."
    r.rateText = h1(r.rate) .. " h/level"
    r.lvlText = "level " .. r.lvl
    r.hoursText = h1(r.hours) .. " h played"
    r.search = table.concat({ r.name, r.key, r.lvlText }, " ")
  end
  return rows
end

local vp, list, model

local function redraw()
  if model and vp and vp:IsShown() then model:set(DT.slowestRows()); list:refresh() end
end
DT.slowestRedraw = redraw

-- Fix round 4: the closing line is the viewport's footer (it wraps inside the window: the Port 2
-- walk's defect 2); every column but the name is as wide as its widest value, so "93.7 h played"
-- stays on one line; the tooltip is the name only (defect 4, Tim's ruling).
local function build()
  if vp then return end
  model = DT.listModel()
  vp = DT.viewport({ id = "slowest", title = "Glacial Progress", search = true, width = 420, height = 360, footer = CLOSING,
    onSearch = function(text) model:filter(text); list.offset = 0; list:refresh() end })
  list = DT.list(vp.body, model, { count = 14,
    empty = function(m) if #m.rows == 0 then return EMPTY end end,
    tip = function(row, tt) tt:AddLine(DT.safe(DT.nameOf(row.key), 48)) end,
    columns = { { key = "n", fixed = true, colour = "muted" }, { key = "name", flex = true },
      { key = "rateText", fixed = true }, { key = "lvlText", fixed = true, colour = "muted" },
      { key = "hoursText", fixed = true, colour = "muted" } } })
end

local function view(rows)
  build()
  model:set(rows)
  list:refresh()
  vp:Show()
end

-- The award line (rc3's), then the board.
function DT.slowest()
  local rows = DT.slowestRows()
  if #rows == 0 then
    DT.out(EMPTY)
  else
    local r = rows[1]
    DT.out("The Crypt Keeper's Award for Glacial Progress goes to " .. r.name .. ": " .. h1(r.rate)
      .. " hours a level (level " .. r.lvl .. ", " .. h1(r.hours) .. " h played).")
  end
  view(rows)
end

-- ---------------------------------------------------------------- verbs

local function verb(args)
  if not DT.enabled("played") then return DT.out(OFF) end              -- guard: off verbs do nothing else (slowest)
  local w = (args or ""):lower():gsub("%s+", " ")
  if w == "" then return DT.slowest()
  elseif w == "share on" then
    DT.set("played", "share", true)
    return DT.out("sharing your /played. Type /dt played to put yourself on the board.")
  elseif w == "share off" then
    DT.set("played", "share", false)
    return DT.out("not sharing your /played. Your entry is being withdrawn from guildies' boards.")
  elseif w == "share" then
    return DT.out("sharing your /played is " .. (sharing() and "on" or "off") .. ". /dt slowest share on/off")
  end
  return DT.out("/dt slowest, or /dt slowest share on/off")
end

-- F9: switching sharing off (typed, /dt set or the card) withdraws this character's entry from
-- guildies' boards: one message, queued as usual.
local function shareChanged(on)
  if on then return end
  if not DT.enabled("played") then return end                          -- guard: off sends nothing (played)
  local me = DT.myKey()
  if me then board()[me] = nil end
  DT.send("PLAYED", { off = "1" })                                     -- guard: withdrawn when sharing off (F9)
  redraw()
end

DT.keySource(function() return board() end)

DT.module({
  id = "played",
  title = "Glacial Progress",
  optional = true,
  settings = {
    { key = "share", type = "bool", default = false, label = "Share my play time", verb = "slowest share on|off",
      onChange = shareChanged,
      desc = "After /dt played, tells guildies running Dead Tired your level and hours played, for the slowest-leveller board. Off until you switch it on; switching it off withdraws you from their boards." },
  },
  verbs = {
    { verb = "slowest", usage = "slowest [share on/off]", fn = verb },
    { verb = "played", usage = "played", fn = function()
        if not DT.enabled("played") then return DT.out(OFF) end        -- guard: off verbs do nothing else (played)
        ask()
        if not sharing() then DT.out(HINT) end                         -- guard: the hint only when sharing is off
      end },
  },
  init = function() store(); prune() end,
  fit = function() build(); model:set(DT.slowestRows()); list:refresh() end,
  events = { TIME_PLAYED_MSG = onPlayed },
})

-- For the offline tests only.
DT._played = { asked = function() return askedAt end, CLOSING = CLOSING, EMPTY = EMPTY, NO_CLIENT = NO_CLIENT, HINT = HINT,
  vp = function() return vp end, list = function() return list end }
