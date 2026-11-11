-- The taint scan (framework round, Task 9). Reads luac5.1's listing of a file (the bytecode, so
-- comments and strings can't fool it) and reports, with the source line:
--   * an assignment to a global that isn't DT's own (SETGLOBAL; and a write into a non-DT global
--     table, e.g. _G.X = or ChatFrame1.x =, except SlashCmdList["DEADTIRED"]);
--   * any use of hooksecurefunc (and rawset / setglobal / setfenv / getfenv, the ways round it);
--   * a Set*, Show, Hide, HookScript or ClearAllPoints call on a global frame DT didn't create
--     (a method called on a value read straight from a non-DT global).
--   * R-P2-2 (Port 2): UISpecialFrames read in any shape but exactly two:
--     table.insert(UISpecialFrames, <one value>) (two arguments, nothing taken back) and
--     type(UISpecialFrames). A removal, an insert at a position, an assignment into it, a local
--     copy, any other call on it, or _G["UISpecialFrames"]: a hit.
-- DT's own globals: DT, DeadTired*, SLASH_DEADTIRED<n>, and SlashCmdList["DEADTIRED"].
-- Registers are followed within each function: a register loaded from a global keeps that global's
-- name until anything else writes it.
local M = {}

function M.own(name)
  return name == "DT" or name:match("^DeadTired") ~= nil or name:match("^SLASH_DEADTIRED%d+$") ~= nil
end

local BANNED_CALLS = { hooksecurefunc = true, rawset = true, setglobal = true, setfenv = true, getfenv = true }
local function bannedMethod(m)
  return m:match("^Set") ~= nil or m == "Show" or m == "Hide" or m == "HookScript" or m == "ClearAllPoints"
end

-- ops that don't write register A
local NO_WRITE = { SETTABLE = true, SETGLOBAL = true, SETUPVAL = true, SETLIST = true, JMP = true, EQ = true,
  LT = true, LE = true, TEST = true, RETURN = true, TAILCALL = true, CLOSE = true }

-- The register operands each op reads (R-P2-2's follow-up of UISpecialFrames).
local READS = { MOVE = "b", GETTABLE = "bc", SETTABLE = "abc", SELF = "bc", ADD = "bc", SUB = "bc", MUL = "bc",
  DIV = "bc", MOD = "bc", POW = "bc", UNM = "b", NOT = "b", LEN = "b", EQ = "bc", LT = "bc", LE = "bc",
  TEST = "a", TESTSET = "b", SETGLOBAL = "a", SETUPVAL = "a", RETURN = "a", TAILCALL = "a" }
local UISF = "UISpecialFrames"
local UISF_HIT = "uses UISpecialFrames other than table.insert(UISpecialFrames, <name>) (R-P2-2)"

function M.scanListing(listing, file)
  local hits = {}
  local reg = {}
  local pending          -- { reg, fn, line }: UISpecialFrames loaded as an argument, its call not yet seen
  local function hit(line, what) hits[#hits + 1] = { file = file, line = tonumber(line), what = what } end
  for l in listing:gmatch("[^\n]+") do
    if l:match("^main <") or l:match("^function <") then
      if pending then hit(pending.line, UISF_HIT) end
      reg, pending = {}, nil
    end
    local line, op, args, comment = l:match("^%s+%d+%s+%[(%d+)%]%s+(%u+)%s+([%-%d ]+)%s*;?%s*(.*)$")
    if op then
      local a, b, c = args:match("^(%-?%d+)%s*(%-?%d*)%s*(%-?%d*)")
      a, b, c = tonumber(a), tonumber(b), tonumber(c)
      -- R-P2-2: until its call, nothing may read, overwrite or consume the UISpecialFrames register
      if pending then
        local x = pending.reg
        if op == "CALL" and a == x - 1 then
          local ok = (pending.fn == "table.insert" and b == 3 and c == 1) or (pending.fn == "type" and b == 2)
          if not ok then hit(line, UISF_HIT) end
          pending = nil
        else
          local bad = (op == "CALL" or op == "TAILCALL") and a < x
          for k in (READS[op] or ""):gmatch(".") do
            local v = (k == "a" and a) or (k == "b" and b) or c
            if v == x then bad = true end
          end
          if op == "CONCAT" and b <= x and x <= c then bad = true end
          if a == x and op ~= "SETTABLE" and op ~= "TEST" and op ~= "SETGLOBAL" and op ~= "SETUPVAL"
             and op ~= "RETURN" and op ~= "EQ" and op ~= "LT" and op ~= "LE" and op ~= "JMP" then bad = true end
          if bad then hit(line, UISF_HIT); pending = nil end
        end
      end
      if op == "GETGLOBAL" then
        local name = comment:match("^([%w_]+)")
        if name and BANNED_CALLS[name] then hit(line, "uses " .. name) end
        if name == UISF then
          local fn = reg[a - 1]
          if fn == "table.insert" or fn == "type" then pending = { reg = a, fn = fn, line = line }
          else hit(line, UISF_HIT) end
        end
        reg[a] = name
      elseif op == "SETGLOBAL" then
        local name = comment:match("^([%w_]+)")
        if name and not M.own(name) then hit(line, "assigns the global " .. name) end
      elseif op == "SETTABLE" then
        local g = reg[a]
        if g and not M.own(g) then
          local key = (b and b < 0) and comment:match('^"([^"]*)"') or nil
          if not (g == "SlashCmdList" and key == "DEADTIRED") then
            hit(line, "writes into the global " .. g .. (key and ("." .. key) or "[?]"))
          end
        end
      elseif op == "SELF" then
        local g = reg[b]
        local m = comment:match('^"([^"]*)"')
        if g and not M.own(g) and m and bannedMethod(m) then hit(line, "calls " .. g .. ":" .. m) end
        reg[a], reg[a + 1] = nil, nil
      elseif op == "GETTABLE" then
        local g = reg[b]
        local key = (c and c < 0) and comment:match('"([^"]*)"') or nil
        if g == "_G" and key == UISF then hit(line, UISF_HIT) end
        if g == "table" and key == "insert" then reg[a] = "table.insert"
        else reg[a] = (g == "_G") and "_G[?]" or nil end
      elseif op == "MOVE" then
        reg[a] = reg[b]
      elseif op == "CALL" or op == "LOADNIL" or op == "TFORLOOP" or op == "FORPREP" or op == "FORLOOP" or op == "VARARG" then
        for r = a, a + 255 do reg[r] = nil end
      elseif not NO_WRITE[op] then
        reg[a] = nil
      end
    end
  end
  if pending then hit(pending.line, UISF_HIT) end
  return hits
end

function M.scanFile(path)
  local p = io.popen('luac5.1 -p -l "' .. path .. '" 2>&1')
  local listing = p:read("*a")
  p:close()
  if not listing:find("main <", 1, true) then return nil, listing end
  return M.scanListing(listing, path)
end

return M
