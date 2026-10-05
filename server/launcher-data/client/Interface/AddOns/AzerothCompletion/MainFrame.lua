-- Azeroth Completion: the journal window - frame, tabs, search box, breadcrumbs, navigation.

local AZC = AZC
local W = AZC.W
local UI = {}
AZC.UI = UI

UI.pages = {}
UI.history = {}
UI.current = nil        -- { tab, params }

local WIDTH, HEIGHT = 800, 590
-- Width of the page area (window minus its 16 px margins). Pages size their art and bars from
-- this instead of GetWidth(), which Vanilla reports scaled down for anchored frames.
UI.CONTENT_WIDTH = WIDTH - 32
UI.CONTENT_HEIGHT = HEIGHT - 92     -- 76 px title/tabs/breadcrumbs above, 16 px margin below

local f = CreateFrame("Frame", "AzerothCompletionFrame", UIParent)
UI.frame = f
f:SetWidth(WIDTH)
f:SetHeight(HEIGHT)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
f:SetFrameStrata("HIGH")
f:SetToplevel(true)
f:EnableMouse(true)
f:SetMovable(true)
f:SetClampedToScreen(true)
f:RegisterForDrag("LeftButton")
f:Hide()
W.Backdrop(f, "window", 0.05, 0.045, 0.04, 1)
tinsert(UISpecialFrames, "AzerothCompletionFrame")

f:SetScript("OnDragStart", function() this:StartMoving() end)
f:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local point, _, relPoint, x, y = this:GetPoint()
    AZC.db.window.point = { point, relPoint, x, y }
end)
f:SetScript("OnShow", function() if AZC.db.sound then PlaySound("igQuestLogOpen") end end)
f:SetScript("OnHide", function() if AZC.db.sound then PlaySound("igQuestLogClose") end end)

-- title plate
local title = W.Text(f, 15, "gold", AZC.FONT_TITLE)
title:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -20)
title:SetText("Azeroth Completion")

local close = CreateFrame("Button", "AzerothCompletionFrameClose", f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

-- tabs
UI.tabs = {}
local tabDefs = {
    { key = "zone", text = "Zone" },
    { key = "azeroth", text = "Azeroth" },
    { key = "settings", text = "Settings" },
}
local lastTab
for _, def in ipairs(tabDefs) do
    local key = def.key
    local tab = W.ToggleButton(f, def.text, 86, 24, function()
        if key == "zone" then UI.OpenZone(nil) else UI.Navigate(key, {}) end
    end)
    if lastTab then
        tab:SetPoint("LEFT", lastTab, "RIGHT", 6, 0)
    else
        tab:SetPoint("TOPLEFT", f, "TOPLEFT", 210, -18)
    end
    lastTab = tab
    UI.tabs[key] = tab
end

-- search box
local search = CreateFrame("EditBox", "AzerothCompletionSearchBox", f, "InputBoxTemplate")
search:SetWidth(170)
search:SetHeight(20)
search:SetPoint("TOPRIGHT", f, "TOPRIGHT", -42, -20)
search:SetAutoFocus(false)
search:SetMaxLetters(40)
local searchHint = W.Text(search, 11, "dim")
searchHint:SetPoint("LEFT", search, "LEFT", 2, 0)
searchHint:SetText("Search zones, quests, places...")
search:SetScript("OnEditFocusGained", function() searchHint:Hide() end)
search:SetScript("OnEditFocusLost", function() if this:GetText() == "" then searchHint:Show() end end)
search:SetScript("OnEscapePressed", function() this:ClearFocus() end)
search:SetScript("OnEnterPressed", function()
    local text = this:GetText()
    this:ClearFocus()
    if string.len(text) >= 2 then UI.Navigate("search", { text = text }) end
end)
local searchIcon = search:CreateTexture(nil, "OVERLAY")
searchIcon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_02")
searchIcon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
searchIcon:SetWidth(16)
searchIcon:SetHeight(16)
searchIcon:SetPoint("RIGHT", search, "LEFT", -8, 0)
UI.searchBox = search

-- breadcrumb bar with back button
local crumbBar = CreateFrame("Frame", nil, f)
crumbBar:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -48)
crumbBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -48)
crumbBar:SetHeight(24)
local crumbLine = W.Line(crumbBar, 0.35)
crumbLine:SetPoint("BOTTOMLEFT", crumbBar, "BOTTOMLEFT", 0, 0)
crumbLine:SetPoint("BOTTOMRIGHT", crumbBar, "BOTTOMRIGHT", 0, 0)

local back = CreateFrame("Button", nil, crumbBar)
back:SetWidth(22)
back:SetHeight(22)
back:SetPoint("LEFT", crumbBar, "LEFT", 4, 0)
back:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
back:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
back:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
back:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
back:SetScript("OnClick", function() UI.Back() end)
W.Tooltip(back, "Back")
UI.backButton = back

local crumbs = {}
local function Crumb(i)
    if crumbs[i] then return crumbs[i] end
    local b = CreateFrame("Button", nil, crumbBar)
    b:SetHeight(20)
    b.text = W.Text(b, 12, "paleGold")
    b.text:SetPoint("LEFT", b, "LEFT", 0, 0)
    b.sep = W.Text(crumbBar, 12, "dim")
    b.sep:SetText(">")
    b:SetScript("OnEnter", function() if this.fn then W.SetColor(this.text, "white") end end)
    b:SetScript("OnLeave", function() W.SetColor(this.text, this.fn and "paleGold" or "gold") end)
    b:SetScript("OnClick", function() if this.fn then this.fn() end end)
    crumbs[i] = b
    return b
end

function UI.SetBreadcrumbs(list)
    for _, b in ipairs(crumbs) do b:Hide() b.sep:Hide() end
    local anchor, anchorPoint, gap = back, "RIGHT", 8
    for i, item in ipairs(list or {}) do
        local b = Crumb(i)
        b.fn = item.fn
        b.text:SetText(item.label)
        W.SetColor(b.text, item.fn and "paleGold" or "gold")
        b:SetWidth(b.text:GetStringWidth() + 4)
        if i > 1 then
            b.sep:ClearAllPoints()
            b.sep:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
            b.sep:Show()
            b:ClearAllPoints()
            b:SetPoint("LEFT", b.sep, "RIGHT", 6, 0)
        else
            b:ClearAllPoints()
            b:SetPoint("LEFT", anchor, anchorPoint, gap, 0)
        end
        b:Show()
        anchor = b
    end
end

-- content area shared by the pages
local content = CreateFrame("Frame", nil, f)
content:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -76)
content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
UI.content = content

-- status overlay: shown instead of progress when the server is not ready
local overlay = CreateFrame("Frame", nil, f)
overlay:SetAllPoints(content)
overlay:SetFrameLevel(content:GetFrameLevel() + 20)
overlay:EnableMouse(true)
W.Backdrop(overlay, "panel", 0.04, 0.035, 0.03, 0.97)
W.Parchment(overlay, 0.18)
local overlayIcon = W.Icon(overlay, 64, "Interface\\Icons\\INV_Misc_Map_01")
overlayIcon:SetPoint("CENTER", overlay, "CENTER", 0, 60)
local overlayTitle = W.Text(overlay, 22, "gold", AZC.FONT_TITLE)
overlayTitle:SetPoint("TOP", overlayIcon, "BOTTOM", 0, -18)
overlayTitle:SetJustifyH("CENTER")
local overlayText = W.Text(overlay, 13, "parchment")
overlayText:SetPoint("TOP", overlayTitle, "BOTTOM", 0, -12)
overlayText:SetWidth(460)
overlayText:SetJustifyH("CENTER")
local retry = W.PanelButton(overlay, "Try again", 120, 24, function() AZC.Protocol.Hello() end)
retry:SetPoint("TOP", overlayText, "BOTTOM", 0, -20)
overlay:Hide()

local function UpdateOverlay()
    local status = AZC.Protocol.status
    if status == "ready" or (UI.current and UI.current.tab == "settings") then
        overlay:Hide()
        return
    end
    retry:Hide()
    if status == "incompatible" then
        overlayTitle:SetText("Azeroth Completion requires an update.")
        overlayText:SetText("Please restart the launcher.")
    elseif status == "unavailable" then
        overlayTitle:SetText("The journal is out of reach")
        overlayText:SetText("Azeroth Completion is not answering on this realm right now.")
        retry:Show()
    else
        overlayTitle:SetText("Opening your journal...")
        overlayText:SetText("")
    end
    overlay:Show()
end

-- ---------------------------------------------------------------------------
-- navigation

function UI.Register(key, page)
    UI.pages[key] = page
    page.frame:SetParent(content)
    page.frame:SetAllPoints(content)
    page.frame:Hide()
end

local function ShowPage(tab, params)
    for key, page in pairs(UI.pages) do
        if key ~= tab then page.frame:Hide() end
    end
    for key, b in pairs(UI.tabs) do
        b:SetSelected(key == tab)
    end
    UI.current = { tab = tab, params = params or {} }
    if tab == "zone" or tab == "azeroth" or tab == "settings" then AZC.db.window.tab = tab end
    local page = UI.pages[tab]
    if page then
        page.frame:Show()
        page:Show(UI.current.params)
    end
    UI.backButton:Enable()
    if table.getn(UI.history) == 0 then UI.backButton:Disable() end
    UpdateOverlay()
end

function UI.Navigate(tab, params, replace)
    if UI.current and not replace then
        table.insert(UI.history, UI.current)
        if table.getn(UI.history) > 30 then table.remove(UI.history, 1) end
    end
    ShowPage(tab, params)
    if not f:IsShown() then f:Show() end
end

function UI.Back()
    local prev = table.remove(UI.history)
    if prev then ShowPage(prev.tab, prev.params) end
end

-- zoneId nil = the zone the player is in; `focus` optionally jumps to an objective
function UI.OpenZone(zoneId, focus)
    UI.Navigate("zone", { zoneId = zoneId, focus = focus })
end

function UI.Open(tab)
    if tab == "zone" or not tab then UI.OpenZone(nil) else UI.Navigate(tab, {}) end
end

function UI.Toggle()
    if f:IsShown() then
        f:Hide()
        return
    end
    UI.history = {}
    UI.current = nil
    local tab = AZC.db.window.tab or "zone"
    f:Show()
    UI.Open(tab)
    -- bars measure their width only once the frame has been drawn
    AZC.After(0.05, UI.Refresh)
end

function UI.Refresh()
    if not f:IsShown() or not UI.current then return end
    local page = UI.pages[UI.current.tab]
    if page and page.Refresh then page:Refresh() end
    UpdateOverlay()
end

function UI.ApplyScale()
    f:SetScale(AZC.db.window.scale or 1)
end

function UI.ResetPosition()
    AZC.db.window.point = nil
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
end

AZC.On("Ready", function()
    UI.ApplyScale()
    local p = AZC.db.window.point
    if p then
        f:ClearAllPoints()
        f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end
end)

AZC.On("StatusChanged", function()
    UpdateOverlay()
    UI.Refresh()
end)

AZC.On("DataChanged", function()
    UI.Refresh()
end)
