-- The taint guard (static): every DeadTired/*.lua (not Libs/, not tests/) is scanned for a write to
-- a global that isn't DT's own, for hooksecurefunc, and for Set*/Show/Hide calls on a global frame
-- DT didn't create (tests/taint_scan.lua). The scanner is proved on a sample first.
-- lua5.1 DeadTired/tests/test_taint.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local S = dofile(dir .. "/taint_scan.lua")
local check = H.check

local function tmpfile(body)
  local path = os.tmpname()
  local f = assert(io.open(path, "w"))
  f:write(body)
  f:close()
  return path
end

-- ---------------------------------------------------------------- the scanner, on a sample
do
  local sample = table.concat({
    'SlashCmdList = SlashCmdList or {}',               -- 1  rc3's Core.lua:305: flagged
    'SlashCmdList["DEADTIRED"] = function() end',      -- 2  ours: allowed
    'local x = UIParent:GetScale()',                   -- 3  a read: allowed
    'UIParent:Hide()',                                 -- 4  flagged
    'GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")',   -- 5  flagged
    '_G.Foo = 1',                                      -- 6  flagged
    'hooksecurefunc("SendChatMessage", print)',        -- 7  flagged
    'local f = CreateFrame("Frame"); f:Show()',        -- 8  our own frame: allowed
    'DeadTiredDB = {}',                                -- 9  ours: allowed
    'ChatFrame1.foo = 2',                              -- 10 flagged
    'local t = ChatFrame1; t:SetScript("OnShow", nil)',-- 11 flagged through a local
    'SlashCmdList.PLAYED = nil',                       -- 12 flagged
    'local function g() Minimap:SetParent(nil) end',   -- 13 flagged inside a function
    'SLASH_DEADTIRED3 = "/rip"',                       -- 14 ours: allowed
    'DEFAULT_CHAT_FRAME:AddMessage("x")',              -- 15 not a change to the frame: allowed
    'rawset(_G, "Bar", 1)',                            -- 16 flagged
    '-- hooksecurefunc in a comment is not code',      -- 17 allowed
    'local s = "UIParent:Hide()"',                     -- 18 a string: allowed
    'local n = SlashCmdList and SlashCmdList.DEADTIRED',-- 19 a read: allowed
  }, "\n")
  local path = tmpfile(sample)
  local hits = S.scanFile(path)
  os.remove(path)
  local lines = {}
  for _, h in ipairs(hits) do lines[#lines + 1] = h.line end
  table.sort(lines)
  local got = table.concat(lines, ",")
  check("scanner: flags exactly the bad lines of the sample (1,4,5,6,7,10,11,12,13,16)", got == "1,4,5,6,7,10,11,12,13,16")
  if got ~= "1,4,5,6,7,10,11,12,13,16" then
    for _, h in ipairs(hits) do print("  hit " .. h.line .. ": " .. h.what) end
  end
end

-- ---------------------------------------------------------------- R-P2-2: UISpecialFrames, insert only
do
  local sample = table.concat({
    'local name = "DeadTiredViewport_x"',                    -- 1
    'if type(UISpecialFrames) ~= "table" then return end',   -- 2  the type check: allowed
    'table.insert(UISpecialFrames, name)',                   -- 3  the one allowed call
    'table.insert(UISpecialFrames, "DeadTired" .. name:upper())', -- 4 allowed (two arguments)
    'table.remove(UISpecialFrames, 1)',                      -- 5  a removal: flagged
    'UISpecialFrames[1] = nil',                              -- 6  an assignment into it: flagged
    'table.insert(UISpecialFrames, 1, name)',                -- 7  an insert at a position (reorders): flagged
    'local t = UISpecialFrames',                             -- 8  a copy: flagged
    'wipe(UISpecialFrames)',                                 -- 9  any other call: flagged
    'local n = #UISpecialFrames',                            -- 10 any other read: flagged
    'local g = _G["UISpecialFrames"]',                       -- 11 by _G: flagged
    'UISpecialFrames = {}',                                  -- 12 replaced: flagged
    'local ok = table.insert(UISpecialFrames, name)',        -- 13 a result taken: flagged
    'for i = #UISpecialFrames, 1, -1 do end',                -- 14 flagged
    '-- table.remove(UISpecialFrames) in a comment',         -- 15 allowed
  }, "\n")
  local path = tmpfile(sample)
  local hits = S.scanFile(path)
  os.remove(path)
  local seen, lines = {}, {}
  for _, h in ipairs(hits) do if not seen[h.line] then seen[h.line] = true; lines[#lines + 1] = h.line end end
  table.sort(lines)
  local got = table.concat(lines, ",")
  check("R-P2-2 scanner: only table.insert(UISpecialFrames, <name>) and type() pass (flags 5,6,7,8,9,10,11,12,13,14)",
    got == "5,6,7,8,9,10,11,12,13,14")
  if got ~= "5,6,7,8,9,10,11,12,13,14" then
    for _, h in ipairs(hits) do print("  hit " .. h.line .. ": " .. h.what) end
  end
end

-- ---------------------------------------------------------------- every DT file
local files = {}
local p = io.popen('ls "' .. H.addonDir .. '"/*.lua')
for f in p:lines() do files[#files + 1] = f end
p:close()
check("scanned every DT file (Config, Core and the modules)", #files >= 12)
local all = {}
for _, f in ipairs(files) do
  local hits, err = S.scanFile(f)
  check("scan read " .. f:match("[^/]+$"), hits ~= nil)
  if not hits then print("  " .. tostring(err)) end
  for _, h in ipairs(hits or {}) do all[#all + 1] = h end
end
check("taint scan: no hits in DeadTired/*.lua", #all == 0)
for _, h in ipairs(all) do print("  " .. h.file .. ":" .. h.line .. " " .. h.what) end

-- ---------------------------------------------------------------- rc3's line, inserted into a copy of Core.lua
do
  local src = io.open(H.addonDir .. "/Core.lua"):read("*a")
  local bad = src:gsub('SLASH_DEADTIRED1 = "/dt"', 'SLASH_DEADTIRED1 = "/dt"\nSlashCmdList = SlashCmdList or {}', 1)
  local path = tmpfile(bad)
  local hits = S.scanFile(path)
  os.remove(path)
  check("rc3's SlashCmdList = SlashCmdList or {} in a copy of Core.lua: the scan goes red",
    #hits == 1 and hits[1].what == "assigns the global SlashCmdList")
end

-- ---------------------------------------------------------------- R-P2-2 in the addon itself
do
  -- exactly one place touches UISpecialFrames: UI.lua's DT.closeOnEscape (its type check and its insert)
  local where = {}
  for _, f in ipairs(files) do
    local p2 = io.popen('luac5.1 -p -l "' .. f .. '" 2>&1')
    local listing = p2:read("*a")
    p2:close()
    local n = select(2, listing:gsub("GETGLOBAL[^\n]*; UISpecialFrames", ""))
    if n > 0 then where[#where + 1] = f:match("[^/]+$") .. ":" .. n end
  end
  check("R-P2-2: only UI.lua reads UISpecialFrames (once to check it, once to insert)", table.concat(where, ",") == "UI.lua:2")
  local src = io.open(H.addonDir .. "/UI.lua"):read("*a")
  for _, bad in ipairs({
      { "a removal", "  escaped[name] = true", "  escaped[name] = true\n  table.remove(UISpecialFrames, 1)" },
      { "an insert at the front", "table.insert(UISpecialFrames, name)", "table.insert(UISpecialFrames, 1, name)" },
      { "a replaced table", "  escaped[name] = true", "  escaped[name] = true\n  UISpecialFrames = { name }" } }) do
    local a = src:find(bad[2], 1, true)
    local copy = src:sub(1, a - 1) .. bad[3] .. src:sub(a + #bad[2])
    local path = tmpfile(copy)
    local hs = S.scanFile(path)
    os.remove(path)
    check("R-P2-2: " .. bad[1] .. " in a copy of UI.lua: the scan goes red", #hs >= 1)
  end
end

H.finish("taint")
