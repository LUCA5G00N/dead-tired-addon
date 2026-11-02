-- Audit test helpers. Loads a card's own harness from its checkout (sh audit/tests/setup.sh) and
-- points it at that card's DeadTired/ folder. No addon file is copied or changed.
local L = {}
L.WT = os.getenv("DT_AUDIT_WT") or "/tmp/dt-audit-wt"

-- card: "dt_foundation", "dt_prep", ... Returns the card's harness, aimed at its DeadTired/.
function L.harness(card)
  local dir = L.WT .. "/" .. card .. "/DeadTired"
  local f = io.open(dir .. "/tests/harness.lua")
  if not f then
    print("no checkout of card/" .. card .. " at " .. L.WT .. ": run sh audit/tests/setup.sh first")
    os.exit(2)
  end
  f:close()
  local H = dofile(dir .. "/tests/harness.lua")
  H.addonDir = dir
  return H
end

L.G = "DEAD TIRED"
function L.half() return 0.5 end

-- A /reload: the old Lua state is gone (the client leaves the world), a new instance loads with
-- the same SavedVariables table and fires PLAYER_ENTERING_WORLD(false, true).
function L.reload(w, c, opts)
  local db = c:db()
  c:logout()
  opts = opts or {}
  opts.name, opts.realm, opts.guild, opts.db = c.name, c.realm, c.guild, db
  opts.files = opts.files or c.files
  local n = w:client(opts)
  if opts.stubs then opts.stubs(n) end
  n:fire("PLAYER_ENTERING_WORLD", false, true)
  return n
end

function L.count(c, pat)
  local n = 0
  for _, s in ipairs(c.sent) do if s.text:find(pat) then n = n + 1 end end
  return n
end

return L
