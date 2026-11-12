-- Dead Tired: the event tracker's list (card 6, R4). Data, not logic: edit freely.
-- { name, weekday = 1 (Sunday) .. 7 (Saturday), start = "HH:MM", minutes = <length> }, all in
-- server time. The Fishing Extravaganza's schedule is the classic one as remembered; Tim checks
-- it against Forever's at G9 and corrects it here.
local ADDON, ns = ...
ns = ns or {}

ns.EventsList = {
  { name = "Stranglethorn Fishing Extravaganza", weekday = 1, start = "14:00", minutes = 120 },
}
