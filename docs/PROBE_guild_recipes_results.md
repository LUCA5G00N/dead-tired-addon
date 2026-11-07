# Probe results: guild recipes (card 2, P3), 7 Nov 2026

The answer to card 2's *Launch-night probe* (`docs/COWORK_BRIEF_dt_professions.md` on
`claude/loving-meitner-yzdxtn`), which R1 is ruled on. Drafted by a session from the probe's saved
file, Tim's screenshots and BugSack; **Tim checks it**.

Stromham, level 18, Guild Master of DEAD TIRED, in Undercity, Mining 83/150, build 1.60.1.70862.
The probe's own `/dtprobe recipes` section does the brief's steps 1-5 itself, so those are the
main record. Tim's typed lines are noted where they differ.

## The five steps

1. **`C_GuildInfo.QueryGuildMembersForRecipe`, `C_GuildInfo.QueryGuildMemberRecipes`:**
   function, function. (`recipes.attempts[*].fns`, all five attempts.)
2. **`GetGuildRecipeInfoPostQuery`, `GetGuildRecipeMember`:** function, function.
3. **A recipe ID and its line**, with the Mining window open: `C_TradeSkillUI.GetAllRecipeIDs()`
   gave **1213638** (Lodestone, Mining's new *Camping* recipe). `GetTradeSkillLineForRecipe`
   answered **186, "Mining", nil**: there is **no parent line**, so the query used 186.
   - The list is empty until the window is ready: the first attempt (`IsTradeSkillReady` false)
     recorded *"no recipe ID: the list is empty"*.
   - With the window closed, `GetAllRecipeIDs` still gave 1213638 (`ready` false).
   - `GetFilteredRecipeIDs()` came back **empty** with the window open. Tim's typed check
     (`f[1]` into `GetTradeSkillLineForRecipe`) failed silently; BugSack has
     `Usage: GetTradeSkillLineForRecipe(recipeID)`.
4. **Query with the window open**, `QueryGuildMembersForRecipe(186, 1213638)`: the call returns
   nothing, and **`GUILD_RECIPE_KNOWN_BY_MEMBERS` never fired**: no event within 10 s, and no stray
   event at any time in the session. Members: **none, not even Stromham**, who knows the recipe.
   (Run 18 attempt 2, and run 19 attempt 1, which printed `answers 0, members 0` at 10:50:25.)
5. **Query with the window closed:** the same. No event, no members. (Run 18 attempt 3, and run 19
   attempt 2 at 10:50:30.)

## Result

**Native: doesn't work.**

By the brief's own test: steps 1 and 2 answer, but step 4 gives no event and names nobody.

Caveats, for the ruling, not against the result:
- **One recipe, one profession, and a gathering one.** A crafting profession might behave
  differently. Not needed to call this, but a retry on (say) tailoring would close it.
- **No parent line on Forever.** The brief expects a parent line ID; Forever gives none, so the
  query went out with the profession's own line. If the server wants a different line, no addon
  can supply it.

## What it means for card 2 (for the rulings round, not decided here)
- **R1** says: build the addon directory either way; no `dt_professions_native` follow-up if
  native doesn't work. **That follow-up is off.**
- **But fork B (7 Nov) cuts deeper.** The directory itself (R2, R4) works by sending answers to a
  guildie's search, and addon messages are restricted on every read
  (`PROBE_launch_results.md`). As drafted, card 2 would be silent. It needs **re-briefing**
  (R1's own "re-brief" option), not ratifying. The likely shape is solo-only (your own
  professions and recipes, kept locally) with the shared directory routed through the Discord
  bridge instead.
- Whatever shape it takes, `GetAllRecipeIDs` needs the profession window open and ready, and
  recipe IDs from Forever's new recipes are large (1213638): no byte budgets that assume classic
  IDs.
