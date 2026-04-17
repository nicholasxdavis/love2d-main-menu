local M = {}

M.UI = {
    selection = 1,
    lerpSelection = 1,
    lerpVel = 0,
    timer = 0,
    options = { "RESUME", "NEW GAME", "OPTIONS", "EXIT" },
    optionsDetail = { "AUDIO", "GRAPHICS", "WINDOW", "BACK" },

    view = "menu",
    irisActive = false,
    irisTime = 0,
    gameScreenT = 0,

    V_WIDTH = 1920,
    V_HEIGHT = 1080,
    scale = 1,
    offsetX = 0,
    offsetY = 0,

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
    sliderThumbStar = nil,
    handCursor = nil,
    fontFooter = nil,
    fontVersion = nil,
    fontPreviewUpdate = nil,
    fontMain = nil,
    fontMainPx = 0,
    fontFooterPx = 0,
    fontVersionPx = 0,
    fontPreviewUpdatePx = 0,
    fontPreviewUpdateTargetPx = 0,
    updateInfoText = "UPDATE: v1.0 — Patch notes, version info, and latest news appear here.",

    gameStartSound = nil,
    hoverSound = nil,
    optionsSound = nil,
    lastHoverMenuIndex = nil,
    lastPreviewImgHover = false,

    menuOptionsT = 0,
    menuOptionsTarget = 0,
    optionsDetailView = false,
    --- Options detail rows only: hover lift 0..1 per index (smoothed in app.update).
    optionsDetailHoverLift = { 0, 0, 0, 0 },

    settings = {
        master = 1,
        music = 1,
        sfx = 1,
        menuBgMusic = true,
        menuMusicShuffle = false,
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

M.MenuMusic = {
    tracks = {},
    source = nil,
    trackIndex = 1,
    gatePlaying = false,
    playShieldT = 0,
}

return M
