-- Offline checks for Guild.lua: the guild gate (silent outside: says nothing, sends nothing, shows
-- nothing) and the welcome line.  lua5.1 DeadTired/tests/test_guild.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"

do
  local w = H.world()
  local c = w:client({ guild = "  dead tired " })
  check("member: case and surrounding spaces ignored", c.DT.isMember() == true)
  c.guild = "Dead Tired Too"
  check("another guild is not the guild", c.DT.isMember() == false)
  c.guild = nil
  check("no guild is not the guild", c.DT.isMember() == false)
end

-- ---------------------------------------------------------------- outside the guild: silent
do
  local w = H.world()
  local out = w:client({ name = "Wanderer", guild = "Some Other Guild" })
  local inG = w:client({ name = "Graverobber", guild = "Some Other Guild" })   -- same other guild, to hear
  out:login()
  w:advance(15)
  check("outside: login prints nothing (no welcome, no bar intro)", #out.printed == 0)
  out:slash("help")
  out:slash("who")
  out:slash("debug names")
  out:slash("set guild welcome off")
  check("outside: /dt says nothing", #out.printed == 0)
  check("outside: a /dt set does nothing either", out:db().settings.guild == nil)
  out.printed = {}
  check("outside: DT.out itself prints nothing", out.DT.out("Rest in Pieces") == false and #out.printed == 0)
  check("outside: DT.send refuses", out.DT.send("TEST", { x = 1 }) == false)
  w:advance(15)
  check("outside: nothing on the wire, ever", #out.sent == 0 and #out.refused == 0)
  check("outside: no bar, no viewport, no toast shown", not (out:frame("DeadTiredBar") and out:frame("DeadTiredBar").shown)
    and out:frame("DeadTiredViewport_who") == nil and out.DT.toast("guild", "welcome", "x") == false)
  -- a message from a member arrives at a non-member: ignored
  local m = w:client({ name = "Ghoul", guild = G })
  local wire = m.DT._comms.encode("HELLO", { v = "x" }, m:key())
  out:fire("CHAT_MSG_ADDON", "DEADTIRED", wire, "GUILD", m.full)
  check("outside: inbound ignored", out:db().comms.received == 0 and next(out.DT._who.session()) == nil)
end

-- ---------------------------------------------------------------- the guild arrives late
do
  local w = H.world()
  local c = w:client({ guild = nil })
  c:login()
  check("guild info not there yet: nothing said", #c.printed == 0)
  c.guild = G
  c:fire("PLAYER_GUILD_UPDATE")
  check("it arrives: the welcome, once", c:count("Rest in Pieces,") == 1)
  c:fire("PLAYER_GUILD_UPDATE")
  check("not twice", c:count("Rest in Pieces,") == 1)
end

-- ---------------------------------------------------------------- the welcome
do
  local w = H.world()
  local c = w:client({ guild = G })
  c:login()
  check("one welcome line, with the full name", c:count("Rest in Pieces,") == 1
    and c:said("Rest in Pieces, Stromham Hamson. The crypt's open. /dt for the rest."))
  c:fire("PLAYER_ENTERING_WORLD", false, false)
  check("zoning doesn't repeat it", c:count("Rest in Pieces,") == 1)
  local r = c:reload()
  check("a /reload counts as a login", r:count("Rest in Pieces,") == 1)
  r:slash("set guild welcome off")
  check("/dt set guild welcome off", r:said("guild.welcome = off") ~= nil and r:db().settings.guild.welcome == false)
  local r2 = r:reload()
  check("off: no welcome next login", r2:count("Rest in Pieces") == 0)
  check("nothing else printed unasked (bar intro was said once already)", #r2.printed == 0)
end

H.finish("guild")
