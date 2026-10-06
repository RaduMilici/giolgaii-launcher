-- Azeroth Completion: namespace, saved settings and shared helpers.
-- Vanilla (Lua 5.0): no '#', no '%' operator, no string methods via ':', no string.match.

AZC = {}
local AZC = AZC

AZC.VERSION = "1.0.0"
AZC.PROTOCOL = 1            -- the protocol this addon speaks (AZCOMP_PROTOCOL)
AZC.PREFIX = "AZC"

AZC.CATEGORIES = { "exploration", "storylines", "rares", "elites", "travel", "lore" }

AZC.CATEGORY_INFO = {
    exploration = { title = "Exploration",      icon = "Interface\\Icons\\INV_Misc_Spyglass_03",    event = "EXPLORATION",
                    single = "location",  hiddenName = "Undiscovered Location" },
    storylines  = { title = "Storylines",       icon = "Interface\\Icons\\INV_Misc_Book_09",        event = "STORYLINE",
                    single = "storyline", hiddenName = "Unknown Storyline" },
    rares       = { title = "Rare Hunts",       icon = "Interface\\Icons\\Ability_Hunter_SniperShot", event = "RARE",
                    single = "rare",      hiddenName = "Undiscovered Rare" },
    elites      = { title = "Elite Encounters", icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01", event = "ELITE",
                    single = "elite",     hiddenName = "Unknown Elite" },
    travel      = { title = "Travel",           icon = "Interface\\Icons\\Ability_Rogue_Sprint",    event = "TRAVEL",
                    single = "flight path", hiddenName = "Unknown Flight Path" },
    -- usually extra only: the server sends it with vis=0 and bonus counts
    lore        = { title = "Lore & Secrets",   icon = "Interface\\Icons\\INV_Misc_Book_11",        event = "LORE",
                    single = "secret",    hiddenName = "Undiscovered Secret", bonusOnly = true },
}

-- event category -> category key
AZC.EVENT_CATEGORY = { EXPLORATION = "exploration", STORYLINE = "storylines", RARE = "rares", ELITE = "elites", TRAVEL = "travel", LORE = "lore" }

AZC.COLORS = {
    gold      = { 1.00, 0.82, 0.00 },
    paleGold  = { 0.93, 0.80, 0.52 },
    parchment = { 0.86, 0.78, 0.62 },
    white     = { 1.00, 1.00, 1.00 },
    grey      = { 0.55, 0.53, 0.50 },
    dim       = { 0.42, 0.40, 0.37 },
    green     = { 0.40, 0.90, 0.35 },
    red       = { 1.00, 0.35, 0.30 },
    elite     = { 1.00, 0.55, 0.25 },
    rare      = { 0.75, 0.80, 0.95 },
    blue      = { 0.45, 0.75, 1.00 },
}

AZC.FONT_TITLE = "Fonts\\MORPHEUS.TTF"
AZC.FONT_BODY = "Fonts\\FRIZQT__.TTF"

local DEFAULTS = {
    minimap = { show = true, locked = false, angle = nil },
    window = { point = nil, scale = 1.0, tab = "zone" },
    notifications = true,
    milestoneNotifications = true,
    compactHeader = false,
    hideUndiscovered = true,
    sound = true,
}

-- ---------------------------------------------------------------------------
-- small helpers

function AZC.Num(v, default)
    local n = tonumber(v)
    if n == nil then return default or 0 end
    return n
end

function AZC.Bool(v)
    return v == "1" or v == 1 or v == true
end

function AZC.Count(t)
    return table.getn(t)
end

function AZC.Split(text, sep)
    local out = {}
    if not text or text == "" then return out end
    local start = 1
    while true do
        local i = string.find(text, sep, start, true)
        if not i then
            table.insert(out, string.sub(text, start))
            break
        end
        table.insert(out, string.sub(text, start, i - 1))
        start = i + string.len(sep)
    end
    return out
end

function AZC.NumList(text)
    local out = {}
    for _, v in ipairs(AZC.Split(text or "", ",")) do
        local n = tonumber(v)
        if n then table.insert(out, n) end
    end
    return out
end

function AZC.Unescape(text)
    if not text then return "" end
    return (string.gsub(text, "%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

function AZC.Upper(text)
    return string.upper(text or "")
end

function AZC.Color(name, text)
    local c = AZC.COLORS[name] or AZC.COLORS.white
    return string.format("|cff%02x%02x%02x%s|r", c[1] * 255, c[2] * 255, c[3] * 255, text or "")
end

function AZC.Print(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cffe6c35cAzeroth Completion|r: " .. (text or ""))
end

function AZC.Copy(t)
    local out = {}
    for k, v in pairs(t) do
        if type(v) == "table" then out[k] = AZC.Copy(v) else out[k] = v end
    end
    return out
end

function AZC.FormatDate(unixTime)
    local t = AZC.Num(unixTime)
    if t <= 0 then return nil end
    return date("%d %b %Y", t)
end

-- "1 hour 5 min" style respawn description
function AZC.FormatDuration(seconds)
    seconds = AZC.Num(seconds)
    if seconds <= 0 then return nil end
    if seconds < 120 then return seconds .. " sec" end
    local minutes = math.floor(seconds / 60)
    if minutes < 120 then return minutes .. " min" end
    local hours = math.floor(minutes / 60)
    local rest = math.mod(minutes, 60)
    if rest == 0 then return hours .. " hours" end
    return hours .. " h " .. rest .. " min"
end

-- ---------------------------------------------------------------------------
-- human readable quest states and reasons

AZC.STATE_TEXT = {
    done = "Completed",
    active = "In your quest log",
    available = "Available",
    blocked = "Locked",
    na = "Not available to you",
}

AZC.REASON_TEXT = {
    LEVEL_TOO_LOW = "Requires level %d",
    LEVEL_TOO_HIGH = "You have outgrown this quest",
    MISSING_PREREQUISITE = "Missing prerequisite",
    PREREQUISITE_ACTIVE = "Finish or abandon the quest that leads here first",
    PREREQUISITE_UNOBTAINABLE = "Its earlier quests are not open to you",
    WRONG_FACTION = "Offered only to the other faction",
    WRONG_RACE = "Not offered to your race",
    WRONG_CLASS = "A quest for another class",
    WRONG_PROFESSION = "Requires a profession",
    EXCLUSIVE_BRANCH = "You chose another path in this story",
    QUEST_DISABLED = "Currently unavailable",
    SEASONAL = "Only during a world event",
    REPUTATION = "Requires reputation",
    CONDITION = "Has special requirements",
    CHALLENGE_RESTRICTED = "Restricted by your challenge",
    TIMED_QUEST_ACTIVE = "Finish your timed quest first",
    UNAVAILABLE = "Not available right now",
}

AZC.OPTIONAL_TEXT = {
    breadcrumb = "Optional lead-in quest",
    repeatable = "Repeatable",
    seasonal = "World event quest",
    disabled = "Currently unavailable",
    condition = "Special requirements",
    reputation = "Requires reputation",
    profession = "Profession quest",
    challenge = "Challenge mode quest",
    concurrent_only = "Only alongside another quest",
    item_started = "Begins from a found item",
    no_giver = "No known quest giver",
    giver_not_spawned = "Quest giver not found in the world",
    no_ender = "No known turn-in",
    ender_not_spawned = "Turn-in not found in the world",
    prerequisite_optional = "Follows an optional quest",
    level_unreachable = "Beyond the level cap",
    technical_name = "Unused quest",
}

AZC.BONUS_TEXT = {
    event_only = "Appears only during world events",
    world_boss = "World boss",
    not_attackable_by_default = "Appears through special circumstances",
    phased = "Appears through special circumstances",
    override_bonus = "Bonus objective",
    no_reliable_quests = "Bonus storyline",
    lore = "Lore is read for its own sake and for the lore rewards",
    secret = "A secret, far from any town",
}

-- Title of a quest in its storyline; chains often reuse one title, so repeated titles get
-- their part number ("The Defias Brotherhood, part 4").
function AZC.QuestLabel(story, questId)
    local q = story and story.quests[questId]
    if not q then return "an earlier quest" end
    local same, part, n = 0, nil, 0
    for _, id in ipairs(story.order or {}) do
        local x = story.quests[id]
        if x and AZC.Bool(x.cnt) then
            n = n + 1
            if id == questId then part = n end
        end
        if x and x.n == q.n then same = same + 1 end
    end
    if same > 1 and part then return q.n .. ", part " .. part end
    return q.n
end

-- Primary reason of a QUEST record, readable. `story` (a cached storyline) names prerequisites.
function AZC.ReasonText(quest, story)
    local why = quest.why
    if not why or why == "" then return nil end
    local text = AZC.REASON_TEXT[why] or "Not available right now"
    if why == "LEVEL_TOO_LOW" then
        return string.format(text, AZC.Num(quest.ml))
    end
    if why == "MISSING_PREREQUISITE" then
        local names = {}
        for _, id in ipairs(AZC.NumList(quest.mp)) do
            table.insert(names, AZC.QuestLabel(story, id))
        end
        if AZC.Count(names) > 0 then
            return text .. ": " .. table.concat(names, ", ")
        end
    end
    return text
end

-- ---------------------------------------------------------------------------
-- timers (one shared OnUpdate)

local timers = {}
local timerFrame = CreateFrame("Frame")
timerFrame:SetScript("OnUpdate", function()
    local now = GetTime()
    local i = 1
    while i <= table.getn(timers) do
        local t = timers[i]
        if now >= t.at then
            table.remove(timers, i)
            t.fn()
        else
            i = i + 1
        end
    end
end)

function AZC.After(seconds, fn)
    table.insert(timers, { at = GetTime() + seconds, fn = fn })
end

-- ---------------------------------------------------------------------------
-- callbacks between modules

local listeners = {}

function AZC.On(name, fn)
    if not listeners[name] then listeners[name] = {} end
    table.insert(listeners[name], fn)
end

function AZC.Fire(name, a, b, c)
    local list = listeners[name]
    if not list then return end
    for _, fn in ipairs(list) do fn(a, b, c) end
end

-- ---------------------------------------------------------------------------
-- saved variables and startup

local function ApplyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            if type(v) == "table" then target[k] = AZC.Copy(v) else target[k] = v end
        elseif type(v) == "table" and type(target[k]) == "table" then
            ApplyDefaults(target[k], v)
        end
    end
end

local core = CreateFrame("Frame")
core:RegisterEvent("VARIABLES_LOADED")
core:RegisterEvent("PLAYER_ENTERING_WORLD")
core:RegisterEvent("ZONE_CHANGED_NEW_AREA")
core:RegisterEvent("CHAT_MSG_ADDON")

local entered = false

core:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        if type(AzerothCompletionDB) ~= "table" then AzerothCompletionDB = {} end
        ApplyDefaults(AzerothCompletionDB, DEFAULTS)
        AZC.db = AzerothCompletionDB
        AZC.Fire("Ready")
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- every login, reload or reconnect starts from a fresh authoritative state
        if not entered then
            entered = true
            AZC.After(2, function() AZC.Protocol.Hello() end)
        else
            AZC.Fire("ZoneChanged")
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        AZC.Fire("ZoneChanged")
    elseif event == "CHAT_MSG_ADDON" then
        if arg1 == AZC.PREFIX and arg4 == UnitName("player") then
            AZC.Protocol.OnMessage(arg2)
        end
    end
end)

SLASH_AZEROTHCOMPLETION1 = "/azc"
SLASH_AZEROTHCOMPLETION2 = "/completion"
SlashCmdList["AZEROTHCOMPLETION"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "settings" or msg == "options" then
        AZC.UI.Open("settings")
    elseif msg == "azeroth" or msg == "world" then
        AZC.UI.Open("azeroth")
    elseif msg == "reset" then
        AZC.UI.ResetPosition()
        AZC.Minimap.ResetPosition()
        AZC.Print("Window and minimap button positions reset.")
    else
        AZC.UI.Toggle()
    end
end
