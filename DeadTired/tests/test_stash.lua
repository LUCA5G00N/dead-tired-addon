-- Offline checks for Stash.lua (card 6, guild stash search, ported from rc3 in Port 2): rc3's checks
-- on full-name keys, the setting as a card, the answers in a viewport.
--   lua5.1 DeadTired/tests/test_stash.lua
-- Stubs per client (c.env): Enum.BagIndex, C_Container (GetContainerNumSlots, GetContainerItemInfo),
-- C_Item (GetItemNameByID, RequestLoadItemDataByID, and (A4) IsBound over c.slotBound["bag:slot"]),
-- ItemLocation:CreateFromBagAndSlot, date (c.stampStr). c.bags[bag][slot] = { itemID, stackCount, isBound }.
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local R2 = "CAMWOW EU4 Realm 2 PvP"
local K2 = "CAMWOWEU4Realm2PvP-"
local P = "|cff7fa650Dead Tired|r "
local CLOSING = "Only guildies running the addon with stash sharing on answer."
local NOBODY = "Nobody's got it. Or nobody's sharing."
local NAMES = { [2589] = "Linen Cloth", [2592] = "Wool Cloth", [4306] = "Silk Cloth", [2996] = "Bolt of Linen Cloth",
  [6948] = "Hearthstone", [4338] = "Mageweave Cloth", [14047] = "Runecloth", [2770] = "Copper Ore" }

local function stub(c)
  local o = c.opts
  c.bags, c.names, c.requested, c.scans, c.slotBound = o.bags or {}, {}, {}, 0, {}
  c.stampStr = "2026-11-04 23:00:00"
  for k, v in pairs(NAMES) do c.names[k] = v end
  local env = c.env
  local idx = { Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4, Bank = -1, BankBag_1 = 6, BankBag_2 = 7 }
  if o.noBank then idx.Bank, idx.BankBag_1, idx.BankBag_2 = nil, nil, nil end
  local E = rawget(env, "Enum")
  rawset(env, "Enum", setmetatable({ BagIndex = idx }, { __index = E }))
  rawset(env, "C_Container", {
    GetContainerNumSlots = function(b) if b == 0 then c.scans = c.scans + 1 end return c.bags[b] and 16 or 0 end,
    GetContainerItemInfo = function(b, s) return c.bags[b] and c.bags[b][s] end,
  })
  rawset(env, "C_Item", {
    GetItemNameByID = function(id) return c.names[id] end,
    RequestLoadItemDataByID = function(id) c.requested[id] = true end,
    IsBound = function(loc)
      local v = c.slotBound[loc.bag .. ":" .. loc.slot]
      if v == "error" then error("no item there") end
      return v
    end,
  })
  rawset(env, "ItemLocation", { CreateFromBagAndSlot = function(self, b, sl) return { bag = b, slot = sl } end })
  rawset(env, "date", function() return c.stampStr end)
end

local function mk(w, o)
  o.realm = o.realm or R2
  if o.guild == nil then o.guild = G end
  o.random = o.random or function() return 0.5 end
  local setup = o.setup
  o.setup = function(c) stub(c); if setup then setup(c) end end
  return w:client(o)
end
local function item(id, n, bound) return { itemID = id, stackCount = n, isBound = bound or false } end
local function sentKind(c, kind)
  local out = {}
  for _, m in ipairs(c.sent) do
    local ok, p = c.DT._comms.decode(m.text)
    if ok == "ok" and p.k == kind then out[#out + 1] = p.d end
  end
  return out
end
local function mine(c) return c:db().stash.chars[c:key()] end
local function inject(c, kind, from, d)
  c.DT._comms.inbound("DEADTIRED", c.DT._comms.encode(kind, d, from), "GUILD", from:match("%-(.+)$"))
end
local function rows(c)
  local L = c.DT._stash.list()
  local out = {}
  if not L then return out end
  for _, r in ipairs(L.model.rows) do out[#out + 1] = r.holder .. ": " .. r.items end
  return out
end

-- ---------------------------------------------------------------- store and verbs
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  a:login(); w:advance(30)
  local s = a:db().stash
  check("store: DeadTiredDB.stash, sharing off, badStash 0, no characters", a.DT.get("stash", "share") == false
    and s.badStash == 0 and next(s.chars) == nil)
  check("the setting is a card with a typed path", a.DT.setting("stash", "share").verb == "stash share on|off")
  a:slash("")
  check("the help lists stash with its usage", a:said("stash [item/share on/off]") ~= nil)
  a:slash("stash"); check("/dt stash alone, sharing off", a.printed[1] == P .. "Sharing off. Nothing offered.")
  a:slash("stash share"); check("/dt stash share shows the setting", a:said("stash sharing is off.") ~= nil)
  local n0 = #a.sent
  a:slash("stash ab"); check("a 2-letter term is refused", a:said("/dt stash <item, 3-32 letters>") ~= nil and #a.sent == n0)
  a:slash("stash " .. string.rep("x", 33)); w:advance(1); check("a 33-letter term is refused", #a.sent == n0)
  a:slash("stash share on")
  check("A4: the share-on line says answers name the holder", #a.printed == 1 and a.printed[1]
    == P .. "stash sharing on. Guildies' searches see your tradeable items, four at a time, and which character holds them.")
end

-- ---------------------------------------------------------------- scanning
do
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson", bags = { [0] = { item(2589, 20), item(2589, 7), item(6948, 1, true) },
    [2] = { [5] = item(2592, 12), [6] = { itemID = "x", stackCount = 3 }, [7] = { itemID = 4306 }, [8] = item(4306, 0) } } })
  a:login()
  check("sharing off: no scan at login, no list", a.scans == 0 and mine(a) == nil)
  a:fire("BAG_UPDATE_DELAYED"); a:fire("BANKFRAME_OPENED")
  check("sharing off: no scan on bag or bank events", a.scans == 0 and mine(a) == nil)
  a:slash("stash share on")
  local e = mine(a)
  check("sharing on scans the bags at once, under the full-name key", e and e.bags[2589] == 27 and e.bags[2592] == 12
    and e.at == "2026-11-04 23:00:00" and a:key() == K2 .. "Stromham Hamson")
  check("a bound item is never listed", e.bags[6948] == nil)
  check("bad slot info is skipped", e.bags[4306] == nil)
  check("and the bank is not read yet", next(e.bank) == nil and e.bankAt == nil)
  a.bags[1] = { item(2770, 5) }
  w:advance(10)
  local before = a.scans
  a:fire("BAG_UPDATE_DELAYED")
  check("BAG_UPDATE_DELAYED rescans", a.scans == before + 1 and mine(a).bags[2770] == 5)
  a.bags[1] = { item(2770, 9) }
  w:advance(1); a:fire("BAG_UPDATE_DELAYED"); a:fire("BAG_UPDATE_DELAYED")
  check("inside 5 s: no scan yet", a.scans == before + 1 and mine(a).bags[2770] == 5)
  w:advance(4.1)
  check("one rescan at the end of the window", a.scans == before + 2 and mine(a).bags[2770] == 9)
  a.bags[-1] = { item(2589, 40) }
  a.bags[6] = { item(14047, 60), item(6948, 1, true) }
  a:fire("BANKFRAME_OPENED")
  check("the bank is read when opened: bank and bank bags, bound skipped", mine(a).bank[2589] == 40
    and mine(a).bank[14047] == 60 and mine(a).bank[6948] == nil and mine(a).bankAt ~= nil)
  a:slash("stash")
  check("/dt stash alone: items across characters, bank read", a.printed[1]
    == P .. "Your account offers 4 items across 1 character (bank read 2026-11-04). Sharing on.")
  a:logout()
  local alt = mk(w, { name = "Bonechill", full = "Bone Chill", db = a:db(), bags = { [0] = { item(4338, 15) } } })
  alt:login()
  check("an alt on the same account adds its own entry, keeping the main's",
    alt:db().stash.chars[K2 .. "Bone Chill"].bags[4338] == 15 and alt:db().stash.chars[K2 .. "Stromham Hamson"] ~= nil)
  alt:slash("stash")
  check("/dt stash on the alt: bank not read yet", alt:said("across 2 characters (bank not read yet)") ~= nil)
  alt:slash("stash share off")
  check("sharing off deletes the account's list", next(alt:db().stash.chars) == nil and alt:said("Your list is gone") ~= nil)
  alt.DT.set("stash", "share", true); alt.DT.set("stash", "share", false)
  check("sharing off from the card (or /dt set) deletes it too", next(alt:db().stash.chars) == nil)
  local w2 = H.world()
  local n = mk(w2, { name = "Nobank", full = "No Bank", noBank = true, bags = { [0] = { item(2589, 1) }, [-1] = { item(2592, 9) } } })
  n:login()
  n:slash("stash share on")
  n:fire("BANKFRAME_OPENED")
  check("Enum.BagIndex.Bank absent: the bank is never read", next(mine(n).bank) == nil and n.DT._stash.bankIDs() == nil)
  n:slash("stash")
  check("and /dt stash says so", n:said("(bank not read on this client)") ~= nil)
  rawset(n.env, "Enum", nil)
  n.bags[3] = { item(2770, 2) }
  n.DT._stash.scanBags()
  check("Enum absent: bags 0-4 are still read", mine(n).bags[2770] == 2)
end

-- ---------------------------------------------------------------- A4: listed only when known not bound
do
  local function nb(id) return { itemID = id, stackCount = 1 } end    -- isBound nil: the client didn't say
  local function bagsFor(bag)
    return { [bag] = { item(101, 1, false), item(102, 1, true), nb(103), nb(104), nb(105), nb(106), nb(107) } }
  end
  local function setSlots(c, bag)
    c.slotBound[bag .. ":3"], c.slotBound[bag .. ":4"] = false, true
    c.slotBound[bag .. ":6"], c.slotBound[bag .. ":7"] = "error", "yes"
  end
  local function cases(where, list)
    check("A4 " .. where .. ": isBound false is listed", list[101] == 1)
    check("A4 " .. where .. ": isBound true is skipped", list[102] == nil)
    check("A4 " .. where .. ": isBound nil, C_Item.IsBound false: listed", list[103] == 1)
    check("A4 " .. where .. ": isBound nil, C_Item.IsBound true: skipped", list[104] == nil)
    check("A4 " .. where .. ": isBound nil, C_Item.IsBound nil: skipped", list[105] == nil)
    check("A4 " .. where .. ": isBound nil, C_Item.IsBound erroring: skipped", list[106] == nil)
    check("A4 " .. where .. ": isBound nil, C_Item.IsBound not a boolean: skipped", list[107] == nil)
  end
  local w = H.world()
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson", bags = bagsFor(0) })
  a:login(); setSlots(a, 0)
  a:slash("stash share on")
  cases("bags", mine(a).bags)
  local k = mk(w, { name = "Banker", full = "Bank Er", bags = bagsFor(-1) })
  k:login(); setSlots(k, -1)
  k:slash("stash share on"); k:fire("BANKFRAME_OPENED")
  cases("bank", mine(k).bank)
  local kb = mk(w, { name = "Bankbag", full = "Bank Bag", bags = bagsFor(6) })
  kb:login(); setSlots(kb, 6)
  kb:slash("stash share on"); kb:fire("BANKFRAME_OPENED")
  cases("bank bag", mine(kb).bank)
  for _, how in ipairs({ "C_Item.IsBound absent", "ItemLocation absent", "CreateFromBagAndSlot erroring",
      "a secret IsBound answer" }) do
    local c = mk(w, { name = "Unknown" .. #how, full = "Unknown N" .. #how, bags = { [0] = { item(101, 1, false), nb(103) }, [-1] = { nb(108) } } })
    c:login()
    c.slotBound["0:1"], c.slotBound["0:2"], c.slotBound["-1:1"] = false, false, false
    if how == "C_Item.IsBound absent" then c.env.C_Item.IsBound = nil
    elseif how == "ItemLocation absent" then rawset(c.env, "ItemLocation", nil)
    elseif how == "CreateFromBagAndSlot erroring" then c.env.ItemLocation.CreateFromBagAndSlot = function() error("no") end
    else
      rawset(c.env, "issecretvalue", function(v) return v == false end)   -- every false is secret here
    end
    c:slash("stash share on"); c:fire("BANKFRAME_OPENED")
    local e = mine(c)
    if how == "a secret IsBound answer" then
      check("A4: " .. how .. ": unknown, nothing listed", next(e.bags) == nil and next(e.bank) == nil)
    else
      check("A4: " .. how .. ": isBound false still listed, unknown skipped, bags and bank",
        e.bags[101] == 1 and e.bags[103] == nil and e.bank[108] == nil)
    end
  end
end

-- ---------------------------------------------------------------- searching and answering
do
  local w = H.world()
  local tim = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  local a = mk(w, { name = "Ghoul", full = "Ghoul Grim", random = function() return 0 end,
    bags = { [0] = { item(2589, 20), item(2996, 4) } } })
  local b = mk(w, { name = "Wight", full = "Wight Pale", bags = { [0] = { item(2589, 99) } } })   -- sharing off
  tim:login(); a:login(); b:login(); w:advance(30)
  a:slash("stash share on")
  a:db().stash.chars[K2 .. "Ghoul Alt"] = { bags = { [2589] = 50 }, bank = { [2589] = 10 } }
  local aSent = #sentKind(a, "STASH")
  tim:slash("stash Linen")
  local q1 = tostring(tim.env.time() % 1000000)   -- F8b: the id is the clock, not a counter
  w:advance(0.05)
  local q = sentKind(tim, "STASHQ")[1]
  check("a search sends STASHQ with the term, and says so", q and q.q == q1 and q.term == "Linen"
    and tim.printed[1] == P .. "Asking the guild. Answers in 10 seconds.")
  w:advance(0.8)
  check("nobody answers before 1 s", #sentKind(a, "STASH") == aSent)
  w:advance(0.4)
  local ans = sentKind(a, "STASH")[1]
  check("a sharing member answers once: the alt's items under the alt's full name, largest first",
    ans and ans.hits == "2589:60:Ghoul Alt,2589:20:Ghoul Grim,2996:4:Ghoul Grim" and ans.q == q1 and ans.to == K2 .. "Stromham Hamson")
  check("a member with sharing off sends nothing and doesn't note the question", #sentKind(b, "STASH") == 0
    and next(b.DT._stash.answered()) == nil)
  tim.printed = {}
  w:advance(10)
  local vp = tim.DT._stash.vp()
  check("the answers open in a viewport: one row per holder, in arrival order",
    vp and vp:IsShown() and rows(tim)[1] == "Ghoul Alt: Linen Cloth x60" and rows(tim)[2] == "Ghoul Grim: Linen Cloth x20, Bolt of Linen Cloth x4")
  check("the closing line under them", vp.note.text == CLOSING)
  check("the answers are a DT viewport: Escape closes it (R-P2-2)", vp.name == "DeadTiredViewport_stash")
  check("nothing printed over them", #tim.printed == 0)
  check("receivers print nothing", not a:said("Linen") and not b:said("Linen"))
  inject(a, "STASHQ", K2 .. "Stromham Hamson", { q = q1, term = "Linen" })
  w:advance(10)
  check("one answer per asker and search", #sentKind(a, "STASH") == aSent + 1)
  tim:slash("stash wool")
  check("a second search inside 30 s is refused", tim.printed[1] == P .. "One search at a time. The crypt echoes."
    and #sentKind(tim, "STASHQ") == 1)
  w:advance(10)
  tim:slash("stash wool")
  w:advance(11)
  check("after 30 s a new search goes out", #sentKind(tim, "STASHQ") == 2)
  local L = tim.DT._stash.list()
  check("no hits means no answer, and the viewport says so", #sentKind(a, "STASH") == aSent + 1
    and #L.model.rows == 0 and L.empty.shown and L.empty.text == NOBODY)
  w:advance(31)
  local ok = pcall(function()
    inject(a, "STASHQ", K2 .. "Lich King", { q = "7", term = "%a+" })
    inject(a, "STASHQ", K2 .. "Wraith Grey", { q = "8", term = "[[[" })
    w:advance(10)
  end)
  check("a term like %a+ or [[[ matches literally and never errors", ok and #sentKind(a, "STASH") == aSent + 1)
  a:db().stash.chars[K2 .. "Ghoul Alt"].bags = { [2589] = 1, [2592] = 2, [4306] = 3, [4338] = 4, [14047] = 5 }
  inject(a, "STASHQ", K2 .. "Banshee Wail", { q = "9", term = "cloth" })
  w:advance(10)
  local capped = sentKind(a, "STASH")[aSent + 2]
  check("at most 4 hits, largest first", capped and capped.hits == "2589:20:Ghoul Grim,2589:11:Ghoul Alt,14047:5:Ghoul Alt,2996:4:Ghoul Grim")
  -- holder names: a full name up to 48 bytes is answered (rc3: 24, the old wire limit)
  local long = "Abcdefghijklmnopqrstuvwx Abcdefghijklmnopqrstuvw"     -- 48 bytes
  a:db().stash.chars[K2 .. long] = { bags = { [2770] = 7 }, bank = {} }
  inject(a, "STASHQ", K2 .. "Ghast Ly", { q = "10", term = "copper" })
  w:advance(10)
  local la = sentKind(a, "STASH")[aSent + 3]
  check("a 48-byte holder name is answered", #long == 48 and la and la.hits == "2770:7:" .. long)
  a:db().stash.chars[K2 .. long] = nil
  a:db().stash.chars[K2 .. long .. "x"] = { bags = { [2770] = 7 }, bank = {} }
  inject(a, "STASHQ", K2 .. "Shade Dim", { q = "12", term = "copper" })
  w:advance(10)
  check("a holder name over 48 bytes is left out of answers", #sentKind(a, "STASH") == aSent + 3)
  inject(a, "STASHQ", K2 .. "Revenant Old", { q = "11", term = "linen" })
  a.DT.set("stash", "share", false)
  w:advance(10)
  check("sharing turned off before the delay ends: no answer", #sentKind(a, "STASH") == aSent + 3)
end

-- ---------------------------------------------------------------- receiving: validation and addressing
do
  local w = H.world()
  local tim = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  tim:login(); w:advance(30)
  tim:slash("stash linen")
  local Q = tostring(tim.env.time() % 1000000)
  local me = K2 .. "Stromham Hamson"
  inject(tim, "STASH", K2 .. "Ghoul Grim", { hits = "2589:3:Ghoul Grim", q = Q, to = me })
  inject(tim, "STASH", K2 .. "Ghoul Grim", { hits = "2589:9:Ghoul Grim", q = Q, to = me })
  inject(tim, "STASH", K2 .. "Wight Pale", { hits = "2589:5:Wight Pale", q = Q, to = K2 .. "Someone Else" })
  inject(tim, "STASH", K2 .. "Lich King", { hits = "2589:6:Lich King", q = tostring((Q + 1) % 1000000), to = me })
  inject(tim, "STASH", K2 .. "Bones Dry", { hits = "99999:2:Bones Dry", q = Q, to = me })
  inject(tim, "STASH", K2 .. "Oldie Moldy", { hits = "2592:4:Oldie Moldy", q = Q, to = "CAMWOW EU4 Realm 2 PvP-Stromham Hamson" })
  w:advance(10)
  local r = rows(tim)
  check("once per sender; addressed elsewhere and other searches ignored", r[1] == "Ghoul Grim: Linen Cloth x3" and #r == 3)
  check("an unloaded item shows as item <id>, and its load is requested", r[2] == "Bones Dry: item 99999 x2"
    and tim.requested[99999] == true)
  check("AUD-06: an answer whose to is in the spaced spelling still arrives", r[3] == "Oldie Moldy: Wool Cloth x4")
  inject(tim, "STASH", K2 .. "Late Comer", { hits = "2589:1:Late Comer", q = Q, to = me })
  check("an answer after the summary is ignored", #rows(tim) == 3 and tim.DT._stash.open() == nil)
  local bad = {
    { "STASH", { hits = "2589:3:Ghoul", q = "x", to = "R-N" } }, { "STASH", { hits = "2589:3:Ghoul", q = "1", to = "NoRealm" } },
    { "STASH", { hits = "", q = "1", to = "R-N" } }, { "STASH", { q = "1", to = "R-N" } },
    { "STASH", { hits = "12345678:3:Ghoul", q = "1", to = "R-N" } }, { "STASH", { hits = "2589:0:Ghoul", q = "1", to = "R-N" } },
    { "STASH", { hits = "2589:100000:Ghoul", q = "1", to = "R-N" } },
    { "STASH", { hits = "2589:3:" .. string.rep("y", 49), q = "1", to = "R-N" } },
    { "STASH", { hits = "2589:3", q = "1", to = "R-N" } }, { "STASH", { hits = "2589:3:Ghoul,", q = "1", to = "R-N" } },
    { "STASH", { hits = "1:1:A,2:1:A,3:1:A,4:1:A,5:1:A", q = "1", to = "R-N" } },
    { "STASHQ", { q = "1", term = "ab" } }, { "STASHQ", { q = "abc", term = "linen" } } }
  for _, x in ipairs(bad) do inject(tim, x[1], K2 .. "Bad Sender", x[2]) end
  check("each invalid STASH / STASHQ field is counted in badStash, nothing shown", tim:db().stash.badStash == #bad
    and #rows(tim) == 3)
end

-- ---------------------------------------------------------------- the whole addon
do
  local w = H.world()
  local tim = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  local a = mk(w, { name = "Ghoul", full = "Ghoul Grim", bags = { [0] = { item(2589, 20) } } })
  local x = mk(w, { name = "Spy", full = "Spy Glass", guild = "Alliance Spies", bags = { [0] = { item(2589, 20) } } })
  a.DT.set("stash", "share", true); x.DT.set("stash", "share", true)
  tim:login(); a:login(); x:login()
  w:advance(60)
  check("a login prints nothing from Stash", not tim:said("stash") and not a:said("stash") and #x.printed == 0)
  check("a non-member keeps no list even with sharing on", next(x:db().stash.chars) == nil)
  tim:slash("stash linen"); w:advance(11)
  check("a search works end to end (H8)", rows(tim)[1] == "Ghoul Grim: Linen Cloth x20")
  check("the non-member sends and prints nothing", #x.sent == 0 and #x.printed == 0)
end

-- ---------------------------------------------------------------- fix round 1 (F8b, F6d)
do
  local w = H.world()
  local tim = mk(w, { name = "Stromham", full = "Stromham Hamson" })
  local a = mk(w, { name = "Ghoul", full = "Ghoul Grim", random = function() return 0 end, bags = { [0] = { item(2589, 20) } } })
  tim:login(); a:login()
  w:advance(60)
  a:slash("stash share on")
  tim:slash("stash linen")
  w:advance(11)
  check("F8b baseline: Ghoul answers the first search", rows(tim)[1] ~= nil)
  w:advance(120)
  local tim2 = tim:reload()
  w:advance(30)
  tim2:slash("stash linen")
  w:advance(11)
  check("F8b: after the asker's /reload, the search is answered", rows(tim2)[1] == "Ghoul Grim: Linen Cloth x20")
end
do
  local w = H.world()
  local a = mk(w, { name = "Ghoul", full = "Ghoul Grim", random = function() return 0 end, bags = { [0] = { item(2589, 20) } } })
  a:login()
  w:advance(30)
  a:slash("stash share on")
  local function ask(q, from)
    inject(a, "STASHQ", K2 .. (from or "Stromham Hamson"), { q = tostring(q), term = "linen" })
  end
  ask(1)
  for i = 2, 10 do w:advance(1); ask(i) end
  w:advance(10)
  check("F6d: ten searches from one asker in 10 s, each with a new id: one answer", #sentKind(a, "STASH") == 1)
  check("F6d: the rest are counted in stash.dropped", a:db().stash.dropped == 9)
  ask(11, "Wight Pale")
  w:advance(10)
  check("F6d: the limit is per asker: another asker is answered", #sentKind(a, "STASH") == 2)
  w:advance(1)
  ask(12)
  w:advance(10)
  check("F6d: 30 s later the same asker is answered again", #sentKind(a, "STASH") == 3)
end

-- ---------------------------------------------------------------- own rc3 short key folds in
do
  local w = H.world()
  local db = { schema = 3, settings = { stash = { share = true } }, stash = { badStash = 0, chars = {
    [K2 .. "Stromham"] = { bags = { [2589] = 3 }, bank = { [2592] = 9 }, bankAt = "2026-11-01 10:00:00" },
    [K2 .. "Gizzardthe"] = { bags = { [4338] = 1 }, bank = {} } } } }
  local a = mk(w, { name = "Stromham", full = "Stromham Hamson", db = db, bags = { [0] = { item(2589, 20) } } })
  a:login()
  local chars = db.stash.chars
  check("own short key: folded into the full key at login (bank kept, bags rescanned)", chars[K2 .. "Stromham"] == nil
    and chars[K2 .. "Stromham Hamson"].bank[2592] == 9 and chars[K2 .. "Stromham Hamson"].bags[2589] == 20)
  check("another character's short key is left for its own login", chars[K2 .. "Gizzardthe"] ~= nil)
end

H.finish("stash")
