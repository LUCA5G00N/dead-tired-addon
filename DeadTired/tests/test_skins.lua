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

check("three skins ship: clean, deadtired and forever", DT.skins.forever and DT.skins.deadtired and DT.skins.clean
  and DT.skins.forever.title == "Forever")
-- fix round 4 (R-F4-3)
check("R-F4-3: the default skin is clean (a fresh account, nothing saved)", DT.skinName() == "clean"
  and DT.get("core", "skin") == "clean")
check("R-F4-3: clean is shown as \"Dead Tired\", deadtired as \"Dead Tired Gothic\"", DT.skins.clean.title == "Dead Tired"
  and DT.skins.deadtired.title == "Dead Tired Gothic")
local same = true
for _, part in ipairs({ "colours", "textures", "spacing" }) do
  for k in pairs(DT.skins.deadtired[part]) do
    if DT.style(part .. "." .. k, "clean") ~= DT.style(part .. "." .. k, "deadtired") then same = false end
  end
end
check("R-F4-3: clean has deadtired's colours, textures and spacing", same)
check("R-F4-3: clean names no fonts: the game's Friz Quadrata throughout, titles included", DT.skins.clean.fonts == nil
  and (DT.font("title", "clean")) == [[Fonts\FRIZQT__.TTF]] and (DT.font("body", "clean")) == [[Fonts\FRIZQT__.TTF]]
  and (DT.font("small", "clean")) == [[Fonts\FRIZQT__.TTF]])
check("R-F4-3: the gothic skin keeps its Morpheus titles", (DT.font("title", "deadtired")) == [[Fonts\MORPHEUS_CYR.TTF]])
local sk = DT.setting("core", "skin")
check("R-F4-3: choices clean, deadtired, forever; typed /dt skin clean|deadtired|forever",
  table.concat(sk.choices, ",") == "clean,deadtired,forever" and sk.verb == "skin clean|deadtired|forever")
check("R-F4-8: the skin card's description", sk.desc == "How every Dead Tired window and the bar look: Dead Tired (the guild's colours, plain lettering), Dead Tired Gothic (the same, with gothic titles) or Forever (the game's stone and metal).")
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
c:slash("skin clean")
check("R-F4-3: /dt skin clean: the guild's edges, plain titles", runs == 4 and vp.frame.backdrop.edgeFile == [[Interface\Buttons\WHITE8X8]]
  and vp.title.font[1] == [[Fonts\FRIZQT__.TTF]] and c:said("core.skin = clean") ~= nil)
runs = 3
DT.skin(function() error("bad brush") end)
c:slash("skin forever")
check("a failing painter is counted, the others still run", runs == 4 and (c:db().errors.skin or 0) >= 1)

-- ---------------------------------------------------------------- fix round 5 (R-F5-5)
do
  -- every skin's fonts are set once on a hidden string at load (the `loaded` signal)
  local Frame = H.Frame
  local real = Frame.SetFont
  local seen, loading = {}, true
  Frame.SetFont = function(self, p, size, fl)
    if loading then seen[#seen + 1] = { fs = self, p = p, size = size } end
    return real(self, p, size, fl)
  end
  local w5 = H.world()
  local c5 = w5:client({ guild = G })
  c5:login()
  loading = false
  local D5 = c5.DT
  local want = {}
  for name in pairs(D5.skins) do
    for _, role in ipairs({ "title", "body", "small" }) do
      local p, size = D5.font(role, name)
      want[name .. ":" .. role] = { p = p, size = size }
    end
  end
  check("R-F5-5 fonts at load: every skin's title, body and small font was set once on the preload string",
    #D5.preloaded == 9 and (function()
      for k in pairs(want) do
        local found = false
        for _, x in ipairs(D5.preloaded) do if x == k then found = true end end
        if not found then return false end
      end
      return true end)())
  local n_morph = 0
  for _, x in ipairs(seen) do if x.p == [[Fonts\MORPHEUS_CYR.TTF]] and x.size == 16 then n_morph = n_morph + 1 end end
  check("R-F5-5 fonts at load: the gothic font is set at login though the default skin is clean", n_morph >= 1)
  -- a skin change repaints at once and again on the next frame
  local runs5 = 0
  D5.skin(function() runs5 = runs5 + 1 end)
  check("R-F5-5 a painter ran once when registered", runs5 == 1)
  c5:slash("skin deadtired")
  check("R-F5-5 a skin change repaints at once...", runs5 == 2)
  w5:advance(0.1)
  check("R-F5-5 ...and again on the next frame", runs5 == 3)
  w5:advance(5)
  check("R-F5-5 ...and no more than twice", runs5 == 3)
  -- a SetFont that answers false is counted under ui:font, the paint carries on
  local before = c5:db().errors["ui:font"] or 0
  local vp5 = D5.viewport({ id = "fonttest", title = "Font test" })
  Frame.SetFont = function(self, p, size, fl) real(self, p, size, fl); return false end
  c5:slash("skin clean")
  w5:advance(1)
  Frame.SetFont = real
  check("R-F5-5 a false from SetFont is counted under ui:font", (c5:db().errors["ui:font"] or 0) > before)
  check("R-F5-5 ...and the paint carried on (the title is plain)", vp5.title.font[1] == [[Fonts\FRIZQT__.TTF]])
  local before2 = c5:db().errors["ui:font"] or 0
  c5:slash("skin deadtired")
  w5:advance(1)
  -- and at load: a false from the preload's SetFont is counted too
  -- false only for the gothic font, which at load (default skin clean) only the preload asks for,
  -- so fontTo's own count can't cover for it
  Frame.SetFont = function(self, p, size, fl)
    real(self, p, size, fl)
    if p == [[Fonts\MORPHEUS_CYR.TTF]] then return false end
  end
  local w6 = H.world()
  local c6 = w6:client({ guild = G })
  c6:login()
  Frame.SetFont = real
  check("R-F5-5 a false from SetFont at load (the preload's one gothic font) is counted under ui:font",
    (c6:db().errors["ui:font"] or 0) == 1)
  check("R-F5-5 a SetFont that answers nothing (the usual case) is not counted", (c5:db().errors["ui:font"] or 0) == before2)
end

H.finish("skins")
