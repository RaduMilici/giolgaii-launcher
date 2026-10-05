-- Azeroth Completion: search results. The server searches, so nothing hidden leaks.

local AZC = AZC
local W = AZC.W
local D = AZC.Data
local UI = AZC.UI

local page = {}
local frame = CreateFrame("Frame", nil, UIParent)
page.frame = frame

local back = CreateFrame("Frame", nil, frame)
back:SetAllPoints(frame)
W.Backdrop(back, "panel", 0.05, 0.045, 0.04, 0.97, 0.6, 0.48, 0.3)
W.Parchment(back, 0.2)

local title = W.Text(frame, 22, "gold", AZC.FONT_TITLE)
title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -14)

local status = W.Text(frame, 12, "paleGold")
status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 2, -4)

local view = W.VirtualScroll(frame)
view:Anchor(frame, 12, 62, 6, 10)
view:SetHeightFunc(function() return UI.CONTENT_HEIGHT - 62 - 10 end)
local child = view.content

local KINDS = {
    { key = "zone",        title = "Zones",            icon = "Interface\\Icons\\INV_Misc_Map_01" },
    { key = "storyline",   title = "Storylines",       icon = AZC.CATEGORY_INFO.storylines.icon },
    { key = "quest",       title = "Quests",           icon = "Interface\\GossipFrame\\AvailableQuestIcon" },
    { key = "exploration", title = "Places",           icon = AZC.CATEGORY_INFO.exploration.icon },
    { key = "rare",        title = "Rare Hunts",       icon = AZC.CATEGORY_INFO.rares.icon },
    { key = "elite",       title = "Elite Encounters", icon = AZC.CATEGORY_INFO.elites.icon },
    { key = "travel",      title = "Flight Paths",     icon = AZC.CATEGORY_INFO.travel.icon },
}

local rows, used = {}, 0
local results = nil
local lastQuery = nil

local function Row()
    used = used + 1
    local r = rows[used]
    if not r then
        r = CreateFrame("Button", nil, child)
        r:SetHeight(22)
        r:SetWidth(700)
        r.icon = W.Icon(r, 18, nil)
        r.icon:SetPoint("LEFT", r, "LEFT", 4, 0)
        r.text = W.Text(r, 13, "white")
        r.text:SetPoint("LEFT", r, "LEFT", 30, 0)
        r.right = W.Text(r, 11, "grey")
        r.right:SetPoint("RIGHT", r, "RIGHT", -8, 0)
        r.right:SetJustifyH("RIGHT")
        r.hl = r:CreateTexture(nil, "HIGHLIGHT")
        r.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        r.hl:SetBlendMode("ADD")
        r.hl:SetAllPoints(r)
        r.hl:SetAlpha(0.4)
        r:SetScript("OnClick", function() if this.onClick then this.onClick() end end)
        rows[used] = r
    end
    r.onClick = nil
    r.hl:Show()
    r.icon:Show()
    r:Show()
    return r
end

local function Open(hit)
    local zoneId = AZC.Num(hit.z)
    if hit.k == "zone" then
        UI.OpenZone(zoneId)
    elseif hit.k == "quest" then
        UI.Navigate("zone", { zoneId = zoneId, focus = hit.id, quest = AZC.Num(hit.q) })
    else
        UI.OpenZone(zoneId, hit.id)
    end
end

function page:Refresh()
    view:Begin()
    for i = 1, used do rows[i]:Hide() end
    used = 0
    title:SetText("Search: " .. (lastQuery or ""))
    if not results then
        status:SetText("Searching the journal...")
        view:Finish(10)
        return
    end
    if results.error then
        status:SetText(results.error)
        view:Finish(10)
        return
    end
    local count = table.getn(results.hits)
    if count == 0 then
        status:SetText("Nothing in the journal matches. Undiscovered rares stay secret until you find them.")
        view:Finish(10)
        return
    end
    status:SetText(count .. (results.more and "+" or "") .. " results")

    local y = 0
    for _, kind in ipairs(KINDS) do
        local first = true
        for _, hit in ipairs(results.hits) do
            if hit.k == kind.key then
                if first then
                    first = false
                    local h = Row()
                    h.hl:Hide()
                    h.icon:SetTexture(kind.icon)
                    h.text:SetText(kind.title)
                    h.text:SetFont(AZC.FONT_TITLE, 15, "")
                    W.SetColor(h.text, "gold")
                    h.right:SetText("")
                    h:ClearAllPoints()
                    view:Place(h, 0, y, h:GetHeight())
                    y = y + 26
                end
                local r = Row()
                r.icon:Hide()
                r.text:SetFont(AZC.FONT_BODY, 13, "")
                W.SetColor(r.text, "white")
                r.text:SetText("   " .. hit.n)
                r.right:SetText(hit.k ~= "zone" and (hit.zn or "") or "")
                r:ClearAllPoints()
                view:Place(r, 0, y, r:GetHeight())
                local h = hit
                r.onClick = function() Open(h) end
                y = y + 22
            end
        end
        if not first then y = y + 8 end
    end
    view:Finish(y + 10)
end

function page:Show(params)
    UI.SetBreadcrumbs({
        { label = "Azeroth", fn = function() UI.Navigate("azeroth", {}) end },
        { label = "Search" },
    })
    if params.text ~= lastQuery or not results then
        lastQuery = params.text
        results = nil
        view:Reset()
        local query = params.text
        D.Search(query, function(records, err)
            if query ~= lastQuery then return end
            if not records or err then
                results = { error = (err and err.code == "QUERY_TOO_SHORT") and "Type at least two letters." or "The journal did not answer. Try again." }
            else
                results = { hits = {} }
                for _, rec in ipairs(records) do
                    if rec.type == "HIT" then table.insert(results.hits, rec)
                    elseif rec.type == "MORE" then results.more = true end
                end
            end
            if frame:IsShown() then page:Refresh() end
        end)
    end
    self:Refresh()
end

UI.Register("search", page)
