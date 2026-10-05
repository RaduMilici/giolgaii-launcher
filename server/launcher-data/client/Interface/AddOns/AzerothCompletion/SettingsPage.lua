-- Azeroth Completion: settings.

local AZC = AZC
local W = AZC.W
local UI = AZC.UI

local page = {}
local frame = CreateFrame("Frame", nil, UIParent)
page.frame = frame

local back = CreateFrame("Frame", nil, frame)
back:SetAllPoints(frame)
W.Backdrop(back, "panel", 0.05, 0.045, 0.04, 0.97, 0.6, 0.48, 0.3)
W.Parchment(back, 0.2)

local title = W.Text(frame, 24, "gold", AZC.FONT_TITLE)
title:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -18)
title:SetText("Settings")

local checks = {}

local function Section(text, x, y)
    local fs = W.Text(frame, 11, "gold", AZC.FONT_BODY, "OUTLINE")
    fs:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
    fs:SetText(AZC.Upper(text))
    local line = W.Line(frame, 0.4)
    line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -4)
    line:SetWidth(300)
end

-- get/set work on AZC.db
local function Check(label, tip, x, y, get, set)
    local name = W.Name("Check")
    local c = CreateFrame("CheckButton", name, frame, "UICheckButtonTemplate")
    c:SetWidth(26)
    c:SetHeight(26)
    c:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
    local text = getglobal(name .. "Text")
    text:SetFont(AZC.FONT_BODY, 12, "")
    text:SetTextColor(0.93, 0.80, 0.52)
    text:SetText(label)
    c:SetScript("OnClick", function()
        set(this:GetChecked() and true or false)
        if AZC.db.sound then PlaySound(this:GetChecked() and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff") end
    end)
    W.Tooltip(c, label, { { tip, "white", true } })
    c.get = get
    table.insert(checks, c)
    return c
end

local LEFT, RIGHT = 30, 400

Section("Minimap", LEFT, -70)
Check("Show minimap button", "Show the Azeroth Completion button around the minimap.", LEFT, -92,
    function() return AZC.db.minimap.show end,
    function(v) AZC.db.minimap.show = v AZC.Minimap.Refresh() end)
Check("Lock minimap button", "Stop the button from being dragged around the minimap.", LEFT, -118,
    function() return AZC.db.minimap.locked end,
    function(v) AZC.db.minimap.locked = v end)

Section("Notifications", LEFT, -164)
Check("Show completion notifications", "Announce discovered areas, slain rares, finished storylines and new quests.", LEFT, -186,
    function() return AZC.db.notifications end,
    function(v) AZC.db.notifications = v end)
Check("Show milestone notifications", "Announce zone milestones and completed zones.", LEFT, -212,
    function() return AZC.db.milestoneNotifications end,
    function(v) AZC.db.milestoneNotifications = v end)
Check("Play sounds", "Sounds for notifications and the journal.", LEFT, -238,
    function() return AZC.db.sound end,
    function(v) AZC.db.sound = v end)
local preview = W.PanelButton(frame, "Preview", 90, 22, function() AZC.Toasts.Preview() end)
preview:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT + 4, -272)

Section("Journal", RIGHT, -70)
Check("Compact zone panel", "A smaller zone header, leaving more room for the list.", RIGHT, -92,
    function() return AZC.db.compactHeader end,
    function(v) AZC.db.compactHeader = v end)
Check("Hide undiscovered objective names", "Show unkilled rares and elites as undiscovered instead of naming them.", RIGHT, -118,
    function() return AZC.db.hideUndiscovered end,
    function(v) AZC.db.hideUndiscovered = v end)

-- window scale
local sliderName = W.Name("Scale")
local slider = CreateFrame("Slider", sliderName, frame, "OptionsSliderTemplate")
slider:SetWidth(220)
slider:SetHeight(16)
slider:SetPoint("TOPLEFT", frame, "TOPLEFT", RIGHT + 8, -176)
slider:SetMinMaxValues(0.7, 1.3)
slider:SetValueStep(0.05)
getglobal(sliderName .. "Low"):SetText("70%")
getglobal(sliderName .. "High"):SetText("130%")
local sliderText = getglobal(sliderName .. "Text")
slider:SetScript("OnValueChanged", function()
    local v = math.floor(this:GetValue() * 20 + 0.5) / 20
    sliderText:SetText("Window scale: " .. math.floor(v * 100 + 0.5) .. "%")
    if AZC.db and this.ready then
        AZC.db.window.scale = v
        UI.ApplyScale()
    end
end)

Section("Positions", RIGHT, -226)
local resetWindow = W.PanelButton(frame, "Reset window position", 180, 22, function() UI.ResetPosition() end)
resetWindow:SetPoint("TOPLEFT", frame, "TOPLEFT", RIGHT + 4, -250)
local resetMinimap = W.PanelButton(frame, "Reset minimap button", 180, 22, function() AZC.Minimap.ResetPosition() end)
resetMinimap:SetPoint("TOPLEFT", resetWindow, "BOTTOMLEFT", 0, -6)

local about = W.Text(frame, 11, "dim")
about:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 18)
about:SetWidth(700)

function page:Refresh()
    for _, c in ipairs(checks) do c:SetChecked(c.get() and 1 or nil) end
    slider.ready = false
    slider:SetValue(AZC.db.window.scale or 1)
    slider.ready = true
    local proto = AZC.Protocol.proto
    local server = proto and ("server " .. (proto.srv or "?") .. ", protocol " .. AZC.Num(proto.v)) or ("server " .. AZC.Protocol.status)
    about:SetText("Azeroth Completion " .. AZC.VERSION .. "  -  " .. server .. "  -  /azc opens the journal")
end

function page:Show()
    UI.SetBreadcrumbs({ { label = "Settings" } })
    self:Refresh()
end

UI.Register("settings", page)
