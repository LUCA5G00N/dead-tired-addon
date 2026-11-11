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
  check("with LDB: the bar hosts other addons' launchers and data sources", texts(c) == "Dead Tired | DT: 0 online | AtlasLoot | DPS 0"
    or texts(c) == "Dead Tired | DT: 0 online | DPS 0 | AtlasLoot")
  check("other LDB types left out", not texts(c):find("skip me", 1, true))
  check("DT's own LDB objects not drawn twice", select(2, texts(c):gsub("DT: 0 online", "")) == 1)
  c.DT.update("who", "text", "DT: 2 online")
  check("DT's text change reaches its LDB object (for Titan and friends)", lib:GetDataObjectByName("DeadTired_who").text == "DT: 2 online")
  lib:NewDataObject("Leatrix", { type = "launcher", text = "Leatrix" })
  check("an LDB object made later joins the bar", texts(c):find("Leatrix", 1, true) ~= nil)
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
  check("and shows the later addon's launcher", texts(c):find("BugSack", 1, true) ~= nil)
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

H.finish("bar")
