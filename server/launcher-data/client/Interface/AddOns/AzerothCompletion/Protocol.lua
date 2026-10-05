-- Azeroth Completion: the versioned addon protocol (see PROTOCOL.md in the server module).
--   out: "<reqId> <COMMAND> args"            (addon message, prefix AZC)
--   in:  "R<reqId> <seq>/<total> <chunk>"    response
--        "E<n> <seq>/<total> <chunk>"        event
-- A payload is records separated by ';', fields "^key=value", values %XX-escaped.

local AZC = AZC
local P = {}
AZC.Protocol = P

-- status: "connecting" | "ready" | "incompatible" | "unavailable"
P.status = "connecting"
P.proto = nil

local nextId = 0
local pending = {}      -- reqId -> { cmd, cb, sent }
local buffers = {}      -- "R12" -> { total, parts, got }
local TIMEOUT = 15

local function Decode(payload)
    local records = {}
    for _, raw in ipairs(AZC.Split(payload, ";")) do
        if raw ~= "" then
            local fields = AZC.Split(raw, "^")
            local rec = { type = fields[1] }
            for i = 2, table.getn(fields) do
                local f = fields[i]
                local eq = string.find(f, "=", 1, true)
                if eq then
                    rec[string.sub(f, 1, eq - 1)] = AZC.Unescape(string.sub(f, eq + 1))
                end
            end
            table.insert(records, rec)
        end
    end
    return records
end
P.Decode = Decode

local function Send(text)
    -- The server consumes AZC messages on any channel before relaying them. "GUILD" reaches it
    -- without a guild too; a group channel is used when there is one and no guild.
    local channel = "GUILD"
    if not IsInGuild() then
        if GetNumRaidMembers() > 0 then channel = "RAID"
        elseif GetNumPartyMembers() > 0 then channel = "PARTY" end
    end
    SendAddonMessage(AZC.PREFIX, text, channel)
end

-- Sends a request; cb(records, errorRecord) is called once.
function P.Request(cmd, args, cb)
    nextId = nextId + 1
    if nextId > 99999 then nextId = 1 end
    local id = nextId
    local text = id .. " " .. cmd
    if args and args ~= "" then text = text .. " " .. args end
    pending[id] = { cmd = cmd, cb = cb, sent = GetTime() }
    Send(text)
    AZC.After(TIMEOUT, function()
        local p = pending[id]
        if p then
            pending[id] = nil
            if p.cb then p.cb(nil, { type = "ERR", code = "TIMEOUT" }) end
        end
    end)
    return id
end

local function HandleEvent(records)
    for _, rec in ipairs(records) do
        if rec.type == "EV" then
            AZC.Fire("ServerEvent", rec)
        end
    end
end

local function Complete(kind, id, payload)
    local records = Decode(payload)
    if kind == "E" then
        if P.status == "ready" then HandleEvent(records) end
        return
    end
    local p = pending[id]
    if not p then return end
    pending[id] = nil
    local err
    for _, rec in ipairs(records) do
        if rec.type == "ERR" then err = rec end
    end
    if p.cb then p.cb(records, err) end
end

function P.OnMessage(msg)
    local _, _, kind, id, seq, total, chunk = string.find(msg, "^([RE])(%d+) (%d+)/(%d+) ?(.*)$")
    if not kind then return end
    id, seq, total = tonumber(id), tonumber(seq), tonumber(total)
    if total == 1 then
        Complete(kind, id, chunk)
        return
    end
    local key = kind .. id
    local buf = buffers[key]
    if not buf or buf.total ~= total then
        buf = { total = total, parts = {}, got = 0, started = GetTime() }
        buffers[key] = buf
    end
    if not buf.parts[seq] then
        buf.parts[seq] = chunk
        buf.got = buf.got + 1
    end
    if buf.got == total then
        buffers[key] = nil
        local all = {}
        for i = 1, total do table.insert(all, buf.parts[i] or "") end
        Complete(kind, id, table.concat(all))
    end
end

-- Version handshake. Until it succeeds nothing is shown as progress.
function P.Hello()
    P.status = "connecting"
    AZC.Fire("StatusChanged")
    P.Request("HELLO", tostring(AZC.PROTOCOL), function(records, err)
        if not records then
            P.status = "unavailable"
            AZC.Fire("StatusChanged")
            return
        end
        local proto
        for _, rec in ipairs(records) do
            if rec.type == "PROTO" then proto = rec end
        end
        if not proto then
            P.status = "unavailable"
        elseif AZC.Num(proto.min) > AZC.PROTOCOL or AZC.Num(proto.v) < AZC.PROTOCOL or (err and err.code == "CLIENT_TOO_OLD") then
            P.status = "incompatible"
        else
            P.status = "ready"
            P.proto = proto
        end
        AZC.Fire("StatusChanged")
    end)
end

function P.IsReady()
    return P.status == "ready"
end

-- Server hides unkilled rares itself? (0 strip, 1 flag, 2 reveal)
function P.HiddenMode()
    return P.proto and AZC.Num(P.proto.hid, 1) or 1
end

-- Drop stale partial messages now and then.
AZC.After(30, function()
    local function sweep()
        local now = GetTime()
        for key, buf in pairs(buffers) do
            if now - buf.started > 60 then buffers[key] = nil end
        end
        AZC.After(30, sweep)
    end
    sweep()
end)
