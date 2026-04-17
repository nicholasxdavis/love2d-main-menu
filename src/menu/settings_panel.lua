local state = require("src.menu.state")
local config = require("src.constants.menu_config")
local layout = require("src.menu.layout")
local audio = require("src.menu.audio")
local settings_persist = require("src.menu.settings_persist")
local music = require("src.menu.music")
local particles = require("src.menu.particles")

local UI = state.UI

local M = {}

local function audioSliderRows(x0, y0, pw)
    local pad = config.SETTINGS_INNER_PAD_X
    local tw = math.max(160, pw - pad * 2 - config.SETTINGS_PCT_COL)
    local baseY = y0 + 188
    local gap = 128
    return {
        { x = x0 + pad, y = baseY, w = tw, key = "master", label = "MASTER" },
        { x = x0 + pad, y = baseY + gap, w = tw, key = "music", label = "MUSIC" },
        { x = x0 + pad, y = baseY + gap * 2, w = tw, key = "sfx", label = "SOUND EFFECTS" },
    }
end

local function drawSettingsSliderVirt(x, y, w, val, label)
    local vr = layout.settingsVirtRound
    local vx, vy, vw = vr(x), vr(y), vr(w)
    local labY = vy - 58
    love.graphics.setFont(UI.fontSettingsMain or UI.fontMain)
    love.graphics.setColor(0.26, 0.27, 0.32, 1)
    love.graphics.print(label, vx, labY)
    local trackY = vy + 6
    local trackH = 16
    love.graphics.setColor(0.9, 0.91, 0.94, 1)
    love.graphics.rectangle("fill", vx, trackY, vw, trackH)
    love.graphics.setColor(0.72, 0.74, 0.8, 0.55)
    love.graphics.rectangle("line", vx + 0.5, trackY + 0.5, vw - 1, trackH - 1)
    local fillW = math.max(3, vr(vw * val))
    love.graphics.setColor(0.82, 0.14, 0.11, 1)
    love.graphics.rectangle("fill", vx, trackY, fillW, trackH)
    local cx = x + val * w
    cx = math.max(x + 12, math.min(x + w - 12, cx))
    local tcx, tcy = vr(cx) + 0.5, vr(trackY + trackH * 0.5) + 0.5
    local tr = 14
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", tcx, tcy, tr)
    love.graphics.setFont(UI.fontSettingsMain or UI.fontMain)
    love.graphics.setColor(0.28, 0.29, 0.34, 1)
    local pct = string.format("%d%%", math.floor(val * 100 + 0.5))
    local ptw = (UI.fontSettingsMain or UI.fontMain):getWidth(pct)
    love.graphics.print(pct, vx + vw + math.floor((config.SETTINGS_PCT_COL - ptw) * 0.5 + 0.5), labY)
end

local function drawSettingsTrapezoidRowVirt(bx, by, bw, bh, textStr)
    local vr = layout.settingsVirtRound
    bx, by, bw, bh = vr(bx), vr(by), vr(bw), vr(bh)
    local skewT, skewB, ins = 4, 10, 4
    love.graphics.setColor(0.99, 0.99, 1, 1)
    love.graphics.polygon("fill", bx, by + skewT, bx + bw, by, bx + bw - ins, by + bh, bx, by + bh + skewB)
    love.graphics.setColor(0.72, 0.74, 0.8, 0.65)
    love.graphics.setLineWidth(1)
    love.graphics.polygon(
        "line",
        bx + 0.5,
        by + skewT + 0.5,
        bx + bw - 0.5,
        by + 0.5,
        bx + bw - ins - 0.5,
        by + bh - 0.5,
        bx + 0.5,
        by + bh + skewB - 0.5
    )
    love.graphics.setLineWidth(1)
    local fsm = UI.fontSettingsMain or UI.fontMain
    love.graphics.setFont(fsm)
    local fh = fsm:getHeight()
    local fw = fsm:getWidth(textStr)
    love.graphics.setColor(0.22, 0.23, 0.28, 1)
    love.graphics.print(textStr, vr(bx + (bw - fw) * 0.5), vr(by + (bh - fh) * 0.5 + skewT * 0.28))
end

local function drawAudioSettingsVirt(x0, y0, pw, ph)
    local pad = config.SETTINGS_INNER_PAD_X
    local vr = layout.settingsVirtRound
    local fsm = UI.fontSettingsMain or UI.fontMain
    local fsf = UI.fontSettingsFoot or UI.fontFooter
    love.graphics.setFont(fsm)
    love.graphics.setColor(0.22, 0.23, 0.28, 1)
    love.graphics.print("LEVELS", vr(x0 + pad), vr(y0 + 40))
    love.graphics.setFont(fsf)
    love.graphics.setColor(0.28, 0.29, 0.34, 1)
    love.graphics.print("Per-channel gain", vr(x0 + pad), vr(y0 + 96))
    local rows = audioSliderRows(x0, y0, pw)
    for _, row in ipairs(rows) do
        drawSettingsSliderVirt(row.x, row.y, row.w, UI.settings[row.key], row.label)
    end
    local bx = x0 + pad
    local bw = pw - pad * 2
    local bh = 58
    local yT1 = y0 + 478
    local yT2 = yT1 + bh + 22
    local onStr = "MENU MUSIC —  " .. (UI.settings.menuBgMusic and "ON" or "OFF")
    drawSettingsTrapezoidRowVirt(bx, yT1, bw, bh, onStr)
    local ordStr = "TRACK ORDER  —  " .. (UI.settings.menuMusicShuffle and "SHUFFLE" or "SEQUENTIAL")
    drawSettingsTrapezoidRowVirt(bx, yT2, bw, bh, ordStr)
    love.graphics.setFont(fsf)
    love.graphics.setColor(0.32, 0.34, 0.4, 1)
    love.graphics.printf(
        "Music plays on the main menu only. Tap rows below to toggle.  [ and ]  |  Tab  |  Drag",
        vr(x0 + pad),
        vr(y0 + ph - 52),
        pw - pad * 2,
        "left"
    )
end

local function drawGraphicsSettingsVirt(x0, y0, pw, ph)
    local pad = config.SETTINGS_INNER_PAD_X
    local vr = layout.settingsVirtRound
    local fsm = UI.fontSettingsMain or UI.fontMain
    local fsf = UI.fontSettingsFoot or UI.fontFooter
    love.graphics.setFont(fsm)
    love.graphics.setColor(0.22, 0.23, 0.28, 1)
    love.graphics.print("DISPLAY", vr(x0 + pad), vr(y0 + 40))
    love.graphics.setFont(fsf)
    love.graphics.setColor(0.28, 0.29, 0.34, 1)
    love.graphics.print("Tap a row to toggle", vr(x0 + pad), vr(y0 + 96))
    local bx = x0 + pad
    local y1 = y0 + 132
    local bw = pw - pad * 2
    local bh = 58
    local vsStr = "VERTICAL SYNC  —  " .. (UI.settings.vsync and "ON" or "OFF")
    drawSettingsTrapezoidRowVirt(bx, y1, bw, bh, vsStr)
    local y2 = y1 + bh + 22
    local pStr = "PARTICLES  —  " .. (UI.settings.particlesLight and "LIGHT" or "FULL")
    drawSettingsTrapezoidRowVirt(bx, y2, bw, bh, pStr)
    love.graphics.setFont(fsf)
    love.graphics.setColor(0.32, 0.34, 0.4, 1)
    love.graphics.printf(
        "VSync caps frame rate. Light particles reduce GPU load.",
        vr(x0 + pad),
        vr(y0 + ph - 52),
        pw - pad * 2,
        "left"
    )
end

local function drawWindowSettingsVirt(x0, y0, pw, ph)
    local pad = config.SETTINGS_INNER_PAD_X
    local vr = layout.settingsVirtRound
    local fsm = UI.fontSettingsMain or UI.fontMain
    local fsf = UI.fontSettingsFoot or UI.fontFooter
    love.graphics.setFont(fsm)
    love.graphics.setColor(0.22, 0.23, 0.28, 1)
    love.graphics.print("DISPLAY MODE", vr(x0 + pad), vr(y0 + 40))
    love.graphics.setFont(fsf)
    love.graphics.setColor(0.28, 0.29, 0.34, 1)
    love.graphics.print("Window and fullscreen", vr(x0 + pad), vr(y0 + 96))
    local bx = x0 + pad
    local y1 = y0 + 132
    local bw = pw - pad * 2
    local bh = 58
    local fsStr = "FULLSCREEN  —  " .. (UI.settings.fullscreen and "ON" or "OFF")
    drawSettingsTrapezoidRowVirt(bx, y1, bw, bh, fsStr)
    local y2 = y1 + bh + 22
    local p = config.RES_PRESETS[UI.settings.resIdx] or config.RES_PRESETS[7]
    local resStr = string.format("RESOLUTION  —  %d × %d", p[1], p[2])
    if UI.settings.fullscreen then
        resStr = "RESOLUTION —  exit fullscreen to change"
    end
    drawSettingsTrapezoidRowVirt(bx, y2, bw, bh, resStr)
    love.graphics.setFont(fsf)
    love.graphics.setColor(0.32, 0.34, 0.4, 1)
    love.graphics.printf(
        "Desktop fullscreen uses your monitor. Change resolution while windowed.",
        vr(x0 + pad),
        vr(y0 + ph - 52),
        pw - pad * 2,
        "left"
    )
end

local function drawBackSettingsHintVirt(x0, y0, pw, ph)
    local pad = config.SETTINGS_INNER_PAD_X
    local vr = layout.settingsVirtRound
    local fsm = UI.fontSettingsMain or UI.fontMain
    local fsf = UI.fontSettingsFoot or UI.fontFooter
    love.graphics.setFont(fsm)
    love.graphics.setColor(0.22, 0.23, 0.28, 1)
    love.graphics.print("DONE?", vr(x0 + pad), vr(y0 + 40))
    love.graphics.setFont(fsf)
    love.graphics.setColor(0.28, 0.29, 0.34, 1)
    love.graphics.printf(
        "Press Enter on BACK or Escape to return to the main menu.",
        vr(x0 + pad),
        vr(y0 + 128),
        pw - pad * 2,
        "left"
    )
end

function M.drawSettingsPanel()
    local x0, y0, pw, ph = layout.settingsPanelVirtBounds()
    love.graphics.push()
    love.graphics.translate(UI.offsetX, UI.offsetY)
    love.graphics.scale(UI.scale)

    local vr = layout.settingsVirtRound
    local ix0, iy0, ipw, iph = vr(x0), vr(y0), vr(pw), vr(ph)
    love.graphics.setColor(0.99, 0.99, 1, 0.97)
    love.graphics.rectangle("fill", ix0, iy0, ipw, iph)
    love.graphics.setColor(0.88, 0.16, 0.12, 1)
    love.graphics.rectangle("fill", ix0 + 18, iy0 + 3, ipw - 36, 4)
    love.graphics.setColor(0.55, 0.57, 0.64, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", ix0 + 0.5, iy0 + 0.5, ipw - 1, iph - 1)

    local sel = UI.selection
    if sel == 1 then
        drawAudioSettingsVirt(x0, y0, pw, ph)
    elseif sel == 2 then
        drawGraphicsSettingsVirt(x0, y0, pw, ph)
    elseif sel == 3 then
        drawWindowSettingsVirt(x0, y0, pw, ph)
    else
        drawBackSettingsHintVirt(x0, y0, pw, ph)
    end

    love.graphics.pop()
end

local function audioToggleRects(x0, y0, pw)
    local pad = config.SETTINGS_INNER_PAD_X
    local bx = x0 + pad
    local bw = pw - pad * 2
    local bh = 58
    local y1 = y0 + 478
    local y2 = y1 + bh + 22
    local hitH = bh + 18
    return { x = bx, y = y1, w = bw, h = hitH, kind = "menuBgMusic" },
        { x = bx, y = y2, w = bw, h = hitH, kind = "menuMusicShuffle" }
end

local function graphicsToggleRects(x0, y0, pw)
    local pad = config.SETTINGS_INNER_PAD_X
    local bx = x0 + pad
    local y1 = y0 + 132
    local bw = pw - pad * 2
    local bh = 58
    local hitH = bh + 18
    return { x = bx, y = y1, w = bw, h = hitH, kind = "vsync" },
        { x = bx, y = y1 + bh + 22, w = bw, h = hitH, kind = "particles" }
end

local function windowToggleRects(x0, y0, pw)
    local pad = config.SETTINGS_INNER_PAD_X
    local bx = x0 + pad
    local y1 = y0 + 132
    local bw = pw - pad * 2
    local bh = 58
    local hitH = bh + 18
    return { x = bx, y = y1, w = bw, h = hitH, kind = "fullscreen" },
        { x = bx, y = y1 + bh + 22, w = bw, h = hitH, kind = "resolution" }
end

function M.toggleVsyncSetting()
    UI.settings.vsync = not UI.settings.vsync
    audio.applyVsyncFlag(UI)
    settings_persist.saveSettings(UI)
end

function M.toggleParticlesSetting()
    UI.settings.particlesLight = not UI.settings.particlesLight
    settings_persist.saveSettings(UI)
end

function M.toggleFullscreenSetting()
    local s = UI.settings
    if s.fullscreen then
        s.fullscreen = false
        love.window.setFullscreen(false)
        love.window.setMode(s.winW, s.winH, config.WINDOW_FLAGS)
    else
        local w, h = love.graphics.getDimensions()
        s.winW, s.winH = w, h
        s.fullscreen = true
        love.window.setFullscreen(true, "desktop")
    end
    audio.applyVsyncFlag(UI)
    layout.updateLayout()
    particles.init()
    settings_persist.saveSettings(UI)
end

function M.cycleResolutionSetting()
    if UI.settings.fullscreen then
        return
    end
    local idx = (UI.settings.resIdx % #config.RES_PRESETS) + 1
    UI.settings.resIdx = idx
    local p = config.RES_PRESETS[idx]
    love.window.setMode(p[1], p[2], config.WINDOW_FLAGS)
    UI.settings.winW, UI.settings.winH = p[1], p[2]
    audio.applyVsyncFlag(UI)
    layout.updateLayout()
    particles.init()
    settings_persist.saveSettings(UI)
end

function M.trySettingsPanelMousePressed(vx, vy, button)
    if button ~= 1 or not layout.menuShowsOptionsDetail() then
        return false
    end
    local x0, y0, pw, ph = layout.settingsPanelVirtBounds()
    if not layout.virtPointInRect(vx, vy, x0, y0, pw, ph) then
        return false
    end
    local sel = UI.selection
    if sel == 1 then
        for _, row in ipairs(audioSliderRows(x0, y0, pw)) do
            if layout.virtPointInRect(vx, vy, row.x, row.y - 62, row.w, 86) then
                UI.settingsDrag = row.key
                UI.settings[row.key] = math.max(0, math.min(1, (vx - row.x) / row.w))
                audio.applyAudioVolumes(UI)
                settings_persist.saveSettings(UI)
                return true
            end
        end
        local a1, a2 = audioToggleRects(x0, y0, pw)
        if layout.virtPointInRect(vx, vy, a1.x, a1.y, a1.w, a1.h) then
            music.toggleMenuBgMusicSetting()
            return true
        end
        if layout.virtPointInRect(vx, vy, a2.x, a2.y, a2.w, a2.h) then
            music.toggleMenuMusicShuffleSetting()
            return true
        end
        return true
    elseif sel == 2 then
        local r1, r2 = graphicsToggleRects(x0, y0, pw)
        if layout.virtPointInRect(vx, vy, r1.x, r1.y, r1.w, r1.h) then
            M.toggleVsyncSetting()
            return true
        end
        if layout.virtPointInRect(vx, vy, r2.x, r2.y, r2.w, r2.h) then
            M.toggleParticlesSetting()
            return true
        end
        return true
    elseif sel == 3 then
        local r1, r2 = windowToggleRects(x0, y0, pw)
        if layout.virtPointInRect(vx, vy, r1.x, r1.y, r1.w, r1.h) then
            M.toggleFullscreenSetting()
            return true
        end
        if not UI.settings.fullscreen and layout.virtPointInRect(vx, vy, r2.x, r2.y, r2.w, r2.h) then
            M.cycleResolutionSetting()
            return true
        end
        return true
    end
    return true
end

function M.updateSettingsSliderDrag(vx, vy)
    if not UI.settingsDrag or not layout.menuShowsOptionsDetail() or UI.selection ~= 1 then
        return
    end
    local x0, y0, pw = layout.settingsPanelVirtBounds()
    for _, row in ipairs(audioSliderRows(x0, y0, pw)) do
        if row.key == UI.settingsDrag then
            UI.settings[row.key] = math.max(0, math.min(1, (vx - row.x) / row.w))
            audio.applyAudioVolumes(UI)
            return
        end
    end
end

function M.settingsPanelWantsHand(mx, my)
    if not layout.menuShowsOptionsDetail() then
        return false
    end
    local vx, vy = layout.screenToVirtual(mx, my)
    local x0, y0, pw, ph = layout.settingsPanelVirtBounds()
    if not layout.virtPointInRect(vx, vy, x0, y0, pw, ph) then
        return false
    end
    local sel = UI.selection
    if sel == 1 then
        for _, row in ipairs(audioSliderRows(x0, y0, pw)) do
            if layout.virtPointInRect(vx, vy, row.x, row.y - 62, row.w, 86) then
                return true
            end
        end
        local a1, a2 = audioToggleRects(x0, y0, pw)
        if layout.virtPointInRect(vx, vy, a1.x, a1.y, a1.w, a1.h) then
            return true
        end
        if layout.virtPointInRect(vx, vy, a2.x, a2.y, a2.w, a2.h) then
            return true
        end
    elseif sel == 2 then
        local r1, r2 = graphicsToggleRects(x0, y0, pw)
        if layout.virtPointInRect(vx, vy, r1.x, r1.y, r1.w, r1.h) then
            return true
        end
        if layout.virtPointInRect(vx, vy, r2.x, r2.y, r2.w, r2.h) then
            return true
        end
    elseif sel == 3 then
        local r1, r2 = windowToggleRects(x0, y0, pw)
        if layout.virtPointInRect(vx, vy, r1.x, r1.y, r1.w, r1.h) then
            return true
        end
        if layout.virtPointInRect(vx, vy, r2.x, r2.y, r2.w, r2.h) then
            return true
        end
    end
    return false
end

function M.nudgeAudioSlider(delta)
    local keys = { "master", "music", "sfx" }
    local k = keys[UI.audioSliderFocus]
    if not k then
        return
    end
    UI.settings[k] = math.max(0, math.min(1, UI.settings[k] + delta))
    audio.applyAudioVolumes(UI)
    settings_persist.saveSettings(UI)
end

return M
