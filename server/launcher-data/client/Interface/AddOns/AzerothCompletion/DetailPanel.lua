-- Azeroth Completion: the side panel next to the zone list.
-- Shows the zone's rewards by default, or the details of a clicked objective, storyline or quest.

local AZC = AZC
local W = AZC.W
local D = AZC.Data

local P = {}
AZC.Detail = P

local zonePage = AZC.ZonePage
local panel = CreateFrame("Frame", nil, zonePage.frame)
panel:SetPoint("TOPLEFT", zonePage.detailAnchor, "TOPRIGHT", 8, 30)
panel:SetPoint("BOTTOMRIGHT", zonePage.frame, "BOTTOMRIGHT", 0, 0)
W.Backdrop(panel, "panel", 0.05, 0.045, 0.04, 0.97, 0.62, 0.50, 0.30)
W.Parchment(panel, 0.2)

local closeButton = CreateFrame("Button", "AzerothCompletionDetailClose", panel, "UIPanelCloseButton")
closeButton:SetWidth(26)
closeButton:SetHeight(26)
closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
closeButton:SetScript("OnClick", function()
    zonePage.selected = nil
    P.ShowRewards(P.zoneId)
    zonePage:Layout()
end)

local view = W.VirtualScroll(panel)
view:Anchor(panel, 10, 10, 4, 10)
-- the panel starts 30 px above the list, i.e. 8 px under the header; 10 px inset top and bottom
view:SetHeightFunc(function() return AZC.UI.CONTENT_HEIGHT - zonePage.HeaderHeight() - 8 - 20 end)
local child = view.content
local WIDTH = 236

-- ---------------------------------------------------------------------------
-- a tiny layout builder over pooled widgets

local texts, icons, bars, buttons, marks, items = {}, {}, {}, {}, {}, {}
local nMark, nItem = 0, 0
local nText, nIcon, nBar, nButton = 0, 0, 0, 0
local y = 0

local function Begin()
    for i = 1, nText do texts[i]:Hide() end
    for i = 1, nIcon do icons[i]:Hide() end
    for i = 1, nBar do bars[i]:Hide() end
    for i = 1, nButton do buttons[i]:Hide() end
    for i = 1, nMark do marks[i]:Hide() end
    for i = 1, nItem do items[i]:Hide() end
    nText, nIcon, nBar, nButton, nMark, nItem = 0, 0, 0, 0, 0, 0
    y = 2
    view:Begin()
end

local function End()
    view:Finish(y + 8)
end

local function Gap(h) y = y + (h or 8) end

local function Text(text, colorName, size, font, indent, flags)
    nText = nText + 1
    local fs = texts[nText]
    if not fs then
        fs = W.Text(child, 12, "white")
        fs:SetJustifyV("TOP")
        texts[nText] = fs
    end
    size = size or 12
    fs:SetFont(font or AZC.FONT_BODY, size, flags or "")
    W.SetColor(fs, colorName or "white")
    fs:SetWidth(WIDTH - (indent or 0))
    fs:SetText(text or "")
    local lineHeight = size + 3
    local h = W.WrappedHeight(fs, WIDTH - (indent or 0), lineHeight)
    -- explicit line breaks
    local _, breaks = string.gsub(text or "", "\n", "")
    h = h + breaks * lineHeight
    fs:SetHeight(h)
    view:Place(fs, indent or 0, y, h)
    y = y + h
    return fs
end

local function Heading(text)
    Gap(6)
    Text(AZC.Upper(text), "gold", 10, AZC.FONT_BODY, 0, "OUTLINE")
    Gap(2)
end

local function IconTitle(iconPath, title, subtitle, titleColor)
    nIcon = nIcon + 1
    local holder = icons[nIcon]
    if not holder then
        holder = W.FramedIcon(child, 34, nil)
        icons[nIcon] = holder
    end
    holder.icon:SetTexture(iconPath)
    view:Place(holder, 0, y, 40)
    local top = y
    nText = nText + 1
    local fs = texts[nText]
    if not fs then
        fs = W.Text(child, 12, "white")
        fs:SetJustifyV("TOP")
        texts[nText] = fs
    end
    fs:SetFont(AZC.FONT_TITLE, 17, "")
    W.SetColor(fs, titleColor or "gold")
    fs:SetWidth(WIDTH - 54)
    fs:SetText(title)
    local h = W.WrappedHeight(fs, WIDTH - 54, 20)
    fs:SetHeight(h)
    view:Place(fs, 48, top + 1, h)
    y = top + h + 2
    if subtitle then
        Text(subtitle, "grey", 11, nil, 48)
    end
    y = math.max(y, top + 44)
end

-- a line of text with a check box (done) or an empty box in front
local function CheckLine(done, text, colorName, size, font)
    nMark = nMark + 1
    local t = marks[nMark]
    if not t then
        t = child:CreateTexture(nil, "OVERLAY")
        marks[nMark] = t
    end
    t:SetTexture(done and "Interface\\Buttons\\UI-CheckBox-Check" or "Interface\\Buttons\\UI-CheckBox-Up")
    t:SetWidth(18)
    t:SetHeight(18)
    view:Place(t, -2, math.max(0, y - 2), 18)
    return Text(text, colorName, size, font, 18)
end

local function Bar(done, total, complete)
    nBar = nBar + 1
    local b = bars[nBar]
    if not b then
        b = W.ProgressBar(child, 14)
        b:SetWidth(WIDTH)
        b:SetKnownWidth(WIDTH)
        bars[nBar] = b
    end
    view:Place(b, 0, y, 14)
    b:SetProgress(done, total, complete)
    y = y + 18
end

local function Button(label, fn, colorName)
    nButton = nButton + 1
    local b = buttons[nButton]
    if not b then
        b = CreateFrame("Button", nil, child)
        b:SetHeight(16)
        b.text = W.Text(b, 11, "paleGold")
        b.text:SetPoint("LEFT", b, "LEFT", 0, 0)
        b:SetScript("OnLeave", function() W.SetColor(this.text, this.color or "paleGold") GameTooltip:Hide() end)
        b:SetScript("OnClick", function() if this.fn then this.fn() end end)
        buttons[nButton] = b
    end
    b:SetScript("OnEnter", function() W.SetColor(this.text, "white") end)
    b.fn = fn
    b.color = colorName or "paleGold"
    W.SetColor(b.text, b.color)
    b.text:SetText(label)
    b:SetWidth(math.min(WIDTH - 12, b.text:GetStringWidth() + 4))
    view:Place(b, 12, y, 16)
    y = y + 17
    return b
end

-- a row of item icons from "id:count,id:count"; wraps when it runs out of width
local ITEM_SIZE = 28
local function ItemRow(list, indent)
    local x, step = indent or 0, ITEM_SIZE + 6 + 4
    local placed = false
    for _, part in ipairs(AZC.Split(list or "", ",")) do
        local _, _, id, count = string.find(part, "^(%d+):(%d+)$")
        if id then
            if x + step - 4 > WIDTH then
                x = indent or 0
                y = y + step
            end
            nItem = nItem + 1
            local b = items[nItem]
            if not b then
                b = W.ItemButton(child, ITEM_SIZE)
                items[nItem] = b
            end
            view:Place(b, x, y, ITEM_SIZE + 6)
            b:SetItem(tonumber(id), tonumber(count))
            x = x + step
            placed = true
        end
    end
    if placed then y = y + step end
end

-- ---------------------------------------------------------------------------
-- views

P.mode = "rewards"

local function ShowZoneSummary(z)
    -- categories at a glance under the rewards
    Heading("This zone")
    for _, key in ipairs(AZC.CATEGORIES) do
        local c = z.cats[key]
        if c and AZC.Bool(c.vis) then
            local done, total = AZC.Num(c.d), AZC.Num(c.tot)
            local color = done >= total and "gold" or "parchment"
            Text(AZC.CATEGORY_INFO[key].title .. "   " .. AZC.Color(done >= total and "gold" or "white", done .. " / " .. total), color, 12, nil, 12)
        end
    end
end

local function RenderRewards()
    closeButton:Hide()
    local z = P.zoneId and D.Zone(P.zoneId)
    if not z or not z.zone then
        Text("Consulting the journal...", "grey", 12)
        return
    end
    local zone = z.zone
    IconTitle("Interface\\Icons\\INV_Box_02", "Zone Rewards", zone.n)
    local pct = AZC.Num(zone.pct)
    local nextMs = D.NextMilestone(z)
    if table.getn(z.ms) == 0 then
        Text("This zone offers no milestone rewards.", "grey", 11)
    end
    for _, ms in ipairs(z.ms) do
        local m = AZC.Num(ms.m)
        local got = AZC.Bool(ms.got)
        local title = m == 100 and (zone.n .. " Completion Reward") or (m .. "% Explorer's Cache")
        Gap(3)
        CheckLine(got, title, got and "gold" or "white", 13, AZC.FONT_TITLE)
        if ms.it and ms.it ~= "" then
            -- items as icons, everything else (XP, money, titles) as text
            if ms.rx and ms.rx ~= "" then Text(ms.rx, got and "paleGold" or "parchment", 11, nil, 20) end
            Gap(3)
            ItemRow(ms.it, 20)
        elseif ms.rw and ms.rw ~= "" then
            Text(ms.rw, got and "paleGold" or "parchment", 11, nil, 20)
        end
        if not got and nextMs == ms then
            Text(math.max(0, m - pct) .. "% remaining", "green", 11, nil, 20)
        elseif got then
            Text("Claimed", "dim", 10, nil, 20)
        end
    end
    if AZC.Bool(zone.earned) then
        Gap(6)
        local when = AZC.FormatDate(zone.eat)
        Text("You completed " .. zone.n .. (when and (" on " .. when) or "") .. ".", "gold", 11)
        if AZC.Num(zone.new) > 0 then Text(AZC.Num(zone.new) .. " objectives have appeared since. Your completion stays yours.", "parchment", 11) end
    end
    Gap(4)
    ShowZoneSummary(z)
end

local function DetailRecords(objectiveId)
    return D.details[objectiveId]
end

local function FindRec(records, type)
    for _, r in ipairs(records or {}) do if r.type == type then return r end end
end

local function RenderObjective()
    closeButton:Show()
    local id = P.objectiveId
    local records = DetailRecords(id)
    local obj = P.objective
    if not records then
        if obj then
            local name = D.DisplayName(obj)
            IconTitle(AZC.CATEGORY_INFO[obj.c].icon, name, AZC.CATEGORY_INFO[obj.c].title)
        end
        if D.HasFailed("detail:" .. id) then
            Text("These details are out of reach right now.", "red", 11)
        else
            Text("Consulting the journal...", "grey", 11)
            D.RequestDetail(id)
        end
        return
    end
    obj = FindRec(records, "OBJ") or obj
    local err = FindRec(records, "ERR")
    if err or not obj then
        Text(err and err.msg or "Nothing more is known about this.", "grey", 11)
        return
    end
    local info = AZC.CATEGORY_INFO[obj.c]
    local name, hidden = D.DisplayName(obj)
    local done = AZC.Bool(obj.d)
    local isElite = obj.c == "elites"

    local subtitle = info.title
    if (obj.c == "rares" or isElite) and not hidden then
        local lv = AZC.Num(obj.lmin) == AZC.Num(obj.lmax) and AZC.Num(obj.lmax) or (AZC.Num(obj.lmin) .. "-" .. AZC.Num(obj.lmax))
        local rank = ({ rare = "Rare", rare_elite = "Rare Elite", elite = "Elite", boss = "Boss" })[obj.r or ""] or ""
        subtitle = "Level " .. lv .. "  " .. rank
    end
    IconTitle(hidden and "Interface\\Icons\\INV_Misc_QuestionMark" or info.icon, name, subtitle, isElite and "elite" or "gold")

    if done then
        local when = AZC.FormatDate(obj.at)
        CheckLine(true, "Completed" .. (when and (" on " .. when) or ""), "green", 12)
    elseif hidden then
        Text("Not yet discovered.", "grey", 12)
        local where = obj.an and obj.an ~= "" and (" Rumours place it near " .. obj.an .. ".") or ""
        Text("Explore " .. ((D.Zone(P.zoneId) and D.Zone(P.zoneId).zone.n) or "the zone") .. " to learn more." .. where, "parchment", 11)
        return
    else
        Text("Not yet completed", "paleGold", 12)
    end
    if AZC.Bool(obj.b) then Text("Bonus objective - " .. (AZC.BONUS_TEXT[obj.br] or "not required for completion") .. ".", "blue", 11) end
    if obj.h and obj.h ~= "" then
        Heading("Hint")
        Text(obj.h, "parchment", 11)
    end

    if obj.c == "exploration" then
        local area = FindRec(records, "AREA")
        Heading("Location")
        if area and area.pn and area.pn ~= "" then Text("Part of " .. area.pn, "parchment", 11) end
        if AZC.Num(obj.lv) > 0 then Text("Discovery level " .. AZC.Num(obj.lv), "parchment", 11) end
    elseif obj.c == "travel" then
        Heading("Flight path")
        local f = ({ A = "Alliance", H = "Horde", B = "Alliance and Horde" })[obj.f or "B"]
        Text("Flight master for " .. (f or "travellers"), "parchment", 11)
        if obj.an and obj.an ~= "" then Text("At " .. obj.an, "parchment", 11) end
    elseif obj.c == "rares" or isElite then
        local cre = FindRec(records, "CRE")
        local areas = {}
        for _, r in ipairs(records) do
            if r.type == "AREA" and r.an and r.an ~= "" then table.insert(areas, r.an) end
        end
        if table.getn(areas) > 0 then
            Heading("Haunts")
            Text(table.concat(areas, ", "), "parchment", 11)
        end
        if cre and cre.sub and cre.sub ~= "" then Text("<" .. cre.sub .. ">", "grey", 11) end
        if cre and AZC.Num(cre.rmax) > 0 then
            local a, b = AZC.FormatDuration(cre.rmin), AZC.FormatDuration(cre.rmax)
            Text("Returns after " .. (a == b and a or (a .. " to " .. b)), "grey", 11)
        end
        if isElite and cre and AZC.Num(cre.imp) >= 6 then Text("A formidable foe. Bring friends.", "elite", 11) end
        local first = true
        for _, r in ipairs(records) do
            if r.type == "QREF" then
                if first then Heading("Related quests") first = false end
                local state = r.st == "done" and AZC.Color("green", "  done") or (r.st == "active" and AZC.Color("blue", "  in log") or "")
                Text(r.qn .. state, "white", 11, nil, 6)
            end
        end
        first = true
        for _, r in ipairs(records) do
            if r.type == "LOOT" then
                if first then Heading("Notable loot") first = false end
                local qc = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[AZC.Num(r.q)]
                local hex = qc and qc.hex
                local item = AZC.Num(r.item)
                local b = Button((hex or "|cffffffff") .. r.n .. "|r" .. AZC.Color("dim", "  " .. r.ch .. "%"), nil, "white")
                b:SetScript("OnEnter", function()
                    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
                    GameTooltip:SetHyperlink("item:" .. item .. ":0:0:0")
                    GameTooltip:Show()
                end)
            end
        end
    end
end

local function QuestTitle(s, qid)
    return AZC.QuestLabel(s, qid)
end

local function RenderStoryline()
    closeButton:Show()
    local s = D.stories[P.storyId]
    if not s then
        if D.HasFailed("story:" .. P.storyId) then
            Text("This storyline is out of reach right now.", "red", 11)
        else
            Text("Unrolling the story...", "grey", 11)
            D.RequestStory(P.storyId)
        end
        return
    end
    local st = s.story
    local faction = ({ A = "Alliance", H = "Horde", B = "" })[st.f or "B"] or ""
    local lv = AZC.Num(st.lmax) > 0 and ("Level " .. AZC.Num(st.lmin) .. "-" .. AZC.Num(st.lmax)) or ""
    IconTitle(AZC.CATEGORY_INFO.storylines.icon, st.n, lv .. (faction ~= "" and ("  " .. faction) or ""))
    if st.sum and st.sum ~= "" then Text(st.sum, "parchment", 11) Gap(4) end

    local done, total = AZC.Num(st.qd), AZC.Num(st.qt)
    Text("Progress " .. done .. " / " .. total, AZC.Bool(st.d) and "gold" or "white", 13, AZC.FONT_TITLE)
    Bar(done, total, AZC.Bool(st.d))
    if AZC.Bool(st.d) then
        local when = AZC.FormatDate(st.at)
        CheckLine(true, "Story complete" .. (when and (" - " .. when) or ""), "green", 12)
    end
    if AZC.Bool(st.b) then Text("Bonus storyline - never required.", "blue", 11) end

    local nq = s.quests[AZC.Num(st.nx)]
    if nq and nq.st ~= "done" then
        if nq.st == "blocked" then
            Heading("Locked")
            Text(nq.n, "white", 12)
            Text(AZC.ReasonText(nq, s) or "Not available yet", "red", 11)
        elseif nq.st == "active" then
            Heading("In progress")
            Text(nq.n, "white", 12)
            if nq.e_n then Text("Turn in to " .. nq.e_n .. (nq.e_an and (", " .. nq.e_an) or ""), "parchment", 11) end
        else
            Heading("Next quest")
            Text(nq.n, "white", 12)
            if nq.g_n then Text("Starts from " .. nq.g_n .. (nq.g_an and (", " .. nq.g_an) or ""), "parchment", 11) end
            if AZC.Num(nq.ml) > 1 then Text("Required level " .. AZC.Num(nq.ml), "grey", 11) end
        end
        Button("Show quest details", function() P.ShowQuest(P.storyId, AZC.Num(st.nx), P.zoneId) end)
    end

    for _, g in ipairs(s.exg) do
        Heading("A choice")
        local names = {}
        for _, qid in ipairs(AZC.NumList(g.q)) do table.insert(names, QuestTitle(s, qid)) end
        Text("Only one of these paths can be taken: " .. table.concat(names, ", or "), "parchment", 11)
    end
    local branches = AZC.NumList(st.brn)
    if table.getn(branches) > 0 then
        Heading("Branches")
        Text("This story divides after " .. QuestTitle(s, branches[1]) .. ".", "parchment", 11)
    end
end

local function RenderQuest()
    closeButton:Show()
    local s = D.stories[P.storyId]
    local q = s and s.quests[P.questId]
    if not q then
        if not s then D.RequestStory(P.storyId) end
        Text("Consulting the journal...", "grey", 11)
        return
    end
    local level = AZC.Num(q.lv) > 0 and ("Level " .. AZC.Num(q.lv)) or ""
    if AZC.Num(q.ml) > 0 then level = level .. (level ~= "" and "   " or "") .. "Requires " .. AZC.Num(q.ml) end
    IconTitle("Interface\\GossipFrame\\AvailableQuestIcon", q.n, level)

    local stateColor = ({ done = "green", active = "blue", available = "gold", blocked = "red", na = "grey" })[q.st] or "white"
    Text("Status: " .. AZC.Color(stateColor, AZC.STATE_TEXT[q.st] or q.st), "paleGold", 12)
    local why = AZC.ReasonText(q, s)
    if why and q.st ~= "done" and q.st ~= "active" then Text(why, "red", 11) end
    if AZC.Bool(q.opt) then Text((AZC.OPTIONAL_TEXT[q.optr] or "Optional") .. " - not required for the storyline.", "blue", 11) end

    if q.g_n then
        Heading("Starts")
        Text(q.g_n, "white", 12, nil, 6)
        if q.g_an then Text(q.g_an, "grey", 11, nil, 6) end
    end
    if q.e_n then
        Heading("Ends")
        Text(q.e_n, "white", 12, nil, 6)
        if q.e_an then Text(q.e_an, "grey", 11, nil, 6) end
    end

    local objectives = s.qobj[P.questId]
    if (objectives and table.getn(objectives) > 0) or (q.sum and q.sum ~= "") then
        Heading("Objectives")
        if q.sum and q.sum ~= "" then Text(q.sum, "parchment", 11) end
        for _, t in ipairs(objectives or {}) do Text("- " .. t, "white", 11, nil, 6) end
    end

    local pre = AZC.NumList(q.pre)
    if table.getn(pre) > 0 then
        Heading(table.getn(pre) > 1 and "After any of" or "After")
        for _, id in ipairs(pre) do
            local pq = s.quests[id]
            local qid = id
            local doneMark = pq and pq.st == "done" and AZC.Color("green", "  done") or ""
            Button(QuestTitle(s, id) .. doneMark, function() P.ShowQuest(P.storyId, qid, P.zoneId) end)
        end
    end
    local nexts = AZC.NumList(q.nx)
    if table.getn(nexts) > 0 then
        Heading("Leads to")
        for _, id in ipairs(nexts) do
            local qid = id
            Button(QuestTitle(s, id), function() P.ShowQuest(P.storyId, qid, P.zoneId) end)
        end
    end

    -- "Part 5 of 7"
    Heading("Storyline")
    local part, total = 0, 0
    for _, id in ipairs(s.order) do
        local x = s.quests[id]
        if x and AZC.Bool(x.cnt) then
            total = total + 1
            if id == P.questId then part = total end
        end
    end
    Button(s.story.n, function() P.ShowStoryline(P.storyId, P.zoneId) end, "gold")
    if part > 0 then Text("Part " .. part .. " of " .. total, "grey", 11, nil, 12) end
end

function P.Refresh()
    if not zonePage.frame:IsShown() then return end
    Begin()
    if P.mode == "objective" then RenderObjective()
    elseif P.mode == "storyline" then RenderStoryline()
    elseif P.mode == "quest" then RenderQuest()
    else RenderRewards() end
    End()
end

local function Switch(mode)
    P.mode = mode
    view:Reset()
    P.Refresh()
end

function P.ShowRewards(zoneId)
    P.zoneId = zoneId
    Switch("rewards")
end

function P.ShowObjective(obj, zoneId)
    P.zoneId = zoneId
    P.objective = obj
    P.objectiveId = obj.id
    Switch("objective")
end

function P.ShowObjectiveId(objectiveId, zoneId)
    P.zoneId = zoneId
    P.objective = nil
    P.objectiveId = objectiveId
    Switch("objective")
end

function P.ShowStoryline(storyId, zoneId)
    P.zoneId = zoneId
    P.storyId = storyId
    Switch("storyline")
end

function P.ShowQuest(storyId, questId, zoneId)
    P.zoneId = zoneId
    P.storyId = storyId
    P.questId = questId
    zonePage.selected = "quest:" .. questId
    Switch("quest")
end
