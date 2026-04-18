-- Supplemental copy in the preview panel while the save-slot submenu is open
-- (main interaction uses the same scaled menu rows as Options).

local state  = require("src.menu.state")
local layout = require("src.menu.layout")
local config = require("src.constants.menu_config")
local mathu  = require("src.utils.menu_math")
local saves  = require("src.menu.saves")

local UI = state.UI
local M  = {}

function M.drawRightPanel()
    if not layout.menuShowsSavesDetail() then
        return
    end

    local sel = UI.selection
    if sel < 1 or sel > 3 then
        return
    end

    local px, py, pw, ph = layout.getPreviewLayout()
    local imageH = ph - config.PREVIEW_FOOTER_H
    local slot = UI.savesSlots and UI.savesSlots[sel] or { exists = false }

    love.graphics.push()
    love.graphics.translate(UI.offsetX, UI.offsetY)
    love.graphics.scale(UI.scale)

    local vr = layout.settingsVirtRound
    local outerPad = 28
    local ix = vr(px + outerPad)
    local iy = vr(py + outerPad)
    local iw = vr(pw - outerPad * 2)
    local ih = vr(imageH - outerPad * 2 - 10)

    -- Match settings_panel chrome: white body, cycling top rule, soft border.
    love.graphics.setColor(0.99, 0.99, 1, 0.97)
    love.graphics.rectangle("fill", ix, iy, iw, ih)
    local cr, cg, cb = mathu.getCyclingBackgroundRgb(UI.timer)
    love.graphics.setColor(cr, cg, cb, 1)
    love.graphics.rectangle("fill", ix + 18, iy + 3, iw - 36, 4)
    love.graphics.setColor(0.55, 0.57, 0.64, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", ix + 0.5, iy + 0.5, iw - 1, ih - 1)

    love.graphics.setFont(UI.fontPreviewUpdate or UI.fontFooter)
    local font = UI.fontPreviewUpdate or UI.fontFooter
    local lh = font:getHeight() * 1.12
    local innerPad = config.SETTINGS_INNER_PAD_X
    local x = ix + innerPad
    local y = iy + 52

    love.graphics.setColor(0.14, 0.14, 0.16, 0.88)
    if slot.exists then
        love.graphics.print(slot.name or ("Save " .. sel), x, y)
        y = y + lh
        love.graphics.setColor(0.22, 0.22, 0.26, 0.82)
        love.graphics.print(slot.level or "World 1-1", x, y)
        y = y + lh
        love.graphics.print("Play time: " .. saves.formatPlaytime(slot.playtime), x, y)
        y = y + lh
        love.graphics.setColor(0.38, 0.38, 0.42, 0.72)
        love.graphics.print(slot.timestamp or "", x, y)
    else
        love.graphics.print("Empty slot", x, y)
        y = y + lh
        love.graphics.setColor(0.32, 0.32, 0.36, 0.78)
        if UI.savesMode == "new" then
            love.graphics.print("Press ENTER to start a new game here.", x, y)
        else
            love.graphics.print("No save in this slot.", x, y)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.pop()
end

return M
