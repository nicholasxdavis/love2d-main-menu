local state = require("src.menu.state")
local config = require("src.constants.menu_config")
local fonts = require("src.utils.menu_fonts")
local settings_persist = require("src.menu.settings_persist")
local audio = require("src.menu.audio")
local music = require("src.menu.music")
local layout = require("src.menu.layout")
local particles = require("src.menu.particles")
local settings_panel = require("src.menu.settings_panel")
local background = require("src.menu.background")
local preview = require("src.menu.preview")
local draw_ui = require("src.menu.draw_ui")
local game_view = require("src.menu.game_view")

local UI = state.UI

local M = {}

local function updateMenuCursor()
    if UI.view == "game" or UI.irisActive then
        love.mouse.setCursor()
        return
    end
    local mx, my = love.mouse.getPosition()
    if settings_panel.settingsPanelWantsHand(mx, my) then
        love.mouse.setCursor(UI.handCursor)
        return
    end
    local vx, vy = layout.screenToVirtual(mx, my)
    local idx = layout.getMenuIndexAtVirtual(vx, vy)
    if idx then
        love.mouse.setCursor(UI.handCursor)
        if idx ~= UI.lastHoverMenuIndex then
            layout.playHoverSound()
        end
        UI.lastHoverMenuIndex = idx
    else
        love.mouse.setCursor()
        UI.lastHoverMenuIndex = nil
    end
end

function M.load()
    love.graphics.setDefaultFilter("linear", "linear", 1)
    fonts.captureDefaultFontLineHeights()
    settings_persist.loadSettings(UI)
    local s = UI.settings
    love.window.setMode(s.winW, s.winH, config.WINDOW_FLAGS)
    if s.fullscreen then
        love.window.setFullscreen(true, "desktop")
    end
    audio.applyVsyncFlag(UI)
    for i, p in ipairs(config.RES_PRESETS) do
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
    if ok then
        UI.bgImage = img
    end
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

    UI.bgShader = love.graphics.newShader(config.BG_SHADER)
    UI.bgPostShader = love.graphics.newShader(config.BG_WATERCOLOR_SHADER)
    UI.uiShader = love.graphics.newShader(config.UI_SHADER)
    UI.previewShader = love.graphics.newShader(config.PREVIEW_GRAYSCALE_SHADER)
    UI.previewShader:send("colorMax", config.PREVIEW_COLOR_MAX)
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

    music.scanMenuMusicTracks()

    audio.applyAudioVolumes(UI)
    layout.updateLayout()
    particles.init()
end

function M.resize()
    layout.updateLayout()
    particles.init()
end

function M.update(dt)
    UI.timer = UI.timer + dt
    music.updateMenuMusic(dt)

    if UI.irisActive then
        UI.irisTime = UI.irisTime + dt
        if UI.irisTime >= config.IRIS_OUT_DURATION then
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
    local accel = (target - x) * config.SPRING_K - v * config.SPRING_C
    v = v + accel * dt
    x = x + v * dt
    if math.abs(target - x) < 0.0008 and math.abs(v) < 0.02 then
        x, v = target, 0
    end
    UI.lerpSelection, UI.lerpVel = x, v

    UI.menuOptionsT = UI.menuOptionsT
        + (UI.menuOptionsTarget - UI.menuOptionsT) * (1 - math.exp(-config.MENU_OPTIONS_T_RATE * dt))

    local detailNow = layout.menuShowsOptionsDetail()
    if detailNow and not UI.optionsDetailView then
        UI.optionsDetailView = true
        UI.selection = 1
        UI.lerpSelection = 1
        UI.lerpVel = 0
        UI.audioSliderFocus = 1
    elseif not detailNow then
        UI.optionsDetailView = false
    end

    particles.update(dt)
    updateMenuCursor()
    preview.updateHoverMix(dt)
    preview.updateShotCycle()
end

function M.draw()
    if UI.view == "game" then
        game_view.drawGamePlaceholder()
        return
    end

    background.draw()
    particles.draw()
    if layout.menuShowsOptionsDetail() then
        settings_panel.drawSettingsPanel()
    else
        preview.drawPanel()
    end
    draw_ui.draw()

    if UI.irisActive then
        game_view.drawIrisCloseToBlack()
    end
end

function M.keypressed(key)
    if UI.view == "game" or UI.irisActive then
        return
    end
    if key == "escape" and UI.menuOptionsTarget > 0.5 then
        if layout.menuShowsOptionsDetail() then
            layout.closeOptionsMenuLayout()
        else
            UI.menuOptionsTarget = 0
        end
        return
    end
    if layout.menuShowsOptionsDetail() and UI.selection == 1 then
        if key == "tab" then
            UI.audioSliderFocus = (UI.audioSliderFocus % 3) + 1
            return
        end
        if key == "[" then
            settings_panel.nudgeAudioSlider(-0.04)
            return
        end
        if key == "]" then
            settings_panel.nudgeAudioSlider(0.04)
            return
        end
    end
    local nLab = #layout.getMenuLabels()
    if key == "up" or key == "w" then
        UI.selection = UI.selection - 1
        if UI.selection < 1 then
            UI.selection = nLab
        end
    elseif key == "down" or key == "s" then
        UI.selection = UI.selection + 1
        if UI.selection > nLab then
            UI.selection = 1
        end
    elseif key == "return" or key == "kpenter" or key == "space" then
        layout.activateMenuOption(UI.selection)
    end
end

function M.mousemoved(x, y, dx, dy)
    if UI.view == "game" or UI.irisActive then
        return
    end
    if UI.settingsDrag then
        settings_panel.updateSettingsSliderDrag(layout.screenToVirtual(x, y))
    end
    local vx, vy = layout.screenToVirtual(x, y)
    local idx = layout.getMenuIndexAtVirtual(vx, vy)
    if idx then
        UI.selection = idx
    end
end

function M.mousepressed(x, y, button, istouch, presses)
    if UI.view == "game" or UI.irisActive then
        return
    end
    if button ~= 1 then
        return
    end
    local vx, vy = layout.screenToVirtual(x, y)
    if settings_panel.trySettingsPanelMousePressed(vx, vy, button) then
        return
    end
    local idx = layout.getMenuIndexAtVirtual(vx, vy)
    if idx then
        UI.selection = idx
        layout.activateMenuOption(idx)
    end
end

function M.mousereleased(x, y, button, istouch, presses)
    if button == 1 then
        if UI.settingsDrag then
            settings_persist.saveSettings(UI)
        end
        UI.settingsDrag = nil
    end
end

function M.quit()
    music.releaseMenuMusicSource()
end

return M
