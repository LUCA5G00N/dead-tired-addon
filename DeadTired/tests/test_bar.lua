-- Offline checks for Bar.lua: DT's own buttons with and without a borrowed LibDataBroker-1.1; a
-- third-party LDB object shown; no copy of LibDataBroker in DeadTired/; stand-back for a display
-- addon; the intro once only; /dt bar on|off; drag and keep.  lua5.1 DeadTired/tests/test_bar.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local INTRO = "DeadTired's bar has risen. /dt bar off to bury it."

local function texts(c)
  local out = {}
  for _, b in ipairs(c.DT._bar.buttons()) do if b.shown and b.entry then out[#out + 1] = b.text.text end end
  return table.concat(out, " | ")
end

-- ---------------------------------------------------------------- without LibDataBroker
do
  local w = H.world()
  local c
  local okLogin, errLogin = pcall(function() c = w:client({ guild = G }); c:login() end)
  check("no LDB: loads and logs in without an error", okLogin)
  if not okLogin then print("  " .. tostring(errLogin)); H.finish("bar") end
  local bar = c:frame("DeadTiredBar")
  check("no LDB: the bar shows DT's own buttons, drawn natively", bar and bar.shown and texts(c) == "Dead Tired | DT: 0 online")
  check("no LDB: nothing errors", #c.errors == 0 and next(c:db().errors) == nil)
  check("no LDB: DT never creates LibDataBroker-1.1", c.env.LibStub("LibDataBroker-1.1", true) == nil
    and c.env.LibStub.libs["LibDataBroker-1.1"] == nil)
  check("the intro line, once, on the first login", c:count(INTRO) == 1 and c:db().barIntroSaid == true)
  c.DT.update("who", "text", "DT: 3 online")
  check("an object's text change redraws its button", texts(c):find("DT: 3 online", 1, true) ~= nil)
  -- left-click opens, right-click its settings
  local whoBtn
  for _, b in ipairs(c.DT._bar.buttons()) do if b.entry and b.entry.name == "who" then whoBtn = b end end
  whoBtn.scripts.OnClick(whoBtn, "LeftButton")
  check("left-click the Who button: the Who viewport", c:frame("DeadTiredViewport_who").shown)
  whoBtn.scripts.OnClick(whoBtn, "RightButton")
  check("right-click: its settings", c:frame("DeadTiredViewport_settings").shown)
  whoBtn.scripts.OnEnter(whoBtn)
  local tt = c:frame("DeadTiredTooltip")
  check("its tooltip is DT's own tooltip frame", tt and tt.lines and tt.lines[1] == "Who runs Dead Tired")
  -- drag and keep
  bar.scripts.OnDragStart(bar)
  bar:ClearAllPoints(); bar:SetPoint("BOTTOMLEFT", c.env.UIParent, "BOTTOMLEFT", 40, 30)
  bar.scripts.OnDragStop(bar)
  check("dragged by a button too", whoBtn.scripts.OnDragStop ~= nil)
  local r = c:reload()
  local p = r:frame("DeadTiredBar").points[1]
  check("after /reload: where it was left", p[1] == "BOTTOMLEFT" and p[4] == 40 and p[5] == 30)
  check("after /reload: no intro again", r:count(INTRO) == 0 and r:frame("DeadTiredBar").shown)
end

-- ---------------------------------------------------------------- with LibDataBroker, loaded by another addon first
do
  local w = H.world()
  local lib
  local c = w:client({ guild = G, afterLibs = function(c0)
    lib = H.fakeLDB(c0)
    lib:NewDataObject("AtlasLoot", { type = "launcher", text = "AtlasLoot", icon = "x",
      OnClick = function(_, b) c0.atlasClicked = b end })
    lib:NewDataObject("Recount", { type = "data source", text = "DPS 0" })
    lib:NewDataObject("Weird", { type = "something else", text = "skip me" })
  end })
  c:login()
  check("with LDB: DT's objects registered there too", lib:GetDataObjectByName("DeadTired_who") ~= nil
    and lib:GetDataObjectByName("DeadTired_DeadTired") ~= nil)
  check("R-P4: other addons' objects are listed but unticked: the bar shows DT's own only",
    texts(c) == "Dead Tired | DT: 0 online" and #c.DT.barList() == 5)
  c:slash("bar add AtlasLoot"); c:slash("bar add recount")
  check("with LDB: ticked, the bar hosts other addons' launchers and data sources", texts(c) == "Dead Tired | DT: 0 online | AtlasLoot | DPS 0"
    or texts(c) == "Dead Tired | DT: 0 online | DPS 0 | AtlasLoot")
  check("other LDB types left out", not texts(c):find("skip me", 1, true))
  check("DT's own LDB objects not drawn twice", select(2, texts(c):gsub("DT: 0 online", "")) == 1)
  c.DT.update("who", "text", "DT: 2 online")
  check("DT's text change reaches its LDB object (for Titan and friends)", lib:GetDataObjectByName("DeadTired_who").text == "DT: 2 online")
  lib:NewDataObject("Leatrix", { type = "launcher", text = "Leatrix" })
  local bl = c.DT.barList()
  check("R-P4: an LDB object made later is listed at the bottom, unticked", bl[#bl].name == "Leatrix" and not bl[#bl].on
    and texts(c):find("Leatrix", 1, true) == nil)
  c:slash("bar add leatrix")
  check("an LDB object made later joins the bar once ticked", texts(c):find("Leatrix", 1, true) ~= nil)
  lib:GetDataObjectByName("Recount").text = "DPS 9000"
  check("another addon's text change redraws", texts(c):find("DPS 9000", 1, true) ~= nil)
  local atlas
  for _, b in ipairs(c.DT._bar.buttons()) do if b.entry and b.entry.name == "AtlasLoot" then atlas = b end end
  atlas.scripts.OnClick(atlas, "RightButton")
  check("a click on another addon's button reaches its OnClick with the button", c.atlasClicked == "RightButton")
  check("nothing errors", #c.errors == 0)
end

-- ---------------------------------------------------------------- LibDataBroker arriving after DT
do
  local w = H.world()
  local c = w:client({ guild = G })
  c:login()
  local lib = H.fakeLDB(c)
  lib:NewDataObject("BugSack", { type = "launcher", text = "BugSack" })
  c:fire("ADDON_LOADED", "BugSack")
  check("LDB loaded by a later addon: DT binds then, registers its objects", lib:GetDataObjectByName("DeadTired_who") ~= nil)
  c:slash("bar add BugSack")
  check("and shows the later addon's launcher once ticked", texts(c):find("BugSack", 1, true) ~= nil)
end

-- ---------------------------------------------------------------- stand-back
do
  local w = H.world()
  local c = w:client({ guild = G, addons = { Titan = true } })
  c:login()
  local bar = c:frame("DeadTiredBar")
  check("Titan Panel loaded: DT's bar stands back", not (bar and bar.shown))
  check("standing back: no intro", c:count(INTRO) == 0 and not c:db().barIntroSaid)
  check("the display addon is named", c.DT.displayAddon() == "Titan")
  c:slash("bar on")
  bar = c:frame("DeadTiredBar")
  check("/dt bar on: shown anyway", bar and bar.shown and c:said("bar.mode = on"))
  check("and the intro then, once", c:count(INTRO) == 1)
  c:slash("bar off")
  check("/dt bar off: buried", not bar.shown and c:said("bar.mode = off") and c:db().settings.bar.mode == "off")
  c:slash("bar on")
  check("on again: no second intro", bar.shown and c:count(INTRO) == 0)
  c:slash("bar auto")
  check("/dt bar auto: stands back again for Titan", not bar.shown)
  c:slash("bar sideways")
  check("/dt bar <nonsense>: says the mode and the choices", c:said("bar.mode = auto. /dt bar on|off|auto") ~= nil)
end

for _, name in ipairs({ "ChocolateBar", "Bazooka" }) do
  local w = H.world()
  local c = w:client({ guild = G, addons = { [name] = true } })
  c:login()
  check("stands back for " .. name, not (c:frame("DeadTiredBar") and c:frame("DeadTiredBar").shown))
end

do
  local w = H.world()
  local c = w:client({ guild = G, addons = { AtlasLoot = true, DBM = true } })
  c:login()
  check("ordinary addons loaded: the bar stays", c:frame("DeadTiredBar").shown)
end

do
  local w = H.world()
  local c = w:client({ guild = G, db = { schema = 3, settings = { bar = { mode = "off" } } } })
  c:login()
  check("saved off: not built, no intro", c:frame("DeadTiredBar") == nil and c:count(INTRO) == 0)
end

-- ---------------------------------------------------------------- no copy of LibDataBroker (or LibDBIcon) in DeadTired/
do
  local p = io.popen('find "' .. H.addonDir .. '" -path "*/tests" -prune -o -type f -print')
  local named, inside = {}, {}
  for path in p:lines() do
    if path:lower():find("databroker", 1, true) or path:lower():find("dbicon", 1, true) then named[#named + 1] = path end
    local f = io.open(path, "rb")
    local body = f and f:read("*a") or ""
    if f then f:close() end
    if body:find('NewLibrary%(%s*"LibDataBroker') or body:find('NewLibrary%(%s*"LibDBIcon') then inside[#inside + 1] = path end
  end
  p:close()
  check("no LibDataBroker or LibDBIcon file in DeadTired/", #named == 0)
  check("no file in DeadTired/ creates LibDataBroker or LibDBIcon", #inside == 0)
  if #named + #inside > 0 then print("  " .. table.concat(named, ", ") .. " " .. table.concat(inside, ", ")) end
  local toc = io.open(H.addonDir .. "/DeadTired.toc"):read("*a")
  check("the .toc loads neither", not toc:find("DataBroker", 1, true) or toc:find("never bundled", 1, true) and not toc:find("LibDataBroker%-1%.1%.lua"))
end

-- ---------------------------------------------------------------- outside the guild
do
  local w = H.world()
  local c = w:client({ guild = "Elsewhere" })
  c:login()
  check("outside the guild: no bar", not (c:frame("DeadTiredBar") and c:frame("DeadTiredBar").shown) and #c.printed == 0)
end

-- ---------------------------------------------------------------- Port 1: R-P4, the bar list
do
  local w = H.world()
  local lib
  local c = w:client({ guild = G, afterLibs = function(c0) lib = H.fakeLDB(c0) end })
  c:login()
  -- made after DT bound the library, so they arrive in this order (the iterator's order is pairs')
  lib:NewDataObject("AtlasLoot", { type = "launcher", text = "AtlasLoot" })
  lib:NewDataObject("Prat-3.0", { type = "launcher", label = "Prat", text = "|cff8080ff3.0|r" })
  lib:NewDataObject("BugSack", { type = "data source", text = "0 bugs" })
  local DT = c.DT
  local function order() local o = {} for _, e in ipairs(DT.barList()) do o[#o + 1] = e.name .. (e.on and "+" or "-") end return table.concat(o, " ") end
  check("R-P4: unticked by default: every other addon's object, DT's own ticked, Session waits",
    order() == "DeadTired+ who+ session- AtlasLoot- Prat-3.0- BugSack-")
  check("R-P4: the bar shows the ticked ones only", texts(c) == "Dead Tired | DT: 0 online")
  -- tick from the settings card
  c:slash("settings")
  local card
  for _, r in ipairs(DT._settingsView.rows()) do if r.setting and r.setting.key == "objects" then card = r end end
  check("R-P4: the bar's settings card lists every object, in order", card and #card.subs == 6 and card.subs[4].label.text == "AtlasLoot"
    and card.subs[1].grip ~= nil and card.subs[1].tick ~= nil)
  local sub = card.subs[4]
  sub.tick:SetChecked(true); sub.tick.scripts.OnClick(sub.tick)
  check("R-P4: tick adds it to the bar", texts(c) == "Dead Tired | DT: 0 online | AtlasLoot")
  -- typed verbs
  c:slash("bar add prat")
  check("R-P4: /dt bar add <label> ticks it", texts(c):find("Prat", 1, true) == nil and DT.barList()[5].on
    and c:said("bar.Prat-3.0 = on"))
  check("colour codes: another addon's colour code is shown, not escaped", texts(c):find("|cff8080ff3.0|r", 1, true) ~= nil
    and texts(c):find("||cff", 1, true) == nil)
  c:slash("bar remove AtlasLoot")
  check("R-P4: /dt bar remove unticks it", texts(c) == "Dead Tired | DT: 0 online | |cff8080ff3.0|r" and c:said("bar.AtlasLoot = off"))
  c:slash("bar add nothing-here")
  check("R-P4: an unknown name says so", c:said("bar.list: no nothing-here") ~= nil)
  -- move: the model
  DT.barMove("Prat-3.0", 1)
  check("R-P4 move: to position 1", order():sub(1, 9) == "Prat-3.0+" and texts(c):sub(1, 14) == "|cff8080ff3.0|")
  DT.barMove("Prat-3.0", 2)
  check("R-P4 move: down one", order() == "DeadTired+ Prat-3.0+ who+ session- AtlasLoot- BugSack-")
  DT.barMove("Prat-3.0", 1)
  check("R-P4 move: up one", order() == "Prat-3.0+ DeadTired+ who+ session- AtlasLoot- BugSack-")
  DT.barMove("who", 99)
  check("R-P4 move: past the end goes last", order() == "Prat-3.0+ DeadTired+ session- AtlasLoot- BugSack- who+")
  c:slash("bar move who 2")
  check("R-P4: /dt bar move <name> <n>", order() == "Prat-3.0+ who+ DeadTired+ session- AtlasLoot- BugSack-" and c:said("bar.who at 2"))
  check("R-P4: the bar follows the order", texts(c) == "|cff8080ff3.0|r | DT: 0 online | Dead Tired")
  c:slash("bar list")
  check("R-P4: /dt bar list (Port 2: names, not live text)", c:said("bar.list: 1 Prat (Prat-3.0) [on], 2 Who [on], 3 Dead Tired (DeadTired) [on]") ~= nil)
  -- drag: the grip, dropped over row 1
  c:slash("settings")
  for i, sb in ipairs(card.subs) do sb.GetBottom = function() return 500 - i * 22 end end
  c.env.GetCursorPosition = function() return 0, 470 end          -- inside the second row
  local grip
  for _, sb in ipairs(card.subs) do if sb.item and sb.item.name == "BugSack" then grip = sb.grip end end
  grip.scripts.OnDragStart(grip); grip.scripts.OnDragStop(grip)
  check("R-P4 drag: a row dragged by its grip lands where it's dropped", order() == "Prat-3.0+ BugSack- who+ DeadTired+ session- AtlasLoot-")
  -- Session ticked on
  c:slash("bar add session")
  check("R-P4: Session can be ticked on", texts(c):find("Session 0:00", 1, true) ~= nil)
  -- saved
  local r = c:reload()
  -- the other addons load again and make their objects again (in another order this time)
  lib:NewDataObject("BugSack", { type = "data source", text = "0 bugs" })
  lib:NewDataObject("AtlasLoot", { type = "launcher", text = "AtlasLoot" })
  lib:NewDataObject("Prat-3.0", { type = "launcher", label = "Prat", text = "|cff8080ff3.0|r" })
  local o2 = {}
  for _, e in ipairs(r.DT.barList()) do o2[#o2 + 1] = e.name .. (e.on and "+" or "-") end
  check("R-P4: order and ticks saved through /reload", table.concat(o2, " ") == "Prat-3.0+ BugSack- who+ DeadTired+ session+ AtlasLoot-")
  check("nothing errors", #c.errors == 0 and #r.errors == 0)
end

-- ---------------------------------------------------------------- Port 2: names, not live text; the grab hand
do
  local w = H.world()
  local lib
  local cursor = {}
  local c = w:client({ guild = G, afterLibs = function(c0) lib = H.fakeLDB(c0) end, setup = function(c0)
    rawset(c0.env, "C_GuildInfo", { IsGuildOfficer = function() return true end })
    rawset(c0.env, "SetCursor", function(p) cursor[#cursor + 1] = "set:" .. tostring(p) end)
    rawset(c0.env, "ResetCursor", function() cursor[#cursor + 1] = "reset" end)
  end })
  c:login()
  lib:NewDataObject("BugSack", { type = "data source", text = "0" })
  lib:NewDataObject("Prat-3.0", { type = "launcher", label = "Prat", text = "|cff8080ff3.0|r" })
  local DT = c.DT
  DT.update("recruit", "text", "Recruit 8:23")
  DT.update("session", "text", "Session 1:05")
  DT.update("who", "text", "DT: 3 online")
  local labels = {}
  for _, it in ipairs(DT.setting("bar", "objects").items()) do labels[#labels + 1] = it.label end
  local L = table.concat(labels, ",")
  check("Port 2: the list names each object, never its live text (BugSack, not 0; Recruit, not Recruit 8:23)",
    L == "Dead Tired,Who,Recruit,Session,BugSack,Prat")
  c:slash("settings")
  local card
  for _, r in ipairs(DT._settingsView.rows()) do if r.setting and r.setting.key == "objects" then card = r end end
  local shown = {}
  for _, sb in ipairs(card.subs) do if sb.item then shown[#shown + 1] = sb.label.text end end
  check("Port 2: the settings card shows the names", table.concat(shown, ",") == L)
  c:slash("bar list")
  check("Port 2: /dt bar list shows the names", c:said("bar.list: 1 Dead Tired (DeadTired) [on], 2 Who [on], 3 Recruit [on], 4 Session [off], 5 BugSack [off], 6 Prat (Prat-3.0) [off]") ~= nil)
  check("Port 2: the bar itself still shows the live text", (function()
    for _, b in ipairs(DT._bar.buttons()) do if b.shown and b.entry and b.entry.name == "recruit" then return b.text.text == "Recruit 8:23" end end
  end)())
  c:slash("bar add bugsack")
  check("Port 2: typed by its name", c:said("bar.BugSack = on") ~= nil)
  c:slash("bar remove 0")
  check("Port 2: not by its text", c:said("bar.list: no 0") ~= nil)
  -- the grab hand (the Port 1 walk's request 3)
  c:slash("settings")
  local grip = card.subs[5].grip
  grip.scripts.OnDragStart(grip)
  check("Port 2: dragging a row by its grip shows the grab hand", cursor[1] == "set:Interface\\CURSOR\\openhand")
  grip.scripts.OnDragStop(grip)
  check("Port 2: dropping it puts the cursor back", cursor[2] == "reset")
  rawset(c.env, "SetCursor", nil); rawset(c.env, "ResetCursor", nil)
  local ok = pcall(function() grip.scripts.OnDragStart(grip); grip.scripts.OnDragStop(grip) end)
  check("Port 2: a client without SetCursor/ResetCursor: the drag still works, no error", ok and #c.errors == 0)
end

-- ---------------------------------------------------------------- colour codes (fw1 walk defect 3)
do
  local w = H.world()
  local c = w:client({ guild = G })
  local T = c.DT.barText
  check("barText: a colour code and |r pass", T("|cff8080ff3.0|r") == "|cff8080ff3.0|r")
  check("barText: an open colour is closed", T("|cffff0000red") == "|cffff0000red|r")
  check("barText: a texture passes", T("|TInterface\\Icons\\x:16|t 5") == "|TInterface\\Icons\\x:16|t 5")
  check("barText: a hyperlink passes", T("|Hitem:1|h[Thing]|h") == "|Hitem:1|h[Thing]|h")
  check("barText: any other escape is escaped", T("a|Kq1|kb") == "a||Kq1||kb" and T("|cffxyz") == "||cffxyz")
  check("barText: control bytes go", T("a\nb") == "ab")
  check("barText: long text cut, codes don't count", T("|cff00ff00" .. string.rep("x", 50), 40) == "|cff00ff00" .. string.rep("x", 40) .. "...|r")
  check("DT's own text still goes through DT.safe", c.DT.safe("|cff") == "||cff")
end

H.finish("bar")
