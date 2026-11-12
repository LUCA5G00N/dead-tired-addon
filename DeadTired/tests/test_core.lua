-- Offline checks for Core.lua: the module registry, verbs, help, the module switch, error counting,
-- the store (schema 3, legacy move), and the router's globals.  lua5.1 DeadTired/tests/test_core.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"

-- ---------------------------------------------------------------- registry and help
do
  local w = H.world()
  local c = w:client({ guild = G })
  local DT = c.DT
  local ids = {}
  for _, m in ipairs(DT.modules) do ids[#ids + 1] = m.id end
  check("modules registered in .toc order", table.concat(ids, ",") == "guild,comms,core,ui,settingsview,bar,debug,who,alts,crypt,recruit,prep,session,gank,played,stash,events,logs,migrate")
  check("each module has its own frame", DT.byId.who.frame ~= DT.byId.bar.frame and DT.byId.who.frame ~= nil)
  local help = DT.helpLine()
  local missing = {}
  for _, v in ipairs(DT.verbs) do if not help:find(v.usage, 1, true) then missing[#missing + 1] = v.verb end end
  check("help lists every registered verb", #missing == 0 and #DT.verbs >= 10)
  DT.verb({ verb = "zombie", usage = "zombie walk", fn = function() end })
  check("help is built from the registry: a new verb shows", DT.helpLine():find("zombie walk", 1, true) ~= nil)
  c:slash("")
  check("/dt alone prints the help line", c:count("/dt ") == 1 and c:said("Dead Tired 0.3.1:"))
  c:slash("nonsense verb")
  check("an unknown verb prints the help line", c:said("Dead Tired 0.3.1:") ~= nil)
  local got
  DT.verb({ verb = "debug", usage = "debug", fn = function(a) got = "debug:" .. a end })
  DT.verb({ verb = "echo", usage = "echo", fn = function(a) got = a end })
  c:slash("ECHO Hello There")
  check("args keep their case; the verb matches any case", got == "Hello There")
  c:slash("debug names")
  check("the longest verb wins (debug names over debug)", got ~= "debug:names" and c:said("player: UnitName") ~= nil)
  c:slash("/dt? help")
  check("/deadtired is the same router", c.env.SLASH_DEADTIRED2 == "/deadtired" and c.env.SLASH_DEADTIRED1 == "/dt")
end

-- ---------------------------------------------------------------- the module switch
local function withTestModule(db, extra)
  local w = H.world()
  local c = w:client({ guild = G, db = db, load = false })
  local calls = { enable = 0, disable = 0, ev = 0 }
  c.DT.module({ id = "t", title = "Test", optional = true, settings = extra,
    events = { TEST_EVENT = function() calls.ev = calls.ev + 1 end },
    onEnable = function() calls.enable = calls.enable + 1 end, onDisable = function() calls.disable = calls.disable + 1 end })
  c:fire("ADDON_LOADED", "DeadTired")
  return w, c, calls
end

do
  local w, c, calls = withTestModule()
  local f = c.DT.byId.t.frame
  check("an optional module gets an enabled switch, on by default", c.DT.setting("t", "enabled") and c.DT.enabled("t"))
  check("on: its events are registered", f.events.TEST_EVENT == true and calls.enable == 1)
  c:slash("set t enabled off")
  check("/dt set t enabled off: events unregistered, onDisable ran", f.events.TEST_EVENT == nil and calls.disable == 1)
  c:fire("TEST_EVENT")
  check("off: its handler never runs", calls.ev == 0)
  c:slash("set t enabled on")
  c:fire("TEST_EVENT")
  check("on again: registered and running", f.events.TEST_EVENT == true and calls.ev == 1)
  check("the switch is saved", c:db().settings.t.enabled == true)
end

do
  local w, c, calls = withTestModule({ schema = 3, settings = { t = { enabled = false } } })
  local f = c.DT.byId.t.frame
  local n = 0
  for _ in pairs(f.events) do n = n + 1 end
  check("a module saved off registers no events at load", n == 0 and calls.enable == 0)
end

-- ---------------------------------------------------------------- error counting
do
  local w = H.world()
  local c = w:client({ guild = G, load = false })
  local DT = c.DT
  DT.module({ id = "bad", events = { BOOM = function() error("bones") end } })
  DT.module({ id = "badinit", init = function() error("no crypt") end, events = { LATER = function() end } })
  local afterRan = false
  DT.module({ id = "after", init = function() afterRan = true end, events = { AFTER = function() end } })
  local okLoad, errLoad = pcall(c.fire, c, "ADDON_LOADED", "DeadTired")
  check("a failing init is re-raised after every module loaded", not okLoad and tostring(errLoad):find("no crypt", 1, true))
  check("a failing init is counted under its module", c:db().errors.badinit == 1
    and c:db().errors["badinit:last"]:find("init: ", 1, true))
  check("the failing module's events are registered anyway", DT.byId.badinit.frame.events.LATER == true)
  check("a module after the failing one still inits and registers", afterRan and DT.byId.after.frame.events.AFTER == true)
  check("every other module still loaded", DT.byId.who.loaded == true and DT.byId.who.active and DT.byId.bar.frame.events.PLAYER_LOGIN)
  local ok, err = pcall(c.fire, c, "BOOM")
  check("a handler failure is re-raised", not ok and tostring(err):find("bones", 1, true))
  check("and counted under the module's own error key", c:db().errors.bad == 1 and c:db().errors["bad:last"]:find("BOOM", 1, true))
  pcall(c.fire, c, "BOOM")
  check("each failure counts", c:db().errors.bad == 2)
  DT.verb({ verb = "crash", usage = "crash", module = "bad", fn = function() error("verb broke") end })
  local okv = pcall(c.slash, c, "crash")
  check("a verb failure is counted and re-raised", not okv and c:db().errors.bad == 3)
  check("DT.inCommand is cleared after a failing verb", DT.inCommand == false)
end

-- ---------------------------------------------------------------- the store
do
  local w = H.world()
  local c = w:client({ guild = G })
  local db = c:db()
  check("a fresh store is schema 3 with its tables", db.schema == 3 and type(db.errors) == "table"
    and type(db.settings) == "table" and type(db.frames) == "table" and db.legacy == nil)
  c:login()
  check("no old-records line without old records", not c:said("old crypt records"))
end

do
  local old = { roster = { ["DEAD TIRED"] = { ["CAMWOWEU4Realm2PvP-Stromham"] = { seen = 1 } } }, welcome = true,
    keysV = 2, errors = { comms = 1 }, account = { main = "x" } }
  local w = H.world()
  local c = w:client({ guild = G, db = old })
  local db = c:db()
  check("an rc3 store is moved under legacy, the same table, untouched", db.schema == 3 and db.legacy == old
    and old.roster["DEAD TIRED"]["CAMWOWEU4Realm2PvP-Stromham"].seen == 1 and old.keysV == 2 and old.schema == nil
    and old.legacy == nil and old.settings == nil)
  check("the new store holds no rc3 tables at its top", db.roster == nil and db.account == nil and db.welcome == nil)
  c:login()
  check("the old-records line, once, on the first login", c:count("Your old crypt records are kept for the move.") == 1)
  local c2 = c:reload()
  check("not again after a reload", c2:count("old crypt records") == 0 and c2:db().legacy == old)
  check("a schema-3 store is left as it is", c2:db().schema == 3 and c2:db().legacySaid == true)
end

do
  local w = H.world()
  local c = w:client({ guild = G, db = {} })
  check("an empty old store is not called legacy", c:db().schema == 3 and c:db().legacy == nil)
end

-- ---------------------------------------------------------------- globals
do
  local w = H.world()
  local before = {}
  local c = w:client({ guild = G, setup = function(c0) before.slash = rawget(c0.env, "SlashCmdList") end })
  local bad = {}
  for _, name in ipairs(c:ownWrites()) do if not H.ownGlobal(name) then bad[#bad + 1] = name end end
  check("DT's files write only DT's own globals at load", #bad == 0)
  if #bad > 0 then print("  wrote: " .. table.concat(bad, ", ")) end
  check("SlashCmdList itself is never reassigned", rawget(c.env, "SlashCmdList") == before.slash)
  local keys = {}
  for k in pairs(before.slash) do keys[#keys + 1] = k end
  check("only SlashCmdList.DEADTIRED is added", #keys == 1 and keys[1] == "DEADTIRED")
end

H.finish("core")
