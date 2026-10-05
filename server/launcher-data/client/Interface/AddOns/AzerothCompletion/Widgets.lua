-- Azeroth Completion: building blocks with the look of the Blizzard UI.

local AZC = AZC
local W = {}
AZC.W = W

local uid = 0
function W.Name(base)
    uid = uid + 1
    return "AzerothCompletion" .. base .. uid
end

W.BACKDROPS = {
    window = {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    },
    panel = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    },
    thin = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    },
}

function W.Backdrop(frame, style, r, g, b, a, er, eg, eb)
    frame:SetBackdrop(W.BACKDROPS[style])
    frame:SetBackdropColor(r or 0.08, g or 0.07, b or 0.06, a or 0.92)
    frame:SetBackdropBorderColor(er or 0.62, eg or 0.52, eb or 0.32, 1)
end

-- A darkened parchment fill behind content.
function W.Parchment(frame, darkness)
    local tex = frame:CreateTexture(nil, "BACKGROUND")
    tex:SetTexture("Interface\\Stationery\\StationeryTest1")
    tex:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    tex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    local d = darkness or 0.32
    tex:SetVertexColor(d, d * 0.9, d * 0.75, 1)
    return tex
end

function W.Text(parent, size, colorName, font, flags, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(font or AZC.FONT_BODY, size or 12, flags or "")
    local c = AZC.COLORS[colorName or "white"]
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetJustifyH("LEFT")
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
    return fs
end

function W.SetColor(fs, colorName)
    local c = AZC.COLORS[colorName] or AZC.COLORS.white
    fs:SetTextColor(c[1], c[2], c[3])
end

function W.Line(parent, alpha)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(0.85, 0.68, 0.30, alpha or 0.45)
    tex:SetHeight(1)
    return tex
end

-- Square icon with the edges trimmed, like spell icons in the spellbook.
function W.Icon(parent, size, path)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetWidth(size)
    tex:SetHeight(size)
    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if path then tex:SetTexture(path) end
    return tex
end

-- A framed icon (thin gold border) for categories and toasts.
function W.FramedIcon(parent, size, path)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetWidth(size + 6)
    holder:SetHeight(size + 6)
    W.Backdrop(holder, "thin", 0, 0, 0, 1, 0.75, 0.62, 0.35)
    holder.icon = W.Icon(holder, size, path)
    holder.icon:SetPoint("CENTER", holder, "CENTER", 0, 0)
    return holder
end

-- ---------------------------------------------------------------------------
-- item icon: the normal item tooltip on hover, shift-click links it, ctrl-click tries it on

local scanTip

-- Asks the server about an item the client has not cached yet (custom rewards often).
local function QueryItem(itemId)
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "AzerothCompletionScanTip", UIParent, "GameTooltipTemplate")
    end
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTip:SetHyperlink("item:" .. itemId .. ":0:0:0")
    scanTip:Hide()
end

function W.ItemLink(itemId)
    local name, link, quality = GetItemInfo(itemId)
    if not name then return nil end
    local color = ITEM_QUALITY_COLORS[quality] and ITEM_QUALITY_COLORS[quality].hex or "|cffffffff"
    return color .. "|H" .. link .. "|h[" .. name .. "]|h|r"
end

function W.ItemButton(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(size + 6)
    b:SetHeight(size + 6)
    W.Backdrop(b, "thin", 0, 0, 0, 1, 0.75, 0.62, 0.35)
    b.icon = W.Icon(b, size, "Interface\\Icons\\INV_Misc_QuestionMark")
    b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints(b.icon)

    function b:SetItem(itemId, count)
        self.itemId = itemId
        self.count:SetText((count or 1) > 1 and count or "")
        self:Refresh(4)
    end

    -- shows the icon once the client knows the item, asking the server a few times if needed
    function b:Refresh(tries)
        local id = self.itemId
        local _, _, quality, _, _, _, _, _, texture = GetItemInfo(id)
        if texture then
            self.icon:SetTexture(texture)
            local c = ITEM_QUALITY_COLORS[quality]
            if c and quality > 1 then self:SetBackdropBorderColor(c.r, c.g, c.b) else self:SetBackdropBorderColor(0.75, 0.62, 0.35) end
            return
        end
        self.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        self:SetBackdropBorderColor(0.75, 0.62, 0.35)
        if tries > 0 then
            QueryItem(id)
            AZC.After(1, function() if b.itemId == id and b:IsVisible() then b:Refresh(tries - 1) end end)
        end
    end

    b:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. this.itemId .. ":0:0:0")
        GameTooltip:Show()
        if GetItemInfo(this.itemId) then this:Refresh(0) end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- scrolled back into view: the item may have arrived meanwhile
    b:SetScript("OnShow", function() if this.itemId then this:Refresh(0) end end)
    b:SetScript("OnClick", function()
        local link = W.ItemLink(this.itemId)
        if not link then return end
        if IsShiftKeyDown() and ChatFrameEditBox:IsVisible() then
            ChatFrameEditBox:Insert(link)
        elseif IsControlKeyDown() then
            DressUpItemLink("item:" .. this.itemId .. ":0:0:0")
        end
    end)
    return b
end

-- ---------------------------------------------------------------------------
-- progress bar with milestone ticks and a spark

function W.ProgressBar(parent, height)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(height)
    W.Backdrop(frame, "thin", 0.03, 0.03, 0.03, 0.9, 0.55, 0.45, 0.28)

    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
    bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    frame.bar = bar

    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetWidth(height + 6)
    spark:SetHeight(height * 2.2)
    frame.spark = spark

    frame.ticks = {}

    function frame:SetProgress(done, total, complete)
        local value = 0
        if total and total > 0 then value = done / total end
        if value > 1 then value = 1 end
        self.bar:SetValue(value)
        if complete then
            self.bar:SetStatusBarColor(0.95, 0.78, 0.25)
            self:SetBackdropBorderColor(1.0, 0.84, 0.35)
        elseif value > 0 then
            self.bar:SetStatusBarColor(0.80, 0.58, 0.16)
            self:SetBackdropBorderColor(0.55, 0.45, 0.28)
        else
            self.bar:SetStatusBarColor(0.4, 0.35, 0.25)
            self:SetBackdropBorderColor(0.45, 0.38, 0.25)
        end
        self.value = value
        self:PlaceSpark()
    end

    -- Width of the fill area. Vanilla reports scaled-down widths for frames sized by their
    -- anchors (and a status bar's fill texture always spans the whole bar), so callers that
    -- stretch a bar between anchors tell it its real width with SetKnownWidth.
    function frame:SetKnownWidth(width)
        self.knownWidth = width
        self:PlaceSpark()
        if self.tickList then self:SetTicks(self.tickList) end
    end

    function frame:InnerWidth()
        return (self.knownWidth or self:GetWidth() or 0) - 6
    end

    function frame:PlaceSpark()
        local value = self.value or 0
        local width = self:InnerWidth()
        if value <= 0 or value >= 1 or width <= 0 then
            self.spark:Hide()
            return
        end
        self.spark:ClearAllPoints()
        self.spark:SetPoint("CENTER", self.bar, "LEFT", width * value, 0)
        self.spark:Show()
    end

    -- marks at milestone percents; `reached` colours them
    function frame:SetTicks(list)
        self.tickList = list
        for _, t in ipairs(self.ticks) do t:Hide() end
        local width = self:InnerWidth()
        if not width or width <= 0 then return end
        for i, ms in ipairs(list or {}) do
            local pct = AZC.Num(ms.m)
            if pct > 0 and pct < 100 then
                local t = self.ticks[i]
                if not t then
                    t = self.bar:CreateTexture(nil, "OVERLAY")
                    t:SetWidth(2)
                    self.ticks[i] = t
                end
                t:ClearAllPoints()
                t:SetPoint("TOP", self.bar, "TOPLEFT", width * pct / 100, 0)
                t:SetPoint("BOTTOM", self.bar, "BOTTOMLEFT", width * pct / 100, 0)
                if AZC.Bool(ms.got) then t:SetTexture(1, 0.9, 0.5, 0.9) else t:SetTexture(0, 0, 0, 0.7) end
                t:Show()
            end
        end
    end

    -- the real size arrives once the frame is drawn: redo everything that measured it
    bar:SetScript("OnSizeChanged", function()
        frame:PlaceSpark()
        if frame.tickList then frame:SetTicks(frame.tickList) end
    end)

    return frame
end

-- ---------------------------------------------------------------------------
-- flat toggle button used for tabs and filters

function W.ToggleButton(parent, text, width, height, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(width)
    b:SetHeight(height or 22)
    W.Backdrop(b, "thin", 0.10, 0.08, 0.06, 0.9, 0.5, 0.42, 0.27)
    b.label = W.Text(b, 11, "paleGold", AZC.FONT_BODY)
    b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.label:SetJustifyH("CENTER")
    b.label:SetText(text)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hl:SetBlendMode("ADD")
    hl:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
    hl:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    hl:SetVertexColor(1, 0.8, 0.4, 0.35)

    function b:SetSelected(selected)
        self.selected = selected
        if selected then
            self:SetBackdropColor(0.35, 0.25, 0.08, 0.95)
            self:SetBackdropBorderColor(1.0, 0.82, 0.35)
            W.SetColor(self.label, "gold")
        else
            self:SetBackdropColor(0.10, 0.08, 0.06, 0.9)
            self:SetBackdropBorderColor(0.5, 0.42, 0.27)
            W.SetColor(self.label, "paleGold")
        end
    end

    b:SetScript("OnClick", function()
        if AZC.db.sound then PlaySound("igMainMenuOptionCheckBoxOn") end
        if onClick then onClick(this) end
    end)
    return b
end

function W.PanelButton(parent, text, width, height, onClick)
    local b = CreateFrame("Button", W.Name("Button"), parent, "UIPanelButtonTemplate")
    b:SetWidth(width)
    b:SetHeight(height or 22)
    b:SetText(text)
    b:SetScript("OnClick", function() if onClick then onClick(this) end end)
    return b
end

-- ---------------------------------------------------------------------------
-- tooltips

-- lines: { {text, colorName or r,g,b, wrap}, ... } or a function returning that
function W.ShowTooltip(owner, title, lines, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    local c = AZC.COLORS.gold
    GameTooltip:AddLine(title, c[1], c[2], c[3])
    for _, line in ipairs(lines or {}) do
        if type(line) == "table" and line.left then
            local l = AZC.COLORS[line.leftColor or "white"]
            local r = AZC.COLORS[line.rightColor or "white"]
            GameTooltip:AddDoubleLine(line.left, line.right, l[1], l[2], l[3], r[1], r[2], r[3])
        elseif type(line) == "table" then
            local col = AZC.COLORS[line[2] or "white"]
            GameTooltip:AddLine(line[1], col[1], col[2], col[3], line[3] and 1 or nil)
        elseif line == "" then
            GameTooltip:AddLine(" ")
        else
            GameTooltip:AddLine(line, 1, 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

function W.Tooltip(frame, title, linesFn)
    frame:SetScript("OnEnter", function()
        local t = title
        local lines = linesFn
        if type(title) == "function" then t, lines = title(this) end
        if type(lines) == "function" then lines = lines(this) end
        if t then W.ShowTooltip(this, t, lines) end
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- ---------------------------------------------------------------------------
-- fades

function W.FadeIn(frame, duration)
    frame:SetAlpha(0)
    frame:Show()
    frame.fadeStart = GetTime()
    frame.fadeDuration = duration or 0.2
    if not frame.fadeHooked then
        frame.fadeHooked = true
        local previous = frame:GetScript("OnUpdate")
        frame:SetScript("OnUpdate", function()
            if this.fadeStart then
                local p = (GetTime() - this.fadeStart) / this.fadeDuration
                if p >= 1 then
                    this:SetAlpha(1)
                    this.fadeStart = nil
                else
                    this:SetAlpha(p)
                end
            end
            if previous then previous() end
        end)
    end
end

-- rough height of wrapped text (FontString heights are unreliable in 1.12)
function W.WrappedHeight(fs, width, lineHeight)
    local textWidth = fs:GetStringWidth() or 0
    local lines = math.max(1, math.ceil(textWidth / math.max(1, width - 6)))
    return lines * (lineHeight or 14)
end

-- ---------------------------------------------------------------------------
-- virtual scrolling
--
-- Vanilla scroll frames do not reliably clip nested frames, so lists are laid out in
-- "virtual" coordinates and only the elements that fit completely in the visible area are
-- positioned and shown. A slider with Blizzard's scroll bar art drives the offset.
--
--   local v = W.VirtualScroll(parent)
--   v:Anchor(parent, left, top, right, bottom)
--   v:Begin()  ...  v:Place(obj, x, y, height)  ...  v:Finish(totalHeight)

local SCROLL_STEP = 20

function W.VirtualScroll(parent)
    local v = { items = {}, total = 0, offset = 0 }

    local content = CreateFrame("Frame", nil, parent)
    content:EnableMouseWheel(true)
    v.content = content

    local bar = CreateFrame("Slider", nil, parent)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(16)
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(0, 0, 0, 0.45)
    track:SetAllPoints(bar)
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    thumb:SetWidth(24)
    thumb:SetHeight(24)
    bar:SetThumbTexture(thumb)
    v.bar = bar

    local function Arrow(dir)
        local b = CreateFrame("Button", nil, parent)
        b:SetWidth(18)
        b:SetHeight(16)
        local base = "Interface\\Buttons\\UI-ScrollBar-Scroll" .. dir .. "Button-"
        b:SetNormalTexture(base .. "Up")
        b:SetPushedTexture(base .. "Down")
        b:SetDisabledTexture(base .. "Disabled")
        b:SetHighlightTexture(base .. "Highlight")
        b:SetScript("OnClick", function()
            v:ScrollTo(v.offset + (dir == "Up" and -SCROLL_STEP * 2 or SCROLL_STEP * 2))
        end)
        return b
    end
    v.up = Arrow("Up")
    v.down = Arrow("Down")
    v.up:SetPoint("BOTTOM", bar, "TOP", 0, 0)
    v.down:SetPoint("TOP", bar, "BOTTOM", 0, 0)

    bar:SetScript("OnValueChanged", function()
        local value = math.floor(this:GetValue() + 0.5)
        if value ~= v.offset then
            v.offset = value
            v:Apply()
        end
    end)
    content:SetScript("OnMouseWheel", function()
        v:ScrollTo(v.offset - arg1 * SCROLL_STEP * 2)
    end)

    function v:Anchor(frame, left, top, right, bottom)
        self.content:ClearAllPoints()
        self.content:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -top)
        self.content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(right + 22), bottom)
        self.bar:ClearAllPoints()
        self.bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(right + 1), -(top + 16))
        self.bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(right + 1), bottom + 16)
    end

    -- The visible height comes from the page layout when known (Vanilla reports GetHeight()
    -- of anchored frames scaled down, which would leave rows unshown at the bottom).
    function v:SetHeightFunc(fn)
        self.heightFunc = fn
    end

    function v:ViewHeight()
        if self.heightFunc then return self.heightFunc() end
        local h = self.content:GetHeight()
        if not h or h <= 0 then h = 300 end
        return h
    end

    function v:Begin()
        self.items = {}
    end

    function v:Place(obj, x, y, height)
        table.insert(self.items, { obj = obj, x = x, y = y, h = height })
    end

    function v:Finish(total)
        self.total = total
        local maxOffset = math.max(0, total - self:ViewHeight())
        if self.offset > maxOffset then self.offset = maxOffset end
        self.bar:SetMinMaxValues(0, maxOffset)
        self.bar:SetValue(self.offset)
        if maxOffset > 0 then
            self.bar:Show() self.up:Show() self.down:Show()
        else
            self.bar:Hide() self.up:Hide() self.down:Hide()
        end
        self:Apply()
    end

    -- position what fits, hide the rest
    function v:Apply()
        local view = self:ViewHeight()
        for _, it in ipairs(self.items) do
            local top = it.y - self.offset
            local o = it.obj
            if top >= -0.5 and top + it.h <= view + 0.5 then
                o:ClearAllPoints()
                o:SetPoint("TOPLEFT", self.content, "TOPLEFT", it.x, -top)
                if o.fresh and o.SetAlpha and W.FadeIn and o.GetScript then
                    o.fresh = nil
                    W.FadeIn(o, 0.18)
                else
                    o:Show()
                end
            else
                o:Hide()
            end
        end
        if self.offset <= 0 then self.up:Disable() else self.up:Enable() end
        if self.offset >= self.total - view then self.down:Disable() else self.down:Enable() end
    end

    function v:ScrollTo(offset)
        local maxOffset = math.max(0, self.total - self:ViewHeight())
        offset = math.max(0, math.min(maxOffset, math.floor(offset + 0.5)))
        self.bar:SetValue(offset)
        if offset ~= self.offset then
            self.offset = offset
            self:Apply()
        end
    end

    function v:Reset()
        self.offset = 0
        self.bar:SetValue(0)
    end

    return v
end
