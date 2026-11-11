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
  { "list rows fit their text", "DeadTired/UI.lua", "local h = DT.rowHeight(hs, rh, 4)", "local h = rh", "test_ui" },
  { "settings content follows the scroll", "DeadTired/SettingsView.lua", "  if scroll > maxS then scroll = maxS end\n  place()", "  if scroll > maxS then scroll = maxS end", "test_settingsview" },
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
