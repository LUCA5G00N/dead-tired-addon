-- Dead Tired: the crypt. "Rest in Pieces" death notices, the graveyard, the bedtime nag.
-- Card 3 (docs/COWORK_BRIEF_dt_crypt.md on card/dt_crypt; R1-R3 ratified 2026-11-02), ported from
-- rc3's Crypt.lua onto the framework in Port 1. Logic and lines are rc3's; what changed: full-name
-- keys, settings declared as cards (crypt.rip, crypt.share, crypt.bedtime) with their /dt verbs,
-- the graveyard in a searchable viewport, names without realm (R-P5), one store DeadTiredDB.crypt.
--
-- No combat data: PLAYER_DEAD says only that you died. Level and zone are read from game state
-- afterwards. Nothing names a killer, and nothing here reads the death recap.
-- R1: guildies' death notices print unasked (one line each, /dt rip off silences them).
-- R2, amended 2026-11-02 (rulings round, A2): your own death, hardcore or not, is sent only
-- after /dt rip share on. A hardcore member with share never set is told so once per character.
-- Battleground rule: a death in a battleground or arena never counts as hardcore.
local ADDON, ns = ...
local DT = ns.DT
local try, clean = DT.try, DT.clean

local DEATH_WINDOW = 60      -- seconds: at most one death handled per window
local CAP = 100              -- deaths kept
local ZONE_MAX = 48
local TICK = 60              -- bedtime ticker, seconds
local NIGHT = 360            -- minutes after bedtime the nag may fire
local NAG_GAP = 30           -- minutes between nags
local NAGS = {
  "It's %s. Even the dead sleep.",
  "Still here. The crypt has a bed with your name on it.",
  "Last call. Log off before the sun gets you.",
}
local CLOSING = "Only guildies running the addon, and only deaths seen while you were online."
local HC_LINE = "This one's hardcore. If it falls, the guild won't hear unless you /dt rip share on."
local EMPTY = "The graveyard's empty. Give it time."
local ICON = [[Interface\Icons\Spell_Shadow_RaiseDead]]

-- ---------------------------------------------------------------- the store

local function crypt()
  local db = DT.db()
  if type(db.crypt) ~= "table" then db.crypt = {} end
  local c = db.crypt
  if type(c.deaths) ~= "table" then c.deaths = {} end
  if type(c.badDeath) ~= "number" then c.badDeath = 0 end
  if type(c.hcTold) ~= "table" then c.hcTold = {} end
  return c
end
DT.crypt = crypt
function DT.deaths() return crypt().deaths end

-- This session's counts, for the Session object (Session.lua).
DT.cryptSession = { mine = 0, heard = 0 }

local redraw

local function record(e)
  local list = crypt().deaths
  list[#list + 1] = e
  while #list > CAP do table.remove(list, 1) end                       -- guard: memorial cap
  if redraw then redraw() end
  DT.signal("death", e)
end

-- share as the player set it: true, false, or nil when never set (A2's hardcore line).
local function shareSet()
  local s = DT.db().settings.crypt
  if type(s) ~= "table" then return nil end
  return s.share
end

-- ---------------------------------------------------------------- own death

local function isHardcore()
  return (try(C_GameRules and C_GameRules.IsHardcoreActive)) == true
end

local function level()
  local l = clean(try(UnitLevel, "player"))
  if type(l) ~= "number" or l < 1 or l > 100 or l ~= math.floor(l) then return 0 end
  return l
end

local function zone()
  local z = clean(try(GetRealZoneText))
  if type(z) ~= "string" or z == "" then return "somewhere" end
  return z:sub(1, ZONE_MAX)
end

local lastDeath

local function onDead()
  if not DT.isMember() then return end                                 -- guard: member check
  local t = DT.now()
  if lastDeath and t - lastDeath < DEATH_WINDOW then return end        -- guard: death window
  lastDeath = t
  local lvl, z, hc = level(), zone(), isHardcore()
  local itype = clean(select(2, try(IsInInstance)))
  if itype == "pvp" or itype == "arena" then hc = false end            -- guard: battleground rule
  DT.cryptSession.mine = DT.cryptSession.mine + 1
  record({ who = DT.myKey() or "?", lvl = lvl, zone = z, hc = hc, at = DT.stamp(), mine = true })
  if DT.get("crypt", "share") == true then                             -- guard: sent only when share is on (A2)
    DT.send("DEATH", { lvl = tostring(lvl), zone = z, hc = hc and "1" or "0" })
  end
end

-- ---------------------------------------------------------------- received deaths

local function lvlText(l) return (l and l > 0) and tostring(l) or "??" end

-- lvl "0" is accepted as "level unknown": it is what a sender whose UnitLevel failed sends.
local function valid(f)
  local lvl = type(f.lvl) == "string" and f.lvl:match("^%d%d?%d?$") and tonumber(f.lvl)
  return lvl and lvl <= 100 and type(f.zone) == "string" and #f.zone >= 1 and #f.zone <= ZONE_MAX
    and (f.hc == "0" or f.hc == "1")
end

-- Fix round 1 (F6a): at most one received DEATH per sender per 60 s, whatever the sender's
-- client does. Over the limit: counted in crypt.dropped, not recorded, not printed.
local lastFrom = {}

DT.on("DEATH", function(from, f)
  if not DT.enabled("crypt") then return end
  local c = crypt()
  if not valid(f) then c.badDeath = c.badDeath + 1 return end          -- guard: field validation
  local t = DT.now()
  if lastFrom[from] and t - lastFrom[from] < DEATH_WINDOW then          -- guard: per-sender limit (F6a)
    c.dropped = (c.dropped or 0) + 1
    return
  end
  lastFrom[from] = t
  local lvl, hc = tonumber(f.lvl), f.hc == "1"
  DT.cryptSession.heard = DT.cryptSession.heard + 1
  record({ who = from, lvl = lvl, zone = f.zone, hc = hc, at = DT.stamp(), mine = false })
  if not DT.get("crypt", "rip") then return end                        -- guard: rip toggle
  local who, z = DT.display(from), DT.safe(f.zone, ZONE_MAX)
  if hc then
    DT.out("Rest in Pieces: " .. who .. ", level " .. lvlText(lvl) .. ", " .. z .. ". Hardcore. Gone for good.")
  else
    DT.out(who .. " died at level " .. lvlText(lvl) .. " in " .. z .. ". Again.")
  end
end)

-- ---------------------------------------------------------------- the graveyard (a viewport)

-- Rows, newest first: day, name (R-P5 among the graveyard), level, zone (HC).
function DT.graveRows()
  local list, keys = crypt().deaths, {}
  for _, e in ipairs(list) do if type(e) == "table" then keys[#keys + 1] = e.who end end
  local name = DT.namer(keys)
  local rows = {}
  for i = #list, 1, -1 do
    local e = list[i]
    if type(e) == "table" then
      local day = type(e.at) == "string" and (e.at:match("^(%d%d%d%d%-%d%d%-%d%d)") or e.at) or "?"
      local n = name(e.who)
      local z = DT.safe(e.zone, ZONE_MAX) .. (e.hc and " (HC)" or "")
      rows[#rows + 1] = { key = e.who, day = DT.safe(day, 20), name = n, lvl = lvlText(e.lvl), zone = z,
        search = table.concat({ day, n, tostring(e.who), lvlText(e.lvl), z }, " ") }
    end
  end
  return rows
end

local vp, list, model

redraw = function()
  if model then model:set(DT.graveRows()); list:refresh() end
end

function DT.graveyard()
  if not DT.isMember() then return end
  if not vp then
    model = DT.listModel()
    vp = DT.viewport({ id = "crypt", title = "Rest in Pieces", search = true, width = 440, height = 400, footer = 16,
      onSearch = function(text) model:filter(text); list.offset = 0; list:refresh() end })
    local note = vp.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    note:SetPoint("BOTTOMLEFT", vp.frame, "BOTTOMLEFT", DT.style("spacing.pad"), 6)
    note:SetText(CLOSING)
    vp.note = note
    DT.skin(function() DT.fontTo(note, "small", "muted") end)
    list = DT.list(vp.body, model, { count = 16,
      empty = function(m) if #m.rows == 0 then return EMPTY end end,
      tip = function(row, tt) tt:AddLine(DT.safe(DT.nameOf(row.key), 48)); tt:AddLine(DT.realmLabel(row.key), 1, 1, 1) end,
      columns = { { key = "day", width = 76, colour = "muted" }, { key = "name", width = 130 },
        { key = "lvl", width = 24, colour = "muted" }, { key = "zone", width = 150, colour = "muted" } } })
  end
  model:set(DT.graveRows())
  list:refresh()
  vp:Show()
end

-- ---------------------------------------------------------------- verbs

local function ripVerb(args)
  local w = (args or ""):lower():gsub("%s+", " ")
  if w == "share on" then DT.set("crypt", "share", true); return DT.out("your deaths will be shared. Every last one.")
  elseif w == "share off" then DT.set("crypt", "share", false); return DT.out("your deaths stay between you and the spirit healer.")
  elseif w == "on" then DT.set("crypt", "rip", true); return DT.out("notices on. You'll hear about every fall.")
  elseif w == "off" then DT.set("crypt", "rip", false); return DT.out("notices off. Let the dead bury the dead.")
  elseif w == "" then
    local s = DT.get("crypt", "share") == true and "on" or "off"
    DT.out("notices " .. (DT.get("crypt", "rip") and "on" or "off") .. "; sharing your deaths " .. s .. ".")
    return DT.graveyard()
  end
  return DT.out("/dt rip on/off, or /dt rip share on/off")
end

local function bedtimeVerb(args)
  local arg = (DT.trim(args) or ""):lower()
  local bt = DT.get("crypt", "bedtime")
  if arg == "" then
    return DT.out(bt ~= "off" and ("bedtime is " .. bt .. ".") or "bedtime is off. /dt bedtime HH:MM to set one.")
  end
  if arg == "off" then
    DT.set("crypt", "bedtime", "off")
    return DT.out("bedtime off. Stay up forever; you're dead anyway.")
  end
  local ok, v = DT.set("crypt", "bedtime", arg)
  if not ok then return DT.out("/dt bedtime HH:MM (24-hour), or /dt bedtime off") end
  return DT.out("bedtime set for " .. v .. ". You'll be told.")
end

local function bedtimeValid(v)
  v = (DT.trim(v) or ""):lower()
  if v == "" or v == "off" then return true, "off" end
  local h, m = v:match("^(%d%d?):(%d%d)$")
  h, m = tonumber(h), tonumber(m)
  if not h or h > 23 or m > 59 then return false, "expects HH:MM (24-hour) or off" end
  return true, string.format("%02d:%02d", h, m)
end

-- ---------------------------------------------------------------- the nag

local shown, lastM = 0, 0

local function tick()
  if not DT.isMember() then return end
  local bt = DT.get("crypt", "bedtime")
  if type(bt) ~= "string" then return end
  local bh, bm = bt:match("^(%d%d):(%d%d)$")
  if not bh then return end
  local now = clean(try(date, "*t"))
  if type(now) ~= "table" or type(now.hour) ~= "number" or type(now.min) ~= "number" then return end
  local m = ((now.hour * 60 + now.min) - (tonumber(bh) * 60 + tonumber(bm))) % 1440
  if m >= NIGHT then shown = 0 return end                              -- guard: 6-hour window
  if shown >= #NAGS then return end                                    -- guard: 3-nag cap
  if shown > 0 and m - lastM < NAG_GAP then return end
  shown, lastM = shown + 1, m
  DT.out(string.format(NAGS[shown], string.format("%02d:%02d", now.hour, now.min)))
end

local function loop()
  if DT.enabled("crypt") then
    local ok, err = pcall(tick)
    if not ok then DT.fail("crypt", "bedtime", err) end
  end
  DT.after(TICK, loop)
end

-- ---------------------------------------------------------------- the hardcore line (A2)

-- Once per character, ever: a hardcore member whose share was never set is told how to share.
local entered, looping = false, false

local function hcLine()
  if not entered or not DT.isMember() or not DT.enabled("crypt") then return end
  if shareSet() ~= nil or not isHardcore() then return end
  local me = DT.myKey()
  local c = crypt()
  if not me or c.hcTold[me] then return end                            -- guard: once per character
  c.hcTold[me] = true
  DT.out(HC_LINE)
end

DT.listen("greeted", function() hcLine() end)
DT.listen("member", function(isMember) if isMember then hcLine() end end)

DT.keySource(function()
  local out = {}
  for _, e in ipairs(crypt().deaths) do if type(e) == "table" then out[#out + 1] = e.who end end
  return out
end)

DT.module({
  id = "crypt",
  title = "Rest in Pieces",
  optional = true,
  switchDesc = "Death notices, the graveyard and the bedtime nag. Off, Dead Tired neither hears nor shares deaths.",
  settings = {
    { key = "rip", type = "bool", default = true, label = "Death notices", verb = "rip on|off",
      desc = "Prints one line, unasked, when a guildie running Dead Tired dies and shares it. Off: still kept in the graveyard, nothing printed." },
    { key = "share", type = "bool", default = false, label = "Share my deaths", verb = "rip share on|off",
      desc = "Tells guildies running Dead Tired when you die: your level, the zone, and whether it was hardcore. Nothing else. Off until you switch it on, hardcore included." },
    { key = "bedtime", type = "string", default = "off", maxLen = 5, label = "Bedtime", verb = "bedtime HH:MM|off",
      validate = bedtimeValid,
      desc = "Once set (24-hour HH:MM), up to three nudges in chat from that time, 30 minutes apart. Off by default." },
  },
  verbs = {
    { verb = "rip", usage = "rip [share] on/off", fn = ripVerb },
    { verb = "graveyard", usage = "graveyard", fn = function() DT.graveyard() end },
    { verb = "bedtime", usage = "bedtime HH:MM/off", fn = bedtimeVerb },
  },
  init = function() crypt() end,
  events = {
    PLAYER_DEAD = onDead,
    PLAYER_ENTERING_WORLD = function()
      if entered then return end
      entered = true
      if not looping then looping = true; DT.after(TICK, loop) end
      hcLine()
    end,
  },
})

-- For the offline tests only.
DT._crypt = { tick = tick, nags = function() return shown end, NAGS = NAGS, CLOSING = CLOSING, HC_LINE = HC_LINE,
  EMPTY = EMPTY, onDead = onDead, vp = function() return vp end, list = function() return list end }
