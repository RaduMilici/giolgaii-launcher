-- Azeroth Completion: minimap button.

local AZC = AZC
local W = AZC.W
local M = {}
AZC.Minimap = M

local RADIUS = 80           -- distance from the minimap centre, like Blizzard's own buttons
local MIN_GAP = 24          -- degrees between button centres (a 31 px button at radius 80)
local PREFERRED = 200       -- first choice: lower left, a quiet spot on most layouts

local button = CreateFrame("Button", "AzerothCompletionMinimapButton", Minimap)
button:SetWidth(31)
button:SetHeight(31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:SetToplevel(true)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
button:Hide()

local icon = button:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
icon:SetWidth(20)
icon:SetHeight(20)
icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local border = button:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetWidth(53)
border:SetHeight(53)
border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

-- completion glow: brightens with the current zone's progress, full gold at 100%
local glow = button:CreateTexture(nil, "ARTWORK")
glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
glow:SetBlendMode("ADD")
glow:SetWidth(48)
glow:SetHeight(48)
glow:SetPoint("CENTER", icon, "CENTER", 0, 0)
glow:SetAlpha(0)

local function Place(angle)
    local a = math.rad(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * RADIUS, math.sin(a) * RADIUS)
end

-- Angles (degrees) already taken by other buttons around the minimap.
local function OccupiedAngles()
    local taken = {}
    local mx, my = Minimap:GetCenter()
    if not mx then return taken end
    local scale = Minimap:GetEffectiveScale()
    local function consider(f)
        if not f or f == button or not f.IsShown or not f:IsShown() or not f.GetCenter then return end
        local w, h = f:GetWidth() or 0, f:GetHeight() or 0
        if w < 12 or w > 64 or h < 12 or h > 64 then return end
        local fx, fy = f:GetCenter()
        if not fx then return end
        local fs = f:GetEffectiveScale() / scale
        local dx, dy = fx * fs - mx, fy * fs - my
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > RADIUS - 25 and dist < RADIUS + 35 then
            table.insert(taken, math.deg(math.atan2(dy, dx)))
        end
    end
    local kids = { Minimap:GetChildren() }
    for _, f in ipairs(kids) do consider(f) end
    if MinimapCluster then
        local more = { MinimapCluster:GetChildren() }
        for _, f in ipairs(more) do consider(f) end
    end
    return taken
end

local function AngleDistance(a, b)
    local d = math.abs(math.mod(a - b + 540, 360) - 180)
    return d
end

-- The free spot nearest the preferred angle, scanning outwards both ways.
local function FindFreeAngle()
    local taken = OccupiedAngles()
    for step = 0, 180, 4 do
        for _, sign in ipairs({ 1, -1 }) do
            local candidate = math.mod(PREFERRED + sign * step + 360, 360)
            local free = true
            for _, t in ipairs(taken) do
                if AngleDistance(candidate, t) < MIN_GAP then free = false break end
            end
            if free then return candidate end
        end
    end
    return PREFERRED
end

function M.ResetPosition()
    AZC.db.minimap.angle = FindFreeAngle()
    Place(AZC.db.minimap.angle)
end

button:SetScript("OnDragStart", function()
    if AZC.db.minimap.locked then return end
    this.dragging = true
    this:LockHighlight()
end)

button:SetScript("OnDragStop", function()
    this.dragging = false
    this:UnlockHighlight()
end)

button:SetScript("OnUpdate", function()
    if not this.dragging then return end
    local mx, my = Minimap:GetCenter()
    local x, y = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local angle = math.deg(math.atan2(y / scale - my, x / scale - mx))
    AZC.db.minimap.angle = angle
    Place(angle)
end)

button:SetScript("OnClick", function()
    if arg1 == "RightButton" then
        AZC.UI.Open("settings")
    else
        AZC.UI.Toggle()
    end
end)

function M.Refresh()
    if not AZC.db then return end
    if not AZC.db.minimap.show then
        button:Hide()
        return
    end
    button:Show()
    local z = AZC.Data.CurrentZone()
    if z and z.zone and AZC.Protocol.IsReady() then
        local pct = AZC.Num(z.zone.pct)
        if AZC.Bool(z.zone.done) or AZC.Bool(z.zone.earned) then
            glow:SetVertexColor(1, 0.85, 0.3)
            glow:SetAlpha(0.9)
        else
            glow:SetVertexColor(0.9, 0.7, 0.3)
            glow:SetAlpha(pct / 100 * 0.45)
        end
    else
        glow:SetAlpha(0)
    end
end

W.Tooltip(button, function()
    local lines = {}
    local status = AZC.Protocol.status
    if status == "incompatible" then
        table.insert(lines, { "Requires an update - please restart the launcher.", "red", true })
    elseif status == "unavailable" then
        table.insert(lines, { "Not available on this realm right now.", "grey", true })
    elseif status == "connecting" then
        table.insert(lines, { "Connecting...", "grey" })
    else
        local z = AZC.Data.CurrentZone()
        if z and z.zone then
            local done, total = AZC.Data.ZoneTotals(z)
            table.insert(lines, { left = z.zone.n, right = AZC.Num(z.zone.pct) .. "%", leftColor = "white",
                rightColor = AZC.Bool(z.zone.done) and "gold" or "paleGold" })
            table.insert(lines, { done .. " / " .. total .. " objectives", "grey" })
        else
            table.insert(lines, { (GetRealZoneText() or "") .. " has no completion journal.", "grey", true })
        end
    end
    table.insert(lines, "")
    table.insert(lines, { "Click to open", "paleGold" })
    table.insert(lines, { "Right-click for settings", "paleGold" })
    if not AZC.db.minimap.locked then table.insert(lines, { "Drag to move", "paleGold" }) end
    return "Azeroth Completion", lines
end)

AZC.On("Ready", function()
    if AZC.db.minimap.angle then
        Place(AZC.db.minimap.angle)
        M.Refresh()
    else
        -- wait for other addons to put their buttons down, then pick a free spot
        Place(PREFERRED)
        AZC.After(4, function()
            if not AZC.db.minimap.angle then M.ResetPosition() end
            M.Refresh()
        end)
    end
end)

AZC.On("DataChanged", function() M.Refresh() end)
AZC.On("StatusChanged", function() M.Refresh() end)
