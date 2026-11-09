-- Offline checks for Stash.lua (card 6: guild stash search).
--   lua5.1 DeadTired/tests/test_stash.lua  (from the repo root)
-- Stubs added here, per client, on client.env (card 1's harness is not changed): Enum.BagIndex,
-- C_Container (GetContainerNumSlots, GetContainerItemInfo), C_Item (GetItemNameByID,
-- RequestLoadItemDataByID, and (A4) IsBound over c.slotBound["bag:slot"]), and ItemLocation's
-- CreateFromBagAndSlot. c.bags[bag][slot] = { itemID, stackCount, isBound }.
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local ALL = {}
for _, f in ipairs(H.FILES) do ALL[#ALL + 1] = f end
for _, f in ipairs({ "Stash.lua", "Played.lua", "EventsList.lua", "Events.lua" }) do ALL[#ALL + 1] = f end
local P = "|cff7fa650Dead Tired|r "
local CLOSING = P .. "Only guildies running the addon with stash sharing on answer."
local NAMES = { [2589] = "Linen Cloth", [2592] = "Wool Cloth", [4306] = "Silk Cloth", [2996] = "Bolt of Linen Cloth",
  [6948] = "Hearthstone", [4338] = "Mageweave Cloth", [14047] = "Runecloth", [2770] = "Copper Ore" }

local function client(w, opts)
  opts.files = opts.files or ALL
  if opts.guild == nil and not opts.outside then opts.guild = G end
  opts.random = opts.random or function() return 0.5 end
  local c = w:client(opts)
  c.bags, c.names, c.requested, c.scans = opts.bags or {}, {}, {}, 0
  for k, v in pairs(NAMES) do c.names[k] = v end
  local idx = { Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4, Bank = -1, BankBag_1 = 6, BankBag_2 = 7 }
  if opts.noBank then idx.Bank, idx.BankBag_1, idx.BankBag_2 = nil, nil, nil end
  c.env.Enum = { BagIndex = idx }
  c.env.C_Container = {
    GetContainerNumSlots = function(b) if b == 0 then c.scans = c.scans + 1 end return c.bags[b] and 16 or 0 end,
    GetContainerItemInfo = function(b, s) return c.bags[b] and c.bags[b][s] end,
  }
  c.slotBound = {}
  c.env.C_Item = {
    GetItemNameByID = function(id) return c.names[id] end,
    RequestLoadItemDataByID = function(id) c.requested[id] = true end,
    IsBound = function(loc)
      local v = c.slotBound[loc.bag .. ":" .. loc.slot]
      if v == "error" then error("no item there") end
      return v
    end,
  }
  c.env.ItemLocation = { CreateFromBagAndSlot = function(self, b, sl) return { bag = b, slot = sl } end }
  return c
end
local function item(id, n, bound) return { itemID = id, stackCount = n, isBound = bound or false } end
local function sentKind(c, kind)
  local out = {}
  for _, s in ipairs(c.sent) do if s.text:find("^1%^" .. kind .. "%^") then out[#out + 1] = s.text end end
  return out
end
local function mine(c) return c:db().stash.chars[c:key()] end

-- ---------------------------------------------------------------- store and verbs
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local s = a:db().stash
  check("store: DeadTiredDB.stash, sharing off, badStash 0, no characters", s.share == false and s.badStash == 0
    and next(s.chars) == nil)
  a:slash("")
  check("the help lists stash with its usage, no bar", a:said("stash [item/share on/off]") ~= nil)
  a:slash("stash"); check("/dt stash alone, sharing off", a.printed[1] == P .. "Sharing off. Nothing offered.")
  a:slash("stash share"); check("/dt stash share shows the setting", a:said("stash sharing is off.") ~= nil)
  a:slash("stash ab"); check("a 2-letter term is refused", a:said("/dt stash <item, 3-32 letters>") ~= nil and #a.sent == 0)
  a:slash("stash " .. string.rep("x", 33)); check("a 33-letter term is refused", #a.sent == 0)
  a:slash("stash share on")
  check("A4: the share-on line says answers name the holder", #a.printed == 1 and a.printed[1]
    == P .. "stash sharing on. Guildies' searches see your tradeable items, four at a time, and which character holds them.")
end

-- ---------------------------------------------------------------- scanning
do
  local w = H.world()
  local a = client(w, { name = "Stromham", bags = { [0] = { item(2589, 20), item(2589, 7), item(6948, 1, true) },
    [2] = { [5] = item(2592, 12), [6] = { itemID = "x", stackCount = 3 }, [7] = { itemID = 4306 }, [8] = item(4306, 0) } } })
  a:login()
  check("sharing off: no scan at login, no list", a.scans == 0 and mine(a) == nil)
  a:fire("BAG_UPDATE_DELAYED"); a:fire("BANKFRAME_OPENED")
  check("sharing off: no scan on bag or bank events", a.scans == 0 and mine(a) == nil)
  a:slash("stash share on")
  local e = mine(a)
  check("sharing on scans the bags at once", e and e.bags[2589] == 27 and e.bags[2592] == 12 and e.at == "2026-11-04 23:00:00")
  check("a bound item is never listed", e.bags[6948] == nil)
  check("bad slot info is skipped", e.bags[4306] == nil)
  check("and the bank is not read yet", next(e.bank) == nil and e.bankAt == nil)
  a.bags[1] = { item(2770, 5) }
  w:advance(10)   -- (the bag event fired while sharing was off left one rescan pending; it has run)
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
  -- an alt on the same account adds its own entry
  a:logout()
  local alt = client(w, { name = "Bonechill", db = a:db(), bags = { [0] = { item(4338, 15) } } })
  alt:login()
  check("an alt on the same account adds its own entry, keeping the main's",
    alt:db().stash.chars["ClassicBetaPvP-Bonechill"].bags[4338] == 15 and alt:db().stash.chars["ClassicBetaPvP-Stromham"] ~= nil)
  alt:slash("stash")
  check("/dt stash on the alt: bank not read yet", alt:said("across 2 characters (bank not read yet)") ~= nil)
  alt:slash("stash share off")
  check("sharing off deletes the account's list", next(alt:db().stash.chars) == nil and alt:said("Your list is gone") ~= nil)
  -- no bank constant on this client
  local w2 = H.world()
  local n = client(w2, { name = "Nobank", noBank = true, bags = { [0] = { item(2589, 1) }, [-1] = { item(2592, 9) } } })
  n:slash("stash share on")
  n:fire("BANKFRAME_OPENED")
  check("Enum.BagIndex.Bank absent: the bank is never read", next(mine(n).bank) == nil and n.DT._stash.bankIDs() == nil)
  n:slash("stash")
  check("and /dt stash says so", n:said("(bank not read on this client)") ~= nil)
  n.env.Enum = nil
  n.bags[3] = { item(2770, 2) }
  n.DT._stash.scanBags()
  check("Enum absent: bags 0-4 are still read", mine(n).bags[2770] == 2)
end

-- ---------------------------------------------------------------- A4: listed only when known not bound
do
  local function nb(id) return { itemID = id, stackCount = 1 } end    -- isBound nil: the client didn't say
  local function bagsFor(bag)
    -- slot: 1 isBound false, 2 true, 3 nil + IsBound false, 4 nil + true, 5 nil + nil,
    --       6 nil + erroring, 7 nil + not a boolean
    return { [bag] = { item(101, 1, false), item(102, 1, true), nb(103), nb(104), nb(105), nb(106), nb(107) } }
  end
  local function setSlots(c, bag)
    c.slotBound[bag .. ":3"], c.slotBound[bag .. ":4"] = false, true
    c.slotBound[bag .. ":6"], c.slotBound[bag .. ":7"] = "error", "yes"
  end
  local function cases(where, bag, list)
    check("A4 " .. where .. ": isBound false is listed", list[101] == 1)
    check("A4 " .. where .. ": isBound true is skipped", list[102] == nil)
    check("A4 " .. where .. ": isBound nil, C_Item.IsBound false: listed", list[103] == 1)
    check("A4 " .. where .. ": isBound nil, C_Item.IsBound true: skipped", list[104] == nil)
    check("A4 " .. where .. ": isBound nil, C_Item.IsBound nil: skipped", list[105] == nil)
    check("A4 " .. where .. ": isBound nil, C_Item.IsBound erroring: skipped", list[106] == nil)
    check("A4 " .. where .. ": isBound nil, C_Item.IsBound not a boolean: skipped", list[107] == nil)
  end
  local w = H.world()
  local a = client(w, { name = "Stromham", bags = bagsFor(0) })
  setSlots(a, 0)
  a:slash("stash share on")
  cases("bags", 0, mine(a).bags)
  local k = client(w, { name = "Banker", bags = bagsFor(-1) })
  setSlots(k, -1)
  k:slash("stash share on"); k:fire("BANKFRAME_OPENED")
  cases("bank", -1, mine(k).bank)
  local kb = client(w, { name = "Bankbag", bags = bagsFor(6) })
  setSlots(kb, 6)
  kb:slash("stash share on"); kb:fire("BANKFRAME_OPENED")
  cases("bank bag", 6, mine(kb).bank)
  -- the bound read unavailable: only isBound == false is listed
  for _, how in ipairs({ "C_Item.IsBound absent", "ItemLocation absent", "CreateFromBagAndSlot erroring",
      "a secret IsBound answer" }) do
    local c = client(w, { name = "Unknown" .. #how, bags = { [0] = { item(101, 1, false), nb(103) }, [-1] = { nb(108) } } })
    c.slotBound["0:1"], c.slotBound["0:2"], c.slotBound["-1:1"] = false, false, false
    if how == "C_Item.IsBound absent" then c.env.C_Item.IsBound = nil
    elseif how == "ItemLocation absent" then c.env.ItemLocation = nil
    elseif how == "CreateFromBagAndSlot erroring" then c.env.ItemLocation.CreateFromBagAndSlot = function() error("no") end
    else
      c.env.issecretvalue = function(v) return v == false end   -- every false is secret here
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
  local tim = client(w, { name = "Stromham" })
  local a = client(w, { name = "Ghoul", random = function() return 0 end, bags = { [0] = { item(2589, 20), item(2996, 4) } } })
  local b = client(w, { name = "Wight", bags = { [0] = { item(2589, 99) } } })                 -- sharing off
  a:slash("stash share on")
  -- a's alt, same account, with more linen
  a:db().stash.chars["ClassicBetaPvP-Ghoulalt"] = { bags = { [2589] = 50 }, bank = { [2589] = 10 } }
  tim:slash("stash Linen")
  local q1 = tostring(tim.env.time() % 1000000)   -- F8b: the id is the clock, not a counter
  check("a search sends STASHQ with the term, and says so", sentKind(tim, "STASHQ")[1] == "1^STASHQ^q~" .. q1 .. "^term~Linen"
    and tim.printed[1] == P .. "Asking the guild. Answers in 10 seconds.")
  w:advance(0.9)
  check("nobody answers before 1 s", #a.sent == 0)
  w:advance(0.2)
  local ans = sentKind(a, "STASH")[1]
  check("a sharing member answers once: the alt's items under the alt's name, largest first",
    ans == "1^STASH^hits~2589:60:Ghoulalt,2589:20:Ghoul,2996:4:Ghoul^q~" .. q1 .. "^to~ClassicBetaPvP-Stromham")
  check("a member with sharing off sends nothing and doesn't note the question", #b.sent == 0
    and next(b.DT._stash.answered()) == nil)
  tim.printed = {}
  w:advance(10)
  check("the summary: one line per holder, in arrival order", tim.printed[1] == P .. "Ghoulalt: Linen Cloth x60"
    and tim.printed[2] == P .. "Ghoul: Linen Cloth x20, Bolt of Linen Cloth x4" and tim.printed[3] == CLOSING)
  check("receivers print nothing", #a.printed == 1 and #b.printed == 0)  -- a's one line is its own share-on reply
  -- a duplicate STASHQ gets no second answer
  a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^STASHQ^q~" .. q1 .. "^term~Linen", "GUILD", "Stromham-ClassicBetaPvP")
  w:advance(10)
  check("one answer per asker and search", #sentKind(a, "STASH") == 1)
  -- the 30 s window (21 s have passed)
  tim:slash("stash wool")
  check("a second search inside 30 s is refused", tim.printed[1] == P .. "One search at a time. The crypt echoes."
    and #sentKind(tim, "STASHQ") == 1)
  w:advance(10)
  tim:slash("stash wool")
  check("after 30 s a new search goes out", #sentKind(tim, "STASHQ") == 2)
  tim.printed = {}
  w:advance(11)
  check("no hits means no answer, and the summary says so", #sentKind(a, "STASH") == 1
    and tim.printed[1] == P .. "Nobody's got it. Or nobody's sharing." and tim.printed[2] == CLOSING)
  -- patterns are plain text
  w:advance(31)
  local ok = pcall(function()
    a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^STASHQ^q~7^term~%a+", "GUILD", "Lich-ClassicBetaPvP")
    a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^STASHQ^q~8^term~[[[", "GUILD", "Wraith-ClassicBetaPvP")   -- one asker each: F6d
    w:advance(10)
  end)
  check("a term like %a+ or [[[ matches literally and never errors", ok and #sentKind(a, "STASH") == 1)
  -- the 4-hit cap
  a:db().stash.chars["ClassicBetaPvP-Ghoulalt"].bags = { [2589] = 1, [2592] = 2, [4306] = 3, [4338] = 4, [14047] = 5 }
  a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^STASHQ^q~9^term~cloth", "GUILD", "Banshee-ClassicBetaPvP")
  w:advance(10)
  local capped = sentKind(a, "STASH")[2] or ""
  local n = select(2, capped:gsub(":", ":")) / 2
  check("at most 4 hits, largest first", n == 4 and capped:find("hits~2589:20:Ghoul,2589:11:Ghoulalt,14047:5:Ghoulalt,2996:4:Ghoul^", 1, true) ~= nil)
  -- holder names: a 12-letter name with every letter accented is 24 bytes and is answered;
  -- anything over 24 bytes (no real name is) is left out (the wire limit)
  local accented = "\195\133\195\164\195\182\195\169\195\168\195\170\195\173\195\172\195\174\195\179\195\178\195\180"
  a:db().stash.chars["ClassicBetaPvP-" .. accented] = { bags = { [2770] = 7 }, bank = {} }
  a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^STASHQ^q~10^term~copper", "GUILD", "Ghast-ClassicBetaPvP")
  w:advance(10)
  check("a 12-letter accented holder name (24 bytes) is answered", #accented == 24 and #sentKind(a, "STASH") == 3
    and sentKind(a, "STASH")[3]:find("hits~2770:7:" .. accented .. "^", 1, true) ~= nil)
  a:db().stash.chars["ClassicBetaPvP-" .. accented] = nil
  a:db().stash.chars["ClassicBetaPvP-" .. accented .. "x"] = { bags = { [2770] = 7 }, bank = {} }
  a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^STASHQ^q~12^term~copper", "GUILD", "Shade-ClassicBetaPvP")
  w:advance(10)
  check("a holder name over 24 bytes is left out of answers", #sentKind(a, "STASH") == 3)
  -- sharing turned off between question and answer
  a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^STASHQ^q~11^term~linen", "GUILD", "Revenant-ClassicBetaPvP")
  a:db().stash.share = false
  w:advance(10)
  check("sharing turned off before the delay ends: no answer", #sentKind(a, "STASH") == 3)
end

-- ---------------------------------------------------------------- receiving: validation and addressing
do
  local w = H.world()
  local tim = client(w, { name = "Stromham" })
  local function inject(text, from) tim:fire("CHAT_MSG_ADDON", "DEADTIRED", text, "GUILD", (from or "Ghoul") .. "-ClassicBetaPvP") end
  tim:slash("stash linen")
  local Q = tostring(tim.env.time() % 1000000)   -- F8b
  inject("1^STASH^hits~2589:3:Ghoul^q~" .. Q .. "^to~ClassicBetaPvP-Stromham", "Ghoul")
  inject("1^STASH^hits~2589:9:Ghoul^q~" .. Q .. "^to~ClassicBetaPvP-Stromham", "Ghoul")
  inject("1^STASH^hits~2589:5:Wight^q~" .. Q .. "^to~ClassicBetaPvP-Someone", "Wight")
  inject("1^STASH^hits~2589:6:Lich^q~" .. (Q + 1) % 1000000 .. "^to~ClassicBetaPvP-Stromham", "Lich")
  inject("1^STASH^hits~99999:2:Bones^q~" .. Q .. "^to~ClassicBetaPvP-Stromham", "Bones")
  inject("1^STASH^hits~2592:4:Oldie^q~" .. Q .. "^to~Classic Beta PvP-Stromham", "Oldie")   -- AUD-06
  tim.printed = {}
  w:advance(10)
  check("once per sender; addressed elsewhere and other searches ignored", tim.printed[1] == P .. "Ghoul: Linen Cloth x3")
  check("an unloaded item shows as item <id>, and its load is requested", tim.printed[2] == P .. "Bones: item 99999 x2"
    and tim.requested[99999] == true)
  check("AUD-06: an answer whose to is in the old spaced spelling still arrives", tim.printed[3] == P .. "Oldie: Wool Cloth x4")
  inject("1^STASH^hits~2589:1:Late^q~" .. Q .. "^to~ClassicBetaPvP-Stromham", "Late")
  check("an answer after the summary is ignored", #tim.printed == 4 and tim.DT._stash.open() == nil)
  local bad = { "1^STASH^hits~2589:3:Ghoul^q~x^to~R-N", "1^STASH^hits~2589:3:Ghoul^q~1^to~NoRealm",
    "1^STASH^hits~^q~1^to~R-N", "1^STASH^q~1^to~R-N", "1^STASH^hits~12345678:3:Ghoul^q~1^to~R-N",
    "1^STASH^hits~2589:0:Ghoul^q~1^to~R-N", "1^STASH^hits~2589:100000:Ghoul^q~1^to~R-N",
    "1^STASH^hits~2589:3:Abcdefghijklmnopqrstuvwxy^q~1^to~R-N", "1^STASH^hits~2589:3^q~1^to~R-N",
    "1^STASH^hits~2589:3:Ghoul,^q~1^to~R-N", "1^STASH^hits~1:1:A,2:1:A,3:1:A,4:1:A,5:1:A^q~1^to~R-N",
    "1^STASHQ^q~1^term~ab", "1^STASHQ^q~abc^term~linen" }
  for _, t in ipairs(bad) do inject(t) end
  check("each invalid STASH / STASHQ field is counted in badStash, nothing printed", tim:db().stash.badStash == #bad
    and #tim.printed == 4)
end

-- ---------------------------------------------------------------- receiving a 24-byte holder name
do
  local w = H.world()
  local tim = client(w, { name = "Stromham" })
  local holder = string.rep("\195\169", 12)   -- 12 accented letters, 24 bytes
  tim:slash("stash linen")
  local Q = tostring(tim.env.time() % 1000000)   -- F8b
  tim:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^STASH^hits~2589:3:" .. holder .. "^q~" .. Q .. "^to~ClassicBetaPvP-Stromham",
    "GUILD", "Ghoul-ClassicBetaPvP")
  tim.printed = {}
  w:advance(10)
  check("a received answer with a 24-byte holder is kept and printed", tim.printed[1] == P .. holder .. ": Linen Cloth x3"
    and tim:db().stash.badStash == 0)
end

-- ---------------------------------------------------------------- byte budget
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local E = a.DT._comms.encode
  local holder = string.rep("\195\169", 12)   -- 12 accented letters, 24 bytes
  local hits = table.concat({ "1234567:99999:" .. holder, "1234567:99999:" .. holder, "1234567:99999:" .. holder,
    "1234567:99999:" .. holder }, ",")
  local m1 = E("STASH", { q = "999999", to = string.rep("r", 58) .. "-Abcde", hits = hits })
  local m2 = E("STASHQ", { q = "999999", term = string.rep("^", 32) })
  print("stash: longest STASH is " .. #m1 .. " bytes, longest STASHQ is " .. #m2 .. " bytes")
  check("the longest STASH and STASHQ are at most 250 bytes", #m1 <= 250 and #m2 <= 250)
end

-- ---------------------------------------------------------------- the whole addon
do
  local w = H.world()
  local tim = client(w, { name = "Stromham" })
  local a = client(w, { name = "Ghoul", bags = { [0] = { item(2589, 20) } } })
  local x = client(w, { name = "Spy", guild = "Alliance Spies", bags = { [0] = { item(2589, 20) } } })
  a:db().stash.share, x:db().stash.share = true, true
  tim:login(); a:login(); x:login()
  w:advance(60)
  check("a login prints only card 1's welcome", #tim.printed == 1 and #a.printed == 1 and #x.printed == 0)
  check("a non-member keeps no list even with sharing on", next(x:db().stash.chars) == nil)
  tim:slash("stash linen"); w:advance(11)
  check("a search works end to end", tim:said("Ghoul: Linen Cloth x20") ~= nil)
  check("the non-member sends and prints nothing", #x.sent == 0 and #x.printed == 0)
end

-- ---------------------------------------------------------------- fix round 1 (F8b, F6d)
do
  local w = H.world()
  local tim = client(w, { name = "Stromham" })
  local a = client(w, { name = "Ghoul", random = function() return 0 end, bags = { [0] = { item(2589, 20) } } })
  tim:login(); a:login()
  w:advance(60)
  a:slash("stash share on")
  tim:slash("stash linen")
  w:advance(11)
  check("F8b baseline: Ghoul answers the first search", tim:said("Ghoul: ") ~= nil)
  w:advance(120)
  local tim2 = tim:reload()
  w:advance(30)
  tim2:slash("stash linen")
  w:advance(11)
  check("F8b: after the asker's /reload, the search is answered", tim2:said("Ghoul: ") ~= nil)
  local tim3 = tim2:reboot(900)
  w:advance(60)
  tim3:slash("stash linen")
  w:advance(11)
  check("F8b: after a restart too", tim3:said("Ghoul: ") ~= nil)
end

do
  local w = H.world()
  local a = client(w, { name = "Ghoul", random = function() return 0 end, bags = { [0] = { item(2589, 20) } } })
  a:login()
  w:advance(5)
  a:slash("stash share on")
  local function ask(q, from)
    a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^STASHQ^q~" .. q .. "^term~linen", "GUILD", (from or "Stromham") .. "-ClassicBetaPvP")
  end
  ask(1)
  for i = 2, 10 do w:advance(1); ask(i) end
  w:advance(10)
  check("F6d: ten searches from one asker in 10 s, each with a new id: one answer", #sentKind(a, "STASH") == 1)
  check("F6d: the rest are counted in stash.dropped", a:db().stash.dropped == 9)
  ask(11, "Wight")
  w:advance(10)
  check("F6d: the limit is per asker: another asker is answered", #sentKind(a, "STASH") == 2)
  w:advance(1)    -- 30 s after the first (t0 + 9 + 10 + 10 + 1)
  ask(12)
  w:advance(10)
  check("F6d: 30 s later the same asker is answered again", #sentKind(a, "STASH") == 3)
end

-- ---------------------------------------------------------------- fix round 3 (AUD-06)
do
  local w = H.world()
  local db = { stash = { share = true, badStash = 0, chars = {
    ["Classic Beta PvP-Bonechill"] = { bags = { [4338] = 15 }, bank = {} } } } }
  local a = client(w, { name = "Stromham", db = db })
  local chars = db.stash.chars
  check("AUD-06: an old spaced key in the stash is rewritten", chars["ClassicBetaPvP-Bonechill"]
    and chars["ClassicBetaPvP-Bonechill"].bags[4338] == 15 and chars["Classic Beta PvP-Bonechill"] == nil
    and db.stash.keysV == 2)
  a:login()
  local n = 0
  for _ in pairs(chars) do n = n + 1 end
  check("AUD-06: the logged-in character's own list joins it, two characters, one spelling", n == 2
    and chars["ClassicBetaPvP-Stromham"] ~= nil)
  chars["Classic Beta PvP-Ghoulalt"] = { bags = {}, bank = {} }
  client(w, { name = "Stromham", db = db })
  check("AUD-06: the stash migration runs once", chars["Classic Beta PvP-Ghoulalt"] ~= nil)
end

H.finish("stash")
