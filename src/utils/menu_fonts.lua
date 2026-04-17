local config = require("src.constants.menu_config")

local M = {}

local REF_MAIN_LINE_H, REF_FOOT_LINE_H, REF_VERSION_LINE_H

function M.captureDefaultFontLineHeights()
    local fm = love.graphics.newFont(52)
    REF_MAIN_LINE_H = fm:getHeight()
    fm:release()
    local ff = love.graphics.newFont(28)
    REF_FOOT_LINE_H = ff:getHeight()
    ff:release()
    local fv = love.graphics.newFont(40)
    REF_VERSION_LINE_H = fv:getHeight()
    fv:release()
end

function M.newFontFitLineHeight(path, requestedPx, targetLineH, minSize)
    minSize = minSize or 15
    local size = math.max(minSize, math.floor(requestedPx + 0.5))
    local ok, font = pcall(love.graphics.newFont, path, size)
    if not ok then
        return love.graphics.newFont(size)
    end
    local guard = 0
    while font:getHeight() > targetLineH + 0.5 and size > minSize and guard < 48 do
        font:release()
        size = size - 1
        ok, font = pcall(love.graphics.newFont, path, size)
        if not ok then
            return love.graphics.newFont(math.max(minSize, size))
        end
        guard = guard + 1
    end
    return font
end

function M.refreshUiFonts(UI)
    if not UI.scale or UI.scale <= 0 then
        return
    end
    local mainPx = math.max(24, math.floor(52 * UI.scale + 0.5))
    local footPx = math.max(16, math.floor(28 * UI.scale + 0.5))
    if mainPx ~= UI.fontMainPx then
        if UI.fontMain then
            UI.fontMain:release()
        end
        local targetMainH = REF_MAIN_LINE_H and (REF_MAIN_LINE_H * mainPx / 52) or mainPx
        UI.fontMain = M.newFontFitLineHeight(config.FONT_MENU_BOLD, mainPx, targetMainH, 24)
        UI.fontMainPx = mainPx
    end
    if footPx ~= UI.fontFooterPx then
        if UI.fontFooter then
            UI.fontFooter:release()
        end
        local targetFootH = REF_FOOT_LINE_H and (REF_FOOT_LINE_H * footPx / 28) or footPx
        UI.fontFooter = M.newFontFitLineHeight(config.FONT_MENU, footPx, targetFootH)
        UI.fontFooterPx = footPx
    end
    -- Preview panel footer strip: taller than global footer font (matches preview.lua textPadY 12 * 2).
    local previewPadY2 = 24
    local previewInnerVirt = config.PREVIEW_FOOTER_H - config.PREVIEW_FOOTER_RULE_VIRT - previewPadY2
    local targetPreviewUpdateH = previewInnerVirt * UI.scale
    local previewUpdatePx = math.max(24, math.floor(48 * UI.scale + 0.5))
    local previewTargetKey = math.floor(targetPreviewUpdateH + 0.5)
    if previewUpdatePx ~= UI.fontPreviewUpdatePx or previewTargetKey ~= UI.fontPreviewUpdateTargetPx then
        if UI.fontPreviewUpdate then
            UI.fontPreviewUpdate:release()
        end
        UI.fontPreviewUpdate = M.newFontFitLineHeight(config.FONT_MENU, previewUpdatePx, targetPreviewUpdateH, 18)
        UI.fontPreviewUpdatePx = previewUpdatePx
        UI.fontPreviewUpdateTargetPx = previewTargetKey
    end
    local versionPx = math.max(22, math.floor(40 * UI.scale + 0.5))
    if versionPx ~= UI.fontVersionPx then
        if UI.fontVersion then
            UI.fontVersion:release()
        end
        local targetVerH = REF_VERSION_LINE_H and (REF_VERSION_LINE_H * versionPx / 40) or versionPx
        UI.fontVersion = M.newFontFitLineHeight(config.FONT_MENU, versionPx, targetVerH, 22)
        UI.fontVersionPx = versionPx
    end
end

function M.refreshSettingsFonts(UI)
    if not UI.scale or UI.scale <= 0 then
        return
    end
    local mainPx = math.max(30, math.floor(66 * UI.scale + 0.5))
    local footPx = math.max(20, math.floor(38 * UI.scale + 0.5))
    if mainPx ~= UI.fontSettingsMainPx then
        if UI.fontSettingsMain then
            UI.fontSettingsMain:release()
        end
        local targetMainH = REF_MAIN_LINE_H and (REF_MAIN_LINE_H * mainPx / 52) or mainPx
        UI.fontSettingsMain = M.newFontFitLineHeight(config.FONT_MENU_BOLD, mainPx, targetMainH, 24)
        UI.fontSettingsMainPx = mainPx
    end
    if footPx ~= UI.fontSettingsFootPx then
        if UI.fontSettingsFoot then
            UI.fontSettingsFoot:release()
        end
        local targetFootH = REF_FOOT_LINE_H and (REF_FOOT_LINE_H * footPx / 28) or footPx
        UI.fontSettingsFoot = M.newFontFitLineHeight(config.FONT_MENU, footPx, targetFootH)
        UI.fontSettingsFootPx = footPx
    end
end

return M
