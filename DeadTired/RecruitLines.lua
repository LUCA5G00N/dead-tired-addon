-- Dead Tired: the recruitment rotator's data (card 5, R2 and P3).
-- LINES are Tim's five, verbatim from docs/RECRUIT_lines.md (tests/test_recruit.lua checks it).
-- Don't edit a line here: edit it there, and copy it back exactly.
local ADDON, ns = ...
ns = ns or {}

ns.Recruit = {
  RECRUIT_CHANNEL = "General",
  COOLDOWN = 900,   -- seconds, per account (alts share it)
  LINES = {
    [=[Adventurers, hear my call! ...is what we'd shout if we had the energy. <DEAD TIRED> is recruiting Horde of all classes for PvP and raids. We're already dead, so we don't fear death. Only bedtime. /w for inv]=],
    [=[Do your knees click when you /sit? Is "one more pull" your bedtime story? <DEAD TIRED> - Horde PvP for the chronically exhausted. Undead Paladins welcome, the living merely tolerated. /w for inv]=],
    [=[Forsaken Paladins: the Light has abandoned you, and so has your sleep schedule. Join <DEAD TIRED>. We have Blessing of Kings and absolutely no idea what day it is.]=],
    [=[The Scourge offered us eternal unlife. We asked if it came with a lie-in. <DEAD TIRED> - Horde PvP & raiding for people who peaked in Vanilla. Signups on Discord, /w for inv]=],
    [=[<DEAD TIRED> LFM Tanks, Heals, DPS, and anyone who's mastered the 9pm power nap. Raids & world PvP, zero judgement for falling asleep in Orgrimmar. /w for inv]=],
  },
}
