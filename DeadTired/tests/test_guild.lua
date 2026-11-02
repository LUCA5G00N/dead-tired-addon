-- Offline checks for Guild.lua.  lua5.1 DeadTired/tests/test_guild.lua  (from the repo root)
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local FILES = { "Config.lua", "Core.lua", "Guild.lua" }

local w = H.world()
local c = w:client({ guild = "DEAD TIRED", files = FILES })
local DT = c.DT
check("member: the configured guild", DT.isMember() == true)
c.guild = "Dead Tired"
check("member: case does not matter", DT.isMember() == true)
c.guild = "  dead tired  "
check("member: surrounding spaces do not matter", DT.isMember() == true)
c.guild = "Dead  Tired"
check("not a member: inner spacing still counts", DT.isMember() == false)
c.guild = "Dead Tired Alts"
check("not a member: a different guild", DT.isMember() == false)
c.guild = nil
check("not a member: no guild", DT.isMember() == false)
c.guildError = true
check("not a member: GetGuildInfo erroring", DT.isMember() == false)
c.guildError = false
local sv = {}
c.secrets[sv] = true
c.env.GetGuildInfo = function() return sv end
check("not a member: a secret guild name", DT.isMember() == false)
c.env.GetGuildInfo = nil
check("not a member: GetGuildInfo absent", DT.isMember() == false)

-- Re-checked on PLAYER_GUILD_UPDATE: the answer is live, and a change is signalled once.
local w2 = H.world()
local d = w2:client({ guild = nil, files = FILES })
local seen = {}
d.DT.listen("member", function(v) seen[#seen + 1] = v end)
check("joined later: not a member at load", d.DT.isMember() == false)
d.guild = "DEAD TIRED"
d:fire("PLAYER_GUILD_UPDATE", "player")
check("PLAYER_GUILD_UPDATE signals the join", #seen == 1 and seen[1] == true)
d:fire("PLAYER_GUILD_UPDATE", "player")
check("no signal when nothing changed", #seen == 1)
d.guild = nil
d:fire("PLAYER_GUILD_UPDATE", "player")
check("leaving is signalled", #seen == 2 and seen[2] == false and d.DT.isMember() == false)

H.finish("guild")
