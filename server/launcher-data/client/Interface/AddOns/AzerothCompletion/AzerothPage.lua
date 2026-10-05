-- Azeroth Completion: completion across every zone, by continent.

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
        local top = math.floor((ci - 1) / 2) * (maxHeight + 20)
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
    view:Finish(maxHeight * math.ceil(table.getn(columnDefs) / 2) + 20)

    local world = allCount > 0 and math.floor(allPct / allCount) or 0
    worldPct:SetText(world .. "%")
    summary:SetText(completed .. " of " .. allCount .. " zones complete")
end

function page:Show(params)
    UI.SetBreadcrumbs({ { label = "Azeroth" } })
    -- always fresh: other zones may have moved since we last looked
    if AZC.Protocol.IsReady() then D.RequestProgress() end
    self:Refresh()
end

AZC.AzerothPage = page
UI.Register("azeroth", page)
