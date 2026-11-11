-- Offline checks for Skins.lua: style resolution per skin, the base fallback, LibSharedMedia fetch
-- with raw-path fallback, restyle on /dt skin.  lua5.1 DeadTired/tests/test_skins.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"

local w = H.world()
local c
local okLoad, errLoad = pcall(function() c = w:client({ guild = G }); c:login() end)
check("loads and logs in under the default skin without an error", okLoad)
if not okLoad then print("  " .. tostring(errLoad)); H.finish("skins") end
local DT = c.DT

check("two skins ship: forever and deadtired", DT.skins.forever and DT.skins.deadtired and DT.skins.forever.title == "Forever")
check("the default skin is deadtired", DT.skinName() == "deadtired")
check("colours differ by skin", DT.style("colours.bg", "deadtired")[1] ~= DT.style("colours.bg", "forever")[1])
local r, g, b = DT.colour("text", "deadtired")
check("Dead Tired text is bone, not white", r < 1 and g < 1 and b < r)
local ar, ag, ab = DT.colour("accent", "deadtired")
check("Dead Tired accent is a sickly green", ag > ar and ag > ab)
check("Forever titles are gold", select(2, DT.colour("title", "forever")) == 0.82)
check("what a skin leaves out comes from the base (forever)", DT.style("fonts.body", "deadtired") == DT.style("fonts.body", "forever")
  and DT.style("spacing.pad", "deadtired") == 14)
check("what a skin names wins", DT.style("spacing.edge", "deadtired") == 1 and DT.style("spacing.edge", "forever") == 24)
check("an unknown style path is nil, not an error", DT.style("colours.nope") == nil)

local fp, fsize = DT.font("title", "deadtired")
check("Dead Tired titles in Morpheus, through LibSharedMedia", fp == [[Fonts\MORPHEUS_CYR.TTF]] and fsize == 16)
check("Forever titles in Friz Quadrata", (DT.font("title", "forever")) == [[Fonts\FRIZQT__.TTF]])
check("a role a skin lacks falls back to body", (DT.font("nope", "forever")) == (DT.font("body", "forever")))
check("DT's own media registered with LibSharedMedia", DT.texture("background", "deadtired") == [[Interface\Buttons\WHITE8X8]]
  and c.env.LibStub("LibSharedMedia-3.0"):IsValid("border", "Dead Tired Edge"))
check("Forever backdrop: the dialog stone and border", DT.backdrop(false, "forever").bgFile == [[Interface\DialogFrame\UI-DialogBox-Background-Dark]]
  and DT.backdrop(false, "forever").edgeFile == [[Interface\DialogFrame\UI-DialogBox-Border]])
-- a key LibSharedMedia doesn't know: the raw path stands behind it
DT.skins.test = { textures = { background = { "No Such Media", [[Interface\Test\Raw]] } } }
check("an LSM key it lacks: the raw path", DT.texture("background", "test") == [[Interface\Test\Raw]])

-- restyle
local runs = 0
DT.skin(function() runs = runs + 1 end)
check("a painter runs when registered", runs == 1)
local vp = DT.viewport({ id = "skintest", title = "Skin test" })
local before = vp.frame.backdrop.edgeFile
c:slash("skin forever")
check("/dt skin forever: every painter re-runs", runs == 2)
check("a viewport redraws in the new skin", vp.frame.backdrop.edgeFile ~= before
  and vp.frame.backdrop.edgeFile == [[Interface\DialogFrame\UI-DialogBox-Border]])
check("its title font follows", vp.title.font[1] == [[Fonts\FRIZQT__.TTF]])
c:slash("skin deadtired")
check("and back", runs == 3 and vp.frame.backdrop.edgeFile == [[Interface\Buttons\WHITE8X8]]
  and vp.title.font[1] == [[Fonts\MORPHEUS_CYR.TTF]])
DT.skin(function() error("bad brush") end)
c:slash("skin forever")
check("a failing painter is counted, the others still run", runs == 4 and (c:db().errors.skin or 0) >= 1)

H.finish("skins")
