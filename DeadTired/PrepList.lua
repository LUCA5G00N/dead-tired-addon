-- Dead Tired: the raid-prep list (card 5, R3). Data, not logic: edit freely.
-- { id = <itemID>, name = "<as we call it>", need = <count>, class = "<CLASSFILE>" or nil }
-- An entry with no class applies to everyone. The IDs are a starter, written from memory and
-- unverified: /dt prep list shows the client's name for each ID, so a wrong one stands out.
local ADDON, ns = ...
ns = ns or {}

ns.PrepList = {
  { id = 13446, name = "Major Healing Potion", need = 5 },
  { id = 17029, name = "Sacred Candle",        need = 20, class = "PRIEST" },
  { id = 17020, name = "Arcane Powder",        need = 20, class = "MAGE" },
  { id = 17033, name = "Symbol of Divinity",   need = 5,  class = "PALADIN" },
  { id = 17026, name = "Wild Thornroot",       need = 20, class = "DRUID" },
  { id = 17030, name = "Ankh",                 need = 5,  class = "SHAMAN" },
  { id = 6265,  name = "Soul Shard",           need = 10, class = "WARLOCK" },
  { id = 5140,  name = "Flash Powder",         need = 10, class = "ROGUE" },
}
