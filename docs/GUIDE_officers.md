# Dead Tired: guide for officers (Crypt Keepers)

Everything in `docs/GUIDE_guildies.md` applies to you too. This page covers the one officer-only
command, what members will ask you, and the Discord bot's commands.

## Recruiting: `/dt recruit`

- `/dt recruit` posts **one** recruitment line to **General**, one per command or macro click.
  It never posts on its own: no timer, no queue, no retry.
- **Officers only.** It checks the game's own officer flag for your rank. Anyone else gets:
  *Officers only. The rest of us just haunt the place.*
- **General must be joined.** It finds your General channel by name (`General`, or
  `General - <zone>`). If you're not in it: *You're not in General. /join General first.*
- **Cooldown: 15 minutes per account** (your alts share it, and it survives a relog).
  Too soon: *Too soon. Next post in \<n\> min. Even necromancers pace themselves.* The cooldown is
  yours alone: two officers can each post.
- **Rotation:** the five lines go in order, 1 to 5, then back to 1. `/dt recruit next` shows which
  line is next and the time left on the cooldown. The rotation can't be skipped.
- Other refusals: *Chat's locked right now (an encounter?). Try after.*; *Can't read the clock.
  Not posting.*; *The channel didn't take it. Nothing posted.* (In none of these does anything
  post, or the rotation move.)
- After a post: *Posted line \<n\> of 5 to General.*

The five lines, as the addon posts them:

1. Adventurers, hear my call! ...is what we'd shout if we had the energy. <DEAD TIRED> is recruiting Horde of all classes for PvP and raids. We're already dead, so we don't fear death. Only bedtime. /w for inv
2. Do your knees click when you /sit? Is "one more pull" your bedtime story? <DEAD TIRED> - Horde PvP for the chronically exhausted. Undead Paladins welcome, the living merely tolerated. /w for inv
3. Forsaken Paladins: the Light has abandoned you, and so has your sleep schedule. Join <DEAD TIRED>. We have Blessing of Kings and absolutely no idea what day it is.
4. The Scourge offered us eternal unlife. We asked if it came with a lie-in. <DEAD TIRED> - Horde PvP & raiding for people who peaked in Vanilla. Signups on Discord, /w for inv
5. <DEAD TIRED> LFM Tanks, Heals, DPS, and anyone who's mastered the 9pm power nap. Raids & world PvP, zero judgement for falling asleep in Orgrimmar. /w for inv

## What members will ask you

- **"Do I have to install it?"** No. It's optional and nothing in the guild needs it.
- **"Why isn't X in `/dt who` / the board / the roll call?"** Every list only shows guildies
  running the addon, and only what your client saw while you were online. Roll calls, stash
  answers, death notices and the slowest-leveller board also need that guildie to have switched
  sharing on.
- **"What does it share about me?"** Without you switching anything on: the addon's version and
  your main (if you named one with `/dt main`), so `/dt who` and `/dt alts` work. Gank logs go out
  when you press `/dt gank`. Everything else (your deaths, prep readiness, stash, play time) is
  off until you turn it on, and the guide says how to turn each off. Never your gear, gold,
  professions or what killed you.
- **"Can it see my bags?"** Only if you type `/dt stash share on` (tradeable items, answered
  only to a search, four at a time) or `/dt prep share on` (ready yes/no and how many items
  short, never which). `/dt prep` checks your own bags for you and sends nothing.
- **"The death notices are too much."** `/dt rip off`.
- **"It keeps asking about the combat log."** `/dt logs off`.
- **"Does it post in chat?"** Only `/dt recruit`, officers only, one line per click, to General.
- **"It doesn't work on my character."** It only works inside <DEAD TIRED>. Outside the guild it
  stays silent, by design; `/dt` there just says *only stirs inside <DEAD TIRED>.*
- **"I got an error."** BugSack screenshot to **#dt-chat**, with what they were doing.

## The Discord bot (from the #dt-officers pin, 2026-11-01)

```
/promote @member - accepts an applicant. Gives Restless Dead, removes Freshly Risen, and posts a
welcome in #dt-chat. Run it once per person (running it again posts a second welcome).
/decline @member - removes Freshly Risen and DMs them a polite no (they keep PUG access).
/roster - who's in the guild by class and Tank/Healer/DPS, plus anyone who hasn't picked a class.
/create (Raid-Helper) - make a raid or PvP event; use it in #dt-raids. It carries on in your DMs.
Command replies are only visible to you. Making someone a Crypt Keeper is done by hand in Server
Settings > Members (they need Restless Dead too). The bot also posts a reset reminder in #dt-chat
on Tuesday mornings. All replies vanish if the bot's PC is off.
```
