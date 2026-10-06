-- Azeroth Completion: session cache of what the server told us.
-- The server is authoritative: everything here is presentation data for this session and is
-- dropped whenever the server reports a change.

local AZC = AZC
local D = {}
AZC.Data = D

D.zones = {}        -- zoneId -> { zone, cats = {key = CAT}, objs = {key = {OBJ...}}, ms = {MS...}, full, missing }
D.stories = {}      -- storylineId -> { story, quests = {id = QUEST}, order = {ids}, qobj = {id = {texts}}, exg = {} }
D.details = {}      -- objectiveId -> records
D.progress = nil    -- { cur = CUR, zones = {ZSUM...} }
D.regions = nil     -- { REGION... } in display order, each with .zones = {RZ...}
D.currentZoneId = nil

local inflight = {}
local failedAt = {}     -- key -> time of the last failure; pages refresh often, do not hammer

local function Fetch(key, cmd, args, handler, cb)
    if failedAt[key] and GetTime() - failedAt[key] < 10 then
        if cb then cb(nil, { type = "ERR", code = "RECENTLY_FAILED" }) end
        return
    end
    if inflight[key] then
        table.insert(inflight[key], cb)
        return
    end
    inflight[key] = { cb }
    AZC.Protocol.Request(cmd, args, function(records, err)
        local waiting = inflight[key]
        inflight[key] = nil
        if records and not err then
            failedAt[key] = nil
            handler(records)
        else
            failedAt[key] = GetTime()
            AZC.Fire("RequestFailed", key, err)
        end
        for _, fn in ipairs(waiting) do
            if fn then fn(records, err) end
        end
    end)
end

local function ZoneEntry(zoneId)
    local z = D.zones[zoneId]
    if not z then
        z = { cats = {}, objs = {}, ms = {} }
        D.zones[zoneId] = z
    end
    return z
end

-- Reads ZONE / CAT / OBJ / MISS / MS records into the zone cache. Returns the zone id.
local function StoreZoneRecords(records, replaceObjects)
    local zoneId, z
    for _, rec in ipairs(records) do
        if rec.type == "ZONE" then
            zoneId = AZC.Num(rec.id)
            z = ZoneEntry(zoneId)
            z.zone = rec
            if AZC.Bool(rec.cur) then D.currentZoneId = zoneId end
            if replaceObjects then z.ms = {} end
        elseif z and rec.type == "CAT" then
            z.cats[rec.c] = rec
            if replaceObjects then z.objs[rec.c] = {} end
        elseif z and rec.type == "OBJ" then
            if not z.objs[rec.c] then z.objs[rec.c] = {} end
            table.insert(z.objs[rec.c], rec)
        elseif z and rec.type == "MS" then
            table.insert(z.ms, rec)
        end
    end
    return zoneId
end

-- zoneId 0 = where the player is
function D.RequestZone(zoneId, full, cb)
    local key = "zone:" .. zoneId .. ":" .. (full and 1 or 0)
    Fetch(key, "GET_ZONE_STATE", zoneId .. " " .. (full and 1 or 0), function(records)
        -- a summary must not wipe category lists we already hold
        local id
        for _, rec in ipairs(records) do
            if rec.type == "ZONE" then id = AZC.Num(rec.id) end
        end
        if id and D.zones[id] then
            D.zones[id].ms = {}
            if full then D.zones[id].objs = {} end
        end
        id = StoreZoneRecords(records, false)
        if id and full then D.zones[id].full = true end
        AZC.Fire("DataChanged", "zone", id)
    end, cb)
end

function D.RequestCategory(zoneId, cat, cb)
    Fetch("cat:" .. zoneId .. ":" .. cat, "GET_CATEGORY", zoneId .. " " .. cat, function(records)
        local z = D.zones[zoneId]
        if z then z.objs[cat] = {} end
        local id = StoreZoneRecords(records, false)
        AZC.Fire("DataChanged", "category", id, cat)
    end, cb)
end

function D.RequestMissing(zoneId, cb)
    Fetch("missing:" .. zoneId, "GET_MISSING", tostring(zoneId), function(records)
        local id
        local list = { cats = {}, objs = {}, blocks = {} }
        for _, rec in ipairs(records) do
            if rec.type == "ZONE" then
                id = AZC.Num(rec.id)
                ZoneEntry(id).zone = rec
            elseif rec.type == "CAT" then
                list.cats[rec.c] = rec
            elseif rec.type == "MISS" then
                if not list.objs[rec.c] then list.objs[rec.c] = {} end
                table.insert(list.objs[rec.c], rec)
            elseif rec.type == "BLOCK" then
                table.insert(list.blocks, rec)
            end
        end
        if id then ZoneEntry(id).missing = list end
        AZC.Fire("DataChanged", "missing", id)
    end, cb)
end

local function StoreStory(records)
    local s
    for _, rec in ipairs(records) do
        if rec.type == "STORY" then
            local id = AZC.Num(rec.id)
            s = { story = rec, quests = {}, order = AZC.NumList(rec.q), qobj = {}, exg = {} }
            D.stories[id] = s
        elseif s and rec.type == "QUEST" then
            s.quests[AZC.Num(rec.id)] = rec
        elseif s and rec.type == "QOBJ" then
            local q = AZC.Num(rec.q)
            if not s.qobj[q] then s.qobj[q] = {} end
            table.insert(s.qobj[q], rec.t)
        elseif s and rec.type == "EXG" then
            table.insert(s.exg, rec)
        end
    end
    return s
end

function D.RequestStory(storyId, cb)
    Fetch("story:" .. storyId, "GET_STORYLINE", tostring(storyId), function(records)
        local s = StoreStory(records)
        AZC.Fire("DataChanged", "story", s and AZC.Num(s.story.id))
    end, cb)
end

function D.RequestDetail(objectiveId, cb)
    Fetch("detail:" .. objectiveId, "GET_OBJECTIVE_DETAIL", objectiveId, function(records)
        D.details[objectiveId] = records
        StoreStory(records)     -- storyline details carry the whole quest graph
        AZC.Fire("DataChanged", "detail", objectiveId)
    end, cb)
end

function D.RequestProgress(cb)
    Fetch("progress", "GET_CURRENT_PROGRESS", "1", function(records)
        local p = { zones = {} }
        for _, rec in ipairs(records) do
            if rec.type == "CUR" then p.cur = rec
            elseif rec.type == "ZSUM" then table.insert(p.zones, rec) end
        end
        D.progress = p
        AZC.Fire("DataChanged", "progress")
    end, cb)
end

function D.RequestRegions(cb)
    Fetch("regions", "GET_REGIONS", "", function(records)
        local list, byId = {}, {}
        for _, rec in ipairs(records) do
            if rec.type == "REGION" then
                rec.zones = {}
                table.insert(list, rec)
                byId[rec.id] = rec
            elseif rec.type == "RZ" and byId[rec.r] then
                table.insert(byId[rec.r].zones, rec)
            end
        end
        D.regions = list
        AZC.Fire("DataChanged", "regions")
    end, cb)
end

function D.Search(text, cb)
    AZC.Protocol.Request("SEARCH", text, cb)
end

function D.IsLoading(key) return inflight[key] ~= nil end
function D.HasFailed(key) return failedAt[key] ~= nil end

-- ---------------------------------------------------------------------------
-- convenience views

function D.Zone(zoneId)
    return D.zones[zoneId]
end

function D.CurrentZone()
    return D.currentZoneId and D.zones[D.currentZoneId]
end

-- Totals across visible categories.
function D.ZoneTotals(z)
    local done, total = 0, 0
    for _, key in ipairs(AZC.CATEGORIES) do
        local c = z.cats[key]
        if c and AZC.Bool(c.vis) then
            done = done + AZC.Num(c.d)
            total = total + AZC.Num(c.tot)
        end
    end
    return done, total
end

-- Next unclaimed milestone, or nil.
function D.NextMilestone(z)
    local best
    for _, ms in ipairs(z.ms or {}) do
        if not AZC.Bool(ms.got) and (not best or AZC.Num(ms.m) < AZC.Num(best.m)) then best = ms end
    end
    return best
end

-- Name to show for an objective, honouring hidden information.
function D.DisplayName(obj)
    local info = AZC.CATEGORY_INFO[obj.c]
    if obj.n == "???" or (AZC.Bool(obj.hid) and AZC.db.hideUndiscovered) then
        return info and info.hiddenName or "Undiscovered", true
    end
    return obj.n, false
end

-- ---------------------------------------------------------------------------
-- staying in sync

local function Invalidate(zoneId)
    if zoneId then
        D.zones[zoneId] = nil
    else
        D.zones = {}
    end
    D.details = {}
    D.stories = {}
    D.progress = nil
    D.regions = nil
    failedAt = {}
end
D.Invalidate = Invalidate

AZC.On("StatusChanged", function()
    Invalidate(nil)
    if AZC.Protocol.IsReady() then
        D.RequestZone(0, false)
    end
    AZC.Fire("DataChanged", "status")
end)

AZC.On("ZoneChanged", function()
    if not AZC.Protocol.IsReady() then return end
    -- the new zone may have no journal: forget the old one until the server answers
    D.currentZoneId = nil
    failedAt["zone:0:0"] = nil
    D.RequestZone(0, false)
end)

AZC.On("ServerEvent", function(ev)
    if ev.t == "DEFINITION_UPDATED" then
        Invalidate(nil)
        D.RequestZone(0, false)
        AZC.Fire("DataChanged", "reset")
        return
    end
    if ev.t == "RETROACTIVE" then return end
    if ev.t == "REGION_COMPLETED" then
        D.regions = nil
        AZC.Fire("DataChanged", "regions")
        return
    end
    -- the server changed something in zone z: forget what we knew and ask again
    local zoneId = AZC.Num(ev.z)
    if zoneId > 0 then
        Invalidate(zoneId)
        D.RequestZone(zoneId, false)
        AZC.Fire("DataChanged", "reset", zoneId)
    end
end)
