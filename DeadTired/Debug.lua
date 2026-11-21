-- Dead Tired: diagnostics, asked for only.
--   /dt debug names    the name functions for player and target (rebuild requirement 4)
--   /dt debug senders  every distinct raw CHAT_MSG_ADDON sender string on DT's prefix (cap 50)
--   /dt debug errors   the error counts each module has recorded, and the comms counters
--   /dt debug fit      fix round 4: text that doesn't fit, under each skin (DT.fitCheck, UI.lua):
--                      one line per fault, then "fit: <n> checked, <m> over, <k> rows cut,
--                      measure failures <f>". Each window is built (hidden) with its current data;
--                      each skin is applied in memory only; nothing is saved.
--   /dt debug rip <n>  0.3.3: a guildie's two death-notice lines, previewed (R-F6-6)
-- Values are printed through DT.safe: as strings, never interpreted.
local ADDON, ns = ...
local DT = ns.DT
local try = DT.try

local function q(v)
  if v == nil then return "nil" end
  if DT.secret(v) then return "<secret>" end
  return '"' .. DT.safe(tostring(v), 60) .. '"'
end

local function names()
  for _, unit in ipairs({ "player", "target" }) do
    local fn, fr = try(UnitFullName, unit)
    DT.out(unit .. ": UnitName " .. q((try(UnitName, unit))) .. ", UnitFullName " .. q(fn) .. " / " .. q(fr)
      .. ", GetUnitName(true) " .. q((try(GetUnitName, unit, true))))
  end
  DT.out("realm: GetRealmName " .. q((try(GetRealmName))) .. ", GetNormalizedRealmName "
    .. q((try(GetNormalizedRealmName))) .. ", key " .. q(DT.myKey()))
end

local function senders()
  local s = DT.db().comms
  local list = {}
  for raw, e in pairs(s.senders) do list[#list + 1] = { raw = raw, e = e } end
  table.sort(list, function(a, b) return a.raw < b.raw end)
  DT.out("senders: " .. #list .. " (cap " .. DT._comms.MAX_SENDERS .. ", over cap " .. (s.sendersOverflow or 0)
    .. "), key mismatches " .. s.keyMismatch)
  for _, x in ipairs(list) do
    DT.out(q(x.raw) .. " x" .. tostring(x.e.n) .. " " .. DT.safe(x.e.chan, 12) .. " " .. DT.safe(x.e.last, 20))
  end
  for _, m in ipairs(s.mismatches) do
    DT.out("mismatch: sender " .. q(m.sender) .. " said key " .. q(m.key) .. " " .. DT.safe(m.t, 20))
  end
end

local function errors()
  local e, c = DT.db().errors, DT.db().comms
  local ids = {}
  for k in pairs(e) do if not k:find(":last", 1, true) then ids[#ids + 1] = k end end
  table.sort(ids)
  if #ids == 0 then DT.out("errors: none") end
  for _, id in ipairs(ids) do DT.out("errors " .. id .. ": " .. tostring(e[id]) .. " " .. q(e[id .. ":last"])) end
  DT.out("comms: sent " .. c.sent .. ", received " .. c.received .. ", refused " .. c.sendRefused
    .. ", dropped after 3 " .. c.refusedDropped .. ", queue drops " .. c.dropped .. ", holds " .. c.held
    .. ", malformed " .. c.malformed .. ", unknown version " .. c.unknownVersion
    .. ", restricted flag " .. q(c.flagRestricted))
end

-- R-F6-6 (0.3.3): /dt debug rip <name> prints the two death-notice lines (ordinary, then hardcore)
-- as they would look if that roster member died, at level 30 in Duskwood. Records nothing, sends
-- nothing; built by DT.noticeLine, the line the DEATH handler prints.
local function rip(args)
  local want = DT.fullName(DT.trim(args or "") or "")
  if not want then return DT.out("/dt debug rip <name>") end
  local roster = DT.rosterClasses()
  local e = roster[(want:lower():gsub("%s+", " "))]
  if not e then return DT.out("not on the roster.") end
  -- The key a real DEATH from them would carry: a key DT already knows for that name (on the roster's
  -- realm when it gives one; my realm first), else the name on the roster's realm or mine. Never a
  -- made-up "?" realm (walk, 21 Nov: the 0.3.3 preview printed "Echo Wagyu (?)").
  local mine = DT.splitKey(DT.myKey() or "")
  local key, lname = nil, e.name:lower()
  for _, k in ipairs(DT.knownKeys()) do
    local r, n = DT.splitKey(k)
    if n and n:lower() == lname and (not e.realm or r:lower() == e.realm:lower()) then
      if not key or (mine and r:lower() == mine:lower()) then key = k end
    end
  end
  local realm = e.realm or mine
  key = key or (realm and (realm .. "-" .. e.name))                     -- guard: a real key, never "?"
  if not key then return DT.out("not on the roster.") end
  DT.out(DT.noticeLine(key, 30, "Duskwood", false, roster))
  DT.out(DT.noticeLine(key, 30, "Duskwood", true, roster))
end

DT.module({
  id = "debug",
  title = "Diagnostics",
  verbs = {
    { verb = "debug names", usage = "debug names", fn = names },
    { verb = "debug senders", usage = "debug senders", fn = senders },
    { verb = "debug errors", usage = "debug errors", fn = errors },
    { verb = "debug fit", usage = "debug fit", fn = function() for _, l in ipairs(DT.fitCheck()) do DT.out(l) end end },
    { verb = "debug rip", usage = "debug rip <name>", fn = rip },
  },
})
