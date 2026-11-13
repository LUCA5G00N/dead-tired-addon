-- Guard proofs (CLAUDE.md: "Guards are proved, not assumed"). For each guard: change the guarded
-- line once in the addon file, run its suite, record which checks went red, put the line back and
-- confirm the file is byte-identical again. From the repo root: lua5.1 tools/guard_proofs.lua
-- Prints a markdown table for the round's report. Exits non-zero if any removal turned nothing red
-- or any file failed to restore.
local T = "DeadTired/tests/"
local GUARDS = {
  -- Task 11's list
  { "guild gate", "DeadTired/Guild.lua", "return want ~= nil and have == want", "return want ~= nil", "test_guild" },
  { "lockdown hold (R-1)", "DeadTired/Comms.lua", "    if lockdown() then                                                     -- guard: lockdown hold (R-1)", "    if false then", "test_comms" },
  { "AUD-10 success test", "DeadTired/Comms.lua", "if not (didSend == true or didSend == 0) then item.failed = true end", "if false then item.failed = true end", "test_comms" },
  { "3-refusal limit (AUD-10)", "DeadTired/Comms.lua", "  if item.tries >= MAX_TRIES then", "  if false then", "test_comms" },
  { "payload-key name match", "DeadTired/Comms.lua", "return DT.fullName(kn):lower() == sn:lower()", "return true", "test_comms" },
  { "self-exclusion in Who (R-P6: own entry never doubled)", "DeadTired/Who.lua", "    if isMe(key) then return end                                           -- guard: self never listed", "", "test_who" },
  { "settings verb-or-noVerb rule", "DeadTired/Core.lua", 'if not DT.typed(s) and not (type(s.noVerb) == "string" and s.noVerb:match("%S")) then', "if false then", "test_settings" },
  { "bar stand-back", "DeadTired/Bar.lua", "  return DT.displayAddon() == nil", "  return true", "test_bar" },
  { "borrow-only LibDataBroker", "DeadTired/Bar.lua", '  if type(lib) ~= "table" then return nil end', "", "test_bar" },
  { "bar intro once only", "DeadTired/Bar.lua", "if db.barIntroSaid or not (bar and bar:IsShown()) then return end", "if not (bar and bar:IsShown()) then return end", "test_bar" },
  { "taint scan (rc3's line inserted)", "DeadTired/Core.lua", 'SLASH_DEADTIRED2 = "/deadtired"', 'SLASH_DEADTIRED2 = "/deadtired"\nSlashCmdList = SlashCmdList or {}', "test_taint" },
  -- the other guards marked in the code
  { "guild gate: DT.out", "DeadTired/Core.lua", "  if not (DT.isMember and DT.isMember()) then return false end", "", "test_guild" },
  { "guild gate: DT.send", "DeadTired/Comms.lua", "  if not DT.isMember() then return false end                              -- guard: guild gate (send)", "", "test_guild" },
  { "guild gate: inbound", "DeadTired/Comms.lua", "  if not DT.isMember() then return end                                    -- guard: guild gate (inbound)", "", "test_guild" },
  { "disabled module registers nothing", "DeadTired/Core.lua", "  if on then                                                               -- guard: disabled registers nothing", "  if true then", "test_core" },
  { "handler error count", "DeadTired/Core.lua", "      DT.fail(def.id, ev, err)                                              -- guard: handler error count", "", "test_core" },
  { "legacy move", "DeadTired/Core.lua", "    if next(db) ~= nil then                                               -- guard: legacy move", "    if false then", "test_core" },
  { "protocol version", "DeadTired/Comms.lua", 'if tonumber(pv) ~= PROTOCOL then return "unknown" end', "", "test_comms" },
  { "held line once per hold", "DeadTired/Comms.lua", "if holding and DT.inCommand and not heldSaid then", "if holding and DT.inCommand then", "test_comms" },
  { "held line for typed commands only", "DeadTired/Comms.lua", "if holding and DT.inCommand and not heldSaid then", "if holding and not heldSaid then", "test_comms" },
  { "realm normalise (AUD-06)", "DeadTired/Keys.lua", 'realm = realm:gsub("[%s%-]", "")', 'realm = realm', "test_keys" },
  { "full name for my key", "DeadTired/Keys.lua", 'return DT.fullName(str((try(GetUnitName, "player", true)))) or DT.fullName(str((try(UnitName, "player"))))', 'return DT.fullName(str((try(UnitName, "player"))))', "test_keys" },
  { "list filter", "DeadTired/UI.lua", 'if q == "" or hay:find(q, 1, true) then out[#out + 1] = r end', "out[#out + 1] = r", "test_ui" },
  { "toast gate", "DeadTired/UI.lua", "  if DT.get(id, key) ~= true then return false end", "", "test_ui" },
  { "skin base fallback", "DeadTired/Skins.lua", "  if v == nil then v = look(DT.skins[BASE]) end", "", "test_skins" },
  { "Who ask rate limit", "DeadTired/Who.lua", "if not lastAsk or t - lastAsk >= ASK_GAP then", "if true then", "test_who" },
  { "Who hello rate limit", "DeadTired/Who.lua", "if lastHello and t - lastHello < HELLO_GAP then return false end", "", "test_who" },
  -- Port 1 (COWORK_BRIEF_dt_port1.md, Task 7)
  { "recruit officer check (A1)", "DeadTired/Recruit.lua", "  if not isOfficer() then                                             -- guard: officer gate (A1)", "  if false then", "test_recruit" },
  { "recruit cooldown", "DeadTired/Recruit.lua", "  if wait > 0 then                                                    -- guard: cooldown", "  if false then", "test_recruit" },
  { "recruit click-only post (R1, R-P1)", "DeadTired/Recruit.lua", "  if not (DT.inCommand or clicking) then", "  if false then", "test_recruit" },
  { "recruit General only (A1)", "DeadTired/Recruit.lua", 'return name == CHANNEL or name:sub(1, #CHANNEL + 3) == CHANNEL .. " - "', "return true", "test_recruit" },
  { "death share opt-in (A2)", "DeadTired/Crypt.lua", 'if DT.get("crypt", "share") == true then', "if true then", "test_crypt" },
  { "battleground rule", "DeadTired/Crypt.lua", 'if itype == "pvp" or itype == "arena" then hc = false end', "", "test_crypt" },
  { "hardcore line once only", "DeadTired/Crypt.lua", "if not me or c.hcTold[me] then return end", "if not me then return end", "test_crypt" },
  { "prep officers-only acceptance", "DeadTired/Prep.lua", "  if not senderIsOfficer(from) then", "  if false then", "test_prep" },
  { "prep verdict only (no names or counts)", "DeadTired/Prep.lua", "short = tostring(math.min(#short, MAX_SHORT)) })", "short = tostring(math.min(#short, MAX_SHORT)), items = short[1] and short[1].e.name or nil })", "test_prep" },
  { "prep officers set the list", "DeadTired/Prep.lua", "  if not isOfficer() then return DT.out(OFFICERS) end                 -- guard: officers set the list\n  local item", "  local item", "test_prep" },
  { "migration runs once", "DeadTired/Migrate.lua", "  if M.port1 then return false end", "", "test_migrate" },
  { "short->full merge: exactly one", "DeadTired/Migrate.lua", "if hits == 1 then map[k] = hit", "if hits >= 1 then map[k] = hit", "test_migrate" },
  { "R-P5 collision rule", "DeadTired/Keys.lua", "if e and e.n > 1 then", "if false then", "test_keys" },
  { "bar: others unticked by default (R-P4)", "DeadTired/Bar.lua", "b.on[name] = own and not offByDefault or false", "b.on[name] = true", "test_bar" },
  { "bar: colour codes pass", "DeadTired/Bar.lua", "if colour then out[#out + 1] = colour; i = i + #colour; open = true", "if false then", "test_bar" },
  -- (fix round 4: R-F4-1 retires 0.3.0's "list rows fit their text" (rows grew with wrapped text);
  -- its place is taken by the opposite rule, every row one height, proved below.)
  { "every row one height (R-F4-1; replaces 'list rows fit their text')", "DeadTired/UI.lua", "        b:SetHeight(self.rowH)                                             -- guard: every row one height", "        b:SetHeight(#b.cut > 0 and self.rowH * 2 or self.rowH)", "test_ui" },
  { "settings content follows the scroll", "DeadTired/SettingsView.lua", "  if scroll > maxS then scroll = maxS end\n  place()", "  if scroll > maxS then scroll = maxS end", "test_settingsview" },
  -- Port 2 (COWORK_BRIEF_dt_port2.md, Task 5)
  { "gank reads the target only on the verb (R1)", "DeadTired/Gank.lua", "  if not DT.inCommand then return false end                            -- guard: target read only on /dt gank (R1)", "", "test_gank" },
  { "stash shares only unbound items (A4)", "DeadTired/Stash.lua", "          if bound == false then                                                 -- guard: only known unbound listed (A4)", "          if true then", "test_stash" },
  { "stash shares only known-unbound (unknown not listed)", "DeadTired/Stash.lua", "          if bound == false then                                                 -- guard: only known unbound listed (A4)", "          if bound ~= true then", "test_stash" },
  { "stash opt-in: answering", "DeadTired/Stash.lua", "  if not sharing() then return end                                               -- guard: share gate on answering (opt-in)", "", "test_stash" },
  { "stash opt-in: scanning", "DeadTired/Stash.lua", "  if not sharing() then return false end                                         -- guard: share gate on scanning", "", "test_stash" },
  { "stash list deleted when sharing off", "DeadTired/Stash.lua", "  else store().chars = {} end                                                    -- guard: list deleted when sharing off", "  end", "test_stash" },
  { "played shares only after /dt played (R-P2-1)", "DeadTired/Played.lua", "  if not at or DT.now() - at >= ASKED_WINDOW then return end           -- guard: only after /dt played (R-P2-1)", "", "test_played" },
  { "played: one report per /dt played (R-P2-1)", "DeadTired/Played.lua", "  askedAt = nil                                                        -- guard: one report per /dt played", "", "test_played" },
  { "played: share gate on sending", "DeadTired/Played.lua", "  if not sharing() then return end                                     -- guard: share gate on sending", "", "test_played" },
  { "played withdrawn when sharing off (F9)", "DeadTired/Played.lua", '  DT.send("PLAYED", { off = "1" })                                     -- guard: withdrawn when sharing off (F9)', "", "test_played" },
  { "played: the 30-day drop (F9)", "DeadTired/Played.lua", "    if type(e) ~= \"table\" or type(e.t) ~= \"number\" or now - e.t > MAX_AGE then b[key] = nil end   -- guard: 30-day drop (F9)", "    if type(e) ~= \"table\" then b[key] = nil end", "test_played" },
  { "played: no hook (a hooksecurefunc on /played inserted)", "DeadTired/Played.lua", "local SEND_WINDOW = 60", "local SEND_WINDOW = 60\nhooksecurefunc(SlashCmdList, \"PLAYED\", function() end)", "test_taint" },
  { "events print only once switched on (R4)", "DeadTired/Events.lua", '  if DT.get("events", "remind") ~= true then return end                 -- guard: reminders only once switched on (R4)', "", "test_events" },
  { "logs never switch a log off: combat (only an OFF log armed)", "DeadTired/Logs.lua", '  local c = (combatOn == false) and "/combatlog" or nil                     -- guard: unknown not armed (F10)', '  local c = (combatOn ~= nil) and "/combatlog" or nil', "test_logs" },
  { "logs never switch a log off: chat", "DeadTired/Logs.lua", '  local h = (chatOn == false) and "/chatlog" or nil', '  local h = "/chatlog"', "test_logs" },
  { "logs only read the state (no argument to LoggingCombat/LoggingChat)", "DeadTired/Logs.lua", "  if v == nil then v = clean((try(_G[legacyName]))) end", "  if v == nil then v = clean((try(_G[legacyName], true))) end", "test_logs" },
  { "logs one prompt at a time: login covers a dungeon (F12)", "DeadTired/Logs.lua", '  if shown(dialogs.login) or (pendingShow and pendingShow.kind == "login") then   -- guard: login prompt covers (F12)', "  if false then", "test_logs" },
  { "logs one prompt at a time: instance hidden for login (F12)", "DeadTired/Logs.lua", "  if shown(dialogs.instance) then dialogs.instance:Hide() end              -- guard: instance hidden for login (F12)", "", "test_logs" },
  { "logs one prompt at a time: a click hides the others (F13)", "DeadTired/Logs.lua", "      if d ~= dlg and d:IsShown() then d:Hide() end                       -- guard: hide the others (F13)", "", "test_logs" },
  { "logs never in a battleground or arena", "DeadTired/Logs.lua", '  if kind ~= "party" and kind ~= "raid" then return kind, nil end        -- guard: dungeons and raids only (R1)', '  if kind == "none" then return kind, nil end', "test_logs" },
  { "logs never in the open world", "DeadTired/Logs.lua", '  if kind ~= "party" and kind ~= "raid" then return kind, nil end        -- guard: dungeons and raids only (R1)', '  if kind == "pvp" or kind == "arena" then return kind, nil end', "test_logs" },
  { "nudge re-armed on 'nudge on' (Port 1 defect 1)", "DeadTired/Recruit.lua", "    schedule(at, wait)                                                -- guard: nudge re-armed (Port 2)", "", "test_recruit" },
  { "nudge once per post", "DeadTired/Recruit.lua", "    if store().at ~= at or nudged == at then return end               -- guard: once per post (nudge)", "    if store().at ~= at then return end", "test_recruit" },
  { "UISpecialFrames insert only (R-P2-2)", "DeadTired/UI.lua", "  table.insert(UISpecialFrames, name)                                      -- guard: insert only (R-P2-2)", "  table.insert(UISpecialFrames, 1, name)", "test_taint" },
  { "UISpecialFrames: never a removal (R-P2-2)", "DeadTired/UI.lua", "  escaped[name] = true\n  return true", "  escaped[name] = true\n  table.remove(UISpecialFrames, 1)\n  return true", "test_taint" },
  { "UISpecialFrames: DT's own names, once each (R-P2-2)", "DeadTired/UI.lua", '  if type(name) ~= "string" or not name:match("^DeadTired") or escaped[name] then return false end  -- guard: DT\'s own names only', '  if type(name) ~= "string" then return false end', "test_ui" },
  { "Escape registration at creation (R-P2-2)", "DeadTired/UI.lua", "  if not o.sticky then DT.closeOnEscape(name) end", "", "test_ui" },
  { "bar list shows names, not live text (Port 1 defect 2)", "DeadTired/Bar.lua", '  local l = type(e.obj.label) == "string" and DT.trim(plain(e.obj.label)) or ""', '  local l = DT.trim(plain(e.obj.label or e.obj.text or "")) or ""', "test_bar" },
  { "graveyard date on one line (Port 1 defect 4)", "DeadTired/Crypt.lua", "rows[#rows + 1] = { key = e.who, day = short,", "rows[#rows + 1] = { key = e.who, day = DT.safe(day, 20),", "test_crypt" },
  { "Port 2 migration runs once", "DeadTired/Migrate.lua", "  if M.port2 then return false end                                       -- guard: Port 2 migration runs once", "", "test_migrate" },
  -- Fix round 4 (COWORK_BRIEF_dt_fixes4.md, Task 10)
  { "fitLine cuts to the width", "DeadTired/UI.lua", "  if not w or w <= width then return text, false end                       -- guard: fitLine cuts to the width", "  if true then return text, false end", "test_ui" },
  { "fitLine: the UTF-8 boundary", "DeadTired/UI.lua", "    while j < n and (text:byte(j + 1) or 0) >= 128 and (text:byte(j + 1) or 0) < 192 do j = j + 1 end  -- guard: whole characters only", "", "test_ui" },
  { "the cut row's tooltip text", "DeadTired/UI.lua", "        for _, full in ipairs(b.cut) do tt:AddLine(full, 1, 1, 1, true) end    -- guard: a cut cell's full text in the tooltip", "", "test_ui" },
  { "fixed columns measured from the widest value", "DeadTired/UI.lua", "          if w > widest then widest = w end                                -- guard: fixed column from its widest value", "", "test_ui" },
  { "exactly one flex column", "DeadTired/UI.lua", '  if flexes ~= 1 then error("DT.list: exactly one flex column (" .. flexes .. " given)", 2) end   -- guard: exactly one flex column', "", "test_ui" },
  { "the footer insets the body by its measured height", "DeadTired/UI.lua", '    vp.body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -pad, pad + math.ceil(h))   -- guard: footer insets the body', '    vp.body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -pad, pad + 16)', "test_ui" },
  { "a measure failure is counted (ui:measure)", "DeadTired/UI.lua", '    DT.fail("ui:measure", role, "width " .. tostring(w or raw))', "", "test_ui" },
  { "static suite: the CreateFontString rule (a raw call inserted)", "DeadTired/Crypt.lua", "local ICON = [[Interface\\Icons\\Spell_Shadow_RaiseDead]]", "local ICON = [[Interface\\Icons\\Spell_Shadow_RaiseDead]]\nlocal function raw(f) return f:CreateFontString() end", "test_textfit" },
  { "static suite: the numeric-footer rule (a pixel footer put back)", "DeadTired/Crypt.lua", "width = 440, height = 400, footer = CLOSING,", "width = 440, height = 400, footer = 16,", "test_textfit" },
  { "/dt debug fit restores the skin", "DeadTired/UI.lua", "  DT.fitSkin = nil                                                         -- guard: debug fit restores the skin", "", "test_debug" },
  { "/dt debug fit never saves the skin", "DeadTired/UI.lua", "    DT.fitSkin = name\n", '    DT.fitSkin = name; DT.set("core", "skin", name)\n', "test_debug" },
  { "realm line absent from the slowest board's tooltip", "DeadTired/Played.lua", "    tip = function(row, tt) tt:AddLine(DT.safe(DT.nameOf(row.key), 48)) end,", "    tip = function(row, tt) tt:AddLine(DT.safe(DT.nameOf(row.key), 48)); tt:AddLine(DT.realmLabel(row.key), 1, 1, 1) end,", "test_played" },
  { "realm line absent from the graveyard's tooltip", "DeadTired/Crypt.lua", "      tt:AddLine(DT.safe(DT.nameOf(row.key), 48))\n      tt:AddLine(row.full", "      tt:AddLine(DT.safe(DT.nameOf(row.key), 48)); tt:AddLine(DT.realmLabel(row.key), 1, 1, 1)\n      tt:AddLine(row.full", "test_crypt" },
  { "nudge: re-armed on a /reload (R-F4-6)", "DeadTired/Recruit.lua", "      if isReload == true then rearm() end                            -- guard: re-armed on a /reload (R-F4-6)", "", "test_recruit" },
  { "nudge: no re-arm on a first login", "DeadTired/Recruit.lua", "      if isReload == true then rearm() end", "      rearm()", "test_recruit" },
  { "nudge: no re-arm once the cooldown has ended", "DeadTired/Recruit.lua", '  if wait and wait > 0 and type(at) == "number" then', '  if type(at) == "number" then', "test_recruit" },
  { "the hint only when sharing is off (R-F4-7)", "DeadTired/Played.lua", "        if not sharing() then DT.out(HINT) end                         -- guard: the hint only when sharing is off", "        DT.out(HINT)", "test_played" },
  { "gank off: ignores inbound", "DeadTired/Gank.lua", '  if not DT.enabled("gank") then return end                                           -- guard: off ignores inbound (gank)', "", "test_gank" },
  { "gank off: /dt gank sends nothing, does nothing else", "DeadTired/Gank.lua", '        if not DT.enabled("gank") then return DT.out(OFF) end                         -- guard: off verbs do nothing else (gank)', "", "test_gank" },
  { "gank off: /dt ganks does nothing else", "DeadTired/Gank.lua", '        if not DT.enabled("gank") then return DT.out(OFF) end                         -- guard: off verbs do nothing else (ganks)', "", "test_gank" },
  { "played off: ignores inbound", "DeadTired/Played.lua", '  if not DT.enabled("played") then return end                          -- guard: off ignores inbound (played)', "", "test_played" },
  { "the sharing toggle withdraws even while Played is off (Tim, 12 Nov)", "DeadTired/Played.lua", "  if on then return end                                               -- (Tim, 12 Nov: withdraws even while Played is off)", '  if on then return end\n  if not DT.enabled("played") then return end', "test_played" },
  { "played off: /dt slowest does nothing else", "DeadTired/Played.lua", '  if not DT.enabled("played") then return DT.out(OFF) end              -- guard: off verbs do nothing else (slowest)', "", "test_played" },
  { "played off: /dt played does nothing else (the client not asked)", "DeadTired/Played.lua", '        if not DT.enabled("played") then return DT.out(OFF) end        -- guard: off verbs do nothing else (played)', "", "test_played" },
  { "stash off: ignores inbound searches", "DeadTired/Stash.lua", '  if not DT.enabled("stash") then return end                                     -- guard: off ignores inbound (stash)', "", "test_stash" },
  { "stash off: ignores inbound answers", "DeadTired/Stash.lua", '  if not DT.enabled("stash") then return end                                     -- guard: off ignores answers (stash)', "", "test_stash" },
  { "stash off: sends nothing (a waiting answer)", "DeadTired/Stash.lua", '    if not DT.enabled("stash") then return end                                   -- guard: off sends nothing (stash)', "", "test_stash" },
  { "stash off: /dt stash does nothing else", "DeadTired/Stash.lua", '  if not DT.enabled("stash") then return DT.out("stash.enabled = off") end       -- guard: off verbs do nothing else (stash)', "", "test_stash" },
  { "events off: prints nothing unasked (the ticker stops)", "DeadTired/Events.lua", '  if not DT.enabled("events") then looping = false return end          -- guard: off, the reminder ticker stops (events)', "", "test_events" },
  { "events off: /dt events does nothing else", "DeadTired/Events.lua", '  if not DT.enabled("events") then return DT.out("events.enabled = off") end   -- guard: off verbs do nothing else (events)', "", "test_events" },
  { "logs off: no prompt (the member signal)", "DeadTired/Logs.lua", '  if not DT.enabled("logs") then return end                                 -- guard: off, no prompt (logs)', "", "test_logs" },
  { "logs off: /dt logs does nothing else", "DeadTired/Logs.lua", '  if not DT.enabled("logs") then return DT.out("logs.enabled = off") end    -- guard: off verbs do nothing else (logs)', "", "test_logs" },
  { "a log dialog sized from its text", "DeadTired/Logs.lua", "  dlg:SetSize(w, L.dialogHeight(DT.textHeight(dlg.title, tw), DT.textHeight(dlg.status, tw)))   -- guard: dialog sized from its text", "  dlg:SetSize(w, 104)", "test_logs" },
  { "the skin move runs once (R-F4-4)", "DeadTired/Migrate.lua", "  if M.skin031 then return false end                                     -- guard: the skin move runs once", "", "test_migrate" },
  { "the skin move leaves forever alone", "DeadTired/Migrate.lua", '  if cur == nil or cur == "deadtired" then                               -- guard: forever left alone', '  if cur ~= "clean" then', "test_migrate" },
  -- Fix round 5 (COWORK_BRIEF_dt_fixes5.md, Task 6)
  { "the detail line is cut to its width (R-F5-1)", "DeadTired/UI.lua", "        DT.setWidth(b.detail, self.detailW)                                -- guard: the detail line is cut to its width", "        DT.setWidth(b.detail, 100000)", "test_ui" },
  { "a cut detail's text reaches the tooltip (R-F5-1)", "DeadTired/UI.lua", "        if DT.setText(b.detail, full) and not covers[self.detail.key] then b.cut[#b.cut + 1] = full end   -- guard: a cut detail's text reaches the tooltip", "        DT.setText(b.detail, full)", "test_ui" },
  { "a detail list's rows are one height (R-F5-1)", "DeadTired/UI.lua", "        b:SetHeight(self.rowH)                                             -- guard: every row one height", "        b:SetHeight(self.rowH + (b.detail and #b.cut or 0))", "test_ui" },
  { "count keeps the last row inside the body (R-F5-1)", "DeadTired/UI.lua", "    count = math.max(1, math.min(frames, math.floor(self.bodyH / self.rowH)))   -- guard: count keeps the last row inside the body", "    count = frames", "test_ui" },
  { "tipCovers suppresses the repeat (R-F5-1)", "DeadTired/UI.lua", "        if DT.setText(b.cells[c], full) and not covers[col.key] then b.cut[#b.cut + 1] = full end   -- guard: tipCovers suppresses the repeat", "        if DT.setText(b.cells[c], full) then b.cut[#b.cut + 1] = full end", "test_ui" },
  { "a list without detail is unchanged (R-F5-1)", "DeadTired/UI.lua", "  if opts.detail then rh = detailRowHeight() end                           -- guard: a list without detail is unchanged", "  rh = detailRowHeight()", "test_ui" },
  { "fonts set at load for every skin (R-F5-5)", "DeadTired/UI.lua", 'DT.listen("loaded", function() DT.preloadFonts() end)               -- guard: fonts set at load for every skin', "", "test_skins" },
  { "the second repaint is scheduled on a skin change (R-F5-5)", "DeadTired/Skins.lua", "    DT.after(0, DT.restyle)                                                -- guard: the second repaint is scheduled", "", "test_skins" },
  { "a false from SetFont is counted (fontTo) (R-F5-5)", "DeadTired/Skins.lua", '    if ok == false then DT.fail("ui:font", role, "SetFont refused " .. tostring(p)) end   -- guard: a false from SetFont is counted', "", "test_skins" },
  { "a false from SetFont is counted (the preload) (R-F5-5)", "DeadTired/UI.lua", '        if ok == false then DT.fail("ui:font", role, "SetFont refused " .. tostring(p)) end   -- guard: preload counts a false SetFont', "", "test_skins" },
}

local function read(p) local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return s end
local function write(p, s) local f = assert(io.open(p, "wb")); f:write(s); f:close() end
local function count(s, needle)
  local n, i = 0, 1
  while true do
    local a, b = s:find(needle, i, true)
    if not a then return n end
    n, i = n + 1, b + 1
  end
end

local bad = 0
print("| Guard | File | Change | Suite | Went red |")
print("|---|---|---|---|---|")
for _, g in ipairs(GUARDS) do
  local name, file, old, new, suite = g[1], g[2], g[3], g[4], g[5]
  local orig = read(file)
  local n = count(orig, old)
  local red, fails = false, {}
  if n ~= 1 then
    fails = { "guarded text found " .. n .. " times" }
    bad = bad + 1
  else
    local a = orig:find(old, 1, true)
    write(file, orig:sub(1, a - 1) .. new .. orig:sub(a + #old))
    local ok, err = pcall(function()
      local p = io.popen("lua5.1 " .. T .. suite .. ".lua 2>&1; echo EXIT=$?")
      local out = p:read("*a")
      p:close()
      local code = tonumber(out:match("EXIT=(%d+)")) or -1
      for l in out:gmatch("[^\n]+") do
        local f = l:match("^FAIL (.*)$")
        if f then fails[#fails + 1] = f end
      end
      if #fails == 0 and code ~= 0 then fails[1] = "suite crashed: " .. (out:match("lua5%.1: ([^\n]*)") or "?") end
      red = code ~= 0 and #fails > 0
    end)
    write(file, orig)
    if read(file) ~= orig then print("RESTORE FAILED: " .. file); bad = bad + 1 end
    if not ok then fails = { "runner error: " .. tostring(err) } end
    if not red then bad = bad + 1 end
  end
  local shown = {}
  for i = 1, math.min(3, #fails) do shown[i] = fails[i] end
  local more = #fails > 3 and (" (+" .. (#fails - 3) .. " more)") or ""
  local change = new == "" and "line removed" or ("`" .. new:gsub("\n", " ⏎ "):gsub("^%s+", "") .. "`")
  print(string.format("| %s | `%s` | %s | %s | %s |", name, file:match("[^/]+$"), change, suite,
    (red and "**red**: " or "**NOT RED**: ") .. table.concat(shown, "; ") .. more))
end
print("")
print(bad == 0 and "every guard proved; every file restored" or (bad .. " guard(s) not proved"))
os.exit(bad == 0 and 0 or 1)
