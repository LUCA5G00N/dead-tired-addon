-- Offline checks for Comms.lua, on the real AceComm-3.0 + ChatThrottleLib: R-1, the held line,
-- AUD-10, the protocol version, the payload key (match / mismatch), sender with and without -Realm,
-- the raw-sender record.  lua5.1 DeadTired/tests/test_comms.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"

local function quiet() return { schema = 3, settings = { who = { enabled = false } } } end

local function setup(o)
  o = o or {}
  local w = H.world()
  local a = w:client({ name = "Stromham", full = "Stromham Hamson", realm = "CAMWOW EU4 Realm 2 PvP", guild = G, db = quiet(),
    senderShape = o.shape })
  local b = w:client({ name = "Lilbit", full = "Lilbit High", realm = o.bRealm or "CAMWOW EU4 Realm 4 PvP", guild = G,
    db = quiet(), senderShape = o.shape })
  a:login(); b:login()
  w:advance(6)                         -- past ChatThrottleLib's 5 s of hard throttling after login
  local got = {}
  b.DT.on("TEST", function(from, d, sender) got[#got + 1] = { from = from, d = d, sender = sender } end)
  a.DT.on("TEST", function(from, d) got.a = (got.a or 0) + 1 end)
  return w, a, b, got
end

local function inject(c, text, sender, chan, prefix)
  c:fire("CHAT_MSG_ADDON", prefix or "DEADTIRED", text, chan or "GUILD", sender)
end

-- a typed command that sends (DT.inCommand is set by the router)
local function pingVerb(c)
  c.DT.verb({ verb = "ping", usage = "ping", fn = function() c.DT.send("TEST", { p = 1 }) end })
end

-- ---------------------------------------------------------------- end to end, both sender shapes
do
  local w, a, b, got = setup()
  check("prefix registered (through AceComm)", a.registered.DEADTIRED == true)
  check("send queues and answers true", a.DT.send("TEST", { x = "hi^there~|", n = 7 }) == true)
  w:advance(2)
  check("on the wire: GUILD, our prefix, protocol 2 in front", #a.sent == 1 and a.sent[1].chan == "GUILD"
    and a.sent[1].prefix == "DEADTIRED" and a.sent[1].text:sub(1, 2) == "2:")
  check("received once, from the payload key, data intact", #got == 1 and got[1].from == "CAMWOWEU4Realm2PvP-Stromham Hamson"
    and got[1].d.x == "hi^there~|" and got[1].d.n == 7)
  check("cross-realm sender string carried -Realm", got[1].sender == "Stromham Hamson-CAMWOWEU4Realm2PvP")
  check("own message ignored (the GUILD echo)", got.a == nil and a:db().comms.received == 0)
  check("counted: sent 1, received 1", a:db().comms.sent == 1 and b:db().comms.received == 1)
end

do -- Tim's rc3 /dt who: a guildie on another realm arrived with no realm in the sender string
  local w, a, b, got = setup({ shape = function(from) return from.full end })
  a.DT.send("TEST", { x = 1 })
  w:advance(2)
  check("sender without -Realm from a connected realm: the payload key still names the realm",
    #got == 1 and got[1].sender == "Stromham Hamson" and got[1].from == "CAMWOWEU4Realm2PvP-Stromham Hamson")
end

do
  local w, a, b, got = setup({ bRealm = "CAMWOW EU4 Realm 2 PvP" })
  a.DT.send("TEST", { x = 1 })
  w:advance(2)
  check("same realm: bare sender name, key from the payload", #got == 1 and got[1].sender == "Stromham Hamson"
    and got[1].from == "CAMWOWEU4Realm2PvP-Stromham Hamson")
end

-- ---------------------------------------------------------------- payload key: match and mismatch
do
  local w, a, b, got = setup()
  local enc = b.DT._comms.encode
  inject(b, enc("TEST", { x = 1 }, "CAMWOWEU4Realm9PvP-Ghoul Grim"), "ghoul grim-CAMWOWEU4Realm9PvP")
  check("name parts match case-insensitively", #got == 1 and got[1].from == "CAMWOWEU4Realm9PvP-Ghoul Grim")
  inject(b, enc("TEST", { x = 2 }, "CAMWOWEU4Realm9PvP-Ghoul Grim"), "Ghoul Grim")
  check("accepted with no -Realm in the sender", #got == 2)
  inject(b, enc("TEST", { x = 3 }, "CAMWOWEU4Realm2PvP-Stromham Hamson"), "Ghoul Grim-CAMWOWEU4Realm9PvP")
  check("a payload key naming someone else is not taken", #got == 2)
  local s = b:db().comms
  check("the mismatch is counted and kept, not guessed", s.keyMismatch == 1 and #s.mismatches == 1
    and s.mismatches[1].sender == "Ghoul Grim-CAMWOWEU4Realm9PvP" and s.mismatches[1].key == "CAMWOWEU4Realm2PvP-Stromham Hamson")
  inject(b, enc("TEST", { x = 4 }, "CAMWOWEU4Realm9PvP-Ghoul"), "Ghoul Grim")
  check("a short name is not the full name", #got == 2 and s.keyMismatch == 2)
  for i = 1, 12 do inject(b, enc("TEST", {}, "R-Nobody" .. i), "Somebody") end
  check("mismatches kept: the last 10", #s.mismatches == 10 and s.keyMismatch == 14)
  b:slash("debug senders")
  check("/dt debug senders shows the mismatches", b:said("mismatch: sender") ~= nil)
end

-- ---------------------------------------------------------------- protocol version, malformed
do
  local w, a, b, got = setup()
  local s = b:db().comms
  inject(b, "1^HELLO^v~0.1.0", "Ghoul Grim")
  check("an rc3 (protocol 1) message: not ours, counted malformed", s.malformed == 1 and #got == 0)
  inject(b, "3:" .. b.DT._comms.encode("TEST", {}, "R-Ghoul Grim"):sub(3), "Ghoul Grim")
  check("an unknown version is counted and ignored, not decoded", s.unknownVersion == 1 and #got == 0)
  inject(b, "2:!!not deflate!!", "Ghoul Grim")
  inject(b, "2:", "Ghoul Grim")
  inject(b, string.rep("x", 300), "Ghoul Grim")
  check("junk never raises, counted malformed", s.malformed == 4 and #got == 0 and #b.errors == 0)
  inject(b, b.DT._comms.encode("TEST", {}, "no key here"), "Ghoul Grim")
  inject(b, b.DT._comms.encode("lower", {}, "R-Ghoul Grim"), "Ghoul Grim")
  check("a payload without a key, or a bad kind: malformed", s.malformed == 6)
  inject(b, b.DT._comms.encode("TEST", {}, "R-Ghoul Grim"), "Ghoul Grim", "PARTY")
  inject(b, b.DT._comms.encode("TEST", {}, "R-Ghoul Grim"), "Ghoul Grim", "GUILD", "OTHERADDON")
  check("only GUILD and only our prefix are read", #got == 0)
end

-- ---------------------------------------------------------------- chunking (AceComm)
do
  local w, a, b, got = setup()
  local parts, seed = {}, 7
  for i = 1, 1500 do seed = (seed * 1103515245 + 12345) % 2147483648; parts[i] = string.char(33 + seed % 90) end
  local big = table.concat(parts)
  a.DT.send("TEST", { big = big })
  w:advance(5)
  local over = false
  for _, m in ipairs(a.sent) do if #m.text > 255 then over = true end end
  check("a big message goes in chunks of at most 255 bytes", #a.sent > 3 and not over)
  check("and arrives whole", #got == 1 and got[1].d.big == big)
end

-- ---------------------------------------------------------------- R-1: lockdown only
do
  local w, a, b, got = setup()
  check("the restricted flag is read and recorded at login", a:db().comms.flagRestricted == true and a:db().comms.flagReads == 1)
  a.DT.send("TEST", { x = 1 })
  w:advance(2)
  check("restricted flag true does not hold a send (R-1)", #got == 1)
  a.lockdown = true
  a.DT.send("TEST", { x = 2 })
  w:advance(12)
  check("in lockdown: held, nothing sent", #got == 1 and #a.sent == 1 and a.DT._comms.holding() and #a.DT._comms.queue() == 1)
  check("a hold is counted", a:db().comms.held == 1)
  a.lockdown = false
  w:advance(6)
  check("lockdown over: it goes, within the 5 s recheck", #got == 2 and got[2].d.x == 2 and not a.DT._comms.holding())
end

-- ---------------------------------------------------------------- the held line
do
  local w, a, b, got = setup()
  pingVerb(a)
  a.lockdown = true
  a.printed = {}
  a.DT.send("TEST", { auto = true })
  check("a send the addon makes itself: no held line", #a.printed == 0)
  a:slash("ping")
  check("a typed command's message: the held line", a:count("The dead are gagged for this fight. Your message goes when it's over.") == 1)
  a:slash("ping")
  check("once per hold", a:count("The dead are gagged") == 0)
  a.lockdown = false
  w:advance(6)
  check("all three go after the fight", #got == 3)
  a.lockdown = true
  a:slash("ping")
  check("a new hold, the line again", a:count("The dead are gagged") == 1)
end

-- ---------------------------------------------------------------- AUD-10
do
  local w, a, b, got = setup()
  a.sendResult = H.RESULT.GeneralError
  a.DT.send("TEST", { x = 1 })
  w:advance(10)
  local s = a:db().comms
  check("refused every time: tried 3 times, then dropped and counted", #a.refused == 3 and s.refusedDropped == 1
    and s.sendRefused == 3 and #got == 0 and #a.DT._comms.queue() == 0)
  local gap = true
  for i = 2, #a.refused do if a.refused[i].t - a.refused[i - 1].t < 1 then gap = false end end
  check("at least 1 s between tries", gap)
  w:advance(10)
  check("and not tried again", #a.refused == 3)
end

do
  local w, a, b, got = setup()
  local n = 0
  a.sendResult = function() n = n + 1; return n == 1 and H.RESULT.GeneralError or 0 end
  a.DT.send("TEST", { x = 1 })
  w:advance(4)
  local s = a:db().comms
  check("refused once, then sent: delivered once", #got == 1 and s.sendRefused == 1 and s.refusedDropped == 0 and s.sent == 1)
end

do -- ChatThrottleLib keeps a throttled chunk itself (result 3); DT's count doesn't see it
  local w, a, b, got = setup()
  a.sendResult = H.RESULT.AddonMessageThrottle
  a.DT.send("TEST", { x = 1 })
  w:advance(3)
  check("throttled: kept by ChatThrottleLib, retried, not a DT refusal", #a.refused >= 2 and a:db().comms.sendRefused == 0)
  a.sendResult = 0
  w:advance(2)
  check("throttle lifts: delivered once", #got == 1 and a:db().comms.refusedDropped == 0)
end

do -- refused because of lockdown: held, not a try
  local w, a, b, got = setup()
  a.sendResult = function() a.lockdown = true; return H.RESULT.AddOnMessageLockdown end
  a.DT.send("TEST", { x = 1 })
  w:advance(3)
  check("a refusal while in lockdown is held, not counted as a try", a.DT._comms.holding() and #a.DT._comms.queue() == 1
    and a:db().comms.refusedDropped == 0)
  a.sendResult = 0
  a.lockdown = false
  w:advance(6)
  check("and goes after", #got == 1)
end

do -- a big message with one refused chunk: the whole message again
  local w, a, b, got = setup()
  local parts, seed = {}, 3
  for i = 1, 900 do seed = (seed * 1103515245 + 12345) % 2147483648; parts[i] = string.char(33 + seed % 90) end
  local big = table.concat(parts)
  local n = 0
  a.sendResult = function() n = n + 1; return n == 2 and H.RESULT.GeneralError or 0 end
  a.DT.send("TEST", { big = big })
  w:advance(6)
  check("a refused chunk: the message is sent again and arrives whole, once", #got == 1 and got[1].d.big == big
    and a:db().comms.sendRefused == 1 and #b.errors == 0)
end

-- ---------------------------------------------------------------- raw senders, capped
do
  local w, a, b, got = setup()
  a.DT.send("TEST", { x = 1 })
  w:advance(2)
  for i = 1, 60 do inject(b, "junk", "Ghoul" .. i .. "-Realm") end
  local s = b:db().comms
  local n = 0
  for _ in pairs(s.senders) do n = n + 1 end
  check("every distinct raw sender string kept, capped at 50", n == 50 and s.sendersOverflow >= 10)
  check("including the cross-realm guildie's, raw", s.senders["Stromham Hamson-CAMWOWEU4Realm2PvP"] ~= nil)
  b:slash("debug senders")
  check("/dt debug senders prints them", b:said('"Ghoul1-Realm"') ~= nil and b:said("senders: 50 (cap 50") ~= nil)
end

-- ---------------------------------------------------------------- queue cap
do
  local w, a, b, got = setup()
  a.lockdown = true
  for i = 1, 55 do a.DT.send("TEST", { i = i }) end
  check("held queue capped at 50, oldest dropped and counted", #a.DT._comms.queue() == 50 and a:db().comms.dropped == 5)
end

H.finish("comms")
