-- Dead Tired: the standard frames. One viewport frame every module draws into, one list widget,
-- one toast, one tooltip. All drawn through the skin (Skins.lua). Every frame here is DT's own
-- (named DeadTired*), insecure, so it shows and works in combat.
--
-- Viewport rules (FEATURES.md, the Wizardry marks bar's visibility rules; its code isn't in
-- reference/, so only the rules are copied): placed and kept (dragged by the title, the place saved
-- in DeadTiredDB.frames and restored after /reload), no secure templates, so usable in combat.
-- R-P2-2 (Port 2, ruled 11 Nov): Escape closes every viewport. At creation DT does
-- table.insert(UISpecialFrames, <the viewport's own frame name>), once per viewport; that is the one
-- touch on a Blizzard table (CLAUDE.md), and DT never removes, reorders or replaces anything in it.
-- A viewport may opt out with sticky = true (none does yet). tests/test_taint.lua allows exactly
-- this call and type(UISpecialFrames), nothing else.
local ADDON, ns = ...
local DT = ns.DT

-- ---------------------------------------------------------------- places

-- The saved place of frame id: { point, relPoint, x, y } or nil.
function DT.place(id)
  local p = DT.db().frames[id]
  if type(p) == "table" and type(p[1]) == "string" and type(p[3]) == "number" and type(p[4]) == "number" then
    return p
  end
  return nil
end

function DT.savePlace(frame, id)
  local point, _, relPoint, x, y = frame:GetPoint(1)
  if type(point) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then return false end
  DT.db().frames[id] = { point, relPoint or point, math.floor(x + 0.5), math.floor(y + 0.5) }
  return true
end

function DT.restorePlace(frame, id, default)
  local p = DT.place(id) or default
  frame:ClearAllPoints()
  frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

-- Drag to move, place saved on release.
function DT.draggable(frame, id, handle)
  handle = handle or frame
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  handle:EnableMouse(true)
  handle:RegisterForDrag("LeftButton")
  handle:SetScript("OnDragStart", function() frame:StartMoving() end)
  handle:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    DT.savePlace(frame, id)
  end)
end

-- ---------------------------------------------------------------- tooltip

function DT.tooltip()
  if not DT._tooltip then
    DT._tooltip = CreateFrame("GameTooltip", "DeadTiredTooltip", UIParent, "GameTooltipTemplate")
  end
  return DT._tooltip
end

-- ---------------------------------------------------------------- the viewport

DT.viewports = {}

-- R-P2-2: Escape closes DT's own frame `name` (a name DT created, "DeadTired..."). Inserts only;
-- once per name; nothing else in the table is read, moved or removed.
local escaped = {}
function DT.closeOnEscape(name)
  if type(name) ~= "string" or not name:match("^DeadTired") or escaped[name] then return false end  -- guard: DT's own names only
  if type(UISpecialFrames) ~= "table" then return false end
  table.insert(UISpecialFrames, name)                                      -- guard: insert only (R-P2-2)
  escaped[name] = true
  return true
end

-- A date for a narrow column: "2026-11-10 21:00:00" -> "10 Nov" (Port 2, the graveyard's date
-- column). Anything else is returned as given (made safe), at most 10 characters.
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
function DT.shortDate(at)
  if type(at) ~= "string" then return "?" end
  local m, d = at:match("^%d%d%d%d%-(%d%d)%-(%d%d)")
  m, d = tonumber(m), tonumber(d)
  if m and d and MONTHS[m] then return d .. " " .. MONTHS[m] end
  return DT.safe(at, 10)
end

-- The body's top, in pixels below the frame's top: under the title, and under the search box with a
-- clear gap (the box's backdrop edge drawn outside it included).
local TITLE_H, SEARCH_H, SEARCH_GAP = 22, 20, 10
function DT.bodyTop(search)
  local pad = DT.style("spacing.pad")
  local top = pad + TITLE_H
  if search then top = top + SEARCH_H + SEARCH_GAP + (DT.style("spacing.barEdge") or 0) / 2 end
  return top
end
DT.SEARCH_H = SEARCH_H

-- DT.viewport{ id, title, search = true|false, width, height, onSearch = fn(text), onShow = fn,
--              footer = pixels kept free at the bottom (for a note line),
--              sticky = true: Escape leaves it open (R-P2-2's opt-out) }
function DT.viewport(o)
  if DT.viewports[o.id] then return DT.viewports[o.id] end
  local vp = { id = o.id }
  local name = "DeadTiredViewport_" .. o.id
  local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  vp.frame = f
  vp.name = name
  if not o.sticky then DT.closeOnEscape(name) end
  f:SetSize(o.width or 360, o.height or 420)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:Hide()
  DT.restorePlace(f, "viewport." .. o.id, { "CENTER", "CENTER", 0, 0 })
  DT.draggable(f, "viewport." .. o.id)

  local pad = DT.style("spacing.pad")
  vp.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  vp.title:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -pad)
  vp.title:SetText(o.title or o.id)

  vp.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  vp.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
  vp.close:SetScript("OnClick", function() f:Hide() end)

  -- fw1 walk defect 2: the body starts a clear gap below the search box (DT.bodyTop).
  local top = DT.bodyTop(o.search)
  if o.search then
    local e = CreateFrame("EditBox", nil, f, "BackdropTemplate")
    vp.search = e
    e:SetAutoFocus(false)
    e:SetHeight(SEARCH_H)
    e:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -(pad + TITLE_H))
    e:SetPoint("TOPRIGHT", f, "TOPRIGHT", -pad, -(pad + TITLE_H))
    e:SetTextInsets(6, 6, 0, 0)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    e:SetScript("OnTextChanged", function(self)
      if o.onSearch then o.onSearch(self:GetText() or "") end
    end)
  end
  vp.top = top

  vp.body = CreateFrame("Frame", nil, f)
  vp.body:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -top)
  vp.body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -pad, pad + (o.footer or 0))

  f:SetScript("OnShow", function() if o.onShow then o.onShow(vp) end end)

  DT.skin(function()
    DT.paint(f)
    DT.fontTo(vp.title, "title")
    if vp.search then
      DT.paint(vp.search, true)
      vp.search:SetBackdropColor(DT.colour("input"))
      local p, size, flags = DT.font("body")
      vp.search:SetFont(p, size, flags)
      vp.search:SetTextColor(DT.colour("text"))
    end
  end)

  function vp:Show() if DT.isMember() then f:Show() end end
  function vp:Hide() f:Hide() end
  function vp:IsShown() return f:IsShown() and true or false end
  function vp:Toggle() if self:IsShown() then self:Hide() else self:Show() end end
  DT.viewports[o.id] = vp
  return vp
end

-- ---------------------------------------------------------------- the list widget

-- The model: rows (tables with .search, the text the filter looks in), a query, the visible rows.
-- The filter is case-insensitive plain text, applied as you type.
function DT.listModel()
  local m = { rows = {}, shown = {}, query = "" }
  function m:apply()
    local q = (DT.trim(self.query) or ""):lower()
    local out = {}
    for _, r in ipairs(self.rows) do
      local hay = tostring(r.search or r.text or ""):lower()
      if q == "" or hay:find(q, 1, true) then out[#out + 1] = r end          -- guard: list filter
    end
    self.shown = out
    return out
  end
  function m:set(rows) self.rows = rows or {}; return self:apply() end
  function m:filter(q) self.query = tostring(q or ""); return self:apply() end
  function m:visible() return self.shown end
  return m
end

-- Text height: a font string's own wrapped height (GetStringHeight, once its width and text are
-- set), else an estimate from its one-line width. Rows and settings cards are sized from it (fw1
-- walk defects 1 and 4: long text overlapped the next row).
local LINE_H = 14
function DT.textHeight(fs, width)
  if not fs then return LINE_H end
  if fs.SetWidth and width then fs:SetWidth(width) end
  local h = fs.GetStringHeight and fs:GetStringHeight()
  if type(h) == "number" and h > 0 then return h end
  local w = fs.GetStringWidth and fs:GetStringWidth()
  if type(w) ~= "number" or w <= 0 then return LINE_H end
  if not width or width <= 0 then return LINE_H end
  return math.ceil(w / width) * LINE_H
end

-- A row's height: its tallest cell plus padding, never less than the minimum.
function DT.rowHeight(heights, min, pad)
  local tall = 0
  for _, h in ipairs(heights) do if type(h) == "number" and h > tall then tall = h end end
  return math.max(min or 0, tall + (pad or 0))
end

-- The view: `count` rows of columns, scrolled by the mouse wheel. opts = { columns = { { key, width,
-- colour } }, rowHeight (the minimum), onClick = fn(row, button), tip = fn(row, tooltip),
-- empty = text shown when nothing is listed, or fn(model, visible) -> text or nil }. list:refresh() redraws from the model; each row is
-- as tall as its wrapped text.
function DT.list(parent, model, opts)
  local L = { model = model, offset = 0, rows = {} }
  local rh = opts.rowHeight or DT.style("spacing.row")
  local count = opts.count or 16
  L.frame = CreateFrame("Frame", nil, parent)
  L.frame:SetAllPoints(parent)
  L.frame:EnableMouseWheel(true)
  if L.frame.SetClipsChildren then L.frame:SetClipsChildren(true) end
  L.empty = L.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  L.empty:SetPoint("TOPLEFT", L.frame, "TOPLEFT", 4, -4)
  L.empty:SetPoint("RIGHT", L.frame, "RIGHT", -4, 0)
  L.empty:SetJustifyH("LEFT")
  L.empty:Hide()
  for i = 1, count do
    local b = CreateFrame("Button", nil, L.frame)
    b:SetHeight(rh)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.cells = {}
    local x = 4
    for c, col in ipairs(opts.columns) do
      local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      fs:SetPoint("TOPLEFT", b, "TOPLEFT", x, -2)
      fs:SetWidth(col.width)
      fs:SetJustifyH("LEFT")
      if fs.SetWordWrap then fs:SetWordWrap(true) end
      b.cells[c] = fs
      x = x + col.width + 6
    end
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(_, button) if b.row and opts.onClick then opts.onClick(b.row, button) end end)
    b:SetScript("OnEnter", function()
      b.bg:SetColorTexture(DT.colour("rowHover"))
      if b.row and opts.tip then
        local tt = DT.tooltip()
        tt:SetOwner(b, "ANCHOR_RIGHT")
        opts.tip(b.row, tt)
        tt:Show()
      end
    end)
    b:SetScript("OnLeave", function()
      b.bg:SetColorTexture(DT.colour(i % 2 == 0 and "row" or "bg"))
      if opts.tip and DT._tooltip then DT._tooltip:Hide() end
    end)
    L.rows[i] = b
  end
  function L:refresh()
    local vis = self.model:visible()
    if self.model.query ~= self.lastQuery then self.offset = 0; self.lastQuery = self.model.query end
    local maxOff = math.max(0, #vis - count)
    if self.offset > maxOff then self.offset = maxOff end
    local y = 0
    for i, b in ipairs(self.rows) do
      local r = vis[self.offset + i]
      b.row = r
      local hs = {}
      for c, col in ipairs(opts.columns) do
        b.cells[c]:SetText(r and DT.safe(r[col.key], 64) or "")
        hs[c] = r and DT.textHeight(b.cells[c], col.width) or 0
      end
      if r then
        local h = DT.rowHeight(hs, rh, 4)                                -- guard: row fits its text
        b:SetHeight(h)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -y)
        b:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, -y)
        b.top = y
        y = y + h
        b:Show()
      else
        b:Hide()
      end
    end
    self.height = y
    local e
    if type(opts.empty) == "function" then e = opts.empty(self.model, vis)
    elseif #vis == 0 then e = opts.empty end
    if e then
      self.empty:ClearAllPoints()
      self.empty:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 4, -(y + 4))
      self.empty:SetPoint("RIGHT", self.frame, "RIGHT", -4, 0)
      self.empty:SetText(e)
      self.empty:Show()
    else
      self.empty:Hide()
    end
  end
  L.frame:SetScript("OnMouseWheel", function(_, delta)
    L.offset = math.max(0, L.offset - delta)
    L:refresh()
  end)
  DT.skin(function()
    for i, b in ipairs(L.rows) do
      b.bg:SetColorTexture(DT.colour(i % 2 == 0 and "row" or "bg"))
      for c, col in ipairs(opts.columns) do DT.fontTo(b.cells[c], "body", col.colour) end
    end
    DT.fontTo(L.empty, "body", "muted")
  end)
  return L
end

-- ---------------------------------------------------------------- toasts

-- One toast style. Nothing toasts unless the module's setting is on: DT.toast(module, settingKey,
-- text) shows only while DT.get(module, settingKey) is true (and only inside the guild).
-- /dt toast test shows one because it was asked for.
local TEST_TOAST = "Dead Tired toasts look like this."
local toastFrame, toastSeq = nil, 0

local function showToast(text)
  if not DT.isMember() then return false end
  if not toastFrame then
    toastFrame = CreateFrame("Frame", "DeadTiredToast", UIParent, "BackdropTemplate")
    toastFrame:SetSize(280, 44)
    toastFrame:SetFrameStrata("HIGH")
    toastFrame:SetPoint("TOP", UIParent, "TOP", 0, -140)
    toastFrame.text = toastFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    toastFrame.text:SetPoint("CENTER", toastFrame, "CENTER", 0, 0)
    toastFrame.text:SetWidth(260)
    DT.skin(function()
      DT.paint(toastFrame)
      DT.fontTo(toastFrame.text, "body")
    end)
  end
  toastFrame.text:SetText(DT.safe(text, 120))
  toastFrame:Show()
  toastSeq = toastSeq + 1
  local mine = toastSeq
  DT.after(4, function() if mine == toastSeq then toastFrame:Hide() end end)
  DT.toasted = (DT.toasted or 0) + 1
  return true
end

function DT.toast(id, key, text)
  if DT.get(id, key) ~= true then return false end                         -- guard: toast gate
  return showToast(text)
end

DT.module({
  id = "ui",
  title = "Windows",
  verbs = {
    { verb = "toast test", usage = "toast test", fn = function() showToast(TEST_TOAST) end },
  },
})

DT._ui = { TEST_TOAST = TEST_TOAST, toastFrame = function() return toastFrame end }
