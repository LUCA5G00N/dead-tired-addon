-- Offline checks for Comms.lua.  lua5.1 DeadTired/tests/test_comms.lua  (from the repo root)
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local FILES = { "Config.lua", "Core.lua", "Guild.lua", "Comms.lua" }
local G = "DEAD TIRED"

local function setup(opts)
  local w = H.world()
  local a = w:client({ name = "Stromham", guild = G, files = FILES })
  local b = w:client({ name = "Graverobber", guild = (opts and opts.bGuild) or G, files = FILES })
  local got = {}
  b.DT.on("TEST", function(from, f) got[#got + 1] = { from = from, f = f } end)
  return w, a, b, got
end

-- Inject a message straight into a client's CHAT_MSG_ADDON, as from `sender`.
local function inject(c, text, sender, chan, prefix)
  c:fire("CHAT_MSG_ADDON", prefix or "DEADTIRED", text, chan or "GUILD", sender or "Graverobber-ClassicBetaPvP")
end

-- ---------------------------------------------------------------- escaping
do
  local w, a = setup()
  local C = a.DT._comms
  check("prefix registered at load", a.registered.DEADTIRED == true)
  local all = "%^~|"
  for i = 0, 31 do all = all .. string.char(i) end
  local e = C.esc(all)
  check("every escaped character becomes %XX, upper-case", e:sub(1, 12) == "%25%5E%7E%7C" and e:find("%00%01", 1, true)
    and e:find("%1F", 1, true) and not e:find("[%^~|%z\1-\31]") and #e == 36 * 3)
  check("escape round-trip on every escaped character", C.unesc(e) == all)
  local mixed = "Rest in Pieces: 100% ^_^ ~ |cffff0000red|r\nline2"
  check("escape round-trip on mixed text", C.unesc(C.esc(mixed)) == mixed)
  check("plain text passes untouched", C.esc("Classic Beta PvP-Stromham") == "Classic Beta PvP-Stromham")
  check("lower-case hex decodes too; a broken escape is refused", C.unesc("%7e") == "~" and C.unesc("%ZZ") == nil
    and C.unesc("50%") == nil and C.unesc("a^b") == nil and C.unesc("a|b") == nil)
  local m = C.encode("HELLO", { v = "0.1.0", main = "Classic Beta PvP-Stromham" })
  check("encode: protocol, kind, sorted escaped fields", m == "1^HELLO^main~Classic Beta PvP-Stromham^v~0.1.0")
  local k, f = C.parseBody("HELLO^main~a%5Eb^v~")
  check("parse: fields decoded, empty values kept", k == "HELLO" and f.main == "a^b" and f.v == "")
end

-- ---------------------------------------------------------------- end to end
do
  local w, a, b, got = setup()
  check("send queues and answers true", a.DT.send("TEST", { x = "hi^there~|" }) == true)
  check("sent on GUILD with the prefix", #a.sent == 1 and a.sent[1].chan == "GUILD" and a.sent[1].prefix == "DEADTIRED")
  w:advance(0)
  check("the other client receives it once, sender normalised to Realm-Name, fields decoded", #got == 1
    and got[1].from == "ClassicBetaPvP-Stromham" and got[1].f.x == "hi^there~|")
end

-- ---------------------------------------------------------------- own messages
do
  local w, a, b, got = setup()
  b.DT.send("TEST", { x = "me" })
  w:advance(0)
  check("own message ignored: the GUILD echo does not reach the sender's handlers", #got == 0 and #b.sent == 1)
  inject(b, "1^TEST^x~bare", "Graverobber")
  check("own message ignored: a bare Name takes the player's realm", #got == 0)
  inject(b, "1^TEST^x~other", "Ghoul")
  check("a bare Name from someone else is Realm-Name on the player's realm", #got == 1
    and got[1].from == "ClassicBetaPvP-Ghoul")
  inject(b, "1^TEST^x~far", "Ghoul-Nethergarde")
  check("another realm keeps its own name", got[2].from == "Nethergarde-Ghoul")
end

-- ---------------------------------------------------------------- channel and prefix
do
  local w, a, b, got = setup()
  inject(b, "1^TEST^x~1", "Ghoul", "PARTY")
  inject(b, "1^TEST^x~1", "Ghoul", "WHISPER")
  inject(b, "1^TEST^x~1", "Ghoul", "GUILD", "OTHERADDON")
  check("only GUILD and only our prefix are read", #got == 0)
end

-- ---------------------------------------------------------------- chunking
do
  local w, a, b, got = setup()
  local big = string.rep("abcdefghij", 45) .. "^~|"   -- 450 bytes raw, 459 escaped
  a.DT.send("TEST", { x = big })
  check("a long message is sent as 3 chunks", #a.sent == 3)
  local c1 = a.sent[1].text
  local id0 = tonumber(c1:match("^1%^%+%^(%d+)%^"))
  check("chunk header: protocol ^ + ^ msgid ^ i ^ n ^ slice", c1:match("^1%^%+%^%d+%^1%^3%^") ~= nil
    and a.sent[3].text:match("^1%^%+%^" .. tostring(id0) .. "%^3%^3%^") ~= nil)
  local slices = {}
  for i = 1, 3 do slices[i] = a.sent[i].text:match("^1%^%+%^%d+%^%d+%^%d+%^(.*)$") end
  check("slices are at most 200 bytes and every chunk at most 255", #slices[1] == 200 and #slices[2] == 200
    and #a.sent[1].text <= 255)
  check("the slices join to the whole encoded message", table.concat(slices) == a.DT._comms.encode("TEST", { x = big }))
  w:advance(0)
  check("reassembled and delivered once", #got == 1 and got[1].f.x == big)
  check("nothing left partial", next(b.DT._comms.partial()) == nil)
  a.DT.send("TEST", { x = big })
  check("msgid counts up within a session", a.sent[4].text:match("^1%^%+%^" .. (id0 + 1) .. "%^1%^3%^") ~= nil)
  -- F5: the first msgid comes from the clock (time() % 100000), not 0, so a reload doesn't
  -- reuse the ids of the session before it.
  check("F5: the first msgid is time() % 100000 + 1", id0 == (a.env.time() % 100000) + 1)
  w:advance(5)
  check("the second long message arrives too", #got == 2)

  -- Out of order, and two senders interleaved, reassemble per sender and msgid.
  local whole = a.DT._comms.encode("TEST", { x = big })
  local function ch(id, i) return "1^+^" .. id .. "^" .. i .. "^3^" .. whole:sub((i - 1) * 200 + 1, i * 200) end
  inject(b, ch(9, 3), "Ghoul"); inject(b, ch(9, 1), "Wight"); inject(b, ch(9, 1), "Ghoul")
  inject(b, ch(9, 2), "Ghoul")
  check("out of order, per sender: Ghoul's set completes, Wight's waits", #got == 3
    and got[3].from == "ClassicBetaPvP-Ghoul")

  -- Stale: an incomplete set is discarded after 30 seconds.
  local stale0 = b:db().comms.stale
  inject(b, ch(11, 1), "Ghoul"); inject(b, ch(11, 2), "Ghoul")
  w:advance(31)
  inject(b, ch(11, 3), "Ghoul")
  check("a stale incomplete set is discarded, its late chunk delivers nothing", #got == 3
    and b:db().comms.stale >= stale0 + 1)
  w:advance(40)
  check("and the stray late chunk goes stale too; nothing is left", next(b.DT._comms.partial()) == nil)
  local nRefused = #a.sent
  check("a message needing more than 32 chunks is refused", a.DT.send("TEST", { x = string.rep("x", 7000) }) == false
    and #a.sent == nRefused)
end

-- ---------------------------------------------------------------- throttle
do
  local w, a = setup()
  for i = 1, 8 do a.DT.send("TEST", { n = i }) end
  check("throttle: a burst of 8 sends 5 at once", #a.sent == 5)
  w:advance(0.99)
  check("throttle: nothing more inside the first second", #a.sent == 5)
  w:advance(0.02)
  check("throttle: one more after a second", #a.sent == 6)
  w:advance(2)
  check("throttle: the rest at one a second, in order", #a.sent == 8
    and a.sent[8].text == "1^TEST^n~8" and a.sent[6].text == "1^TEST^n~6")
  w:advance(10)
  for i = 1, 5 do a.DT.send("TEST", { n = i }) end
  check("throttle: the bucket refills to 5, no more", #a.sent == 13)
end

-- ---------------------------------------------------------------- lockdown (R-1), queue cap
-- Fix round 3 (R-1): the hold is for C_ChatInfo.InChatMessagingLockdown only. These checks were
-- the "restricted: ..." checks, rewritten to the lockdown form.
do
  local w, a = setup()
  a.lockdown = true
  a.DT.send("TEST", { n = 1 })
  check("lockdown: nothing sent, the message is held", #a.sent == 0 and #a.DT._comms.queue() == 1)
  w:advance(4.9)
  check("lockdown: still held before the 5 s retry", #a.sent == 0)
  a.lockdown = false
  w:advance(0.2)
  check("lockdown: sent on the 5 s retry once lifted", #a.sent == 1)

  a.lockdown = true
  for i = 1, 55 do a.DT.send("TEST", { n = i }) end
  check("queue cap: 50 held, the 5 oldest dropped and counted", #a.DT._comms.queue() == 50
    and a:db().comms.dropped == 5)
  a.lockdown = false
  w:advance(120)
  check("queue cap: the survivors go out oldest first", #a.sent == 51 and a.sent[2].text == "1^TEST^n~6"
    and a.sent[51].text == "1^TEST^n~55")
  a.sendError = true
  local okRaise = pcall(a.DT.send, "TEST", { n = 1 })
  check("a SendAddonMessage error is counted as a refusal, never raised", okRaise
    and (a:db().comms.sendRefused or 0) == 1 and a:db().comms.lastRefusal:find("send failed", 1, true) ~= nil)
  a.sendError = false
  w:advance(2)
  check("the longest message sent is recorded", a:db().comms.longest == #"1^TEST^n~55")
end

-- ---------------------------------------------------------------- R-1: the flag never gates
do
  local w, a = setup()
  a.restricted = true
  a:login()
  check("R-1: the restricted flag is read at login and recorded (flagReads 1, flagRestricted true)",
    a:db().comms.flagReads == 1 and a:db().comms.flagRestricted == true and a.flagCalls == 1)
  a:fire("PLAYER_ENTERING_WORLD", false, false)
  check("R-1: read once per login, not on every loading screen", a:db().comms.flagReads == 1)
  a.DT.send("TEST", { n = 1 })
  check("R-1: flag true, no lockdown: the message is sent", #a.sent == 1)
  for i = 2, 9 do a.DT.send("TEST", { n = i }) end
  w:advance(10)
  check("R-1: flag true: the whole queue goes, and the pump never asked the flag", #a.sent == 9
    and a.flagCalls == 1)
  local n = w:client({ name = "Ghoul", guild = G, files = FILES, db = a:db() })
  n.restricted = false
  n:login()
  check("R-1: the next login reads it again: flagReads 2, the last reading kept", n:db().comms.flagReads == 2
    and n:db().comms.flagRestricted == false)
end
do
  local w = H.world()
  local a = w:client({ name = "Stromham", guild = G, files = FILES, lockdown = "absent" })
  a.restricted = true
  a.DT.send("TEST", { n = 1 })
  check("R-1: InChatMessagingLockdown absent: sends", #a.sent == 1)
  local b = w:client({ name = "Ghoul", guild = G, files = FILES })
  b.lockdown = "error"
  b.DT.send("TEST", { n = 1 })
  check("R-1: InChatMessagingLockdown erroring: sends", #b.sent == 1)
  b.lockdown = true
  b.DT.send("TEST", { n = 2 })
  check("R-1: lockdown true: held", #b.sent == 1 and #b.DT._comms.queue() == 1)
  w:advance(5.1)
  check("R-1: lockdown true: retried and still held", #b.sent == 1)
  b.lockdown = false
  w:advance(5)
  check("R-1: lockdown lifted: sent", #b.sent == 2 and b.sent[2].text == "1^TEST^n~2")
end

-- ---------------------------------------------------------------- the held line
do
  local w, a = setup()
  local LINE = a.DT._comms.HELD_LINE
  local function held() local n = 0 for _, m in ipairs(a.printed) do if m:find(LINE, 1, true) then n = n + 1 end end return n end
  check("held line: the brief's wording", LINE == "The dead are gagged for this fight. Your message goes when it's over.")
  a.DT.verb("shout", function() a.DT.send("TEST", { x = "1" }) end)
  a.printed = {}
  a.DT.send("TEST", { x = "auto" })
  check("held line: never for a send outside lockdown", held() == 0 and #a.sent == 1)
  a.lockdown = true
  a.DT.send("TEST", { x = "auto" })
  check("held line: never for a send the addon makes by itself", held() == 0)
  a.env.SlashCmdList.DEADTIRED("shout")
  check("held line: a typed command's message held for lockdown prints it once", held() == 1)
  a.env.SlashCmdList.DEADTIRED("shout")
  check("held line: not for the second queued message", held() == 1)
  w:advance(5.1)
  a.env.SlashCmdList.DEADTIRED("shout")
  check("held line: not again while the same hold goes on", held() == 1)
  a.lockdown = false
  w:advance(5.1)
  check("held line: the hold ends, everything goes", #a.DT._comms.queue() == 0 and #a.sent == 5)
  a.env.SlashCmdList.DEADTIRED("shout")
  check("held line: not for a command outside lockdown", held() == 1)
  a.lockdown = true
  a.env.SlashCmdList.DEADTIRED("shout")
  check("held line: a new hold prints it again", held() == 2)
end

-- ---------------------------------------------------------------- AUD-10: refused sends
do
  local w, a, b, got = setup()
  a.sendResult = 0
  a.DT.send("TEST", { n = 1 })
  check("AUD-10: return 0: sent", #a.sent == 1 and (a:db().comms.sendRefused or 0) == 0)
  a.sendResult = true
  a.DT.send("TEST", { n = 2 })
  a.sendResult = H.NIL
  a.DT.send("TEST", { n = 3 })
  check("AUD-10: return true and return nil: sent", #a.sent == 3 and (a:db().comms.sendRefused or 0) == 0)
  w:advance(10)
  a.sendResult = 5
  a.DT.send("TEST", { n = 4 })
  a.DT.send("TEST", { n = 5 })
  local q = a.DT._comms.queue()
  check("AUD-10: return 5: refused, counted, the code kept", #a.sent == 3 and #a.refused == 1
    and a:db().comms.sendRefused == 1 and a:db().comms.lastRefusal == "5")
  check("AUD-10: the refused message is still at the head of the queue", #q == 2 and q[1] == "1^TEST^n~4"
    and q[2] == "1^TEST^n~5")
  w:advance(0.9)
  check("AUD-10: nothing retried inside the 1 s wait", #a.refused == 1)
  a.sendResult = 0
  w:advance(0.2)
  check("AUD-10: retried after the wait, then sent in order", #a.sent == 5 and a.sent[4].text == "1^TEST^n~4"
    and a.sent[5].text == "1^TEST^n~5")
end
do
  local w, a = setup()
  a.sendResult = function(text) if text == "1^TEST^n~1" then return 5 end return 0 end
  a.DT.send("TEST", { n = 1 })
  a.DT.send("TEST", { n = 2 })
  w:advance(1.05)
  check("AUD-10: two refusals: still queued, still first", #a.refused == 2 and a.DT._comms.queue()[1] == "1^TEST^n~1"
    and #a.sent == 0)
  w:advance(1.05)
  check("AUD-10: the third refusal drops it and counts the drop", #a.refused == 3
    and a:db().comms.refusedDropped == 1 and a:db().comms.sendRefused == 3)
  check("AUD-10: the next message then goes", #a.sent == 1 and a.sent[1].text == "1^TEST^n~2"
    and #a.DT._comms.queue() == 0)
  a.sendResult = 7
  a.DT.send("TEST", { n = 3 })
  check("AUD-10: a new message starts its own count", a.DT._comms.refusals() == 1)
  a.sendResult = 0
  w:advance(2)
  check("AUD-10: ...and goes when the game takes it", #a.sent == 2 and a.DT._comms.refusals() == 0)
  a.sendError = true
  a.DT.send("TEST", { n = 4 })
  check("AUD-10: a raised error counts as a refusal and requeues", a:db().comms.sendRefused == 5
    and a.DT._comms.queue()[1] == "1^TEST^n~4")
  a.sendError = false
  w:advance(2)
  check("AUD-10: ...and is retried", a.sent[3].text == "1^TEST^n~4")
  a.env.Enum = { SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3 } }
  a.sendResult = 3
  a.DT.send("TEST", { n = 5 })
  check("AUD-10: with Enum present, a non-Success code is a refusal", a:db().comms.sendRefused == 6
    and a:db().comms.lastRefusal == "3")
  a.sendResult = 0
  w:advance(2)
  check("AUD-10: with Enum present, Success (0) is sent", a.sent[4].text == "1^TEST^n~5")
end

-- ---------------------------------------------------------------- unknown version, malformed
do
  local w, a, b, got = setup()
  inject(b, "2^TEST^x~future", "Ghoul")
  inject(b, "17^HELLO", "Ghoul")
  check("unknown protocol: counted, ignored", #got == 0 and b:db().comms.unknownVersion == 2)
  local bad = { "", "hello", "1", "1^", "1^test^x~1", "1^TEST^x", "1^TEST^x~1~2", "1^TEST^^x~1",
    "1^TEST^x~50%", "1^TEST^x~%G1", "1^TEST^~v", "1^TEST^x~a|b", "1^TEST^x~a\1b", "^1^TEST",
    "1^TEST1^x~1", "1^+^1^0^3^abc", "1^+^1^4^3^abc", "1^+^1^1^1^abc", "1^+^x^1^3^abc", "1^+^1^1^99^abc",
    "1^TEST" .. string.rep("^k~v", 40) }
  local ok = true
  for _, t in ipairs(bad) do ok = pcall(inject, b, t, "Ghoul") and ok end
  check("malformed input never raises", ok)
  check("malformed input is counted and delivers nothing", #got == 0 and b:db().comms.malformed == #bad)
  check("a non-string message never raises and is counted", pcall(inject, b, nil, "Ghoul")
    and b:db().comms.malformed == #bad + 1)
  check("no sender: counted as malformed", pcall(inject, b, "1^TEST^x~1", "") and b:db().comms.malformed == #bad + 2)
  -- A chunk set whose reassembled text is not a message.
  inject(b, "1^+^5^1^2^1^TE", "Ghoul"); inject(b, "1^+^5^2^2^st", "Ghoul")
  check("a reassembled message that is malformed is counted", b:db().comms.malformed == #bad + 3 and #got == 0)
  -- A fault inside parsing (here: string.char failing) is caught by the pcall, counted, never raised.
  local real = b.env.string
  b.env.string = setmetatable({ char = function() error("fault in parse") end }, { __index = string })
  local okFault = pcall(inject, b, "1^TEST^x~%41", "Ghoul")
  b.env.string = real
  check("a fault inside parsing never escapes the handler, and is counted", okFault
    and b:db().comms.malformed == #bad + 4 and #got == 0)
  inject(b, "1^TEST^x~fine", "Ghoul")
  check("a good message still gets through after all that", #got == 1 and got[1].f.x == "fine")
end

-- ---------------------------------------------------------------- the member gate
do
  local w, a, b, got = setup({ bGuild = "Alliance Spies" })
  -- b is in another guild: a's GUILD message never reaches it anyway; test the gates directly.
  check("non-member: send sends nothing and answers false", b.DT.send("TEST", { x = 1 }) == false and #b.sent == 0)
  inject(b, "1^TEST^x~1", "Ghoul")
  check("non-member: inbound is ignored", #got == 0 and b:db().comms.malformed == 0)
  b.guild = nil
  check("no guild: send sends nothing", b.DT.send("TEST", { x = 1 }) == false and #b.sent == 0)
  b.guild = G
  inject(b, "1^TEST^x~1", "Ghoul")
  check("joining the guild opens the gate", #got == 1)
end

-- ---------------------------------------------------------------- the first message's size
do
  local w, a = setup()
  local m = a.DT._comms.encode("HELLO", { v = "0.1.0", main = "Classic Beta PvP-" .. string.rep("M", 40), r = "1" })
  check("a HELLO with a 40-character main is well under 250 bytes (" .. #m .. ")", #m <= 250)
end

H.finish("comms")
