-- Offline checks for Ghost.lua (dt_selftest, R-F8-3 to R-F8-6): each kind reaches its handler
-- through Comms' inbound, the answers to STASHQ, PREPQ and WHO, the purge at its three call sites,
-- the comms counters left alone, nothing on the wire, the guild gate, "on" kept in memory only.
--   lua5.1 DeadTired/tests/test_ghost.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local GKEY = "DTGHOST-Restless Ghost"

local LIL = { name = "Lilbit", full = "Lilbit High", realm = "CAMWOW EU4 Realm 4 PvP" }

local function mk(w, o)
  o = o or {}
  return w:client({ name = o.name or "Stromham", full = o.full or "Stromham Hamson",
    realm = o.realm or "CAMWOW EU4 Realm 2 PvP", guild = o.guild == nil and G or (o.guild or nil), db = o.db,
    random = function() return 0.5 end })
end

-- Any string in t (keys or values, nested) containing DTGHOST.
local function ghostly(t, depth)
  depth = depth or 0
  if depth > 12 then return false end
  for k, v in pairs(t) do
    if type(k) == "string" and k:find("DTGHOST", 1, true) then return true end
    if type(v) == "string" and v:find("DTGHOST", 1, true) then return true end
    if type(v) == "table" and ghostly(v, depth + 1) then return true end
  end
  return false
end

local function copy(t)
  if type(t) ~= "table" then return t end
  local o = {}
  for k, v in pairs(t) do o[k] = copy(v) end
  return o
end

local function listed(c)
  for _, r in ipairs(c.DT.whoRows()) do if r.key == GKEY then return true end end
  return false
end

local function wireCount(w) return #w.wire end

-- ---------------------------------------------------------------- each kind reaches its handler
do
  local w = H.world()
  local a = mk(w); a:login(); w:advance(10)
  local wire0, sent0 = wireCount(w), #a.sent
  a:slash("debug ghost hello")
  check("hello: the ghost is in Who's list", listed(a))
  check("hello: the ghost is on the alts roster", type(a:db().alts.roster[GKEY]) == "table")
  check("hello: the bar counts the ghost", a.DT.whoCount() == 1)
  a:slash("debug ghost death")
  check("death: the notice prints", a:said("Restless Ghost died at level 13 in The Barrens") ~= nil)
  local deaths = a:db().crypt.deaths
  check("death: recorded with the ghost's key", deaths[#deaths].who == GKEY)
  a:slash("debug ghost gank")
  local logs = a:db().gank.logs
  check("gank: recorded, by the ghost", logs[#logs].by == GKEY)
  a:slash("debug ghost played")
  check("played: on the slowest board", type(a:db().played.board[GKEY]) == "table")
  w:advance(30)
  check("nothing reached the wire or AceComm", wireCount(w) == wire0 and #a.sent == sent0 and #a.refused == 0)
end

-- ---------------------------------------------------------------- stash and prep need a question first
do
  local w = H.world()
  local a = mk(w); a:login(); w:advance(10)
  a:slash("debug ghost stash")
  check("stash before any search: ask first", a:said("Ask first: /dt stash <item>.") ~= nil)
  a:slash("debug ghost prep")
  check("prep before any roll call: ask first", a:said("Ask first: /dt prep roll.") ~= nil)
end

-- ---------------------------------------------------------------- the answers (R-F8-4)
do
  local w = H.world()
  local a = mk(w); a:login(); w:advance(10)
  a:slash("debug ghost on")
  check("on: says so", a:said("The Restless Ghost is up.") ~= nil)
  a:slash("stash Linen")
  w:advance(2)
  local o = a.DT._stash.open()
  check("stash: the ghost answers the search", o and o.answers[GKEY] ~= nil and o.answers[GKEY][1].id == 2589)
  a:slash("prep roll")
  w:advance(2)
  local p = a.DT._prep.open()
  check("prep: the ghost answers the roll call, ready", p and p.answers[GKEY] and p.answers[GKEY].ok == true)
  w:advance(10)
  check("prep: the summary names the ghost", a:said("Ready (1): Restless Ghost") ~= nil)
  a.DT._who.reset()
  a:slash("who")
  w:advance(2)
  check("who: the ghost answers with a HELLO", listed(a))
  -- the real questions still went to the guild, and only they did
  local kinds = {}
  for _, m in ipairs(a.sent) do local ok, pl = a.DT._comms.decode(m.text); if ok == "ok" then kinds[pl.k] = (kinds[pl.k] or 0) + 1 end end
  check("the real STASHQ, PREPQ and WHO went out; nothing as the ghost", kinds.STASHQ == 1 and kinds.PREPQ == 1
    and kinds.WHO == 1 and not kinds.STASH and not kinds.PREP)
  for _, m in ipairs(a.sent) do
    local ok, pl = a.DT._comms.decode(m.text)
    check("no message on the wire carries the ghost's key", ok ~= "ok" or pl.f ~= GKEY)
  end
end

-- ---------------------------------------------------------------- off before the answer is due
do
  local w = H.world()
  local a = mk(w); a:login(); w:advance(10)
  a:slash("debug ghost on")
  a:slash("stash Linen")
  a:slash("debug ghost off")
  w:advance(2)
  local o = a.DT._stash.open()
  check("off before the answer is due: no answer", o and o.answers[GKEY] == nil)
end

-- ---------------------------------------------------------------- off answers nothing
do
  local w = H.world()
  local a = mk(w); a:login(); w:advance(10)
  a:slash("stash Linen")
  w:advance(2)
  local o = a.DT._stash.open()
  check("off: the ghost doesn't answer", o and o.answers[GKEY] == nil)
  a:slash("debug ghost stash")
  check("off: the verb answers the open search", o.answers[GKEY] ~= nil)
end

-- ---------------------------------------------------------------- the purge: ghost off
do
  local w = H.world()
  local a = mk(w); a:login(); w:advance(10)
  local b = mk(w, LIL); b:login(); w:advance(10)
  -- a real guildie's death and gank, which must survive the purge
  b.DT.send("DEATH", { lvl = "20", zone = "Duskwood", hc = "0" })
  b.DT.send("GANK", { who = "Stormwind-Some Rogue", cls = "ROGUE", lvl = "22", zone = "Duskwood" })
  w:advance(2)
  a:slash("debug ghost on")
  a:slash("debug ghost all")
  check("all: the ghost said its four (no question open)", a:said("The Restless Ghost said 4 things.") ~= nil)
  check("before off: the ghost is in the saved data", ghostly(a:db()))
  a:slash("debug ghost off")
  check("off: says so", a:said("laid to rest") ~= nil)
  check("off: no DTGHOST anywhere in DeadTiredDB", not ghostly(a:db()))
  check("off: not in Who's session list; the bar back to 1", not listed(a) and a.DT.whoCount() == 1)
  local bkey = b:key()
  local keptDeath, keptGank = false, false
  for _, d in ipairs(a:db().crypt.deaths) do if d.who == bkey then keptDeath = true end end
  for _, g in ipairs(a:db().gank.logs) do if g.by == bkey then keptGank = true end end
  check("off: a real guildie's death and gank are kept", keptDeath and keptGank)
  check("off: the answers stop", not a.DT._ghost.isOn())
end

-- ---------------------------------------------------------------- the purge: PLAYER_LOGOUT
do
  local w = H.world()
  local a = mk(w); a:login(); w:advance(10)
  a:slash("debug ghost all")
  check("logout: ghost entries present first", ghostly(a:db()))
  a:fire("PLAYER_LOGOUT")
  check("logout: no DTGHOST anywhere in DeadTiredDB", not ghostly(a:db()))
end

-- ---------------------------------------------------------------- the purge: every load
do
  local w = H.world()
  local db = { schema = 3, who = { seen = { [GKEY] = { v = "0.3.5" } } },
    crypt = { deaths = { { who = GKEY, lvl = 13, zone = "The Barrens", mine = false } } },
    played = { board = { [GKEY] = { lvl = 13, hours = 666 } } },
    errors = { ["who:last"] = "HELLO: " .. GKEY } }
  local a = mk(w, { db = db })
  check("load: no DTGHOST anywhere after loading planted entries", not ghostly(a:db()))
  check("load: the rest of the store kept", a:db().schema == 3 and type(a:db().crypt.deaths) == "table")
end

-- ---------------------------------------------------------------- counters left alone
do
  local w = H.world()
  local a = mk(w); a:login(); w:advance(10)
  local c = a:db().comms
  local before = { received = c.received, malformed = c.malformed, mm = #c.mismatches, km = c.keyMismatch }
  local nSenders = 0; for _ in pairs(c.senders) do nSenders = nSenders + 1 end
  a:slash("debug ghost all")
  local after = 0; for _ in pairs(c.senders) do after = after + 1 end
  check("counters: received, malformed, mismatches unchanged", c.received == before.received
    and c.malformed == before.malformed and #c.mismatches == before.mm and c.keyMismatch == before.km)
  check("counters: no sender recorded for the ghost", after == nSenders and not c.senders["Restless Ghost-DTGHOST"])
end

-- ---------------------------------------------------------------- a ghost never makes DT send
do
  local w = H.world()
  local a = mk(w); a:login(); w:advance(10)
  a.DT.on("DEATH", function() a.DT.send("DEATH", { lvl = "1", zone = "X", hc = "0" }) end)
  local wire0 = wireCount(w)
  local ok, sends = a.DT.ghostDeliver("DEATH", { lvl = "13", zone = "The Barrens", hc = "0" })
  w:advance(5)
  check("a handler's send during a ghost message is recorded, not sent", ok and #sends == 1 and sends[1] == "DEATH"
    and wireCount(w) == wire0)
  check("DT.send is itself again afterwards", a.DT.send("WHO", { v = "x" }) == true)
end

-- ---------------------------------------------------------------- outside the guild
do
  local w = H.world()
  local a = mk(w, { guild = false })
  a:login(); w:advance(10)
  a:slash("debug ghost hello")
  check("outside the guild: the verb says nothing", #a.printed == 0)
  local ok = a.DT.ghostDeliver("HELLO", { v = "x" })
  check("outside the guild: nothing delivered", ok == false and not listed(a))
end

-- ---------------------------------------------------------------- on is never saved; the switch
do
  local w = H.world()
  local a = mk(w); a:login(); w:advance(10)
  local before = copy(a:db().settings)
  a:slash("debug ghost on")
  check("on: no setting written", not ghostly(a:db()) and (a:db().settings.ghost == nil
    or a:db().settings.ghost.on == nil) and (before.ghost == nil) == (a:db().settings.ghost == nil))
  local n = a:reload()
  check("on: a /reload turns it off", not n.DT._ghost.isOn())
  n:slash("debug ghost all")
  n:slash("set ghost enabled off")
  check("switch off: purges, and the verb is off", not ghostly(n:db()) and not n.DT._ghost.isOn())
  n:slash("debug ghost hello")
  check("switch off: the verb says so and does nothing", n:said("ghost.enabled = off") ~= nil and not listed(n))
  check("help lists debug ghost", n.DT.helpLine():find("debug ghost", 1, true) ~= nil)
end

H.finish("ghost")
