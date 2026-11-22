-- Offline checks for Selftest.lua (dt_selftest, R-F8-1, R-F8-2): every S-check passes on a healthy
-- client and each fails on a client broken for it; S3 fails on a "" realm with no fallback; the record
-- is written, capped and overwritten; nothing else saved; switches restored; nothing sent.
--   lua5.1 DeadTired/tests/test_selftest.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"

-- The .toc's Version line, read from the file (S1 compares the client's answer with DT.VERSION).
local TOC_VERSION
for line in io.lines(H.addonDir .. "/DeadTired.toc") do
  TOC_VERSION = TOC_VERSION or line:match("^## Version: *(%S+)")
end

-- Fill in, as do-nothing stubs, the REQUIRED functions the harness doesn't provide, and give C_AddOns
-- a GetAddOnMetadata that reads the .toc (version = override, when given).
local function healthy(c, version)
  local env = c.env
  for _, name in ipairs(c.DT.REQUIRED) do
    local ns, fn = name:match("^([%w_]+)%.([%w_]+)$")
    if ns then
      local t = rawget(env, ns)
      if type(t) ~= "table" then t = {}; rawset(env, ns, t) end
      if type(t[fn]) ~= "function" then t[fn] = function() return nil end end
    elseif type(env[name]) ~= "function" then
      rawset(env, name, function() return nil end)
    end
  end
  rawget(env, "C_AddOns").GetAddOnMetadata = function(addon, field)
    if addon == "DeadTired" and field == "Version" then return version or TOC_VERSION end
  end
end

local function mk(w, o)
  o = o or {}
  local c = w:client({ name = "Stromham", full = "Stromham Hamson", realm = o.realm or "CAMWOW EU4 Realm 2 PvP",
    guild = (o.guild ~= false) and G or nil, db = o.db, random = function() return 0.5 end, setup = o.setup })
  healthy(c, o.version)
  return c
end

local function up(o)
  local w = H.world()
  local c = mk(w, o)
  c:login(); w:advance(10)
  return w, c
end

local function line(c, id)
  for _, l in ipairs(c:db().selftest.lines) do if l:sub(1, #id + 1) == id .. " " then return l end end
end
local function passed(c, id) local l = line(c, id); return l ~= nil and l:find(": pass - ", 1, true) ~= nil end
local function failed(c, id) local l = line(c, id); return l ~= nil and l:find(": FAIL - ", 1, true) ~= nil end

local function copy(t)
  if type(t) ~= "table" then return t end
  local o = {}
  for k, v in pairs(t) do o[k] = copy(v) end
  return o
end
local function same(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do if not same(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end
local function ghostly(t, depth)
  depth = depth or 0
  for k, v in pairs(t) do
    if type(k) == "string" and k:find("DTGHOST", 1, true) then return true end
    if type(v) == "string" and v:find("DTGHOST", 1, true) then return true end
    if type(v) == "table" and depth < 12 and ghostly(v, depth + 1) then return true end
  end
  return false
end

local IDS = { "S1", "S3", "S4", "S5", "S6", "S7", "S8", "S9", "S10", "S11" }

-- ---------------------------------------------------------------- healthy: every check passes
do
  local w, c = up()
  local sent0, wire0 = #c.sent, #w.wire
  c:slash("selftest")
  local rec = c:db().selftest
  check("healthy: one summary line, 10 passed, 0 failed", c:said("Self-test: 10 passed, 0 failed. /reload to keep the record.") ~= nil
    and #c.printed == 1)
  for _, id in ipairs(IDS) do check("healthy: " .. id .. " passes", passed(c, id)) end
  check("healthy: S2 recorded as information", line(c, "S2"):find(": info - build 70245, interface 16001", 1, true) ~= nil)
  check("the record: version, build, interface, key, source", rec.version == "0.3.7" and rec.build == "70245"
    and rec.interface == 16001 and rec.key == c:key() and rec.source == "game" and rec.pass == 10 and rec.fail == 0
    and #rec.lines == 11 and type(rec.at) == "string")
  check("healthy: the .toc and DT.VERSION agree (G1)", TOC_VERSION == c.DT.VERSION)
  w:advance(30)
  check("nothing sent by a run (S8/S11 never reach the wire)", #c.sent == sent0 and #w.wire == wire0)
  check("no DTGHOST left in DeadTiredDB after a run", not ghostly(c:db()))
  check("not in Who's list after a run; the bar at 0", c.DT.whoCount() == 0)
  -- nothing else saved; overwritten each run
  local snap = copy(c:db()); snap.selftest = nil
  local first = rec
  c:slash("selftest")
  local now = copy(c:db()); now.selftest = nil
  check("a run saves nothing but its record", same(snap, now))
  check("the record is overwritten, not added to", c:db().selftest ~= first and #c:db().selftest.lines == 11)
  check("switches restored after a run", c.DT.enabled("crypt") and c.DT.enabled("who") and c.DT.out("x") == true)
  check("help lists selftest", c.DT.helpLine():find("selftest", 1, true) ~= nil)
end

-- ---------------------------------------------------------------- the first run saves no setting
do
  local w, c = up()
  local before = copy(c:db().settings)
  c:slash("selftest")
  check("no setting written by a run", same(before, c:db().settings))
end

-- ---------------------------------------------------------------- lines capped at 100
do
  local w, c = up()
  local CH = c.DT._selftest.CHECKS
  for i = 1, 120 do CH[#CH + 1] = { id = "X" .. i, name = "extra", fn = function() return true, "" end } end
  c:slash("selftest")
  check("lines capped at 100", #c:db().selftest.lines == 100 and c:db().selftest.pass == 130)
end

-- ---------------------------------------------------------------- each check can fail
do -- S1
  local w, c = up({ version = "0.3.4" })
  c:slash("selftest")
  check("S1 fails when the .toc disagrees", failed(c, "S1") and c:said("S1 version: FAIL") ~= nil
    and c:said("Self-test: 9 passed, 1 failed.") ~= nil)
end
do -- S3: a client like 21 Nov's, with no fallback (no GUID, nothing remembered)
  local w, c = up({ realm = "" })
  c:slash("selftest")
  check("S3 fails on a \"\" realm with no fallback", failed(c, "S3") and c:db().selftest.key == nil
    and line(c, "S3"):find("no key", 1, true) ~= nil)
end
do -- S3 passes once 0.3.4's fallback has a server ID
  local w, c = up({ realm = "", setup = function(c) rawset(c.env, "UnitGUID", function(u)
    if u == "player" then return "Player-6842-001FEF8D" end end) end })
  c:slash("selftest")
  check("S3 passes on a \"\" realm with the server-ID fallback", passed(c, "S3") and c:db().selftest.source == "server-id")
end
do -- S4
  local w, c = up()
  rawset(c.env, "UnitLevel", nil)
  c:slash("selftest")
  check("S4 fails with one API removed, naming it", failed(c, "S4") and line(c, "S4"):find("missing UnitLevel", 1, true) ~= nil)
end
do -- S5
  local w, c = up()
  c.DT.byId.who.loaded = false
  c:slash("selftest")
  check("S5 fails on a module not loaded", failed(c, "S5") and line(c, "S5"):find("who", 1, true) ~= nil)
end
do -- S5 and S6 on an init failure
  local w, c = up()
  c.DT.fail("crypt", "init", "boom")
  c:slash("selftest")
  check("S5 fails on an init failure this session", failed(c, "S5") and line(c, "S5"):find("crypt", 1, true) ~= nil)
  check("S6 fails on it too, naming the module", failed(c, "S6") and line(c, "S6"):find("crypt 1", 1, true) ~= nil)
end
do -- S6
  local w, c = up()
  c.DT.fail("bar", "OnEvent", "boom")
  c:slash("selftest")
  check("S6 fails on an error this session", failed(c, "S6") and line(c, "S6"):find("bar 1", 1, true) ~= nil
    and passed(c, "S5"))
end
do -- S7: a text that overflows its box
  local w, c = up()
  c.DT.module({ id = "zz", title = "Overflow", fit = function()
    local f = CreateFrame and CreateFrame("Frame") end })
  local realFit = c.DT.fitFaults
  c.DT.fitFaults = function()
    local faults, n, k = realFit()
    faults[#faults + 1] = { window = "zz", kind = "label", text = "far too long", measured = 300, box = 100 }
    return faults, n + 1, k
  end
  c:slash("selftest")
  check("S7 fails when a text doesn't fit", failed(c, "S7") and line(c, "S7"):find("over", 1, true) ~= nil)
end
do -- S8: a handler that ignores its switch (prints), and one that sends
  local w, c = up()
  c.DT.on("DEATH", function() if true then c.DT.out("I ignore my switch") end end)
  c.DT.on("GANK", function() c.DT.send("GANK", { who = "A-B", cls = "MAGE", lvl = "1", zone = "Z" }) end)
  c:slash("selftest")
  local l = line(c, "S8") or ""
  check("S8 fails on a handler that prints with its module off", failed(c, "S8") and l:find("DEATH printed", 1, true) ~= nil)
  check("S8 fails on a handler that sends with its module off", l:find("GANK sent GANK", 1, true) ~= nil)
  check("S8: the loud handler's line never reached chat", c:said("I ignore my switch") == nil)
  w:advance(30)
  check("S8: nothing reached the wire", #w.wire == 0 or (function()
    for _, m in ipairs(w.wire) do
      local ok, p = c.DT._comms.decode(m.text)
      if ok == "ok" and p.k == "GANK" then return false end
    end
    return true end)())
  check("S8: switches restored afterwards", c.DT.enabled("crypt") and c.DT.enabled("gank"))
end
do -- S8: a check that errors still restores the switches and DT.out
  local w, c = up()
  local realEnabled, realOut = c.DT.enabled, c.DT.out
  local realDeliver = c.DT.ghostDeliver
  c.DT.ghostDeliver = function() error("boom") end
  c:slash("selftest")
  c.DT.ghostDeliver = realDeliver
  check("an erroring check fails, and is reported as an error", failed(c, "S8") and line(c, "S8"):find("error: ", 1, true) ~= nil)
  check("switches and DT.out restored after an error", c.DT.enabled == realEnabled and c.DT.out == realOut)
end
do -- S9: a flag missing; a cap exceeded
  local w, c = up()
  c:db().migrated.skin031 = nil
  c:slash("selftest")
  check("S9 fails on a migration flag missing", failed(c, "S9") and line(c, "S9"):find("migrated.skin031", 1, true) ~= nil)
  local w2, c2 = up()
  local d = c2.DT.crypt().deaths
  for i = 1, 101 do d[#d + 1] = { who = "A-B", lvl = 1, zone = "Z" } end
  c2:slash("selftest")
  check("S9 fails on a list over its cap", failed(c2, "S9") and line(c2, "S9"):find("crypt.deaths 101/100", 1, true) ~= nil)
  local w3, c3 = up({ db = { schema = 3 } })
  c3:db().schema = 4                                    -- saved by a newer DT (an older one is moved aside)
  c3:slash("selftest")
  check("S9 fails on the wrong schema", failed(c3, "S9") and line(c3, "S9"):find("schema 4", 1, true) ~= nil)
end
do -- S10
  local w, c = up()
  local C = c.DT._comms
  local realDecode = C.decode
  C.decode = function(text)
    local r, p = realDecode(text)
    if r == "ok" and p.k == "PLAYED" then p.d.h = "1.0" end
    return r, p
  end
  c:slash("selftest")
  C.decode = realDecode
  check("S10 fails when a payload changes in transit", failed(c, "S10") and line(c, "S10"):find("PLAYED", 1, true) ~= nil)
end
do -- S11: never heard; heard but not purged
  local w, c = up()
  local realRows = c.DT.whoRows
  c.DT.whoRows = function() return {} end
  c:slash("selftest")
  c.DT.whoRows = realRows
  check("S11 fails when the ghost never reaches Who", failed(c, "S11") and line(c, "S11"):find("never reached", 1, true) ~= nil)
  local w2, c2 = up()
  local realPurge = c2.DT.ghostPurge
  c2.DT.ghostPurge = function() return 0 end
  c2:slash("selftest")
  c2.DT.ghostPurge = realPurge
  check("S11 fails when the purge leaves the ghost listed", failed(c2, "S11") and line(c2, "S11"):find("still listed", 1, true) ~= nil)
end
do -- S11 forces Who on for its run, even when the player has switched it off
  local w, c = up()
  c:slash("set who enabled off")
  c:slash("selftest")
  check("S11 passes with Who switched off, and Who stays off", passed(c, "S11") and not c.DT.enabled("who"))
end

-- ---------------------------------------------------------------- R-F10-1, R-F10-2 (0.3.6): ui:font is information
do -- the client refuses the gothic font at load and on every repaint (as Tim's did, 22 Nov): S6 passes, twice
  local Frame = H.Frame
  local real, n = Frame.SetFont, 0
  Frame.SetFont = function(self, p, size, fl)
    real(self, p, size, fl)
    if p == [[Fonts\MORPHEUS_CYR.TTF]] then n = n + 1; return false end
  end
  local w, c = up()
  c:slash("selftest")
  local first = c:said("Self-test: 10 passed, 0 failed.") ~= nil
  local l1 = line(c, "S6") or ""
  local refusedInRun = n
  c:slash("selftest")
  Frame.SetFont = real
  check("R-F10-1 ui:font refused at load: S6 passes, noting it", first and passed(c, "S6")
    and l1:find("none this session; ui:font 1 (known, not counted)", 1, true) ~= nil)
  check("R-F10-2 a second run in the same session: 10 passed again", c:said("Self-test: 10 passed, 0 failed.") ~= nil
    and passed(c, "S6") and refusedInRun > 1)
  check("R-F10-2 the run's own refusals are not in the next run's note", (line(c, "S6") or ""):find("ui:font 1 (known", 1, true) ~= nil)
  check("R-F10-3 the run's own refusals are still saved", (c:db().errors["ui:font"] or 0) > 1)
end
do -- any other id still fails S6, naming only that id
  local w, c = up()
  c.DT.fail("ui:font", "title", "refused")
  c.DT.fail("bar", "OnEvent", "boom")
  c:slash("selftest")
  local l = line(c, "S6") or ""
  check("R-F10-1 another id with ui:font: S6 fails, naming the other id", failed(c, "S6") and l:find("FAIL - bar 1", 1, true) ~= nil
    and l:find("ui:font 1 (known, not counted)", 1, true) ~= nil)
end
do -- an error recorded during a run (any id) doesn't fail the next run
  local w, c = up()
  local CH = c.DT._selftest.CHECKS
  table.insert(CH, { id = "X1", name = "noisy", fn = function() c.DT.fail("crypt", "paint", "during"); return true, "" end })
  c:slash("selftest")
  c:slash("selftest")
  check("R-F10-2 an error recorded during a run: the next run's S6 passes", passed(c, "S6")
    and (c:db().errors.crypt or 0) == 2)
  table.remove(CH)
  c.DT.fail("crypt", "paint", "after")
  c:slash("selftest")
  check("R-F10-2 ...but one recorded after the run fails S6 as before", failed(c, "S6") and line(c, "S6"):find("crypt 1", 1, true) ~= nil)
end

-- ---------------------------------------------------------------- gates
do
  local w, c = up({ guild = false })
  c:slash("selftest")
  check("outside the guild: nothing printed, nothing recorded", #c.printed == 0 and c:db().selftest == nil)
  c.DT.byId.selftest.verbs[1].fn("")                        -- past the router's own gate: the verb's gate
  check("outside the guild: the verb itself records nothing", c:db().selftest == nil)
end
do
  local w, c = up()
  c:slash("set selftest enabled off")
  c:slash("selftest")
  check("switched off: says so, nothing recorded", c:said("selftest.enabled = off") ~= nil and c:db().selftest == nil)
end

H.finish("selftest")
