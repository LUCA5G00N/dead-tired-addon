-- Offline checks for Gamble.lua (dt_gamble, 0.6.0; rulings D1-D10, PR #38).
--   lua5.1 DeadTired/tests/test_gamble.lua
-- Stubs per client: time and date on the world clock (plus c.skew), the weekly reset (c.opts.noReset leaves it
-- out), RANDOM_ROLL_RESULT (the probe's string, 23 Nov, unless c.opts.rollFormat), a party shared by the
-- world (w.party: the clients in it, in order), GetUnitName for party1..4 / raid1..n, and RandomRoll: it takes
-- the next scripted number from c.rolls (else min) and fires the probe-shaped line on CHAT_MSG_SYSTEM to every
-- client in the party, as the game shows a /roll to its party (probe: a party member's roll is seen).
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local R2 = "CAMWOW EU4 Realm 2 PvP"
local DAY, WEEK = 86400, 7 * 86400
local T0 = 1794000000
local RESET = T0 + 3 * DAY
local PROBE = "%s rolls %d (%d-%d)"

local function stub(c)
  c.skew = c.skew or 0
  local env = c.env
  local function now() return T0 + math.floor(c.world.t - 1000) + c.skew end
  c.now = now
  rawset(env, "time", function() return now() end)
  rawset(env, "date", function(fmt, t) return os.date(fmt, t or now()) end)
  if not c.opts.noReset then
    rawset(env, "C_DateAndTime", { GetSecondsUntilWeeklyReset = function()
      local r = RESET
      while r <= now() do r = r + WEEK end
      return r - now()
    end })
  end
  rawset(env, "RANDOM_ROLL_RESULT", c.opts.rollFormat or PROBE)
  local w = c.world
  local function members()
    for _, p in ipairs(w.party or {}) do if p == c then return w.party end end
    return nil
  end
  rawset(env, "GetNumGroupMembers", function() local m = members(); return m and #m or 0 end)
  rawset(env, "IsInRaid", function() return w.raid == true end)
  local base = rawget(env, "GetUnitName")
  rawset(env, "GetUnitName", function(u, showRealm)
    local m = members()
    local i = type(u) == "string" and tonumber(u:match("^party(%d)$") or u:match("^raid(%d+)$"))
    if m and i then
      local others = {}
      if w.raid then others = m else for _, p in ipairs(m) do if p ~= c then others[#others + 1] = p end end end
      local p = others[i]
      return p and (showRealm and p.full or p.name) or nil
    end
    return base(u, showRealm)
  end)
  c.rolls = {}
  rawset(env, "RandomRoll", function(lo, hi)
    local v = table.remove(c.rolls, 1) or lo
    c.rolled = (c.rolled or 0) + 1
    local line = string.format(PROBE, c.full, v, lo, hi)
    for _, p in ipairs(members() or { c }) do p:fire("CHAT_MSG_SYSTEM", line) end
  end)
end

local function mk(w, o)
  o.realm = o.realm or R2
  if o.guild == nil then o.guild = G end
  if o.guild == false then o.guild = nil end
  local setup = o.setup
  o.setup = function(c) stub(c); if setup then setup(c) end end
  local c = w:client(o)
  c:login()
  return c
end

-- A typed /roll: the line every party member sees.
local function typed(c, v, lo, hi)
  local line = string.format(PROBE, c.full, v, lo, hi)
  for _, p in ipairs(c.world.party or { c }) do p:fire("CHAT_MSG_SYSTEM", line) end
end

local function sentKind(c, kind)
  local out = {}
  for _, m in ipairs(c.sent) do
    local ok, p = c.DT._comms.decode(m.text)
    if ok == "ok" and p.k == kind then out[#out + 1] = p.d end
  end
  return out
end
local function inject(c, kind, from, d)
  c.DT._comms.inbound("DEADTIRED", c.DT._comms.encode(kind, d, from), "GUILD", from:match("%-(.+)$"))
end
local function bal(c) local t = c.DT.gambleWallet(); return t and t.b end
local function game(c) local o = c.DT._gamble.order(); return c.DT._gamble.games()[o[#o]] end
local function logHas(g, s) for _, l in ipairs(g and g.log or {}) do if l:find(s, 1, true) then return true end end return false end
local function bad(c) return c.DT._gamble.store().bad end

local function table3()
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  local b = mk(w, { name = "Sap", full = "Sap Hapi" })
  local c = mk(w, { name = "Liliac", full = "Liliac Thorne" })
  w.party = { a, b, c }
  w:advance(30)
  return w, a, b, c
end

-- ---------------------------------------------------------------- the roll reader
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  local D = a.DT
  local n, r, lo, hi = D.readRoll("Stromham Hamson rolls 32 (1-100)")
  check("reader: the probe's line (Stromham Hamson rolls 32 (1-100))", n == "Stromham Hamson" and r == 32 and lo == 1 and hi == 100)
  n, r, lo, hi = D.readRoll("Sap Hapi rolls 60 (1-100)")
  check("reader: a party member's line (Sap Hapi rolls 60 (1-100))", n == "Sap Hapi" and r == 60 and hi == 100)
  n, r, lo, hi = D.readRoll("Stromham Hamson rolls 57 (1-57)")
  check("reader: RandomRoll(1,57)'s line", r == 57 and hi == 57)
  n = D.readRoll("Echo Nightclaw-OtherRealm rolls 5 (1-10)")
  check("reader: a realm suffix is dropped from the name", n == "Echo Nightclaw")
  check("reader: junk is not a roll", D.readRoll("Stromham Hamson is now Tank.") == nil and D.readRoll("") == nil
    and D.readRoll(nil) == nil and D.readRoll("rolls rolls (x-y)") == nil)
  local secret = "Sap Hapi rolls 99 (1-100)"
  a.secrets[secret] = true
  check("reader: a secret line is skipped, never parsed", D.readRoll(secret) == nil)
  local p = D.rollPattern("%3$d-%4$d: %1$s würfelt %2$d")
  local caps = { ("1-100: Sap Hapi würfelt 42"):match(p.pat) }
  check("reader: positional fields in another order (pattern)", #caps == 4 and p.order[1] == 3 and p.order[3] == 1)
  check("reader: a format without four fields gives no pattern", D.rollPattern("%s rolls") == nil and D.rollPattern(nil) == nil)
  local w2 = H.world()
  local de = mk(w2, { name = "Stromham", full = "Stromham Hamson", rollFormat = "%3$d-%4$d: %1$s würfelt %2$d" })
  n, r, lo, hi = de.DT.readRoll("1-100: Sap Hapi würfelt 42")
  check("reader: the client's own format, fields reordered, reads right", n == "Sap Hapi" and r == 42 and lo == 1 and hi == 100)
  check("reader: and refuses the English line then", de.DT.readRoll("Sap Hapi rolls 42 (1-100)") == nil)
end

-- ---------------------------------------------------------------- D1, D3: the wallet
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  local D = a.DT
  check("D1: no wallet until it's needed (looking makes none)", D.gambleWallet(true) == nil)
  check("D1: a wallet starts at 1,000", bal(a) == 1000)
  local t = D.gambleWallet()
  t.b = 400; t.w = -600; t.bb = 300
  a.skew = 4 * DAY                                                          -- past this week's reset
  t = D.gambleWallet()
  check("D3: 400 at the reset is topped up to 1,000", t.b == 1000)
  check("D3: the week's net and biggest loss start again", t.w == 0 and t.bb == 0)
  check("D3: the new week ends at the next reset", t.we == RESET + WEEK)
  t.b = 1500
  a.skew = 4 * DAY + WEEK
  check("D3: 1,500 at the reset stays 1,500", D.gambleWallet().b == 1500)

  local w2 = H.world()
  local n = mk(w2, { name = "Stromham", full = "Stromham Hamson", noReset = true })
  local nt = n.DT.gambleWallet()
  check("D3: unreadable reset: we is 0", nt.we == 0)
  nt.b = 400
  n.skew = 30 * DAY
  check("D3: unreadable reset: nobody is topped up", n.DT.gambleWallet().b == 400)
  check("D3: unreadable reset: the board footer says so", n.DT.gambleFooter():find(n.DT._gamble.NO_RESET, 1, true) ~= nil)
  local w3 = H.world()
  local r = mk(w3, { name = "Stromham", full = "Stromham Hamson" })
  local rt = r.DT.gambleWallet()
  rt.b = 400
  rt.we = T0 - DAY                                                          -- a stored week that has ended...
  rawset(r.env, "C_DateAndTime", nil)                                       -- ...and a reset that can't be read now
  check("D3: a week ending while the reset can't be read: no top-up", r.DT.gambleWallet().b == 400)
end

-- ---------------------------------------------------------------- the wallet cap
do
  local w = H.world()
  local wallets = {}
  for i = 1, 50 do wallets["CAMWOWEU4Realm2PvP-Alt " .. i] = { b = 1000, w = 0, bb = 0, we = 0, t = T0 - i } end
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson", db = { schema = 4, gamble = { wallet = wallets } } })
  local t, me = a.DT.gambleWallet()
  local n = 0 for _ in pairs(a:db().gamble.wallet) do n = n + 1 end
  check("wallet cap: a 51st character keeps the store at 50", n == 50 and a:db().gamble.wallet[me] == t)
  check("wallet cap: the one seen longest ago went", a:db().gamble.wallet["CAMWOWEU4Realm2PvP-Alt 50"] == nil)
end

-- ---------------------------------------------------------------- D4: deathroll
do
  local w, a, b = table3()
  a:slash("gamble deathroll Sap 100")
  w:advance(1)
  local ga, gb = game(a), game(b)
  check("D4: the challenge reaches the opponent", gb and gb.kind == "dr" and gb.s == 100 and gb.opp == "Sap Hapi")
  check("D4: a challenged player isn't listening until they join", not b.DT._gambleListening())
  check("D4: the challenger is listening", a.DT._gambleListening())
  b:slash("gamble join")
  w:advance(1)
  check("D4: join starts the game for both", ga.state == "rolling" and gb.state == "rolling")
  check("D4: the challenger rolls first, 1-100", a.DT._gambleRange() == 100 and b.DT._gambleRange() == nil)
  a.rolls = { 60 }; a:slash("gamble roll")
  check("D4: Roll calls RandomRoll", a.rolled == 1)
  check("D4: then the opponent, 1-60", b.DT._gambleRange() == 60 and a.DT._gambleRange() == nil)
  b.rolls = { 20 }; b:slash("gamble roll")
  a.rolls = { 7 }; a:slash("gamble roll")
  b.rolls = { 1 }; b:slash("gamble roll")
  w:advance(1)
  check("D4: a 1 ends it: settled on both", ga.state == "settled" and gb.state == "settled")
  check("D4: the loser pays the stake (900)", bal(b) == 900)
  check("D4: the winner takes it (1,100)", bal(a) == 1100)
  check("D4: the same rolls on both clients", a.DT._gambleCanonical(ga) == b.DT._gambleCanonical(gb))
  check("D9: one line in your own chat", a:said("Deathroll: Stromham Hamson beat Sap Hapi. 100 chips.") ~= nil)
  check("D4: the listener is gone once it's settled", not a.DT._gambleListening() and not b.DT._gambleListening())
  local chips = sentKind(b, "CHIPS")
  check("D8: CHIPS after the game, from each player (balance, net, biggest loss)", #chips >= 1
    and chips[#chips].b == "900" and chips[#chips].w == "-100" and chips[#chips].bb == "100")
  check("D9: nothing to any chat channel", #a.sent > 0 and (function()
    for _, m in ipairs(a.sent) do if m.chan ~= "GUILD" then return false end end return true end)())
end

-- ---------------------------------------------------------------- D4: turn, range, outsiders
do
  local w, a, b, c = table3()
  a:slash("gamble deathroll sap hapi 50")
  w:advance(1)
  b:slash("gamble join")
  w:advance(1)
  local ga = game(a)
  typed(b, 30, 1, 50)
  check("D7: out of turn: ignored, with the line", #ga.rolls == 0 and logHas(ga, "Sap Hapi rolled out of turn."))
  typed(a, 30, 1, 30)
  check("D7: wrong range: ignored, with the line", #ga.rolls == 0 and logHas(ga, "Stromham Hamson rolled the wrong range."))
  typed(c, 2, 1, 50)
  check("D7: a bystander's roll is not ours", #ga.rolls == 0 and not logHas(ga, "Liliac"))
  typed(a, 30, 1, 50)
  check("D7: a typed /roll with the right range counts", #ga.rolls == 1 and ga.cur == 30)
  local seen = game(c)
  check("D2: a party member not in the duel sees it listed, not joinable", seen and seen.opp == "Sap Hapi")
  c:slash("gamble join")
  check("D2: and can't join it", c:said("No open game to join in your party.") ~= nil)
end

-- ---------------------------------------------------------------- D6: stakes
do
  local w, a, b = table3()
  a:slash("gamble deathroll Sap 1")
  check("D6: a stake of 1 is refused", a:said(a.DT._gamble.STAKE_LINE) ~= nil)
  a:slash("gamble deathroll Sap 501")
  check("D6: 501 is refused", a:said(a.DT._gamble.STAKE_LINE) ~= nil)
  a:slash("gamble highlow 2.5")
  check("D6: a fraction is refused", a:said(a.DT._gamble.STAKE_LINE) ~= nil)
  a.DT.gambleWallet().b = 40
  a:slash("gamble highlow 50")
  check("D6: more than you hold is refused", a:said("You hold 40 chips. Not enough for that stake.") ~= nil
    and #sentKind(a, "GAME") == 0)
  a:slash("gamble highlow 40")
  check("D6: exactly what you hold is fine", #sentKind(a, "GAME") == 1)
  w:advance(1)
  b.DT.gambleWallet().b = 10
  b:slash("gamble join")
  check("D6: joining with too little is refused", b:said("You hold 10 chips.") ~= nil and #sentKind(b, "JOIN") == 0)
  a:slash("gamble deathroll Nobody 10")
  check("D2: a name not in your party is refused", a:said("Nobody isn't in your party.") ~= nil)
  a:slash("gamble deathroll Stromham 10")
  check("deathroll yourself: refused", a:said("You can't deathroll yourself.") ~= nil)
  local w2 = H.world()
  local solo = mk(w2, { name = "Stromham", full = "Stromham Hamson" })
  solo:slash("gamble highlow 50")
  check("D2: no party, no game", solo:said(solo.DT._gamble.NO_PARTY) ~= nil and #sentKind(solo, "GAME") == 0)
end

-- ---------------------------------------------------------------- D5: high-low
do
  local w, a, b, c = table3()
  a:slash("gamble highlow 100")
  w:advance(1)
  b:slash("gamble join"); c:slash("gamble join")
  w:advance(1)
  local ga, gb, gc = game(a), game(b), game(c)
  check("D5: the host's table has three players", #ga.players == 3)
  a:slash("gamble call")
  w:advance(1)
  check("D5: Final call starts it for everyone", ga.state == "rolling" and gb.state == "rolling" and gc.state == "rolling")
  check("D5: everyone rolls 1-100", a.DT._gambleRange() == 100 and b.DT._gambleRange() == 100 and c.DT._gambleRange() == 100)
  a.rolls = { 80 }; a:slash("gamble roll")
  b.rolls = { 30 }; b:slash("gamble roll")
  c.rolls = { 55 }; c:slash("gamble roll")
  w:advance(1)
  check("D5: settled on all three", ga.state == "settled" and gb.state == "settled" and gc.state == "settled")
  check("D5: the lowest pays the highest the difference (50)", bal(a) == 1050 and bal(b) == 950)
  check("D5: the middle moves nothing", bal(c) == 1000)
  check("D9: the result line", b:said("High-low: Sap Hapi pays Stromham Hamson 50 chips.") ~= nil)
  check("D8: the middle player is on the board too (played)", c.DT.gambleWallet().played == true)
end

-- ---------------------------------------------------------------- D5: ties
do
  local w, a, b, c = table3()
  a:slash("gamble highlow 100"); w:advance(1)
  b:slash("gamble join"); c:slash("gamble join"); w:advance(1)
  a:slash("gamble call"); w:advance(1)
  local ga, gc = game(a), game(c)
  a.rolls = { 90 }; a:slash("gamble roll")
  b.rolls = { 90 }; b:slash("gamble roll")
  c.rolls = { 10 }; c:slash("gamble roll")
  check("D5: a tie at the top: only the tied roll again", ga.state == "rolling" and c.DT._gambleRange() == nil
    and a.DT._gambleRange() == 100 and b.DT._gambleRange() == 100)
  typed(c, 50, 1, 100)
  check("D5: the untied player rolling then is out of turn", logHas(ga, "Liliac Thorne rolled out of turn."))
  typed(a, 40, 1, 50)
  check("D7: high-low, the wrong range: ignored, with the line", logHas(ga, "Stromham Hamson rolled the wrong range.")
    and a.DT._gambleRange() == 100)
  a.rolls = { 20 }; a:slash("gamble roll")
  b.rolls = { 70 }; b:slash("gamble roll")
  w:advance(1)
  check("D5: tie settled: the payment is from the first round (90 - 10 = 80)", bal(b) == 1080 and bal(c) == 920 and bal(a) == 1000)
  check("D5: all three agree", gc.state == "settled")
end
do
  local w, a, b, c = table3()
  a:slash("gamble highlow 100"); w:advance(1)
  b:slash("gamble join"); c:slash("gamble join"); w:advance(1)
  a:slash("gamble call"); w:advance(1)
  a.rolls = { 90 }; a:slash("gamble roll")
  b.rolls = { 5 }; b:slash("gamble roll")
  c.rolls = { 5 }; c:slash("gamble roll")
  check("D5: a tie at the bottom: only the tied roll again", a.DT._gambleRange() == nil and b.DT._gambleRange() == 100
    and c.DT._gambleRange() == 100)
  b.rolls = { 40 }; b:slash("gamble roll")
  c.rolls = { 3 }; c:slash("gamble roll")
  w:advance(1)
  check("D5: the low tie's loser pays (90 - 5 = 85)", bal(c) == 915 and bal(a) == 1085 and bal(b) == 1000)
end
do
  local w, a, b = table3()
  w.party = { a, b }
  a:slash("gamble highlow 100"); w:advance(1)
  b:slash("gamble join"); w:advance(1)
  a:slash("gamble call"); w:advance(1)
  a.rolls = { 50, 70 }; a:slash("gamble roll")
  b.rolls = { 50, 20 }; b:slash("gamble roll")
  check("D5: two players, the same roll: both roll again", a.DT._gambleRange() == 100 and b.DT._gambleRange() == 100)
  a:slash("gamble roll"); b:slash("gamble roll")
  w:advance(1)
  check("D5: then settled on the new rolls (50)", bal(a) == 1050 and bal(b) == 950)
end

-- ---------------------------------------------------------------- D5: the close
do
  local w, a, b = table3()
  a:slash("gamble highlow 30"); w:advance(1)
  local ga = game(a)
  w:advance(21)
  check("D5: nobody joins: 20 s on, the table folds", ga.state == "folded" and a:said(a.DT._gamble.FOLDED) ~= nil)
  check("D5: the fold reaches the party", game(b).state == "folded" and #sentKind(a, "FOLD") == 1)
  check("D5: nothing moved", bal(a) == 1000 and not a.DT._gambleListening())
  a:slash("gamble highlow 30"); w:advance(1)
  w:advance(15)
  b:slash("gamble join"); w:advance(1)
  w:advance(15)
  check("D5: a join puts the 20 s back", game(a).state == "open")
  w:advance(6)
  check("D5: 20 s after the last join, it closes by itself", game(a).state == "rolling" and game(b).state == "rolling")
  local calls = sentKind(a, "CALL")
  check("D5: CALL names the players, host first", calls[#calls].p == "Stromham Hamson,Sap Hapi")
end

-- ---------------------------------------------------------------- D7: disputes
do
  local w, a, b, c = table3()
  a:slash("gamble highlow 100"); w:advance(1)
  b:slash("gamble join"); c:slash("gamble join"); w:advance(1)
  a:slash("gamble call"); w:advance(1)
  local gb = game(b)
  -- c never sees b's roll (as if it missed the line); a and b do
  a.rolls = { 80 }; a:slash("gamble roll")
  local line = string.format(PROBE, b.full, 30, 1, 100)
  a:fire("CHAT_MSG_SYSTEM", line); b:fire("CHAT_MSG_SYSTEM", line); b.rolled = 1
  c.rolls = { 55 }; c:slash("gamble roll")
  w:advance(1)
  check("D7: the host settled on its own reading", game(a).state == "settled" and bal(a) == 1050)
  check("D7: a client that saw the same rolls settles", gb.state == "settled" and bal(b) == 950)
  w:advance(6)
  check("D7: a client that missed a roll: disputed", game(c).state == "disputed" and c:said(c.DT._gamble.DISPUTED) ~= nil)
  check("D7: and its own balance didn't move", bal(c) == 1000)
end
do
  local w, a, b = table3()
  w.party = { a, b }
  a:slash("gamble highlow 100"); w:advance(1)
  b:slash("gamble join"); w:advance(1)
  a:slash("gamble call"); w:advance(1)
  -- a sees b roll 30; b's client sees 90 (two different readings)
  a.rolls = { 80 }; a:slash("gamble roll")
  a:fire("CHAT_MSG_SYSTEM", string.format(PROBE, b.full, 30, 1, 100))
  b:fire("CHAT_MSG_SYSTEM", string.format(PROBE, b.full, 90, 1, 100))
  w:advance(1)
  check("D7: a client whose rolls disagree with the host's: disputed", game(b).state == "disputed")
  check("D7: nothing moved on that client", bal(b) == 1000)
  check("D7: only a player's own client changes their balance (the host never touches b's)",
    a.DT.gambleWallet().b == 1050 and b.DT.gambleWallet().b == 1000)
end

-- ---------------------------------------------------------------- D2: same name twice; not in the party
do
  local w, a, b = table3()
  local twin = mk(w, { name = "Sap", full = "Sap Hapi", realm = "CAMWOW EU4 Realm 1 PvP" })
  w.party = { a, b, twin }
  a:slash("gamble highlow 50"); w:advance(1)
  b:slash("gamble join"); w:advance(1)
  twin:slash("gamble join"); w:advance(1)
  check("D2: a second Sap Hapi (another realm) can't sit at the same table", #game(a).players == 2)
  local w2, x, y, z = table3()
  w2.party = { x, y }
  x:slash("gamble highlow 50"); w2:advance(1)
  check("D2: a game from outside your party isn't listed", game(z) == nil)
  inject(x, "JOIN", z:key(), { h = x:key(), g = tostring(game(x).n) })
  check("D2: a join from outside the party is ignored", #game(x).players == 1)
end

-- ---------------------------------------------------------------- the time-out
do
  local w, a, b = table3()
  a:slash("gamble deathroll Sap 50"); w:advance(1)
  b:slash("gamble join"); w:advance(1)
  w:advance(121)
  check("time-out: two minutes with nobody rolling folds it", game(a).state == "folded" and a:said(a.DT._gamble.TIMED_OUT) ~= nil)
  check("time-out: nothing moved", bal(a) == 1000 and bal(b) == 1000)
  a:slash("debug gamble fast")
  check("time-out: debug shortens it to 10 s", a.DT._gamble.timeout() == 10)
  local saved = false
  local function scan(t, depth)
    if depth > 6 then return end
    for _, v in pairs(t) do if v == 10 then saved = true elseif type(v) == "table" then scan(v, depth + 1) end end
  end
  scan(a:db().gamble, 1)
  scan(a:db().settings or {}, 1)
  check("time-out: the debug setting is never saved", not saved)
  a:slash("gamble deathroll Sap 50"); w:advance(1)
  b:slash("gamble join"); w:advance(1)
  w:advance(11)
  check("time-out: shortened, it folds in 10 s", game(a).state == "folded")
  local a2 = a:reload()
  check("time-out: a reload puts it back to two minutes", a2.DT._gamble.timeout() == 120)
end

-- ---------------------------------------------------------------- D8: the board
do
  local w, a, b = table3()
  local D = a.DT
  local K = "CAMWOWEU4Realm2PvP-"
  inject(a, "CHIPS", K .. "Echo Nightclaw", { b = "1400", w = "400", bb = "0", we = tostring(RESET) })
  inject(a, "CHIPS", K .. "Liliac High", { b = "600", w = "-400", bb = "300", we = tostring(RESET) })
  inject(a, "CHIPS", K .. "Zed Last", { b = "1000", w = "-400", bb = "120", we = tostring(RESET) })
  local rows = D.gambleRows()
  check("D8: rows sorted by this week, then balance, then name",
    rows[1].name == "Echo Nightclaw" and rows[2].name == "Zed Last" and rows[3].name == "Liliac High")
  check("D8: the footer names the week's biggest beat-down", D.gambleFooter():find("Biggest beat-down this week: Liliac High, 300 chips.", 1, true) ~= nil)
  check("D8: the closing line", D.gambleFooter():find("Only guildies running the addon who have played.", 1, true) ~= nil)
  check("D8: you're not on it before you've played", #rows == 3)
  a.skew = 4 * DAY
  rows = D.gambleRows()
  check("D8: a week gone: every received week reads 0", rows[1].w == 0 and rows[2].w == 0)
  check("D8: and no beat-down footer", D.gambleFooter():find("Biggest", 1, true) == nil)
  inject(a, "CHIPS", K .. "Liliac High", { off = "1" })
  check("D8: CHIPS off=1 deletes the entry", D._gamble.store().board[K .. "Liliac High"] == nil)
  local before = bad(a)
  inject(a, "CHIPS", K .. "Junk One", { b = "x", w = "1", bb = "0", we = "1" })
  inject(a, "CHIPS", K .. "Junk Two", { b = "1", w = "1", bb = "0" })
  inject(a, "CHIPS", K .. "Junk Three", { b = "99999999999", w = "1", bb = "0", we = "1" })
  inject(a, "CHIPS", K .. "Junk Four", { off = "1", b = "1" })
  check("D8: bad CHIPS are counted and dropped", bad(a) == before + 4 and D._gamble.store().board[K .. "Junk One"] == nil)
  for i = 1, 205 do inject(a, "CHIPS", K .. "Player " .. i, { b = "1000", w = "0", bb = "0", we = tostring(RESET) }) end
  local n = 0 for _ in pairs(D._gamble.store().board) do n = n + 1 end
  check("D8: the board caps at 200", n == 200)
  a.skew = 4 * DAY + 29 * DAY
  D.gambleRows()
  n = 0 for _ in pairs(D._gamble.store().board) do n = n + 1 end
  check("D8: 29 days unseen: still there", n == 200)
  a.skew = 4 * DAY + 31 * DAY
  D.gambleRows()
  n = 0 for _ in pairs(D._gamble.store().board) do n = n + 1 end
  check("D8: entries drop after 30 days unseen", n == 0)
end
do
  local w, a, b = table3()
  a:slash("gamble deathroll Sap 50"); w:advance(1)
  b:slash("gamble join"); w:advance(1)
  a.rolls = { 1 }; a:slash("gamble roll"); w:advance(1)
  local K = b:key()
  check("D8: after a game, each player is on the other's board", a.DT._gamble.store().board[K] ~= nil)
  b:slash("gamble board off"); w:advance(1)
  check("D8: board off withdraws you from everyone's board", a.DT._gamble.store().board[K] == nil)
  local offs = sentKind(b, "CHIPS")
  check("D8: with CHIPS {off=1}", offs[#offs].off == "1")
  local before = #sentKind(b, "CHIPS")
  b.DT.set("gamble", "enabled", false)
  b.DT.set("gamble", "board", true)
  b.DT.set("gamble", "board", false)
  check("D8: withdraw is sent even with the module off", #sentKind(b, "CHIPS") == before + 1)
  b.DT.set("gamble", "enabled", true)
  local b2 = b:reload(); w:advance(30)
  check("D8: board off: nothing sent at login", #sentKind(b2, "CHIPS") == 0)
  b2:slash("gamble deathroll Stromham 20"); w:advance(1)
  a:slash("gamble join"); w:advance(1)
  b2.rolls = { 1 }; b2:slash("gamble roll"); w:advance(1)
  check("D8: board off: nothing sent after a game either", #sentKind(b2, "CHIPS") == 0 and a.DT._gamble.store().board[K] == nil)
  local w2, x = table3()
  local s0 = #sentKind(x, "CHIPS")
  check("D8: never played: nothing sent at login", s0 == 0)
end
do
  local w, a, b = table3()
  a:slash("gamble deathroll Sap 50"); w:advance(1)
  b:slash("gamble join"); w:advance(1)
  a.rolls = { 1 }; a:slash("gamble roll"); w:advance(1)
  local a2 = a:reload()
  w:advance(9)
  check("D8: not yet at 9 s after login", #sentKind(a2, "CHIPS") == 0)
  w:advance(2)
  check("D8: CHIPS 10 s after login once you've played", #sentKind(a2, "CHIPS") >= 1)
end

-- ---------------------------------------------------------------- inbound validation
do
  local w, a, b = table3()
  local K = b:key()
  local before = bad(a)
  inject(a, "GAME", K, { g = "x", k = "hl", s = "50" })
  inject(a, "GAME", K, { g = "1", k = "poker", s = "50" })
  inject(a, "GAME", K, { g = "1", k = "hl", s = "501" })
  inject(a, "GAME", K, { g = "1", k = "dr", s = "50" })
  inject(a, "GAME", K, { g = "1", k = "hl", s = "50", o = "Someone" })
  check("GAME validation: five bad, five counted, no game", bad(a) == before + 5 and game(a) == nil)
  inject(a, "GAME", K, { g = "7", k = "hl", s = "50" })
  local before2 = bad(a)
  inject(a, "CALL", K, { g = "7", p = "Sap Hapi" })
  inject(a, "CALL", K, { g = "7", p = "Sap Hapi,Sap Hapi" })
  inject(a, "CALL", K, { g = "7", p = "Stromham Hamson,Sap Hapi" })
  inject(a, "CALL", K, { g = "7", p = "Sap Hapi,Bad;Name" })
  inject(a, "RESULT", K, { g = "7" })
  inject(a, "JOIN", K, { g = "z", h = a:key() })
  check("CALL, RESULT and JOIN validation: six bad, six counted", bad(a) == before2 + 6)
  local before3 = bad(a)
  inject(a, "CALL", K, { g = "7" })
  local long = {}
  for i = 1, 41 do long[#long + 1] = "Someone Number" .. string.rep("x", 30) end
  inject(a, "CALL", K, { g = "7", p = "Sap Hapi," .. table.concat(long, ",") })
  check("CALL validation: no players, or more than a table holds: counted", bad(a) == before3 + 2)
  check("a bad CALL starts nothing", game(a).state == "open")
end

-- ---------------------------------------------------------------- the module off; outside the guild
do
  local w, a, b = table3()
  b.DT.set("gamble", "enabled", false)
  a:slash("gamble highlow 50"); w:advance(1)
  check("off: no game heard", game(b) == nil)
  b:slash("gamble")
  check("off: the verb says off and nothing else", b:said(b.DT._gamble.OFF) ~= nil and #b.printed == 1)
  b:fire("CHAT_MSG_SYSTEM", "Sap Hapi rolls 3 (1-50)")
  check("off: no error from a roll line", #b.errors == 0)
  b:slash("gamble highlow 50")
  check("off: a typed game starts nothing", #sentKind(b, "GAME") == 0 and #b.printed == 1)
  local wr, x, y = table3()
  wr.party = { x, y }
  x:slash("gamble deathroll Sap 50"); wr:advance(1)
  y:slash("gamble join"); wr:advance(1)
  x.DT.set("gamble", "enabled", false)
  check("off: the roll listener goes with the switch", not x.DT._gambleListening())
  x.DT._gambleSystem(string.format(PROBE, x.full, 20, 1, 50))
  check("off: a roll line reaching the module is not read", #game(x).rolls == 0)
  local w2 = H.world()
  local out = mk(w2, { name = "Stromham", full = "Stromham Hamson", guild = false })
  local other = mk(w2, { name = "Sap", full = "Sap Hapi" })
  w2.party = { out, other }
  out:slash("gamble highlow 50")
  check("outside the guild: nothing", #out.printed == 0 and #out.sent == 0)
end

-- ---------------------------------------------------------------- the windows
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson", setup = function(c) rawset(c.env, "UISpecialFrames", {}) end })
  local b = mk(w, { name = "Sap", full = "Sap Hapi" })
  w.party = { a, b }
  w:advance(30)
  a:slash("gamble")
  local vp = a.DT._gamble.vp()
  check("window: /dt gamble opens the table", vp and vp:IsShown())
  local L = a.DT._gamble.list()
  check("window: the list's empty state", L.empty.text == a.DT._gamble.EMPTY and L.empty.shown)
  local raw = a.DT.textRecord(a.DT._gamble.status()).raw
  check("window: with no game the status shows your balance, not the empty line again (walk, 24 Nov)",
    raw == "You hold 1000 chips." and raw:find(a.DT._gamble.EMPTY, 1, true) == nil)
  local esc = false
  for _, n in ipairs(a.env.UISpecialFrames) do if n == "DeadTiredViewport_gamble" then esc = true end end
  check("window: Escape closes it (in UISpecialFrames)", esc)
  check("window: draggable, its place remembered", vp.frame.scripts.OnDragStop ~= nil or vp.frame.scripts.OnMouseUp ~= nil)
  b:slash("gamble deathroll Stromham 20"); w:advance(1)
  local bt = a.DT._gamble.buttons()
  check("window: Join shows for a challenge to you", bt.join:IsShown() and not bt.roll:IsShown() and not bt.call:IsShown())
  a:slash("gamble join"); w:advance(1)
  check("window: Roll shows only on your turn", not bt.roll:IsShown())
  b.rolls = { 10 }; b:slash("gamble roll"); w:advance(1)
  check("window: then it's yours", bt.roll:IsShown())
  bt.roll.scripts.OnClick()
  check("window: the Roll button calls RandomRoll with your range", a.rolled == 1)
  a:slash("gamble board")
  check("window: /dt gamble board opens the ledger", a.DT._gamble.bvp():IsShown())
  local w2, x = table3()
  x:slash("gamble board")
  local rows = x.DT.gambleRows()
  check("board: empty state when nobody has played", #rows == 0)
  check("fit: no text over its box under any skin", (function()
    local last = x.DT.fitCheck()
    return last[#last]:find(" 0 over,", 1, true) ~= nil and last[#last]:find("measure failures 0", 1, true) ~= nil
  end)())
  local st = a.DT._gamble.status()
  local body = a.DT._gamble.vp().body
  a.DT.byId.gamble.fit()
  check("fit: the status block keeps to its room above the buttons", a.DT.textHeight(st, body.dtWidth) <= body.dtHeight - 110 - 28)
  st.font = { "big", 26 }                                                   -- a big skin font: the oldest lines must go
  a.DT.byId.gamble.fit()
  check("fit: under a big font the status still keeps to its room", a.DT.textHeight(st, body.dtWidth) <= body.dtHeight - 110 - 28)
  check("fit: ...by dropping log lines, keeping the balance line", a.DT.textRecord(st).raw:find("^You hold") ~= nil)
  local help = x.DT.helpLine()
  check("help: /dt gamble is listed", help:find("gamble [join|deathroll <name> <stake>|highlow <stake>|call|roll|board]", 1, true) ~= nil)
  check("settings: the board card has a typed form and a description", x.DT.setting("gamble", "board").verb == "gamble board on|off"
    and x.DT.setting("gamble", "board").desc ~= "")
end

-- ---------------------------------------------------------------- the ghost
do
  local w, a = table3()
  a:slash("debug ghost chips")
  local rows = a.DT.gambleRows()
  check("ghost: /dt debug ghost chips puts the Restless Ghost on the board", #rows == 1 and rows[1].name == "Restless Ghost"
    and rows[1].b == 1250 and rows[1].w == 250)
  a:slash("debug ghost off")
  check("ghost: laid to rest, it leaves the board", #a.DT.gambleRows() == 0)
end

H.finish("gamble")
