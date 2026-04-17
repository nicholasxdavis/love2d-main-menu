local state = require("src.menu.state")
local config = require("src.constants.menu_config")
local mathu = require("src.utils.menu_math")

local UI = state.UI

local M = {}

function M.drawIrisCloseToBlack()
    local sw, sh = love.graphics.getDimensions()
    local cx, cy = sw * 0.5, sh * 0.5
    local maxR = math.sqrt(cx * cx + cy * cy) + 8
    local p = mathu.smootherstep01(UI.irisTime / config.IRIS_OUT_DURATION)
    local r = maxR * (1 - p)

    love.graphics.stencil(function()
        love.graphics.circle("fill", cx, cy, math.max(r, 0))
    end, "replace", 1)
    love.graphics.setStencilTest("equal", 0)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    love.graphics.setStencilTest()
end

function M.drawGamePlaceholder()
    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    local typeT = (UI.gameScreenT or 0) - config.GAME_PLACEHOLDER_BLACK_HOLD
    local vis = mathu.gamePlaceholderTypewriterProgress(typeT)
    if vis <= 0 then
        return
    end

    local s = config.GAME_PLACEHOLDER_TEXT
    local n = math.floor(vis + 1e-8)
    local frac = vis - n
    local pre = s:sub(1, n)
    local cur = s:sub(n + 1, n + 1)

    love.graphics.setFont(UI.fontMain)
    local fh = UI.fontMain:getHeight()
    local y = sh * 0.5 - fh * 0.5
    local font = UI.fontMain
    local wPre = font:getWidth(pre)
    local wCur = (cur ~= "") and font:getWidth(cur) or 0
    local xStart = sw * 0.5 - (wPre + wCur) * 0.5

    love.graphics.setColor(0.96, 0.96, 0.98, 1)
    love.graphics.print(pre, xStart, y)
    if cur ~= "" then
        local ca = mathu.smootherstep01(frac)
        love.graphics.setColor(0.96, 0.96, 0.98, ca)
        love.graphics.print(cur, xStart + wPre, y)
    end

    local cursorBlink = (math.floor(UI.timer * 2.35) % 2) == 0
    if cursorBlink and vis < #s then
        local curs = "|"
        local wCurs = font:getWidth(curs)
        local cx = xStart + wPre + wCur * mathu.smootherstep01(frac)
        love.graphics.setColor(0.96, 0.96, 0.98, 0.82)
        love.graphics.print(curs, cx - wCurs * 0.35, y)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return M
