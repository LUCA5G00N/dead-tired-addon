-- Dead Tired: guild quests' data, round one (dt_guildquests Q2, 0.8.0): the Cozy Sleeping Bag arc.
-- Source: Wowhead's Forever guide "Cozy Sleeping Bag: locations and rewards" (Serenal), Kami Labs and Warcraft
-- Wiki, gathered in claude/39_guild_quests_arcs_2026-11-22.md (22 Nov). Quest IDs 79007 and 79976 confirmed
-- in game on Stromham, 22 Nov 20:24 (IsQuestFlaggedCompleted -> true). Coordinates as the guide gives them
-- (0-100, the zone's own map). The library books are DT.WAY_BOOKS (WayBooks.lua; book 79094 confirmed in game
-- 25 Nov 00:33): no second list. Data only: nothing here runs.
--   step = { n, name, quest ID (Horde), quest ID (Alliance, if different), zone, x, y, optional, note }
local ADDON, ns = ...
local DT = ns.DT

DT.QUEST_BAG_SOURCE = "Steps from Wowhead's Forever sleeping bag guide."

DT.QUEST_BAG = {
  { 1, "...and that note you found", 79007, 79008, "The Barrens", 46.0, 74.0, false,
    "Picked up at the burned tower; handed in at Alexston Farmstead, Westfall 37, 50." },
  { 2, "Stepping Stones", 79192, nil, "Stonetalon Mountains", 40.6, 52.4, false, "Pocket Litter on a crate. A 12-slot toolbox." },
  { 3, "Rekindle", 80001, nil, "Stonetalon Mountains", 40.6, 52.4, true, "Optional: the dead campfire (Simple Wood, Flint and Tinder)." },
  { 4, "Scramble", 79980, nil, "Stonetalon Mountains", 39.6, 49.8, false, "A mound of dirt up the hill." },
  { 5, "Wet Job", 79974, nil, "Loch Modan", 49.4, 12.9, false, "Dwarf country. Bring a friend." },
  { 6, "Eagle's Fist", 79975, nil, "Hillsbrad Foothills", 87.3, 49.6, false, "The messenger bag on Thoradin's Wall." },
  { 7, "This Must Be The Place", 79976, nil, "Hillsbrad Foothills", 87.3, 49.6, false, "Just below the messenger bag. The Cozy Sleeping Bag." },
}

-- Step 1's hand-in, for a player already on it (IsOnQuest).
DT.QUEST_BAG_HANDIN = { "Westfall", 37.0, 50.0 }

-- The library's reward tiers: { books, reward quest ID, name }.
DT.QUEST_LIB_TIERS = {
  { 10, 78150, "Friend of the Library" },
  { 20, 79536, "Greater Friend of the Library" },
  { 25, 82208, "Greater Friend of the Library" },
  { 35, 84394, "Greater Friend of the Library" },
}
