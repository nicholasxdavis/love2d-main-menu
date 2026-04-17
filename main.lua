local UI = {
    selection = 1,
    lerpSelection = 1,
    lerpVel = 0,
    timer = 0,
    options = {"RESUME", "NEW GAME", "OPTIONS", "EXIT"},
    optionsDetail = { "AUDIO", "GRAPHICS", "WINDOW", "BACK" },

    view = "menu",
    irisActive = false,
    irisTime = 0,
    gameScreenT = 0,

    V_WIDTH = 1920,
    V_HEIGHT = 1080,
    scale = 1, offsetX = 0, offsetY = 0,

    particles = {},
    bgImage = nil,
    previewImage = nil,
    previewImage2 = nil,
    previewShotMix = 0,
    bgShader = nil,
    bgPostShader = nil,
    bgCanvas = nil,
    uiShader = nil,
    previewShader = nil,
    previewHoverMix = 0,
    menuBtnIcon = nil,
    handCursor = nil,
    fontFooter = nil,
    fontVersion = nil,
    fontMainPx = 0,
    fontFooterPx = 0,
    fontVersionPx = 0,
    updateInfoText = "UPDATE: v1.0 — Patch notes, version info, and latest news appear here.",

    gameStartSound = nil,
    hoverSound = nil,
    optionsSound = nil,
    lastHoverMenuIndex = nil,
    lastPreviewImgHover = false,

    menuOptionsT = 0,
    menuOptionsTarget = 0,
    optionsDetailView = false,

    settings = {
        master = 1,
        music = 1,
        sfx = 1,
        vsync = true,
        fullscreen = false,
        winW = 1280,
        winH = 720,
        resIdx = 7,
        particlesLight = false,
    },
    audioSliderFocus = 1,
    settingsDrag = nil,

    fontSettingsMain = nil,
    fontSettingsFoot = nil,
    fontSettingsMainPx = 0,
    fontSettingsFootPx = 0,
}

local SPRING_K = 260
local SPRING_C = 24

local FONT_MENU = "src/fonts/SairaExtraCondensed-Regular.ttf"
local FONT_MENU_BOLD = "src/fonts/SairaExtraCondensed-ExtraBold.ttf"
local REF_MAIN_LINE_H, REF_FOOT_LINE_H, REF_VERSION_LINE_H
local initParticles

local function captureDefaultFontLineHeights()
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

local function newFontFitLineHeight(path, requestedPx, targetLineH, minSize)
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

local MENU_START_Y = 520
local MENU_SPACING = 85

local MENU_OPTIONS_SCALE_MAX = 1.38
local MENU_OPTIONS_SPACING_ADD = 52
local MENU_OPTIONS_T_RATE = 2.85
local MENU_OPTIONS_BANNER_PIVOT_Y = 31.5
-- Vertical tweak for options-detail labels vs. the white pill (screen pixels before row scale).
local MENU_OPTIONS_TEXT_NUDGE_SCREEN_PX = 3

-- Submenu labels swap as soon as options opens (same frame target flips), not after the zoom finishes.
local function menuShowsOptionsDetail()
    return UI.menuOptionsTarget > 0.5
end

local function getMenuLabels()
    if menuShowsOptionsDetail() then
        return UI.optionsDetail
    end
    return UI.options
end

local function menuOptionCount()
    return #getMenuLabels()
end

local LOGO_X, LOGO_Y = 98, 98
local LOGO_TARGET_W = 450
local LOGO_SCALE_MUL = 0.94

local PREVIEW_W = 930
local PREVIEW_H = 485
-- Nominal size; actual width may shrink so the card does not overlap the left options column.
local SETTINGS_PANEL_W = 1120
local SETTINGS_PANEL_H = 740
local PREVIEW_MARGIN_RIGHT = 42
local PREVIEW_OUTLINE_PX = 2
local PREVIEW_FOOTER_H = 78
local PREVIEW_FOOTER_RULE_VIRT = 3
local PREVIEW_HOVER_LERP_RATE = 1.85
local PREVIEW_COLOR_MAX = 0.8
local PREVIEW_SHOT_HOLD = 6
local PREVIEW_SHOT_CROSSFADE = 1.35

local IRIS_OUT_DURATION = 2.0
local GAME_PLACEHOLDER_BLACK_HOLD = 0.9
local GAME_PLACEHOLDER_TEXT = "Game here lol..."

local GAME_PLACEHOLDER_TYPE_BASE = 0.068
local GAME_PLACEHOLDER_TYPE_SPACE_MUL = 1.42
local GAME_PLACEHOLDER_TYPE_PUNCT_MUL = 1.88

local GAME_PLACEHOLDER_TYPE_DELAYS = {}
do local s = GAME_PLACEHOLDER_TEXT
    for i = 1, #s do
        local c = s:sub(i, i)
        local d = GAME_PLACEHOLDER_TYPE_BASE
        if c == " " then
            d = d * GAME_PLACEHOLDER_TYPE_SPACE_MUL
        elseif c == "." then
            d = d * GAME_PLACEHOLDER_TYPE_PUNCT_MUL
        end
        GAME_PLACEHOLDER_TYPE_DELAYS[i] = d
    end
end

local function gamePlaceholderTypewriterProgress(typeT)
    if typeT <= 0 then
        return 0
    end
    local s = GAME_PLACEHOLDER_TEXT
    local acc = 0
    for i = 1, #s do
        local d = GAME_PLACEHOLDER_TYPE_DELAYS[i]
        if typeT < acc + d then
            return (i - 1) + (typeT - acc) / d
        end
        acc = acc + d
    end
    return #s
end

local BG_CYCLE_SECONDS = 440
local BG_CYCLE_COLORS = {
    { 0.78, 0.05, 0.05 },
    { 0.06, 0.70, 0.14 },
    { 0.88, 0.78, 0.10 },
    { 0.10, 0.22, 0.82 },
}

local function smootherstep01(t)
    t = math.max(0, math.min(1, t))
    return t * t * t * (t * (t * 6 - 15) + 10)
end

local function getCyclingBackgroundRgb()
    local n = #BG_CYCLE_COLORS
    local u = (UI.timer / BG_CYCLE_SECONDS) % 1 * n
    local i0 = math.floor(u) % n + 1
    local i1 = i0 % n + 1
    local t = smootherstep01(u - math.floor(u))
    local a, b = BG_CYCLE_COLORS[i0], BG_CYCLE_COLORS[i1]
    return a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
        a[3] + (b[3] - a[3]) * t
end

local function getLogoDrawScale()
    local lw = UI.logo:getDimensions()
    return (LOGO_TARGET_W / lw) * LOGO_SCALE_MUL
end

local function getPreviewLayout()
    local pw, ph = PREVIEW_W, PREVIEW_H
    local px = UI.V_WIDTH - PREVIEW_MARGIN_RIGHT - pw
    local py = (UI.V_HEIGHT - ph) * 0.5
    return px, py, pw, ph
end

-- Must be defined before settings helpers (e.g. settingsPanelWantsHand) that call these.
local function screenToVirtual(mx, my)
    return (mx - UI.offsetX) / UI.scale, (my - UI.offsetY) / UI.scale
end

local function virtToScreen(vx, vy)
    return math.floor(UI.offsetX + vx * UI.scale + 0.5), math.floor(UI.offsetY + vy * UI.scale + 0.5)
end

-- Virtual X center of the menu pill used on the main screen (matches original layout).
local MENU_PILL_CENTER_X = 300

local RES_PRESETS = {
    {3840, 2160}, {2560, 1440}, {1920, 1080}, {1680, 1050},
    {1600, 900}, {1366, 768}, {1280, 720}, {1024, 768},
}
local SETTINGS_FILE = "menu_settings.txt"
local WINDOW_FLAGS = { resizable = true, highdpi = true, msaa = 4 }

local function virtPointInRect(vx, vy, rx, ry, rw, rh)
    return vx >= rx and vx <= rx + rw and vy >= ry and vy <= ry + rh
end

local SETTINGS_INNER_PAD_X = 72
local SETTINGS_INNER_PAD_Y = 48

local SETTINGS_PCT_COL = 96

-- Virtual X: keep the white panel strictly to the right of the selection pill and labels.
local SETTINGS_PANEL_MIN_LEFT_X = MENU_PILL_CENTER_X + math.ceil(290 * MENU_OPTIONS_SCALE_MAX) + 72

local function audioSliderRows(x0, y0, pw)
    local pad = SETTINGS_INNER_PAD_X
    local tw = math.max(160, pw - pad * 2 - SETTINGS_PCT_COL)
    local baseY = y0 + 188
    local gap = 128
    return {
        { x = x0 + pad, y = baseY, w = tw, key = "master", label = "MASTER" },
        { x = x0 + pad, y = baseY + gap, w = tw, key = "music", label = "MUSIC" },
        { x = x0 + pad, y = baseY + gap * 2, w = tw, key = "sfx", label = "SOUND EFFECTS" },
    }
end

local function settingsVirtRound(n)
    return math.floor(n + 0.5)
end

local function saveSettings()
    local s = UI.settings
    local lines = {
        string.format("master=%.5f", s.master),
        string.format("music=%.5f", s.music),
        string.format("sfx=%.5f", s.sfx),
        "vsync=" .. (s.vsync and "1" or "0"),
        "fullscreen=" .. (s.fullscreen and "1" or "0"),
        string.format("winW=%d", s.winW),
        string.format("winH=%d", s.winH),
        string.format("resIdx=%d", s.resIdx),
        "particlesLight=" .. (s.particlesLight and "1" or "0"),
    }
    love.filesystem.write(SETTINGS_FILE, table.concat(lines, "\n"))
end

local function loadSettings()
    if not love.filesystem.getInfo(SETTINGS_FILE) then
        return
    end
    local text = love.filesystem.read(SETTINGS_FILE)
    if not text then return end
    for line in text:gmatch("[^\r\n]+") do
        local k, v = line:match("^(%w+)=(.*)$")
        if k and v then
            if k == "master" or k == "music" or k == "sfx" then
                local n = tonumber(v)
                if n then UI.settings[k] = math.max(0, math.min(1, n)) end
            elseif k == "vsync" or k == "fullscreen" or k == "particlesLight" then
                UI.settings[k] = (v == "1" or v == "true")
            elseif k == "winW" or k == "winH" then
                local n = tonumber(v)
                if n then UI.settings[k] = math.floor(n) end
            elseif k == "resIdx" then
                local n = tonumber(v)
                if n then UI.settings.resIdx = math.max(1, math.min(#RES_PRESETS, math.floor(n))) end
            end
        end
    end
end

local function applyAudioVolumes()
    local st = UI.settings
    love.audio.setVolume(st.master)
    local sv = st.sfx
    if UI.hoverSound then UI.hoverSound:setVolume(sv) end
    if UI.gameStartSound then UI.gameStartSound:setVolume(sv) end
    if UI.optionsSound then UI.optionsSound:setVolume(sv) end
end

local function applyVsyncFlag()
    pcall(love.window.setVSync, UI.settings.vsync)
end

local function toggleVsyncSetting()
    UI.settings.vsync = not UI.settings.vsync
    applyVsyncFlag()
    saveSettings()
end

local function toggleParticlesSetting()
    UI.settings.particlesLight = not UI.settings.particlesLight
    saveSettings()
end

local function toggleFullscreenSetting()
    local s = UI.settings
    if s.fullscreen then
        s.fullscreen = false
        love.window.setFullscreen(false)
        love.window.setMode(s.winW, s.winH, WINDOW_FLAGS)
    else
        local w, h = love.graphics.getDimensions()
        s.winW, s.winH = w, h
        s.fullscreen = true
        love.window.setFullscreen(true, "desktop")
    end
    applyVsyncFlag()
    updateLayout()
    initParticles()
    saveSettings()
end

local function cycleResolutionSetting()
    if UI.settings.fullscreen then
        return
    end
    local idx = (UI.settings.resIdx % #RES_PRESETS) + 1
    UI.settings.resIdx = idx
    local p = RES_PRESETS[idx]
    love.window.setMode(p[1], p[2], WINDOW_FLAGS)
    UI.settings.winW, UI.settings.winH = p[1], p[2]
    applyVsyncFlag()
    updateLayout()
    initParticles()
    saveSettings()
end

local function drawSettingsSliderVirt(x, y, w, val, label)
    local vr = settingsVirtRound
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
    love.graphics.print(pct, vx + vw + math.floor((SETTINGS_PCT_COL - ptw) * 0.5 + 0.5), labY)
end

-- Slanted row: integer verts, no shadow duplicate (avoids fringe / blur).
local function drawSettingsTrapezoidRowVirt(bx, by, bw, bh, textStr)
    local vr = settingsVirtRound
    bx, by, bw, bh = vr(bx), vr(by), vr(bw), vr(bh)
    local skewT, skewB, ins = 4, 10, 4
    love.graphics.setColor(0.99, 0.99, 1, 1)
    love.graphics.polygon(
        "fill",
        bx,
        by + skewT,
        bx + bw,
        by,
        bx + bw - ins,
        by + bh,
        bx,
        by + bh + skewB
    )
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
    local pad = SETTINGS_INNER_PAD_X
    local vr = settingsVirtRound
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
    love.graphics.setFont(fsf)
    love.graphics.setColor(0.32, 0.34, 0.4, 1)
    love.graphics.printf(
        "[ and ] adjust |   Tab: next row   |   Drag track",
        vr(x0 + pad),
        vr(y0 + ph - 52),
        pw - pad * 2,
        "left"
    )
end

local function drawGraphicsSettingsVirt(x0, y0, pw, ph)
    local pad = SETTINGS_INNER_PAD_X
    local vr = settingsVirtRound
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
    local pad = SETTINGS_INNER_PAD_X
    local vr = settingsVirtRound
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
    local p = RES_PRESETS[UI.settings.resIdx] or RES_PRESETS[7]
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
    local pad = SETTINGS_INNER_PAD_X
    local vr = settingsVirtRound
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

local function settingsPanelVirtBounds()
    local pwNominal, ph = SETTINGS_PANEL_W, SETTINGS_PANEL_H
    local rightX = UI.V_WIDTH - PREVIEW_MARGIN_RIGHT
    local maxW = math.max(320, rightX - SETTINGS_PANEL_MIN_LEFT_X)
    local pw = math.min(pwNominal, maxW)
    local px = rightX - pw
    local py = (UI.V_HEIGHT - ph) * 0.5
    return px, py, pw, ph
end

local function drawSettingsPanel()
    local x0, y0, pw, ph = settingsPanelVirtBounds()
    love.graphics.push()
    love.graphics.translate(UI.offsetX, UI.offsetY)
    love.graphics.scale(UI.scale)

    local vr = settingsVirtRound
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

local function graphicsToggleRects(x0, y0, pw)
    local pad = SETTINGS_INNER_PAD_X
    local bx = x0 + pad
    local y1 = y0 + 132
    local bw = pw - pad * 2
    local bh = 58
    local hitH = bh + 18
    return { x = bx, y = y1, w = bw, h = hitH, kind = "vsync" },
        { x = bx, y = y1 + bh + 22, w = bw, h = hitH, kind = "particles" }
end

local function windowToggleRects(x0, y0, pw)
    local pad = SETTINGS_INNER_PAD_X
    local bx = x0 + pad
    local y1 = y0 + 132
    local bw = pw - pad * 2
    local bh = 58
    local hitH = bh + 18
    return { x = bx, y = y1, w = bw, h = hitH, kind = "fullscreen" },
        { x = bx, y = y1 + bh + 22, w = bw, h = hitH, kind = "resolution" }
end

local function trySettingsPanelMousePressed(vx, vy, button)
    if button ~= 1 or not menuShowsOptionsDetail() then
        return false
    end
    local x0, y0, pw, ph = settingsPanelVirtBounds()
    if not virtPointInRect(vx, vy, x0, y0, pw, ph) then
        return false
    end
    local sel = UI.selection
    if sel == 1 then
        for _, row in ipairs(audioSliderRows(x0, y0, pw)) do
            if virtPointInRect(vx, vy, row.x, row.y - 62, row.w, 86) then
                UI.settingsDrag = row.key
                UI.settings[row.key] = math.max(0, math.min(1, (vx - row.x) / row.w))
                applyAudioVolumes()
                saveSettings()
                return true
            end
        end
        return true
    elseif sel == 2 then
        local r1, r2 = graphicsToggleRects(x0, y0, pw)
        if virtPointInRect(vx, vy, r1.x, r1.y, r1.w, r1.h) then
            toggleVsyncSetting()
            return true
        end
        if virtPointInRect(vx, vy, r2.x, r2.y, r2.w, r2.h) then
            toggleParticlesSetting()
            return true
        end
        return true
    elseif sel == 3 then
        local r1, r2 = windowToggleRects(x0, y0, pw)
        if virtPointInRect(vx, vy, r1.x, r1.y, r1.w, r1.h) then
            toggleFullscreenSetting()
            return true
        end
        if not UI.settings.fullscreen and virtPointInRect(vx, vy, r2.x, r2.y, r2.w, r2.h) then
            cycleResolutionSetting()
            return true
        end
        return true
    end
    return true
end

local function updateSettingsSliderDrag(vx, vy)
    if not UI.settingsDrag or not menuShowsOptionsDetail() or UI.selection ~= 1 then
        return
    end
    local x0, y0, pw = settingsPanelVirtBounds()
    for _, row in ipairs(audioSliderRows(x0, y0, pw)) do
        if row.key == UI.settingsDrag then
            UI.settings[row.key] = math.max(0, math.min(1, (vx - row.x) / row.w))
            applyAudioVolumes()
            return
        end
    end
end

local function settingsPanelWantsHand(mx, my)
    if not menuShowsOptionsDetail() then
        return false
    end
    local vx, vy = screenToVirtual(mx, my)
    local x0, y0, pw, ph = settingsPanelVirtBounds()
    if not virtPointInRect(vx, vy, x0, y0, pw, ph) then
        return false
    end
    local sel = UI.selection
    if sel == 1 then
        for _, row in ipairs(audioSliderRows(x0, y0, pw)) do
            if virtPointInRect(vx, vy, row.x, row.y - 62, row.w, 86) then
                return true
            end
        end
    elseif sel == 2 then
        local r1, r2 = graphicsToggleRects(x0, y0, pw)
        if virtPointInRect(vx, vy, r1.x, r1.y, r1.w, r1.h) then return true end
        if virtPointInRect(vx, vy, r2.x, r2.y, r2.w, r2.h) then return true end
    elseif sel == 3 then
        local r1, r2 = windowToggleRects(x0, y0, pw)
        if virtPointInRect(vx, vy, r1.x, r1.y, r1.w, r1.h) then return true end
        if virtPointInRect(vx, vy, r2.x, r2.y, r2.w, r2.h) then return true end
    end
    return false
end

local function nudgeAudioSlider(delta)
    local keys = { "master", "music", "sfx" }
    local k = keys[UI.audioSliderFocus]
    if not k then return end
    UI.settings[k] = math.max(0, math.min(1, UI.settings[k] + delta))
    applyAudioVolumes()
    saveSettings()
end

local function updatePreviewShotCycle()
    if not (UI.previewImage and UI.previewImage2) then
        UI.previewShotMix = 0
        return
    end
    local hold, xfd = PREVIEW_SHOT_HOLD, PREVIEW_SHOT_CROSSFADE
    local period = 2 * (hold + xfd)
    local t = UI.timer % period
    if t < hold then
        UI.previewShotMix = 0
    elseif t < hold + xfd then
        UI.previewShotMix = smootherstep01((t - hold) / xfd)
    elseif t < hold + xfd + hold then
        UI.previewShotMix = 1
    elseif t < period then
        UI.previewShotMix = 1 - smootherstep01((t - hold - xfd - hold) / xfd)
    else
        UI.previewShotMix = 0
    end
end

local function getPreviewImageScreenRect()
    local x0, y0, pw, ph = getPreviewLayout()
    local sx = math.floor(UI.offsetX + x0 * UI.scale + 0.5)
    local sy = math.floor(UI.offsetY + y0 * UI.scale + 0.5)
    local sw = math.max(1, math.floor(pw * UI.scale + 0.5))
    local imageH = ph - PREVIEW_FOOTER_H
    local shImg = math.max(1, math.floor(imageH * UI.scale + 0.5))
    return sx, sy, sw, shImg
end

local function refreshUiFonts()
    if not UI.scale or UI.scale <= 0 then return end
    local mainPx = math.max(24, math.floor(52 * UI.scale + 0.5))
    local footPx = math.max(16, math.floor(28 * UI.scale + 0.5))
    if mainPx ~= UI.fontMainPx then
        if UI.fontMain then UI.fontMain:release() end
        local targetMainH = REF_MAIN_LINE_H and (REF_MAIN_LINE_H * mainPx / 52) or mainPx
        UI.fontMain = newFontFitLineHeight(FONT_MENU_BOLD, mainPx, targetMainH, 24)
        UI.fontMainPx = mainPx
    end
    if footPx ~= UI.fontFooterPx then
        if UI.fontFooter then UI.fontFooter:release() end
        local targetFootH = REF_FOOT_LINE_H and (REF_FOOT_LINE_H * footPx / 28) or footPx
        UI.fontFooter = newFontFitLineHeight(FONT_MENU, footPx, targetFootH)
        UI.fontFooterPx = footPx
    end
    local versionPx = math.max(22, math.floor(40 * UI.scale + 0.5))
    if versionPx ~= UI.fontVersionPx then
        if UI.fontVersion then UI.fontVersion:release() end
        local targetVerH = REF_VERSION_LINE_H and (REF_VERSION_LINE_H * versionPx / 40) or versionPx
        UI.fontVersion = newFontFitLineHeight(FONT_MENU, versionPx, targetVerH, 22)
        UI.fontVersionPx = versionPx
    end
end

local function refreshSettingsFonts()
    if not UI.scale or UI.scale <= 0 then return end
    local mainPx = math.max(30, math.floor(66 * UI.scale + 0.5))
    local footPx = math.max(20, math.floor(38 * UI.scale + 0.5))
    if mainPx ~= UI.fontSettingsMainPx then
        if UI.fontSettingsMain then UI.fontSettingsMain:release() end
        local targetMainH = REF_MAIN_LINE_H and (REF_MAIN_LINE_H * mainPx / 52) or mainPx
        UI.fontSettingsMain = newFontFitLineHeight(FONT_MENU_BOLD, mainPx, targetMainH, 24)
        UI.fontSettingsMainPx = mainPx
    end
    if footPx ~= UI.fontSettingsFootPx then
        if UI.fontSettingsFoot then UI.fontSettingsFoot:release() end
        local targetFootH = REF_FOOT_LINE_H and (REF_FOOT_LINE_H * footPx / 28) or footPx
        UI.fontSettingsFoot = newFontFitLineHeight(FONT_MENU, footPx, targetFootH)
        UI.fontSettingsFootPx = footPx
    end
end

local function interpRowMetric(ls, fn)
    local n = menuOptionCount()
    if n < 1 then return 0 end
    if ls <= 1 then return fn(1) end
    if ls >= n then return fn(n) end
    local il = math.floor(ls)
    local fh = ls - il
    return (1 - fh) * fn(il) + fh * fn(il + 1)
end

local function menuOptionsEase()
    return smootherstep01(UI.menuOptionsT)
end

local function rowCenterX(tMo)
    local te = smootherstep01(tMo)
    return 300 + (UI.V_WIDTH * 0.5 - 300) * te
end

local function rowTextY(i, tMo)
    local te = smootherstep01(tMo)
    local spacing = MENU_SPACING + MENU_OPTIONS_SPACING_ADD * te
    local origY = MENU_START_Y + (i - 1) * MENU_SPACING
    local mid = UI.V_HEIGHT * 0.5
    local span = (menuOptionCount() - 1) * spacing
    local tgtY = mid - span * 0.5 + (i - 1) * spacing
    return origY + (tgtY - origY) * te
end

local function getMenuIndexAtVirtual(vx, vy)
    local te = menuOptionsEase()
    for i = 1, menuOptionCount() do
        local ty = rowTextY(i, UI.menuOptionsT)
        local rs = 1 + (MENU_OPTIONS_SCALE_MAX - 1) * te
        local y0, y1 = ty - 12 * rs, ty + 80 * rs
        local ax = menuShowsOptionsDetail() and MENU_PILL_CENTER_X or rowCenterX(UI.menuOptionsT)
        local halfW = (0.5 * (540 * (1 - te) + 620 * te)) * rs
        local x0, x1 = ax - halfW, ax + halfW
        if vx >= x0 and vx <= x1 and vy >= y0 and vy <= y1 then
            return i
        end
    end
    return nil
end

local function playHoverSound()
    local gs = UI.gameStartSound
    if gs and gs:isPlaying() then
        return
    end
    local s = UI.hoverSound
    if not s then return end
    s:stop()
    s:seek(0)
    s:play()
end

local function updateMenuCursor()
    if UI.view == "game" or UI.irisActive then
        love.mouse.setCursor()
        return
    end
    local mx, my = love.mouse.getPosition()
    if settingsPanelWantsHand(mx, my) then
        love.mouse.setCursor(UI.handCursor)
        return
    end
    local vx, vy = screenToVirtual(mx, my)
    local idx = getMenuIndexAtVirtual(vx, vy)
    if idx then
        love.mouse.setCursor(UI.handCursor)
        if idx ~= UI.lastHoverMenuIndex then
            playHoverSound()
        end
        UI.lastHoverMenuIndex = idx
    else
        love.mouse.setCursor()
        UI.lastHoverMenuIndex = nil
    end
end

local function closeOptionsMenuLayout()
    UI.menuOptionsTarget = 0
    UI.selection = 3
    UI.lerpSelection = 3
    UI.lerpVel = 0
    UI.settingsDrag = nil
end

local function activateMenuOption(index)
    if UI.irisActive or UI.view == "game" then
        return
    end
    local labels = getMenuLabels()
    local label = labels[index]
    if label == "RESUME" or label == "NEW GAME" then
        local h = UI.hoverSound
        if h then h:stop() end
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
        closeOptionsMenuLayout()
    elseif label == "EXIT" then
        love.event.quit()
    end
end

local function drawIrisCloseToBlack()
    local sw, sh = love.graphics.getDimensions()
    local cx, cy = sw * 0.5, sh * 0.5
    local maxR = math.sqrt(cx * cx + cy * cy) + 8
    local p = smootherstep01(UI.irisTime / IRIS_OUT_DURATION)
    local r = maxR * (1 - p)

    love.graphics.stencil(function()
        love.graphics.circle("fill", cx, cy, math.max(r, 0))
    end, "replace", 1)
    love.graphics.setStencilTest("equal", 0)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    love.graphics.setStencilTest()
end

local function drawGamePlaceholder()
    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    local typeT = (UI.gameScreenT or 0) - GAME_PLACEHOLDER_BLACK_HOLD
    local vis = gamePlaceholderTypewriterProgress(typeT)
    if vis <= 0 then
        return
    end

    local s = GAME_PLACEHOLDER_TEXT
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
        local ca = smootherstep01(frac)
        love.graphics.setColor(0.96, 0.96, 0.98, ca)
        love.graphics.print(cur, xStart + wPre, y)
    end

    local cursorBlink = (math.floor(UI.timer * 2.35) % 2) == 0
    if cursorBlink and vis < #s then
        local curs = "|"
        local wCurs = font:getWidth(curs)
        local cx = xStart + wPre + wCur * smootherstep01(frac)
        love.graphics.setColor(0.96, 0.96, 0.98, 0.82)
        love.graphics.print(curs, cx - wCurs * 0.35, y)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local BG_SHADER = [[
extern number time;
extern vec2 screenSize;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec4 base = Texel(tex, texture_coords) * color;
    vec2 uv = screen_coords / screenSize;
    vec2 d = uv - vec2(0.5);
    float vig = 1.0 - dot(d, d) * 0.38;
    vig = smoothstep(0.35, 1.0, clamp(vig, 0.0, 1.0));

    float g = fract(sin(dot(screen_coords.xy * 0.71 + time * 12.0, vec2(12.9898, 78.233))) * 43758.5453);
    float grain = mix(1.0, g, 0.035);

    return vec4(base.rgb * vig * grain, base.a);
}
]]

local BG_WATERCOLOR_SHADER = [[
extern number time;
extern vec2 screenSize;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec2 uv = texture_coords;
    vec2 p = screen_coords / screenSize;
    float t = time * 0.11;

    vec2 flow = vec2(
        sin(uv.y * 9.0 + t * 1.3) * cos(uv.x * 5.0 - t * 0.6),
        cos(uv.x * 8.0 - t * 1.0) * sin(uv.y * 4.5 + t * 0.75)
    ) * 0.014;
    vec2 suv = clamp(uv + flow, vec2(0.002), vec2(0.998));
    vec4 scene = Texel(tex, suv) * color;

    float y = dot(scene.rgb, vec3(0.299, 0.587, 0.114));
    scene.rgb = mix(scene.rgb, vec3(y), 0.28);

    float wash = sin(p.x * 3.2 + t * 0.35) * sin(p.y * 2.8 - t * 0.28);
    wash = wash * 0.04 + 0.97;
    scene.rgb *= wash;

    vec2 d = p - vec2(0.5);
    float edge = 1.0 - dot(d, d) * 0.42;
    edge = mix(0.88, 1.0, smoothstep(0.15, 1.0, clamp(edge, 0.0, 1.0)));
    scene.rgb *= edge;

    scene.rgb = scene.rgb * 0.84 + vec3(0.035);

    float g = fract(sin(dot(screen_coords.xy * 0.63 + time * 2.0, vec2(12.9898, 78.233))) * 43758.5453);
    float grain = mix(0.97, 1.0, g);
    scene.rgb *= grain;

    return vec4(clamp(scene.rgb, 0.0, 1.0), scene.a);
}
]]

local UI_SHADER = [[
extern number time;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec4 texel = Texel(tex, texture_coords);
    float sheen = sin(screen_coords.x * 0.018 + time * 1.9) * 0.018;
    float rim = sin(screen_coords.y * 0.012 - time * 1.4) * 0.012;
    float pulse = sin(time * 2.4) * 0.008;
    float lum = 1.0 + sheen + rim + pulse;
    return texel * vec4(color.rgb * lum, color.a);
}
]]

local PREVIEW_GRAYSCALE_SHADER = [[
extern number colorBlend;
extern number colorMax;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec4 texel = Texel(tex, texture_coords) * color;
    float y = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
    vec3 gray = vec3(y);
    float t = clamp(colorBlend, 0.0, 1.0) * colorMax;
    vec3 outRgb = mix(gray, texel.rgb, t);
    return vec4(outRgb, texel.a);
}
]]

local PARTICLE_RADIAL_EXCL_PAD = 72
local PARTICLE_COUNT = 119

local function getParticleRadialSymbolParams(sw, sh)
    local scale = (UI.scale and UI.scale > 0) and UI.scale or math.min(sw / UI.V_WIDTH, sh / UI.V_HEIGHT)
    return sw * 0.75, sh * 0.45, 700 * scale
end

local function particleRadialExclRadiusSq(sw, sh)
    local _, _, r = getParticleRadialSymbolParams(sw, sh)
    local ex = r + PARTICLE_RADIAL_EXCL_PAD
    return ex * ex
end

local function particlePosOutsideRadialSymbol(x, y, sw, sh)
    local cx, cy = getParticleRadialSymbolParams(sw, sh)
    local dx, dy = x - cx, y - cy
    return dx * dx + dy * dy >= particleRadialExclRadiusSq(sw, sh)
end

local function randomParticlePosOutsideRadialSymbol(sw, sh)
    local cx, cy = getParticleRadialSymbolParams(sw, sh)
    local r2 = particleRadialExclRadiusSq(sw, sh)
    for _ = 1, 100 do
        local x = love.math.random() * sw
        local y = love.math.random() * sh
        local dx, dy = x - cx, y - cy
        if dx * dx + dy * dy >= r2 then
            return x, y
        end
    end
    for y = 0, sh, 31 do
        if particlePosOutsideRadialSymbol(0, y, sw, sh) then
            return 0, y
        end
    end
    return sw * 0.25, sh * 0.12
end

local function randomParticleYForXOutsideRadial(x, sw, sh)
    local cx, cy = getParticleRadialSymbolParams(sw, sh)
    local r2 = particleRadialExclRadiusSq(sw, sh)
    for _ = 1, 80 do
        local y = love.math.random() * sh
        local dx, dy = x - cx, y - cy
        if dx * dx + dy * dy >= r2 then
            return y
        end
    end
    for y = 0, sh, 23 do
        if particlePosOutsideRadialSymbol(x, y, sw, sh) then
            return y
        end
    end
    return love.math.random() * sh
end

local function randomParticleXForYOutsideRadial(y, sw, sh)
    local cx, cy = getParticleRadialSymbolParams(sw, sh)
    local r2 = particleRadialExclRadiusSq(sw, sh)
    for _ = 1, 80 do
        local x = love.math.random() * sw
        local dx, dy = x - cx, y - cy
        if dx * dx + dy * dy >= r2 then
            return x
        end
    end
    for x = 0, sw, 23 do
        if particlePosOutsideRadialSymbol(x, y, sw, sh) then
            return x
        end
    end
    return love.math.random() * sw
end

local function nudgeParticleOutOfRadialSymbol(p, sw, sh)
    if particlePosOutsideRadialSymbol(p.x, p.y, sw, sh) then
        return
    end
    local cx, cy = getParticleRadialSymbolParams(sw, sh)
    local ex = math.sqrt(particleRadialExclRadiusSq(sw, sh))
    local dx, dy = p.x - cx, p.y - cy
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 1e-4 then
        p.x, p.y = randomParticlePosOutsideRadialSymbol(sw, sh)
        return
    end
    local push = ex - dist + 6
    p.x = p.x + (dx / dist) * push
    p.y = p.y + (dy / dist) * push
end

initParticles = function()
    UI.particles = {}
    local sw, sh = love.graphics.getDimensions()
    for _ = 1, PARTICLE_COUNT do
        local x, y = randomParticlePosOutsideRadialSymbol(sw, sh)
        UI.particles[#UI.particles + 1] = {
            x = x, y = y,
            vx = (love.math.random() - 0.5) * 14,
            vy = (love.math.random() - 0.5) * 10 - 6,
            r = love.math.random(8, 22) * 0.1,
            a = love.math.random() * 0.22 + 0.06,
            phase = love.math.random() * 6.283,
            wob = 0.4 + love.math.random() * 1.2,
        }
    end
end

function love.load()
    love.graphics.setDefaultFilter("linear", "linear", 1)
    captureDefaultFontLineHeights()
    loadSettings()
    local s = UI.settings
    love.window.setMode(s.winW, s.winH, WINDOW_FLAGS)
    if s.fullscreen then
        love.window.setFullscreen(true, "desktop")
    end
    applyVsyncFlag()
    for i, p in ipairs(RES_PRESETS) do
        if p[1] == s.winW and p[2] == s.winH then
            s.resIdx = i
            break
        end
    end
    love.mouse.setRelativeMode(false)
    love.mouse.setVisible(true)

    UI.logo = love.graphics.newImage("src/img/M.png")

    UI.menuBtnIcon = nil
    for _, path in ipairs({ "src/img/btn-icon.png", "btn-icon.png", "img/btn-icon.png" }) do
        local okIcon, iconImg = pcall(love.graphics.newImage, path)
        if okIcon then
            UI.menuBtnIcon = iconImg
            break
        end
    end

    local ok, img = pcall(love.graphics.newImage, "src/img/background.png")
    if ok then UI.bgImage = img end
    UI.previewImage = nil
    UI.previewImage2 = nil
    local shotPairs = {
        { "src/img/screenshot.png", "src/img/screenshot2.png" },
        { "screenshot.png", "screenshot2.png" },
        { "img/screenshot.png", "img/screenshot2.png" },
    }
    for _, pair in ipairs(shotPairs) do
        local ok1, img1 = pcall(love.graphics.newImage, pair[1])
        local ok2, img2 = pcall(love.graphics.newImage, pair[2])
        if ok1 and ok2 then
            UI.previewImage, UI.previewImage2 = img1, img2
            break
        end
        if ok1 and not UI.previewImage then
            UI.previewImage = img1
        end
    end

    UI.bgShader = love.graphics.newShader(BG_SHADER)
    UI.bgPostShader = love.graphics.newShader(BG_WATERCOLOR_SHADER)
    UI.uiShader = love.graphics.newShader(UI_SHADER)
    UI.previewShader = love.graphics.newShader(PREVIEW_GRAYSCALE_SHADER)
    UI.previewShader:send("colorMax", PREVIEW_COLOR_MAX)
    UI.handCursor = love.mouse.getSystemCursor("hand")

    UI.gameStartSound = nil
    local okGs, gsSrc = pcall(love.audio.newSource, "src/audio/game-start.wav", "static")
    if okGs and gsSrc then
        UI.gameStartSound = gsSrc
    end

    UI.hoverSound = nil
    local okHov, hovSrc = pcall(love.audio.newSource, "src/audio/hover.mp3", "static")
    if okHov and hovSrc then
        UI.hoverSound = hovSrc
    end

    UI.optionsSound = nil
    local okOpt, optSrc = pcall(love.audio.newSource, "src/audio/options.wav", "static")
    if okOpt and optSrc then
        UI.optionsSound = optSrc
    end

    applyAudioVolumes()
    updateLayout()
    initParticles()
end

function updateLayout()
    local w, h = love.graphics.getDimensions()
    UI.scale = math.min(w / UI.V_WIDTH, h / UI.V_HEIGHT)
    UI.offsetX = math.floor((w - UI.V_WIDTH * UI.scale) * 0.5 + 0.5)
    UI.offsetY = math.floor((h - UI.V_HEIGHT * UI.scale) * 0.5 + 0.5)
    refreshUiFonts()
    refreshSettingsFonts()
end

function love.resize(w, h)
    updateLayout()
    initParticles()
end

local function updatePreviewHoverMix(dt)
    if menuShowsOptionsDetail() then
        UI.previewHoverMix = 0
        UI.lastPreviewImgHover = false
        return
    end
    if not (UI.previewImage or UI.previewImage2) then
        UI.previewHoverMix = 0
        UI.lastPreviewImgHover = false
        return
    end
    local _, _, _, ph = getPreviewLayout()
    local imageH = ph - PREVIEW_FOOTER_H
    if imageH <= 8 then
        UI.previewHoverMix = 0
        UI.lastPreviewImgHover = false
        return
    end
    local sx, sy, sw, shImg = getPreviewImageScreenRect()
    local mx, my = love.mouse.getPosition()
    local hover = mx >= sx and mx < sx + sw and my >= sy and my < sy + shImg
    if hover and not UI.lastPreviewImgHover and not UI.irisActive then
        playHoverSound()
    end
    UI.lastPreviewImgHover = hover
    local target = hover and 1 or 0
    local k = PREVIEW_HOVER_LERP_RATE
    UI.previewHoverMix = UI.previewHoverMix + (target - UI.previewHoverMix) * (1 - math.exp(-k * dt))
end

function love.update(dt)
    UI.timer = UI.timer + dt

    if UI.irisActive then
        UI.irisTime = UI.irisTime + dt
        if UI.irisTime >= IRIS_OUT_DURATION then
            UI.irisActive = false
            UI.view = "game"
            UI.gameScreenT = 0
            love.mouse.setCursor()
        end
    elseif UI.view == "game" then
        UI.gameScreenT = (UI.gameScreenT or 0) + dt
        return
    end

    local target = UI.selection
    local x = UI.lerpSelection
    local v = UI.lerpVel
    local accel = (target - x) * SPRING_K - v * SPRING_C
    v = v + accel * dt
    x = x + v * dt
    if math.abs(target - x) < 0.0008 and math.abs(v) < 0.02 then
        x, v = target, 0
    end
    UI.lerpSelection, UI.lerpVel = x, v

    UI.menuOptionsT = UI.menuOptionsT
        + (UI.menuOptionsTarget - UI.menuOptionsT) * (1 - math.exp(-MENU_OPTIONS_T_RATE * dt))

    local detailNow = menuShowsOptionsDetail()
    if detailNow and not UI.optionsDetailView then
        UI.optionsDetailView = true
        UI.selection = 1
        UI.lerpSelection = 1
        UI.lerpVel = 0
        UI.audioSliderFocus = 1
    elseif not detailNow then
        UI.optionsDetailView = false
    end

    local sw, sh = love.graphics.getDimensions()
    for _, p in ipairs(UI.particles) do
        p.phase = p.phase + dt * p.wob
        p.x = p.x + (p.vx + math.sin(p.phase) * 3) * dt
        p.y = p.y + (p.vy + math.cos(p.phase * 0.7) * 2) * dt
        if p.x < -40 then
            p.x = sw + 40
            p.y = randomParticleYForXOutsideRadial(p.x, sw, sh)
        elseif p.x > sw + 40 then
            p.x = -40
            p.y = randomParticleYForXOutsideRadial(p.x, sw, sh)
        end
        if p.y < -40 then
            p.y = sh + 40
            p.x = randomParticleXForYOutsideRadial(p.y, sw, sh)
        elseif p.y > sh + 40 then
            p.y = -40
            p.x = randomParticleXForYOutsideRadial(p.y, sw, sh)
        end
        nudgeParticleOutOfRadialSymbol(p, sw, sh)
    end

    updateMenuCursor()
    updatePreviewHoverMix(dt)
    updatePreviewShotCycle()
end

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
    UI.bgShader:send("screenSize", {sw, sh})
    love.graphics.setShader(UI.bgShader)

    if UI.bgImage then
        love.graphics.setColor(1, 1, 1, 0.76)
        local iw, ih = UI.bgImage:getDimensions()
        local sc = math.max(sw / iw, sh / ih)
        local ox = (sw - iw * sc) * 0.5
        local oy = (sh - ih * sc) * 0.5
        love.graphics.draw(UI.bgImage, ox, oy, 0, sc, sc)
    end

    local br, bgc, bb = getCyclingBackgroundRgb()
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

function drawBackground()
    local sw, sh = love.graphics.getDimensions()
    ensureBgCanvas(sw, sh)

    love.graphics.setCanvas(UI.bgCanvas)
    love.graphics.clear(0, 0, 0, 1)
    drawBackgroundLayers(sw, sh)
    love.graphics.setCanvas()

    UI.bgPostShader:send("time", UI.timer)
    UI.bgPostShader:send("screenSize", {sw, sh})
    love.graphics.setShader(UI.bgPostShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(UI.bgCanvas, 0, 0)
    love.graphics.setShader()
end

local function drawPreviewPanel()
    local fp = 1 - menuOptionsEase()
    local x0, y0, pw, ph = getPreviewLayout()
    local sx, sy, sw, shImg = getPreviewImageScreenRect()
    local sh = math.max(1, math.floor(ph * UI.scale + 0.5))
    local o = PREVIEW_OUTLINE_PX

    local imageH = ph - PREVIEW_FOOTER_H

    local ox, oy, drawW, drawH, sc
    local layoutImg = UI.previewImage or UI.previewImage2
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

    love.graphics.setColor(0.88, 0.14, 0.12, fp)
    love.graphics.rectangle("fill", x0, fy, pw, PREVIEW_FOOTER_RULE_VIRT)

    love.graphics.setColor(1, 1, 1, fp)
    love.graphics.rectangle("fill", x0, fy + PREVIEW_FOOTER_RULE_VIRT, pw, PREVIEW_FOOTER_H - PREVIEW_FOOTER_RULE_VIRT)

    love.graphics.pop()

    local textPadX, textPadY = 18, 12
    local txtX = math.floor(UI.offsetX + (x0 + textPadX) * UI.scale + 0.5)
    local txtY = math.floor(UI.offsetY + (fy + PREVIEW_FOOTER_RULE_VIRT + textPadY) * UI.scale + 0.5)
    local wrapPx = math.max(48, math.floor((pw - textPadX * 2) * UI.scale + 0.5))
    love.graphics.setShader()
    love.graphics.setFont(UI.fontFooter)
    love.graphics.setColor(0.14, 0.14, 0.16, fp)
    love.graphics.printf(UI.updateInfoText, txtX, txtY, wrapPx, "left")

    love.graphics.setColor(1, 1, 1, fp)
    love.graphics.rectangle("fill", sx - o, sy - o, sw + o * 2, o)
    love.graphics.rectangle("fill", sx - o, sy + sh, sw + o * 2, o)
    love.graphics.rectangle("fill", sx - o, sy, o, sh)
    love.graphics.rectangle("fill", sx + sw, sy, o, sh)
end

function drawAmbientParticles()
    local prevBlend, prevAlpha = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add", "alphamultiply")
    local pm = UI.settings.particlesLight and 0.3 or 1

    for _, p in ipairs(UI.particles) do
        local tw = 0.5 + math.sin(UI.timer * 1.1 + p.phase) * 0.35
        love.graphics.setColor(1, 0.82, 0.65, p.a * tw * pm)
        love.graphics.circle("fill", p.x, p.y, p.r)
        love.graphics.setColor(1, 0.95, 0.85, p.a * tw * 0.35 * pm)
        love.graphics.circle("fill", p.x, p.y, p.r * 2.4)
    end

    love.graphics.setBlendMode(prevBlend, prevAlpha)
end

function drawUI()
    local inSettings = menuShowsOptionsDetail()
    local fadeRest = inSettings and 1 or (1 - menuOptionsEase())
    local logoA = inSettings and 0 or (1 - menuOptionsEase())

    love.graphics.push()
    love.graphics.translate(UI.offsetX, UI.offsetY)
    love.graphics.scale(UI.scale)

    local logoHover = math.sin(UI.timer * 1.5) * 10
    local logoScale = getLogoDrawScale() * 0.8
    local bannerShadowOx, bannerShadowOy = 5, 7

    UI.uiShader:send("time", UI.timer)
    love.graphics.setShader(UI.uiShader)

    if logoA > 0.01 then
        love.graphics.setColor(0, 0, 0, 0.2 * logoA)
        love.graphics.draw(UI.logo, LOGO_X + bannerShadowOx, LOGO_Y + logoHover + bannerShadowOy, 0, logoScale, logoScale)

        love.graphics.setColor(1, 1, 1, logoA)
        love.graphics.draw(UI.logo, LOGO_X, LOGO_Y + logoHover, 0, logoScale, logoScale)
    end

    local te = menuOptionsEase()
    local ax = rowCenterX(UI.menuOptionsT)
    local bannerAx = inSettings and MENU_PILL_CENTER_X or ax
    local selTy = interpRowMetric(UI.lerpSelection, function(ii)
        return rowTextY(ii, UI.menuOptionsT)
    end)
    local rs = 1 + (MENU_OPTIONS_SCALE_MAX - 1) * te

    love.graphics.translate(bannerAx, selTy + MENU_OPTIONS_BANNER_PIVOT_Y)
    love.graphics.scale(rs)
    love.graphics.setColor(0, 0, 0, 0.2)
    love.graphics.polygon("fill", -235, -33, 275, -33, 245, 40, -265, 40)
    love.graphics.setColor(1, 1, 1)
    love.graphics.polygon("fill", -240, -36.5, 270, -36.5, 240, 36.5, -270, 36.5)

    love.graphics.setShader()
    love.graphics.pop()

    love.graphics.setFont(UI.fontMain)
    for i, label in ipairs(getMenuLabels()) do
        local ty = rowTextY(i, UI.menuOptionsT)
        local axRow = rowCenterX(UI.menuOptionsT)
        local axDraw = inSettings and MENU_PILL_CENTER_X or axRow
        local sx = UI.offsetX + axDraw * UI.scale
        local sy = UI.offsetY + ty * UI.scale
        local isSelected = (i == UI.selection)
        local w = UI.fontMain:getWidth(label)
        -- translate(sx,sy) and scale(rs) are in screen space; offsets must be (screen px)/rs.
        -- Center every row on the same axis as the selection pill (main menu moves with rowCenterX;
        -- options stay on MENU_PILL_CENTER_X). A fixed left margin only looked OK before the pill grew.
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
                local iconScr = leftScr - 10 * UI.scale - iconR + cappyBounce * UI.scale
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
            labelDy = -MENU_OPTIONS_TEXT_NUDGE_SCREEN_PX / rs
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

function love.draw()
    if UI.view == "game" then
        drawGamePlaceholder()
        return
    end

    drawBackground()
    drawAmbientParticles()
    if menuShowsOptionsDetail() then
        drawSettingsPanel()
    else
        drawPreviewPanel()
    end
    drawUI()

    if UI.irisActive then
        drawIrisCloseToBlack()
    end
end

function love.keypressed(key)
    if UI.view == "game" or UI.irisActive then
        return
    end
    if key == "escape" and UI.menuOptionsTarget > 0.5 then
        if menuShowsOptionsDetail() then
            closeOptionsMenuLayout()
        else
            UI.menuOptionsTarget = 0
        end
        return
    end
    if menuShowsOptionsDetail() and UI.selection == 1 then
        if key == "tab" then
            UI.audioSliderFocus = (UI.audioSliderFocus % 3) + 1
            return
        end
        if key == "[" then
            nudgeAudioSlider(-0.04)
            return
        end
        if key == "]" then
            nudgeAudioSlider(0.04)
            return
        end
    end
    local nLab = #getMenuLabels()
    if key == "up" or key == "w" then
        UI.selection = UI.selection - 1
        if UI.selection < 1 then UI.selection = nLab end
    elseif key == "down" or key == "s" then
        UI.selection = UI.selection + 1
        if UI.selection > nLab then UI.selection = 1 end
    elseif key == "return" or key == "kpenter" or key == "space" then
        activateMenuOption(UI.selection)
    end
end

function love.mousemoved(x, y, dx, dy)
    if UI.view == "game" or UI.irisActive then
        return
    end
    if UI.settingsDrag then
        updateSettingsSliderDrag(screenToVirtual(x, y))
    end
    local vx, vy = screenToVirtual(x, y)
    local idx = getMenuIndexAtVirtual(vx, vy)
    if idx then UI.selection = idx end
end

function love.mousepressed(x, y, button, istouch, presses)
    if UI.view == "game" or UI.irisActive then
        return
    end
    if button ~= 1 then return end
    local vx, vy = screenToVirtual(x, y)
    if trySettingsPanelMousePressed(vx, vy, button) then
        return
    end
    local idx = getMenuIndexAtVirtual(vx, vy)
    if idx then
        UI.selection = idx
        activateMenuOption(idx)
    end
end

function love.mousereleased(x, y, button, istouch, presses)
    if button == 1 then
        if UI.settingsDrag then
            saveSettings()
        end
        UI.settingsDrag = nil
    end
end
