local state = require("src.menu.state")
local config = require("src.constants.menu_config")
local mathu = require("src.utils.menu_math")

local UI = state.UI

local M = {}

local function ensureBgCanvas(sw, sh)
    if UI.bgCanvas and UI.bgCanvas:getWidth() == sw and UI.bgCanvas:getHeight() == sh then
        return
    end
    if UI.bgCanvas then
        UI.bgCanvas:release()
        UI.bgCanvas = nil
    end
    UI.bgCanvas = love.graphics.newCanvas(sw, sh)
    UI.bgCanvas:setFilter("linear", "linear")
end

local function drawBackgroundLayers(sw, sh)
    UI.bgShader:send("time", UI.timer)
    UI.bgShader:send("screenSize", { sw, sh })
    love.graphics.setShader(UI.bgShader)

    if UI.bgImage then
        love.graphics.setColor(1, 1, 1, 0.76)
        local iw, ih = UI.bgImage:getDimensions()
        local sc = math.max(sw / iw, sh / ih)
        local ox = (sw - iw * sc) * 0.5
        local oy = (sh - ih * sc) * 0.5
        love.graphics.draw(UI.bgImage, ox, oy, 0, sc, sc)
    end

    local br, bgc, bb = mathu.getCyclingBackgroundRgb(UI.timer)
    love.graphics.setColor(br, bgc, bb, UI.bgImage and 0.94 or 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    love.graphics.setColor(0, 0, 0, 0.07)
    love.graphics.circle("fill", sw / 2, sh / 2, sw * 0.8)

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 0.095)

    local centerX, centerY = sw * 0.75, sh * 0.45
    local radius = 700 * UI.scale
    local rot = UI.timer * 0.006

    for i = 0, 11 do
        local angle = math.rad(i * 30) + rot
        love.graphics.line(centerX, centerY, centerX + math.cos(angle) * radius, centerY + math.sin(angle) * radius)
    end
    for i = 1, 5 do
        love.graphics.circle("line", centerX, centerY, (radius / 5) * i)
    end

    love.graphics.setShader()
end

function M.draw()
    local sw, sh = love.graphics.getDimensions()
    ensureBgCanvas(sw, sh)

    love.graphics.setCanvas(UI.bgCanvas)
    love.graphics.clear(0, 0, 0, 1)
    drawBackgroundLayers(sw, sh)
    love.graphics.setCanvas()

    UI.bgPostShader:send("time", UI.timer)
    UI.bgPostShader:send("screenSize", { sw, sh })
    love.graphics.setShader(UI.bgPostShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(UI.bgCanvas, 0, 0)
    love.graphics.setShader()
end

return M
