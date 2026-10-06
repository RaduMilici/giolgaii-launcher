-- Azeroth Completion: notifications for progress earned while playing.

local AZC = AZC
local W = AZC.W
local T = {}
AZC.Toasts = T

local queue = {}
local showing = false
local FADE_IN, HOLD, FADE_OUT = 0.35, 3.6, 0.8

local frame = CreateFrame("Frame", "AzerothCompletionToast", UIParent)
frame:SetFrameStrata("HIGH")
frame:SetWidth(380)
frame:SetHeight(82)
frame:SetPoint("TOP", UIParent, "TOP", 0, -150)
frame:Hide()
W.Backdrop(frame, "panel", 0.05, 0.04, 0.03, 0.94, 0.85, 0.68, 0.32)
frame:EnableMouse(true)
frame:SetScript("OnMouseUp", function()
    -- clicking a toast opens the journal on that zone (or page)
    if this.zoneId then AZC.UI.OpenZone(this.zoneId)
    elseif this.tab then AZC.UI.Open(this.tab) end
    this.elapsed = FADE_IN + HOLD
end)

local parchment = W.Parchment(frame, 0.22)

frame.iconHolder = W.FramedIcon(frame, 40, nil)
frame.iconHolder:SetPoint("LEFT", frame, "LEFT", 14, 0)

frame.glow = frame:CreateTexture(nil, "OVERLAY")
frame.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
frame.glow:SetBlendMode("ADD")
frame.glow:SetWidth(84)
frame.glow:SetHeight(84)
frame.glow:SetPoint("CENTER", frame.iconHolder, "CENTER", 0, 0)
frame.glow:SetVertexColor(1, 0.82, 0.3)

frame.title = W.Text(frame, 11, "gold", AZC.FONT_BODY, "OUTLINE")
frame.title:SetPoint("TOPLEFT", frame.iconHolder, "TOPRIGHT", 12, 0)
frame.name = W.Text(frame, 19, "white", AZC.FONT_TITLE)
frame.name:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -3)
frame.name:SetWidth(290)
frame.sub = W.Text(frame, 11, "paleGold")
frame.sub:SetPoint("TOPLEFT", frame.name, "BOTTOMLEFT", 0, -4)
frame.sub:SetWidth(290)

-- sparkles for the big moments
frame.stars = {}
for i = 1, 2 do
    local s = frame:CreateTexture(nil, "OVERLAY")
    s:SetTexture("Interface\\Cooldown\\star4")
    s:SetBlendMode("ADD")
    s:SetWidth(64)
    s:SetHeight(64)
    s:Hide()
    frame.stars[i] = s
end
frame.stars[1]:SetPoint("CENTER", frame, "TOPLEFT", 10, -6)
frame.stars[2]:SetPoint("CENTER", frame, "BOTTOMRIGHT", -10, 6)

local function Present(t)
    frame.zoneId = t.zoneId
    frame.tab = t.tab
    frame.iconHolder.icon:SetTexture(t.icon or "Interface\\Icons\\INV_Misc_Map_01")
    frame.title:SetText(t.title or "")
    frame.name:SetText(t.name or "")
    frame.sub:SetText(t.sub or "")
    frame.big = t.big
    frame.glow:SetAlpha(0)
    for _, s in ipairs(frame.stars) do
        if t.big then s:Show() else s:Hide() end
    end
    if t.big then
        frame:SetHeight(96)
        frame.name:SetFont(AZC.FONT_TITLE, 24, "")
        W.SetColor(frame.name, "gold")
        parchment:SetVertexColor(0.34, 0.28, 0.16)
    else
        frame:SetHeight(82)
        frame.name:SetFont(AZC.FONT_TITLE, 19, "")
        W.SetColor(frame.name, "white")
        parchment:SetVertexColor(0.22, 0.2, 0.16)
    end
    if t.sound and AZC.db.sound then pcall(PlaySound, t.sound) end
    frame.elapsed = 0
    frame:SetAlpha(0)
    frame:Show()
end

local function Next()
    local t = table.remove(queue, 1)
    if not t then
        showing = false
        frame:Hide()
        return
    end
    showing = true
    Present(t)
end

frame:SetScript("OnUpdate", function()
    this.elapsed = (this.elapsed or 0) + arg1
    local e = this.elapsed
    local alpha
    if e < FADE_IN then
        alpha = e / FADE_IN
    elseif e < FADE_IN + HOLD then
        alpha = 1
    elseif e < FADE_IN + HOLD + FADE_OUT then
        alpha = 1 - (e - FADE_IN - HOLD) / FADE_OUT
    else
        Next()
        return
    end
    this:SetAlpha(alpha)
    -- a slow golden pulse on the icon, stronger for big moments
    local pulse = (math.sin(e * 3.2) + 1) / 2
    this.glow:SetAlpha((this.big and 0.9 or 0.45) * pulse * alpha)
    if this.big then
        for i, s in ipairs(this.stars) do
            local size = 48 + 24 * math.abs(math.sin(e * 2 + i))
            s:SetWidth(size)
            s:SetHeight(size)
            s:SetAlpha(alpha * (0.5 + 0.5 * pulse))
        end
        this:SetBackdropBorderColor(1, 0.75 + 0.15 * pulse, 0.3 + 0.3 * pulse)
    end
end)

function T.Push(t)
    -- keep the queue short: a burst of discoveries should not take a minute to play
    if table.getn(queue) >= 6 then table.remove(queue, 1) end
    table.insert(queue, t)
    if not showing then Next() end
end

local OBJECTIVE_TITLES = {
    EXPLORATION = "AREA DISCOVERED",
    STORYLINE = "STORY COMPLETE",
    RARE = "RARE HUNT COMPLETE",
    ELITE = "ELITE DEFEATED",
    TRAVEL = "FLIGHT PATH DISCOVERED",
}

AZC.On("ServerEvent", function(ev)
    if not AZC.db then return end
    local zoneId = AZC.Num(ev.z)
    local zoneName = ev.zn or ""
    if ev.t == "OBJECTIVE_COMPLETED" and AZC.db.notifications then
        local cat = AZC.EVENT_CATEGORY[ev.c] or "exploration"
        local info = AZC.CATEGORY_INFO[cat]
        local title = OBJECTIVE_TITLES[ev.c] or "OBJECTIVE COMPLETE"
        if AZC.Bool(ev.b) then title = "BONUS " .. title end
        T.Push({ zoneId = zoneId, icon = info.icon, title = title, name = ev.n,
            sub = info.title .. "   " .. AZC.Num(ev.cd) .. " / " .. AZC.Num(ev.ct) .. "      " .. zoneName .. " " .. AZC.Num(ev.zp) .. "%",
            sound = "QUESTADDED" })
    elseif ev.t == "CATEGORY_COMPLETED" and AZC.db.notifications then
        local cat = AZC.EVENT_CATEGORY[ev.c] or "exploration"
        local info = AZC.CATEGORY_INFO[cat]
        T.Push({ zoneId = zoneId, icon = info.icon, title = AZC.Upper(info.title) .. " COMPLETE", name = zoneName,
            sub = "All " .. AZC.Num(ev.ct) .. " done      Zone " .. AZC.Num(ev.zp) .. "%", sound = "QUESTCOMPLETED" })
    elseif ev.t == "STORYLINE_PROGRESS" and AZC.db.notifications then
        local sub = "Progress " .. AZC.Num(ev.qd) .. " / " .. AZC.Num(ev.qt)
        if ev.nxn and ev.nxn ~= "" then sub = sub .. "      Next: " .. ev.nxn end
        T.Push({ zoneId = zoneId, icon = AZC.CATEGORY_INFO.storylines.icon, title = "STORY PROGRESS", name = ev.n, sub = sub })
    elseif ev.t == "MILESTONE_REACHED" and AZC.db.milestoneNotifications then
        local sub = ev.rw and ev.rw ~= "" and ("Reward: " .. ev.rw) or "Milestone reached"
        T.Push({ zoneId = zoneId, icon = "Interface\\Icons\\INV_Box_02", title = AZC.Upper(zoneName),
            name = AZC.Num(ev.m) .. "% COMPLETE", sub = sub, sound = "QUESTCOMPLETED" })
    elseif ev.t == "REGION_COMPLETED" and AZC.db.milestoneNotifications then
        local sub = ev.rw and ev.rw ~= "" and ("Reward: " .. ev.rw) or ("All " .. AZC.Num(ev.zc) .. " zones complete.")
        T.Push({ tab = "azeroth", icon = "Interface\\Icons\\INV_Misc_Map02", title = "REGION COMPLETE",
            name = AZC.Upper(ev.rn or ""), sub = sub, sound = "LEVELUPSOUND", big = true })
    elseif ev.t == "ZONE_COMPLETED" and AZC.db.milestoneNotifications then
        T.Push({ zoneId = zoneId, icon = "Interface\\Icons\\INV_Misc_Map_01", title = "ZONE COMPLETE",
            name = AZC.Upper(zoneName) .. "  100%", sub = "Every corner explored, every tale told.", sound = "LEVELUPSOUND", big = true })
    end
end)

-- preview from settings
function T.Preview()
    T.Push({ icon = AZC.CATEGORY_INFO.exploration.icon, title = "AREA DISCOVERED", name = "The Dagger Hills",
        sub = "Exploration   11 / 13      Westfall 68%", sound = "QUESTADDED" })
end
