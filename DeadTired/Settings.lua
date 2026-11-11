-- Dead Tired: settings from the terminal. /dt set <module> <key> <value> and /dt get <module> [key]
-- reach every setting any module declares (the registry is in Core.lua). The settings viewport
-- (SettingsView.lua) writes through the same DT.set, so the two paths can't drift apart.
-- Also the core module: /dt help, and the skin choice.
local ADDON, ns = ...
local DT = ns.DT

local function line(id, s) return id .. "." .. s.key .. " = " .. DT.format(s, DT.get(id, s.key)) end

function DT.moduleIds()
  local ids = {}
  for id in pairs(DT.settings) do ids[#ids + 1] = id end
  table.sort(ids)
  return ids
end

local function setVerb(args)
  local id, key, value = args:match("^(%S+)%s+(%S+)%s*(.-)%s*$")
  if not id then
    return DT.out("/dt set <module> <key> <value>. Modules: " .. table.concat(DT.moduleIds(), ", "))
  end
  local ok, v = DT.set(id:lower(), key, value, true)
  if not ok then return DT.out("/dt set: " .. v) end
  return DT.out(line(id:lower(), DT.setting(id:lower(), key)))
end

local function getVerb(args)
  local id, key = args:match("^(%S+)%s*(%S*)")
  if not id then
    return DT.out("/dt get <module> [key]. Modules: " .. table.concat(DT.moduleIds(), ", "))
  end
  id = id:lower()
  local reg = DT.settings[id]
  if not reg then return DT.out("/dt get: no module called " .. DT.safe(id, 24)) end
  if key ~= "" then
    local s = reg.by[key]
    if not s then return DT.out("/dt get: no setting " .. DT.safe(id, 24) .. "." .. DT.safe(key, 24)) end
    return DT.out(line(id, s))
  end
  for _, s in ipairs(reg.list) do DT.out(line(id, s)) end
end

DT.module({
  id = "core",
  title = "Dead Tired",
  settings = {
    { key = "skin", type = "choice", choices = { "deadtired", "forever" }, default = "deadtired",
      label = "Skin", verb = "skin forever|deadtired",
      desc = "How every Dead Tired window and the bar look: Dead Tired (the guild's) or Forever (the game's stone and metal)." },
    { key = "windows", type = "position", label = "Window places",
      desc = "Each Dead Tired window stays where you drag it, through reloads.",
      noVerb = "drag a window by its title to move it" },
  },
  verbs = {
    { verb = "help", usage = "help", fn = function() DT.help() end },
    { verb = "set", usage = "set <module> <key> <value>", fn = setVerb },
    { verb = "get", usage = "get <module> [key]", fn = getVerb },
    { verb = "skin", usage = "skin forever|deadtired", fn = function(args)
        return setVerb("core skin " .. (args ~= "" and args or "?"))
      end },
  },
})
