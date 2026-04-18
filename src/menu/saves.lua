local M = {}

M.NUM_SLOTS = 3

local function slotPath(n)
    return "saves/slot_" .. n .. ".txt"
end

function M.formatPlaytime(secs)
    local s = math.floor(secs or 0)
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local sc = s % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, sc)
    end
    return string.format("%d:%02d", m, sc)
end

function M.loadSlot(n)
    if not love.filesystem.getInfo(slotPath(n)) then
        return { exists = false }
    end
    local text = love.filesystem.read(slotPath(n))
    if not text then
        return { exists = false }
    end
    local d = { exists = true }
    for line in text:gmatch("[^\r\n]+") do
        local k, v = line:match("^([%w_]+)=(.*)$")
        if k then
            if k == "playtime" or k == "chapter" then
                d[k] = tonumber(v) or 0
            else
                d[k] = v
            end
        end
    end
    return d
end

function M.loadAll()
    local t = {}
    for i = 1, M.NUM_SLOTS do
        t[i] = M.loadSlot(i)
    end
    return t
end

function M.writeSlot(n, data)
    love.filesystem.createDirectory("saves")
    local lines = {
        "name=" .. (data.name or ("Slot " .. n)),
        "timestamp=" .. os.date("%Y-%m-%d %H:%M"),
        string.format("playtime=%.1f", data.playtime or 0),
        "level=" .. (data.level or "World 1-1"),
        string.format("chapter=%d", data.chapter or 1),
    }
    love.filesystem.write(slotPath(n), table.concat(lines, "\n"))
end

return M
