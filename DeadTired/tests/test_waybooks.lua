-- Offline checks for WayBooks.lua (dt_waypointer W1, 0.5.0): the built-in list's data is well formed.
--   lua5.1 DeadTired/tests/test_waybooks.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check

local w = H.world()
local c = w:client({ guild = "DEAD TIRED" })
local B = c.DT.WAY_BOOKS
check("39 books", type(B) == "table" and #B == 39)
local bad, ids, names = {}, {}, {}
for i, b in ipairs(B) do
  local ok = type(b[1]) == "string" and #b[1] > 0 and type(b[2]) == "string" and #b[2] > 0
    and type(b[3]) == "number" and b[3] >= 0 and b[3] <= 100 and type(b[4]) == "number" and b[4] >= 0 and b[4] <= 100
    and type(b[5]) == "number" and b[5] > 0 and type(b[6]) == "string" and type(b[7]) == "string"
  if not ok then bad[#bad + 1] = i end
  if ids[b[5]] then bad[#bad + 1] = "dup id " .. tostring(b[5]) end
  if names[b[1]] then bad[#bad + 1] = "dup name " .. tostring(b[1]) end
  ids[b[5]], names[b[1]] = true, true
end
check("every row: name, zone, x and y in 0-100, a quest ID, level and note text; no duplicates", #bad == 0)
check("Rumi of Gnomeregan is listed once, with the other inn in its note", (function()
  local n, note = 0, nil
  for _, b in ipairs(B) do if b[1]:find("Rumi of Gnomeregan", 1, true) then n = n + 1; note = b[7] end end
  return n == 1 and note:find("Sentinel Hill", 1, true) ~= nil end)())
check("the source is named", c.DT.WAY_BOOKS_SOURCE == "Coordinates from Warcraft Tavern's Forever book guide.")
check("the data file loads before Way.lua", (function()
  local a, b
  for i, f in ipairs(H.tocFiles()) do if f == "WayBooks.lua" then a = i elseif f == "Way.lua" then b = i end end
  return a and b and a < b end)())

H.finish("waybooks")
