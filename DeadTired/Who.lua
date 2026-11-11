-- Dead Tired: Who, the walk module. Who in the guild runs Dead Tired.
--   HELLO { v, rn, login }: sent once after login (and after a /reload), and in answer to a login
--     HELLO or a WHO, at most once per 10 s, after a short random wait so answers don't pile up.
--     Shares your key (name and realm), your realm's display name and DT's version, only while
--     who.hello is on.
--   WHO { v, rn }: /dt who asks everyone once; again only after 30 s. /dt who also opens the list.
-- The list (searchable) shows each key with DT.display, its version and "this session" or "seen
-- before" (kept in DeadTiredDB.who.seen). Your own key is never listed as someone else. Only
-- guildies who run Dead Tired can show, and the window says so. The bar object reads
-- "DT: <n> online", n being the guildies heard from this session.
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local HELLO_GAP, ASK_GAP, LOGIN_WAIT = 10, 30, 5
local NOTE = "Only guildies running Dead Tired show here."
local ICON = [[Interface\Icons\Spell_Shadow_AnimateDead]]

local session = {}          -- [key] = { v, rn, t }
local lastHello, lastAsk = nil, nil
local helloDue, greeted = false, false
local vp, list, model = nil, nil, nil

local function seen()
  local db = DT.db()
  if type(db.who) ~= "table" then db.who = {} end
  if type(db.who.seen) ~= "table" then db.who.seen = {} end
  return db.who.seen
end

local function isMe(key)
  local me = DT.myKey()
  return me ~= nil and DT.sameKey(key, me)
end

function DT.whoRows()
  local rows, done = {}, {}
  local function add(key, e, here)
    if done[key] then return end
    done[key] = true
    if isMe(key) then return end                                           -- guard: self never listed
    local name = DT.display(key)
    rows[#rows + 1] = { key = key, name = name, v = DT.safe(e.v or "?", 16),
      when = here and "this session" or "seen before", search = name .. " " .. key }
  end
  for key, e in pairs(session) do add(key, e, true) end
  for key, e in pairs(seen()) do add(key, e, false) end
  table.sort(rows, function(a, b)
    if (a.when == "this session") ~= (b.when == "this session") then return a.when == "this session" end
    return a.name:lower() < b.name:lower()
  end)
  return rows
end

function DT.whoCount()
  local n = 0
  for key in pairs(session) do if not isMe(key) then n = n + 1 end end
  return n
end

local function redraw()
  DT.update("who", "text", "DT: " .. DT.whoCount() .. " online")
  if model then model:set(DT.whoRows()); list:refresh() end
end

local function record(key, d)
  if type(key) ~= "string" or isMe(key) then return end
  local v = type(d.v) == "string" and DT.safe(d.v, 16) or "?"
  local rn = type(d.rn) == "string" and DT.safe(d.rn, 40) or nil
  local r = DT.splitKey(key)
  if r and rn then DT.realmNames[r] = rn end
  session[key] = { v = v, rn = rn, t = DT.now() }
  seen()[key] = { v = v, rn = rn, last = DT.stamp() }
  redraw()
end

local function hello(login)
  if not DT.get("who", "hello") then return false end
  local t = DT.now()
  if lastHello and t - lastHello < HELLO_GAP then return false end         -- guard: hello rate limit
  lastHello = t
  return DT.send("HELLO", { v = DT.VERSION, rn = clean((try(GetRealmName))), login = login or nil })
end

local function answer()
  DT.after(1 + math.random() * 2, function() if DT.enabled("who") then hello(false) end end)
end

DT.on("HELLO", function(from, d)
  if not DT.enabled("who") then return end
  record(from, d)
  if d.login then answer() end
end)
DT.on("WHO", function(from, d)
  if not DT.enabled("who") then return end
  record(from, d)
  answer()
end)

-- /dt who: ask once (rate-limited) and open the list.
local function ask()
  if not DT.enabled("who") then return DT.out("who.enabled = off") end
  local t = DT.now()
  if not lastAsk or t - lastAsk >= ASK_GAP then                            -- guard: ask rate limit
    lastAsk = t
    DT.send("WHO", { v = DT.VERSION, rn = clean((try(GetRealmName))) })
  end
  DT.openWho()
end

function DT.openWho()
  if not DT.isMember() then return end
  if not vp then
    model = DT.listModel()
    vp = DT.viewport({ id = "who", title = "Who runs Dead Tired", search = true, width = 380, height = 400,
      onSearch = function(text) model:filter(text); list.offset = 0; list:refresh() end })
    local note = vp.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    note:SetPoint("BOTTOMLEFT", vp.frame, "BOTTOMLEFT", DT.style("spacing.pad"), 6)
    note:SetText(NOTE)
    DT.skin(function() DT.fontTo(note, "small", "muted") end)
    list = DT.list(vp.body, model, { count = 16, columns = {
      { key = "name", width = 180 }, { key = "v", width = 70, colour = "muted" }, { key = "when", width = 80, colour = "muted" } } })
  end
  model:set(DT.whoRows())
  list:refresh()
  vp:Show()
end

local function loginHello()
  if helloDue or not greeted or not DT.isMember() or not DT.enabled("who") then return end
  helloDue = true
  DT.after(LOGIN_WAIT, function() hello(true) end)
end

DT.module({
  id = "who",
  title = "Who",
  optional = true,
  switchDesc = "Who in the guild runs Dead Tired. Off, Dead Tired neither says hello nor answers.",
  settings = {
    { key = "hello", type = "bool", default = true, label = "Say hello",
      desc = "When you log in, and when a guildie asks, tells guildies running Dead Tired that you run it too. Shares your name, realm and Dead Tired version." },
  },
  verbs = { { verb = "who", usage = "who", fn = ask } },
  ldb = { type = "data source", text = "DT: 0 online", icon = ICON,
    OnClick = function(_, which) if which == "RightButton" then DT.openSettings("who") else DT.openWho() end end,
    OnTooltipShow = function(tt) tt:AddLine("Who runs Dead Tired"); tt:AddLine(NOTE, 1, 1, 1) end },
  onEnable = function() loginHello() end,
})

-- After the welcome (Guild.lua: once per login, inside the guild), the login hello.
DT.listen("greeted", function() greeted = true; loginHello() end)

DT._who = { NOTE = NOTE, session = function() return session end, record = record,
  reset = function() lastHello, lastAsk = nil, nil end }
