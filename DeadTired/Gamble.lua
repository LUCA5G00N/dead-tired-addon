-- Dead Tired: the Crypt's Table, guild gambling (dt_gamble, 0.6.0; docs/COWORK_BRIEF_dt_gamble.md, rulings
-- D1-D10, ratified by Tim's merge of PR #38, 23 Nov 2026). Liliac's idea; Tim's sketch of 22 Nov.
--
-- D1  Chips, not gold: every character starts with 1,000. No gold ever moves through DT.
-- D2  Party only: everyone in a game is in one party or raid with you. Game messages go on the GUILD
--     channel like every DT message (Comms is unchanged); a client ignores a game it isn't in.
-- D3  At each weekly reset (DeathBoard's L3 read, DT.weekEnd) a character under 1,000 is brought up to
--     1,000; anyone above keeps theirs. If the reset can't be read, nobody is topped up.
-- D4  Deathroll: two players, stake S; first roll 1-S, then 1-(last result), taking turns; whoever
--     rolls 1 loses S to the other.
-- D5  High-low: a host opens a table at S; party members join; Final call, or 20 s after the last join,
--     closes it; everyone rolls 1-S; the lowest pays the highest the difference. Ties at either end are
--     rolled off by the tied players only (1-S). Fewer than two at the close: the table folds.
-- D6  S is a whole number, 2-500, and never more than you hold.
-- D7  Only the game's own RandomRoll counts. Every client reads every roll from CHAT_MSG_SYSTEM through
--     the client's own RANDOM_ROLL_RESULT and settles the game from the rolls IT saw. The host's RESULT
--     carries the host's rolls; a client that saw different ones, or missed one, marks the game
--     disputed and moves nothing. Each player's own client is the only one that changes that player's
--     balance.
-- D8  /dt gamble board: everyone who has played. CHIPS { b, w, bb, we } after every settled game and
--     10 s after login; playing is the opt-in; board off sends CHIPS {off=1}.
-- D9  Nothing to chat: results show in the window and one DT.out line, only for games you were in.
--
-- Messages (all GUILD, through DT.send; validated, bad ones counted):
--   GAME   { g = n, k = "dr"|"hl", s = S, o = <opponent's full name, deathroll only> }   from the host
--   JOIN   { h = <host key>, g = n }                                                      from a joiner
--   CALL   { g = n, p = "<full name>,<full name>,..." }  the players, host first; rolling starts
--   RESULT { g = n, r = "<canonical rolls>" }            from the host, when the host's game is settled
--   FOLD   { g = n }                                     from the host: the table folded, nothing moved
--   CHIPS  { b, w, bb, we } | { off = "1" }
-- Players are named by their full name (Forever's two-part name), as the roll lines name them (probe,
-- 23 Nov). Two players with the same full name can't sit at one table.
--
-- Round 2 (dt_gamble2, 0.7.0; T1-T12, PR #42): the New game panel, challenge your target (T5: the target's
-- NAME only, on press, party members only, read in readTarget() alone), Accept/Decline, Cancel/Leave,
-- Rematch / Double or nothing / Same again, the your-turn glow and an opt-in sound, a bar launcher.
--   DECLINE { h = <host key>, g = n }          from the challenged player
--   LEAVE   { h = <host key>, g = n }          from a joiner, before the call
--   FOLD    { g = n, why = "cancel" }          the host cancelled (0.6.0 clients read it as a plain fold)
--   GAME    { ..., re = "1"|"2" }              a rematch / double or nothing (0.6.0 clients ignore re)
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local START = 1000
local MIN_STAKE, MAX_STAKE = 2, 500
local MAX_PLAYERS = 40
local CLOSE_AFTER = 20                  -- D5: seconds after the last join
local TIMEOUT = 120                     -- a game nobody moves folds after this (shortened by debug, never saved)
local RESULT_WAIT = 5                   -- how long a client waits for its own last roll after the host's RESULT
local LOGIN_WAIT = 10
local WEEK = 7 * 86400
local MAX_AGE = 30 * 86400
local BOARD_CAP = 200
local WALLET_CAP = 50
local MAX_ROLLS = 200
local MAXB = 10000000
local NAME_MAX = 48
local LOG_MAX = 8

local TITLE = "The Crypt's Table"
local BOARD_TITLE = "The Crypt's Ledger"
local EMPTY = "No games in your party. Start one."
local BOARD_EMPTY = "Nobody has played yet. The table is cold."
local CLOSING = "Only guildies running the addon who have played."
local TABLE_FOOTER = "Chips only. No gold changes hands."
local BEATDOWN = "Biggest beat-down this week: %s, %d chips."
local NO_RESET = "The weekly reset can't be read, so nobody is topped up."
local OUT_OF_TURN = "%s rolled out of turn."
local WRONG_RANGE = "%s rolled the wrong range."
local DISPUTED = "Disputed. Nothing moved."
local FOLDED = "The table folds. Nothing moved."
local TIMED_OUT = "Nobody rolled for too long. The table folds. Nothing moved."
local USAGE = "/dt gamble [join|decline|leave|cancel|deathroll [<name>] <stake>|highlow <stake>|call|roll|rematch|double|again|board|sound]"
local DECLINED = "%s declined."
local CANCELLED = "%s cancelled."
local LEFT = "%s left the table."
local NO_TARGET = "Target a party member first."
local NOT_RUNNING = "Not running Dead Tired."
local OVER_CAP = "Over the 500 cap."
local PANEL_HEAD = "New game: pick a stake, then a game."
local REMATCH_LINE = "%s wants a rematch for %d."
local DOUBLE_LINE = "%s says double or nothing: %d."
local SOUND_KIT_ID = 8960                -- SOUNDKIT.READY_CHECK, used when the SOUNDKIT table isn't there
local STAKE_LINE = "A stake is a whole number from 2 to 500."
local POOR = "You hold %d chips. Not enough for that stake."
local NO_PARTY = "You need a party. The dead don't gamble alone."
local OFF = "gamble.enabled = off"

-- ---------------------------------------------------------------- the store

local function store()
  local db = DT.db()
  if type(db.gamble) ~= "table" then db.gamble = {} end
  local s = db.gamble
  if type(s.wallet) ~= "table" then s.wallet = {} end
  if type(s.board) ~= "table" then s.board = {} end
  if type(s.bad) ~= "number" then s.bad = 0 end
  if type(s.seq) ~= "number" then s.seq = 0 end
  return s
end
local function board() return store().board end
local function bad() local s = store(); s.bad = s.bad + 1 end

local function epoch()
  local t = clean(try(time))
  return type(t) == "number" and t or nil
end
local function weekEnd() return DT.weekEnd and DT.weekEnd() or nil end

local function size(t) local k = 0 for _ in pairs(t) do k = k + 1 end return k end

-- Room for one more: the entry seen longest ago goes (key `keep` never).
local function makeRoom(t, cap, keep)
  while size(t) >= cap do
    local oldKey, oldT
    for key, e in pairs(t) do
      if key ~= keep then
        local at = type(e) == "table" and type(e.t) == "number" and e.t or -1
        if not oldKey or at < oldT or (at == oldT and key < oldKey) then oldKey, oldT = key, at end
      end
    end
    if not oldKey then return end
    t[oldKey] = nil
  end
end

-- ---------------------------------------------------------------- the wallet (D1, D3)

local resetUnread = false

-- This character's wallet, rolled to this week. nil without a key.
local function wallet(peek)
  local me = DT.myKey()
  if not me then return nil end
  local w = store().wallet
  local we = weekEnd()
  resetUnread = we == nil
  if type(w[me]) ~= "table" then
    if peek then return nil end                                            -- looking never makes a wallet
    makeRoom(w, WALLET_CAP, me)                                            -- guard: wallet cap
    w[me] = { b = START, w = 0, bb = 0, we = we or 0, t = epoch() }        -- D1: 1,000 to start
  end
  local t = w[me]
  local now = epoch()
  if t.we > 0 and now and now >= t.we then                                 -- a new week
    t.w, t.bb = 0, 0
    if we and t.b < START then t.b = START end                             -- guard: top-up threshold (D3)
    t.we = 0
  end
  if we then t.we = we end
  return t, me
end
DT.gambleWallet = wallet

local function boardOn() return DT.get("gamble", "board") == true end

local redrawBoard

local function mineEntry(t)
  return { b = t.b, w = t.w, bb = t.bb, we = t.we, t = epoch() }
end

local function sendChips()
  if not boardOn() then return false end                                   -- guard: board switch (send)
  if not DT.enabled("gamble") or not DT.isMember() then return false end   -- guard: module switch (send)
  local t, me = wallet()
  if not t or not t.played then return false end
  board()[me] = mineEntry(t)
  DT.send("CHIPS", { b = tostring(t.b), w = tostring(t.w), bb = tostring(t.bb), we = tostring(t.we) })
  if redrawBoard then redrawBoard() end
  return true
end

local function withdraw()
  local me = DT.myKey()
  if me then board()[me] = nil end
  DT.send("CHIPS", { off = "1" })                                          -- guard: withdraw on board off
  if redrawBoard then redrawBoard() end
end

-- ---------------------------------------------------------------- the party (D2)

local function lower(s) return type(s) == "string" and s:lower() or nil end

-- Everyone in your party or raid, yourself included: { [lower full name] = full name }.
local function party()
  local out = {}
  local me = DT.fullName(clean(try(GetUnitName, "player", true)))
  if me then out[me:lower()] = me end
  local n = clean(try(GetNumGroupMembers)) or 0
  if type(n) ~= "number" or n < 1 then return out, false end
  local raid = clean(try(IsInRaid)) == true
  local units = raid and n or (n - 1)
  for i = 1, math.min(units, MAX_PLAYERS) do
    local name = DT.fullName(clean(try(GetUnitName, (raid and "raid" or "party") .. i, true)))
    if name then out[name:lower()] = name end
  end
  return out, true
end
DT.gambleParty = party

local function inParty(name)
  local p = party()
  return name ~= nil and p[lower(name)] ~= nil                             -- guard: party check
end

local function myName() return DT.fullName(clean(try(GetUnitName, "player", true))) end

-- ---------------------------------------------------------------- the roll reader (D7, probe 23 Nov)

-- RANDOM_ROLL_RESULT ("%s rolls %d (%d-%d)" on Forever) into a pattern. Positional forms ("%2$d") are
-- honoured; order[i] says which argument capture i is (1 name, 2 roll, 3 min, 4 max).
function DT.rollPattern(fmt)
  if type(fmt) ~= "string" or fmt == "" then return nil end
  local out, order, n, i = {}, {}, 0, 1
  while i <= #fmt do
    local pos, conv, e = fmt:match("^%%(%d*)%$?([sd])()", i)
    if conv then
      n = n + 1
      order[n] = tonumber(pos) or n
      out[#out + 1] = conv == "s" and "(.-)" or "(%-?%d+)"
      i = e
    else
      local c = fmt:sub(i, i)
      if c:match("[%^%$%(%)%%%.%[%]%*%+%-%?]") then c = "%" .. c end
      out[#out + 1] = c
      i = i + 1
    end
  end
  if n ~= 4 then return nil end
  return { pat = "^" .. table.concat(out) .. "$", order = order }
end

local compiled
local function reader()
  if compiled == nil then
    compiled = DT.rollPattern(clean(RANDOM_ROLL_RESULT)) or false
  end
  return compiled or nil
end
DT._gambleReset = function() compiled = nil end

-- A roll line into name, roll, min, max; nil for anything else (a secret line is never parsed).
function DT.readRoll(msg)
  if DT.secret(msg) or type(msg) ~= "string" then return nil end          -- guard: secret message skipped
  local r = reader()
  if not r then return nil end
  local caps = { msg:match(r.pat) }
  if #caps ~= 4 then return nil end
  local a = {}
  for j = 1, 4 do a[r.order[j]] = caps[j] end
  local name = DT.fullName(a[1])
  local roll, lo, hi = tonumber(a[2]), tonumber(a[3]), tonumber(a[4])
  if not name or not roll or not lo or not hi then return nil end
  return name, roll, lo, hi
end

-- ---------------------------------------------------------------- games

local games = {}            -- [id] = game, this session only
local order = {}            -- ids, newest last
local selected              -- the game the table window shows (a click, or a new challenge to you)
local timeout = TIMEOUT
local redraw
local listener

local function gameId(host, n) return host .. "#" .. n end

local function addLog(g, line)
  g.log[#g.log + 1] = line
  while #g.log > LOG_MAX do table.remove(g.log, 1) end
end

local function amIn(g)
  local me = lower(myName())
  if not me then return false end
  for _, n in ipairs(g.players) do if lower(n) == me then return true end end
  return false
end

local function live(g) return g.state == "open" or g.state == "rolling" end

-- A game is yours if you host it, joined it, or were challenged to it (T11: who gets the printed lines).
local function involved(g)
  return g.mine or g.joined or (g.kind == "dr" and g.opp ~= nil and lower(g.opp) == lower(myName()))
end

-- The CHAT_MSG_SYSTEM listener exists only while a game you're in is open (working rules).
local function listening()
  for _, g in pairs(games) do
    if live(g) and (g.mine or g.joined) then return true end
  end
  return false
end

local onSystem
local function relisten()
  if not listener then
    listener = CreateFrame("Frame")
    listener:SetScript("OnEvent", function(_, ev, msg)
      if ev ~= "CHAT_MSG_SYSTEM" then return end
      local ok, err = pcall(onSystem, msg)
      if not ok then DT.fail("gamble", "roll", err) end
    end)
  end
  if listening() and DT.enabled("gamble") then
    listener:RegisterEvent("CHAT_MSG_SYSTEM")
  else
    listener:UnregisterEvent("CHAT_MSG_SYSTEM")                            -- guard: listener unregister
  end
end
DT._gambleListening = function() return listener ~= nil and listener:IsEventRegistered("CHAT_MSG_SYSTEM") end

local function touch(g)
  g.moves = (g.moves or 0) + 1
  local mark = g.moves
  DT.after(timeout, function()
    if g.moves == mark and live(g) then                                    -- guard: time-out
      g.state = "folded"
      addLog(g, TIMED_OUT)
      if g.joined or g.mine then DT.out(TIMED_OUT) end
      relisten()
      if redraw then redraw() end
    end
  end)
end

local function newGame(host, n, kind, stake, hostName, opp)
  local id = gameId(host, n)
  local g = { id = id, host = host, n = n, kind = kind, s = stake, hostName = hostName, opp = opp,
    players = { hostName }, state = "open", rolls = {}, log = {}, phase = 0, t = epoch() }
  games[id] = g
  order[#order + 1] = id
  while #order > 20 do games[table.remove(order, 1)] = nil end
  touch(g)
  return g
end

-- ---------------------------------------------------------------- the game state (D4, D5)

local function expect(g, names, ph)
  g.phase = ph
  g.want = {}
  for _, n in ipairs(names) do g.want[lower(n)] = true end
  g.seen = {}
end

local afterStart                         -- turnCheck, set once it exists
local function startRolling(g)
  g.state = "rolling"
  g.base = nil
  if g.kind == "dr" then
    g.turn, g.cur = 1, g.s
    addLog(g, g.players[1] .. " rolls first, 1-" .. g.s .. ".")
  else
    g.stage = "all"
    expect(g, g.players, 1)
    addLog(g, "Everyone rolls 1-" .. g.s .. ".")
  end
  touch(g)
  if afterStart then afterStart() end
end

-- Phase results: the rolls of phase ph, as { [lower name] = roll }.
local function phaseRolls(g, ph)
  local out = {}
  for _, r in ipairs(g.rolls) do if r.ph == ph then out[lower(r.name)] = r end end
  return out
end

local function ends(g, ph, names)
  local rs = phaseRolls(g, ph)
  local hiV, loV
  for _, n in ipairs(names) do
    local v = rs[lower(n)].roll
    if not hiV or v > hiV then hiV = v end
    if not loV or v < loV then loV = v end
  end
  local hi, lo = {}, {}
  for _, n in ipairs(names) do
    local v = rs[lower(n)].roll
    if v == hiV then hi[#hi + 1] = n end
    if v == loV then lo[#lo + 1] = n end
  end
  return hi, lo, hiV, loV
end

local settleLocal

-- After the last roll of a high-low phase: settle, or roll off a tie (D5).
local function nextPhase(g)
  local ph = g.phase
  if g.stage == "all" then
    local hi, lo, hiV, loV = ends(g, ph, g.players)
    if hiV == loV then                                                     -- everyone tied: everyone again
      addLog(g, "All square. Everyone rolls again.")
      expect(g, g.players, ph + 1)
      return
    end
    g.base = { hiV = hiV, loV = loV, hi = hi, lo = lo }
    g.winner = #hi == 1 and hi[1] or nil
    g.loser = #lo == 1 and lo[1] or nil
  elseif g.stage == "high" then
    local hi = ends(g, ph, g.tied)
    if #hi == 1 then g.winner = hi[1] else g.tied = hi end
  elseif g.stage == "low" then
    local _, lo = ends(g, ph, g.tied)
    if #lo == 1 then g.loser = lo[1] else g.tied = lo end
  end
  if not g.winner then                                                     -- guard: tie for high rolled off
    if g.stage ~= "high" then g.tied = g.base.hi end
    g.stage = "high"
    addLog(g, "A tie at the top: " .. table.concat(g.tied, ", ") .. " roll again.")
    expect(g, g.tied, ph + 1)
    return
  end
  if not g.loser then                                                      -- guard: tie for low rolled off
    if g.stage ~= "low" then g.tied = g.base.lo end
    g.stage = "low"
    addLog(g, "A tie at the bottom: " .. table.concat(g.tied, ", ") .. " roll again.")
    expect(g, g.tied, ph + 1)
    return
  end
  g.amount = g.base.hiV - g.base.loV
  settleLocal(g)
end

-- One roll line, for one game. Returns true when the game moved.
local function rollFor(g, name, roll, lo, hi)
  local who = lower(name)
  if not amIn(g) and not g.watch then return false end
  local isPlayer = false
  for _, n in ipairs(g.players) do if lower(n) == who then isPlayer = true; name = n end end
  if not isPlayer then return false end                                    -- a bystander's roll: not ours
  if g.kind == "dr" then
    if lower(g.players[g.turn]) ~= who then                                -- guard: turn check
      addLog(g, OUT_OF_TURN:format(name)); return true
    end
    if lo ~= 1 or hi ~= g.cur then                                         -- guard: range check
      addLog(g, WRONG_RANGE:format(name)); return true
    end
    g.rolls[#g.rolls + 1] = { name = name, roll = roll, max = hi, ph = 1 }
    addLog(g, name .. " rolls " .. roll .. " (1-" .. hi .. ").")
    if roll == 1 then
      g.loser = name
      g.winner = g.players[3 - g.turn]
      g.amount = g.s
      settleLocal(g)
    else
      g.cur = roll
      g.turn = 3 - g.turn
    end
  else
    if not g.want[who] or g.seen[who] then                                 -- guard: turn check (high-low)
      addLog(g, OUT_OF_TURN:format(name)); return true
    end
    if lo ~= 1 or hi ~= g.s then                                           -- guard: range check (high-low)
      addLog(g, WRONG_RANGE:format(name)); return true
    end
    g.seen[who] = true
    g.rolls[#g.rolls + 1] = { name = name, roll = roll, max = hi, ph = g.phase }
    addLog(g, name .. " rolls " .. roll .. ".")
    local left = false
    for w in pairs(g.want) do if not g.seen[w] then left = true end end
    if not left then nextPhase(g) end
  end
  if #g.rolls > MAX_ROLLS then g.state = "folded"; addLog(g, FOLDED) end
  return true
end

-- Your roll's range in game g, or nil when it isn't your turn.
local function myRange(g)
  if not g or g.state ~= "rolling" or not amIn(g) then return nil end
  local me = lower(myName())
  if g.kind == "dr" then
    if lower(g.players[g.turn]) == me then return g.cur end
    return nil
  end
  if g.want and g.want[me] and not g.seen[me] then return g.s end
  return nil
end

local sounds = 0
local function turnSound()
  if DT.get("gamble", "sound") ~= true then return end                     -- guard: sound only when switched on
  local kit = clean(try(function() return SOUNDKIT and SOUNDKIT.READY_CHECK end)) or SOUND_KIT_ID
  sounds = sounds + 1
  try(PlaySound, kit)
end
DT._gambleSounds = function() return sounds end


-- T6: when it becomes your turn in any game you're in: the sound (if on). The glow follows in fill().
local function turnCheck()
  for _, g in pairs(games) do
    local now = myRange(g) ~= nil
    if now and not g.wasMine then turnSound() end
    g.wasMine = now
  end
end

afterStart = function() turnCheck() end

onSystem = function(msg)
  if not DT.enabled("gamble") then return end                              -- guard: module switch (rolls)
  local name, roll, lo, hi = DT.readRoll(msg)
  if not name then return end
  local moved = false
  for _, id in ipairs(order) do
    local g = games[id]
    if g and g.state == "rolling" and (g.mine or g.joined) then
      if rollFor(g, name, roll, lo, hi) then moved = true; touch(g) end
    end
  end
  turnCheck()
  if moved and redraw then redraw() end
end
DT._gambleSystem = function(msg) return onSystem(msg) end

-- The rolls a client saw, in one spelling every client can compare: sorted "phase:name:roll:max".
local function canonical(g)
  local parts = {}
  for _, r in ipairs(g.rolls) do parts[#parts + 1] = r.ph .. ":" .. r.name .. ":" .. r.roll .. ":" .. r.max end
  table.sort(parts)
  return table.concat(parts, ";")
end
DT._gambleCanonical = canonical

local function resultLine(g)
  if g.kind == "dr" then
    return string.format("Deathroll: %s beat %s. %d chips.", g.winner, g.loser, g.amount)
  end
  return string.format("High-low: %s pays %s %d chips.", g.loser, g.winner, g.amount)
end

-- Your own balance, from your own client only (D7).
local function applyMine(g)
  local me = lower(myName())
  local t = wallet()
  if not t or not me then return end
  local delta = 0
  if lower(g.winner) == me then delta = g.amount end                       -- guard: own balance only
  if lower(g.loser) == me then delta = -g.amount end
  if delta == 0 and not amIn(g) then return end
  t.b = math.max(0, math.min(MAXB, t.b + delta))
  t.w = math.max(-MAXB, math.min(MAXB, t.w + delta))
  if delta < 0 and -delta > t.bb then t.bb = -delta end
  t.played = true
  t.t = epoch() or t.t
  sendChips()
end

local function finish(g, state, line)
  g.state = state
  addLog(g, line)
  if amIn(g) or involved(g) then DT.out(line) end
  relisten()
  if redraw then redraw() end
end

local function dispute(g)
  if g.state == "disputed" or g.state == "settled" then return end
  finish(g, "disputed", DISPUTED)                                           -- guard: dispute moves nothing
end

local function settle(g)
  applyMine(g)
  finish(g, "settled", resultLine(g))
end

-- The host settles on its own reading and sends its rolls; everyone else waits for that RESULT.
settleLocal = function(g)
  g.mineDone = canonical(g)
  if g.mine then
    DT.send("RESULT", { g = tostring(g.n), r = g.mineDone })
    settle(g)
    return
  end
  if g.hostRolls then
    if g.hostRolls == g.mineDone then settle(g) else dispute(g) end
  end
end

-- ---------------------------------------------------------------- starting and joining

local function stakeOf(s)
  local n = tonumber(s)
  if not n or n ~= math.floor(n) or n < MIN_STAKE or n > MAX_STAKE then return nil end   -- guard: stake cap
  return n
end

local function canAfford(s)
  local t = wallet()
  if not t or t.b < s then                                                 -- guard: hold-enough check
    DT.out(POOR:format(t and t.b or 0))
    return false
  end
  return true
end

local function openFor(host, n, kind, s, opp)
  local hostName = myName()
  if not hostName then return nil end
  local g = newGame(host, n, kind, s, hostName, opp)
  g.mine = true
  relisten()
  return g
end

local function nextN()
  local st = store()
  st.seq = (st.seq % 999999999) + 1
  return st.seq
end

local function closeTable(g)
  if g.state ~= "open" or not g.mine then return end
  if #g.players < 2 then                                                   -- D5: fewer than two folds
    DT.send("FOLD", { g = tostring(g.n) })
    finish(g, "folded", FOLDED)
    return
  end
  DT.send("CALL", { g = tostring(g.n), p = table.concat(g.players, ",") })
  startRolling(g)
  relisten()
  if redraw then redraw() end
end

local function armClose(g)
  g.closeMark = (g.closeMark or 0) + 1
  local mark = g.closeMark
  DT.after(CLOSE_AFTER, function()
    if g.closeMark == mark then closeTable(g) end
  end)
end

local function startHighLow(s)
  local _, grouped = party()
  if not grouped then return DT.out(NO_PARTY) end
  if not canAfford(s) then return end
  local me = DT.myKey()
  local n = nextN()
  local g = openFor(me, n, "hl", s)
  if not g then return end
  DT.send("GAME", { g = tostring(n), k = "hl", s = tostring(s) })
  addLog(g, "You open a high-low table at " .. s .. ". Final call when they're in.")
  armClose(g)
  DT.gambleView(g.id)
end

local function partyMatch(text)
  local p = party()
  local want = lower(DT.trim(text) or "")
  if not want or want == "" then return nil end
  if p[want] then return p[want] end                                       -- guard: a named or targeted player must be in your party
  local hit
  for low, full in pairs(p) do
    if low:match("^(%S+)") == want then
      if hit then return nil, "many" end
      hit = full
    end
  end
  return hit
end

local function startDeathroll(args, re)
  local who, s = args:match("^(.-)%s+(%S+)$")
  local stake = stakeOf(s)
  if not who or who == "" then return DT.out(USAGE) end
  if not stake then return DT.out(STAKE_LINE) end
  local _, grouped = party()
  if not grouped then return DT.out(NO_PARTY) end
  local opp, why = partyMatch(who)
  if not opp then
    return DT.out(why == "many" and ("More than one " .. DT.safe(who, 24) .. " in your party. Use the full name.")
      or (DT.safe(who, NAME_MAX) .. " isn't in your party."))
  end
  if lower(opp) == lower(myName()) then return DT.out("You can't deathroll yourself. You'd lose.") end
  if not canAfford(stake) then return end
  local n = nextN()
  local g = openFor(DT.myKey(), n, "dr", stake, opp)
  if not g then return end
  DT.send("GAME", { g = tostring(n), k = "dr", s = tostring(stake), o = opp, re = re })
  addLog(g, re == "2" and ("You say double or nothing to " .. opp .. ": " .. stake .. ". Waiting for them.")
    or re == "1" and ("You offer " .. opp .. " a rematch for " .. stake .. ". Waiting for them.")
    or ("You challenge " .. opp .. " to a deathroll for " .. stake .. ". Waiting for them to join."))
  DT.gambleView(g.id)
end

local function joinable(g)
  if g.state ~= "open" or g.mine or g.joined then return false end
  if g.kind == "dr" then return lower(g.opp) == lower(myName()) end
  return true
end

local function join(id)
  local g = id and games[id]
  if not g then
    for i = #order, 1, -1 do
      local c = games[order[i]]
      if c and joinable(c) then g = c; break end
    end
  end
  if not g or not joinable(g) then return DT.out("No open game to join in your party.") end
  if not inParty(g.hostName) then return DT.out(g.hostName .. " isn't in your party any more.") end
  if not canAfford(g.s) then return end
  g.joined = true
  g.left = nil
  DT.send("JOIN", { h = g.host, g = tostring(g.n) })
  addLog(g, "You join. Waiting for the call.")
  relisten()
  if redraw then redraw() end
end

-- T2: decline a challenge to you.
local function challengedOpen(g)
  return g and g.kind == "dr" and g.state == "open" and not g.mine and not g.joined
    and lower(g.opp) == lower(myName())
end

local function lastWhere(test)
  for i = #order, 1, -1 do
    local g = games[order[i]]
    if g and test(g) then return g end
  end
end

local function decline(g)
  g = g or lastWhere(challengedOpen)
  if not challengedOpen(g) then return DT.out("No challenge to decline.") end
  DT.send("DECLINE", { h = g.host, g = tostring(g.n) })
  g.state = "declined"
  addLog(g, "You declined.")
  if redraw then redraw() end
end

-- T3: the host cancels before rolling; a joiner leaves before the call.
local function cancel(g)
  g = g or lastWhere(function(c) return c.mine and c.state == "open" end)
  if not g or not g.mine or g.state ~= "open" then                         -- guard: cancel only by the host, before rolling
    return DT.out("No game of yours to cancel.")
  end
  DT.send("FOLD", { g = tostring(g.n), why = "cancel" })
  finish(g, "folded", CANCELLED:format(g.hostName))
end

local function leave(g)
  g = g or lastWhere(function(c) return c.joined and c.state == "open" end)
  if not g or not g.joined or g.state ~= "open" then                       -- guard: leave only before the call
    return DT.out("No table to leave.")
  end
  DT.send("LEAVE", { h = g.host, g = tostring(g.n) })
  g.joined, g.left = false, true
  addLog(g, "You left the table.")
  relisten()
  if redraw then redraw() end
end

-- T4, T7: a rematch or double or nothing after a settled deathroll, from either player; always a new challenge.
local function settledDuel(g)
  return g and g.kind == "dr" and g.state == "settled" and amIn(g)
end

local function rematchProblem(g, mult)
  if not settledDuel(g) then return "No deathroll to replay." end
  local s = g.s * mult
  if s > MAX_STAKE then return OVER_CAP end                                -- guard: double respects the cap
  local t = wallet(true)
  if not t or t.b < s then return POOR:format(t and t.b or 0) end          -- guard: double respects what you hold
  return nil, s
end

local function rematch(g, mult)
  g = g or lastWhere(settledDuel)
  local why, s = rematchProblem(g, mult)
  if why then return DT.out(why) end
  local me = lower(myName())
  local other = lower(g.players[1]) == me and g.players[2] or g.players[1]
  startDeathroll(other .. " " .. s, tostring(mult))
end

local function again(g)
  g = g or lastWhere(function(c) return c.mine and c.kind == "hl" and c.state == "settled" end)
  if not g or not g.mine or g.kind ~= "hl" or g.state ~= "settled" then return DT.out("No table of yours to run again.") end
  startHighLow(g.s)
end

-- T5: the target's name, only at a press. The only read of the target in this file. Whether they're in
-- your party is checked where every named challenge is: startDeathroll's partyMatch.
local function readTarget()
  local isPlayer = clean(try(UnitIsPlayer, "target"))
  local name = DT.fullName(clean(try(GetUnitName, "target", true)))
  if not name or isPlayer ~= true then return nil, NO_TARGET end           -- guard: target only a player
  if lower(name) == lower(myName()) then return nil, NO_TARGET end
  return name
end

local function challengeTarget(stake)
  local name, why = readTarget()
  if not name then return DT.out(why) end
  startDeathroll(name .. " " .. stake)
end

-- ---------------------------------------------------------------- receiving

local function int(s, digits, signed)
  if type(s) ~= "string" or #s > digits then return nil end
  if not s:match(signed and "^%-?%d+$" or "^%d+$") then return nil end
  return tonumber(s)
end

local function nameOk(n)
  return type(n) == "string" and #n > 0 and #n <= NAME_MAX and not n:find("[,;:%c]") and DT.fullName(n) == n
end

local function fromGame(from, f)
  local n = int(f.g, 9)
  if not n then return nil end
  return games[gameId(from, n)], n
end

DT.on("GAME", function(from, f)
  if not DT.enabled("gamble") then return end                              -- guard: module switch (inbound)
  local n, s = int(f.g, 9), stakeOf(f.s)
  if not n or not s or (f.k ~= "dr" and f.k ~= "hl") then bad() return end -- guard: GAME validation
  if f.k == "dr" and not nameOk(f.o) then bad() return end
  if f.k == "hl" and f.o ~= nil then bad() return end
  if f.re ~= nil and (f.k ~= "dr" or (f.re ~= "1" and f.re ~= "2")) then bad() return end   -- guard: re validation
  local hostName = DT.nameOf(from)
  if not inParty(hostName) then return end                                 -- D2: not our party, not our game
  if games[gameId(from, n)] then return end
  if f.k == "dr" and lower(f.o) ~= lower(myName()) then
    local g = newGame(from, n, "dr", s, hostName, f.o)                     -- shown, not ours to join
    addLog(g, hostName .. " challenges " .. f.o .. " to a deathroll for " .. s .. ".")
  else
    local g = newGame(from, n, f.k, s, hostName, f.o)
    addLog(g, f.re == "1" and (REMATCH_LINE:format(hostName, s) .. " Accept or decline.")
      or f.re == "2" and (DOUBLE_LINE:format(hostName, s) .. " Accept or decline.")
      or f.k == "dr" and (hostName .. " challenges you to a deathroll for " .. s .. ". Accept or decline.")
      or (hostName .. " opens a high-low table at " .. s .. ". Join if you dare."))
    if f.k == "dr" then selected = g.id; DT.out(g.log[#g.log]) end
  end
  if redraw then redraw() end
end)

DT.on("JOIN", function(from, f)
  if not DT.enabled("gamble") then return end
  local n = int(f.g, 9)
  if not n or type(f.h) ~= "string" or #f.h > 80 then bad() return end   -- guard: JOIN validation
  if not DT.sameKey(f.h, DT.myKey()) then return end                       -- not our table
  local g = games[gameId(DT.myKey(), n)]
  if not g or not g.mine or g.state ~= "open" then return end
  local who = DT.nameOf(from)
  if not inParty(who) then return end                                      -- guard: party check (join)
  for _, p in ipairs(g.players) do
    if lower(p) == lower(who) then return end                              -- the same full name twice: refused
  end
  if g.kind == "dr" and lower(who) ~= lower(g.opp) then return end
  if #g.players >= MAX_PLAYERS then return end
  g.players[#g.players + 1] = who
  addLog(g, who .. " joins.")
  if g.kind == "dr" then
    closeTable(g)
  else
    armClose(g)
    touch(g)
  end
  if redraw then redraw() end
end)

DT.on("CALL", function(from, f)
  if not DT.enabled("gamble") then return end
  local g = fromGame(from, f)
  if type(f.p) ~= "string" or #f.p > MAX_PLAYERS * (NAME_MAX + 1) then bad() return end   -- guard: CALL validation
  local names, seen = {}, {}
  for p in f.p:gmatch("[^,]+") do
    if not nameOk(p) or seen[p:lower()] then bad() return end
    seen[p:lower()] = true
    names[#names + 1] = p
  end
  if #names < 2 or #names > MAX_PLAYERS or lower(names[1]) ~= lower(DT.nameOf(from)) then bad() return end
  if not g or g.state ~= "open" then return end
  g.players = names
  if not amIn(g) or g.left then
    g.joined = false
    g.state = "closed"
    addLog(g, "The table closed without you.")
  else
    startRolling(g)
  end
  relisten()
  if redraw then redraw() end
end)

DT.on("RESULT", function(from, f)
  if not DT.enabled("gamble") then return end
  local g = fromGame(from, f)
  if type(f.r) ~= "string" or #f.r > MAX_ROLLS * 64 then bad() return end -- guard: RESULT validation
  if not g or g.mine or not g.joined then return end
  if g.state == "settled" or g.state == "disputed" then return end
  g.hostRolls = f.r
  if g.mineDone then
    if g.mineDone == f.r then settle(g) else dispute(g) end
    return
  end
  DT.after(RESULT_WAIT, function()                                         -- your last roll may still be on its way
    if g.state ~= "rolling" then return end
    if g.mineDone and g.mineDone == g.hostRolls then settle(g) else dispute(g) end   -- guard: a missed roll disputes
  end)
end)

DT.on("FOLD", function(from, f)
  if not DT.enabled("gamble") then return end
  if f.why ~= nil and f.why ~= "cancel" then bad() return end
  local g = fromGame(from, f)
  if not g then return end
  if live(g) then finish(g, "folded", f.why == "cancel" and CANCELLED:format(g.hostName) or FOLDED) end
end)

local function hostGame(f)
  local n = int(f.g, 9)
  if not n or type(f.h) ~= "string" or #f.h > 80 then return nil, true end
  if not DT.sameKey(f.h, DT.myKey()) then return nil end
  return games[gameId(DT.myKey(), n)]
end

DT.on("DECLINE", function(from, f)
  if not DT.enabled("gamble") then return end
  local g, isBad = hostGame(f)
  if isBad then bad() return end                                           -- guard: DECLINE validation
  if not g or not g.mine or g.kind ~= "dr" or g.state ~= "open" then return end
  local who = DT.nameOf(from)
  if lower(who) ~= lower(g.opp) then return end                            -- guard: decline only from the challenged
  finish(g, "folded", DECLINED:format(who))
end)

DT.on("LEAVE", function(from, f)
  if not DT.enabled("gamble") then return end
  local g, isBad = hostGame(f)
  if isBad then bad() return end                                           -- guard: LEAVE validation
  if not g or not g.mine or g.state ~= "open" then return end              -- guard: leave only before the call
  local who = DT.nameOf(from)
  for i = 2, #g.players do
    if lower(g.players[i]) == lower(who) then
      table.remove(g.players, i)
      addLog(g, LEFT:format(who))
      DT.out(LEFT:format(who))
      if g.kind == "hl" then armClose(g) end
      touch(g)
      if redraw then redraw() end
      return
    end
  end
end)

local function validChips(f)
  local b, w, bb, we = int(f.b, 8), int(f.w, 9, true), int(f.bb, 8), int(f.we, 12)
  if not b or not w or not bb or not we then return nil end
  if b > MAXB or bb > MAXB or math.abs(w) > MAXB then return nil end
  return { b = b, w = w, bb = bb, we = we }
end

DT.on("CHIPS", function(from, f)
  if not DT.enabled("gamble") then return end
  if f.off ~= nil then
    if f.off == "1" and f.b == nil and f.w == nil and f.bb == nil and f.we == nil then
      board()[from] = nil
    else
      bad()
    end
    if redrawBoard then redrawBoard() end
    return
  end
  local v = validChips(f)
  if not v then bad() return end                                           -- guard: CHIPS validation
  local b = board()
  if b[from] == nil then makeRoom(b, BOARD_CAP) end                        -- guard: board cap
  v.t = epoch()
  b[from] = v
  if redrawBoard then redrawBoard() end
end)

-- ---------------------------------------------------------------- the board (D8)

local function prune()
  local now = epoch()
  if not now then return end
  local b = board()
  for key, e in pairs(b) do
    if type(e) ~= "table" or type(e.t) ~= "number" or now - e.t > MAX_AGE then b[key] = nil end
  end
end

local function weekOf(e, now)
  if type(e.we) == "number" and e.we > 0 and now and now >= e.we then return 0, 0 end
  return e.w, e.bb
end

function DT.gambleRows()
  prune()
  local b = board()
  if boardOn() then
    local t, me = wallet(true)
    if t and t.played then b[me] = mineEntry(t) end
  end
  local keys = {}
  for key in pairs(b) do keys[#keys + 1] = key end
  local name = DT.namer(keys)
  local roster = DT.rosterClasses()
  local now = epoch()
  local rows, big, bigName = {}, 0, nil
  for key, e in pairs(b) do
    if type(e) == "table" and type(e.b) == "number" and type(e.w) == "number" then
      local wk, bb = weekOf(e, now)
      local cr, cg, cb = DT.classColour(key, roster)
      local nm = name(key)
      rows[#rows + 1] = { key = key, w = wk, b = e.b, name = nm, nameRGB = cr and { cr, cg, cb } or nil,
        week = (wk > 0 and "+" or "") .. wk .. " this week", bal = e.b .. " chips", search = nm .. " " .. key }
      if (bb or 0) > big or ((bb or 0) == big and big > 0 and bigName and nm:lower() < bigName:lower()) then
        big, bigName = bb, nm
      end
    end
  end
  table.sort(rows, function(a, c)
    if a.w ~= c.w then return a.w > c.w end
    if a.b ~= c.b then return a.b > c.b end
    if a.name:lower() ~= c.name:lower() then return a.name:lower() < c.name:lower() end
    return a.key < c.key
  end)
  return rows, big > 0 and bigName or nil, big
end

function DT.gambleFooter()
  local _, who, n = DT.gambleRows()
  local parts = {}
  if who then parts[#parts + 1] = BEATDOWN:format(who, n) end
  wallet(true)
  if resetUnread then parts[#parts + 1] = NO_RESET end
  parts[#parts + 1] = CLOSING
  return table.concat(parts, " ")
end

local bvp, blist, bmodel

local function fillBoard()
  bmodel:set((DT.gambleRows()))
  bvp:setFooter(DT.gambleFooter())
  blist:refresh()
end

redrawBoard = function() if bmodel and bvp and bvp:IsShown() then fillBoard() end end

local function buildBoard()
  if bvp then return end
  bmodel = DT.listModel()
  bvp = DT.viewport({ id = "gambleboard", title = BOARD_TITLE, search = true, width = 400, height = 360, footer = CLOSING,
    onSearch = function(text) bmodel:filter(text); blist.offset = 0; blist:refresh() end })
  blist = DT.list(bvp.body, bmodel, { count = 12, tipCovers = { "name" },
    empty = function(m) if #m.rows == 0 then return BOARD_EMPTY end end,
    tip = function(row, tt) tt:AddLine(DT.safe(DT.nameOf(row.key), 48)) end,
    columns = { { key = "name", flex = true, rgb = "nameRGB" }, { key = "week", fixed = true },
      { key = "bal", fixed = true, colour = "muted" } } })
end

function DT.gambleBoardView()
  if not DT.isMember() then return end
  buildBoard()
  fillBoard()
  bvp:Show()
end

-- ---------------------------------------------------------------- the table window

local vp, list, model, status, buttons

local function gameRow(g)
  local what = g.kind == "dr" and ("Deathroll: " .. g.hostName .. " v " .. (g.opp or "?")) or ("High-low: " .. g.hostName)
  local state = ({ open = "open", rolling = "rolling", settled = "settled", disputed = "disputed", folded = "folded",
    closed = "closed" })[g.state] or g.state
  return { id = g.id, name = what, stake = g.s .. " chips", state = state, search = what }
end

function DT.gambleGameRows()
  local rows = {}
  for i = #order, 1, -1 do
    local g = games[order[i]]
    if g then rows[#rows + 1] = gameRow(g) end
  end
  return rows
end

-- The game the window shows: the one clicked while it's still live; else the newest you're in or can join;
-- else the one clicked; else the newest.
local function current()
  local g = selected and games[selected]
  if g and live(g) then return g end
  for i = #order, 1, -1 do
    local c = games[order[i]]
    if c and live(c) and (c.mine or c.joined or joinable(c)) then return c end
  end
  if g then return g end
  for i = #order, 1, -1 do
    local c = games[order[i]]
    if c and (c.mine or c.joined or amIn(c)) then return c end
  end
  for i = #order, 1, -1 do if games[order[i]] then return games[order[i]] end end
end

local function rollRange(g) return myRange(g) end
DT._gambleRange = function() return rollRange(current()) end

local function doRoll()
  local hi = rollRange(current())
  if not hi then return DT.out("Not your roll.") end
  try(RandomRoll, 1, hi)
end

local function statusText(g)
  local lines = {}
  local t = wallet(true)
  lines[#lines + 1] = "You hold " .. (t and t.b or START) .. " chips."
  if not g then return lines[1] end                                        -- the list already says it's empty (walk, 24 Nov)
  for _, l in ipairs(g.log) do lines[#lines + 1] = l end
  if g.state == "rolling" then
    if g.kind == "dr" then lines[#lines + 1] = g.players[g.turn] .. " to roll, 1-" .. g.cur .. "."
    else
      local waiting = {}
      for _, n in ipairs(g.players) do
        local w = lower(n)
        if g.want[w] and not g.seen[w] then waiting[#waiting + 1] = n end
      end
      if #waiting > 0 then lines[#lines + 1] = "Waiting on " .. table.concat(waiting, ", ") .. "." end
    end
  end
  return table.concat(lines, "\n")
end

local STATUS_TOP, BUTTON_ROOM = 110, 28
local BUTTON_W, BUTTON_GAP = 92, 6

-- The status block keeps to the room between the list and the buttons: the oldest log lines go
-- first (the balance line and the whose-turn line stay).
local function setStatus(text)
  local lines = {}
  for l in (text .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
  local room = (vp.body.dtHeight or 200) - STATUS_TOP - BUTTON_ROOM
  local width = vp.body.dtWidth
  while true do
    DT.setText(status, table.concat(lines, "\n"))
    if DT.textHeight(status, width) <= room or #lines <= 2 then break end
    table.remove(lines, 2)                                                 -- guard: status fits its room
  end
end

-- ---------------------------------------------------------------- the New game panel (T1)

local panel, pmodel, plist, pstake, phead
local stake = 50                                -- the last stake used, this session only

local function runningNow()
  local out = {}
  for _, r in ipairs(DT.whoRows and DT.whoRows() or {}) do
    if r.when == "this session" then
      local n = DT.nameOf(r.key)
      if n then out[n:lower()] = true end
    end
  end
  return out
end

function DT.gamblePartyRows()
  local p = party()
  local me = lower(myName())
  local runs = runningNow()
  local rows = {}
  for low, full in pairs(p) do
    if low ~= me then
      local on = runs[low] == true
      rows[#rows + 1] = { name = full, runs = on, state = on and "Dead Tired" or "no addon", search = full }
    end
  end
  table.sort(rows, function(x, y)
    if x.runs ~= y.runs then return x.runs end
    return x.name:lower() < y.name:lower()
  end)
  return rows
end

local function panelStake()
  local typed = pstake and DT.trim(pstake:GetText() or "") or ""
  local s = stakeOf(typed ~= "" and typed or tostring(stake))
  if not s then DT.out(STAKE_LINE) return nil end
  stake = s
  return s
end

local function showPanel(on)
  if not panel then return end
  panel:SetShown(on)
  if on then
    pmodel:set(DT.gamblePartyRows())
    plist:refresh()
    pstake:SetText(tostring(stake))
  end
end

local function fromPanel(fn)
  return function()
    local s = panelStake()
    if not s then return end
    showPanel(false)
    fn(s)
  end
end

-- ---------------------------------------------------------------- the action buttons

local function layout(shown)
  local x = 0
  for _, b in ipairs(shown) do
    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT", vp.body, "BOTTOMLEFT", x, 0)
    b:Show()
    x = x + BUTTON_W + BUTTON_GAP
  end
end

local function setOn(b, on, why)
  b.dtDisabled = not on
  b.dtWhy = why
  if on then try(b.Enable, b) else try(b.Disable, b) end
end

local function fill()
  model:set(DT.gambleGameRows())
  list:refresh()
  local g = current()
  setStatus(statusText(g))
  if not buttons then return end
  for _, b in pairs(buttons) do b:Hide() end
  local shown = {}
  local function add(b) shown[#shown + 1] = b end
  if g and joinable(g) then
    buttons.join:SetText(g.kind == "dr" and "Accept" or "Join")
    add(buttons.join)
    if challengedOpen(g) then add(buttons.decline) end
  end
  if rollRange(g) ~= nil then add(buttons.roll) end
  if g and g.mine and g.kind == "hl" and g.state == "open" then add(buttons.call) end
  if g and g.mine and g.state == "open" then add(buttons.cancel) end
  if g and g.joined and g.state == "open" then add(buttons.leave) end
  if settledDuel(g) then
    add(buttons.rematch)
    local why = rematchProblem(g, 2)
    setOn(buttons.double, why == nil, why)
    add(buttons.double)
  end
  if g and g.mine and g.kind == "hl" and g.state == "settled" then add(buttons.again) end
  add(buttons.new)
  layout(shown)
  buttons.glow:SetShown(buttons.roll:IsShown())                           -- T6: the glow follows your turn
end

redraw = function() if model and vp and vp:IsShown() then fill() end end

local function button(parent, label, fn, tip)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(BUTTON_W, 22)
  b:SetText(label)
  b:SetScript("OnClick", function()
    if b.dtDisabled then if b.dtWhy then DT.out(b.dtWhy) end return end
    local ok, err = pcall(fn)
    if not ok then DT.fail("gamble", "click " .. label, err) end
  end)
  b:SetScript("OnEnter", function()
    local tt = DT.tooltip()
    tt:SetOwner(b, "ANCHOR_TOP")
    tt:AddLine(label)
    if tip then tt:AddLine(tip, 0.8, 0.8, 0.8, true) end
    if b.dtWhy then tt:AddLine(b.dtWhy, 1, 0.4, 0.4, true) end
    tt:Show()
  end)
  b:SetScript("OnLeave", function() DT.tooltip():Hide() end)
  return b
end

local function buildPanel()
  panel = CreateFrame("Frame", nil, vp.body)
  panel:SetAllPoints(vp.body)
  panel.dtWidth, panel.dtHeight = vp.body.dtWidth, vp.body.dtHeight
  try(panel.SetFrameLevel, panel, (clean(try(vp.body.GetFrameLevel, vp.body)) or 1) + 10)
  local bg = panel:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(panel)
  bg:SetColorTexture(0.04, 0.06, 0.04, 0.97)
  phead = DT.text(panel, "line", { width = panel.dtWidth, window = "gamble" })
  phead:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  DT.setText(phead, PANEL_HEAD)
  local stakes = {}
  for i, v in ipairs({ 10, 50, 100, 250, 500 }) do
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetSize(48, 22)
    b:SetText(tostring(v))
    b:SetPoint("TOPLEFT", panel, "TOPLEFT", (i - 1) * 52, -22)
    b:SetScript("OnClick", function() stake = v; pstake:SetText(tostring(v)) end)
    stakes[i] = b
  end
  pstake = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  pstake:SetSize(60, 22)
  pstake:SetPoint("TOPLEFT", panel, "TOPLEFT", 5 * 52 + 8, -22)
  try(pstake.SetAutoFocus, pstake, false)
  try(pstake.SetNumeric, pstake, true)
  try(pstake.SetMaxLetters, pstake, 3)
  pmodel = DT.listModel()
  local holder = CreateFrame("Frame", nil, panel)                          -- the member list sits below the stakes
  holder:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -52)
  holder:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, BUTTON_ROOM)
  holder.dtWidth, holder.dtHeight = panel.dtWidth, (panel.dtHeight or 200) - 52 - BUTTON_ROOM
  plist = DT.list(holder, pmodel, { count = 5, tipCovers = { "name" },
    empty = function(m) if #m.rows == 0 then return "Nobody else in your party." end end,
    onClick = function(row)
      if not row.runs then return DT.out(DT.safe(row.name, NAME_MAX) .. " isn't running Dead Tired.") end
      local s = panelStake()
      if not s then return end
      showPanel(false)
      startDeathroll(row.name .. " " .. s)
    end,
    tip = function(row, tt)
      tt:AddLine(DT.safe(row.name, 48))
      tt:AddLine(row.runs and "Click for a deathroll at the stake above." or NOT_RUNNING, 0.7, 0.7, 0.7)
    end,
    columns = { { key = "name", flex = true }, { key = "state", fixed = true, colour = "muted" } } })
  panel.buttons = {
    target = button(panel, "Challenge target", fromPanel(function(s) challengeTarget(s) end),
      "A deathroll with the party member you have targeted."),
    table = button(panel, "Open high-low", fromPanel(function(s) startHighLow(s) end),
      "A high-low table for your party at the stake above."),
    back = button(panel, "Back", function() showPanel(false) end),
  }
  panel.buttons.target:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
  panel.buttons.table:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", BUTTON_W + BUTTON_GAP, 0)
  panel.buttons.back:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 2 * (BUTTON_W + BUTTON_GAP), 0)
  panel.stakes = stakes
  panel:Hide()
end

local function build()
  if vp then return end
  model = DT.listModel()
  vp = DT.viewport({ id = "gamble", title = TITLE, width = 420, height = 380, footer = TABLE_FOOTER })
  list = DT.list(vp.body, model, { count = 4, tipCovers = { "name" },
    empty = function(m) if #m.rows == 0 then return EMPTY end end,
    onClick = function(row) selected = row.id; fill() end,
    tip = function(row, tt) tt:AddLine(DT.safe(row.name, 64)); tt:AddLine("Click to show this game.", 0.6, 0.6, 0.6) end,
    columns = { { key = "name", flex = true }, { key = "stake", fixed = true, colour = "muted" },
      { key = "state", fixed = true } } })
  status = DT.text(vp.body, "block", { width = vp.body.dtWidth, window = "gamble" })
  status:SetPoint("TOPLEFT", vp.body, "TOPLEFT", 0, -STATUS_TOP)
  local function cur() return current() end
  buttons = {
    join = button(vp.body, "Join", function() local g = cur(); join(g and g.id) end),
    decline = button(vp.body, "Decline", function() decline(cur()) end),
    roll = button(vp.body, "Roll", doRoll),
    call = button(vp.body, "Final call", function() local g = cur(); if g then closeTable(g) end end),
    cancel = button(vp.body, "Cancel", function() cancel(cur()) end),
    leave = button(vp.body, "Leave", function() leave(cur()) end),
    rematch = button(vp.body, "Rematch", function() rematch(cur(), 1) end, "The same stake again. They must accept."),
    double = button(vp.body, "Double or nothing", function() rematch(cur(), 2) end, "Twice the stake. They must accept."),
    again = button(vp.body, "Same again", function() again(cur()) end, "A new table at the same stake."),
    new = button(vp.body, "New game", function() showPanel(true) end),
  }
  local glow = buttons.roll:CreateTexture(nil, "OVERLAY")
  glow:SetAllPoints(buttons.roll)
  glow:SetColorTexture(1, 0.82, 0.2, 0.35)
  try(glow.SetBlendMode, glow, "ADD")
  glow:Hide()
  buttons.roll:SetScript("OnUpdate", function()
    if glow:IsShown() then
      local t = clean(try(GetTime)) or 0
      try(glow.SetAlpha, glow, 0.25 + 0.25 * math.abs(math.sin(t * 3)))
    end
  end)
  buttons.glow = glow
  buildPanel()
end

function DT.gambleView(id)
  if not DT.isMember() then return end
  build()
  if id then selected = id end
  fill()
  vp:Show()
end

-- ---------------------------------------------------------------- the verb

local function verb(args)
  if not DT.enabled("gamble") then return DT.out(OFF) end                  -- guard: off verbs do nothing else (gamble)
  local a = DT.trim(args) or ""
  local lw = a:lower()
  if lw == "" then return DT.gambleView() end
  if lw == "join" then return join() end
  if lw == "roll" then return doRoll() end
  if lw == "decline" then return decline() end
  if lw == "cancel" then return cancel() end
  if lw == "leave" then return leave() end
  if lw == "rematch" then return rematch(nil, 1) end
  if lw == "double" then return rematch(nil, 2) end
  if lw == "again" then return again() end
  local snd = lw:match("^sound%s+(%a+)$")
  if snd == "on" or snd == "off" then
    DT.set("gamble", "sound", snd == "on")
    return DT.out(snd == "on" and "A bell when it's your roll." or "No bell. You'll have to pay attention.")
  end
  if lw == "call" then
    local g = current()
    if g and g.mine and g.kind == "hl" and g.state == "open" then return closeTable(g) end
    return DT.out("No table of yours to call.")
  end
  if lw == "board" then return DT.gambleBoardView() end
  local sw = lw:match("^board%s+(%a+)$")
  if sw == "on" or sw == "off" then
    DT.set("gamble", "board", sw == "on")
    return DT.out(sw == "on" and "You're on the board." or "You're off the board. Your chips are your own business.")
  end
  local rest = a:match("^[Dd][Ee][Aa][Tt][Hh][Rr][Oo][Ll][Ll]%s+(.+)$")
  if rest and rest:match("^%S+$") then                                     -- T5: a stake and no name: your target
    local s = stakeOf(rest)
    if not s then return DT.out(STAKE_LINE) end
    return challengeTarget(s)
  end
  if rest then return startDeathroll(rest) end
  local s = lw:match("^highlow%s+(%S+)$")
  if s then
    local stake = stakeOf(s)
    if not stake then return DT.out(STAKE_LINE) end
    return startHighLow(stake)
  end
  return DT.out(USAGE)
end

local function debugVerb(args)
  local w = (DT.trim(args) or ""):lower()
  if w == "fast" then
    timeout = 10                                                           -- guard: memory only, never saved
    return DT.out("A quiet table folds after 10 s this session.")
  elseif w == "slow" then
    timeout = TIMEOUT
    return DT.out("A quiet table folds after 2 minutes.")
  end
  return DT.out("/dt debug gamble fast|slow")
end

DT.listen("setting", function(id, key, v)
  if id ~= "gamble" or key ~= "board" then return end
  local ok, err = pcall(function()
    if v == false then withdraw() elseif v == true then sendChips() end
  end)
  if not ok then DT.fail("gamble", "board", err) end
end)

local sentLogin = false
DT.listen("greeted", function()
  if sentLogin then return end
  sentLogin = true
  DT.after(LOGIN_WAIT, function()
    local ok, err = pcall(function() wallet(); sendChips() end)
    if not ok then DT.fail("gamble", "login", err) end
  end)
end)

DT.keySource(function() return board() end)

DT.module({
  id = "gamble",
  title = TITLE,
  optional = true,
  switchDesc = "Guild gambling with play chips: deathroll and high-low in your party, /dt gamble. Off, it hears no games and reads no rolls.",
  settings = {
    { key = "board", type = "bool", default = true, label = "On the board", verb = "gamble board on|off",
      desc = "Puts your chips and this week's winnings on the guild's board once you've played. Off takes you off everyone's board." },
    { key = "sound", type = "bool", default = false, label = "Your-turn bell", verb = "gamble sound on|off",
      desc = "A short sound when it becomes your roll. The Roll button glows either way." },
  },
  verbs = {
    { verb = "gamble", usage = "gamble [join|decline|leave|cancel|deathroll [<name>] <stake>|highlow <stake>|call|roll|rematch|double|again|board|sound]", fn = verb },
    { verb = "debug gamble", usage = "debug gamble fast|slow", fn = debugVerb },
  },
  ldb = { type = "launcher", text = TITLE, label = TITLE, icon = "Interface\\Icons\\INV_Misc_Coin_01", offByDefault = true,
    OnClick = function(_, button)
      if button == "RightButton" then DT.gambleBoardView() else DT.gambleView() end
    end,
    OnTooltipShow = function(tt)
      local t = wallet(true)
      tt:AddLine(TITLE)
      tt:AddLine("You hold " .. (t and t.b or START) .. " chips.", 1, 1, 1)
      tt:AddLine("Click: the table. Right-click: the ledger.", 0.7, 0.7, 0.7)
    end },
  init = function() store(); prune() end,
  onDisable = function() relisten() end,
  fit = function()
    build()
    local g = { id = "fit", host = "x", n = 0, kind = "hl", s = 500, hostName = "Bartholomew Longname-Grimshaw",
      players = { "Bartholomew Longname-Grimshaw" }, state = "rolling", log = {}, rolls = {}, want = {}, seen = {} }
    for i = 1, LOG_MAX do addLog(g, "Bartholomew Longname-Grimshaw rolls 500 (1-500), and it is very long " .. i .. ".") end
    model:set({ gameRow(g) }); list:refresh()
    setStatus(statusText(g))
    pmodel:set({ { name = "Bartholomew Longname-Grimshaw", runs = false, state = "no addon" } }); plist:refresh()
    buildBoard(); fillBoard()
  end,
})

-- For the offline tests only.
DT._gamble = { games = function() return games end, order = function() return order end, store = store,
  vp = function() return vp end, list = function() return list end, status = function() return status end,
  buttons = function() return buttons end, bvp = function() return bvp end, blist = function() return blist end,
  validChips = validChips, START = START, EMPTY = EMPTY, BOARD_EMPTY = BOARD_EMPTY, CLOSING = CLOSING,
  BEATDOWN = BEATDOWN, NO_RESET = NO_RESET, OUT_OF_TURN = OUT_OF_TURN, WRONG_RANGE = WRONG_RANGE,
  DISPUTED = DISPUTED, FOLDED = FOLDED, TIMED_OUT = TIMED_OUT, OFF = OFF, POOR = POOR, STAKE_LINE = STAKE_LINE,
  NO_PARTY = NO_PARTY, TIMEOUT = TIMEOUT, CLOSE_AFTER = CLOSE_AFTER, BOARD_CAP = BOARD_CAP, WALLET_CAP = WALLET_CAP,
  timeout = function() return timeout end, select = function(id) selected = id end,
  panel = function() return panel end, plist = function() return plist end, pstake = function() return pstake end,
  OVER_CAP = OVER_CAP, NO_TARGET = NO_TARGET }
