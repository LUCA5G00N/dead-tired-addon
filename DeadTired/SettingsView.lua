-- Dead Tired: settings as cards. The settings viewport builds itself from the registry: one card
-- per module, one row per setting, in plain words (label, what it does), with the control and the
-- /dt set line that does the same. A setting that can't be typed shows where it lives instead (its
-- noVerb). Changing a control goes through DT.set, the same path /dt set takes; a change made
-- either way shows in the other (the "setting" signal).
-- Entry points: /dt settings, the game's Settings -> AddOns -> Dead Tired page (a stub with one
-- button), and the addon compartment (DeadTired_OnAddonCompartmentClick, named in the .toc).
local ADDON, ns = ...
local DT = ns.DT

local vp, content, rows, scroll = nil, nil, {}, 0
local ROW_H, CARD_H = 52, 26

local function hint(s)
  if not DT.typed(s) then return "Not typed: " .. s.noVerb end
  local h = "/dt set " .. s.module .. " " .. s.key .. " <value>"
  if s.verb then h = h .. "  or  /dt " .. s.verb end
  return h
end

local function syncRow(r)
  local s, v = r.setting, DT.get(r.setting.module, r.setting.key)
  if s.type == "bool" then r.control:SetChecked(v and true or false)
  elseif s.type == "choice" then r.control:SetText(DT.format(s, v))
  elseif s.type == "number" or s.type == "string" then r.control:SetText(DT.format(s, v)) end
end

local function control(r, parent)
  local s = r.setting
  local c
  if s.type == "bool" then
    c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    c:SetScript("OnClick", function(self) DT.set(s.module, s.key, self:GetChecked() and true or false) end)
  elseif s.type == "choice" then
    c = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    c:SetSize(96, 22)
    c:SetScript("OnClick", function()
      local cur, nxt = DT.get(s.module, s.key), s.choices[1]
      for i, ch in ipairs(s.choices) do if ch == cur then nxt = s.choices[i % #s.choices + 1] end end
      DT.set(s.module, s.key, nxt)
    end)
  elseif s.type == "number" or s.type == "string" then
    c = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    c:SetSize(96, 20)
    c:SetAutoFocus(false)
    c:SetTextInsets(4, 4, 0, 0)
    c:SetScript("OnEscapePressed", function(self) self:ClearFocus(); syncRow(r) end)
    c:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      local ok, why = DT.set(s.module, s.key, self:GetText() or "")
      if not ok then DT.out("/dt set: " .. why) end
      syncRow(r)
    end)
    DT.skin(function()
      DT.paint(c, true)
      c:SetBackdropColor(DT.colour("input"))
      local p, size, flags = DT.font("body")
      c:SetFont(p, size, flags)
      c:SetTextColor(DT.colour("text"))
    end)
  end
  return c
end

-- What the search box looks in for a row.
local function searchText(s)
  local m = DT.byId[s.module]
  return table.concat({ m and m.title or s.module, s.module, s.key, s.label, s.desc }, " ")
end

-- Lay the cards out for the current query (case-insensitive, like every list).
local model = DT.listModel()
local function layout()
  if not content then return end
  local visible = {}
  for _, r in ipairs(model:visible()) do visible[r] = true end
  local y, lastModule = 0, nil
  for _, r in ipairs(rows) do
    if r.header then
      r.frame:Hide()
    else
      if visible[r] then
        if r.setting.module ~= lastModule then
          local h = rows[r.headerIndex]
          h.frame:ClearAllPoints()
          h.frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
          h.frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
          h.frame:Show()
          y = y + CARD_H
          lastModule = r.setting.module
        end
        r.frame:ClearAllPoints()
        r.frame:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -y)
        r.frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
        r.frame:Show()
        syncRow(r)
        y = y + ROW_H
      else
        r.frame:Hide()
      end
    end
  end
  content:SetHeight(math.max(1, y))
  content.total = y
end

local function build()
  vp = DT.viewport({ id = "settings", title = "Dead Tired settings", search = true, width = 440, height = 480,
    onSearch = function(text) model:filter(text); scroll = 0; layout() end,
    onShow = function() layout() end })
  vp.body:SetClipsChildren(true)
  content = CreateFrame("Frame", nil, vp.body)
  content:SetPoint("TOPLEFT", vp.body, "TOPLEFT", 0, 0)
  content:SetPoint("TOPRIGHT", vp.body, "TOPRIGHT", 0, 0)
  vp.body:EnableMouseWheel(true)
  vp.body:SetScript("OnMouseWheel", function(_, delta)
    local maxS = math.max(0, (content.total or 0) - (vp.body:GetHeight() or 0))
    scroll = math.min(maxS, math.max(0, scroll - delta * ROW_H))
    content:SetPoint("TOPLEFT", vp.body, "TOPLEFT", 0, scroll)
    content:SetPoint("TOPRIGHT", vp.body, "TOPRIGHT", 0, scroll)
  end)
  local searchRows = {}
  for _, m in ipairs(DT.modules) do
    local reg = DT.settings[m.id]
    if reg and #reg.list > 0 then
      local h = { header = true, frame = CreateFrame("Frame", nil, content) }
      h.frame:SetHeight(CARD_H)
      h.text = h.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      h.text:SetPoint("LEFT", h.frame, "LEFT", 0, 0)
      h.text:SetText(m.title)
      DT.skin(function() DT.fontTo(h.text, "title") end)
      rows[#rows + 1] = h
      local hi = #rows
      for _, s in ipairs(reg.list) do
        local r = { setting = s, headerIndex = hi, frame = CreateFrame("Frame", nil, content) }
        r.frame:SetHeight(ROW_H)
        r.label = r.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.label:SetPoint("TOPLEFT", r.frame, "TOPLEFT", 0, -2)
        r.label:SetText(s.label)
        r.desc = r.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.desc:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -2)
        r.desc:SetPoint("RIGHT", r.frame, "RIGHT", -110, 0)
        r.desc:SetJustifyH("LEFT")
        r.desc:SetText(s.desc)
        r.hint = r.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.hint:SetPoint("TOPLEFT", r.desc, "BOTTOMLEFT", 0, -2)
        r.hint:SetText(hint(s))
        r.control = control(r, r.frame)
        if r.control then r.control:SetPoint("TOPRIGHT", r.frame, "TOPRIGHT", -4, -2) end
        DT.skin(function()
          DT.fontTo(r.label, "body")
          DT.fontTo(r.desc, "small", "muted")
          DT.fontTo(r.hint, "small", "accent")
        end)
        r.search = searchText(s)
        rows[#rows + 1] = r
        searchRows[#searchRows + 1] = r
      end
    end
  end
  model:set(searchRows)
end

function DT.openSettings(query)
  if not DT.isMember() then return end
  if not vp then build() end
  vp:Show()
  if vp.search then vp.search:SetText(query or "") end
  model:filter(query or "")
  layout()
end

DT.listen("setting", function() if vp and vp:IsShown() then layout() end end)

-- The game's Settings -> AddOns page: a stub that opens DT's own viewport.
local function blizzardPage()
  local panel = CreateFrame("Frame", "DeadTiredSettingsPanel")
  local t = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  t:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
  t:SetText("Dead Tired")
  local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  b:SetSize(200, 24)
  b:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -12)
  b:SetText("Open Dead Tired settings")
  b:SetScript("OnClick", function() DT.openSettings() end)
  local S = Settings
  if type(S) == "table" and type(S.RegisterCanvasLayoutCategory) == "function"
     and type(S.RegisterAddOnCategory) == "function" then
    local cat = DT.try(S.RegisterCanvasLayoutCategory, panel, "Dead Tired")
    if cat then DT.try(S.RegisterAddOnCategory, cat) end
    DT.settingsCategory = cat
  end
  DT.settingsPanel = panel
end

-- Named in the .toc (## AddonCompartmentFunc). A DeadTired* global: DT's own.
function DeadTired_OnAddonCompartmentClick()
  DT.openSettings()
end

DT.module({
  id = "settingsview",
  title = "Settings window",
  init = blizzardPage,
  verbs = {
    { verb = "settings", usage = "settings", fn = function(args) DT.openSettings(args) end },
  },
})
