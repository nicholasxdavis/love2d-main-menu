local state = require("src.menu.state")
local config = require("src.constants.menu_config")
local layout = require("src.menu.layout")

local UI = state.UI

local M = {}

function M.draw()
    local inSettings = layout.menuShowsOptionsDetail()
    local fadeRest = inSettings and 1 or (1 - layout.menuOptionsEase())
    local logoA = inSettings and 0 or (1 - layout.menuOptionsEase())

    love.graphics.push()
    love.graphics.translate(UI.offsetX, UI.offsetY)
    love.graphics.scale(UI.scale)

    local logoHover = math.sin(UI.timer * 1.5) * 10
    local logoScale = layout.getLogoDrawScale() * 0.8
    local bannerShadowOx, bannerShadowOy = 5, 7

    UI.uiShader:send("time", UI.timer)
    love.graphics.setShader(UI.uiShader)

    if logoA > 0.01 then
        love.graphics.setColor(0, 0, 0, 0.2 * logoA)
        love.graphics.draw(
            UI.logo,
            config.LOGO_X + bannerShadowOx,
            config.LOGO_Y + logoHover + bannerShadowOy,
            0,
            logoScale,
            logoScale
        )

        love.graphics.setColor(1, 1, 1, logoA)
        love.graphics.draw(UI.logo, config.LOGO_X, config.LOGO_Y + logoHover, 0, logoScale, logoScale)
    end

    local te = layout.menuOptionsEase()
    local ax = layout.rowCenterX(UI.menuOptionsT)
    local rs = 1 + (config.MENU_OPTIONS_SCALE_MAX - 1) * te
    local bannerAx = inSettings and layout.optionsPillCenterX(rs) or ax
    local selTy = layout.interpRowMetric(UI.lerpSelection, function(ii)
        return layout.rowTextY(ii, UI.menuOptionsT)
    end)
    love.graphics.translate(bannerAx, selTy + config.MENU_OPTIONS_BANNER_PIVOT_Y)
    love.graphics.scale(rs)
    love.graphics.setColor(0, 0, 0, 0.2)
    love.graphics.polygon("fill", -235, -33, 275, -33, 245, 40, -265, 40)
    love.graphics.setColor(1, 1, 1)
    love.graphics.polygon("fill", -240, -36.5, 270, -36.5, 240, 36.5, -270, 36.5)

    love.graphics.setShader()
    love.graphics.pop()

    love.graphics.setFont(UI.fontMain)
    for i, label in ipairs(layout.getMenuLabels()) do
        local ty = layout.rowTextY(i, UI.menuOptionsT)
        local axRow = layout.rowCenterX(UI.menuOptionsT)
        local axDraw = inSettings and layout.optionsPillCenterX(rs) or axRow
        local sx = UI.offsetX + axDraw * UI.scale
        local sy = UI.offsetY + ty * UI.scale
        local isSelected = (i == UI.selection)
        local w = UI.fontMain:getWidth(label)
        local leftScr = UI.offsetX + axDraw * UI.scale - w * rs * 0.5
        local lx = (leftScr - sx) / rs

        love.graphics.push()
        love.graphics.translate(sx, sy)
        love.graphics.scale(rs)

        if isSelected then
            local cappyBounce = math.abs(math.sin(UI.timer * 5)) * 5
            love.graphics.setColor(0.08, 0.08, 0.08, 1)
            if not inSettings then
                local iconR = math.max(3, math.floor(14 * UI.scale + 0.5)) * rs
                local iconScr = leftScr - config.MENU_BTN_ICON_TEXT_GAP_SCREEN_PX * UI.scale - iconR + cappyBounce * UI.scale
                local ix = (iconScr - sx) / rs
                local iy = (32 * UI.scale) / rs
                local crScreen = math.max(3, math.floor(14 * UI.scale + 0.5))
                if UI.menuBtnIcon then
                    local iw, ih = UI.menuBtnIcon:getDimensions()
                    local diam = 2 * crScreen
                    local iconSc = diam / math.max(iw, ih)
                    love.graphics.draw(UI.menuBtnIcon, ix, iy, 0, iconSc, iconSc, iw * 0.5, ih * 0.5)
                else
                    love.graphics.circle("fill", ix, iy, crScreen)
                end
            end
            love.graphics.setColor(0.08, 0.08, 0.08)
        else
            love.graphics.setColor(0.98, 0.98, 1, 0.94)
        end

        local labelDy = 0
        if inSettings then
            labelDy = config.MENU_OPTIONS_DETAIL_BASELINE_NUDGE_SCREEN_PX / rs
            local lift = UI.optionsDetailHoverLift[i] or 0
            labelDy = labelDy - (config.MENU_OPTIONS_DETAIL_HOVER_LIFT_SCREEN_PX / rs) * lift
        end
        love.graphics.print(label, lx, labelDy)
        love.graphics.pop()
    end

    love.graphics.push()
    love.graphics.translate(UI.offsetX, UI.offsetY)
    love.graphics.scale(UI.scale)
    love.graphics.setShader()
    love.graphics.setFont(UI.fontVersion)
    local verText = "VERSION 1.0"
    local vm = 36
    local vx = UI.V_WIDTH - vm - UI.fontVersion:getWidth(verText)
    local vy = UI.V_HEIGHT - vm - UI.fontVersion:getHeight()
    local verA = inSettings and 0.96 or (0.96 * fadeRest)
    love.graphics.setColor(0, 0, 0, 0.42 * verA)
    love.graphics.print(verText, vx + 2, vy + 2)
    love.graphics.setColor(0.98, 0.98, 1, verA)
    love.graphics.print(verText, vx, vy)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

return M
