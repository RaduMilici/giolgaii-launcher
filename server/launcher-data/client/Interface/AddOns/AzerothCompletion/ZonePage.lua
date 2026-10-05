-- Azeroth Completion: the zone page - header, filters and the expandable category list.

local AZC = AZC
local W = AZC.W
local D = AZC.Data
local UI = AZC.UI

local page = {}
local frame = CreateFrame("Frame", nil, UIParent)
page.frame = frame

local LIST_WIDTH = 478
local HEADER_FULL, HEADER_COMPACT = 118, 70

page.zoneId = nil           -- the zone shown (resolved)
page.filter = "all"         -- all | missing | completed
page.expanded = {}          -- category key -> true
page.expandedStory = {}     -- storyline id -> true
page.selected = nil         -- objective id or "quest:<id>"
page.focus = nil            -- objective id to bring into view after the next layout

-- ===========================================================================
-- header

local header = CreateFrame("Frame", nil, frame)
header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
header:SetHeight(HEADER_FULL)
W.Backdrop(header, "panel", 0.06, 0.05, 0.04, 1, 0.70, 0.56, 0.30)
page.header = header

local headerParchment = W.Parchment(header, 0.26)

-- zone map artwork, faded behind the title
-- The fourth tile in this row is empty on some zone maps (for example Elwynn).
-- Use the three map tiles with artwork so the banner stays filled edge to edge.
local art = {}
for i = 1, 3 do
    local t = header:CreateTexture(nil, "BORDER")
    t:SetAlpha(0.55)
    t:Hide()
    art[i] = t
end
local shade = header:CreateTexture(nil, "ARTWORK")
shade:SetTexture(0, 0, 0)
shade:SetPoint("TOPLEFT", header, "TOPLEFT", 4, -4)
shade:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -4, 4)
shade:SetGradientAlpha("HORIZONTAL", 0, 0, 0, 0.82, 0, 0, 0, 0.30)

local artCache = {}
-- World map tiles of a zone, found through the client's own map list.
local function ZoneArtFile(zoneName)
    if not zoneName or zoneName == "" then return nil end
    if artCache[zoneName] ~= nil then return artCache[zoneName] or nil end
    if WorldMapFrame and WorldMapFrame:IsShown() then return nil end   -- never disturb an open map
    local found = false
    for c = 1, 2 do
        local zones = { GetMapZones(c) }
        for i, name in ipairs(zones) do
            if name == zoneName then
                SetMapZoom(c, i)
                found = GetMapInfo() or false
                break
            end
        end
        if found then break end
    end
    SetMapToCurrentZone()
    artCache[zoneName] = found
    return found or nil
end

local LayoutArt
header:SetScript("OnSizeChanged", function() if LayoutArt then LayoutArt() end end)

function LayoutArt()
    local file = page.zoneId and D.Zone(page.zoneId) and D.Zone(page.zoneId).zone and ZoneArtFile(D.Zone(page.zoneId).zone.n)
    if not file then
        for _, t in ipairs(art) do t:Hide() end
        headerParchment:Show()
        return
    end
    headerParchment:Hide()
    -- sizes from the layout, not GetWidth() (Vanilla reports it scaled down here)
    local height = (AZC.db.compactHeader and HEADER_COMPACT or HEADER_FULL) - 8
    local w = (UI.CONTENT_WIDTH - 8) / table.getn(art)
    for i, t in ipairs(art) do
        t:SetTexture("Interface\\WorldMap\\" .. file .. "\\" .. file .. (i + 4))
        t:SetTexCoord(0, 1, 0.15, math.min(1, 0.15 + height / w))
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", header, "TOPLEFT", 4 + (i - 1) * w, -4)
        t:SetWidth(w)
        t:SetHeight(height)
        t:Show()
    end
end

local zoneName = W.Text(header, 30, "gold", AZC.FONT_TITLE)
zoneName:SetPoint("TOPLEFT", header, "TOPLEFT", 20, -14)

local zoneSub = W.Text(header, 11, "paleGold")
zoneSub:SetPoint("TOPLEFT", zoneName, "BOTTOMLEFT", 2, -2)

local pctText = W.Text(header, 32, "white", AZC.FONT_TITLE)
pctText:SetPoint("TOPRIGHT", header, "TOPRIGHT", -20, -10)
pctText:SetJustifyH("RIGHT")

local pctLabel = W.Text(header, 11, "paleGold", AZC.FONT_BODY, "OUTLINE")
pctLabel:SetPoint("TOPRIGHT", pctText, "BOTTOMRIGHT", 0, 0)
pctLabel:SetJustifyH("RIGHT")

local completeCheck = header:CreateTexture(nil, "OVERLAY")
completeCheck:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
completeCheck:SetWidth(26)
completeCheck:SetHeight(26)
completeCheck:SetPoint("RIGHT", pctLabel, "LEFT", 0, 1)
completeCheck:Hide()

local zoneBar = W.ProgressBar(header, 18)
zoneBar:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 18, 30)
zoneBar:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -18, 30)

local countText = W.Text(header, 12, "parchment")
countText:SetPoint("TOPLEFT", zoneBar, "BOTTOMLEFT", 2, -5)

local rewardText = W.Text(header, 12, "paleGold")
rewardText:SetPoint("TOPRIGHT", zoneBar, "BOTTOMRIGHT", -2, -5)
rewardText:SetJustifyH("RIGHT")

local hereButton = W.ToggleButton(header, "Back to my zone", 120, 20, function()
    page.zoneId = nil
    UI.OpenZone(nil)
end)
hereButton:SetPoint("LEFT", zoneSub, "RIGHT", 10, 0)
hereButton:Hide()

-- sparkles and pulse for a completed zone
local stars = {}
for i = 1, 3 do
    local s = header:CreateTexture(nil, "OVERLAY")
    s:SetTexture("Interface\\Cooldown\\star4")
    s:SetBlendMode("ADD")
    s:Hide()
    stars[i] = s
end
stars[1]:SetPoint("CENTER", pctText, "TOPLEFT", 4, -6)
stars[2]:SetPoint("CENTER", pctText, "BOTTOMRIGHT", -2, 8)
stars[3]:SetPoint("CENTER", zoneName, "TOPRIGHT", 0, -4)

header:SetScript("OnUpdate", function()
    if not this.complete then return end
    local t = GetTime()
    local pulse = (math.sin(t * 2.2) + 1) / 2
    this:SetBackdropBorderColor(0.85 + 0.15 * pulse, 0.68 + 0.16 * pulse, 0.25 + 0.2 * pulse)
    pctText:SetTextColor(1, 0.82 + 0.18 * pulse, 0.3 + 0.7 * pulse)
    for i, s in ipairs(stars) do
        local size = 26 + 18 * math.abs(math.sin(t * 1.3 + i * 2))
        s:SetWidth(size)
        s:SetHeight(size)
        s:SetAlpha(0.35 + 0.5 * math.abs(math.sin(t * 1.7 + i)))
    end
end)

local function UpdateHeader(z)
    local compact = AZC.db.compactHeader
    header:SetHeight(compact and HEADER_COMPACT or HEADER_FULL)
    zoneName:SetFont(AZC.FONT_TITLE, compact and 22 or 30, "")
    pctText:SetFont(AZC.FONT_TITLE, compact and 24 or 32, "")
    if compact then zoneSub:Hide() countText:Hide() rewardText:Hide() else zoneSub:Show() countText:Show() rewardText:Show() end
    zoneBar:ClearAllPoints()
    zoneBar:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 18, compact and 10 or 30)
    zoneBar:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", compact and -120 or -18, compact and 10 or 30)
    zoneBar:SetKnownWidth(UI.CONTENT_WIDTH - 18 - (compact and 120 or 18))

    if not z or not z.zone then
        zoneName:SetText(AZC.Upper(GetRealZoneText()))
        zoneSub:SetText("")
        pctText:SetText("")
        pctLabel:SetText("")
        countText:SetText("")
        rewardText:SetText("")
        zoneBar:SetProgress(0, 1)
        completeCheck:Hide()
        header.complete = false
        for _, s in ipairs(stars) do s:Hide() end
        hereButton:Hide()
        return
    end

    local zone = z.zone
    local pct = AZC.Num(zone.pct)
    local done, total = D.ZoneTotals(z)
    local complete = AZC.Bool(zone.done)

    zoneName:SetText(AZC.Upper(zone.n))
    local levels = ""
    if AZC.Num(zone.lmax) > 0 then levels = "Level " .. AZC.Num(zone.lmin) .. "-" .. AZC.Num(zone.lmax) end
    local here = AZC.Bool(zone.cur)
    zoneSub:SetText(levels .. (here and "    You are here" or ""))
    if here then hereButton:Hide() else hereButton:Show() end

    pctText:SetText(pct .. "%")
    zoneBar:SetProgress(done, total, complete)
    zoneBar:SetTicks(z.ms)
    countText:SetText(done .. " / " .. total .. " objectives completed")

    header.complete = complete
    if complete then
        pctLabel:SetText("ZONE COMPLETE")
        W.SetColor(pctLabel, "gold")
        completeCheck:Show()
        for _, s in ipairs(stars) do s:Show() end
    else
        pctLabel:SetText("COMPLETE")
        W.SetColor(pctLabel, "paleGold")
        pctText:SetTextColor(1, 1, 1)
        header:SetBackdropBorderColor(0.70, 0.56, 0.30)
        completeCheck:Hide()
        for _, s in ipairs(stars) do s:Hide() end
    end

    local nextMs = D.NextMilestone(z)
    if AZC.Bool(zone.earned) and not complete then
        rewardText:SetText(AZC.Color("gold", "Completed before") .. " - " .. AZC.Num(zone.new) .. " new objectives to find")
    elseif nextMs then
        local remaining = AZC.Num(nextMs.m) - pct
        rewardText:SetText("Next reward: " .. AZC.Num(nextMs.m) .. "%    " .. AZC.Color("white", remaining .. "% remaining"))
    elseif complete then
        rewardText:SetText(AZC.Color("gold", "Every milestone claimed"))
    else
        rewardText:SetText("")
    end
    LayoutArt()
end

-- ===========================================================================
-- filter bar

local filterBar = CreateFrame("Frame", nil, frame)
filterBar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
filterBar:SetWidth(LIST_WIDTH)
filterBar:SetHeight(24)

local filters = {}
local function SetFilter(key)
    page.filter = key
    for k, b in pairs(filters) do b:SetSelected(k == key) end
    page:Refresh()
end
local lastFilter
for _, def in ipairs({ { "all", "All" }, { "missing", "Missing" }, { "completed", "Completed" } }) do
    local key = def[1]
    local b = W.ToggleButton(filterBar, def[2], 96, 22, function() SetFilter(key) end)
    if lastFilter then b:SetPoint("LEFT", lastFilter, "RIGHT", 6, 0) else b:SetPoint("LEFT", filterBar, "LEFT", 0, 0) end
    lastFilter = b
    filters[key] = b
end
filters.all:SetSelected(true)

local expandAll = W.ToggleButton(filterBar, "Expand all", 84, 22, function()
    local anyClosed = false
    for _, key in ipairs(AZC.CATEGORIES) do if not page.expanded[key] then anyClosed = true end end
    for _, key in ipairs(AZC.CATEGORIES) do page.expanded[key] = anyClosed end
    page:Refresh()
end)
expandAll:SetPoint("RIGHT", filterBar, "RIGHT", 0, 0)

-- ===========================================================================
-- scrolling list

local listBack = CreateFrame("Frame", nil, frame)
listBack:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -6)
listBack:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
listBack:SetWidth(LIST_WIDTH)
W.Backdrop(listBack, "panel", 0.05, 0.045, 0.04, 0.96, 0.55, 0.45, 0.28)
W.Parchment(listBack, 0.17)

local list = W.VirtualScroll(listBack)
list:Anchor(listBack, 6, 6, 4, 6)
-- header + 8 gap + 24 filter bar + 6 gap above the list, 6 px inset top and bottom
function page.HeaderHeight() return AZC.db.compactHeader and HEADER_COMPACT or HEADER_FULL end
list:SetHeightFunc(function() return UI.CONTENT_HEIGHT - page.HeaderHeight() - 38 - 12 end)
local child = list.content
local ROW_WIDTH = LIST_WIDTH - 40

-- detail panel lives to the right of the list
page.detailAnchor = listBack

-- ---------------------------------------------------------------------------
-- row pool

local rows = {}
local used = 0
local lastUsed = 0

local function NewRow()
    local r = CreateFrame("Button", nil, child)
    r:SetWidth(ROW_WIDTH)
    r:RegisterForClicks("LeftButtonUp")

    r.arrow = r:CreateTexture(nil, "ARTWORK")
    r.arrow:SetWidth(14)
    r.arrow:SetHeight(14)

    r.iconFrame = W.FramedIcon(r, 26, nil)
    r.state = r:CreateTexture(nil, "ARTWORK")
    r.state:SetWidth(16)
    r.state:SetHeight(16)

    r.text = W.Text(r, 12, "white")
    r.right = W.Text(r, 12, "paleGold")
    r.right:SetJustifyH("RIGHT")
    r.sub = W.Text(r, 11, "grey")
    r.sub:SetJustifyV("TOP")

    r.bar = W.ProgressBar(r, 10)

    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    r.hl:SetBlendMode("ADD")
    r.hl:SetAllPoints(r)
    r.hl:SetAlpha(0.35)

    r.sel = r:CreateTexture(nil, "BACKGROUND")
    r.sel:SetTexture(0.9, 0.7, 0.25, 0.16)
    r.sel:SetAllPoints(r)

    r:SetScript("OnClick", function() if this.onClick then this.onClick(this) end end)
    r:SetScript("OnEnter", function() if this.tooltip then
        local t, lines = this.tooltip(this)
        if t then W.ShowTooltip(this, t, lines) end
    end end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

local function ResetRow(r)
    r:ClearAllPoints()
    r:SetBackdrop(nil)
    r.arrow:Hide()
    r.iconFrame:Hide()
    r.iconFrame:ClearAllPoints()
    r.iconFrame:SetWidth(32) r.iconFrame:SetHeight(32)
    r.iconFrame.icon:SetWidth(26) r.iconFrame.icon:SetHeight(26)
    r.arrow:ClearAllPoints()
    r.state:Hide()
    r.state:ClearAllPoints()
    r.state:SetTexCoord(0, 1, 0, 1)
    r.state:SetVertexColor(1, 1, 1)
    r.state:SetWidth(16)
    r.state:SetHeight(16)
    r.text:ClearAllPoints()
    r.right:ClearAllPoints()
    r.sub:ClearAllPoints()
    r.text:SetText("")
    r.right:SetText("")
    r.sub:SetText("")
    r.text:SetFont(AZC.FONT_BODY, 12, "")
    r.right:SetFont(AZC.FONT_BODY, 12, "")
    r.text:SetWidth(0)
    r.sub:SetWidth(0)
    r.bar:Hide()
    r.hl:Show()
    r.sel:Hide()
    r.onClick = nil
    r.tooltip = nil
    r.objId = nil
end

local y = 0
local function AddRow(height, indent)
    used = used + 1
    local r = rows[used]
    local fresh = false
    if not r then
        r = NewRow()
        rows[used] = r
        fresh = true
    end
    ResetRow(r)
    r:SetHeight(height)
    r:SetWidth(ROW_WIDTH - (indent or 0))
    r.vy = y
    -- rows that did not exist in the previous layout fade in; reused ones just update
    if fresh or used > lastUsed then r.fresh = true end
    list:Place(r, indent or 0, y, height)
    y = y + height
    return r
end

local function Gap(h) y = y + h end

-- ---------------------------------------------------------------------------
-- row kinds

local function StateIcon(r, kind)
    r.state:Show()
    if kind == "done" then
        r.state:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        r.state:SetWidth(20) r.state:SetHeight(20)
    elseif kind == "locked" then
        r.state:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        r.state:SetWidth(14) r.state:SetHeight(14)
        r.state:SetVertexColor(0.8, 0.6, 0.6)
    elseif kind == "next" then
        r.state:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    elseif kind == "active" then
        r.state:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
    elseif kind == "skull" then
        r.state:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
    elseif kind == "unknown" then
        r.state:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        r.state:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        r.state:SetWidth(14) r.state:SetHeight(14)
        r.state:SetVertexColor(0.7, 0.7, 0.7)
        return
    else
        r.state:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
        r.state:SetWidth(20) r.state:SetHeight(20)
    end
    r.state:SetTexCoord(0, 1, 0, 1)
end

local function CategoryRow(z, key, catRec, expandable)
    local info = AZC.CATEGORY_INFO[key]
    local r = AddRow(50)
    local done, total = AZC.Num(catRec.d), AZC.Num(catRec.tot)
    local complete = total > 0 and done >= total
    r:SetBackdrop(W.BACKDROPS.thin)
    r:SetBackdropColor(0.12, 0.10, 0.07, complete and 0.85 or 0.7)
    if complete then r:SetBackdropBorderColor(0.95, 0.78, 0.35) else r:SetBackdropBorderColor(0.45, 0.38, 0.24) end

    if expandable then
        r.arrow:SetTexture(page.expanded[key] and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
        r.arrow:SetPoint("LEFT", r, "LEFT", 8, 0)
        r.arrow:Show()
    end
    r.iconFrame.icon:SetTexture(info.icon)
    r.iconFrame:SetPoint("LEFT", r, "LEFT", expandable and 26 or 8, 0)
    r.iconFrame:Show()

    r.text:SetFont(AZC.FONT_TITLE, 16, "")
    W.SetColor(r.text, complete and "gold" or "paleGold")
    r.text:SetText(info.title)
    r.text:SetPoint("TOPLEFT", r.iconFrame, "TOPRIGHT", 10, -1)

    r.right:SetFont(AZC.FONT_TITLE, 16, "")
    W.SetColor(r.right, complete and "gold" or "white")
    r.right:SetText(done .. " / " .. total)
    r.right:SetPoint("TOPRIGHT", r, "TOPRIGHT", complete and -30 or -10, -8)
    if complete then
        StateIcon(r, "done")
        r.state:SetPoint("LEFT", r.right, "RIGHT", 2, 0)
    end

    r.bar:ClearAllPoints()
    r.bar:SetPoint("BOTTOMLEFT", r.iconFrame, "BOTTOMRIGHT", 10, 2)
    r.bar:SetPoint("RIGHT", r, "RIGHT", -10, 0)
    -- row width minus the icon column (arrow + 32 px icon + gap) and the right margin
    r.bar:SetKnownWidth(ROW_WIDTH - ((expandable and 26 or 8) + 32 + 10) - 10)
    r.bar:Show()
    r.bar:SetProgress(done, total, complete)

    r.tooltip = function()
        local lines = { { AZC.Num(catRec.pct) .. "% of this category", "white" } }
        if AZC.Num(catRec.w) > 0 then table.insert(lines, { "Worth " .. AZC.Num(catRec.w) .. "% of the zone", "grey" }) end
        if AZC.Num(catRec.bt) > 0 then
            table.insert(lines, { "Bonus: " .. AZC.Num(catRec.bd) .. " / " .. AZC.Num(catRec.bt) .. " (not required)", "paleGold" })
        end
        if expandable then table.insert(lines, { "Click to " .. (page.expanded[key] and "collapse" or "expand"), "paleGold" }) end
        return info.title, lines
    end
    if expandable then
        r.onClick = function()
            page.expanded[key] = not page.expanded[key]
            page:Refresh()
        end
    end
    Gap(4)
    return r
end

local function InfoRow(text, indent, color)
    local r = AddRow(20, indent or 30)
    r.hl:Hide()
    r.text:SetFont(AZC.FONT_BODY, 11, "")
    W.SetColor(r.text, color or "grey")
    r.text:SetText(text)
    r.text:SetPoint("LEFT", r, "LEFT", 4, 0)
    return r
end

local function ObjectiveTooltip(obj)
    return function()
        local name, hidden = D.DisplayName(obj)
        local info = AZC.CATEGORY_INFO[obj.c]
        local lines = { { info.title, "grey" } }
        if AZC.Bool(obj.d) then
            local when = AZC.FormatDate(obj.at)
            table.insert(lines, { "Completed" .. (when and (" on " .. when) or ""), "green" })
        elseif hidden then
            table.insert(lines, { "Not yet discovered", "grey" })
        else
            table.insert(lines, { "Not yet completed", "paleGold" })
        end
        if AZC.Bool(obj.b) then table.insert(lines, { "Bonus - " .. (AZC.BONUS_TEXT[obj.br] or "not required"), "blue" }) end
        if obj.an and obj.an ~= "" and not hidden then table.insert(lines, { "Near " .. obj.an, "parchment" }) end
        if obj.h and obj.h ~= "" then table.insert(lines, { obj.h, "parchment", true }) end
        if obj.c == "storylines" and obj.qt then table.insert(lines, { "Progress " .. AZC.Num(obj.qd) .. " / " .. AZC.Num(obj.qt), "white" }) end
        table.insert(lines, { "Click for details", "paleGold" })
        return name, lines
    end
end

local QuestBlock      -- forward

local function ObjectiveRow(z, obj, indent)
    local r = AddRow(22, indent or 30)
    local done = AZC.Bool(obj.d)
    local name, hidden = D.DisplayName(obj)
    r.objId = obj.id
    if page.selected == obj.id then r.sel:Show() end

    if done then
        StateIcon(r, "done")
    elseif hidden then
        StateIcon(r, "unknown")
    elseif obj.c == "elites" then
        StateIcon(r, "skull")
    else
        StateIcon(r, "open")
    end
    r.state:SetPoint("LEFT", r, "LEFT", 2, 0)

    r.text:SetPoint("LEFT", r, "LEFT", 26, 0)
    r.text:SetText(name)
    if obj.c == "elites" then
        r.text:SetFont(AZC.FONT_BODY, 12, "OUTLINE")
        W.SetColor(r.text, done and "paleGold" or "elite")
    elseif hidden then
        W.SetColor(r.text, "dim")
    else
        W.SetColor(r.text, done and "paleGold" or "white")
    end
    if AZC.Bool(obj.b) then r.text:SetText(name .. AZC.Color("blue", "  bonus")) end

    -- right side: storyline progress, level range for creatures
    if obj.c == "storylines" and obj.qt then
        r.right:SetText(AZC.Num(obj.qd) .. " / " .. AZC.Num(obj.qt))
        W.SetColor(r.right, done and "gold" or "paleGold")
        r.arrow:SetTexture(page.expandedStory[AZC.Num(string.sub(obj.id, 11))] and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
        r.arrow:SetPoint("RIGHT", r, "RIGHT", -2, 0)
        r.arrow:Show()
        r.right:SetPoint("RIGHT", r.arrow, "LEFT", -6, 0)
    elseif (obj.c == "rares" or obj.c == "elites") and AZC.Num(obj.lmax) > 0 and not hidden then
        local lv = AZC.Num(obj.lmin) == AZC.Num(obj.lmax) and AZC.Num(obj.lmax) or (AZC.Num(obj.lmin) .. "-" .. AZC.Num(obj.lmax))
        r.right:SetText("Level " .. lv)
        W.SetColor(r.right, "grey")
        r.right:SetPoint("RIGHT", r, "RIGHT", -6, 0)
    elseif done and obj.at then
        local when = AZC.FormatDate(obj.at)
        if when then
            r.right:SetFont(AZC.FONT_BODY, 10, "")
            r.right:SetText(when)
            W.SetColor(r.right, "dim")
            r.right:SetPoint("RIGHT", r, "RIGHT", -6, 0)
        end
    end

    r.tooltip = ObjectiveTooltip(obj)
    r.onClick = function()
        page.selected = obj.id
        if obj.c == "storylines" then
            local sid = AZC.Num(string.sub(obj.id, 11))
            page.expandedStory[sid] = not page.expandedStory[sid]
            AZC.Detail.ShowStoryline(sid, page.zoneId)
        else
            AZC.Detail.ShowObjective(obj, page.zoneId)
        end
        page:Refresh()
    end

    if obj.c == "storylines" then
        local sid = AZC.Num(string.sub(obj.id, 11))
        if page.expandedStory[sid] then QuestBlock(sid, obj) end
    end
    return r
end

-- The quests of an expanded storyline, then a NEXT QUEST / LOCKED box.
QuestBlock = function(sid, obj)
    local s = D.stories[sid]
    if not s then
        if D.HasFailed("story:" .. sid) then
            InfoRow("Could not load this storyline.", 56, "red")
        else
            InfoRow("Unrolling the story...", 56)
            D.RequestStory(sid)
        end
        return
    end
    local nextId = AZC.Num(s.story.nx)
    local part = 0
    for _, loopId in ipairs(s.order) do
        -- Lua 5.0: closures made in a loop share the loop variable (nil after the loop), so copy it
        local qid = loopId
        local q = s.quests[qid]
        if q and q.st ~= "na" then
            local counted = AZC.Bool(q.cnt)
            if counted then part = part + 1 end
            local r = AddRow(19, 52)
            local key = "quest:" .. qid
            r.objId = key
            if page.selected == key then r.sel:Show() end
            if q.st == "done" then StateIcon(r, "done")
            elseif q.st == "active" then StateIcon(r, "active")
            elseif qid == nextId or q.st == "available" then StateIcon(r, "next")
            else StateIcon(r, "locked") end
            r.state:SetPoint("LEFT", r, "LEFT", 0, 0)
            r.text:SetPoint("LEFT", r, "LEFT", 22, 0)
            r.text:SetFont(AZC.FONT_BODY, 11, "")
            local label = counted and (part .. ". " .. q.n) or q.n
            r.text:SetText(label)
            if qid == nextId and q.st ~= "done" then
                W.SetColor(r.text, "gold")
            elseif q.st == "done" then
                W.SetColor(r.text, "paleGold")
            elseif counted then
                W.SetColor(r.text, "white")
            else
                W.SetColor(r.text, "dim")
            end
            r.right:SetFont(AZC.FONT_BODY, 10, "")
            r.right:SetPoint("RIGHT", r, "RIGHT", -4, 0)
            if not counted then
                r.right:SetText(AZC.OPTIONAL_TEXT[q.optr] or "Optional")
                W.SetColor(r.right, "dim")
            elseif q.st == "active" then
                r.right:SetText("In progress")
                W.SetColor(r.right, "green")
            elseif q.st == "blocked" then
                r.right:SetText(q.why == "LEVEL_TOO_LOW" and ("Level " .. AZC.Num(q.ml)) or "Locked")
                W.SetColor(r.right, "grey")
            end
            r.tooltip = function()
                local lines = { { AZC.STATE_TEXT[q.st] or "", q.st == "done" and "green" or "white" } }
                local why = AZC.ReasonText(q, s)
                if why and q.st ~= "done" then table.insert(lines, { why, "red", true }) end
                if q.g_n and q.st ~= "done" and q.st ~= "active" then table.insert(lines, { "Starts: " .. q.g_n .. (q.g_an and (", " .. q.g_an) or ""), "parchment" }) end
                if q.st == "active" and q.e_n then table.insert(lines, { "Turn in: " .. q.e_n .. (q.e_an and (", " .. q.e_an) or ""), "parchment" }) end
                table.insert(lines, { "Click for details", "paleGold" })
                return q.n, lines
            end
            r.onClick = function()
                page.selected = key
                AZC.Detail.ShowQuest(sid, qid, page.zoneId)
                page:Refresh()
            end
        end
    end

    -- NEXT QUEST / LOCKED box
    local nq = s.quests[nextId]
    if nq and nq.st ~= "done" then
        local lines = {}
        local title, color
        if nq.st == "blocked" then
            title, color = "LOCKED", "red"
            table.insert(lines, AZC.Color("paleGold", nq.n))
            table.insert(lines, AZC.Color("grey", "Reason: ") .. (AZC.ReasonText(nq, s) or "Not available yet"))
        elseif nq.st == "active" then
            title, color = "IN PROGRESS", "green"
            table.insert(lines, AZC.Color("white", nq.n))
            if nq.e_n then table.insert(lines, AZC.Color("grey", "Turn in to: ") .. nq.e_n .. (nq.e_an and AZC.Color("grey", ", " .. nq.e_an) or "")) end
        else
            title, color = "NEXT QUEST", "gold"
            table.insert(lines, AZC.Color("white", nq.n))
            if nq.g_n then table.insert(lines, AZC.Color("grey", "Starts from: ") .. nq.g_n .. (nq.g_an and AZC.Color("grey", ", " .. nq.g_an) or "")) end
            if AZC.Num(nq.ml) > 1 then table.insert(lines, AZC.Color("grey", "Required level: ") .. AZC.Num(nq.ml)) end
        end
        local height = 26 + 15 * table.getn(lines)
        local r = AddRow(height, 52)
        r:SetBackdrop(W.BACKDROPS.thin)
        r:SetBackdropColor(0.10, 0.08, 0.05, 0.85)
        if color == "red" then r:SetBackdropBorderColor(0.7, 0.3, 0.25) else r:SetBackdropBorderColor(0.8, 0.65, 0.3) end
        r.text:SetFont(AZC.FONT_BODY, 10, "OUTLINE")
        W.SetColor(r.text, color)
        r.text:SetText(title)
        r.text:SetPoint("TOPLEFT", r, "TOPLEFT", 10, -7)
        r.sub:SetFont(AZC.FONT_BODY, 11, "")
        W.SetColor(r.sub, "parchment")
        r.sub:SetText(table.concat(lines, "\n"))
        r.sub:SetPoint("TOPLEFT", r.text, "BOTTOMLEFT", 0, -4)
        r.sub:SetWidth(ROW_WIDTH - 72)
        r.onClick = function()
            page.selected = "quest:" .. nextId
            AZC.Detail.ShowQuest(sid, nextId, page.zoneId)
            page:Refresh()
        end
        Gap(4)
    end
    Gap(4)
end

-- ===========================================================================
-- the three views

local function CategoryObjects(z, key, onlyDone)
    local list = z.objs[key]
    if not list then return nil end
    local out = {}
    for _, obj in ipairs(list) do
        if onlyDone == nil or AZC.Bool(obj.d) == onlyDone then table.insert(out, obj) end
    end
    return out
end

local function ViewAll(z, onlyDone)
    local any = false
    for _, key in ipairs(AZC.CATEGORIES) do
        local c = z.cats[key]
        if c and AZC.Bool(c.vis) then
            any = true
            CategoryRow(z, key, c, true)
            if page.expanded[key] then
                local list = CategoryObjects(z, key, onlyDone)
                if not list then
                    local loadKey = "cat:" .. page.zoneId .. ":" .. key
                    if D.HasFailed(loadKey) then
                        InfoRow("Could not load this category.", 30, "red")
                    else
                        InfoRow("Consulting the journal...", 30)
                        D.RequestCategory(page.zoneId, key)
                    end
                elseif table.getn(list) == 0 then
                    InfoRow(onlyDone and "Nothing completed here yet." or "Nothing here.", 30)
                else
                    for _, obj in ipairs(list) do ObjectiveRow(z, obj, 30) end
                end
                Gap(8)
            end
        end
    end
    if not any then InfoRow("There is nothing for you to complete in this zone.", 10) end
end

local function ViewMissing(z)
    local m = z.missing
    if not m then
        if D.HasFailed("missing:" .. page.zoneId) then
            InfoRow("Could not load what is missing.", 10, "red")
        else
            InfoRow("Looking for what remains...", 10)
            D.RequestMissing(page.zoneId)
        end
        return
    end
    local r = AddRow(30, 0)
    r.hl:Hide()
    r.text:SetFont(AZC.FONT_TITLE, 18, "")
    W.SetColor(r.text, "gold")
    r.text:SetText(AZC.Upper((z.zone and z.zone.n) or "") .. " - MISSING")
    r.text:SetPoint("LEFT", r, "LEFT", 6, 0)

    local any = false
    for _, key in ipairs(AZC.CATEGORIES) do
        local list = m.objs[key]
        if list and table.getn(list) > 0 then
            any = true
            local info = AZC.CATEGORY_INFO[key]
            local h = AddRow(28, 0)
            h.hl:Hide()
            h.iconFrame.icon:SetTexture(info.icon)
            h.iconFrame:SetWidth(22) h.iconFrame:SetHeight(22)
            h.iconFrame.icon:SetWidth(16) h.iconFrame.icon:SetHeight(16)
            h.iconFrame:SetPoint("LEFT", h, "LEFT", 6, 0)
            h.iconFrame:Show()
            h.text:SetFont(AZC.FONT_TITLE, 15, "")
            W.SetColor(h.text, "paleGold")
            h.text:SetText(info.title)
            h.text:SetPoint("LEFT", h.iconFrame, "RIGHT", 8, 0)
            local cat = m.cats[key]
            if cat then
                h.right:SetText(AZC.Num(cat.tot) - AZC.Num(cat.d) .. " left")
                W.SetColor(h.right, "grey")
                h.right:SetPoint("RIGHT", h, "RIGHT", -6, 0)
            end

            local hiddenCount = 0
            for _, obj in ipairs(list) do
                local _, hidden = D.DisplayName(obj)
                if hidden then
                    hiddenCount = hiddenCount + 1
                else
                    ObjectiveRow(z, obj, 18)
                    if key == "storylines" and obj.nxn and obj.nxn ~= "" and not page.expandedStory[AZC.Num(string.sub(obj.id, 11))] then
                        local where
                        if obj.nxs == "active" then
                            where = "In progress: " .. obj.nxn .. (obj.e_n and (" - turn in to " .. obj.e_n) or "")
                        elseif obj.nxs == "blocked" then
                            local fake = { why = obj.why, ml = obj.ml, mp = obj.mp }
                            where = "Next: " .. obj.nxn .. " - " .. (AZC.ReasonText(fake, nil) or "locked")
                        else
                            where = "Next: " .. obj.nxn .. (obj.g_n and (" - starts at " .. obj.g_n) or "") .. (obj.g_an and (", " .. obj.g_an) or "")
                        end
                        InfoRow(where, 46, obj.nxs == "blocked" and "grey" or "parchment")
                    end
                end
            end
            if hiddenCount > 0 then
                local noun = AZC.CATEGORY_INFO[key].single
                InfoRow(hiddenCount .. " undiscovered " .. noun .. (hiddenCount > 1 and "s" or ""), 44, "dim")
            end
            Gap(6)
        end
    end
    if not any then
        local done = AddRow(60, 0)
        done.hl:Hide()
        done.text:SetFont(AZC.FONT_TITLE, 17, "")
        W.SetColor(done.text, "gold")
        done.text:SetText("Nothing missing. This zone is yours.")
        done.text:SetPoint("CENTER", done, "CENTER", 0, 0)
    end
end

-- ===========================================================================
-- page api

local function FinishList()
    for i = used + 1, lastUsed do rows[i]:Hide() end
    lastUsed = used
    list:Finish(y + 10)
end

function page:Layout()
    list:Begin()
    used = 0
    y = 4

    local z = self.zoneId and D.Zone(self.zoneId)
    UpdateHeader(z)
    filterBar:ClearAllPoints()
    filterBar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)

    if not AZC.Protocol.IsReady() then
        FinishList()
        return
    end
    if not self.zoneId then
        if D.HasFailed("zone:0:0") then
            InfoRow((GetRealZoneText() or "This place") .. " has no completion journal.", 10, "paleGold")
            InfoRow("Open the Azeroth tab to browse the zones of the world.", 10)
        else
            InfoRow("Consulting the journal...", 10)
        end
        FinishList()
        return
    end
    if not z or not z.zone then
        InfoRow("Consulting the journal...", 10)
        D.RequestZone(self.zoneId, false)
        FinishList()
        return
    end

    if self.filter == "missing" then
        ViewMissing(z)
    elseif self.filter == "completed" then
        if not z.full then
            InfoRow("Gathering your accomplishments...", 10)
            D.RequestZone(self.zoneId, true)
        else
            ViewAll(z, true)
        end
    else
        ViewAll(z, nil)
    end
    FinishList()

    -- bring a focused objective into view
    if self.focus then
        for i = 1, used do
            local r = rows[i]
            if r.objId == self.focus then
                list:ScrollTo(r.vy - 60)
                self.focus = nil
                break
            end
        end
    end
end

function page:Refresh()
    -- resolve "the current zone" once the server has told us which it is
    if self.followCurrent then self.zoneId = D.currentZoneId end
    if self.zoneId and not D.Zone(self.zoneId) then D.RequestZone(self.zoneId, false) end
    self:Layout()
    AZC.Detail.Refresh()
end

function page:Show(params)
    local wanted = params.zoneId
    self.followCurrent = (wanted == nil)
    local newZone = wanted or D.currentZoneId
    if newZone ~= self.zoneId then
        self.selected = nil
        self.expandedStory = {}
        list:Reset()
    end
    self.zoneId = newZone
    if not self.zoneId and AZC.Protocol.IsReady() then D.RequestZone(0, false) end

    -- jump to an objective (from search or a notification)
    if params.focus then
        local focus = params.focus
        self.filter = "all"
        for k, b in pairs(filters) do b:SetSelected(k == "all") end
        local cat
        local prefix = string.gsub(focus, ":.*$", "")
        if prefix == "storyline" or prefix == "quest" then cat = "storylines"
        elseif prefix == "exploration" then cat = "exploration"
        elseif prefix == "rare" then cat = "rares"
        elseif prefix == "elite" then cat = "elites"
        elseif prefix == "travel" then cat = "travel" end
        if cat then self.expanded[cat] = true end
        if prefix == "storyline" then
            local sid = AZC.Num(string.sub(focus, 11))
            self.expandedStory[sid] = true
            if params.quest then
                self.selected = "quest:" .. params.quest
                self.focus = self.selected
                AZC.Detail.ShowQuest(sid, params.quest, self.zoneId)
            else
                self.selected = focus
                self.focus = focus
                AZC.Detail.ShowStoryline(sid, self.zoneId)
            end
        else
            self.selected = focus
            self.focus = focus
            AZC.Detail.ShowObjectiveId(focus, self.zoneId)
        end
    elseif not params.keepDetail then
        AZC.Detail.ShowRewards(self.zoneId)
    end

    local name = self.zoneId and D.Zone(self.zoneId) and D.Zone(self.zoneId).zone and D.Zone(self.zoneId).zone.n or GetRealZoneText()
    UI.SetBreadcrumbs({
        { label = "Azeroth", fn = function() UI.Navigate("azeroth", {}) end },
        { label = name or "Zone" },
    })
    self:Refresh()
end

-- keep the breadcrumb label in step once the zone arrives
AZC.On("DataChanged", function(kind, zoneId)
    if kind == "zone" and frame:IsShown() and page.zoneId == zoneId then
        local z = D.Zone(zoneId)
        if z and z.zone then
            UI.SetBreadcrumbs({
                { label = "Azeroth", fn = function() UI.Navigate("azeroth", {}) end },
                { label = z.zone.n },
            })
        end
    end
end)

-- the player walked into another zone while looking at "their" zone
AZC.On("ZoneChanged", function()
    if frame:IsShown() and page.followCurrent then
        page.selected = nil
        page.expandedStory = {}
    end
end)

AZC.ZonePage = page
UI.Register("zone", page)
