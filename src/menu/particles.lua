local state = require("src.menu.state")
local config = require("src.constants.menu_config")

local UI = state.UI

local M = {}

local function getParticleRadialSymbolParams(sw, sh)
    local scale = (UI.scale and UI.scale > 0) and UI.scale or math.min(sw / UI.V_WIDTH, sh / UI.V_HEIGHT)
    return sw * 0.75, sh * 0.45, 700 * scale
end

local function particleRadialExclRadiusSq(sw, sh)
    local _, _, r = getParticleRadialSymbolParams(sw, sh)
    local ex = r + config.PARTICLE_RADIAL_EXCL_PAD
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

function M.init()
    UI.particles = {}
    local sw, sh = love.graphics.getDimensions()
    for _ = 1, config.PARTICLE_COUNT do
        local x, y = randomParticlePosOutsideRadialSymbol(sw, sh)
        UI.particles[#UI.particles + 1] = {
            x = x,
            y = y,
            vx = (love.math.random() - 0.5) * 14,
            vy = (love.math.random() - 0.5) * 10 - 6,
            r = love.math.random(8, 22) * 0.1,
            a = love.math.random() * 0.22 + 0.06,
            phase = love.math.random() * 6.283,
            wob = 0.4 + love.math.random() * 1.2,
        }
    end
end

function M.update(dt)
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
end

function M.draw()
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

return M
