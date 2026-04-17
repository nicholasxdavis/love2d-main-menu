local state = require("src.menu.state")
local config = require("src.constants.menu_config")
local fonts = require("src.utils.menu_fonts")
local mathu = require("src.utils.menu_math")

local UI = state.UI

local M = {}

function M.screenToVirtual(mx, my)
    return (mx - UI.offsetX) / UI.scale, (my - UI.offsetY) / UI.scale
end

function M.virtToScreen(vx, vy)
    return math.floor(UI.offsetX + vx * UI.scale + 0.5), math.floor(UI.offsetY + vy * UI.scale + 0.5)
end

function M.virtPointInRect(vx, vy, rx, ry, rw, rh)
    return vx >= rx and vx <= rx + rw and vy >= ry and vy <= ry + rh
end

function M.getPreviewLayout()
    local pw, ph = config.PREVIEW_W, config.PREVIEW_H
    local px = UI.V_WIDTH - config.PREVIEW_MARGIN_RIGHT - pw
    local py = (UI.V_HEIGHT - ph) * 0.5
    return px, py, pw, ph
end

function M.getLogoDrawScale()
    local lw = UI.logo:getDimensions()
    return (config.LOGO_TARGET_W / lw) * config.LOGO_SCALE_MUL
end

function M.menuShowsOptionsDetail()
    return UI.menuOptionsTarget > 0.5
end

function M.getMenuLabels()
    if M.menuShowsOptionsDetail() then
        return UI.optionsDetail
    end
    return UI.options
end

function M.menuOptionCount()
    return #M.getMenuLabels()
end

function M.settingsVirtRound(n)
    return math.floor(n + 0.5)
end

function M.settingsPanelVirtBounds()
    local pwNominal, ph = config.SETTINGS_PANEL_W, config.SETTINGS_PANEL_H
    local rightX = UI.V_WIDTH - config.PREVIEW_MARGIN_RIGHT
    local maxW = math.max(320, rightX - config.SETTINGS_PANEL_MIN_LEFT_X)
    local pw = math.min(pwNominal, maxW)
    local px = rightX - pw
    local py = (UI.V_HEIGHT - ph) * 0.5
    return px, py, pw, ph
end

function M.updateLayout()
    local w, h = love.graphics.getDimensions()
    UI.scale = math.min(w / UI.V_WIDTH, h / UI.V_HEIGHT)
    UI.offsetX = math.floor((w - UI.V_WIDTH * UI.scale) * 0.5 + 0.5)
    UI.offsetY = math.floor((h - UI.V_HEIGHT * UI.scale) * 0.5 + 0.5)
    fonts.refreshUiFonts(UI)
    fonts.refreshSettingsFonts(UI)
end

function M.menuOptionsEase()
    return mathu.smootherstep01(UI.menuOptionsT)
end

function M.rowCenterX(tMo)
    local te = mathu.smootherstep01(tMo)
    return config.MENU_PILL_CENTER_X + (UI.V_WIDTH * 0.5 - config.MENU_PILL_CENTER_X) * te
end

function M.optionsPillCenterX(rowScale)
    local minCx = config.MENU_PILL_LOCAL_LEFT * rowScale + config.MENU_PILL_SCREEN_PAD_VIRT
    return math.max(config.MENU_PILL_CENTER_X, minCx)
end

function M.rowTextY(i, tMo)
    local te = mathu.smootherstep01(tMo)
    local spacing = config.MENU_SPACING + config.MENU_OPTIONS_SPACING_ADD * te
    local origY = config.MENU_START_Y + (i - 1) * config.MENU_SPACING
    local mid = UI.V_HEIGHT * 0.5
    local span = (M.menuOptionCount() - 1) * spacing
    local tgtY = mid - span * 0.5 + (i - 1) * spacing
    return origY + (tgtY - origY) * te
end

function M.interpRowMetric(ls, fn)
    local n = M.menuOptionCount()
    if n < 1 then
        return 0
    end
    if ls <= 1 then
        return fn(1)
    end
    if ls >= n then
        return fn(n)
    end
    local il = math.floor(ls)
    local fh = ls - il
    return (1 - fh) * fn(il) + fh * fn(il + 1)
end

function M.getMenuIndexAtVirtual(vx, vy)
    local te = M.menuOptionsEase()
    for i = 1, M.menuOptionCount() do
        local ty = M.rowTextY(i, UI.menuOptionsT)
        local rs = 1 + (config.MENU_OPTIONS_SCALE_MAX - 1) * te
        local y0, y1 = ty - 12 * rs, ty + 80 * rs
        local ax = M.menuShowsOptionsDetail() and M.optionsPillCenterX(rs) or M.rowCenterX(UI.menuOptionsT)
        local halfW = (0.5 * (540 * (1 - te) + 620 * te)) * rs
        local x0, x1 = ax - halfW, ax + halfW
        if vx >= x0 and vx <= x1 and vy >= y0 and vy <= y1 then
            return i
        end
    end
    return nil
end

function M.playHoverSound()
    local gs = UI.gameStartSound
    if gs and gs:isPlaying() then
        return
    end
    local s = UI.hoverSound
    if not s then
        return
    end
    s:stop()
    s:seek(0)
    s:play()
end

function M.closeOptionsMenuLayout()
    UI.menuOptionsTarget = 0
    UI.selection = 3
    UI.lerpSelection = 3
    UI.lerpVel = 0
    UI.settingsDrag = nil
end

function M.activateMenuOption(index)
    if UI.irisActive or UI.view == "game" then
        return
    end
    local labels = M.getMenuLabels()
    local label = labels[index]
    if label == "RESUME" or label == "NEW GAME" then
        local h = UI.hoverSound
        if h then
            h:stop()
        end
        local g = UI.gameStartSound
        if g then
            g:stop()
            g:seek(0)
            g:play()
        end
        UI.irisActive = true
        UI.irisTime = 0
    elseif label == "OPTIONS" then
        UI.menuOptionsTarget = 1
        local opt = UI.optionsSound
        if opt then
            opt:stop()
            opt:seek(0)
            opt:play()
        end
    elseif label == "BACK" then
        M.closeOptionsMenuLayout()
    elseif label == "EXIT" then
        love.event.quit()
    end
end

return M
