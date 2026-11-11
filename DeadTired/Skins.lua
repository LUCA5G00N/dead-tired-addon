-- Dead Tired: skins. One style table per skin; every DT frame draws through DT.style / DT.font /
-- DT.backdrop and re-draws when the skin changes (DT.skin(fn)). Fonts and textures are named by
-- LibSharedMedia key, so other addons' media can be used later; a raw path stands behind each one
-- for when LibSharedMedia (or the key) is missing.
--   forever:   the game's stone and metal: dark dialog stone, the dialog border, gold titles.
--   deadtired: gothic: deep green-black, bone text, a sickly green accent, Morpheus titles.
--              A first palette, for Tim to curate from screenshot marks.
-- A skin need not name everything: what it leaves out comes from forever (the base).
local ADDON, ns = ...
local DT = ns.DT

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local FLAT = [[Interface\Buttons\WHITE8X8]]
if LSM then
  LSM:Register("background", "Dead Tired Flat", FLAT)
  LSM:Register("border", "Dead Tired Edge", FLAT)
end

DT.skins = {
  forever = {
    title = "Forever",
    colours = {
      bg = { 1, 1, 1, 1 }, border = { 1, 1, 1, 1 },
      title = { 1, 0.82, 0, 1 }, text = { 1, 1, 1, 1 }, muted = { 0.7, 0.7, 0.7, 1 },
      accent = { 1, 0.82, 0, 1 }, row = { 1, 1, 1, 0.06 }, rowHover = { 1, 0.82, 0, 0.15 },
      input = { 0, 0, 0, 0.5 },
    },
    fonts = {
      title = { "Friz Quadrata TT", [[Fonts\FRIZQT__.TTF]], 14, "" },
      body  = { "Friz Quadrata TT", [[Fonts\FRIZQT__.TTF]], 12, "" },
      small = { "Friz Quadrata TT", [[Fonts\FRIZQT__.TTF]], 10, "" },
    },
    textures = {
      background = { "Blizzard Dialog Background Dark", [[Interface\DialogFrame\UI-DialogBox-Background-Dark]] },
      border     = { "Blizzard Dialog", [[Interface\DialogFrame\UI-DialogBox-Border]] },
      barBorder  = { "Blizzard Tooltip", [[Interface\Tooltips\UI-Tooltip-Border]] },
    },
    spacing = { pad = 14, gap = 6, row = 18, edge = 24, inset = 6, barEdge = 12, barInset = 3, barHeight = 24 },
  },
  deadtired = {
    title = "Dead Tired",
    colours = {
      bg = { 0.04, 0.07, 0.05, 0.94 }, border = { 0.42, 0.58, 0.20, 1 },
      title = { 0.62, 0.80, 0.22, 1 }, text = { 0.89, 0.85, 0.74, 1 }, muted = { 0.60, 0.58, 0.50, 1 },
      accent = { 0.62, 0.80, 0.22, 1 }, row = { 0.89, 0.85, 0.74, 0.05 }, rowHover = { 0.62, 0.80, 0.22, 0.18 },
      input = { 0, 0, 0, 0.6 },
    },
    fonts = {
      title = { "Morpheus", [[Fonts\MORPHEUS.TTF]], 16, "" },
    },
    textures = {
      background = { "Dead Tired Flat", FLAT },
      border     = { "Dead Tired Edge", FLAT },
      barBorder  = { "Dead Tired Edge", FLAT },
    },
    spacing = { edge = 1, inset = 1, barEdge = 1, barInset = 1 },
  },
}

local BASE = "forever"

function DT.skinName()
  local n = DT.get and DT.get("core", "skin")
  if type(n) == "string" and DT.skins[n] then return n end
  return BASE
end

-- DT.style("colours.text") from the current skin (or the named one), falling back to the base.
function DT.style(path, skin)
  local function look(t)
    for part in path:gmatch("[^%.]+") do
      if type(t) ~= "table" then return nil end
      t = t[part]
    end
    return t
  end
  local v = look(DT.skins[skin or DT.skinName()])
  if v == nil then v = look(DT.skins[BASE]) end                           -- guard: base fallback
  return v
end

local function fetch(kind, key, path)
  if LSM and key then
    local p = LSM:Fetch(kind, key, true)
    if p then return p end
  end
  return path
end

-- path, size, flags for a font role (title, body, small).
function DT.font(role, skin)
  local f = DT.style("fonts." .. role, skin) or DT.style("fonts.body", skin)
  return fetch("font", f[1], f[2]), f[3], f[4]
end

function DT.texture(role, skin)
  local t = DT.style("textures." .. role, skin)
  if not t then return FLAT end
  return fetch(role == "background" and "background" or "border", t[1], t[2])
end

function DT.colour(name, skin)
  local c = DT.style("colours." .. name, skin) or { 1, 1, 1, 1 }
  return c[1], c[2], c[3], c[4]
end

-- A backdrop table for frame:SetBackdrop (BackdropTemplate). bar = true: the bar's lighter edge.
function DT.backdrop(bar, skin)
  local edge = DT.style(bar and "spacing.barEdge" or "spacing.edge", skin)
  local inset = DT.style(bar and "spacing.barInset" or "spacing.inset", skin)
  return {
    bgFile = DT.texture("background", skin),
    edgeFile = DT.texture(bar and "barBorder" or "border", skin),
    tile = true, tileSize = 32, edgeSize = edge,
    insets = { left = inset, right = inset, top = inset, bottom = inset },
  }
end

-- Paint a DT frame with the current skin's backdrop (only frames that have SetBackdrop).
function DT.paint(frame, bar)
  if not frame or type(frame.SetBackdrop) ~= "function" then return end
  frame:SetBackdrop(DT.backdrop(bar))
  frame:SetBackdropColor(DT.colour("bg"))
  frame:SetBackdropBorderColor(DT.colour("border"))
end

function DT.fontTo(fs, role, colour)
  if not fs then return end
  local p, size, flags = DT.font(role)
  if fs.SetFont then fs:SetFont(p, size, flags) end
  if fs.SetTextColor then fs:SetTextColor(DT.colour(colour or (role == "title" and "title" or "text"))) end
end

-- Painters: every DT frame registers one; all re-run when the skin changes.
DT.painters = {}
function DT.skin(fn)
  DT.painters[#DT.painters + 1] = fn
  local ok, err = pcall(fn)
  if not ok then DT.fail("skin", "paint", err) end
end

function DT.restyle()
  for _, fn in ipairs(DT.painters) do
    local ok, err = pcall(fn)
    if not ok then DT.fail("skin", "paint", err) end
  end
end

DT.listen("setting", function(id, key) if id == "core" and key == "skin" then DT.restyle() end end)
