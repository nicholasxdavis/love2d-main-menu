local state = require("src.menu.state")
local config = require("src.constants.menu_config")
local layout = require("src.menu.layout")
local mathu = require("src.utils.menu_math")

local UI = state.UI

local M = {}

function M.getPreviewImageScreenRect()
    local x0, y0, pw, ph = layout.getPreviewLayout()
    local sx = math.floor(UI.offsetX + x0 * UI.scale + 0.5)
    local sy = math.floor(UI.offsetY + y0 * UI.scale + 0.5)
    local sw = math.max(1, math.floor(pw * UI.scale + 0.5))
    local imageH = ph - config.PREVIEW_FOOTER_H
    local shImg = math.max(1, math.floor(imageH * UI.scale + 0.5))
    return sx, sy, sw, shImg
end

function M.updateShotCycle()
    if not (UI.previewImage and UI.previewImage2) then
        UI.previewShotMix = 0
        return
    end
    local hold, xfd = config.PREVIEW_SHOT_HOLD, config.PREVIEW_SHOT_CROSSFADE
    local period = 2 * (hold + xfd)
    local t = UI.timer % period
    if t < hold then
        UI.previewShotMix = 0
    elseif t < hold + xfd then
        UI.previewShotMix = mathu.smootherstep01((t - hold) / xfd)
    elseif t < hold + xfd + hold then
        UI.previewShotMix = 1
    elseif t < period then
        UI.previewShotMix = 1 - mathu.smootherstep01((t - hold - xfd - hold) / xfd)
    else
        UI.previewShotMix = 0
    end
end

function M.updateHoverMix(dt)
    if UI.submenu == "saves" then
        UI.previewHoverMix = 0
        UI.lastPreviewImgHover = false
        return
    end
    if layout.menuShowsOptionsDetail() then
        UI.previewHoverMix = 0
        UI.lastPreviewImgHover = false
        return
    end
    if not (UI.previewImage or UI.previewImage2) then
        UI.previewHoverMix = 0
        UI.lastPreviewImgHover = false
        return
    end
    local _, _, _, ph = layout.getPreviewLayout()
    local imageH = ph - config.PREVIEW_FOOTER_H
    if imageH <= 8 then
        UI.previewHoverMix = 0
        UI.lastPreviewImgHover = false
        return
    end
    local sx, sy, sw, shImg = M.getPreviewImageScreenRect()
    local mx, my = love.mouse.getPosition()
    local hover = mx >= sx and mx < sx + sw and my >= sy and my < sy + shImg
    if hover and not UI.lastPreviewImgHover and not UI.irisActive then
        layout.playHoverSound()
    end
    UI.lastPreviewImgHover = hover
    local target = hover and 1 or 0
    local k = config.PREVIEW_HOVER_LERP_RATE
    UI.previewHoverMix = UI.previewHoverMix + (target - UI.previewHoverMix) * (1 - math.exp(-k * dt))
end

function M.drawPanel()
    local fp = 1 - layout.menuOptionsEase()
    local x0, y0, pw, ph = layout.getPreviewLayout()
    local sx, sy, sw, shImg = M.getPreviewImageScreenRect()
    local sh = math.max(1, math.floor(ph * UI.scale + 0.5))
    local o = config.PREVIEW_OUTLINE_PX

    local imageH = ph - config.PREVIEW_FOOTER_H

    local ox, oy, drawW, drawH, sc
    -- Save-slot picker: keep the preview *chrome* (cream panel + footer) but hide
    -- the busy screenshot so the slot UI reads as part of this panel, not a sticker.
    local layoutImg = (UI.submenu ~= "saves") and (UI.previewImage or UI.previewImage2) or nil
    if layoutImg and imageH > 8 then
        local iw, ih = layoutImg:getDimensions()
        sc = math.max(pw / iw, imageH / ih)
        drawW, drawH = iw * sc, ih * sc
        ox = x0 + (pw - drawW) * 0.5
        oy = y0 + (imageH - drawH) * 0.5
    end

    love.graphics.push()
    love.graphics.translate(UI.offsetX, UI.offsetY)
    love.graphics.scale(UI.scale)

    love.graphics.setColor(0.99, 0.99, 0.98, fp)
    love.graphics.rectangle("fill", x0, y0, pw, ph)

    love.graphics.pop()

    if ox then
        local gx = math.floor(UI.offsetX + ox * UI.scale + 0.5)
        local gy = math.floor(UI.offsetY + oy * UI.scale + 0.5)
        local imgSc = sc * UI.scale
        love.graphics.setScissor(sx, sy, sw, shImg)
        UI.previewShader:send("colorBlend", UI.previewHoverMix)
        love.graphics.setShader(UI.previewShader)
        local mix = UI.previewShotMix
        if UI.previewImage2 then
            if mix < 0.998 then
                love.graphics.setColor(1, 1, 1, (1 - mix) * fp)
                love.graphics.draw(UI.previewImage, gx, gy, 0, imgSc, imgSc)
            end
            if mix > 0.002 then
                love.graphics.setColor(1, 1, 1, mix * fp)
                love.graphics.draw(UI.previewImage2, gx, gy, 0, imgSc, imgSc)
            end
        else
            love.graphics.setColor(1, 1, 1, fp)
            love.graphics.draw(UI.previewImage, gx, gy, 0, imgSc, imgSc)
        end
        love.graphics.setShader()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setScissor()
    end

    local fy = y0 + imageH
    love.graphics.push()
    love.graphics.translate(UI.offsetX, UI.offsetY)
    love.graphics.scale(UI.scale)

    local cr, cg, cb = mathu.getCyclingBackgroundRgb(UI.timer)
    love.graphics.setColor(cr, cg, cb, fp)
    love.graphics.rectangle("fill", x0, fy, pw, config.PREVIEW_FOOTER_RULE_VIRT)

    love.graphics.setColor(1, 1, 1, fp)
    love.graphics.rectangle("fill", x0, fy + config.PREVIEW_FOOTER_RULE_VIRT, pw, config.PREVIEW_FOOTER_H - config.PREVIEW_FOOTER_RULE_VIRT)

    love.graphics.pop()

    local textPadX, textPadY = 18, 12
    local txtX = math.floor(UI.offsetX + (x0 + textPadX) * UI.scale + 0.5)
    local txtY = math.floor(UI.offsetY + (fy + config.PREVIEW_FOOTER_RULE_VIRT + textPadY) * UI.scale + 0.5)
    local wrapPx = math.max(48, math.floor((pw - textPadX * 2) * UI.scale + 0.5))
    love.graphics.setShader()
    love.graphics.setFont(UI.fontPreviewUpdate or UI.fontFooter)
    love.graphics.setColor(0.14, 0.14, 0.16, fp)
    love.graphics.printf(UI.updateInfoText, txtX, txtY, wrapPx, "left")

    love.graphics.setColor(1, 1, 1, fp)
    love.graphics.rectangle("fill", sx - o, sy - o, sw + o * 2, o)
    love.graphics.rectangle("fill", sx - o, sy + sh, sw + o * 2, o)
    love.graphics.rectangle("fill", sx - o, sy, o, sh)
    love.graphics.rectangle("fill", sx + sw, sy, o, sh)
end

return M
