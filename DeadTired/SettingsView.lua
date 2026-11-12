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
local CARD_H, WIDTH = 26, 440
local CONTROL_W = 110             -- room kept on the right of a row for its control
local ITEM_H = 22                 -- one row of a list card
local TOP_GAP = 4                 -- the first card starts this far below the body's top

-- Widths inside a row (the viewport is WIDTH wide; rows sit 8 px in from the body's left).
local function rowWidth() return WIDTH - 2 * DT.style("spacing.pad") - 8 end
local function textWidth() return rowWidth() - CONTROL_W end

local function hint(s)
  if not DT.typed(s) then return "Not typed: " .. s.noVerb end
  local h = "/dt set " .. s.module .. " " .. s.key .. " <value>"
  if s.verb then h = h .. "  or  /dt " .. s.verb end
  return h
end

-- fw1 walk defect 1: a row is as tall as its label, wrapped description and hint (never a fixed
-- height), plus its list rows for a list card.
function DT.settingsRowHeight(labelH, descH, hintH, items)
  return math.max(30, 2 + labelH + 2 + descH + 2 + hintH + 6 + (items or 0) * ITEM_H)
end

local syncList

local function syncRow(r)
  local s, v = r.setting, DT.get(r.setting.module, r.setting.key)
  if s.type == "bool" then r.control:SetChecked(v and true or false)
  elseif s.type == "choice" then r.control:SetText(DT.format(s, v))
  elseif s.type == "number" or s.type == "string" then r.control:SetText(DT.format(s, v))
  elseif s.type == "list" then syncList(r) end
end

-- ---------------------------------------------------------------- list cards

-- Where a dragged row lands: the first row whose bottom is below the cursor, else the last.
function DT.dropIndex(cursorY, subs)
  local n = 0
  for i, sub in ipairs(subs) do
    if sub.shown ~= false and sub.item then
      n = i
      local bottom = sub.GetBottom and sub:GetBottom()
      if type(bottom) == "number" and type(cursorY) == "number" and cursorY >= bottom then return i end
    end
  end
  return n
end

local function cursorY()
  local _, y = DT.try(GetCursorPosition)
  local scale = UIParent and UIParent.GetEffectiveScale and DT.try(UIParent.GetEffectiveScale, UIParent)
  if type(y) ~= "number" then return nil end
  if type(scale) == "number" and scale > 0 then y = y / scale end
  return y
end

-- Port 2 (the Port 1 walk's request 3): a grab hand while a row is dragged by its grip. The
-- client's own SetCursor / ResetCursor (globals, guarded); with neither, the cursor is unchanged.
local GRAB = [[Interface\CURSOR\openhand]]
function DT.grabCursor(on)
  if on then DT.try(SetCursor, GRAB) else DT.try(ResetCursor) end
end

local function listSub(r, i)
  local sub = r.subs[i]
  if sub then return sub end
  local s = r.setting
  sub = CreateFrame("Frame", nil, r.frame)
  sub:SetHeight(ITEM_H)
  if s.move then
    sub.grip = CreateFrame("Button", nil, sub)
    sub.grip:SetSize(14, ITEM_H - 4)
    sub.grip:SetPoint("LEFT", sub, "LEFT", 0, 0)
    sub.grip.text = sub.grip:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sub.grip.text:SetPoint("CENTER", sub.grip, "CENTER", 0, 0)
    sub.grip.text:SetText("=")
    sub.grip:RegisterForDrag("LeftButton")
    sub.grip:SetScript("OnDragStart", function()
      r.dragging = sub.item and sub.item.name
      if r.dragging then DT.grabCursor(true) end
    end)
    sub.grip:SetScript("OnDragStop", function()
      local name = r.dragging
      r.dragging = nil
      DT.grabCursor(false)
      if not name then return end
      local n = DT.dropIndex(cursorY(), r.subs)
      if n > 0 then s.move(name, n) end
      syncList(r)
    end)
  end
  local x = s.move and 18 or 0
  if s.toggle then
    sub.tick = CreateFrame("CheckButton", nil, sub, "UICheckButtonTemplate")
    sub.tick:SetSize(20, 20)
    sub.tick:SetPoint("LEFT", sub, "LEFT", x, 0)
    sub.tick:SetScript("OnClick", function(self)
      if sub.item then s.toggle(sub.item.name, self:GetChecked() and true or false) end
      syncList(r)
    end)
    x = x + 22
  end
  sub.label = sub:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  sub.label:SetPoint("LEFT", sub, "LEFT", x, 0)
  sub.label:SetWidth(textWidth() - x)
  sub.label:SetJustifyH("LEFT")
  if s.remove then
    sub.remove = CreateFrame("Button", nil, sub, "UIPanelButtonTemplate")
    sub.remove:SetSize(60, 18)
    sub.remove:SetPoint("RIGHT", sub, "RIGHT", -4, 0)
    sub.remove:SetText("Remove")
    sub.remove:SetScript("OnClick", function()
      if sub.item then s.remove(sub.item.name) end
      syncList(r)
    end)
  end
  sub:EnableMouse(true)
  sub:SetScript("OnEnter", function(self)
    if not (sub.item and sub.item.tip) then return end
    local tt = DT.tooltip()
    tt:SetOwner(self, "ANCHOR_RIGHT")
    tt:AddLine(sub.item.tip)
    tt:Show()
  end)
  sub:SetScript("OnLeave", function() if DT._tooltip then DT._tooltip:Hide() end end)
  DT.skin(function()
    DT.fontTo(sub.label, "body")
    if sub.grip then DT.fontTo(sub.grip.text, "body", "muted") end
  end)
  r.subs[i] = sub
  return sub
end

syncList = function(r)
  local s = r.setting
  local ok, items = pcall(s.items)
  if not ok or type(items) ~= "table" then items = {} end
  local y = r.listTop or 0
  for i, it in ipairs(items) do
    local sub = listSub(r, i)
    sub.item = it
    sub:ClearAllPoints()
    sub:SetPoint("TOPLEFT", r.frame, "TOPLEFT", 0, -y)
    sub:SetPoint("TOPRIGHT", r.frame, "TOPRIGHT", 0, -y)
    sub.label:SetText(DT.safe(it.label or it.name, 60))
    if sub.tick then sub.tick:SetChecked(it.on and true or false) end
    sub:Show()
    y = y + ITEM_H
  end
  for i = #items + 1, #r.subs do r.subs[i].item = nil; r.subs[i]:Hide() end
  if r.empty then
    if #items == 0 and s.empty then r.empty:SetText(s.empty); r.empty:Show() else r.empty:Hide() end
  end
  local n = #items
  if n == 0 and s.empty then n = 1 end
  if n ~= r.items then r.items = n; return true end                       -- the card's height changed
  return false
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

-- Measure a row: each text at its width, the row as tall as all of it (defect 1).
local function measure(r)
  local lh = DT.textHeight(r.label, textWidth())
  local dh = DT.textHeight(r.desc, textWidth())
  local hh = DT.textHeight(r.hint, rowWidth())
  r.listTop = 2 + lh + 2 + dh + 2 + hh + 4
  r.height = DT.settingsRowHeight(lh, dh, hh, r.items)
  return r.height
end

-- The content's place: always where the scroll says. A search, a reopen or a redraw used to leave
-- the content where an earlier scroll put it while the scroll counter went back to 0, so the first
-- setting sat above the body, under the search box (fw1 walk defect 2).
local function place()
  content:ClearAllPoints()
  content:SetPoint("TOPLEFT", vp.body, "TOPLEFT", 0, scroll)              -- guard: content follows scroll
  content:SetPoint("TOPRIGHT", vp.body, "TOPRIGHT", 0, scroll)
end

-- Lay the cards out for the current query (case-insensitive, like every list).
local model = DT.listModel()
local function layout()
  if not content then return end
  local visible = {}
  for _, r in ipairs(model:visible()) do visible[r] = true end
  local y, lastModule = TOP_GAP, nil
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
          h.top = y
          y = y + CARD_H
          lastModule = r.setting.module
        end
        syncRow(r)
        local rh = measure(r)
        r.frame:SetHeight(rh)
        r.frame:ClearAllPoints()
        r.frame:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -y)
        r.frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
        r.frame:Show()
        r.top = y
        y = y + rh
      else
        r.frame:Hide()
      end
    end
  end
  content:SetHeight(math.max(1, y))
  content.total = y
  local maxS = math.max(0, y - ((vp.body:GetHeight() or 0)))
  if scroll > maxS then scroll = maxS end
  place()
end

local function build()
  vp = DT.viewport({ id = "settings", title = "Dead Tired settings", search = true, width = WIDTH, height = 480,
    onSearch = function(text) model:filter(text); scroll = 0; layout() end,
    onShow = function() layout() end })
  vp.body:SetClipsChildren(true)
  content = CreateFrame("Frame", nil, vp.body)
  vp.content = content
  place()
  vp.body:EnableMouseWheel(true)
  vp.body:SetScript("OnMouseWheel", function(_, delta)
    local maxS = math.max(0, (content.total or 0) - (vp.body:GetHeight() or 0))
    scroll = math.min(maxS, math.max(0, scroll - delta * 40))
    place()
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
        local r = { setting = s, headerIndex = hi, frame = CreateFrame("Frame", nil, content), subs = {}, items = 0 }
        r.label = r.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.label:SetPoint("TOPLEFT", r.frame, "TOPLEFT", 0, -2)
        r.label:SetJustifyH("LEFT")
        r.label:SetText(s.label)
        r.desc = r.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.desc:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -2)
        r.desc:SetJustifyH("LEFT")
        if r.desc.SetWordWrap then r.desc:SetWordWrap(true) end
        r.desc:SetText(s.desc)
        r.hint = r.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.hint:SetPoint("TOPLEFT", r.desc, "BOTTOMLEFT", 0, -2)
        r.hint:SetJustifyH("LEFT")
        if r.hint.SetWordWrap then r.hint:SetWordWrap(true) end
        r.hint:SetText(hint(s))
        if s.type == "list" then
          r.empty = r.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
          r.empty:SetPoint("TOPLEFT", r.hint, "BOTTOMLEFT", 0, -6)
          r.empty:Hide()
          DT.skin(function() DT.fontTo(r.empty, "small", "muted") end)
        end
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
  scroll = 0
  layout()
end

-- For the offline tests only.
DT._settingsView = { rows = function() return rows end, vp = function() return vp end,
  scroll = function() return scroll end, layout = function() layout() end }

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
