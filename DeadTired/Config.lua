-- Dead Tired: configuration. The only file a guild officer should ever need to touch.
local ADDON, ns = ...
ns = ns or {}

ns.Config = {
  -- The in-game guild name. Matched case-insensitively, surrounding spaces ignored.
  GUILD_NAME = "DEAD TIRED",
  -- Addon message prefix (registered with C_ChatInfo through AceComm) and wire protocol version.
  PREFIX = "DEADTIRED",
  PROTOCOL = 2,
  -- LDB display addons (folder names). When one is loaded, DT's own bar stands back.
  DISPLAY_ADDONS = { "Titan", "ChocolateBar", "Bazooka", "ButtonBin", "Fortress", "DockingStation",
    "StatBlockCore", "NinjaPanel", "Broker2FuBar", "Carbonite" },
}
