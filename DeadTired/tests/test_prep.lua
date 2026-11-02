-- Offline checks for PrepList.lua and Prep.lua (card 5: raid-prep bag check and roll call).
--   lua5.1 DeadTired/tests/test_prep.lua  (from the repo root)
-- Stubs added here, per client, on client.env (card 1's harness is not changed): UnitClass and
-- C_Item (GetItemCount, GetItemNameByID, RequestLoadItemDataByID). c.bags[id] = count.
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"
local ALL = {}
for _, f in ipairs(H.FILES) do ALL[#ALL + 1] = f end
for _, f in ipairs({ "PrepList.lua", "Prep.lua", "RecruitLines.lua", "Recruit.lua" }) do ALL[#ALL + 1] = f end
local P = "|cff7fa650Dead Tired|r "
local CLOSING = P .. "Only guildies running the addon with sharing on answer."

local function client(w, opts)
  opts.files = opts.files or ALL
  if opts.guild == nil and not opts.outside then opts.guild = G end
  opts.random = opts.random or function() return 0.5 end
  local c = w:client(opts)
  c.cls, c.bags, c.names, c.requested, c.banks = opts.cls or "PRIEST", {}, {}, {}, {}
  c.env.UnitClass = function(u)
    if u ~= "player" then return nil end
    if c.cls == "error" then error("no class") end
    if not c.cls then return nil end
    return c.cls:sub(1, 1) .. c.cls:sub(2):lower(), c.cls, 5
  end
  c.env.C_Item = {
    GetItemCount = function(id, bank)
      c.banks[#c.banks + 1] = bank
      if c.countError then error("no count") end
      return c.bags[id] or 0
    end,
    GetItemNameByID = function(id) return c.names[id] end,
    RequestLoadItemDataByID = function(id) c.requested[id] = true end,
  }
  return c
end
local function sentKind(c, kind)
  local out = {}
  for _, s in ipairs(c.sent) do if s.text:find("^1%^" .. kind .. "%^") then out[#out + 1] = s.text end end
  return out
end

-- ---------------------------------------------------------------- the list, the store, the verb
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  check("the starter list loads: 8 entries, every one with an id, name and need", #a.ns.PrepList == 8
    and (function() for _, e in ipairs(a.ns.PrepList) do
      if type(e.id) ~= "number" or type(e.name) ~= "string" or type(e.need) ~= "number" then return false end end
      return true end)())
  local p = a:db().prep
  check("store: DeadTiredDB.prep, sharing off by default, badPrep 0", type(p) == "table" and p.share == false and p.badPrep == 0)
  a:slash("")
  check("the help lists prep with its usage, no bar", a:said("prep [list/check/share on/off]") ~= nil)
  a:slash("prep share"); check("/dt prep share shows the setting", a:said("sharing is off.") ~= nil)
  a:slash("prep share on"); check("/dt prep share on", p.share == true and a:said("sharing on.") ~= nil)
  a:slash("prep share off"); check("/dt prep share off", p.share == false and a:said("sharing off.") ~= nil)
  a:slash("prep nonsense"); check("/dt prep <other> prints usage", a:said("/dt prep, /dt prep list") ~= nil)
end

-- ---------------------------------------------------------------- /dt prep
do
  local w = H.world()
  local a = client(w, { name = "Stromham", cls = "PRIEST" })
  a:slash("prep")
  check("a priest with empty bags: short on the class-less entry and the priest one, in list order",
    #a.printed == 1 and a.printed[1] == P .. "Short: Major Healing Potion 0/5, Sacred Candle 0/20.")
  check("bags only: the bank flag is passed as false, every time", #a.banks == 2 and a.banks[1] == false and a.banks[2] == false)
  a.bags[13446], a.bags[17029] = 5, 19
  a:slash("prep")
  check("counts from the bags; one short", a.printed[1] == P .. "Short: Sacred Candle 19/20.")
  a.bags[17029] = 40
  a:slash("prep")
  check("all met: ready, exactly", a.printed[1] == P .. "Ready. Bags packed, coffin optional.")
  a.cls = "ROGUE"
  a:slash("prep")
  check("class filter: a rogue is checked for Flash Powder, not candles", a.printed[1] == P .. "Short: Flash Powder 0/10.")
  a.cls = nil
  a:slash("prep")
  check("class unreadable: only class-less entries apply", a.printed[1] == P .. "Ready. Bags packed, coffin optional.")
  a.cls = "error"
  a.bags[13446] = 0
  a:slash("prep")
  check("UnitClass erroring: class-less only", a.printed[1] == P .. "Short: Major Healing Potion 0/5.")
  a.cls, a.countError = "PRIEST", true
  a:slash("prep")
  check("GetItemCount erroring means 0", a.printed[1] == P .. "Short: Major Healing Potion 0/5, Sacred Candle 0/20.")
  a.countError = false
  a.env.C_Item.GetItemCount = nil
  a.bags[13446] = 99
  a:slash("prep")
  check("GetItemCount absent means 0", a.printed[1] == P .. "Short: Major Healing Potion 0/5, Sacred Candle 0/20.")
  check("/dt prep sends nothing", #a.sent == 0)
end

-- ---------------------------------------------------------------- /dt prep list
do
  local w = H.world()
  local a = client(w, { name = "Stromham", cls = "PRIEST" })
  a.names[13446] = "Major Healing Potion"
  a.names[17029] = "Holy Candle"
  a:slash("prep list")
  check("a matching client name", a.printed[1] == P .. "13446 Major Healing Potion x5 — client: Major Healing Potion")
  check("a differing client name is marked", a.printed[2] == P .. "17029 Sacred Candle x20 — client: Holy Candle  <- check this ID")
  a.names[17029] = nil
  a:slash("prep list")
  check("not loaded yet, and the load is requested", a.printed[2] == P .. "17029 Sacred Candle x20 — client: not loaded yet"
    and a.requested[17029] == true)
  a.names[13446] = "major healing POTION"
  a:slash("prep list")
  check("names compare case-insensitively", not a.printed[1]:find("check this ID", 1, true))
  a.ns.PrepList = {}
  a:slash("prep list")
  check("an empty list says so", a.printed[1] == P .. "Nothing on the list for you. Travel light.")
end

-- ---------------------------------------------------------------- the roll call
do
  local w = H.world()
  local tim = client(w, { name = "Stromham" })
  local a = client(w, { name = "Ghoul", random = function() return 0 end })      -- answers after 1 s
  local c = client(w, { name = "Wight", random = function() return 0.9 end })    -- after 4.6 s
  local b = client(w, { name = "Graverobber" })                                  -- sharing off
  a:db().prep.share, c:db().prep.share = true, true
  a.bags[13446], a.bags[17029] = 5, 20                                           -- ready
  tim:slash("prep check")
  local q1 = tostring(tim.env.time() % 1000000)   -- F8a: the id is the clock, not a counter
  check("/dt prep check sends PREPQ and says so", #sentKind(tim, "PREPQ") == 1 and sentKind(tim, "PREPQ")[1] == "1^PREPQ^q~" .. q1
    and tim.printed[1] == P .. "Roll call sent. Answers in 10 seconds.")
  w:advance(0.5)
  check("nobody answers before 1 s", #a.sent == 0 and #c.sent == 0)
  w:advance(1)
  check("a sharing member answers once with ok and short only", #sentKind(a, "PREP") == 1
    and sentKind(a, "PREP")[1] == "1^PREP^ok~1^q~" .. q1 .. "^short~0^to~Classic Beta PvP-Stromham")
  w:advance(4)
  check("the second within 5 s, short 2", sentKind(c, "PREP")[1] == "1^PREP^ok~0^q~" .. q1 .. "^short~2^to~Classic Beta PvP-Stromham")
  check("a member with sharing off sends nothing at all, and doesn't even note the question", #b.sent == 0
    and next(b.DT._prep.answered()) == nil)
  tim.printed = {}
  w:advance(5)
  check("the summary at 10 s, names in order of arrival", #tim.printed == 2
    and tim.printed[1] == P .. "Ready (1): Ghoul. Short (1): Wight (2 short)." and tim.printed[2] == CLOSING)
  check("receivers print nothing", #a.printed == 0 and #b.printed == 0 and #c.printed == 0)
  -- a duplicate PREPQ (same asker, same q) gets no second answer
  a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^PREPQ^q~" .. q1, "GUILD", "Stromham-ClassicBetaPvP")
  w:advance(10)
  check("a duplicate question gets no second answer", #sentKind(a, "PREP") == 1)
  -- the 60 s window
  tim:slash("prep check")
  check("a second roll call inside 60 s is refused, nothing sent", tim.printed[1] == P .. "Patience. The last roll call is still out."
    and #sentKind(tim, "PREPQ") == 1)
  w:advance(45)
  tim:slash("prep check")
  local q2 = tostring(tim.env.time() % 1000000)
  check("after 60 s: a new roll call, a new id", #sentKind(tim, "PREPQ") == 2 and sentKind(tim, "PREPQ")[2] == "1^PREPQ^q~" .. q2
    and q2 ~= q1)
  w:advance(2)
  check("a new question gets a new answer", #sentKind(a, "PREP") == 2)
  -- turning sharing off between question and answer: no answer
  c:db().prep.share = false
  w:advance(10)
  check("sharing turned off before the delay ends: no answer", #sentKind(c, "PREP") == 1)
end

-- ---------------------------------------------------------------- the summary's edges
do
  local w = H.world()
  local tim = client(w, { name = "Stromham" })
  local function inject(text, from) tim:fire("CHAT_MSG_ADDON", "DEADTIRED", text, "GUILD", (from or "Ghoul") .. "-ClassicBetaPvP") end
  tim:slash("prep check")
  tim.printed = {}
  w:advance(10)
  check("nobody answered: both parts read none", tim.printed[1] == P .. "Ready (0): none. Short (0): none."
    and tim.printed[2] == CLOSING)
  qOld = tostring((tim.env.time() - 10) % 1000000)   -- the first roll call's id (F8a: the clock)
  w:advance(60)
  tim:slash("prep check")
  local q = tostring(tim.env.time() % 1000000)
  inject("1^PREP^ok~0^q~" .. q .. "^short~3^to~Classic Beta PvP-Stromham", "Ghoul")
  inject("1^PREP^ok~0^q~" .. q .. "^short~1^to~Classic Beta PvP-Stromham", "Ghoul")
  inject("1^PREP^ok~1^q~" .. q .. "^short~0^to~Classic Beta PvP-Someoneelse", "Wight")
  inject("1^PREP^ok~1^q~" .. qOld .. "^short~0^to~Classic Beta PvP-Stromham", "Lich")
  tim.printed = {}
  w:advance(10)
  check("once per sender; addressed elsewhere and old questions ignored", tim.printed[1] == P .. "Ready (0): none. Short (1): Ghoul (3 short).")
  inject("1^PREP^ok~1^q~" .. q .. "^short~0^to~Classic Beta PvP-Stromham", "Wight")
  check("an answer after the summary is ignored (no print, nothing kept)", #tim.printed == 2 and tim.DT._prep.open() == nil)
  local bad = { "1^PREP^ok~1^q~x^short~0^to~R-N", "1^PREP^ok~1^q~1234567^short~0^to~R-N", "1^PREP^ok~2^q~1^short~0^to~R-N",
    "1^PREP^ok~1^q~1^short~1^to~R-N", "1^PREP^ok~0^q~1^short~0^to~R-N", "1^PREP^ok~0^q~1^short~51^to~R-N",
    "1^PREP^ok~0^q~1^short~-1^to~R-N", "1^PREP^ok~0^q~1^short~2^to~NoRealm", "1^PREP^ok~0^q~1^short~2",
    "1^PREP^ok~0^q~1^short~2^to~" .. string.rep("r", 62) .. "-ab", "1^PREPQ^q~abc" }
  for _, t in ipairs(bad) do inject(t) end
  check("each invalid PREP / PREPQ field is counted in badPrep", tim:db().prep.badPrep == #bad)
end

-- ---------------------------------------------------------------- byte budget
do
  local w = H.world()
  local a = client(w, { name = "Stromham" })
  local m = a.DT._comms.encode("PREP", { q = "999999", to = string.rep("r", 58) .. "-Abcde", ok = "0", short = "50" })
  print("prep: longest PREP is " .. #m .. " bytes")
  check("the longest PREP is at most 250 bytes (" .. #m .. ")", #m <= 250)
end

-- ---------------------------------------------------------------- the whole addon
do
  local w = H.world()
  local tim = client(w, { name = "Stromham" })
  local a = client(w, { name = "Ghoul" })
  local x = client(w, { name = "Spy", guild = "Alliance Spies" })
  a:db().prep.share, x:db().prep.share = true, true
  tim:login(); a:login(); x:login()
  w:advance(60)
  check("a login prints only card 1's welcome", #tim.printed == 1 and tim:said("Rest in Pieces, Stromham.")
    and #a.printed == 1 and #x.printed == 0)
  tim:slash("prep check"); w:advance(11)
  check("a roll call works end to end", tim:said("Short (1): Ghoul (2 short).") ~= nil)
  check("the non-member sends and prints nothing", #x.sent == 0 and #x.printed == 0)
end

-- ---------------------------------------------------------------- fix round 1 (F8a, F6c)
do
  local w = H.world()
  local tim = client(w, { name = "Stromham" })
  local a = client(w, { name = "Ghoul", random = function() return 0 end })
  a:db().prep.share = true
  a.bags[13446], a.bags[17029] = 5, 20
  tim:login(); a:login()
  w:advance(60)
  tim:slash("prep check")
  w:advance(11)
  check("F8a baseline: Ghoul answers the first roll call", tim:said("Ready (1): Ghoul") ~= nil)
  w:advance(120)
  local tim2 = tim:reload()
  w:advance(30)
  tim2:slash("prep check")
  w:advance(11)
  check("F8a: after the asker's /reload, the roll call is answered", tim2:said("Ready (1): Ghoul") ~= nil)
  local tim3 = tim2:reboot(900)
  w:advance(60)
  tim3:slash("prep check")
  w:advance(11)
  check("F8a: after a restart too", tim3:said("Ready (1): Ghoul") ~= nil)
end

do
  local w = H.world()
  local a = client(w, { name = "Ghoul", random = function() return 0 end })
  a:db().prep.share = true
  local function ask(q, from)
    a:fire("CHAT_MSG_ADDON", "DEADTIRED", "1^PREPQ^q~" .. q, "GUILD", (from or "Stromham") .. "-ClassicBetaPvP")
  end
  ask(1)
  for i = 2, 10 do w:advance(1); ask(i) end
  w:advance(10)
  check("F6c: ten roll calls from one asker in 10 s, each with a new id: one answer", #sentKind(a, "PREP") == 1)
  check("F6c: the rest are counted in prep.dropped", a:db().prep.dropped == 9)
  ask(11, "Wight")
  w:advance(10)
  check("F6c: the limit is per asker: another asker is answered", #sentKind(a, "PREP") == 2)
  w:advance(31)   -- 60 s after the first (t0 + 9 + 10 + 10 + 31)
  ask(12)
  w:advance(10)
  check("F6c: 60 s later the same asker is answered again", #sentKind(a, "PREP") == 3)
  a:db().prep.share = false
  local before = a:db().prep.dropped
  w:advance(61); ask(13); ask(14)
  check("F6c: with sharing off nothing is answered or counted", a:db().prep.dropped == before and #sentKind(a, "PREP") == 3)
end

H.finish("prep")
