# reference/ (read-only)

Copied on 2026-11-02 from Tim's `WoWWizardry` repo (HEAD `689c998`, Wizardry Ledger 0.38.1).
Nothing here is loaded by the addon or edited by build sessions.

| File | Why it's here |
|---|---|
| `SPEC_forever_namespaces.md` | Every `C_*` namespace and function the Forever **beta** client exposed (build 1.60.1-69913). Ask it before calling anything. Absent here means absent on that build. The live client may differ. |
| `wizardry/Forever/Core.lua` | The pattern to copy: guarded reads (`try`, `clean`, `secret`), `module{}` wiring, the slash router, pane registration. |
| `wizardry/Forever/ProfessionRecorder.lua` | How Wizardry reads professions and skill levels on this client. Starting point for the profession directory card. |
| `wizardry/tests/test_forever_core.lua` | The offline test style: stubbed WoW API, `check()` counter, plain Lua 5.1. |
| `wizardry/tests/test_forever_professions.lua` | Profession stubs, with captures from the live client. |
| `wizardry/WizardryLedger_Camelot.toc` | How a Forever `.toc` is laid out (interface 16001, Camelot suffix). |
| `wizardry/LogPrompt/` | Tim's beta login reminder (`WizardryLogPrompt` 0.1.0, from the beta install, 2026-11-02): the secure-button `/combatlog` pattern for card 7 (`dt_logs`). Its offline suite passes (27 checks). |
