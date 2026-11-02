-- Offline checks for Stash.lua (card 6: guild stash search).
--   lua5.1 DeadTired/tests/test_stash.lua  (from the repo root)
-- Stubs added here, per client, on client.env (card 1's harness is not changed): Enum.BagIndex,
-- C_Container (GetContainerNumSlots, GetContainerItemInfo), C_Item (GetItemNameByID,
-- RequestLoadItemDataByID). c.bags[bag][slot] = { itemID, stackCount, isBound }.
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
  c.env.C_Item = {
    GetItemNameByID = function(id) return c.names[id] end,
    RequestLoadItemDataByID = function(id) c.requested[id] = true end,
  }
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
    alt:db().stash.chars["Classic Beta PvP-Bonechill"].bags[4338] == 15 and alt:db().stash.chars["Classic Beta PvP-Stromham"] ~= nil)
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

-- ---------------------------------------------------------------- searching and answering
do
  local w = H.world()
  local tim = client(w, { name = "Stromham" })
  local a = client(w, { name = "Ghoul", random = function() return 0 end, bags = { [0] = { item(2589, 20), item(2996, 4) } } })
  local b = client(w, { name = "Wight", bags = { [0] = { item(2589, 99) } } })                 -- sharing off
  a:slash("stash share on")
  -- a's alt, same account, with more linen
  a:db().stash.chars["Classic Beta PvP-Ghoulalt"] = { bags = { [2589] = 50 }, bank = { [2589] = 10 } }
  tim:slash("stash Linen")
  check("a search sends STASHQ with the term, and says so", sentKind(tim, "STASHQ")[1] == "1^STASHQ^q~1^term~Linen"
    and tim.printed[1] == P .. "Asking the guild. Answers in 10 seconds.")
  w:advance(0.9)
  check("nobody answers before 1 s", #a.sent == 0)
  w:advance(0.2)
  local ans = sentKind(a, "STASH")[1]
  check("a sharing member answers once: the alt's items under the alt's name, largest first",
    ans == "1^STASH^hits~2589:60:Ghoulalt,2589:20:Ghoul,2996:4:Ghoul^q~1^to~Classic Beta PvP-Stromham")
  check("a member with sharing off sends nothing and doesn't note the question", #b.sent == 0
    and next(b.DT._stash.answered()) == nil)
  tim.printed = {}
  w:advance(10)
  check("the summary: one line per holder, in arrival order", tim.printed[1] == P .. "Ghoulalt: Linen Cloth x60"
    and tim.printed[2] == P .. "Ghoul: Linen Cloth x20, Bolt of Linen Cloth x4" and tim.printed[3] == CLOSING)
  check("receivers print nothing", #a.printed == 1 and #b.printed == 0)  -- a's one line is its own share-on reply
  -- a duplicate STASHQ gets no second answer
  a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^STASHQ^q~1^term~Linen", "GUILD", "Stromham-ClassicBetaPvP")
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
    a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^STASHQ^q~8^term~[[[", "GUILD", "Lich-ClassicBetaPvP")
    w:advance(10)
  end)
  check("a term like %a+ or [[[ matches literally and never errors", ok and #sentKind(a, "STASH") == 1)
  -- the 5-hit cap
  a:db().stash.chars["Classic Beta PvP-Ghoulalt"].bags = { [2589] = 1, [2592] = 2, [4306] = 3, [4338] = 4, [14047] = 5 }
  a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^STASHQ^q~9^term~cloth", "GUILD", "Lich-ClassicBetaPvP")
  w:advance(10)
  local capped = sentKind(a, "STASH")[2] or ""
  local n = select(2, capped:gsub(":", ":")) / 2
  check("at most 5 hits, largest first", n == 5 and capped:find("hits~2589:20:Ghoul,2589:11:Ghoulalt,14047:5:Ghoulalt,2996:4:Ghoul,4338:4:Ghoulalt^", 1, true) ~= nil)
  -- a holder name over 12 bytes is left out (the wire limit)
  a:db().stash.chars["Classic Beta PvP-Ståhlgéhéimnís"] = { bags = { [2770] = 7 }, bank = {} }
  a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^STASHQ^q~10^term~copper", "GUILD", "Lich-ClassicBetaPvP")
  w:advance(10)
  check("a holder name over 12 bytes is left out of answers", #sentKind(a, "STASH") == 2)
  -- sharing turned off between question and answer
  a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^STASHQ^q~11^term~linen", "GUILD", "Lich-ClassicBetaPvP")
  a:db().stash.share = false
  w:advance(10)
  check("sharing turned off before the delay ends: no answer", #sentKind(a, "STASH") == 2)
end

-- ---------------------------------------------------------------- receiving: validation and addressing
do
  local w = H.world()
  local tim = client(w, { name = "Stromham" })
  local function inject(text, from) tim:fire("CHAT_MSG_ADDON", "DEADTIRED", text, "GUILD", (from or "Ghoul") .. "-ClassicBetaPvP") end
  tim:slash("stash linen")
  inject("1^STASH^hits~2589:3:Ghoul^q~1^to~Classic Beta PvP-Stromham", "Ghoul")
  inject("1^STASH^hits~2589:9:Ghoul^q~1^to~Classic Beta PvP-Stromham", "Ghoul")
  inject("1^STASH^hits~2589:5:Wight^q~1^to~Classic Beta PvP-Someone", "Wight")
  inject("1^STASH^hits~2589:6:Lich^q~2^to~Classic Beta PvP-Stromham", "Lich")
  inject("1^STASH^hits~99999:2:Bones^q~1^to~Classic Beta PvP-Stromham", "Bones")
  tim.printed = {}
  w:advance(10)
  check("once per sender; addressed elsewhere and other searches ignored", tim.printed[1] == P .. "Ghoul: Linen Cloth x3")
  check("an unloaded item shows as item <id>, and its load is requested", tim.printed[2] == P .. "Bones: item 99999 x2"
    and tim.requested[99999] == true)
  inject("1^STASH^hits~2589:1:Late^q~1^to~Classic Beta PvP-Stromham", "Late")
  check("an answer after the summary is ignored", #tim.printed == 3 and tim.DT._stash.open() == nil)
  local bad = { "1^STASH^hits~2589:3:Ghoul^q~x^to~R-N", "1^STASH^hits~2589:3:Ghoul^q~1^to~NoRealm",
    "1^STASH^hits~^q~1^to~R-N", "1^STASH^q~1^to~R-N", "1^STASH^hits~12345678:3:Ghoul^q~1^to~R-N",
    "1^STASH^hits~2589:0:Ghoul^q~1^to~R-N", "1^STASH^hits~2589:100000:Ghoul^q~1^to~R-N",
    "1^STASH^hits~2589:3:Abcdefghijklm^q~1^to~R-N", "1^STASH^hits~2589:3^q~1^to~R-N",
    "1^STASH^hits~2589:3:Ghoul,^q~1^to~R-N", "1^STASH^hits~1:1:A,2:1:A,3:1:A,4:1:A,5:1:A,6:1:A^q~1^to~R-N",
    "1^STASHQ^q~1^term~ab", "1^STASHQ^q~abc^term~linen" }
  for _, t in ipairs(bad) do inject(t) end
  check("each invalid STASH / STASHQ field is counted in badStash, nothing printed", tim:db().stash.badStash == #bad
    and #tim.printed == 3)
end

-- ---------------------------------------------------------------- byte budget
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local E = a.DT._comms.encode
  local hits = table.concat({ "1234567:99999:Abcdefghijkl", "1234567:99999:Abcdefghijkl", "1234567:99999:Abcdefghijkl",
    "1234567:99999:Abcdefghijkl", "1234567:99999:Abcdefghijkl" }, ",")
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

H.finish("stash")
