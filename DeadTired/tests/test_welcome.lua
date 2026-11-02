-- Offline checks for Welcome.lua.  lua5.1 DeadTired/tests/test_welcome.lua  (from the repo root)
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"

local function welcomes(c)
  local n = 0
  for _, m in ipairs(c.printed) do if m:find("Rest in Pieces", 1, true) then n = n + 1 end end
  return n
end

-- A member: exactly one line, at the first PLAYER_ENTERING_WORLD.
local w = H.world()
local db = {}
local a = w:client({ guild = G, db = db })
check("nothing printed at load", #a.printed == 0)
a:login()
check("one welcome line at login", welcomes(a) == 1 and #a.printed == 1
  and a:said("|cff7fa650Dead Tired|r Rest in Pieces, Stromham.") ~= nil)
a:fire("PLAYER_ENTERING_WORLD", false, false)
a:fire("PLAYER_GUILD_UPDATE", "player")
w:advance(120)
check("once per login: zoning and guild updates print nothing more", welcomes(a) == 1)
check("quiet by default: nothing else printed unasked, even after the HELLO", #a.printed == 1)

-- The toggle, and that it persists across a /reload (a new instance on the same SavedVariables).
a:slash("welcome off")
check("/dt welcome off", db.welcome == false and a:said("buried") ~= nil)
a:logout()
local a2 = w:client({ guild = G, db = db })
a2:fire("PLAYER_ENTERING_WORLD", false, true)
check("off persists across a reload: no welcome", welcomes(a2) == 0 and #a2.printed == 0)
a2:slash("welcome")
check("/dt welcome reports the state", a2:said("welcome line is off") ~= nil)
a2:slash("welcome on")
check("/dt welcome on", db.welcome == true and a2:said("exhumed") ~= nil)
a2:logout()
local a3 = w:client({ guild = G, db = db })
a3:fire("PLAYER_ENTERING_WORLD", false, true)
check("on persists: the welcome is back after a reload", welcomes(a3) == 1)

-- Not a member: no welcome, ever.
local x = w:client({ name = "Spy", guild = "Alliance Spies" })
x:login(); w:advance(60)
x:fire("PLAYER_GUILD_UPDATE", "player")
check("another guild: no welcome, nothing printed at all", #x.printed == 0)
local y = w:client({ name = "Loner", guild = nil })
y:login(); w:advance(60)
check("no guild: nothing printed at all", #y.printed == 0)
y:slash("welcome off")
check("outside the guild, /dt answers one line and changes nothing", #y.printed == 1
  and y:said("only stirs inside") ~= nil and y:db().welcome == true)

-- Guild info late at login: the welcome waits for membership, then shows once.
local late = w:client({ name = "Latecomer", guild = nil })
late:login()
check("guild info late: no welcome yet", welcomes(late) == 0)
late.guild = G
late:fire("PLAYER_GUILD_UPDATE", "player")
check("guild info late: the welcome when membership arrives", welcomes(late) == 1)
late.guild = nil; late:fire("PLAYER_GUILD_UPDATE", "player")
late.guild = G; late:fire("PLAYER_GUILD_UPDATE", "player")
check("and still only once", welcomes(late) == 1)

-- Membership before entering the world prints nothing early.
local early = w:client({ name = "Early", guild = nil })
early.guild = G
early:fire("PLAYER_GUILD_UPDATE", "player")
check("no welcome before entering the world", welcomes(early) == 0)
early:login()
check("then exactly one", welcomes(early) == 1)

H.finish("welcome")
