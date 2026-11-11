-- Offline checks for Settings.lua and the settings registry in Core.lua: every declared setting has
-- a /dt set path or a noVerb reason; values typed, validated and saved; /dt get.
-- lua5.1 DeadTired/tests/test_settings.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"

-- ---------------------------------------------------------------- the verb-or-noVerb rule
do
  local w = H.world()
  local c = w:client({ guild = G })
  local DT = c.DT
  local total, bad = 0, {}
  for id, reg in pairs(DT.settings) do
    for _, s in ipairs(reg.list) do
      total = total + 1
      local typed = DT.typed(s)
      if not typed and not (type(s.noVerb) == "string" and s.noVerb:match("%S")) then bad[#bad + 1] = id .. "." .. s.key end
      if typed then
        local ok = DT.set(id, s.key, DT.format(s, DT.get(id, s.key)), true)
        if not ok then bad[#bad + 1] = id .. "." .. s.key .. " (not settable by typing)" end
      end
      if s.label == "" or s.desc == "" then bad[#bad + 1] = id .. "." .. s.key .. " (no plain words)" end
    end
  end
  check("every declared setting: reachable by /dt set, or carries noVerb", total >= 7 and #bad == 0)
  if #bad > 0 then print("  " .. table.concat(bad, ", ")) end

  local ok, err = pcall(DT.module, { id = "sneaky", settings = {
    { key = "spot", type = "position", label = "Spot", desc = "Where it sits." } } })
  check("a setting with no typed path and no noVerb is refused at registration", not ok and tostring(err):find("noVerb", 1, true))
  ok, err = pcall(DT.module, { id = "sneaky2", settings = {
    { key = "hidden", type = "bool", typed = false, default = true, label = "Hidden", desc = "Not typed.", noVerb = "  " } } })
  check("a blank noVerb is no reason", not ok)
  ok = pcall(DT.module, { id = "fine", settings = {
    { key = "spot", type = "position", label = "Spot", desc = "Where it sits.", noVerb = "drag it" } } })
  check("one with a noVerb reason is accepted", ok and DT.setting("fine", "spot") ~= nil)
  ok = pcall(DT.module, { id = "wordless", settings = { { key = "x", type = "bool", default = true } } })
  check("a setting without plain words (label, desc) is refused", not ok)
end

-- ---------------------------------------------------------------- typed, validated, saved
do
  local w = H.world()
  local c = w:client({ guild = G, load = false })
  c.DT.module({ id = "t", title = "Test", settings = {
    { key = "flag", type = "bool", default = false, label = "Flag", desc = "A flag." },
    { key = "hour", type = "number", default = 23, min = 0, max = 23, label = "Hour", desc = "An hour." },
    { key = "mood", type = "choice", choices = { "grim", "grimmer" }, default = "grim", label = "Mood", desc = "A mood." },
    { key = "motto", type = "string", default = "rest", maxLen = 16, label = "Motto", desc = "A motto." },
  } })
  c:fire("ADDON_LOADED", "DeadTired")
  c:login()
  local DT = c.DT
  for _, word in ipairs({ "on", "ON", "yes", "true", "1" }) do
    c:slash("set t flag off")
    c:slash("set t flag " .. word)
    check("bool: '" .. word .. "' is on", DT.get("t", "flag") == true and c:said("t.flag = on"))
  end
  c:slash("set t flag maybe")
  check("bool: a bad word is refused, the value kept", c:said("/dt set: expects on or off") and DT.get("t", "flag") == true)
  c:slash("set t hour 7")
  check("number: typed as a number", DT.get("t", "hour") == 7 and type(DT.get("t", "hour")) == "number")
  c:slash("set t hour 24")
  check("number: out of range refused", c:said("/dt set: expects a number from 0 to 23") and DT.get("t", "hour") == 7)
  c:slash("set t hour soon")
  check("number: not a number refused", DT.get("t", "hour") == 7 and c:said("/dt set:"))
  c:slash("set t mood GRIMMER")
  check("choice: case-insensitive, stored lower", DT.get("t", "mood") == "grimmer")
  c:slash("set t mood cheerful")
  check("choice: unknown refused, the choices named", c:said("/dt set: expects one of: grim, grimmer") and DT.get("t", "mood") == "grimmer")
  c:slash("set t motto   Rest In Pieces  ")
  check("string: case kept, trimmed", DT.get("t", "motto") == "Rest In Pieces")
  c:slash("set t motto a much too long motto")
  check("string: too long refused", c:said("/dt set: expects at most 16 characters") and DT.get("t", "motto") == "Rest In Pieces")
  c:slash("set t motto |cffff0000x")
  check("string: UI escapes stripped", not DT.get("t", "motto"):find("|", 1, true))
  c:slash("set core windows here")
  check("position: refused by typing, with where it lives", c:said("/dt set: can't be typed: drag a window by its title to move it"))
  c:slash("set nope x y")
  check("unknown module named", c:said("/dt set: no module called nope"))
  c:slash("set t nope 1")
  check("unknown setting named", c:said("/dt set: no setting t.nope"))
  c:slash("set")
  check("/dt set alone: the form and the modules", c:said("/dt set <module> <key> <value>. Modules: ") ~= nil)
  c:slash("get t")
  check("/dt get <module>: every setting", c:count("t.") == 4 and c:said("t.hour = 7") and c:said("t.flag = on"))
  c:slash("get t mood")
  check("/dt get <module> <key>", #c.printed == 1 and c:said("t.mood = grimmer"))
  c:slash("get nope")
  check("/dt get unknown module", c:said("/dt get: no module called nope"))
  check("saved in DeadTiredDB.settings", c:db().settings.t.hour == 7 and c:db().settings.t.mood == "grimmer")
  local seen
  DT.listen("setting", function(id, key, v) seen = id .. "." .. key .. "=" .. tostring(v) end)
  check("the settings-view path (typed values) is the same DT.set", DT.set("t", "flag", false) and seen == "t.flag=false")
  check("the view path validates too", not DT.set("t", "hour", 99) and DT.get("t", "hour") == 7)
  -- survives a reload (the module re-registered by the reloaded instance)
  local db = c:db()
  local w2 = H.world()
  local c2 = w2:client({ guild = G, db = db, load = false })
  c2.DT.module({ id = "t", settings = { { key = "hour", type = "number", default = 23, min = 0, max = 23, label = "Hour", desc = "An hour." } } })
  c2:fire("ADDON_LOADED", "DeadTired")
  check("a saved value survives /reload", c2.DT.get("t", "hour") == 7)
end

-- ---------------------------------------------------------------- the real modules' verbs
do
  local w = H.world()
  local c = w:client({ guild = G })
  c:login()
  c:slash("skin forever")
  check("/dt skin forever sets core.skin", c.DT.get("core", "skin") == "forever" and c:said("core.skin = forever"))
  c:slash("skin pink")
  check("/dt skin with a bad name refused", c.DT.get("core", "skin") == "forever" and c:said("/dt set: expects one of: deadtired, forever"))
  c:slash("set who hello off")
  check("/dt set who hello off", c.DT.get("who", "hello") == false)
end

H.finish("settings")
