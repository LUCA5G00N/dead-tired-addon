-- The text-fit guard (static, fix round 4, Task 6): every piece of text DT draws is made by DT.text
-- in UI.lua (R-F4-1: modules never create raw text). Every DeadTired/*.lua but UI.lua is read from
-- luac5.1's listing (the bytecode, as taint_scan.lua does, so comments and strings can't fool it):
--   * red on any CreateFontString call (a SELF or a GETTABLE with that constant key);
--   * red on a footer given as a number (a table field footer = <number constant>, anywhere: the
--     viewport takes the footer's text, never a pixel count). DT.viewport also raises at run time
--     on a footer that isn't text (test_ui.lua).
-- The scanner is proved on a fixture first.
-- lua5.1 DeadTired/tests/test_textfit.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check

local function listing(path)
  local p = io.popen('luac5.1 -p -l "' .. path .. '" 2>&1')
  local out = p:read("*a")
  p:close()
  if not out:find("main <", 1, true) then return nil, out end
  return out
end

-- The hits in one file: { line, what }.
local function scan(path)
  local l, err = listing(path)
  if not l then return nil, err end
  local hits = {}
  for row in l:gmatch("[^\n]+") do
    local line, op, args, comment = row:match("^%s+%d+%s+%[(%d+)%]%s+(%u+)%s+([%-%d ]+)%s*;?%s*(.*)$")
    if op == "SELF" or op == "GETTABLE" then
      local c = select(3, args:match("^(%-?%d+)%s*(%-?%d*)%s*(%-?%d*)"))
      if tonumber(c) and tonumber(c) < 0 and comment:match('^"CreateFontString"') then        -- the CreateFontString rule
        hits[#hits + 1] = { line = tonumber(line), what = "CreateFontString" }
      end
    elseif op == "SETTABLE" then
      local k, v = comment:match('^"([^"]*)"%s+(%S+)$')
      if k == "footer" and tonumber(v) then                                                    -- the numeric-footer rule
        hits[#hits + 1] = { line = tonumber(line), what = "footer = " .. v }
      end
    end
  end
  return hits
end

local function tmpfile(body)
  local path = os.tmpname()
  local f = assert(io.open(path, "w"))
  f:write(body)
  f:close()
  return path
end

-- ---------------------------------------------------------------- the scanner, on a fixture
do
  local fixture = table.concat({
    'local f = CreateFrame("Frame")',                             -- 1
    'local a = f:CreateFontString(nil, "OVERLAY")',               -- 2  a raw call: caught
    'local b = f.CreateFontString(f)',                            -- 3  the same, spelled out: caught
    '-- f:CreateFontString() in a comment is not code',           -- 4  allowed
    'local s = "f:CreateFontString()"',                           -- 5  a string: allowed
    'DT.viewport({ id = "x", footer = 16 })',                     -- 6  a pixel footer: caught
    'DT.viewport({ id = "y", footer = "Times are server time." })',-- 7  a text footer: allowed
    'local t = {}; t.footer = 2.5',                               -- 8  a number footer anywhere: caught
    'local c = DT.text(f, "line", { width = 60 })',               -- 9  the helper: allowed
    'local function g(p) return p:CreateFontString() end',        -- 10 inside a function: caught
  }, "\n")
  local path = tmpfile(fixture)
  local hits = scan(path)
  os.remove(path)
  local lines = {}
  for _, h in ipairs(hits or {}) do lines[#lines + 1] = h.line end
  table.sort(lines)
  local got = table.concat(lines, ",")
  check("scanner: catches a raw CreateFontString on the fixture (2, 3, 10) and a numeric footer (6, 8); comments, strings and the helper pass",
    got == "2,3,6,8,10")
  if got ~= "2,3,6,8,10" then for _, h in ipairs(hits or {}) do print("  hit " .. h.line .. ": " .. h.what) end end
  local fx = tmpfile('local f = CreateFrame("Frame")\nlocal a = f:CreateFontString()\n')
  local h1 = scan(fx)
  os.remove(fx)
  check("scanner: red on a fixture with a raw CreateFontString", h1 and #h1 == 1 and h1[1].what == "CreateFontString")
  local fy = tmpfile('DT.viewport({ id = "z", search = true, footer = 16 })\n')
  local h2 = scan(fy)
  os.remove(fy)
  check("scanner: red on a numeric footer", h2 and #h2 == 1 and h2[1].what == "footer = 16")
end

-- ---------------------------------------------------------------- the tree
do
  local p = io.popen('ls "' .. H.addonDir .. '"/*.lua')
  local files = {}
  for f in p:lines() do files[#files + 1] = f end
  p:close()
  check("the scan sees the addon's files", #files >= 20)
  local raw, footers, unreadable, inUI = {}, {}, {}, 0
  for _, path in ipairs(files) do
    local hits, err = scan(path)
    local base = path:match("[^/\\]+$")
    if not hits then unreadable[#unreadable + 1] = base .. ": " .. tostring(err)
    else
      for _, h in ipairs(hits) do
        if h.what == "CreateFontString" then
          if base == "UI.lua" then inUI = inUI + 1 else raw[#raw + 1] = base .. ":" .. h.line end
        else
          footers[#footers + 1] = base .. ":" .. h.line .. " " .. h.what
        end
      end
    end
  end
  check("every file compiles for the scan", #unreadable == 0)
  for _, u in ipairs(unreadable) do print("  " .. u) end
  check("R-F4-1: no CreateFontString outside UI.lua (DT.text is the only maker of text)", #raw == 0)
  for _, r in ipairs(raw) do print("  raw CreateFontString at " .. r) end
  check("R-F4-1: no viewport footer given as a number", #footers == 0)
  for _, r in ipairs(footers) do print("  numeric footer at " .. r) end
  check("UI.lua does call it (the scan isn't blind): DT.text and the measuring string", inUI == 2)
end

H.finish("textfit")
