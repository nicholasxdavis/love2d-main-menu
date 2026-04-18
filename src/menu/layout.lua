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
    return UI.submenu == "options" and UI.menuOptionsTarget > 0.5
end

function M.menuShowsSavesDetail()
    return UI.submenu == "saves" and UI.menuOptionsTarget > 0.5
end

-- Expanded left-column layout (bigger rows, shifted pill) for options or saves.
function M.menuInSubmenuLayout()
    return UI.submenu ~= nil and UI.menuOptionsTarget > 0.5
end

function M.getMenuLabels()
    if M.menuShowsSavesDetail() then
        return UI.savesMenuLabels
    end
    if M.menuShowsOptionsDetail() then
        return UI.optionsDetail
    end
    return UI.options
end

function M.refreshSavesMenuLabels()
    local slots = UI.savesSlots or {}
    local t = {}
    for i = 1, 3 do
        local s = slots[i]
        if s and s.exists then
            local name = s.name or ("Save " .. i)
            if #name > 22 then
                name = name:sub(1, 21) .. ".."
            end
            t[i] = string.format("SLOT %d   %s", i, name)
        else
            t[i] = string.format("SLOT %d   (empty)", i)
        end
    end
    t[4] = "BACK"
    UI.savesMenuLabels = t
end

function M.closeSavesMenuLayout()
    UI.menuOptionsTarget = 0
    UI.submenu = nil
    UI.selection = UI.savesReturnSelection or 1
    UI.lerpSelection = UI.selection
    UI.lerpVel = 0
    UI.settingsDrag = nil
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
        local ax = M.menuInSubmenuLayout() and M.optionsPillCenterX(rs) or M.rowCenterX(UI.menuOptionsT)
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
    UI.submenu = nil
    UI.selection = 3
    UI.lerpSelection = 3
    UI.lerpVel = 0
    UI.settingsDrag = nil
end

--- @return integer|nil slotIndex If non-nil, caller should start the game in that save slot.
function M.activateMenuOption(index)
    if UI.irisActive or UI.view == "game" then
        return nil
    end
    local labels = M.getMenuLabels()
    local label = labels[index]

    if M.menuShowsOptionsDetail() then
        if label == "BACK" then
            M.closeOptionsMenuLayout()
        end
        return nil
    end

    if M.menuShowsSavesDetail() then
        if label == "BACK" then
            M.closeSavesMenuLayout()
            return nil
        end
        if index >= 1 and index <= 3 then
            local slot = UI.savesSlots and UI.savesSlots[index]
            if UI.savesMode == "resume" and not (slot and slot.exists) then
                return nil
            end
            return index
        end
        return nil
    end

    if label == "RESUME" or label == "NEW GAME" then
        if UI.submenu == "options" then
            return nil
        end
        local saves = require("src.menu.saves")
        UI.submenu = "saves"
        UI.savesMode = (label == "NEW GAME") and "new" or "resume"
        UI.savesSlots = saves.loadAll()
        M.refreshSavesMenuLabels()
        UI.savesReturnSelection = index
        UI.menuOptionsTarget = 1
        local opt = UI.optionsSound
        if opt then
            opt:stop()
            opt:seek(0)
            opt:play()
        end
        return nil
    elseif label == "OPTIONS" then
        UI.submenu = "options"
        UI.menuOptionsTarget = 1
        local opt = UI.optionsSound
        if opt then
            opt:stop()
            opt:seek(0)
            opt:play()
        end
        return nil
    elseif label == "EXIT" then
        love.event.quit()
    end
    return nil
end

return M
