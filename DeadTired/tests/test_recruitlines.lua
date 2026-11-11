-- Offline checks for RecruitLines.lua (card 5's data, copied unchanged from rc3 in Port 1): Tim's five
-- lines, byte-identical to docs/RECRUIT_lines.md.  lua5.1 DeadTired/tests/test_recruitlines.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check

local f = assert(io.open(H.addonDir .. "/../docs/RECRUIT_lines.md", "rb"))
local doc = {}
for line in f:read("*a"):gmatch("[^\n]+") do
  local n, text = line:match("^(%d)%. (.+)$")
  if n then doc[tonumber(n)] = text end
end
f:close()
local ns = {}
local chunk = assert(loadfile(H.addonDir .. "/RecruitLines.lua"))
chunk("DeadTired", ns)
local L = ns.Recruit and ns.Recruit.LINES or {}
local same = #L == 5
for i = 1, 5 do same = same and L[i] == doc[i] end
check("RecruitLines.lua holds docs/RECRUIT_lines.md's five lines, byte-identical", same and doc[5] ~= nil)
for i = 1, 5 do check("line " .. i .. " is at most 255 bytes (" .. #(L[i] or "") .. ")", #(L[i] or "") <= 255 and #(L[i] or "") > 0) end
check("channel and cooldown as ratified", ns.Recruit.RECRUIT_CHANNEL == "General" and ns.Recruit.COOLDOWN == 900)
H.finish("recruitlines")
