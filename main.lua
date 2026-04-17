local UI = {
    selection = 1,
    lerpSelection = 1,
    lerpVel = 0,
    timer = 0,
    options = {"RESUME", "NEW GAME", "OPTIONS", "EXIT"},

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
    lastHoverMenuIndex = nil,
    lastPreviewImgHover = false,
}

local SPRING_K = 260
local SPRING_C = 24

local FONT_MENU = "src/fonts/SairaExtraCondensed-Regular.ttf"
local FONT_MENU_BOLD = "src/fonts/SairaExtraCondensed-ExtraBold.ttf"
local REF_MAIN_LINE_H, REF_FOOT_LINE_H, REF_VERSION_LINE_H

local function captureDefaultFontLineHeights()
    local fm = love.graphics.newFont(52)
    REF_MAIN_LINE_H = fm:getHeight()
    fm:release()
    local ff = love.graphics.newFont(26)
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

local LOGO_X, LOGO_Y = 98, 98
local LOGO_TARGET_W = 450
local LOGO_SCALE_MUL = 0.94

local PREVIEW_W = 930
local PREVIEW_H = 485
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

local function screenToVirtual(mx, my)
    return (mx - UI.offsetX) / UI.scale, (my - UI.offsetY) / UI.scale
end

local function virtToScreen(vx, vy)
    return math.floor(UI.offsetX + vx * UI.scale + 0.5), math.floor(UI.offsetY + vy * UI.scale + 0.5)
end

local function refreshUiFonts()
    if not UI.scale or UI.scale <= 0 then return end
    local mainPx = math.max(24, math.floor(52 * UI.scale + 0.5))
    local footPx = math.max(15, math.floor(26 * UI.scale + 0.5))
    if mainPx ~= UI.fontMainPx then
        if UI.fontMain then UI.fontMain:release() end
        local targetMainH = REF_MAIN_LINE_H and (REF_MAIN_LINE_H * mainPx / 52) or mainPx
        UI.fontMain = newFontFitLineHeight(FONT_MENU_BOLD, mainPx, targetMainH, 24)
        UI.fontMainPx = mainPx
    end
    if footPx ~= UI.fontFooterPx then
        if UI.fontFooter then UI.fontFooter:release() end
        local targetFootH = REF_FOOT_LINE_H and (REF_FOOT_LINE_H * footPx / 26) or footPx
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

local function getMenuIndexAtVirtual(vx, vy)
    for i = 1, #UI.options do
        local rowY = MENU_START_Y + (i - 1) * MENU_SPACING
        local y0, y1 = rowY - 12, rowY + 80
        if vx >= 25 and vx <= 585 and vy >= y0 and vy <= y1 then
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

local function activateMenuOption(index)
    if UI.irisActive or UI.view == "game" then
        return
    end
    local label = UI.options[index]
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

local function initParticles()
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
    love.window.setMode(1280, 720, {resizable = true, highdpi = true})
    love.mouse.setRelativeMode(false)
    love.mouse.setVisible(true)
    love.graphics.setDefaultFilter("linear", "linear", 1)

    captureDefaultFontLineHeights()

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

    updateLayout()
    initParticles()
end

function updateLayout()
    local w, h = love.graphics.getDimensions()
    UI.scale = math.min(w / UI.V_WIDTH, h / UI.V_HEIGHT)
    UI.offsetX = math.floor((w - UI.V_WIDTH * UI.scale) * 0.5 + 0.5)
    UI.offsetY = math.floor((h - UI.V_HEIGHT * UI.scale) * 0.5 + 0.5)
    refreshUiFonts()
end

function love.resize(w, h)
    updateLayout()
    initParticles()
end

local function updatePreviewHoverMix(dt)
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

    love.graphics.setColor(0.99, 0.99, 0.98, 1)
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
                love.graphics.setColor(1, 1, 1, 1 - mix)
                love.graphics.draw(UI.previewImage, gx, gy, 0, imgSc, imgSc)
            end
            if mix > 0.002 then
                love.graphics.setColor(1, 1, 1, mix)
                love.graphics.draw(UI.previewImage2, gx, gy, 0, imgSc, imgSc)
            end
        else
            love.graphics.setColor(1, 1, 1, 1)
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

    love.graphics.setColor(0.88, 0.14, 0.12)
    love.graphics.rectangle("fill", x0, fy, pw, PREVIEW_FOOTER_RULE_VIRT)

    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", x0, fy + PREVIEW_FOOTER_RULE_VIRT, pw, PREVIEW_FOOTER_H - PREVIEW_FOOTER_RULE_VIRT)

    love.graphics.pop()

    local textPadX, textPadY = 18, 12
    local txtX = math.floor(UI.offsetX + (x0 + textPadX) * UI.scale + 0.5)
    local txtY = math.floor(UI.offsetY + (fy + PREVIEW_FOOTER_RULE_VIRT + textPadY) * UI.scale + 0.5)
    local wrapPx = math.max(48, math.floor((pw - textPadX * 2) * UI.scale + 0.5))
    love.graphics.setShader()
    love.graphics.setFont(UI.fontFooter)
    love.graphics.setColor(0.14, 0.14, 0.16)
    love.graphics.printf(UI.updateInfoText, txtX, txtY, wrapPx, "left")

    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", sx - o, sy - o, sw + o * 2, o)
    love.graphics.rectangle("fill", sx - o, sy + sh, sw + o * 2, o)
    love.graphics.rectangle("fill", sx - o, sy, o, sh)
    love.graphics.rectangle("fill", sx + sw, sy, o, sh)
end

function drawAmbientParticles()
    local prevBlend, prevAlpha = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add", "alphamultiply")

    for _, p in ipairs(UI.particles) do
        local tw = 0.5 + math.sin(UI.timer * 1.1 + p.phase) * 0.35
        love.graphics.setColor(1, 0.82, 0.65, p.a * tw)
        love.graphics.circle("fill", p.x, p.y, p.r)
        love.graphics.setColor(1, 0.95, 0.85, p.a * tw * 0.35)
        love.graphics.circle("fill", p.x, p.y, p.r * 2.4)
    end

    love.graphics.setBlendMode(prevBlend, prevAlpha)
end

function drawUI()
    love.graphics.push()
    love.graphics.translate(UI.offsetX, UI.offsetY)
    love.graphics.scale(UI.scale)

    local logoHover = math.sin(UI.timer * 1.5) * 10
    local logoScale = getLogoDrawScale() * 0.8
    local bannerShadowOx, bannerShadowOy = 5, 7

    UI.uiShader:send("time", UI.timer)
    love.graphics.setShader(UI.uiShader)

    love.graphics.setColor(0, 0, 0, 0.2)
    love.graphics.draw(UI.logo, LOGO_X + bannerShadowOx, LOGO_Y + logoHover + bannerShadowOy, 0, logoScale, logoScale)

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(UI.logo, LOGO_X, LOGO_Y + logoHover, 0, logoScale, logoScale)

    local startY = MENU_START_Y
    local spacing = MENU_SPACING
    local bannerY = startY + (UI.lerpSelection - 1) * spacing

    love.graphics.setColor(0, 0, 0, 0.2)
    love.graphics.polygon("fill", 65, bannerY + 2, 575, bannerY + 2, 545, bannerY + 75, 35, bannerY + 75)

    love.graphics.setColor(1, 1, 1)
    love.graphics.polygon("fill", 60, bannerY - 5, 570, bannerY - 5, 540, bannerY + 68, 30, bannerY + 68)

    love.graphics.setShader()
    love.graphics.pop()

    love.graphics.setFont(UI.fontMain)
    for i, label in ipairs(UI.options) do
        local y = startY + (i - 1) * spacing
        local isSelected = (i == UI.selection)
        local tx, ty = virtToScreen(135, y)

        if isSelected then
            local cappyBounce = math.abs(math.sin(UI.timer * 5)) * 5
            local cx, cy = virtToScreen(85 + cappyBounce, y + 32)
            local cr = math.max(3, math.floor(14 * UI.scale + 0.5))
            love.graphics.setColor(0.08, 0.08, 0.08, 1)
            if UI.menuBtnIcon then
                local iw, ih = UI.menuBtnIcon:getDimensions()
                local diam = 2 * cr
                local iconSc = diam / math.max(iw, ih)
                love.graphics.draw(UI.menuBtnIcon, cx, cy, 0, iconSc, iconSc, iw * 0.5, ih * 0.5)
            else
                love.graphics.circle("fill", cx, cy, cr)
            end
            love.graphics.setColor(0.08, 0.08, 0.08)
        else
            love.graphics.setColor(0.98, 0.98, 1, 0.94)
        end

        love.graphics.print(label, tx, ty)
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
    love.graphics.setColor(0, 0, 0, 0.42)
    love.graphics.print(verText, vx + 2, vy + 2)
    love.graphics.setColor(0.98, 0.98, 1, 0.96)
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
    drawPreviewPanel()
    drawUI()

    if UI.irisActive then
        drawIrisCloseToBlack()
    end
end

function love.keypressed(key)
    if UI.view == "game" or UI.irisActive then
        return
    end
    if key == "up" or key == "w" then
        UI.selection = UI.selection - 1
        if UI.selection < 1 then UI.selection = #UI.options end
    elseif key == "down" or key == "s" then
        UI.selection = UI.selection + 1
        if UI.selection > #UI.options then UI.selection = 1 end
    elseif key == "return" or key == "kpenter" or key == "space" then
        activateMenuOption(UI.selection)
    end
end

function love.mousemoved(x, y, dx, dy)
    if UI.view == "game" or UI.irisActive then
        return
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
    local idx = getMenuIndexAtVirtual(vx, vy)
    if idx then
        UI.selection = idx
        activateMenuOption(idx)
    end
end
