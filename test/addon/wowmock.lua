-- Minimal WoW 1.12 API mock for running the addon under real Lua 5.0.
NOW = 100
function GetTime() return NOW end
sent = {}
function SendAddonMessage(prefix, text, chan) table.insert(sent, text) end
function UnitName() return "Tester" end
function IsInGuild() return nil end
function GetNumRaidMembers() return 0 end
function GetNumPartyMembers() return 0 end
function GetRealZoneText() return "Westfall" end
function PlaySound() end
function PlaySoundFile() end
function GetCursorPosition() return 500, 400 end
function GetMapZones(c) if c == 1 then return "Durotar" else return "Elwynn Forest", "Westfall" end end
function SetMapZoom() end
function GetMapInfo() return "Westfall" end
function SetMapToCurrentZone() end
function getglobal(n) return _G_names[n] end
function tinsert(t, v) table.insert(t, v) end
function date(f, t) return "04 Oct 2026" end
ITEM_QUALITY_COLORS = { [1] = { r = 1, g = 1, b = 1, hex = "|cffffffff" }, [2] = { r = 0.12, g = 1, b = 0, hex = "|cff1eff00" }, [3] = { r = 0, g = 0.44, b = 0.87, hex = "|cff0070dd" } }
-- item 93505 is cached, everything else arrives after the client asks for it
cachedItems = { [93505] = true }
function GetItemInfo(id)
    if not cachedItems[id] then return nil end
    return "Item " .. id, "item:" .. id .. ":0:0:0", 3, 1, "Misc", "Junk", 20, "", "Interface\\Icons\\INV_Misc_Bag_08"
end
shiftDown, ctrlDown = nil, nil
function IsShiftKeyDown() return shiftDown end
function IsControlKeyDown() return ctrlDown end
linked = {}
function DressUpItemLink(link) table.insert(linked, "dressup " .. link) end
UISpecialFrames = {}
SlashCmdList = {}
_G_names = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(self, m) end }
errors = 0

local frames = {}
local function Obj(kind, name, parent)
    local o = { _kind = kind, _shown = true, _scripts = {}, _w = 100, _h = 400, _text = "", _parent = parent, _children = {} }
    -- like WoW: unknown methods (Capitalised) are harmless no-ops, unknown fields are nil
    setmetatable(o, { __index = function(t, k)
        if type(k) == "string" and string.find(k, "^%u") then return function() return nil end end
        return nil
    end })
    o.Show = function(self) self._shown = true if self._scripts.OnShow then this = self self._scripts.OnShow() end end
    o.Hide = function(self) local was = self._shown self._shown = false if was and self._scripts.OnHide then this = self self._scripts.OnHide() end end
    o.IsShown = function(self) return self._shown end
    o.IsVisible = function(self) return self._shown end
    o.SetScript = function(self, k, fn) self._scripts[k] = fn end
    o.GetScript = function(self, k) return self._scripts[k] end
    o.SetWidth = function(self, w) self._w = w end
    o.SetHeight = function(self, h) self._h = h end
    o.GetWidth = function(self) return self._w end
    o.GetHeight = function(self) return self._h end
    o.GetCenter = function(self) return 400, 300 end
    o.GetEffectiveScale = function() return 1 end
    o.GetFrameLevel = function() return 1 end
    o.GetChildren = function(self) return unpack(self._children) end
    o.SetText = function(self, t)
        if t ~= nil and type(t) ~= "string" and type(t) ~= "number" then error("SetText with " .. type(t)) end
        self._text = t or ""
    end
    o.GetText = function(self) return self._text end
    o.GetStringWidth = function(self) return string.len(tostring(self._text)) * 6 end
    o.SetPoint = function(self, a, b, c, d, e) self._point = { a, b, c, d, e } end
    o.GetPoint = function(self) local p = self._point or {} return p[1], p[2], p[3], p[4], p[5] end
    o.GetChecked = function(self) return self._checked end
    o.SetChecked = function(self, v) self._checked = v end
    o.GetValue = function(self) return self._value or 0 end
    o.SetValue = function(self, v) self._value = v if self._scripts.OnValueChanged then this = self self._scripts.OnValueChanged() end end
    o.GetVerticalScroll = function() return 0 end
    o.GetName = function(self) return name end
    o.SetParent = function(self, p)
        if self._parent then
            for i, c in ipairs(self._parent._children) do if c == self then table.remove(self._parent._children, i) break end end
        end
        self._parent = p
        table.insert(p._children, self)
    end
    o.SetScrollChild = function(self, c) c:SetParent(self) end
    o.CreateTexture = function(self) return Obj("Texture", nil, self) end
    o.CreateFontString = function(self) return Obj("FontString", nil, self) end
    o.SetFont = function(self, f, size) if type(size) ~= "number" then error("SetFont size " .. tostring(size)) end end
    o.SetTextColor = function(self, r) if type(r) ~= "number" then error("SetTextColor needs numbers") end end
    if name then _G_names[name] = o end
    if parent and parent._children then table.insert(parent._children, o) end
    return o
end

function CreateFrame(kind, name, parent, template)
    local f = Obj(kind, name, parent)
    if template == "UICheckButtonTemplate" then Obj("FontString", name .. "Text") end
    if template == "OptionsSliderTemplate" then
        Obj("FontString", name .. "Text") Obj("FontString", name .. "Low") Obj("FontString", name .. "High")
    end
    table.insert(frames, f)
    return f
end

UIParent = Obj("Frame", "UIParent")
Minimap = Obj("Frame", "Minimap")
MinimapCluster = Obj("Frame", "MinimapCluster")
WorldMapFrame = Obj("Frame", "WorldMapFrame") WorldMapFrame._shown = false
GameTooltip = Obj("Frame", "GameTooltip")
ChatFrameEditBox = Obj("EditBox", "ChatFrameEditBox")
ChatFrameEditBox.Insert = function(self, text) table.insert(linked, text) end

function FireEvent(ev, a1, a2, a3, a4)
    for _, f in ipairs(frames) do
        if f._scripts.OnEvent then
            event, arg1, arg2, arg3, arg4 = ev, a1, a2, a3, a4
            this = f
            f._scripts.OnEvent()
        end
    end
end

function RunUpdates(seconds)
    for i = 1, math.floor(seconds / 0.1) do
        NOW = NOW + 0.1
        for _, f in ipairs(frames) do
            if f._scripts.OnUpdate and f._shown then
                this = f
                arg1 = 0.1
                local ok, err = pcall(f._scripts.OnUpdate)
                if not ok then print("OnUpdate error: " .. err) errors = errors + 1 end
            end
        end
    end
end

function AllFrames() return frames end
