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

H.finish("taint")
