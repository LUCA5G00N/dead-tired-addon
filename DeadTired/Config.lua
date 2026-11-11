-- Dead Tired: configuration. The only file a guild officer should ever need to touch.
local ADDON, ns = ...
ns = ns or {}

ns.Config = {
  -- The in-game guild name. Matched case-insensitively, surrounding spaces ignored.
  GUILD_NAME = "DEAD TIRED",
  -- Addon message prefix (registered with C_ChatInfo through AceComm) and wire protocol version.
  PREFIX = "DEADTIRED",
  PROTOCOL = 2,
  -- Raid prep (Prep.lua): the list is taken only from a guild officer, read as a guild rank index
  -- at most this (0 is the Guild Master). Set it to the guild's lowest officer rank.
  OFFICER_MAX_RANK = 1,
  -- LDB display addons (folder names). When one is loaded, DT's own bar stands back.
  DISPLAY_ADDONS = { "Titan", "ChocolateBar", "Bazooka", "ButtonBin", "Fortress", "DockingStation",
    "StatBlockCore", "NinjaPanel", "Broker2FuBar", "Carbonite" },
}
