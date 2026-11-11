-- Offline checks for Prep.lua (R-P3: the officers' raid-night list; rc3's roll call kept).
--   lua5.1 DeadTired/tests/test_prep.lua
-- Stubs per client (c.env): C_GuildInfo.IsGuildOfficer (c.officer), GetNumGuildMembers /
-- GetGuildRosterInfo (over w.guildRoster: { name, rankIndex }), C_Item.GetItemCount (c.bags; the
-- bank flag kept in c.bankFlags), GetItemNameByID / GetItemInfoInstant (H.items), time (c.now).
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local R2 = "CAMWOW EU4 Realm 2 PvP"
local ITEMS = { [13446] = "Major Healing Potion", [17029] = "Sacred Candle", [5140] = "Flash Powder" }
local BYNAME = { ["Major Healing Potion"] = 13446, ["Flash Powder"] = 5140 }

local function stub(c)
  c.officer, c.bags, c.bankFlags, c.now = false, {}, {}, 1793833200
  local env = c.env
  rawset(env, "time", function() return c.now end)
  rawset(env, "C_GuildInfo", { IsGuildOfficer = function() return c.officer end, GuildRoster = function() c.rosterAsked = true end })
  rawset(env, "GetNumGuildMembers", function() return c.world.guildRoster and #c.world.guildRoster or 0 end)
  rawset(env, "GetGuildRosterInfo", function(i)
    local e = c.world.guildRoster[i]
    if e then return e[1], "rank", e[2] end
  end)
  rawset(env, "C_Item", {
    GetItemCount = function(id, bank) c.bankFlags[#c.bankFlags + 1] = bank; if c.itemError then error("x") end return c.bags[id] or 0 end,
    GetItemNameByID = function(id) return ITEMS[id] end,
    GetItemInfoInstant = function(name) return BYNAME[name] end,
    RequestLoadItemDataByID = function(id) c.requested = id end,
  })
end

local function mk(w, o)
  if o.guild == nil then o.guild = G end
  o.realm = o.realm or R2
  o.random = function() return 0.5 end
  local setup = o.setup
  o.setup = function(c) stub(c); if setup then setup(c) end end
  return w:client(o)
end

local function msgs(c, kind)
  local out = {}
  for _, m in ipairs(c.sent) do
    local ok, p = c.DT._comms.decode(m.text)
    if ok == "ok" and p.k == kind then out[#out + 1] = { d = p.d, len = #m.text } end
  end
  return out
end

local w = H.world()
-- the guild roster as the client reads it: names with "-Realm", rank 0 GM, 1 officer, 4 member
w.guildRoster = {
  { "Stromham Hamson-CAMWOWEU4Realm2PvP", 0 },
  { "Echo Nightclaw-CAMWOWEU4Realm2PvP", 4 },
  { "Lilbit High-CAMWOWEU4Realm4PvP", 1 },
  { "Marvella Hex-CAMWOWEU4Realm2PvP", 4 },
}
local tim = mk(w, { name = "Stromham", full = "Stromham Hamson" }); tim.officer = true
local echo = mk(w, { name = "Echo", full = "Echo Nightclaw" })
local mar = mk(w, { name = "Marvella", full = "Marvella Hex" })
tim:login(); echo:login(); mar:login(); w:advance(30)

check("store: DeadTiredDB.prep, an empty list at version 0, roll-call sharing off", type(tim:db().prep) == "table"
  and tim:db().prep.list.ver == 0 and #tim:db().prep.list.items == 0 and tim.DT.get("prep", "share") == false)
echo:slash("prep check")
check("an empty list: nothing to pack (rc3's line)", echo:said("Nothing on the list for you. Travel light.") ~= nil)
check("settings: the list and the share switch are cards", tim.DT.setting("prep", "list").type == "list"
  and tim.DT.setting("prep", "share").verb == "prep share on|off")

-- ---------------------------------------------------------------- officers set the list
echo:slash("prep add 13446 5")
check("a member can't set the list", echo:said("Officers only. The rest of us just haunt the place.") ~= nil
  and #echo:db().prep.list.items == 0 and #msgs(echo, "PREPLIST") == 0)
tim:slash("prep add 13446 5")
check("an officer adds by item ID; the client's name is used", tim:said("prep.list: Major Healing Potion x5 (1 on the list)") ~= nil)
tim:slash("prep add |cff1eff00|Hitem:5140::::::::60:::::|h[Flash Powder]|h|r 10")
check("...by a shift-clicked link", tim:said("prep.list: Flash Powder x10 (2 on the list)") ~= nil)
tim:slash("prep add Major Healing Potion 6")
check("...by a name the client knows; the same item again changes its count", tim:said("prep.list: Major Healing Potion x6 (2 on the list)") ~= nil)
tim:slash("prep add Unknown Thing 3")
check("an item it can't find: says how, changes nothing", tim:said("/dt prep add <item> <count>") ~= nil and #tim:db().prep.list.items == 2)
tim:slash("prep add 17029 0")
check("a count of 0 is refused", #tim:db().prep.list.items == 2)
w:advance(2)
check("every change is shared (PREPLIST)", #msgs(tim, "PREPLIST") == 3)
local L = echo:db().prep.list
check("members get the list", #L.items == 2 and L.items[1].id == 13446 and L.items[1].need == 6 and L.items[2].name == "Flash Powder"
  and L.by == "CAMWOWEU4Realm2PvP-Stromham Hamson")
check("versioned by the time", L.ver == tim:db().prep.list.ver and L.ver >= 1793833200)

-- ---------------------------------------------------------------- members check their own bags
echo.bags = { [13446] = 2 }
echo:slash("prep check")
check("check: short, with names and counts, in list order (to the player only)", echo:said("Short: Major Healing Potion 2/6, Flash Powder 0/10.") ~= nil)
local onlyBags = true
for _, f in ipairs(echo.bankFlags) do if f ~= false then onlyBags = false end end
check("bags only: the bank flag is passed as false, every time", onlyBags and #echo.bankFlags > 0)
echo.bags = { [13446] = 6, [5140] = 12 }
echo:slash("prep")
check("all met: ready, exactly (/dt prep alone checks too)", echo:said("Ready. Bags packed, coffin optional.") ~= nil)
echo.itemError = true
echo:slash("prep check")
check("GetItemCount erroring means 0", echo:said("Short: Major Healing Potion 0/6") ~= nil)
echo.itemError = false
local sentBefore = #echo.sent
echo:slash("prep check")
w:advance(2)
check("/dt prep check sends nothing", #echo.sent == sentBefore)
echo:slash("prep list")
check("/dt prep list shows the client's name for each", echo:said("13446 Major Healing Potion x6 — client: Major Healing Potion") ~= nil)

-- remove and clear
tim:slash("prep remove Flash Powder")
check("an officer removes by name", tim:said("prep.list: Flash Powder removed (1 on the list)") ~= nil)
w:advance(2)
check("the removal reaches members", #echo:db().prep.list.items == 1)
mar:slash("prep clear")
check("a member can't clear it", mar:said("Officers only.") ~= nil and #mar:db().prep.list.items == 1)

-- ---------------------------------------------------------------- officers only accepted; last writer wins
local function inject(c, from, sender, d)
  c.DT._comms.inbound("DEADTIRED", c.DT._comms.encode("PREPLIST", d, from), "GUILD", sender)
end
local now = echo:db().prep.list
local ver = now.ver
inject(echo, "CAMWOWEU4Realm2PvP-Marvella Hex", "Marvella Hex", { ver = tostring(ver + 100), items = { { id = 1, need = 1, name = "Junk" } } })
check("a list from a member (rank 4) is refused, counted", echo:db().prep.list.ver == ver and echo:db().prep.notOfficer == 1)
inject(echo, "CAMWOWEU4Realm2PvP-Nobody Known", "Nobody Known", { ver = tostring(ver + 100), items = {} })
check("a sender not on the guild roster is refused", echo:db().prep.list.ver == ver and echo:db().prep.notOfficer == 2)
inject(echo, "CAMWOWEU4Realm2PvP-Lilbit High", "Lilbit High", { ver = tostring(ver + 100), items = {} })
check("the roster's realm must match the key's (Lilbit High is on Realm 4)", echo:db().prep.notOfficer == 3)
inject(echo, "CAMWOWEU4Realm4PvP-Lilbit High", "Lilbit High-CAMWOWEU4Realm4PvP", { ver = tostring(ver - 5), items = {} })
check("an officer's older list loses (last writer wins by time)", echo:db().prep.list.ver == ver and #echo:db().prep.list.items == 1)
inject(echo, "CAMWOWEU4Realm4PvP-Lilbit High", "Lilbit High-CAMWOWEU4Realm4PvP", { ver = tostring(ver + 5), items = { { id = 5140, need = 4, name = "Flash Powder" } } })
check("an officer (rank 1, another realm) with a newer list wins", echo:db().prep.list.ver == ver + 5
  and echo:db().prep.list.items[1].id == 5140 and echo:db().prep.list.by == "CAMWOWEU4Realm4PvP-Lilbit High")
local bad = echo:db().prep.badPrep
for _, d in ipairs({ { ver = "x", items = {} }, { ver = "1", items = { { id = 0, need = 1, name = "x" } } },
    { ver = "1", items = { { id = 1, need = 1001, name = "x" } } }, { ver = "1", items = { { id = 1, need = 1, name = string.rep("n", 49) } } },
    { ver = "1" } }) do
  inject(echo, "CAMWOWEU4Realm2PvP-Stromham Hamson", "Stromham Hamson", d)
end
local many = {}
for i = 1, 31 do many[i] = { id = i, need = 1, name = "x" } end
inject(echo, "CAMWOWEU4Realm2PvP-Stromham Hamson", "Stromham Hamson", { ver = "1", items = many })
check("each invalid PREPLIST is counted in badPrep, not taken", echo:db().prep.badPrep == bad + 6 and echo:db().prep.list.ver == ver + 5)

-- late joiner: the HELLO carries the list's version; an officer resends
do
  local w2 = H.world()
  w2.guildRoster = w.guildRoster
  local t = mk(w2, { name = "Stromham", full = "Stromham Hamson" }); t.officer = true
  t:login(); w2:advance(30)
  t:slash("prep add 13446 5")
  w2:advance(70)
  local n = #msgs(t, "PREPLIST")
  local late = mk(w2, { name = "Marvella", full = "Marvella Hex" })
  late:login(); w2:advance(30)
  check("a late joiner's HELLO (version 0) gets the list from an officer", #msgs(t, "PREPLIST") == n + 1
    and #late:db().prep.list.items == 1)
  local again = mk(w2, { name = "Echo", full = "Echo Nightclaw" })
  again:login(); w2:advance(30)
  check("at most once a minute", #msgs(t, "PREPLIST") == n + 1)
  w2:advance(60)
  local third = mk(w2, { name = "Ghoul", full = "Ghoul Grim" })
  third:login(); w2:advance(30)
  check("a minute later, again", #msgs(t, "PREPLIST") == n + 2)
  local before = #msgs(late, "PREPLIST")
  local fourth = mk(w2, { name = "Wight", full = "Wight Bones" })
  fourth:login(); w2:advance(30)
  check("a member never resends", #msgs(late, "PREPLIST") == before)
  local w3 = H.world()
  w3.guildRoster = w.guildRoster
  local t3 = mk(w3, { name = "Stromham", full = "Stromham Hamson" }); t3.officer = true
  t3:login(); w3:advance(30)
  t3:slash("prep add 13446 5"); w3:advance(70)
  local cur = mk(w3, { name = "Current", full = "Current Bones", db = { schema = 3, migrated = { port1 = true },
    prep = { list = { ver = t3:db().prep.list.ver, items = { { id = 13446, need = 5, name = "Major Healing Potion" } } } } } })
  local m = #msgs(t3, "PREPLIST")
  cur:login(); w3:advance(30)
  check("a HELLO with the current version gets nothing", #msgs(t3, "PREPLIST") == m)
end

-- ---------------------------------------------------------------- the roll call (rc3, verdict only)
do
  local w2 = H.world()
  w2.guildRoster = w.guildRoster
  local t = mk(w2, { name = "Stromham", full = "Stromham Hamson" }); t.officer = true
  local g = mk(w2, { name = "Echo", full = "Echo Nightclaw" })
  local q = mk(w2, { name = "Marvella", full = "Marvella Hex" })
  t:login(); g:login(); q:login(); w2:advance(30)
  t:slash("prep add 13446 5"); t:slash("prep add 5140 10"); w2:advance(2)
  g:slash("prep share on")
  check("/dt prep share on (rc3's line)", g:said("sharing on. You'll answer roll calls: ready or not, and how many short.") ~= nil)
  g.bags = { [13446] = 5 }
  t.printed = {}
  t:slash("prep roll")
  check("/dt prep roll sends PREPQ and says so", t:said("Roll call sent. Answers in 10 seconds.") ~= nil and #msgs(t, "PREPQ") == 1)
  w2:advance(0.5)
  check("nobody answers before 1 s", #msgs(g, "PREP") == 0)
  w2:advance(6)
  local ans = msgs(g, "PREP")
  local onlyVerdict = #ans == 1
  for k in pairs(ans[1] and ans[1].d or {}) do if k ~= "q" and k ~= "to" and k ~= "ok" and k ~= "short" then onlyVerdict = false end end
  check("a sharing member answers once with the verdict only: ok and how many short, no names or counts", onlyVerdict
    and ans[1].d.ok == "0" and ans[1].d.short == "1" and ans[1].d.to == "CAMWOWEU4Realm2PvP-Stromham Hamson")
  check("the answer carries no item name or ID", not tostring(ans[1].d.short):find("Flash", 1, true) and ans[1].len <= 250)
  check("a member with sharing off sends nothing", #msgs(q, "PREP") == 0)
  w2:advance(5)
  check("the summary at 10 s", t:said("Ready (0): none. Short (1): Echo Nightclaw (1 short).") ~= nil
    and t:said("Only guildies running the addon with sharing on answer.") ~= nil)
  check("receivers print nothing", not g:said("Roll call") and not q:said("Roll call"))
  t:slash("prep roll")
  check("a second roll call inside 60 s is refused, nothing sent", t:said("Patience. The last roll call is still out.") ~= nil and #msgs(t, "PREPQ") == 1)
  w2:advance(61); t.now = t.now + 61
  g:slash("prep share off")
  check("/dt prep share off (rc3's line)", g:said("sharing off. Your bags are your own business.") ~= nil)
  t:slash("prep roll"); w2:advance(11)
  check("nobody answered: both parts read none", t:said("Ready (0): none. Short (0): none.") ~= nil)
  -- an answer addressed elsewhere, or malformed
  local function injectPrep(c, from, d)
    c.DT._comms.inbound("DEADTIRED", c.DT._comms.encode("PREP", d, from), "GUILD", from:match("%-(.+)$"))
  end
  local b0 = t:db().prep.badPrep
  injectPrep(t, "CAMWOWEU4Realm2PvP-Echo Nightclaw", { q = "1", to = "CAMWOWEU4Realm2PvP-Stromham Hamson", ok = "1", short = "0", items = "Flash Powder" })
  injectPrep(t, "CAMWOWEU4Realm2PvP-Echo Nightclaw", { q = "1", to = "CAMWOWEU4Realm2PvP-Stromham Hamson", ok = "1", short = "2" })
  check("an answer carrying anything but the verdict, or contradicting itself, is counted bad", t:db().prep.badPrep == b0 + 2)
  -- F6c
  g:slash("prep share on")
  local n = #msgs(g, "PREP")
  for i = 1, 10 do
    g.DT._comms.inbound("DEADTIRED", g.DT._comms.encode("PREPQ", { q = tostring(100 + i) }, "CAMWOWEU4Realm2PvP-Stromham Hamson"), "GUILD", "Stromham Hamson")
    w2:advance(1)
  end
  w2:advance(6)
  check("F6c: ten roll calls from one asker in 10 s: one answer, the rest counted", #msgs(g, "PREP") == n + 1 and g:db().prep.dropped == 9)
end

-- ---------------------------------------------------------------- off, and outside the guild
do
  local w2 = H.world()
  w2.guildRoster = w.guildRoster
  local t = mk(w2, { name = "Stromham", full = "Stromham Hamson" }); t.officer = true
  local off = mk(w2, { name = "Echo", full = "Echo Nightclaw", db = { schema = 3, settings = { prep = { enabled = false } } } })
  local out = mk(w2, { name = "Marvella", full = "Marvella Hex", guild = "Elsewhere" })
  t:login(); off:login(); out:login(); w2:advance(30)
  t:slash("prep add 13446 5"); w2:advance(2)
  check("prep switched off: the list isn't taken", #off:db().prep.list.items == 0)
  check("outside the guild: nothing taken, nothing sent", (out:db().prep == nil or #out:db().prep.list.items == 0) and #out.sent == 0)
end

H.finish("prep")
