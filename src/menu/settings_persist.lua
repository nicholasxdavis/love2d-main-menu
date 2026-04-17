local config = require("src.constants.menu_config")

local M = {}

function M.saveSettings(UI)
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
        "menuBgMusic=" .. (s.menuBgMusic and "1" or "0"),
        "menuMusicShuffle=" .. (s.menuMusicShuffle and "1" or "0"),
    }
    love.filesystem.write(config.SETTINGS_FILE, table.concat(lines, "\n"))
end

function M.loadSettings(UI)
    if not love.filesystem.getInfo(config.SETTINGS_FILE) then
        return
    end
    local text = love.filesystem.read(config.SETTINGS_FILE)
    if not text then
        return
    end
    for line in text:gmatch("[^\r\n]+") do
        local k, v = line:match("^(%w+)=(.*)$")
        if k and v then
            if k == "master" or k == "music" or k == "sfx" then
                local n = tonumber(v)
                if n then
                    UI.settings[k] = math.max(0, math.min(1, n))
                end
            elseif k == "vsync" or k == "fullscreen" or k == "particlesLight" then
                UI.settings[k] = (v == "1" or v == "true")
            elseif k == "winW" or k == "winH" then
                local n = tonumber(v)
                if n then
                    UI.settings[k] = math.floor(n)
                end
            elseif k == "resIdx" then
                local n = tonumber(v)
                if n then
                    UI.settings.resIdx = math.max(1, math.min(#config.RES_PRESETS, math.floor(n)))
                end
            elseif k == "menuBgMusic" or k == "menuMusicShuffle" then
                UI.settings[k] = (v == "1" or v == "true")
            end
        end
    end
end

return M
