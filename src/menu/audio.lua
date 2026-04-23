local menu_music = require("src.menu.music")

local M = {}

function M.applyAudioVolumes(UI)
    local st = UI.settings
    love.audio.setVolume(st.master)
    local sv = st.sfx
    if UI.hoverSound then
        UI.hoverSound:setVolume(sv)
    end
    if UI.gameStartSound then
        UI.gameStartSound:setVolume(sv)
    end
    if UI.typeSound then
        UI.typeSound:setVolume(sv * 0.75)
    end
    if UI.optionSwitchSound then
        UI.optionSwitchSound:setVolume(sv * 0.35)
    end
    if UI.optionsSound then
        UI.optionsSound:setVolume(sv)
    end
    menu_music.applyMenuMusicVolume(UI)
end

function M.applyVsyncFlag(UI)
    pcall(love.window.setVSync, UI.settings.vsync)
end

return M
