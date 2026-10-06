dofile("wowmock.lua")

local ADDON = (os.getenv("ADDON_DIR") or "../../server/launcher-data/client/Interface/AddOns/AzerothCompletion") .. "/"
for line in io.lines(ADDON .. "AzerothCompletion.toc") do
    if string.find(line, "%.lua$") then
        local ok, err = pcall(dofile, ADDON .. line)
        if not ok then print("LOAD ERROR " .. line .. ": " .. err) errors = errors + 1 end
    end
end

local function esc(s)
    return (string.gsub(s, "([%%%^;=|])", function(c) return string.format("%%%02X", string.byte(c)) end))
end
local function rec(t, fields)
    local out = t
    for i = 1, table.getn(fields), 2 do out = out .. "^" .. fields[i] .. "=" .. esc(tostring(fields[i + 1])) end
    return out
end

local W40 = rec("ZONE", { "id", 40, "n", "Westfall", "map", 0, "lmin", 9, "lmax", 18, "pct", 68, "done", 0, "ver", 3, "cur", 1 })
local CATS = rec("CAT", { "c", "exploration", "d", 10, "tot", 13, "pct", 76, "w", 30, "vis", 1, "bd", 0, "bt", 1 }) .. ";" ..
    rec("CAT", { "c", "storylines", "d", 5, "tot", 7, "pct", 71, "w", 30, "vis", 1, "bd", 0, "bt", 1 }) .. ";" ..
    rec("CAT", { "c", "rares", "d", 3, "tot", 6, "pct", 50, "w", 15, "vis", 1, "bd", 0, "bt", 1 }) .. ";" ..
    rec("CAT", { "c", "elites", "d", 2, "tot", 4, "pct", 50, "w", 15, "vis", 1 }) .. ";" ..
    rec("CAT", { "c", "travel", "d", 1, "tot", 1, "pct", 100, "w", 10, "vis", 1 })
-- 25: claimed before rewards were recorded; 50: claimed with items; 75/100: open, with items
local MS = rec("MS", { "m", 25, "got", 1 }) .. ";" ..
    rec("MS", { "m", 50, "got", 1, "rw", "120 XP, Westfall Charm", "rx", "120 XP", "it", "93503:1" }) .. ";" ..
    rec("MS", { "m", 75, "got", 0, "rw", "350 XP, 5x Stew, Shirt", "rx", "350 XP", "it", "93502:5,93501:1" }) .. ";" ..
    rec("MS", { "m", 100, "got", 0, "rw", "Tabard, Pet, 1x A, 1x B, 1x C, 1x D, title", "rx", "title", "it", "93500:1,93504:1,93505:1,93506:1,93507:1,93508:1" })
local OBJS = {
    exploration = rec("OBJ", { "id", "exploration:area_108", "c", "exploration", "n", "Sentinel Hill", "d", 1, "z", 40, "at", 1700000000, "a", 108, "lv", 15, "m", 0, "x", 1, "y", 2 }) .. ";" ..
        rec("OBJ", { "id", "exploration:area_920", "c", "exploration", "n", "The Dagger Hills", "d", 0, "z", 40, "a", 920, "lv", 17, "h", "Past the mine" }),
    storylines = rec("OBJ", { "id", "storyline:12", "c", "storylines", "n", "The People's Militia", "d", 1, "z", 40, "qd", 3, "qt", 3, "f", "A" }) .. ";" ..
        rec("OBJ", { "id", "storyline:65", "c", "storylines", "n", "The Defias Brotherhood", "d", 0, "z", 40, "qd", 4, "qt", 7, "f", "A", "nx", 142, "nxn", "The Defias Brotherhood", "nxs", "blocked", "why", "LEVEL_TOO_LOW", "ml", 18, "g_k", "npc", "g_n", "Gryan Stoutmantle", "g_an", "Sentinel Hill" }),
    rares = rec("OBJ", { "id", "rare:520", "c", "rares", "n", "Brack", "d", 1, "z", 40, "lmin", 19, "lmax", 19, "sc", 1, "e", 520, "r", "rare" }) .. ";" ..
        rec("OBJ", { "id", "rare:462", "c", "rares", "n", "Vultros", "d", 0, "z", 40, "hid", 1, "lmin", 26, "lmax", 26, "an", "The Dust Plains" }) .. ";" ..
        rec("OBJ", { "id", "rare:888", "c", "rares", "n", "Leprithus", "d", 0, "z", 40, "b", 1, "br", "event_only", "hid", 1 }),
    elites = rec("OBJ", { "id", "elite:573", "c", "elites", "n", "Foe Reaper 4000", "d", 0, "z", 40, "lmin", 20, "lmax", 20, "imp", 7, "hid", 1 }),
    travel = rec("OBJ", { "id", "travel:4", "c", "travel", "n", "Sentinel Hill, Westfall", "d", 1, "z", 40, "node", 4, "f", "A", "an", "Sentinel Hill" }),
}
local STORY = rec("STORY", { "id", 65, "n", "The Defias Brotherhood", "sum", "Uncover the plot.", "z", 40, "f", "A", "lmin", 14, "lmax", 22, "qd", 4, "qt", 7, "d", 0, "app", 1, "nx", 142, "q", "65,132,142,155,166,214", "roots", 65, "term", "166,214", "brn", 155, "blk", 142 }) .. ";" ..
    rec("EXG", { "s", 65, "g", 7, "q", "166,214" }) .. ";" ..
    rec("QUEST", { "id", 65, "n", "The Defias Brotherhood", "s", 65, "lv", 18, "ml", 14, "st", "done", "cnt", 1, "nx", 132, "g_k", "npc", "g_n", "Gryan Stoutmantle", "g_an", "Sentinel Hill" }) .. ";" ..
    rec("QUEST", { "id", 132, "n", "The Defias Brotherhood", "s", 65, "lv", 18, "ml", 14, "st", "active", "cnt", 1, "pre", 65, "nx", 142, "e_n", "Wiley" }) .. ";" ..
    rec("QUEST", { "id", 142, "n", "The Defias Brotherhood", "s", 65, "lv", 18, "ml", 18, "st", "blocked", "cnt", 1, "why", "MISSING_PREREQUISITE", "whys", "MISSING_PREREQUISITE,LEVEL_TOO_LOW", "pre", 132, "mp", 132, "nx", 155, "g_n", "Gryan Stoutmantle", "g_an", "Sentinel Hill", "sum", "Speak with Shaw." }) .. ";" ..
    rec("QOBJ", { "q", 142, "t", "Speak with Master Mathias Shaw" }) .. ";" ..
    rec("QUEST", { "id", 155, "n", "The Defias Brotherhood", "s", 65, "lv", 18, "ml", 14, "st", "available", "cnt", 1, "pre", 142, "nx", "166,214" }) .. ";" ..
    rec("QUEST", { "id", 166, "n", "The Defias Brotherhood", "s", 65, "lv", 22, "ml", 14, "st", "blocked", "cnt", 1, "ex", 7, "why", "LEVEL_TOO_LOW", "ml", 20, "pre", 155 }) .. ";" ..
    rec("QUEST", { "id", 214, "n", "Red Silk Bandanas", "s", 65, "lv", 17, "ml", 14, "st", "na", "cnt", 0, "opt", 1, "optr", "breadcrumb", "why", "EXCLUSIVE_BRANCH" })

local function Payload(cmd, args)
    if cmd == "HELLO" then return rec("PROTO", { "v", 1, "min", 1, "srv", "1.0.0", "chunk", 200, "hid", 1, "w", "30,30,15,15,10", "ms", "25,50,75,100", "gen", 1 }) end
    if cmd == "GET_ZONE_STATE" then
        local p = W40 .. ";" .. CATS .. ";" .. MS
        if string.find(args, " 1$") then for _, v in pairs(OBJS) do p = p .. ";" .. v end end
        return p
    end
    if cmd == "GET_CATEGORY" then
        local _, _, cat = string.find(args, "^%d+ (%a+)")
        return W40 .. ";" .. CATS .. ";" .. (OBJS[cat] or "")
    end
    if cmd == "GET_MISSING" then
        local p = W40
        for _, cat in ipairs({ "exploration", "storylines", "rares", "elites" }) do
            p = p .. ";" .. rec("CAT", { "c", cat, "d", 1, "tot", 3, "vis", 1 }) .. ";" .. string.gsub(OBJS[cat], "OBJ%^", "MISS^")
        end
        return p .. ";" .. rec("BLOCK", { "s", 65, "q", 142, "qn", "The Defias Brotherhood", "why", "LEVEL_TOO_LOW", "ml", 18 })
    end
    if cmd == "GET_STORYLINE" then return STORY end
    if cmd == "GET_OBJECTIVE_DETAIL" then
        if args == "rare:520" then
            return W40 .. ";" .. CATS .. ";" .. OBJS.rares .. ";" .. rec("DONE", { "id", "rare:520", "at", 1700000000, "src", "kill" }) .. ";" ..
                rec("CRE", { "id", "rare:520", "e", 520, "lmin", 19, "lmax", 19, "sc", 1, "rmin", 5400, "rmax", 9000, "imp", 7, "sig", "unique_name" }) .. ";" ..
                rec("AREA", { "id", "rare:520", "a", 920, "an", "The Dagger Hills" }) .. ";" ..
                rec("QREF", { "id", "rare:520", "q", 99, "qn", "Wanted: Brack", "st", "none" }) .. ";" ..
                rec("LOOT", { "id", "rare:520", "item", 1234, "n", "Brack's Blade", "q", 2, "ch", "12.5" })
        end
        if string.find(args, "^storyline") then return W40 .. ";" .. CATS .. ";" .. OBJS.storylines .. ";" .. STORY end
        if string.find(args, "^travel") then return W40 .. ";" .. CATS .. ";" .. OBJS.travel end
        return W40 .. ";" .. CATS .. ";" .. OBJS.exploration .. ";" .. rec("AREA", { "id", args, "a", 920, "an", "The Dagger Hills", "p", 40, "pn", "Westfall", "cells", 160 })
    end
    if cmd == "GET_CURRENT_PROGRESS" then
        return rec("CUR", { "z", 40, "zn", "Westfall", "a", 108, "an", "Sentinel Hill", "tracked", 1 }) .. ";" ..
            rec("ZSUM", { "id", 12, "n", "Elwynn Forest", "pct", 100, "d", 40, "tot", 40, "lmin", 1, "lmax", 10, "map", 0, "earned", 1 }) .. ";" ..
            rec("ZSUM", { "id", 40, "n", "Westfall", "pct", 68, "d", 32, "tot", 47, "lmin", 9, "lmax", 18, "map", 0, "earned", 0 }) .. ";" ..
            rec("ZSUM", { "id", 14, "n", "Durotar", "pct", 0, "d", 0, "tot", 30, "lmin", 1, "lmax", 10, "map", 1, "earned", 0 })
    end
    if cmd == "GET_REGIONS" then
        return rec("REGION", { "id", 1, "n", "The Kingdom of Azeroth", "desc", "Elwynn to the Blasted Lands.", "icon", "Interface\\Icons\\INV_BannerPVP_02",
                "d", 1, "tot", 2, "done", 0, "earned", 0, "rw", "25g, Lion's Pride Charger", "rx", "25g", "it", "93801:1" }) .. ";" ..
            rec("RZ", { "r", 1, "z", 12, "zn", "Elwynn Forest", "pct", 100, "earned", 1, "app", 1, "lmin", 1, "lmax", 10 }) .. ";" ..
            rec("RZ", { "r", 1, "z", 40, "zn", "Westfall", "pct", 68, "earned", 0, "app", 1, "lmin", 9, "lmax", 18 }) .. ";" ..
            rec("RZ", { "r", 1, "z", 1519, "zn", "Stormwind City", "pct", 0, "earned", 0, "app", 0 }) .. ";" ..
            rec("REGION", { "id", 9, "n", "Eastern Kingdoms", "d", 1, "tot", 1, "done", 1, "earned", 1, "at", 1790000000,
                "rw", "50g, title \"Pathfinder of the Eastern Kingdoms\"", "rx", "50g, title \"Pathfinder of the Eastern Kingdoms\"" }) .. ";" ..
            rec("RZ", { "r", 9, "z", 12, "zn", "Elwynn Forest", "pct", 100, "earned", 1, "app", 1 })
    end
    if cmd == "SEARCH" then
        return rec("HIT", { "k", "zone", "id", "zone:40", "n", "Westfall", "z", 40, "zn", "Westfall" }) .. ";" ..
            rec("HIT", { "k", "storyline", "id", "storyline:65", "n", "The Defias Brotherhood", "z", 40, "zn", "Westfall" }) .. ";" ..
            rec("HIT", { "k", "quest", "id", "storyline:65", "n", "Red Silk Bandanas", "z", 40, "zn", "Westfall", "q", 214 }) .. ";" ..
            rec("HIT", { "k", "rare", "id", "rare:520", "n", "Brack", "z", 40, "zn", "Westfall" })
    end
    return rec("ERR", { "code", "UNKNOWN_REQUEST", "msg", cmd })
end

local function Deliver(kind, id, payload)
    local parts, pos = {}, 1
    local n = string.len(payload)
    while pos <= n do
        local len = math.min(200, n - pos + 1)
        while len > 1 and pos + len <= n and string.sub(payload, pos + len - 1, pos + len - 1) == " " do len = len - 1 end
        table.insert(parts, string.sub(payload, pos, pos + len - 1))
        pos = pos + len
    end
    if table.getn(parts) == 0 then parts = { "" } end
    for i = table.getn(parts), 1, -1 do        -- out of order on purpose
        local msg = string.gsub(kind .. id .. " " .. i .. "/" .. table.getn(parts) .. " " .. parts[i], " +$", "")
        FireEvent("CHAT_MSG_ADDON", "AZC", msg, "GUILD", "Tester")
    end
end

function Pump()
    for round = 1, 10 do
        local batch = sent
        sent = {}
        if table.getn(batch) == 0 then return end
        for _, text in ipairs(batch) do
            local _, _, id, cmd, args = string.find(text, "^(%d+) (%S+) ?(.*)$")
            local ok, err = pcall(Deliver, "R", id, Payload(cmd, args or ""))
            if not ok then print("ERROR handling " .. cmd .. ": " .. err) errors = errors + 1 end
        end
    end
end

local function Try(label, fn)
    local ok, err = pcall(fn)
    if not ok then print("ERROR in " .. label .. ": " .. err) errors = errors + 1 end
end

local evSeq = 0
local function Event(fields) evSeq = evSeq + 1 Deliver("E", evSeq, rec("EV", fields)) end

local function ClickAll(label)
    local n = 0
    for _, f in ipairs(AllFrames()) do
        for _, field in ipairs({ "onClick", "fn", "tooltip" }) do
            if type(f[field]) == "function" then
                this = f
                n = n + 1
                local ok, err = pcall(f[field], f)
                if not ok then print("ERROR click[" .. label .. "] " .. field .. ": " .. err) errors = errors + 1 end
            end
        end
        for _, s in ipairs({ "OnEnter", "OnLeave" }) do
            if f._scripts[s] then this = f local ok, err = pcall(f._scripts[s]) if not ok then print("ERROR " .. s .. "[" .. label .. "]: " .. err) errors = errors + 1 end end
        end
    end
    return n
end

local function CheckOverflow(label)
    for _, f in ipairs(AllFrames()) do
        if f._scripts.OnMouseWheel then
            for _, c in ipairs(f._children) do
                local p = c._point
                if p and p[2] == f and c._shown then
                    local top = -(p[5] or 0)
                    if top < -0.5 or top + c._h > 400.5 then print("ERROR overflow[" .. label .. "]") errors = errors + 1 end
                end
            end
        end
    end
end

Try("startup", function()
    FireEvent("VARIABLES_LOADED") FireEvent("PLAYER_ENTERING_WORLD")
    RunUpdates(3) Pump() RunUpdates(5) Pump()
    assert(AZC.Protocol.status == "ready", "status " .. tostring(AZC.Protocol.status))
end)
Try("open", function() AZC.UI.Toggle() Pump() RunUpdates(0.2) end)
local clicks = 0
for _, filter in ipairs({ "all", "missing", "completed" }) do
    Try("filter " .. filter, function()
        AZC.UI.OpenZone(40) Pump()
        for _, k in ipairs(AZC.CATEGORIES) do AZC.ZonePage.expanded[k] = true end
        AZC.ZonePage.expandedStory[65] = true
        AZC.ZonePage.filter = filter
        AZC.ZonePage:Refresh() Pump() AZC.ZonePage:Refresh()
        CheckOverflow(filter)
        clicks = clicks + ClickAll(filter) Pump()
        clicks = clicks + ClickAll(filter .. "2") Pump()
        CheckOverflow(filter .. " after clicks")
    end)
end
Try("size changes", function()
    -- Vanilla delivers real sizes late; every OnSizeChanged handler must cope
    local n = 0
    for _, f in ipairs(AllFrames()) do
        if f._scripts.OnSizeChanged then this = f f._scripts.OnSizeChanged() n = n + 1 end
    end
    assert(n > 0, "no OnSizeChanged handlers found")
    print("size handlers: " .. n)
end)
Try("compact", function() AZC.db.compactHeader = true AZC.ZonePage:Refresh() AZC.db.compactHeader = false AZC.ZonePage:Refresh() end)
Try("reward items", function()
    AZC.UI.OpenZone(40) Pump()
    AZC.Detail.ShowRewards(40)
    local function Buttons()
        local out = {}
        local function OnZonePage(f)
            while f do
                if f == AZC.ZonePage.frame then return true end
                f = f._parent
            end
        end
        for _, f in ipairs(AllFrames()) do if f.itemId and OnZonePage(f) then table.insert(out, f) end end
        return out
    end
    local shown = Buttons()
    assert(table.getn(shown) == 9, "expected 9 reward icons, got " .. table.getn(shown))
    local function Texts(frame, out)
        for _, c in ipairs(frame._children) do
            if c._kind == "FontString" and c._shown and c._text ~= "" then out[c._text] = true end
            Texts(c, out)
        end
        return out
    end
    local texts = Texts(AZC.Detail and AZC.ZonePage.frame or UIParent, {})
    assert(texts["120 XP"] and not texts["120 XP, Westfall Charm"], "claimed milestone should show text without items")
    -- uncached items show a question mark until the server answers
    local stew
    for _, b in ipairs(shown) do if b.itemId == 93502 then stew = b end end
    assert(stew.count._text == 5, "stack count")
    for id = 93500, 93508 do cachedItems[id] = true end
    RunUpdates(2)
    shiftDown = 1 this = stew stew._scripts.OnClick() shiftDown = nil
    ctrlDown = 1 this = stew stew._scripts.OnClick() ctrlDown = nil
    assert(linked[1] == "|cff0070dd|Hitem:93502:0:0:0|h[Item 93502]|h|r", "chat link " .. tostring(linked[1]))
    assert(linked[2] == "dressup item:93502:0:0:0", "dress up " .. tostring(linked[2]))
end)
Try("azeroth", function() AZC.UI.Navigate("azeroth", {}) Pump() AZC.UI.Refresh() clicks = clicks + ClickAll("azeroth") end)
Try("regions", function()
    local seen = {}
    local function Walk(frame)
        for _, c in ipairs(frame._children) do
            if c._kind == "FontString" and c._shown and c._text ~= "" then seen[c._text] = true end
            if c._shown then Walk(c) end
        end
    end
    Walk(AZC.AzerothPage.frame)
    assert(seen["The Kingdom of Azeroth"] and seen["Eastern Kingdoms"], "region cards")
    assert(seen["1 / 2 zones"], "region progress counts only zones that apply")
    assert(seen["25g"], "non-item reward text next to the mount icon")
    local card
    for _, f in ipairs(AllFrames()) do if f.region and f.region.id == "1" then card = f end end
    this = card card._scripts.OnEnter()
end)
Try("search", function() AZC.UI.Navigate("search", { text = "defias" }) Pump() AZC.UI.Refresh() clicks = clicks + ClickAll("search") Pump() end)
Try("settings", function() AZC.UI.Navigate("settings", {}) clicks = clicks + ClickAll("settings") end)
Try("back", function() for i = 1, 5 do AZC.UI.Back() end end)
Try("events", function()
    Event({ "t", "OBJECTIVE_COMPLETED", "z", 40, "zn", "Westfall", "zp", 70, "c", "RARE", "cd", 4, "ct", 6, "id", "rare:462", "n", "Vultros" })
    Event({ "t", "STORYLINE_PROGRESS", "z", 40, "zn", "Westfall", "zp", 70, "id", "storyline:65", "n", "Defias", "qd", 5, "qt", 7, "nxn", "Next" })
    Event({ "t", "CATEGORY_COMPLETED", "z", 40, "zn", "Westfall", "zp", 75, "c", "RARE", "cd", 6, "ct", 6 })
    Event({ "t", "MILESTONE_REACHED", "z", 40, "zn", "Westfall", "zp", 75, "m", 75, "rw", "350 XP" })
    Event({ "t", "QUEST_BECAME_AVAILABLE", "z", 40, "zn", "Westfall", "zp", 75, "q", 155, "qn", "Defias", "g", "Gryan", "ga", "Sentinel Hill" })
    Event({ "t", "ZONE_COMPLETED", "z", 40, "zn", "Westfall", "zp", 100, "ver", 3 })
    Event({ "t", "DEFINITION_UPDATED", "gen", 2, "zones", "40:4" })
    Event({ "t", "RETROACTIVE", "count", 3 })
    Event({ "t", "REGION_COMPLETED", "r", 1, "rn", "The Kingdom of Azeroth", "zc", 8, "rw", "25g, Lion's Pride Charger", "it", "93801:1" })
    Pump() RunUpdates(40) Pump()
    clicks = clicks + ClickAll("after events")
end)
Try("toast preview", function() AZC.Toasts.Preview() RunUpdates(6) end)
Try("zone change", function() FireEvent("ZONE_CHANGED_NEW_AREA") Pump() RunUpdates(1) end)
Try("slash", function() SlashCmdList["AZEROTHCOMPLETION"]("") SlashCmdList["AZEROTHCOMPLETION"]("") SlashCmdList["AZEROTHCOMPLETION"]("azeroth") SlashCmdList["AZEROTHCOMPLETION"]("settings") end)
Try("minimap", function()
    local b = getglobal("AzerothCompletionMinimapButton")
    this = b b._scripts.OnDragStart() RunUpdates(0.3) this = b b._scripts.OnDragStop()
    this = b arg1 = "LeftButton" b._scripts.OnClick() this = b arg1 = "RightButton" b._scripts.OnClick()
    this = b b._scripts.OnEnter()
end)
Try("incompatible", function()
    AZC.Protocol.Hello()
    local batch = sent sent = {}
    for _, text in ipairs(batch) do local _, _, id = string.find(text, "^(%d+)") Deliver("R", id, rec("PROTO", { "v", 2, "min", 2 })) end
    assert(AZC.Protocol.status == "incompatible") AZC.UI.Open("zone")
end)
Try("timeout", function() AZC.Protocol.Hello() sent = {} RunUpdates(16) assert(AZC.Protocol.status == "unavailable") end)
print("handlers exercised: " .. clicks)
print("ERRORS: " .. errors)
