-- Offline checks for SettingsView.lua: the settings viewport builds itself from the registry; a
-- change there shows in /dt get, a /dt set shows there; the entry points (/dt settings, the game's
-- Settings -> AddOns page, the addon compartment).  lua5.1 DeadTired/tests/test_settingsview.lua
local dir = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]+$") or "."
local H = dofile(dir .. "/harness.lua")
local check = H.check
local G = "DEAD TIRED"

local w = H.world()
local c = w:client({ guild = G })
c:login()
local DT = c.DT

check("Settings -> AddOns: a Dead Tired page registered", c.settingsCat and c.settingsCat.name == "Dead Tired"
  and c.addOnCategory == c.settingsCat and c.settingsCat.frame == c:frame("DeadTiredSettingsPanel"))
check("the .toc names the compartment function", (function()
  for line in io.lines(H.addonDir .. "/DeadTired.toc") do
    if line:match("^## AddonCompartmentFunc: DeadTired_OnAddonCompartmentClick") then return true end
  end
end)())
check("the compartment function is DT's own global", type(rawget(c.env, "DeadTired_OnAddonCompartmentClick")) == "function")

c.env.DeadTired_OnAddonCompartmentClick("DeadTired", "LeftButton")
local vpf = c:frame("DeadTiredViewport_settings")
check("the compartment opens the settings viewport", vpf and vpf.shown)
vpf:Hide()
-- the page's button
local button
for _, f in ipairs(c.frames) do if f._parent == c:frame("DeadTiredSettingsPanel") and f.text == "Open Dead Tired settings" then button = f end end
button.scripts.OnClick(button)
check("the Settings page's button opens it", vpf.shown)
vpf:Hide()
c:slash("settings")
check("/dt settings opens it", vpf.shown)

-- every setting has a row in plain words, with its /dt line or where it lives
local rows = {}
for _, f in ipairs(c.frames) do
  if f._type == "FontString" and type(f.text) == "string" and f.text:find("^/dt set ") then rows[#rows + 1] = f.text end
end
local total, typed, notTyped = 0, 0, 0
for id, reg in pairs(DT.settings) do
  for _, s in ipairs(reg.list) do
    total = total + 1
    if DT.typed(s) then typed = typed + 1 else notTyped = notTyped + 1 end
  end
end
check("one /dt line per typed setting", #rows == typed)
local notTypedLines = 0
for _, f in ipairs(c.frames) do
  if f._type == "FontString" and type(f.text) == "string" and f.text:find("^Not typed: ") then notTypedLines = notTypedLines + 1 end
end
check("and a 'Not typed: <where>' line for each one that isn't", notTypedLines == notTyped and notTyped >= 2)
local function fs(text) for _, f in ipairs(c.frames) do if f._type == "FontString" and f.text == text then return f end end end
check("labels and plain-word descriptions shown", fs("Welcome line") and fs(DT.setting("guild", "welcome").desc)
  and fs(DT.setting("who", "hello").desc))
check("a hint names the dedicated verb too", fs("/dt set bar mode <value>  or  /dt bar on|off|auto") ~= nil)

-- a change there shows in /dt get
local check_, choice
for _, f in ipairs(c.frames) do
  if f._type == "CheckButton" and f._parent and f._parent.c and not check_ then
    -- the welcome row's checkbox: the first CheckButton (guild is the first card)
    check_ = f
  end
  if f._type == "Button" and f._template == "UIPanelButtonTemplate" and f.text == "deadtired" then choice = f end
end
check("the welcome checkbox reads the setting", check_ and check_:GetChecked() == true)
check_:SetChecked(false); check_.scripts.OnClick(check_)
c:slash("get guild welcome")
check("changed in the viewport: /dt get shows it", c:said("guild.welcome = off") ~= nil)
c:slash("set guild welcome on")
check("changed with /dt set: the viewport shows it", check_:GetChecked() == true)
choice.scripts.OnClick(choice)
check("a choice cycles through DT.set", DT.get("core", "skin") == "forever" and choice.text == "forever")

-- search
local search = c:frame("DeadTiredViewport_settings")
local box
for _, f in ipairs(c.frames) do if f._type == "EditBox" and f._parent == search then box = f end end
box:SetText("HELLO"); box.scripts.OnTextChanged(box)
local shownLabels = 0
for _, f in ipairs(c.frames) do
  if f._type == "Frame" and f.shown and f._parent and f._parent._parent and f._parent._parent._parent == search then
    shownLabels = shownLabels + 1
  end
end
check("searching the settings filters the cards (case-insensitive)", shownLabels == 3)   -- the Who card, its switch (says hello) and its hello row
c:slash("settings who")
check("/dt settings <words> opens it searched", box.text == "who")

-- outside the guild nothing opens
local w2 = H.world()
local o = w2:client({ guild = "Elsewhere" })
o:login()
o.env.DeadTired_OnAddonCompartmentClick()
check("outside the guild: the compartment opens nothing", o:frame("DeadTiredViewport_settings") == nil)

H.finish("settingsview")
