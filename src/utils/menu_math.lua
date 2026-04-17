local config = require("src.constants.menu_config")

local M = {}

function M.smootherstep01(t)
    t = math.max(0, math.min(1, t))
    return t * t * t * (t * (t * 6 - 15) + 10)
end

function M.getCyclingBackgroundRgb(timer)
    local n = #config.BG_CYCLE_COLORS
    local u = (timer / config.BG_CYCLE_SECONDS) % 1 * n
    local i0 = math.floor(u) % n + 1
    local i1 = i0 % n + 1
    local t = M.smootherstep01(u - math.floor(u))
    local a, b = config.BG_CYCLE_COLORS[i0], config.BG_CYCLE_COLORS[i1]
    return a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
        a[3] + (b[3] - a[3]) * t
end

function M.gamePlaceholderTypewriterProgress(typeT)
    if typeT <= 0 then
        return 0
    end
    local s = config.GAME_PLACEHOLDER_TEXT
    local acc = 0
    for i = 1, #s do
        local d = config.GAME_PLACEHOLDER_TYPE_DELAYS[i]
        if typeT < acc + d then
            return (i - 1) + (typeT - acc) / d
        end
        acc = acc + d
    end
    return #s
end

return M
