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
    if u == "target" and c.targetName ~= nil then return c.targetName end
    return base(u, showRealm)
  end)
  rawset(env, "UnitIsPlayer", function(u) if u == "target" then return c.targetIsPlayer == true end return true end)
  rawset(env, "SOUNDKIT", { READY_CHECK = 8960 })
  c.played = {}
  rawset(env, "PlaySound", function(kit) c.played[#c.played + 1] = kit end)
  c.bells, c.ringing = {}, {}
  rawset(env, "PlaySoundFile", function(file, channel)
    if c.noBell then return false end
    c.bells[#c.bells + 1] = { file, channel }; c.played[#c.played + 1] = file
    local h = #c.bells; c.ringing[h] = true
    return true, h
  end)
  local cs = rawget(env, "C_Sound") or {}
  cs.IsPlaying = function(h) return c.ringing[h] == true end
  rawset(env, "C_Sound", cs)
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
  check("help: /dt gamble is listed", help:find("gamble [join|decline|leave|cancel|deathroll [<name>] <stake>|highlow <stake>|call|roll|rematch|double|again|board|sound]", 1, true) ~= nil)
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

-- ================================================================ round 2 (dt_gamble2, 0.7.0; T1-T12)

local function btn(c, name) return c.DT._gamble.buttons()[name] end
local function click(b) b.scripts.OnClick(b) end
local function shownButtons(c)
  local out = {}
  for _, k in ipairs({ "join", "decline", "roll", "call", "cancel", "leave", "rematch", "double", "again", "new" }) do
    if btn(c, k):IsShown() then out[#out + 1] = k end
  end
  return table.concat(out, ",")
end
local function lastGameOf(c) local o = c.DT._gamble.order(); return c.DT._gamble.games()[o[#o]] end

-- ---------------------------------------------------------------- T1: the New game panel
do
  local w, a, b, c = table3()
  a:slash("gamble")
  click(btn(a, "new"))
  local P = a.DT._gamble.panel()
  check("T1: New game opens the panel", P:IsShown())
  local rows = a.DT.gamblePartyRows()
  check("T1: the party, without you, DT runners first", #rows == 2 and rows[1].runs and rows[2].runs)
  click(P.stakes[3])                                                       -- 100
  local L = a.DT._gamble.plist()
  local row
  for _, r in ipairs(L.rows) do if r.row and r.row.name == "Sap Hapi" then row = r end end
  row.scripts.OnClick(row, "LeftButton")
  w:advance(1)
  local g = lastGameOf(a)
  check("T1: a name click starts a deathroll at the chosen stake", g and g.kind == "dr" and g.s == 100 and g.opp == "Sap Hapi")
  check("T1: the panel closes after starting", not P:IsShown())
  check("T1: the same as the typed command (GAME to the party)", #sentKind(a, "GAME") == 1 and sentKind(a, "GAME")[1].o == "Sap Hapi")
  click(btn(a, "cancel")); w:advance(1)
  click(btn(a, "new"))
  a.DT._gamble.pstake():SetText("37")
  click(P.buttons.table); w:advance(1)
  g = lastGameOf(a)
  check("T1: Open high-low uses the typed stake", g.kind == "hl" and g.s == 37)
  click(btn(a, "cancel")); w:advance(1)
  click(btn(a, "new"))
  a.DT._gamble.pstake():SetText("900")
  click(P.buttons.table)
  check("T1: a stake over 500 in the box is refused", a:said(a.DT._gamble.STAKE_LINE) ~= nil and P:IsShown())
  -- a party member not running DT
  local w2 = H.world()
  local x = mk(w2, { name = "Stromham", full = "Stromham Hamson" })
  local y = mk(w2, { name = "Sap", full = "Sap Hapi" })
  local z = mk(w2, { name = "Nobody", full = "Nobody Atall", guild = false })
  w2.party = { x, y, z }
  w2:advance(30)
  local r2 = x.DT.gamblePartyRows()
  check("T1: a member not running DT is listed last, greyed", #r2 == 2 and r2[1].name == "Sap Hapi" and r2[2].name == "Nobody Atall"
    and not r2[2].runs and r2[2].state == "no addon")
  x:slash("gamble"); click(btn(x, "new"))
  local L2 = x.DT._gamble.plist()
  for _, r in ipairs(L2.rows) do if r.row and r.row.name == "Nobody Atall" then r.scripts.OnClick(r, "LeftButton") end end
  check("T1: clicking them starts nothing and says why", x:said("Nobody Atall isn't running Dead Tired.") ~= nil and #sentKind(x, "GAME") == 0)
end

-- ---------------------------------------------------------------- T2: Accept and Decline
do
  local w, a, b = table3()
  a:slash("gamble deathroll Sap 40"); w:advance(1)
  check("T2: the challenge is printed to the challenged", b:said("Stromham Hamson challenges you to a deathroll for 40. Accept or decline.") ~= nil)
  b:slash("gamble")
  check("T2: a challenge shows Accept and Decline", shownButtons(b) == "join,decline,new" and btn(b, "join"):GetText() == "Accept")
  click(btn(b, "decline")); w:advance(1)
  check("T2: Decline sends DECLINE", #sentKind(b, "DECLINE") == 1)
  check("T2: the challenger's game folds, with the line", lastGameOf(a).state == "folded" and a:said("Sap Hapi declined.") ~= nil)
  check("T2: nothing moved", bal(a) == 1000 and bal(b) == 1000)
  -- a high-low keeps Join
  a:slash("gamble highlow 20"); w:advance(1)
  b:slash("gamble")
  check("T2: a high-low table shows Join, no Decline", shownButtons(b) == "join,new" and btn(b, "join"):GetText() == "Join")
  -- decline only from the challenged player
  local w2, x, y, z = table3()
  x:slash("gamble deathroll Sap 40"); w2:advance(1)
  inject(x, "DECLINE", z:key(), { h = x:key(), g = tostring(lastGameOf(x).n) })
  check("T2: a DECLINE from someone else is ignored", lastGameOf(x).state == "open")
  local before = bad(x)
  inject(x, "DECLINE", y:key(), { h = x:key(), g = "nope" })
  check("T10: a bad DECLINE is counted", bad(x) == before + 1 and lastGameOf(x).state == "open")
  before = bad(y)
  inject(y, "LEAVE", z:key(), { h = string.rep("k", 81), g = "1" })
  inject(y, "LEAVE", z:key(), { g = "1" })
  check("T10: a bad LEAVE is counted", bad(y) == before + 2)
  before = bad(z)
  inject(z, "GAME", x:key(), { g = "50", k = "dr", s = "20", o = "Liliac Thorne", re = "7" })
  inject(z, "GAME", x:key(), { g = "51", k = "hl", s = "20", re = "1" })
  check("T10: re other than 1 or 2, or on a high-low, is counted and dropped", bad(z) == before + 2
    and z.DT._gamble.games()[x:key() .. "#50"] == nil and z.DT._gamble.games()[x:key() .. "#51"] == nil)
end

-- ---------------------------------------------------------------- T3: Cancel and Leave
do
  local w, a, b, c = table3()
  a:slash("gamble highlow 30"); w:advance(1)
  b:slash("gamble join"); c:slash("gamble join"); w:advance(1)
  check("T3: the host sees Final call and Cancel", (function() a:slash("gamble"); return shownButtons(a) == "call,cancel,new" end)())
  b:slash("gamble")
  check("T3: a joiner sees Leave", shownButtons(b) == "leave,new")
  click(btn(b, "leave")); w:advance(1)
  local g = lastGameOf(a)
  check("T3: Leave drops the joiner from the host's table", #g.players == 2 and g.players[2] == "Liliac Thorne")
  check("T3: the host is told", a:said("Sap Hapi left the table.") ~= nil)
  w:advance(15)
  check("T3: and the 20 s close starts again", lastGameOf(a).state == "open")
  w:advance(6)
  check("T3: closes 20 s after the leave", lastGameOf(a).state == "rolling")
  check("T3: the leaver isn't pulled back in", lastGameOf(b).state == "closed" or lastGameOf(b).state == "open")
  b:slash("gamble leave")
  check("T3: no Leave once rolling", b:said("No table to leave.") ~= nil)
  c:slash("gamble"); click(btn(c, "leave"))
  check("T3: not even from a stale Leave button: no LEAVE sent once rolling", #sentKind(c, "LEAVE") == 0)
  local gr = lastGameOf(a)
  inject(a, "LEAVE", c:key(), { h = a:key(), g = tostring(gr.n) })
  check("T3: a LEAVE reaching the host after the call changes nothing", #gr.players == 2)
  a:slash("gamble cancel")
  check("T3: no Cancel once rolling", a:said("No game of yours to cancel.") ~= nil and lastGameOf(a).state == "rolling")
  click(btn(a, "cancel"))
  check("T3: not even from a stale Cancel button: no FOLD sent once rolling", #sentKind(a, "FOLD") == 0)
  -- cancel before rolling reaches everyone
  local w2, x, y, z = table3()
  x:slash("gamble highlow 30"); w2:advance(1)
  y:slash("gamble join"); w2:advance(1)
  x:slash("gamble cancel"); w2:advance(1)
  check("T3: Cancel folds for everyone, with the line", lastGameOf(x).state == "folded" and lastGameOf(y).state == "folded"
    and y:said("Stromham Hamson cancelled.") ~= nil)
  local f = sentKind(x, "FOLD")
  check("T3: as a FOLD with why=cancel (0.6.0 clients read a fold)", f[#f].why == "cancel")
  check("T3: a bystander isn't told", not z:said("cancelled"))
  local before = bad(y)
  inject(y, "FOLD", x:key(), { g = "1", why = "bored" })
  check("T10: a FOLD with an unknown why is counted", bad(y) == before + 1)
end

-- ---------------------------------------------------------------- T4, T7: Rematch, Double or nothing, Same again
do
  local w, a, b = table3()
  a:slash("gamble deathroll Sap 100"); w:advance(1)
  b:slash("gamble join"); w:advance(1)
  a.rolls = { 1 }; a:slash("gamble roll"); w:advance(1)                     -- a loses 100
  a:slash("gamble"); b:slash("gamble")
  check("T4: after a deathroll both see Rematch and Double or nothing", shownButtons(a) == "rematch,double,new"
    and shownButtons(b) == "rematch,double,new")
  click(btn(a, "double")); w:advance(1)
  local g = lastGameOf(b)
  check("T4/T7: the loser may offer double or nothing: a new challenge at 200", g.kind == "dr" and g.s == 200 and g.state == "open"
    and sentKind(a, "GAME")[2].re == "2")
  check("T4: with its own line", b:said("Stromham Hamson says double or nothing: 200. Accept or decline.") ~= nil)
  check("T7: it needs Accept: nothing rolls yet", g.state == "open" and lastGameOf(a).state == "open")
  b:slash("gamble join"); w:advance(1)
  check("T7: accepted, it plays", lastGameOf(a).state == "rolling")
  b.rolls = { 1 }; w:advance(1)
  a.rolls = { 5 }; a:slash("gamble roll"); b.rolls = { 1 }; b:slash("gamble roll"); w:advance(1)
  check("T4: double or nothing settles at 200", bal(a) == 1100 and bal(b) == 900)
  b:slash("gamble rematch"); w:advance(1)
  check("T4: the winner... the loser offers a rematch at the same stake", lastGameOf(a).s == 200 and sentKind(b, "GAME")[1].re == "1"
    and a:said("Sap Hapi wants a rematch for 200. Accept or decline.") ~= nil)
  -- double over the cap, or over what you hold
  local w2, x, y = table3()
  x:slash("gamble deathroll Sap 300"); w2:advance(1)
  y:slash("gamble join"); w2:advance(1)
  x.rolls = { 1 }; x:slash("gamble roll"); w2:advance(1)
  x:slash("gamble")
  check("T4: double over 500 is greyed with the reason", btn(x, "double").dtDisabled and btn(x, "double").dtWhy == x.DT._gamble.OVER_CAP)
  click(btn(x, "double"))
  check("T4: and clicking it only says why", x:said(x.DT._gamble.OVER_CAP) ~= nil and #sentKind(x, "GAME") == 1)
  local w3, p, q = table3()
  p:slash("gamble deathroll Sap 200"); w3:advance(1)
  q:slash("gamble join"); w3:advance(1)
  p.DT.gambleWallet().b = 300
  p.rolls = { 1 }; p:slash("gamble roll"); w3:advance(1)               -- p now holds 100
  p:slash("gamble")
  check("T4: double over what you hold is greyed, with the reason", btn(p, "double").dtDisabled and btn(p, "double").dtWhy:find("You hold 100", 1, true))
  p:slash("gamble double")
  check("T4: double over what you hold is refused", p:said("You hold 100 chips.") ~= nil and #sentKind(p, "GAME") == 1)
  -- Same again
  local w4, h, j = table3()
  h:slash("gamble highlow 25"); w4:advance(1)
  j:slash("gamble join"); w4:advance(1)
  h:slash("gamble call"); w4:advance(1)
  h.rolls = { 20 }; h:slash("gamble roll"); j.rolls = { 3 }; j:slash("gamble roll"); w4:advance(1)
  h:slash("gamble"); j:slash("gamble")
  check("T4: after a high-low the host sees Same again", shownButtons(h) == "again,new" and shownButtons(j) == "new")
  click(btn(h, "again")); w4:advance(1)
  check("T4: Same again opens a new table at the same stake", lastGameOf(j).kind == "hl" and lastGameOf(j).s == 25 and lastGameOf(j).state == "open")
end

-- ---------------------------------------------------------------- T5: challenge your target
do
  local w, a, b, c = table3()
  a.targetName, a.targetIsPlayer = "Sap Hapi", true
  a:slash("gamble deathroll 60"); w:advance(1)
  check("T5: /dt gamble deathroll <stake> challenges your party target", lastGameOf(b).opp == "Sap Hapi" and lastGameOf(b).s == 60)
  a:slash("gamble cancel"); w:advance(1)
  a.targetName, a.targetIsPlayer = "Mottled Boar", false
  a:slash("gamble deathroll 60")
  check("T5: an NPC target: refused", a:said(a.DT._gamble.NO_TARGET) ~= nil and #sentKind(a, "GAME") == 1)
  a.targetName, a.targetIsPlayer = nil, false
  a:slash("gamble deathroll 60")
  check("T5: no target: refused", #sentKind(a, "GAME") == 1)
  local outsider = mk(w, { name = "Echo", full = "Echo Nightclaw" })
  a.targetName, a.targetIsPlayer = "Echo Nightclaw", true
  a:slash("gamble deathroll 60")
  check("T5: a player outside your party: refused", a:said("Echo Nightclaw isn't in your party.") ~= nil and #sentKind(a, "GAME") == 1)
  a.targetName = "Stromham Hamson"
  a:slash("gamble deathroll 60")
  check("T5: yourself: refused", #sentKind(a, "GAME") == 1)
  a.targetName, a.targetIsPlayer = "Liliac Thorne", true
  a:slash("gamble"); click(btn(a, "new"))
  a.DT._gamble.pstake():SetText("15")
  click(a.DT._gamble.panel().buttons.target); w:advance(1)
  check("T5: the panel's Challenge target does the same", lastGameOf(c).opp == "Liliac Thorne" and lastGameOf(c).s == 15)
  -- the target is read in one function only
  local src = io.open("DeadTired/Gamble.lua"):read("*a")
  local n = 0
  for _ in src:gmatch('"target"') do n = n + 1 end
  check("T5: the target is read in exactly one place (readTarget)", n == 2 and src:find('local function readTarget()', 1, true) ~= nil)
  local _, after = src:find('local function readTarget()', 1, true)
  local body = src:sub(after, (src:find("\nend\n", after, true)))
  local inBody = 0
  for _ in body:gmatch('"target"') do inBody = inBody + 1 end
  check("T5: ...and both reads are inside it (UnitIsPlayer, GetUnitName)", inBody == 2)
end

-- ---------------------------------------------------------------- T6: your turn
do
  local w, a, b = table3()
  a:slash("gamble"); b:slash("gamble")
  a:slash("gamble deathroll Sap 50"); w:advance(1)
  b:slash("gamble join"); w:advance(1)
  check("T6: the glow is on for the player whose turn it is", btn(a, "glow"):IsShown() and not btn(b, "glow"):IsShown())
  check("T6: the sound is off by default: nothing played", #a.played == 0 and a.DT._gambleSounds() == 0)
  a.rolls = { 30 }; a:slash("gamble roll"); w:advance(1)
  check("T6: the glow moves with the turn", not btn(a, "glow"):IsShown() and btn(b, "glow"):IsShown())
  check("T6: still no sound with it off", #b.played == 0)
  b:slash("gamble sound on")
  check("T6: /dt gamble sound on", b.DT.get("gamble", "sound") == true)
  b.rolls = { 10 }; b:slash("gamble roll"); w:advance(1)
  a:slash("gamble sound on")
  check("T6: (a switched on after its turn came: no sound for that turn)", #a.played == 0)
  a.rolls = { 4 }; a:slash("gamble roll"); w:advance(1)
  check("T6: with it on, the turn coming round plays one sound (0.7.1: the Undercity bell, on SFX)",
    #b.played == 1 and b.played[1] == 565853 and b.bells[1][2] == "SFX")
  b.rolls = { 1 }; b:slash("gamble roll"); w:advance(1)
  check("T6: the glow goes when the game ends", not btn(a, "glow"):IsShown() and not btn(b, "glow"):IsShown())
  check("T6: the sound card: typed form and description", b.DT.setting("gamble", "sound").verb == "gamble sound on|off"
    and b.DT.setting("gamble", "sound").default == false)
end

-- ---------------------------------------------------------------- 0.7.1: the bell
do
  local w, a, b = table3()
  a:slash("gamble"); b:slash("gamble")
  a:slash("gamble sound on"); b:slash("gamble sound on")
  a:slash("gamble deathroll Sap 50"); w:advance(1)
  b:slash("gamble join"); w:advance(1)
  check("0.7.1: a's first turn tolls the bell", #a.bells == 1 and a.bells[1][1] == 565853)
  a.rolls = { 40 }; a:slash("gamble roll"); w:advance(1)
  b.rolls = { 30 }; b:slash("gamble roll"); w:advance(1)
  check("0.7.1: still tolling: no second bell over the first", #a.bells == 1 and a.DT._gambleSounds() == 1)
  a.ringing[1] = nil
  a.rolls = { 20 }; a:slash("gamble roll"); w:advance(1)
  b.noBell = true; b.ringing = {}
  b.rolls = { 10 }; b:slash("gamble roll"); w:advance(1)
  check("0.7.1: the bell done, the next turn tolls again", #a.bells == 2)
  a.rolls = { 5 }; a:slash("gamble roll"); w:advance(1)
  check("0.7.1: a client that can't play the bell gets the old chime", b.played[#b.played] == 8960)
  b.rolls = { 1 }; b:slash("gamble roll"); w:advance(1)
  check("0.7.1: the card says bell", b.DT.setting("gamble", "sound").desc:find("Undercity bell", 1, true) ~= nil)
end

-- ---------------------------------------------------------------- T8: the bar
do
  local w, a = table3()
  local found
  for _, e in ipairs(a.DT.barList()) do if e.name == "gamble" then found = e end end
  check("T8: the table has a bar launcher (off until ticked, like Session)", found ~= nil and not found.on)
  local o = a.DT._bar and a.DT.objects
  local ldb
  for _, x in ipairs(a.DT.objects) do if x.name == "gamble" then ldb = x.obj end end
  ldb.OnClick(nil, "LeftButton")
  check("T8: left-click opens the table", a.DT._gamble.vp():IsShown())
  ldb.OnClick(nil, "RightButton")
  check("T8: right-click opens the ledger", a.DT._gamble.bvp():IsShown())
  local tt = { lines = {}, AddLine = function(self, l) self.lines[#self.lines + 1] = l end }
  ldb.OnTooltipShow(tt)
  check("T8: the tooltip shows your chips", tt.lines[2] == "You hold 1000 chips.")
end

-- ---------------------------------------------------------------- T9: a 0.6.0 peer
do
  local w, a, b, c = table3()
  -- b behaves as 0.6.0: it never sends DECLINE or LEAVE and has no Decline; it joins and rolls as before
  inject(b, "GAME", a:key(), { g = "999", k = "dr", s = "50", o = "Sap Hapi", re = "1" })
  check("T9: a GAME with re passes 0.6.0's checks (here: accepted as a challenge)", b.DT._gamble.games()[a:key() .. "#999"] ~= nil)
  a:slash("gamble deathroll Sap 50"); w:advance(1)
  b:slash("gamble join"); w:advance(1)
  a.rolls = { 9 }; a:slash("gamble roll"); b.rolls = { 1 }; b:slash("gamble roll"); w:advance(1)
  check("T9: a deathroll between them settles", bal(a) == 1050 and bal(b) == 950)
  -- the leaver on a 0.6.0 host: the host keeps them; the leaver isn't pulled back in; the time-out covers it
  local w2, x, y = table3()
  w2.party = { x, y }
  x:slash("gamble highlow 20"); w2:advance(1)
  y:slash("gamble join"); w2:advance(1)
  y.DT._gamble.games()[x:key() .. "#" .. lastGameOf(x).n].left = true                  -- y left; x (0.6.0) never heard
  y.DT._gamble.games()[x:key() .. "#" .. lastGameOf(x).n].joined = false
  x:slash("gamble call"); w2:advance(1)
  check("T9: a leaver named in an old host's CALL stays out", lastGameOf(y).state == "closed")
  w2:advance(125)
  check("T9: the old host's table times out; nothing moved", lastGameOf(x).state == "folded" and bal(x) == 1000 and bal(y) == 1000)
end

-- ---------------------------------------------------------------- the window follows your latest game (walk, 24 Nov 23:52)
do
  -- Tim's sequence: Lilbit challenges him to a deathroll (it settles), then opens a high-low; he joins; it settles.
  local w, a, b = table3()
  w.party = { a, b }
  a:slash("gamble")
  b:slash("gamble deathroll Stromham 50"); w:advance(1)
  a:slash("gamble join"); w:advance(1)
  b.rolls = { 1 }; b:slash("gamble roll"); w:advance(1)
  local raw = function() return a.DT.textRecord(a.DT._gamble.status()).raw end
  check("window: the settled deathroll shows", raw():find("Deathroll:", 1, true) ~= nil)
  b:slash("gamble highlow 250"); w:advance(1)
  check("window: a new table in the party takes over the window", raw():find("opens a high-low table at 250", 1, true) ~= nil)
  a:slash("gamble join"); w:advance(1)
  b:slash("gamble call"); w:advance(1)
  b.rolls = { 164 }; b:slash("gamble roll"); w:advance(1)
  a.rolls = { 124 }; a:slash("gamble roll"); w:advance(1)
  check("window: after the high-low settles, the joiner sees the high-low's result, not the old deathroll",
    raw():find("High-low: Stromham Hamson pays Sap Hapi 40 chips.", 1, true) ~= nil and raw():find("Deathroll:", 1, true) == nil)
  -- a click still wins until something newer happens
  local L = a.DT._gamble.list()
  local dr
  for _, r in ipairs(L.rows) do if r.row and r.row.name:find("Deathroll", 1, true) then dr = r end end
  dr.scripts.OnClick(dr, "LeftButton")
  check("window: clicking an older game shows it", raw():find("Deathroll:", 1, true) ~= nil)
  b:slash("gamble highlow 30"); w:advance(1)
  check("window: ...until a newer game happens", raw():find("opens a high-low table at 30", 1, true) ~= nil)
end

-- ---------------------------------------------------------------- buttons fit their labels (walk, 24 Nov 23:16)
do
  local w, a, b = table3()
  a:slash("gamble"); click(btn(a, "new"))
  local P = a.DT._gamble.panel()
  local all = {}
  for _, k in ipairs({ "join", "decline", "roll", "call", "cancel", "leave", "rematch", "double", "again", "new" }) do
    all[#all + 1] = btn(a, k)
  end
  for _, k in ipairs({ "target", "table", "back" }) do all[#all + 1] = P.buttons[k] end
  local bad_ = {}
  for _, bt in ipairs(all) do
    local need = a.DT.measure(bt:GetText(), "body")
    if not (bt.dtWidth and need and bt.dtWidth >= need + 16) then bad_[#bad_ + 1] = bt:GetText() end
  end
  check("buttons: every label fits inside its button", #bad_ == 0)
  if #bad_ > 0 then print("  too narrow: " .. table.concat(bad_, ", ")) end
  local body = a.DT._gamble.vp().body.dtWidth
  check("buttons: the panel's row fits the window", a.DT._gambleRowWidth({ P.buttons.target, P.buttons.table, P.buttons.back }) <= body)
  check("buttons: the widest action row fits the window (Rematch, Double or nothing, New game)",
    a.DT._gambleRowWidth({ btn(a, "rematch"), btn(a, "double"), btn(a, "new") }) <= body)
  check("buttons: ...and Accept, Decline, New game; Final call, Cancel, New game",
    a.DT._gambleRowWidth({ btn(a, "join"), btn(a, "decline"), btn(a, "new") }) <= body
    and a.DT._gambleRowWidth({ btn(a, "call"), btn(a, "cancel"), btn(a, "new") }) <= body)
  check("panel: the status and the game list hide under it", not a.DT._gamble.status():IsShown() and not a.DT._gamble.list().frame:IsShown())
  check("panel: the action buttons hide under it", not btn(a, "new"):IsShown())
  click(P.buttons.back)
  check("panel: Back brings them all back", a.DT._gamble.status():IsShown() and a.DT._gamble.list().frame:IsShown() and btn(a, "new"):IsShown())
end

-- ---------------------------------------------------------------- the round's text fits
do
  local w, a = table3()
  a:slash("gamble"); click(btn(a, "new"))
  check("fit: the panel and the new buttons fit under every skin", (function()
    local last = a.DT.fitCheck()
    return last[#last]:find(" 0 over,", 1, true) ~= nil and last[#last]:find("measure failures 0", 1, true) ~= nil
  end)())
  check("nothing errors in round 2's runs", #a.errors == 0)
end

H.finish("gamble")
