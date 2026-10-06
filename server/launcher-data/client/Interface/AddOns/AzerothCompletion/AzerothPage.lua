-- Azeroth Completion: completion across every zone, by region and by continent.

local AZC = AZC
local W = AZC.W
local D = AZC.Data
local UI = AZC.UI

local page = {}
local frame = CreateFrame("Frame", nil, UIParent)
page.frame = frame

local CONTINENTS = {
    { map = 0, name = "Eastern Kingdoms" },
    { map = 1, name = "Kalimdor" },
}

local back = CreateFrame("Frame", nil, frame)
back:SetAllPoints(frame)
W.Backdrop(back, "panel", 0.05, 0.045, 0.04, 0.97, 0.6, 0.48, 0.3)
W.Parchment(back, 0.2)

local title = W.Text(frame, 26, "gold", AZC.FONT_TITLE)
title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -14)
title:SetText("Azeroth")

local summary = W.Text(frame, 12, "paleGold")
summary:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 2, -2)

local worldPct = W.Text(frame, 28, "white", AZC.FONT_TITLE)
worldPct:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -12)
worldPct:SetJustifyH("RIGHT")

local view = W.VirtualScroll(frame)
view:Anchor(frame, 12, 66, 6, 10)
view:SetHeightFunc(function() return UI.CONTENT_HEIGHT - 66 - 10 end)
local child = view.content

local COL_WIDTH = 348

local rows, used = {}, 0
local headers = {}

local function Row()
    used = used + 1
    local r = rows[used]
    if not r then
        r = CreateFrame("Button", nil, child)
        r:SetHeight(24)
        r:SetWidth(COL_WIDTH)
        r.fill = r:CreateTexture(nil, "BACKGROUND")
        r.fill:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -2)
        r.fill:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 2)
        r.marker = r:CreateTexture(nil, "ARTWORK")
        r.marker:SetWidth(14)
        r.marker:SetHeight(14)
        r.marker:SetPoint("LEFT", r, "LEFT", 4, 0)
        r.name = W.Text(r, 13, "white")
        r.name:SetPoint("LEFT", r, "LEFT", 24, 0)
        r.levels = W.Text(r, 10, "dim")
        r.levels:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
        r.pct = W.Text(r, 14, "white", AZC.FONT_TITLE)
        r.pct:SetPoint("RIGHT", r, "RIGHT", -26, 0)
        r.pct:SetJustifyH("RIGHT")
        r.check = r:CreateTexture(nil, "ARTWORK")
        r.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        r.check:SetWidth(20)
        r.check:SetHeight(20)
        r.check:SetPoint("RIGHT", r, "RIGHT", -2, 0)
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        hl:SetBlendMode("ADD")
        hl:SetAllPoints(r)
        hl:SetAlpha(0.4)
        r:SetScript("OnClick", function() UI.OpenZone(this.zoneId) end)
        r:SetScript("OnEnter", function()
            local z = this.rec
            local lines = {
                { AZC.Num(z.pct) .. "% complete", "white" },
                { AZC.Num(z.d) .. " / " .. AZC.Num(z.tot) .. " objectives", "grey" },
            }
            if AZC.Num(z.lmax) > 0 then table.insert(lines, { "Level " .. AZC.Num(z.lmin) .. "-" .. AZC.Num(z.lmax), "grey" }) end
            if AZC.Bool(z.earned) then table.insert(lines, { "Zone complete", "gold" }) end
            table.insert(lines, { "Click to open", "paleGold" })
            W.ShowTooltip(this, z.n, lines)
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[used] = r
    end
    r:Show()
    return r
end

-- ---------------------------------------------------------------------------
-- regions: groups of zones with a reward for completing all of them

local REGION_WIDTH = COL_WIDTH * 2 + 20
local REGION_HEIGHT = 66
local REWARD_ICON = 26
local cards, usedCards = {}, 0
local regionTitle

local function ZoneLines(region)
    local lines = {}
    if region.desc and region.desc ~= "" then
        table.insert(lines, { region.desc, "parchment", true })
        table.insert(lines, "")
    end
    for _, rz in ipairs(region.zones) do
        if AZC.Bool(rz.app) then
            local done = AZC.Bool(rz.earned)
            table.insert(lines, { left = rz.zn, right = done and "Complete" or (AZC.Num(rz.pct) .. "%"),
                leftColor = done and "gold" or "white", rightColor = done and "gold" or "grey" })
        end
    end
    local skipped = 0
    for _, rz in ipairs(region.zones) do
        if not AZC.Bool(rz.app) then skipped = skipped + 1 end
    end
    if skipped > 0 then
        table.insert(lines, "")
        table.insert(lines, { skipped .. (skipped == 1 and " zone has" or " zones have") .. " nothing for you and do not count.", "dim", true })
    end
    if region.rw and region.rw ~= "" then
        table.insert(lines, "")
        table.insert(lines, { (AZC.Bool(region.earned) and "Rewarded: " or "Reward: ") .. region.rw, "paleGold", true })
    end
    return lines
end

local function Card()
    usedCards = usedCards + 1
    local c = cards[usedCards]
    if not c then
        c = CreateFrame("Button", nil, child)
        c:SetWidth(REGION_WIDTH)
        c:SetHeight(REGION_HEIGHT - 6)
        W.Backdrop(c, "thin", 0.08, 0.07, 0.05, 0.85, 0.5, 0.4, 0.25)
        c.icon = W.FramedIcon(c, 34, nil)
        c.icon:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -6)
        c.check = c:CreateTexture(nil, "OVERLAY")
        c.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        c.check:SetWidth(22)
        c.check:SetHeight(22)
        c.check:SetPoint("BOTTOMRIGHT", c.icon, "BOTTOMRIGHT", 6, -6)
        c.name = W.Text(c, 15, "white", AZC.FONT_TITLE)
        c.name:SetPoint("TOPLEFT", c, "TOPLEFT", 54, -6)
        c.count = W.Text(c, 11, "grey")
        c.count:SetPoint("LEFT", c.name, "RIGHT", 10, 0)
        c.desc = W.Text(c, 10, "grey")
        c.desc:SetPoint("TOPLEFT", c, "TOPLEFT", 54, -25)
        c.desc:SetWidth(400)
        c.desc:SetJustifyH("LEFT")
        c.bar = W.ProgressBar(c, 10)
        c.bar:SetPoint("TOPLEFT", c, "TOPLEFT", 54, -42)
        c.bar:SetWidth(400)
        c.bar:SetKnownWidth(400)
        c.reward = W.Text(c, 10, "paleGold")
        c.reward:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -6)
        c.reward:SetJustifyH("RIGHT")
        c.reward:SetWidth(230)
        c.items = {}
        local hl = c:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        hl:SetBlendMode("ADD")
        hl:SetAllPoints(c)
        hl:SetAlpha(0.25)
        c:SetScript("OnEnter", function()
            local region = this.region
            if region then W.ShowTooltip(this, region.n, ZoneLines(region)) end
        end)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
        cards[usedCards] = c
    end
    c:Show()
    return c
end

-- Fills a region card; items are "id:count,id:count".
local function FillCard(c, region)
    c.region = region
    local done, total = AZC.Num(region.d), AZC.Num(region.tot)
    local earned = AZC.Bool(region.earned)
    c.icon.icon:SetTexture((region.icon and region.icon ~= "") and region.icon or "Interface\\Icons\\INV_Misc_Map_01")
    if earned then c.check:Show() else c.check:Hide() end
    c.name:SetText(region.n)
    W.SetColor(c.name, earned and "gold" or "white")
    if earned then
        local when = AZC.FormatDate(region.at)
        c.count:SetText(AZC.Color("gold", "Complete") .. (when and ("  " .. when) or ""))
    else
        c.count:SetText(done .. " / " .. total .. " zones")
    end
    c.desc:SetText(region.desc or "")
    c.bar:SetProgress(done, total, earned)
    if earned then c:SetBackdropBorderColor(0.95, 0.78, 0.3) else c:SetBackdropBorderColor(0.5, 0.4, 0.25) end

    for _, b in ipairs(c.items) do b:Hide() end
    local n = 0
    for _, part in ipairs(AZC.Split(region.it or "", ",")) do
        local _, _, id, count = string.find(part, "^(%d+):(%d+)$")
        if id then
            n = n + 1
            local b = c.items[n]
            if not b then
                b = W.ItemButton(c, REWARD_ICON)
                c.items[n] = b
            end
            b:ClearAllPoints()
            b:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -8 - (n - 1) * (REWARD_ICON + 10), 5)
            b:SetItem(tonumber(id), tonumber(count))
            b:Show()
        end
    end
    -- what is not an item (gold, a title) as text above the icons
    local extra = region.rx or ""
    if extra == "" and n == 0 then extra = region.rw or "" end
    c.reward:SetText(extra)
    W.SetColor(c.reward, earned and "dim" or "paleGold")
end

-- Places the region cards from the top; returns the height they take.
local function PlaceRegions()
    for i = 1, usedCards do cards[i]:Hide() end
    usedCards = 0
    if not regionTitle then
        regionTitle = W.Text(child, 17, "gold", AZC.FONT_TITLE)
    end
    local regions = D.regions
    if not regions then
        if AZC.Protocol.IsReady() and not D.IsLoading("regions") and not D.HasFailed("regions") then D.RequestRegions() end
        regionTitle:Hide()
        return 0
    end
    if table.getn(regions) == 0 then
        regionTitle:Hide()
        return 0
    end
    local completed = 0
    for _, r in ipairs(regions) do
        if AZC.Bool(r.earned) then completed = completed + 1 end
    end
    regionTitle:SetText("REGIONS   " .. AZC.Color("paleGold", completed .. " of " .. table.getn(regions) .. " complete"))
    view:Place(regionTitle, 4, 0, 24)
    local yy = 26
    for _, region in ipairs(regions) do
        local c = Card()
        c:ClearAllPoints()
        view:Place(c, 0, yy, REGION_HEIGHT - 6)
        FillCard(c, region)
        yy = yy + REGION_HEIGHT
    end
    return yy + 14
end

local function Header(i)
    local h = headers[i]
    if not h then
        h = CreateFrame("Frame", nil, child)
        h:SetWidth(COL_WIDTH)
        h:SetHeight(58)
        h.title = W.Text(h, 17, "gold", AZC.FONT_TITLE)
        h.title:SetPoint("TOPLEFT", h, "TOPLEFT", 4, -2)
        h.pct = W.Text(h, 17, "white", AZC.FONT_TITLE)
        h.pct:SetPoint("TOPRIGHT", h, "TOPRIGHT", -4, -2)
        h.pct:SetJustifyH("RIGHT")
        h.bar = W.ProgressBar(h, 14)
        h.bar:SetPoint("TOPLEFT", h, "TOPLEFT", 2, -26)
        h.bar:SetPoint("TOPRIGHT", h, "TOPRIGHT", -2, -26)
        h.bar:SetKnownWidth(COL_WIDTH - 4)
        h.foot = W.Text(h, 10, "grey")
        h.foot:SetPoint("TOPLEFT", h.bar, "BOTTOMLEFT", 2, -3)
        headers[i] = h
    end
    h:Show()
    return h
end

function page:Refresh()
    view:Begin()
    for i = 1, used do rows[i]:Hide() end
    used = 0
    for _, h in ipairs(headers) do h:Hide() end

    local p = D.progress
    if not p then
        summary:SetText("Gathering the world...")
        worldPct:SetText("")
        if AZC.Protocol.IsReady() and not D.IsLoading("progress") and not D.HasFailed("progress") then D.RequestProgress() end
        view:Finish(0)
        return
    end

    local base = PlaceRegions()
    local currentZone = p.cur and AZC.Num(p.cur.z) or 0
    local allPct, allCount, completed = 0, 0, 0
    local maxHeight = 0
    local columns = {}
    for _, cont in ipairs(CONTINENTS) do columns[cont.map] = {} end
    local others = {}
    for _, z in ipairs(p.zones) do
        local list = columns[AZC.Num(z.map)] or others
        table.insert(list, z)
        allPct = allPct + AZC.Num(z.pct)
        allCount = allCount + 1
        if AZC.Bool(z.earned) then completed = completed + 1 end
    end

    local columnDefs = {}
    for _, cont in ipairs(CONTINENTS) do table.insert(columnDefs, { name = cont.name, zones = columns[cont.map] }) end
    if table.getn(others) > 0 then table.insert(columnDefs, { name = "Other Lands", zones = others }) end

    for ci, col in ipairs(columnDefs) do
        table.sort(col.zones, function(a, b)
            local la, lb = AZC.Num(a.lmin), AZC.Num(b.lmin)
            if la ~= lb then return la < lb end
            return a.n < b.n
        end)
        local x = math.mod(ci - 1, 2) * (COL_WIDTH + 20)
        local top = base + math.floor((ci - 1) / 2) * (maxHeight + 20)
        local h = Header(ci)
        h:ClearAllPoints()
        view:Place(h, x, top, h:GetHeight())
        local sum, done = 0, 0
        for _, z in ipairs(col.zones) do
            sum = sum + AZC.Num(z.pct)
            if AZC.Bool(z.earned) then done = done + 1 end
        end
        local count = table.getn(col.zones)
        local avg = count > 0 and math.floor(sum / count) or 0
        h.title:SetText(AZC.Upper(col.name))
        h.pct:SetText(avg .. "%")
        h.bar:SetProgress(avg, 100, avg >= 100)
        h.foot:SetText(col.name .. " completion: " .. avg .. "%    " .. done .. " of " .. count .. " zones complete")

        local yy = top + 62
        for _, z in ipairs(col.zones) do
            local r = Row()
            r.zoneId = AZC.Num(z.id)
            r.rec = z
            r:ClearAllPoints()
            view:Place(r, x, yy, r:GetHeight())
            local pct = AZC.Num(z.pct)
            local earned = AZC.Bool(z.earned)
            r.name:SetText(z.n)
            W.SetColor(r.name, earned and "gold" or (pct > 0 and "white" or "grey"))
            r.levels:SetText(AZC.Num(z.lmax) > 0 and (AZC.Num(z.lmin) .. "-" .. AZC.Num(z.lmax)) or "")
            r.pct:SetText(pct .. "%")
            W.SetColor(r.pct, earned and "gold" or (pct > 0 and "white" or "dim"))
            if earned then r.check:Show() else r.check:Hide() end
            r.fill:SetWidth(math.max(1, (COL_WIDTH - 4) * pct / 100))
            if earned then r.fill:SetTexture(0.85, 0.65, 0.2, 0.22) else r.fill:SetTexture(0.75, 0.55, 0.2, 0.12) end
            if r.zoneId == currentZone then
                r.marker:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
                r.marker:Show()
            else
                r.marker:Hide()
            end
            yy = yy + 25
        end
        maxHeight = math.max(maxHeight, yy - top)
    end
    view:Finish(base + maxHeight * math.ceil(table.getn(columnDefs) / 2) + 20)

    local world = allCount > 0 and math.floor(allPct / allCount) or 0
    worldPct:SetText(world .. "%")
    summary:SetText(completed .. " of " .. allCount .. " zones complete")
end

function page:Show(params)
    UI.SetBreadcrumbs({ { label = "Azeroth" } })
    -- always fresh: other zones may have moved since we last looked
    if AZC.Protocol.IsReady() then
        D.RequestProgress()
        D.RequestRegions()
    end
    self:Refresh()
end

AZC.AzerothPage = page
UI.Register("azeroth", page)
