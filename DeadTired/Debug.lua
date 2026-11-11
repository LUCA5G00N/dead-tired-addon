-- Dead Tired: diagnostics, asked for only.
--   /dt debug names    the name functions for player and target (rebuild requirement 4)
--   /dt debug senders  every distinct raw CHAT_MSG_ADDON sender string on DT's prefix (cap 50)
--   /dt debug errors   the error counts each module has recorded, and the comms counters
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

DT.module({
  id = "debug",
  title = "Diagnostics",
  verbs = {
    { verb = "debug names", usage = "debug names", fn = names },
    { verb = "debug senders", usage = "debug senders", fn = senders },
    { verb = "debug errors", usage = "debug errors", fn = errors },
  },
})
