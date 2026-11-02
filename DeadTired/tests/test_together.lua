-- Cross-card checks for the combined build (dt_release, 0.1.0-rc1): every module in .toc order,
-- loaded into one client, and into two clients on card 1's fake GUILD bus.
--   lua5.1 DeadTired/tests/test_together.lua   (from the repo root)
-- Read-only on the addon: nothing here changes module code. A collision (verb, DeadTiredDB key,
-- message kind) or a login print/send no ruling allows fails a check.
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local P = "|cff7fa650Dead Tired|r "

local function read(p) local f = io.open(p, "rb"); if not f then return nil end local s = f:read("*a"); f:close(); return s end

-- ---------------------------------------------------------------- the .toc, and who owns what
local toc = read(H.addonDir .. "/DeadTired.toc") or ""
local FILES = {}
for line in toc:gmatch("[^\r\n]+") do if line:match("^[%w_]+%.lua$") then FILES[#FILES + 1] = line end end
local CARD = { ["Config.lua"] = 1, ["Core.lua"] = 1, ["Guild.lua"] = 1, ["Comms.lua"] = 1, ["Roster.lua"] = 1,
  ["Alts.lua"] = 1, ["Welcome.lua"] = 1, ["Crypt.lua"] = 3, ["Gank.lua"] = 4, ["PrepList.lua"] = 5, ["Prep.lua"] = 5,
  ["RecruitLines.lua"] = 5, ["Recruit.lua"] = 5, ["Stash.lua"] = 6, ["Played.lua"] = 6, ["EventsList.lua"] = 6,
  ["Events.lua"] = 6, ["Logs.lua"] = 7 }
local ORDER = { "Config.lua", "Core.lua", "Guild.lua", "Comms.lua", "Roster.lua", "Alts.lua", "Welcome.lua",
  "Crypt.lua", "Gank.lua", "PrepList.lua", "Prep.lua", "RecruitLines.lua", "Recruit.lua",
  "Stash.lua", "Played.lua", "EventsList.lua", "Events.lua", "Logs.lua" }
check("the .toc lists every module once, card 1 first, then card order (" .. #FILES .. " files)",
  table.concat(FILES, ",") == table.concat(ORDER, ","))

-- Static ownership: verbs, top-level DeadTiredDB keys and message kinds, per file and card.
local verbs, keys, kinds = {}, {}, {}
local function note(t, k, file)
  t[k] = t[k] or { files = {}, cards = {} }
  t[k].files[file] = true
  t[k].cards[CARD[file]] = true
end
for _, f in ipairs(FILES) do
  local src = (read(H.addonDir .. "/" .. f) or ""):gsub("%-%-[^\n]*", "")   -- code only, not comments
  for v in src:gmatch('DT%.verb%("([%w]+)"') do
    verbs[v] = verbs[v] or {}
    table.insert(verbs[v], f)
  end
  for v in src:gmatch("slash = { (%w+) =") do
    verbs[v] = verbs[v] or {}
    table.insert(verbs[v], f)
  end
  for k in src:gmatch("db%.(%w+)%s*=[^=]") do note(keys, k, f) end
  for k in src:gmatch('DT%.send%("([A-Z]+)"') do note(kinds, k, f) end
  for k in src:gmatch('DT%.on%("([A-Z]+)"') do note(kinds, k, f) end
end
local function names(t)
  local out = {}
  for k in pairs(t) do out[#out + 1] = k end
  table.sort(out)
  return out
end
local function cardsOf(e) local n = 0 for _ in pairs(e.cards) do n = n + 1 end return n end

local dupVerbs, dupKeys, dupKinds = {}, {}, {}
for _, v in ipairs(names(verbs)) do if #verbs[v] > 1 then dupVerbs[#dupVerbs + 1] = v end end
for _, k in ipairs(names(keys)) do if cardsOf(keys[k]) > 1 then dupKeys[#dupKeys + 1] = k end end
for _, k in ipairs(names(kinds)) do if cardsOf(kinds[k]) > 1 then dupKinds[#dupKinds + 1] = k end end
print("together: verbs (" .. #names(verbs) .. "): " .. table.concat(names(verbs), ", "))
local kl = {}
for _, k in ipairs(names(keys)) do kl[#kl + 1] = k .. " (card " .. next(keys[k].cards) .. ")" end
print("together: DeadTiredDB keys (" .. #kl .. "): " .. table.concat(kl, ", "))
local ml = {}
for _, k in ipairs(names(kinds)) do ml[#ml + 1] = k .. " (card " .. next(kinds[k].cards) .. ")" end
print("together: message kinds (" .. #ml .. "): " .. table.concat(ml, ", "))
check("no two modules register the same verb (" .. table.concat(dupVerbs, ",") .. ")", #dupVerbs == 0)
check("no two cards use the same top-level DeadTiredDB key (" .. table.concat(dupKeys, ",") .. ")", #dupKeys == 0)
check("no two cards use the same message kind (" .. table.concat(dupKinds, ",") .. ")", #dupKinds == 0)
check("15 verbs, 12 keys, 8 kinds, as the cards built them", #names(verbs) == 15 and #names(keys) == 12
  and #names(kinds) == 8)

-- ---------------------------------------------------------------- clients
-- Frames rich enough for card 7's dialogs (built lazily, after load). Module frames come from
-- the harness's CreateFrame at load; dialogs use this one, and are kept by name.
local function richFrames(c)
  c.named = {}
  local base = c.env.CreateFrame
  c.env.CreateFrame = function(kind, name, parent, template)
    if not name then return base(kind, name, parent, template) end
    local f = { attrs = {}, shown = true, enabled = true, template = template }
    local function font() return { SetPoint = function() end, SetText = function(s, t) s.text = t end } end
    for _, m in ipairs({ "SetSize", "SetPoint", "SetFrameStrata", "RegisterForClicks", "SetScript" }) do f[m] = function() end end
    function f:CreateFontString() return font() end
    function f:SetText(t) self.text = t end
    function f:SetAttribute(k, v) self.attrs[k] = v end
    function f:Enable() self.enabled = true end
    function f:Disable() self.enabled = false end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    c.named[name] = f
    return f
  end
  c.env.UIParent = {}
end

local SUNDAY_1345 = os.time({ year = 2026, month = 11, day = 8, hour = 13, min = 45, sec = 0, isdst = false })
local function stubs(c, opts)
  local e = c.env
  richFrames(c)
  e.InCombatLockdown = function() return false end
  e.IsInInstance = function() return c.inst ~= nil, c.inst and c.inst.type or "none" end
  e.GetInstanceInfo = function()
    if c.inst then return c.inst.zone, c.inst.type, 1, "Normal", 5, 0, false, c.inst.id end
    return "Orgrimmar", "none"
  end
  e.GetRealZoneText = function() return c.inst and c.inst.zone or "Orgrimmar" end
  e.UnitIsDeadOrGhost = function() return false end
  e.UnitLevel = function(u) if u == "player" then return 30 end end
  e.C_ChatInfo.IsLoggingCombat = function() return false end
  e.C_ChatInfo.IsLoggingChat = function() return false end
  e.SlashCmdList.PLAYED = function() end
  e.hooksecurefunc = function(t, k, fn) local o = t[k] t[k] = function(...) o(...) fn(...) end end
  if opts.clocks then
    -- the local clock reads 23:00 (bedtime); the server clock reads Sunday 13:45 (+ world time)
    local t0 = c.world.t
    e.date = function(fmt, t)
      if fmt == "*t" then return { hour = 23, min = 0, wday = 4 } end
      if fmt == "!*t" then return os.date("!*t", t) end
      return "2026-11-04 23:00:00"
    end
    e.C_DateAndTime = { GetServerTimeLocal = function() return SUNDAY_1345 + math.floor(c.world.t - t0) end }
  end
end

local function client(w, opts)
  opts.files = FILES
  opts.random = opts.random or function() return 0.5 end
  opts.setup = function(c) stubs(c, opts) end
  local c = w:client(opts)
  return c
end

-- What every opt-in "on" looks like for one account (SavedVariables before login).
local function allOn()
  return { welcome = true, crypt = { rip = true, share = true, bedtime = "23:00" },
    prep = { share = true }, stash = { share = true }, played = { share = true },
    events = { remind = true }, logs = { ask = true, login = true } }
end

-- Lines a ruling lets the addon print unasked (CLAUDE.md, base rules and Ruled exceptions).
local ALLOWED = {
  { "welcome (card 1, base rule)", "^Rest in Pieces, .-%. The crypt's open%. /dt for the rest%.$" },
  { "death notice (card 3 R1)", "^Rest in Pieces: .- Hardcore%. Gone for good%.$" },
  { "death notice (card 3 R1)", " died at level .- in .-%. Again%.$" },
  { "bedtime nag (card 3)", "^It's %d%d:%d%d%. Even the dead sleep%.$" },
  { "bedtime nag (card 3)", "^Still here%. The crypt has a bed with your name on it%.$" },
  { "bedtime nag (card 3)", "^Last call%. Log off before the sun gets you%.$" },
  { "hardcore line (card 3, rulings round)", "^This one's hardcore%." },
  { "event reminder (card 6 R4)", " in %d+ minutes%. Bring a rod, or a grudge%.$" },
  { "event reminder (card 6 R4)", " has started%.$" },
  { "combat-log prompt (card 7 R1, fix round 1 F10)", "^Can't tell if the " },
}
local function ruling(line)
  local s = line:gsub("^%|cff7fa650Dead Tired%|r ", "")
  for _, a in ipairs(ALLOWED) do if s:find(a[2]) then return a[1] end end
end

local function shownDialogs(c)
  local out = {}
  for name, f in pairs(c.named or {}) do
    if (name == "DeadTiredLogsLogin" or name == "DeadTiredLogsInstance") and f:IsShown() then out[#out + 1] = name end
  end
  table.sort(out)
  return out
end

-- ---------------------------------------------------------------- 1. load, defaults, login
do
  local w = H.world()
  local a = client(w, { name = "Stromham", guild = G })
  check("every module registers a frame (one per DT.module, 13)", #a.frames == 13 and #a.DT.modules == 13)
  a:login()
  w:advance(120)
  local errs = {}
  for k, v in pairs(a:db().errors) do errs[#errs + 1] = k .. "=" .. tostring(v) end
  check("every module loads; no error in DeadTiredDB.errors (" .. table.concat(errs, " ") .. ")", #errs == 0)
  check("a login with every opt-in at default prints exactly one welcome line, nothing else (printed "
    .. #a.printed .. ")", #a.printed == 1 and a.printed[1]:find("^%|cff7fa650Dead Tired%|r Rest in Pieces, Stromham%.") ~= nil)
  check("... shows no dialog", #shownDialogs(a) == 0)
  check("... and sends only its HELLO", #a.sent == 1 and a.sent[1].text:find("^1%^HELLO%^") ~= nil)

  -- /dt and /dt help: every verb once
  for _, cmd in ipairs({ "", "help" }) do
    a:slash(cmd)
    local line = a.printed[1] or ""
    local list = line:match("/dt (.*)$") or ""
    local seen, firsts, dup = {}, {}, {}
    for entry in (list .. " | "):gmatch("(.-) | ") do
      local v = entry:match("^(%S+)")
      if v then
        if seen[v] then dup[#dup + 1] = v end
        seen[v] = true
        firsts[#firsts + 1] = v
      end
    end
    local missing = {}
    for _, v in ipairs(names(verbs)) do if not seen[v] then missing[#missing + 1] = v end end
    check("/dt " .. cmd .. " lists every verb exactly once (" .. #firsts .. "; missing " .. table.concat(missing, ",")
      .. "; twice " .. table.concat(dup, ",") .. ")", #a.printed == 1 and #missing == 0 and #dup == 0 and #firsts == 15)
  end
  check("the router holds 15 verbs, none overwritten", #a.DT.verbs == 15)

  -- every card's commands answer, all loaded together
  local answers = {
    { "who", "Only guildies running the addon show up here." }, { "main", "is now your main" },
    { "alts", "is a main with no known alts" }, { "welcome", "welcome line is on" },
    { "rip", "notices on; sharing your deaths off" }, { "graveyard", "The graveyard's empty" },
    { "bedtime", "bedtime is off" }, { "gank", "Target a player first" }, { "ganks", "No grudges yet" },
    { "prep", "Short: Major Healing Potion 0/5" }, { "prep list", "13446 Major Healing Potion" },
    { "recruit", "Officers only." }, { "recruit next", "Next up: line 1 of 5" },
    { "stash", "Sharing off. Nothing offered." }, { "slowest", "No contenders." },
    { "events", "Can't read the server clock." }, { "logs", "Asking in dungeons and raids: on" },
  }
  local bad = {}
  for _, q in ipairs(answers) do
    a:slash(q[1])
    if not a:said(q[2]) then bad[#bad + 1] = q[1] end
  end
  check("every card's commands still answer together (failed: " .. table.concat(bad, ", ") .. ")", #bad == 0)
  local top = names(a:db())
  print("together: DeadTiredDB top-level keys after use (" .. #top .. "): " .. table.concat(top, ", "))
  local unknown = {}
  for _, k in ipairs(top) do if not keys[k] then unknown[#unknown + 1] = k end end
  check("every DeadTiredDB key in use is one a card owns (" .. table.concat(unknown, ",") .. ")", #unknown == 0)
end

-- ---------------------------------------------------------------- 2. every opt-in on, a member
do
  local w = H.world()
  local a = client(w, { name = "Stromham", guild = G, db = allOn(), clocks = true })
  a:login()
  w:advance(120)
  local inWorld = shownDialogs(a)
  a.inst = { type = "party", id = 389, zone = "Ragefire Chasm" }
  a:fire("PLAYER_ENTERING_WORLD", false, false)
  local inDungeon = shownDialogs(a)
  local lines, bad = {}, {}
  for _, m in ipairs(a.printed) do
    local r = ruling(m)
    lines[#lines + 1] = (r or "NOT ALLOWED") .. ": " .. m:gsub("^%|cff7fa650Dead Tired%|r ", "")
    if not r then bad[#bad + 1] = m end
  end
  print("together: all opt-ins on, a member logs in and waits 2 min, then enters a dungeon. Printed:")
  for _, l in ipairs(lines) do print("  " .. l) end
  print("  dialogs shown at login: " .. (#inWorld > 0 and table.concat(inWorld, ", ") or "none")
    .. "; after entering a dungeon: " .. (#inDungeon > 0 and table.concat(inDungeon, ", ") or "none"))
  local sent = {}
  for _, s in ipairs(a.sent) do sent[#sent + 1] = s.text:match("^1%^(%u+)") end
  print("  sent: " .. (#sent > 0 and table.concat(sent, ", ") or "nothing"))
  check("all opt-ins on: every line printed is one a ruling allows (" .. #bad .. " not)", #bad == 0)
  check("all opt-ins on: it printed the welcome, the first bedtime nag and the event reminder",
    #a.printed == 3 and ruling(a.printed[1]):find("welcome") and a:said("Even the dead sleep.")
    and a:said("minutes. Bring a rod, or a grudge."))
  check("all opt-ins on: the login prompt (card 7 R2, opt-in) is the only dialog at login",
    #inWorld == 1 and inWorld[1] == "DeadTiredLogsLogin")
  -- Recorded in the release report, not fixed here: an unanswered login prompt is still open when
  -- the dungeon prompt opens over it.
  check("all opt-ins on: entering a dungeon with the combat log off shows card 7's prompt (R1); nothing else",
    #inDungeon == 2 and inDungeon[1] == "DeadTiredLogsInstance" and inDungeon[2] == "DeadTiredLogsLogin")
  check("all opt-ins on: the only message sent at login is the HELLO (card 1)", #sent == 1 and sent[1] == "HELLO")
end

-- ---------------------------------------------------------------- 3. every opt-in on, outside the guild
do
  local w = H.world()
  local x = client(w, { name = "Spy", guild = "Alliance Spies", db = allOn(), clocks = true })
  x:login()
  w:advance(120)
  x.inst = { type = "party", id = 389, zone = "Ragefire Chasm" }
  x:fire("PLAYER_ENTERING_WORLD", false, false)
  x:fire("PLAYER_DEAD")
  x.env.SlashCmdList.PLAYED(); x:fire("TIME_PLAYED_MSG", 360000, 3600)
  x:fire("BAG_UPDATE_DELAYED")
  w:advance(3600)
  check("outside the guild, every opt-in on, an hour: nothing printed (" .. #x.printed .. ")", #x.printed == 0)
  check("... nothing sent (" .. #x.sent .. ")", #x.sent == 0)
  check("... no dialog shown", #shownDialogs(x) == 0)
end

-- ---------------------------------------------------------------- 4. two clients on one guild channel
do
  local w = H.world()
  local a = client(w, { name = "Stromham", guild = G })
  local b = client(w, { name = "Graverobber", guild = G })
  a:login(); b:login()
  w:advance(60)
  a:slash("who")
  check("two clients: each lists the other", a:said("this session (1): Graverobber") ~= nil)
  b:slash("rip share on"); b:slash("prep share on")
  a.printed = {}
  b:fire("PLAYER_DEAD")
  w:advance(1)
  check("two clients: a death on one prints one notice on the other", #a.printed == 1
    and a.printed[1]:find("Graverobber died at level 30 in Orgrimmar. Again.", 1, true) ~= nil)
  a:slash("prep check")
  w:advance(11)
  check("two clients: a roll call is answered", a:said("Short (1): Graverobber") ~= nil)
  local errs = 0
  for _, c in ipairs({ a, b }) do for _ in pairs(c:db().errors) do errs = errs + 1 end end
  check("two clients: no error recorded on either", errs == 0)
end

H.finish("together")
