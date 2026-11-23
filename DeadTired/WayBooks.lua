-- Dead Tired: the Waypointer's built-in list, round one (dt_waypointer W1, 0.5.0): the library books.
-- Source: Warcraft Tavern, "Library Books Guide: Locations, Quests & Rewards" (WoW Forever), quest IDs
-- from its forever.warcraftdb.com links; gathered in claude/39_guild_quests_arcs_2026-11-22.md (22 Nov).
-- Coordinates as the guide gives them (0-100, the zone's own map). Zone names as the client names them;
-- Way.lua matches them to map IDs at run time. Rumi of Gnomeregan is one book in two inns: listed once,
-- with the other inn in its note. Data only: nothing here runs.
--   { name, zone, x, y, quest ID (kept for the guild quests; not used yet), level text, note }
local ADDON, ns = ...
local DT = ns.DT

DT.WAY_BOOKS_SOURCE = "Coordinates from Warcraft Tavern's Forever book guide."

DT.WAY_BOOKS = {
  { "Archmage Theocritus' Research Journal", "Elwynn Forest", 65.4, 70.1, 79092, "1-10", "Tower of Azora, top floor" },
  { "Archmage Antonidas: The Unabridged Autobiography", "Ironforge", 76.1, 10.2, 79091, "any", "Hall of Explorers" },
  { "The Apothecary's Metaphysical Primer", "Tirisfal Glades", 59.5, 52.3, 79095, "1-10", "Brill, alchemy shop" },
  { "Ataeric: On Arcane Curiosities", "Silverpine Forest", 43.4, 41.2, 79096, "10-20", "The Sepulcher, bottom floor" },
  { "The Dalaran Digest, Vol. 23", "Silverpine Forest", 63.5, 63.1, 78127, "17-18", "Ambermill town hall" },
  { "Rumi of Gnomeregan: The Collected Works", "Loch Modan", 35.6, 48.9, 79093, "10-20", "Thelsamar inn (or Sentinel Hill inn, Westfall 52.7, 53.7)" },
  { "Runes of the Sorcerer-Kings", "Loch Modan", 77.5, 14.1, 78148, "19-20", "Mo'grosh Stronghold, middle cave" },
  { "Bewitchments and Glamours", "Westfall", 45.4, 70.4, 78142, "10-20", "Moonbrook" },
  { "Crimes Against Anatomy", "Duskwood", 6.7, 28.5, 78147, "18-30", "Raven Hill catacombs" },
  { "Goaz Scrolls", "Wetlands", 33.6, 47.9, 78146, "20-30", "Whelgar's Excavation, under pottery" },
  { "Defensive Magics 101", "Alterac Mountains", 48.5, 57.6, 79948, "30-40", "Ruins of Alterac, first tower" },
  { "A Web of Lies: Debunking Myths and Legends", "Arathi Highlands", 73.0, 65.0, 79949, "30-40", "Witherbark Village, east tent" },
  { "Basilisks: Should Petrification be Feared?", "Stranglethorn Vale", 41.5, 50.8, 79535, "30-45", "Mistvale Valley, outside a cave" },
  { "Mummies: A Guide to the Unsavory Undead", "Badlands", 57.0, 39.0, 79951, "35-45", "The crypt, by the skeletons" },
  { "A Luddite's Guide to Caring for Your Demonic Pet", "Swamp of Sorrows", 61.0, 22.0, 79953, "35-45", "Fallow Sanctuary (Rusted Cage Key)" },
  { "Sanguine Sorcery", "Swamp of Sorrows", 70.0, 51.0, 81947, "", "Temple of Atal'Hakkar, top" },
  { "Venomous Journeys", "The Hinterlands", 36.0, 72.7, 81954, "40-50", "Shadra'Alor, eastern ziggurat" },
  { "A Mind of Metal", "Searing Gorge", 37.0, 49.0, 81955, "43-50", "The Cauldron, lone tent" },
  { "Conjurer's Codex", "Blasted Lands", 55.3, 32.2, 81956, "47-55", "Rubble by the road" },
  { "Stonewrought Design", "Burning Steppes", 31.0, 30.0, 81953, "50-58", "Blackrock Mountain, centre island altar" },
  { "Magma or Lava?", "Burning Steppes", 31.0, 30.0, 84396, "", "Blackrock Mountain, by the BRD door" },
  { "Necromancy 101", "Western Plaguelands", 69.4, 72.5, 84402, "50-60", "Caer Darrow" },
  { "Undead Potatoes", "Western Plaguelands", 38.0, 54.0, 84395, "", "Felstone Field house, upstairs" },
  { "A Study of the Light", "Eastern Plaguelands", 72.0, 48.0, 84398, "53-60", "Light's Hope Chapel, back left" },
  { "Scourge: Undead Menace or Misunderstood?", "Eastern Plaguelands", 26.5, 14.5, 84401, "", "Before the Stratholme bridge, on a box" },
  { "The Knight and the Lady", "Eastern Plaguelands", 47.3, 42.3, 84400, "", "Blackwood Lake ruin" },
  { "The Lessons of Ta'zo", "Orgrimmar", 38.5, 78.2, 79094, "any", "Valley of Spirits, the Mural of Ta'zo" },
  { "Nar'thalas Almanac, Vol. 74", "Darkshore", 59.6, 22.2, 78124, "10-20", "Ruins of Mathystra, stair landing" },
  { "Arcanic Systems Manual", "The Barrens", 56.3, 8.8, 78145, "10-25", "Sludge Fen control room" },
  { "Baxtan: On Destructive Magics", "The Barrens", 62.7, 36.3, 79097, "", "Ratchet, engineering upstairs" },
  { "Secrets of the Dreamers", "The Barrens", 46.0, 36.4, 78143, "", "Cavern of Mists" },
  { "Fury of the Land", "Stonetalon Mountains", 74.4, 85.7, 78149, "15-27", "Grimtotem Post, smaller hut" },
  { "Geomancy: The Stone-Cold Truth", "Thousand Needles", 34.0, 40.0, 79947, "25-35", "Darkcloud Pinnacle, largest hut" },
  { "Demons and You", "Desolace", 55.0, 28.0, 79950, "30-40", "Thunder Axe Fortress, on a bench" },
  { "RwlRwlRwlRwl!", "Dustwallow Marsh", 57.0, 21.0, 79952, "35-45", "Witch Hill murloc camp, east side" },
  { "Legends of the Tidesages", "Tanaris", 72.7, 47.8, 81949, "40-50", "Lost Rigger Cove, middle building" },
  { "Everyday Etiquette", "Azshara", 20.0, 61.0, 81952, "48-55", "Haldarr Encampment, on a box" },
  { "Northern Kalimdor - A Comprehensive Guide", "Felwood", 65.2, 3.2, 84397, "48-55", "Timbermaw Hold, middle bridge" },
  { "Ka-Boom!", "Winterspring", 61.0, 38.0, 84399, "55-60", "Everlook alchemy shop" },
}
