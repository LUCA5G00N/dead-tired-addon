# DeadTired/Libs: bundled third-party libraries

Unmodified upstream files, each folder with its licence. Loaded by `DeadTired.toc` in the order below.
Ruled 2026-11-10, amended 2026-11-11 (`CLAUDE.md`, *Libraries*). Vendored 2026-11-11 (framework round).
`SHA256SUMS` holds each file's hash at vendoring; `tests/run_all.sh` checks it (`sha256sum -c`), so any edit shows up.

| Library | Version | Source | Licence |
|---|---|---|---|
| LibStub | minor 2 (Ace3 `ac3d122`) | https://github.com/WoWUIDev/Ace3 `LibStub/LibStub.lua` | Public domain (file header); Ace3 `LICENSE.txt` kept alongside |
| CallbackHandler-1.0 | minor 8 (Ace3 `ac3d122`) | https://github.com/WoWUIDev/Ace3 `CallbackHandler-1.0/` | Ace3 BSD-style (`LICENSE.txt`) |
| ChatThrottleLib | v32 (Ace3 `ac3d122`) | https://github.com/WoWUIDev/Ace3 `AceComm-3.0/ChatThrottleLib.lua` | Public domain (file header) |
| AceComm-3.0 | minor 14 (Ace3 `ac3d122`) | https://github.com/WoWUIDev/Ace3 `AceComm-3.0/` | Ace3 BSD-style (`LICENSE.txt`) |
| LibSerialize | v1.2.3, minor 7 (`aa6e50d`) | https://github.com/rossnichols/LibSerialize | MIT (`LICENSE`) |
| LibDeflate | 1.0.2-release, minor 3 (`6831edc`) | https://github.com/SafeteeWoW/LibDeflate | zlib (`LICENSE.txt`) |
| LibSharedMedia-3.0 | r186, minor 12000005 (9 Nov 2026) | https://repos.wowace.com/wow/libsharedmedia-3-0/trunk (svn) | LGPL v2.1 (file header). Upstream ships no licence text, so `LGPL-2.1.txt` is the FSF text (Debian `/usr/share/common-licenses/LGPL-2.1`) |

Only the library `.lua` files are shipped: no upstream `.toc`, `lib.xml`, tests or docs.
Ace3 commit `ac3d122` is 21 commits past `Release-r1403`. Those commits touch AceDB, AceGUI, AceTab
and the `.toc` only. The four files here are byte-identical at both points.

**Not bundled:**
- **LibDataBroker-1.1** is borrowed, never bundled: its source carries no licence. DT uses it only
  when another addon has loaded it (`LibStub("LibDataBroker-1.1", true)`).
- **LibDBIcon-1.0** isn't used: DT has no minimap button.

**ChatThrottleLib hooks.** At load, ChatThrottleLib places `hooksecurefunc` hooks on
`C_ChatInfo.SendChatMessage`, `C_ChatInfo.SendAddonMessage`, `C_ChatInfo.SendAddonMessageLogged` and
`C_BattleNet.SendGameData`, so it can measure traffic that bypasses it. This is the library's own
code, outside DT's taint scan, which covers `DeadTired/*.lua` only. If another addon loaded a
ChatThrottleLib of v32 or newer first, DT's copy does nothing.
