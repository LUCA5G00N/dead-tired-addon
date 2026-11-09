-- Offline checks for Core.lua (and Config.lua, DeadTired.toc).
--   lua5.1 DeadTired/tests/test_core.lua      (from the repo root)
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check

local w = H.world()
local c = w:client({ files = { "Config.lua", "Core.lua" }, load = false })
local DT, S = c.DT, c

check("Core exports ns.DT at 0.1.0 and creates no frame of its own",
  type(DT) == "table" and DT.VERSION == "0.1.0" and #c.frames == 0)
check("Config: guild, prefix, protocol", c.ns.Config.GUILD_NAME == "DEAD TIRED"
  and c.ns.Config.PREFIX == "DEADTIRED" and c.ns.Config.PROTOCOL == 1)

-- ---------------------------------------------------------------- helpers
check("try returns the call's results", select(2, DT.try(function() return 1, 2 end)) == 2)
check("try answers nothing for an absent function or an error",
  DT.try(nil) == nil and DT.try(function() error("x") end) == nil)
local secretV = {}
S.secrets[secretV] = true
check("try answers nothing for a secret first value", DT.try(function() return secretV end) == nil)
check("clean drops secrets and keeps values", DT.clean(secretV) == nil and DT.clean(5) == 5)
check("now is GetTime", DT.now() == 1000)
check("stamp is the date", DT.stamp() == "2026-11-04 23:00:00")
S.noDate = true
check("stamp falls back to time() when date fails", DT.stamp() == "1793833200")
S.noDate = false
check("build", DT.build() == "1.60.1-70245")
check("charKey is NormalisedRealm-Name (AUD-06)", DT.charKey() == "ClassicBetaPvP-Stromham")
S.name = "Unknown"
check("charKey refuses 'Unknown'", DT.charKey() == nil)
S.name = "Stromham"
local fired = false
check("after uses C_Timer", DT.after(0.5, function() fired = true end) == true)
w:advance(0.4); check("after: not yet", not fired)
w:advance(0.2); check("after: fired", fired)
DT.out("hello")
check("out prints with the Dead Tired prefix", c:said("|cff7fa650Dead Tired|r hello") ~= nil)
check("safe escapes UI codes and strips control bytes", DT.safe("a|Tx\1b") == "a||Txb")
check("safe bounds length", #DT.safe(string.rep("x", 100), 10) == 13)
check("nameOf strips the realm, even one with a hyphen", DT.nameOf("Azjol-Nerub-Bob") == "Bob"
  and DT.nameOf("Classic Beta PvP-Stromham") == "Stromham")
-- ---------------------------------------------------------------- AUD-06: one key spelling
check("AUD-06: realmKey() is GetNormalizedRealmName when it answers", DT.realmKey() == "ClassicBetaPvP")
S.normRealm = ""
check("AUD-06: realmKey() falls back to GetRealmName, spaces removed, when it answers empty",
  DT.realmKey() == "ClassicBetaPvP")
S.normRealm = false
S.realm = "CAMWOW EU4 Realm 2 PvP"
check("AUD-06: ...or nil: 'CAMWOW EU4 Realm 2 PvP' -> CAMWOWEU4Realm2PvP", DT.realmKey() == "CAMWOWEU4Realm2PvP"
  and DT.charKey() == "CAMWOWEU4Realm2PvP-Stromham")
S.realm = "Azjol-Nerub"
check("AUD-06: hyphens removed too", DT.realmKey() == "AzjolNerub" and DT.charKey() == "AzjolNerub-Stromham")
S.realm, S.normRealm = "Classic Beta PvP", nil
check("AUD-06: realmKey(realm) normalises a given realm", DT.realmKey("Argent Dawn") == "ArgentDawn"
  and DT.realmKey("ArgentDawn") == "ArgentDawn" and DT.realmKey("") == nil and DT.realmKey(5) == nil)
check("AUD-06: keyOf(name, realm) and keyOf(name) for the own realm", DT.keyOf("Bob", "Argent Dawn") == "ArgentDawn-Bob"
  and DT.keyOf("Bob") == "ClassicBetaPvP-Bob" and DT.keyOf("", "X") == nil and DT.keyOf(nil) == nil)
check("AUD-06: normKey rewrites an old key, leaves the rest", DT.normKey("Classic Beta PvP-Stromham") == "ClassicBetaPvP-Stromham"
  and DT.normKey("Azjol-Nerub-Bob") == "AzjolNerub-Bob" and DT.normKey("ArgentDawn-Bob") == "ArgentDawn-Bob"
  and DT.normKey("") == "" and DT.normKey("?") == "?" and DT.normKey(nil) == nil)
do
  local t = {
    ["Classic Beta PvP-Ann"] = { seen = "2026-11-01 10:00:00", main = "Classic Beta PvP-Ann", tag = "old" },
    ["ClassicBetaPvP-Ann"] = { seen = "2026-11-02 10:00:00", main = "ClassicBetaPvP-Ann", tag = "new" },
    ["Argent Dawn-Bea"] = { seen = "2026-11-05 10:00:00", main = "Argent Dawn-Cid", tag = "newer" },
    ["ArgentDawn-Bea"] = { seen = "2026-11-03 10:00:00", main = "", tag = "older" },
    ["Nethergarde-Cid"] = { seen = "x", main = "Argent Dawn-Cid" },
    [1] = { who = "Classic Beta PvP-Dee" },
  }
  local n, merged = DT.migrateKeys(t, { "main", "who" })
  check("AUD-06: migrateKeys rewrites keys and the named fields", t["Nethergarde-Cid"].main == "ArgentDawn-Cid"
    and t[1].who == "ClassicBetaPvP-Dee" and t["Classic Beta PvP-Ann"] == nil and t["Argent Dawn-Bea"] == nil)
  check("AUD-06: two keys collapsing into one keep the newer seen, either way round",
    t["ClassicBetaPvP-Ann"].tag == "new" and t["ArgentDawn-Bea"].tag == "newer"
    and t["ArgentDawn-Bea"].main == "ArgentDawn-Cid")
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  check("AUD-06: migrateKeys answers what it did; nothing else lost", merged == 2 and n == 6 and count == 4)
  check("AUD-06: migrateKeys again changes nothing", DT.migrateKeys(t, { "main", "who" }) == 0)
  local u = { ["Classic Beta PvP-Eve"] = { t = 5 }, ["ClassicBetaPvP-Eve"] = { t = 9 } }
  DT.migrateKeys(u, {}, "t")
  check("AUD-06: migrateKeys can compare another stamp field", u["ClassicBetaPvP-Eve"].t == 9)
end
local db = DT.db()
check("db creates DeadTiredDB with defaults", c:db() == db and db.welcome == true
  and db.comms.dropped == 0 and db.comms.malformed == 0 and db.comms.unknownVersion == 0
  and type(db.roster) == "table" and type(db.account) == "table" and type(db.errors) == "table")
db.welcome = false
check("db keeps saved values", DT.db().welcome == false)
check("AUD-06: a new store is marked migrated", db.keysV == 2)

-- ---------------------------------------------------------------- modules
local store, calls = nil, { init = 0, ev = 0 }
local fA = DT.module({
  id = "a", events = { PLAYER_MONEY = function() calls.ev = calls.ev + 1 end,
    BOOM = function() error("kaboom") end },
  init = function() calls.init = calls.init + 1; store = {} end,
  ready = function() return store end,
  errorKey = "aErrors", lastKey = "lastAError",
  slash = { alpha = function(m) S.got = "alpha:" .. m end },
})
check("module returns its own frame", fA == c.frames[1] and fA.events.ADDON_LOADED)
check("nothing registered before ADDON_LOADED", fA.events.PLAYER_MONEY == nil)
c:fire("ADDON_LOADED", "SomeOtherAddon")
check("another addon's ADDON_LOADED is ignored", calls.init == 0)
c:fire("ADDON_LOADED", "DeadTired")
check("init runs once, events registered, ADDON_LOADED dropped", calls.init == 1
  and fA.events.PLAYER_MONEY and fA.events.BOOM and not fA.events.ADDON_LOADED)
c:fire("ADDON_LOADED", "DeadTired")
check("a second ADDON_LOADED does not re-init", calls.init == 1)
c:fire("PLAYER_MONEY")
check("a handler runs when ready", calls.ev == 1)
local ok, err = pcall(c.fire, c, "BOOM")
check("a failure is re-raised", not ok and tostring(err):find("kaboom", 1, true) ~= nil)
check("and counted under the module's own key", store.aErrors == 1 and store.lastAError:find("BOOM: ", 1, true) == 1)
store = nil
c:fire("PLAYER_MONEY")
check("a handler does not run while ready answers nothing", calls.ev == 1)
local silent = 0
local fB = DT.module({ id = "b", events = { BOOM = function() silent = silent + 1; error("quiet") end } })
c:fire("ADDON_LOADED", "DeadTired")
check("with no errorKey a failure is swallowed", pcall(c.fire, c, "BOOM") and silent == 1)
check("a module with no ready always runs", fB.events.BOOM == true)

-- Fix round 1, F4: a failing init is recorded and re-raised, and the events still register.
local cStore, cRan = {}, 0
local fC = DT.module({ id = "c", events = { PLAYER_MONEY = function() cRan = cRan + 1 end },
  init = function() error("bad store") end, ready = function() return cStore end,
  errorKey = "cErrors", lastKey = "lastCError" })
local okC, errC = pcall(c.fire, c, "ADDON_LOADED", "DeadTired")
check("F4: a failing init is re-raised", not okC and tostring(errC):find("bad store", 1, true) ~= nil)
check("F4: and counted under the module's own key", cStore.cErrors == 1
  and tostring(cStore.lastCError):find("init: ", 1, true) == 1)
check("F4: its events are registered anyway, and run", fC.events.PLAYER_MONEY == true
  and not fC.events.ADDON_LOADED and (c:fire("PLAYER_MONEY") or true) and cRan == 1)

-- ---------------------------------------------------------------- signals
local got
DT.listen("x", function(a) got = a end)
DT.signal("x", 7)
check("signal reaches its listener", got == 7)

-- ---------------------------------------------------------------- the router
DT.verb("main", function(m) S.got = "main:" .. m end, "main [clear]")
DT.verb("mainland", function(m) S.got = "mainland:" .. m end)
c:slash("  Main Clear ")
check("a verb takes its arguments, the message lower-cased and trimmed", S.got == "main:main clear")
check("the raw text keeps case", DT.raw == "Main Clear")
c:slash("mainland")
check("the longest verb wins", S.got == "mainland:mainland")
S.got = nil
c:slash("mainx")
check("a verb must be a whole word", S.got == nil and c:said("/dt") ~= nil)
c:slash("alpha")
check("a module's slash table registers its verbs", S.got == "alpha:alpha")
S.got = nil
c:slash("")
check("/dt alone lists the verbs, with usage and version", S.got == nil and c:said("/dt ") and c:said("alpha")
  and c:said("main [clear]") and c:said(DT.VERSION))
check("/dt and /deadtired are declared on one router", c.env.SLASH_DEADTIRED1 == "/dt"
  and c.env.SLASH_DEADTIRED2 == "/deadtired" and type(c.env.SlashCmdList.DEADTIRED) == "function")
DT.isMember = function() return false end
S.got = nil
c:slash("alpha")
check("outside the guild the router runs nothing and says one line", S.got == nil and #c.printed == 1
  and c:said("only stirs inside <DEAD TIRED>"))

-- ---------------------------------------------------------------- files
local function read(p) local f = io.open(p, "rb"); if not f then return nil end local s = f:read("*a"); f:close(); return s end
local toc = read(H.addonDir .. "/DeadTired.toc") or ""
check("toc: interface 16001, title, SavedVariables, version", toc:find("## Interface: 16001\n", 1, true)
  and toc:find("## Title: Dead Tired\n", 1, true) and toc:find("## SavedVariables: DeadTiredDB\n", 1, true)
  and toc:find("## Version: " .. DT.VERSION .. "\n", 1, true))
check("toc: files in order", toc:find("\nConfig.lua\nCore.lua\nGuild.lua\nComms.lua\nRoster.lua\nAlts.lua\nWelcome.lua\n", 1, true) ~= nil)
local strays = {}
for _, f in ipairs(H.FILES) do
  local t = read(H.addonDir .. "/" .. f) or ""
  if f ~= "Core.lua" and (t:find("SlashCmdList") or t:find("SLASH_")) then strays[#strays + 1] = f .. ":slash" end
  -- (names split so that G3's grep over DeadTired/ finds nothing, this file included)
  if t:find("COMBAT" .. "_LOG") or t:find("Combat" .. "Log") or t:find("Send" .. "ChatMessage") then strays[#strays + 1] = f .. ":combat/chat" end
  if t:find("reference/", 1, true) then strays[#strays + 1] = f .. ":reference" end
end
check("no file but Core declares a slash command; no combat, chat or reference/ (" .. table.concat(strays, ",") .. ")", #strays == 0)

H.finish("core")
