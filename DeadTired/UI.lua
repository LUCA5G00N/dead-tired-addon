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
--
-- Fix round 4 (R-F4-1, R-F4-2): every piece of text DT draws is made here, by DT.text, the only
-- caller of CreateFontString in DeadTired/ (tests/test_textfit.lua enforces it). Three kinds:
--   line   one line at a stated width, word wrap off; DT cuts it itself (DT.fitLine) with "…".
--   block  bounded left and right, wrapped; its owner sizes from DT.textHeight (the box).
--   label  one line, unbounded; only where the parent is sized from the text (bar buttons).
-- Text is measured with GetStringWidth on one hidden string per font role (DT.measure); none of
-- the client's truncation calls are used. Every string is recorded (window, kind, box) for
-- /dt debug fit (DT.fitFaults below; the verb is in Debug.lua).
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

-- ---------------------------------------------------------------- text (fix round 4)

local ELLIPSIS = "\226\128\166"         -- "…", UTF-8
DT.ELLIPSIS = ELLIPSIS
local KINDS = { line = true, block = true, label = true }
DT.texts = {}                           -- every string DT.text made, in order: the records
local recs = setmetatable({}, { __mode = "k" })   -- fontstring -> its record
DT.lists = {}                           -- every DT.list, for /dt debug fit

-- One hidden string per font role, fonted from the current skin at each measure.
local measureHost, measurers = nil, {}
local function measurer(role)
  local fs = measurers[role]
  if fs then return fs end
  if not measureHost then
    measureHost = CreateFrame("Frame", nil, UIParent)
    measureHost:Hide()
  end
  fs = measureHost:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  if fs.SetWordWrap then fs:SetWordWrap(false) end
  measurers[role] = fs
  return fs
end

local function widthOf(fs, text)
  fs:SetText(text)
  local ok, w = pcall(fs.GetStringWidth, fs)
  if not ok or type(w) ~= "number" or DT.secret(w) then return nil, w end
  return w
end

-- The width of `text` in font role `role` (title, body, small) under the current skin. A
-- non-number, or a width <= 0 for non-empty text, is counted under errors["ui:measure"] and
-- nil is returned: the caller treats the text as fitting (R-F4-2).
function DT.measure(text, role, fs)
  text = text == nil and "" or tostring(text)
  if text == "" then return 0 end
  role = role or "body"
  if not fs then
    fs = measurer(role)
    local p, size, flags = DT.font(role)
    if fs.SetFont then fs:SetFont(p, size, flags) end
  end
  local w, raw = widthOf(fs, text)
  if not w or w <= 0 then                                                  -- guard: measure failure counted
    DT.fail("ui:measure", role, "width " .. tostring(w or raw))
    return nil
  end
  return w
end

-- The byte positions where `text` may be cut: after each whole UTF-8 character, never inside an
-- escaped "||" pair (DT.safe's escape).
local function cuts(text)
  local out, i, n = {}, 1, #text
  while i <= n do
    local j = (text:sub(i, i + 1) == "||") and i + 1 or i
    while j < n and (text:byte(j + 1) or 0) >= 128 and (text:byte(j + 1) or 0) < 192 do j = j + 1 end  -- guard: whole characters only
    out[#out + 1] = j
    i = j + 1
  end
  return out
end
DT._cuts = cuts

-- R-F4-1: `text` unchanged when it fits `width` in role `role`; else the longest prefix, cut on
-- a character boundary, that fits with "…" after it. Returns the text and whether it was cut.
-- `fs` (optional) measures with that string's own font instead of the role's (fixed fonts).
function DT.fitLine(text, width, role, fs)
  text = text == nil and "" or tostring(text)
  if text == "" or type(width) ~= "number" then return text, false end
  local w = DT.measure(text, role, fs)
  if not w or w <= width then return text, false end                       -- guard: fitLine cuts to the width
  local at = cuts(text)
  local lo, hi, best = 1, #at - 1, nil
  while lo <= hi do
    local mid = math.floor((lo + hi) / 2)
    local cand = (text:sub(1, at[mid]):gsub("%s+$", "")) .. ELLIPSIS
    local cw = DT.measure(cand, role, fs)
    if not cw then return text, false end
    if cw <= width then best = cand; lo = mid + 1 else hi = mid - 1 end
  end
  return best or ELLIPSIS, true
end

-- The window a string belongs to: the nearest parent carrying dtWindow.
local function windowOf(parent)
  local f, n = parent, 0
  while type(f) == "table" and n < 20 do
    if f.dtWindow then return f.dtWindow end
    local ok, p = pcall(function() return f:GetParent() end)
    f = ok and p or nil
    n = n + 1
  end
  return "?"
end

local function refit(rec)
  local fs = rec.fs
  if rec.kind == "line" then
    local t, cut = DT.fitLine(rec.raw, rec.width, rec.role, rec.fixedFont and fs or nil)
    rec.cut = cut
    fs:SetText(t)
  else
    rec.cut = false
    fs:SetText(rec.raw)
  end
end

-- DT.text(parent, kind, opts): opts = { width, role (body), colour, justify (LEFT), layer,
-- template, fixedFont = true (not skinned: the log dialogs), window (else the parent's),
-- inset (a label: room its parent keeps beside it) }. Returns the font string; its text is set
-- with DT.setText.
function DT.text(parent, kind, opts)
  if not KINDS[kind] then error("DT.text: kind must be line, block or label", 2) end
  opts = opts or {}
  local fs = parent:CreateFontString(nil, opts.layer or "OVERLAY", opts.template or "GameFontHighlight")
  local rec = { fs = fs, kind = kind, role = opts.role or "body", colour = opts.colour, fixedFont = opts.fixedFont,
    window = opts.window or windowOf(parent), parent = parent, raw = "", inset = opts.inset or 0 }
  recs[fs] = rec
  DT.texts[#DT.texts + 1] = rec
  if fs.SetJustifyH then fs:SetJustifyH(opts.justify or "LEFT") end
  if fs.SetWordWrap then fs:SetWordWrap(kind == "block") end
  if opts.width then rec.width = opts.width; fs:SetWidth(opts.width) end
  if not opts.fixedFont then
    DT.skin(function()
      DT.fontTo(fs, rec.role, rec.colour)
      refit(rec)
    end)
  end
  return fs
end

function DT.textRecord(fs) return recs[fs] end

-- Set a DT string's text: a line is cut to its width (R-F4-1). Returns true when it was cut.
function DT.setText(fs, text)
  text = text == nil and "" or tostring(text)
  local rec = recs[fs]
  if not rec then fs:SetText(text) return false end
  rec.raw = text
  refit(rec)
  return rec.cut
end

-- A line's width changes: the text is cut again.
function DT.setWidth(fs, width)
  local rec = recs[fs]
  fs:SetWidth(width)
  if not rec then return end
  rec.width = width
  refit(rec)
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
--              footer = "<text>": a wrapped line under the body (fix round 4: the text, never a
--                       pixel count; the body is inset by its measured height),
--              sticky = true: Escape leaves it open (R-P2-2's opt-out) }
local CLOSE_W = 32                      -- the close button's room at the title's right
local FOOTER_Y = 6                      -- the footer's bottom, above the frame's edge
function DT.viewport(o)
  if DT.viewports[o.id] then return DT.viewports[o.id] end
  if o.footer ~= nil and type(o.footer) ~= "string" then error("DT.viewport: footer takes text", 2) end
  local vp = { id = o.id }
  local name = "DeadTiredViewport_" .. o.id
  local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  vp.frame = f
  vp.name = name
  f.dtWindow = o.id
  if not o.sticky then DT.closeOnEscape(name) end
  local width = o.width or 360
  vp.width = width
  f:SetSize(width, o.height or 420)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:Hide()
  DT.restorePlace(f, "viewport." .. o.id, { "CENTER", "CENTER", 0, 0 })
  DT.draggable(f, "viewport." .. o.id)

  local pad = DT.style("spacing.pad")
  -- the title: one line, ending left of the close button
  vp.title = DT.text(f, "line", { role = "title", width = width - pad - 4 - CLOSE_W - 4 })
  vp.title:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -pad)
  DT.setText(vp.title, o.title or o.id)

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
  vp.body.dtWidth = width - 2 * pad       -- the declared width lists take their flex column from
  vp.body:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -top)

  -- the footer: a block between the paddings; the body ends above its measured height
  if o.footer then
    vp.footer = DT.text(f, "block", { role = "small", colour = "muted", width = width - 2 * pad })
    vp.footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", pad, FOOTER_Y)
    DT.setText(vp.footer, o.footer)
  end
  local function inset()
    local h = vp.footer and DT.textHeight(vp.footer, width - 2 * pad) or 0
    vp.footerH = h
    vp.body:ClearAllPoints()
    vp.body:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -top)
    vp.body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -pad, pad + math.ceil(h))   -- guard: footer insets the body
    vp.bodyBottom = pad + math.ceil(h)
  end
  inset()

  f:SetScript("OnShow", function() if o.onShow then o.onShow(vp) end end)

  DT.skin(function()
    DT.paint(f)
    inset()
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
-- set), else an estimate from its one-line width. Settings cards, footers and the toast are sized
-- from it (fw1 walk defects 1 and 4). For a DT block the height measured here is its box: the
-- owner sizes from it, and /dt debug fit checks the text still fits it. A DT line given a new
-- width is cut again.
local LINE_H = 14
function DT.textHeight(fs, width)
  if not fs then return LINE_H end
  local rec = recs[fs]
  if fs.SetWidth and width then
    fs:SetWidth(width)
    if rec then rec.width = width; if rec.kind == "line" then refit(rec) end end
  end
  local h = fs.GetStringHeight and fs:GetStringHeight()
  if type(h) ~= "number" or h <= 0 then
    local w = fs.GetStringWidth and fs:GetStringWidth()
    if type(w) ~= "number" or w <= 0 then h = (rec and rec.raw == "") and 0 or LINE_H
    elseif not width or width <= 0 then h = LINE_H
    else h = math.ceil(w / width) * LINE_H end
  end
  if rec and rec.kind == "block" then rec.boxH = h end
  return h
end

-- The view (fix round 4, R-F4-1): `count` rows of columns, scrolled by the mouse wheel. Every row
-- is one line and one height. opts = { columns = { { key, colour, and one of: fixed = true (as wide
-- as the widest value in the model at the current font), width = n (static), flex = true (the rest
-- of the list's width) } }, width (else the viewport's declared body width), rowHeight,
-- onClick = fn(row, button), tip = fn(row, tooltip), empty = text shown when nothing is listed, or
-- fn(model, visible) -> text or nil }. Exactly one flex column, or DT.list raises. A cell cut
-- with "…" has its full text in the row's tooltip, after the module's own lines; a list with no
-- tip shows a tooltip only for a cut row. list:refresh() redraws from the model.
local LEFT, GAP, RIGHT = 4, 6, 4
local FLEX_MIN = 60
DT.FLEX_MIN = FLEX_MIN
local function cellText(r, key) return DT.safe(r[key], 255) end

function DT.list(parent, model, opts)
  local flexes = 0
  for _, col in ipairs(opts.columns) do if col.flex then flexes = flexes + 1 end end
  if flexes ~= 1 then error("DT.list: exactly one flex column (" .. flexes .. " given)", 2) end   -- guard: exactly one flex column
  local total = opts.width or (parent and parent.dtWidth)
  if type(total) ~= "number" or total <= 0 then error("DT.list: no declared width", 2) end
  local L = { model = model, offset = 0, rows = {}, columns = opts.columns, total = total }
  local rh = opts.rowHeight or DT.style("spacing.row")
  L.rowH = rh
  local count = opts.count or 16
  L.frame = CreateFrame("Frame", nil, parent)
  L.frame:SetAllPoints(parent)
  L.frame:EnableMouseWheel(true)
  if L.frame.SetClipsChildren then L.frame:SetClipsChildren(true) end
  L.empty = DT.text(L.frame, "block", { colour = "muted", width = total - LEFT - RIGHT })
  L.empty:SetPoint("TOPLEFT", L.frame, "TOPLEFT", LEFT, -4)
  L.empty:Hide()
  L.window = windowOf(parent)

  -- Column widths: fixed from the widest value in the model, static as given, flex the rest.
  function L:widths()
    local used = LEFT + RIGHT + GAP * (#self.columns - 1)
    for _, col in ipairs(self.columns) do
      if col.fixed then
        local widest = 0
        for _, r in ipairs(self.model.rows or {}) do
          local w = DT.measure(cellText(r, col.key), "body") or 0
          if w > widest then widest = w end                                -- guard: fixed column from its widest value
        end
        col.w = math.ceil(widest) + 2
        col.widest = widest
      elseif not col.flex then
        col.w = col.width or 0
      end
      if not col.flex then used = used + col.w end
    end
    for _, col in ipairs(self.columns) do if col.flex then col.w = self.total - used end end
    local x = LEFT
    for c, col in ipairs(self.columns) do
      col.x = x
      for _, b in ipairs(self.rows) do
        local fs = b.cells[c]
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", b, "TOPLEFT", x, -2)
        DT.setWidth(fs, col.w)
      end
      x = x + col.w + GAP
    end
    self.measured = self.model.rows
  end

  for i = 1, count do
    local b = CreateFrame("Button", nil, L.frame)
    b:SetHeight(rh)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.cells = {}
    for c, col in ipairs(opts.columns) do
      b.cells[c] = DT.text(b, "line", { colour = col.colour, width = col.width or 0 })
    end
    b.cut = {}
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(_, button) if b.row and opts.onClick then opts.onClick(b.row, button) end end)
    b:SetScript("OnEnter", function()
      b.bg:SetColorTexture(DT.colour("rowHover"))
      if b.row and (opts.tip or #b.cut > 0) then
        local tt = DT.tooltip()
        tt:SetOwner(b, "ANCHOR_RIGHT")
        if opts.tip then opts.tip(b.row, tt) end
        for _, full in ipairs(b.cut) do tt:AddLine(full, 1, 1, 1, true) end    -- guard: a cut cell's full text in the tooltip
        tt:Show()
      end
    end)
    b:SetScript("OnLeave", function()
      b.bg:SetColorTexture(DT.colour(i % 2 == 0 and "row" or "bg"))
      if DT._tooltip then DT._tooltip:Hide() end
    end)
    L.rows[i] = b
  end
  function L:refresh()
    if self.measured ~= self.model.rows then self:widths() end
    local vis = self.model:visible()
    if self.model.query ~= self.lastQuery then self.offset = 0; self.lastQuery = self.model.query end
    local maxOff = math.max(0, #vis - count)
    if self.offset > maxOff then self.offset = maxOff end
    local y = 0
    for i, b in ipairs(self.rows) do
      local r = vis[self.offset + i]
      b.row = r
      b.cut = {}
      for c, col in ipairs(self.columns) do
        local full = r and cellText(r, col.key) or ""
        if DT.setText(b.cells[c], full) then b.cut[#b.cut + 1] = full end
      end
      if r then
        b:SetHeight(rh)                                                    -- guard: every row one height
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -y)
        b:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, -y)
        b.top = y
        y = y + rh
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
      self.empty:SetPoint("TOPLEFT", self.frame, "TOPLEFT", LEFT, -(y + 4))
      DT.setText(self.empty, e)
      DT.textHeight(self.empty, self.total - LEFT - RIGHT)
      self.empty:Show()
    else
      self.empty:Hide()
    end
  end
  -- Rows cut at the current widths, over every row in the model (for /dt debug fit).
  function L:cutRows()
    local n = 0
    for _, r in ipairs(self.model.rows or {}) do
      for _, col in ipairs(self.columns) do
        local w = DT.measure(cellText(r, col.key), "body")
        if w and col.w and w > col.w then n = n + 1 break end
      end
    end
    return n
  end
  L.frame:SetScript("OnMouseWheel", function(_, delta)
    L.offset = math.max(0, L.offset - delta)
    L:refresh()
  end)
  L:widths()
  DT.skin(function()
    for i, b in ipairs(L.rows) do b.bg:SetColorTexture(DT.colour(i % 2 == 0 and "row" or "bg")) end
    L:widths()
    L:refresh()
  end)
  DT.lists[#DT.lists + 1] = L
  return L
end

-- ---------------------------------------------------------------- toasts

-- One toast style. Nothing toasts unless the module's setting is on: DT.toast(module, settingKey,
-- text) shows only while DT.get(module, settingKey) is true (and only inside the guild).
-- /dt toast test shows one because it was asked for.
local TEST_TOAST = "Dead Tired toasts look like this."
local toastFrame, toastSeq = nil, 0
local TOAST_W, TOAST_TEXT_W, TOAST_MIN_H, TOAST_PAD = 280, 260, 44, 12

-- The toast is as tall as its text (a block) plus padding, never under its 0.3.0 height.
local function toastSize()
  if not (toastFrame and toastFrame.text) then return end
  local h = DT.textHeight(toastFrame.text, TOAST_TEXT_W)
  toastFrame:SetSize(TOAST_W, math.max(TOAST_MIN_H, math.ceil(h) + 2 * TOAST_PAD))
end

local function buildToast()
  if not toastFrame then
    toastFrame = CreateFrame("Frame", "DeadTiredToast", UIParent, "BackdropTemplate")
    toastFrame:SetSize(TOAST_W, TOAST_MIN_H)
    toastFrame:SetFrameStrata("HIGH")
    toastFrame:SetPoint("TOP", UIParent, "TOP", 0, -140)
    toastFrame.dtWindow = "toast"
    toastFrame.text = DT.text(toastFrame, "block", { width = TOAST_TEXT_W, justify = "CENTER" })
    toastFrame.text:SetPoint("CENTER", toastFrame, "CENTER", 0, 0)
    DT.skin(function()
      DT.paint(toastFrame)
      toastSize()
    end)
    toastFrame:Hide()
  end
  return toastFrame
end

local function showToast(text)
  if not DT.isMember() then return false end
  buildToast()
  DT.setText(toastFrame.text, DT.safe(text, 120))
  toastSize()
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

-- ---------------------------------------------------------------- /dt debug fit (fix round 4)

local function head(text)
  text = tostring(text or "")
  local at, keep = cuts(text), 0
  for _, j in ipairs(at) do if j <= 24 then keep = j else break end end
  return DT.safe(text:sub(1, keep), 48)
end
local function px(n) return string.format("%d", math.ceil((tonumber(n) or 0) - 0.001)) end

-- The faults under the current skin: { { window, kind, text, measured, box } ... }, and how many
-- things were checked. Faults (R-F4-1): a block taller than its box; a label wider than its
-- parent; a fixed column narrower than its widest value; a flex column under 60; a line with no
-- width. Cut rows are counted, not faults.
function DT.fitFaults()
  local faults, checked, rowsCut = {}, 0, 0
  local function fault(window, kind, text, measured, box)
    faults[#faults + 1] = { window = window, kind = kind, text = head(text), measured = px(measured), box = px(box) }
  end
  for _, rec in ipairs(DT.texts) do
    checked = checked + 1
    local fs = rec.fs
    if rec.kind == "line" then
      if type(rec.width) ~= "number" or rec.width <= 0 then fault(rec.window, "line", rec.raw, 0, 0) end
    elseif rec.kind == "block" then
      local ok, h = pcall(fs.GetStringHeight, fs)
      h = (ok and type(h) == "number") and h or 0
      local box = rec.boxH or 0
      if h > box + 0.5 then fault(rec.window, "block", rec.raw, h, box) end
    elseif rec.kind == "label" then
      local w = DT.measure(rec.raw, rec.role) or 0
      local ok, pw = pcall(rec.parent.GetWidth, rec.parent)
      pw = (ok and type(pw) == "number") and pw or 0
      if w + rec.inset > pw + 0.5 then fault(rec.window, "label", rec.raw, w + rec.inset, pw) end
    end
  end
  for _, L in ipairs(DT.lists) do
    for _, col in ipairs(L.columns) do
      checked = checked + 1
      if col.fixed then
        local widest, text = 0, ""
        for _, r in ipairs(L.model.rows or {}) do
          local t = cellText(r, col.key)
          local w = DT.measure(t, "body") or 0
          if w > widest then widest, text = w, t end
        end
        if (col.w or 0) < widest then fault(L.window, "fixed", text, widest, col.w) end
      elseif col.flex and (col.w or 0) < FLEX_MIN then
        fault(L.window, "flex", col.key, col.w, FLEX_MIN)
      end
    end
    rowsCut = rowsCut + L:cutRows()
  end
  return faults, checked, rowsCut
end

-- The whole check: every module's fit (it builds its windows, hidden, printing nothing), then
-- each skin in turn, applied in memory only (DT.fitSkin; the saved choice is never read for it,
-- never written) and the saved one restored. Returns the lines /dt debug fit prints.
function DT.fitCheck()
  local errs = DT.db().errors
  local before = errs["ui:measure"] or 0
  for _, m in ipairs(DT.modules) do
    if type(m.fit) == "function" and DT.enabled(m.id) then
      local ok, err = pcall(m.fit)
      if not ok then DT.fail(m.id, "fit", err) end
    end
  end
  local names = {}
  for name in pairs(DT.skins) do names[#names + 1] = name end
  table.sort(names)
  local lines, over, checked, cut = {}, 0, 0, 0
  for _, name in ipairs(names) do
    DT.fitSkin = name
    DT.restyle()
    local faults, n, k = DT.fitFaults()
    checked, cut = checked + n, cut + k
    for _, f in ipairs(faults) do
      over = over + 1
      lines[#lines + 1] = "fit: " .. name .. " " .. tostring(f.window) .. " " .. f.kind .. ' "' .. f.text .. '" '
        .. f.measured .. "/" .. f.box
    end
  end
  DT.fitSkin = nil                                                         -- guard: debug fit restores the skin
  DT.restyle()
  local failures = (errs["ui:measure"] or 0) - before
  lines[#lines + 1] = "fit: " .. checked .. " checked, " .. over .. " over, " .. cut .. " rows cut, measure failures " .. failures
  return lines
end

DT.module({
  id = "ui",
  title = "Windows",
  verbs = {
    { verb = "toast test", usage = "toast test", fn = function() showToast(TEST_TOAST) end },
  },
  fit = function() local t = buildToast(); if not t:IsShown() then DT.setText(t.text, TEST_TOAST); toastSize() end end,
})

DT._ui = { TEST_TOAST = TEST_TOAST, toastFrame = function() return toastFrame end }
