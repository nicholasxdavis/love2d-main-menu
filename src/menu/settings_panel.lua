local state = require("src.menu.state")
local config = require("src.constants.menu_config")
local layout = require("src.menu.layout")
local mathu = require("src.utils.menu_math")
local audio = require("src.menu.audio")
local settings_persist = require("src.menu.settings_persist")
local music = require("src.menu.music")
local particles = require("src.menu.particles")

local UI = state.UI

local M = {}

-- Virtual hit box for each audio slider row (label + track + thumb), relative to `row.y`.
local AUDIO_SLIDER_HIT_Y0 = -90
local AUDIO_SLIDER_HIT_H = 140

local SLIDER_TRACK_H = 12
-- Was 34px radius; 5px smaller diameter ⇒ radius 34 - 2.5
local SLIDER_THUMB_R = 31.5
-- Star PNG has clear margin past the visible points; add to thumb travel so at 100% the shape meets the track end.
local SLIDER_THUMB_STAR_END_INSET = 15
local SLIDER_LABEL_OFFSET = 84
local SLIDER_TRACK_OFFSET = 31
local AUDIO_SLIDER_ROW0 = 248
local AUDIO_SLIDER_ROW_GAP = 164
-- ~58px below last row anchor to clear thumb; then gap before toggles.
local AUDIO_SLIDER_TO_TOGGLE_GAP = 48

local function audioSliderToggleY1(y0)
    return y0 + AUDIO_SLIDER_ROW0 + 2 * AUDIO_SLIDER_ROW_GAP + 58 + AUDIO_SLIDER_TO_TOGGLE_GAP
end

--- Horizontal capsule (rounded ends), axis-aligned.
local function fillHorizCapsule(x, y, w, h, cr, cg, cb, ca)
    local rad = math.min(h * 0.5, w * 0.5)
    local my = y + h * 0.5
    love.graphics.setColor(cr, cg, cb, ca)
    if w <= 0.5 then
        return
    end
    if w < 2 * rad then
        love.graphics.circle("fill", x + w * 0.5, my, w * 0.5)
        return
    end
    love.graphics.rectangle("fill", x + rad, y, w - 2 * rad, h)
    love.graphics.circle("fill", x + rad, my, rad)
    love.graphics.circle("fill", x + w - rad, my, rad)
end

--- Glossy white sweep; only visible on the filled (yellow) capsule, not the gray track.
local function drawSliderTrackShine(vx, trackY, vw, fillW, trackH, phaseSeed)
    if vw < 8 or trackH < 2 or fillW < 4 then
        return
    end
    local timer = UI.timer or 0
    local period = vw + 110
    local u = (timer * 125 + phaseSeed * 41.7) % period
    local px = vx - 65 + u
    local midY = trackY + trackH * 0.5
    -- Mostly horizontal so more of the band stays inside the thin yellow stencil (steep diagonal looked "short").
    local bandW = 118
    local prevBlend, prevAlpha = love.graphics.getBlendMode()
    love.graphics.push()
    love.graphics.stencil(function()
        fillHorizCapsule(vx, trackY, fillW, trackH, 1, 1, 1, 1)
    end, "replace", 1)
    love.graphics.setStencilTest("equal", 1)
    love.graphics.setBlendMode("add", "alphamultiply")
    love.graphics.translate(px + bandW * 0.5, midY)
    love.graphics.rotate(0.11)
    love.graphics.scale(1.7, 1.08)
    love.graphics.translate(-bandW * 0.5, 0)
    local bands = 22
    for i = 0, bands - 1 do
        local f = i / (bands - 1)
        local g = math.sin(f * math.pi)
        love.graphics.setColor(0.92, 0.97, 1, g * 0.34)
        local slice = bandW / bands
        love.graphics.rectangle("fill", i * slice - 4, -trackH * 0.5 - 4, slice + 1.2, trackH + 8)
    end
    love.graphics.pop()
    love.graphics.setStencilTest()
    love.graphics.setBlendMode(prevBlend, prevAlpha)
end

local function audioSliderRows(x0, y0, pw)
    local pad = config.SETTINGS_INNER_PAD_X
    local tw = math.max(160, pw - pad * 2 - config.SETTINGS_PCT_COL)
    local baseY = y0 + AUDIO_SLIDER_ROW0
    local gap = AUDIO_SLIDER_ROW_GAP
    return {
        { x = x0 + pad, y = baseY, w = tw, key = "master", label = "MASTER" },
        { x = x0 + pad, y = baseY + gap, w = tw, key = "music", label = "MUSIC" },
        { x = x0 + pad, y = baseY + gap * 2, w = tw, key = "sfx", label = "SOUND EFFECTS" },
    }
end

local function drawSettingsSliderVirt(x, y, w, val, label)
    local vr = layout.settingsVirtRound
    local vx, vy, vw = vr(x), vr(y), vr(w)
    local labY = vy - SLIDER_LABEL_OFFSET
    love.graphics.setFont(UI.fontSettingsMain or UI.fontMain)
    love.graphics.setColor(0.26, 0.27, 0.32, 1)
    love.graphics.print(label, vx, labY)
    local trackY = vy + SLIDER_TRACK_OFFSET
    local trackH = SLIDER_TRACK_H
    fillHorizCapsule(vx, trackY, vw, trackH, 0.9, 0.91, 0.94, 1)
    love.graphics.setColor(0.72, 0.74, 0.8, 0.55)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", vx + 0.5, trackY + 0.5, vw - 1, trackH - 1)
    local minFill = math.max(trackH, 3)
    local fillW = math.max(minFill, vr(vw * val))
    fillW = math.min(fillW, vw)
    fillHorizCapsule(vx, trackY, fillW, trackH, 254 / 255, 253 / 255, 85 / 255, 1) -- #fefd55
    drawSliderTrackShine(vx, trackY, vw, fillW, trackH, y * 1.73)
    local tr = SLIDER_THUMB_R
    local trackMidY = trackY + trackH * 0.5
    -- PNG reads slightly low; nudge up so the star sits on the track center.
    local tcy = trackMidY - 4
    local star = UI.sliderThumbStar
    local tcx
    if star then
        local iw, ih = star:getDimensions()
        local diam = 2 * tr
        local sc = diam / math.max(iw, ih)
        local halfW = iw * sc * 0.5
        local span = math.max(0, vw - 2 * halfW + SLIDER_THUMB_STAR_END_INSET)
        tcx = vx + halfW + val * span
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(star, tcx, tcy, 0, sc, sc, iw * 0.5, ih * 0.5)
    else
        local span = math.max(0, vw - 2 * tr)
        tcx = vx + val * span + tr
        love.graphics.setColor(0, 0, 0, 0.25)
        love.graphics.circle("fill", tcx + 1.5, tcy + 2, tr * 0.85)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("fill", tcx, tcy, tr)
        love.graphics.setColor(0.2, 0.18, 0.15, 0.85)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", tcx, tcy, tr)
        love.graphics.setLineWidth(1)
    end
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
    love.graphics.print("LEVELS", vr(x0 + pad), vr(y0 + 36))
    love.graphics.setFont(fsf)
    love.graphics.setColor(0.28, 0.29, 0.34, 1)
    love.graphics.print("Per-channel gain", vr(x0 + pad), vr(y0 + 118))
    local rows = audioSliderRows(x0, y0, pw)
    for _, row in ipairs(rows) do
        drawSettingsSliderVirt(row.x, row.y, row.w, UI.settings[row.key], row.label)
    end
    local bx = x0 + pad
    local bw = pw - pad * 2
    local bh = 58
    local yT1 = audioSliderToggleY1(y0)
    local yT2 = yT1 + bh + 30
    local onStr = "MENU MUSIC —  " .. (UI.settings.menuBgMusic and "ON" or "OFF")
    drawSettingsTrapezoidRowVirt(bx, yT1, bw, bh, onStr)
    local ordStr = "TRACK ORDER  —  " .. (UI.settings.menuMusicShuffle and "SHUFFLE" or "SEQUENTIAL")
    drawSettingsTrapezoidRowVirt(bx, yT2, bw, bh, ordStr)
    love.graphics.setFont(fsf)
    love.graphics.setColor(0.32, 0.34, 0.4, 1)
    love.graphics.printf(
        "Music plays on the main menu only. Tap rows below to toggle.  [ and ]  |  Tab  |  Drag",
        vr(x0 + pad),
        vr(y0 + ph - 56),
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
    local cr, cg, cb = mathu.getCyclingBackgroundRgb(UI.timer)
    love.graphics.setColor(cr, cg, cb, 1)
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
    local y1 = audioSliderToggleY1(y0)
    local y2 = y1 + bh + 30
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
            if layout.virtPointInRect(vx, vy, row.x, row.y + AUDIO_SLIDER_HIT_Y0, row.w, AUDIO_SLIDER_HIT_H) then
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
            if layout.virtPointInRect(vx, vy, row.x, row.y + AUDIO_SLIDER_HIT_Y0, row.w, AUDIO_SLIDER_HIT_H) then
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
