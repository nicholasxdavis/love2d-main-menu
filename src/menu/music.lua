local state = require("src.menu.state")
local config = require("src.constants.menu_config")
local settings_persist = require("src.menu.settings_persist")

local UI = state.UI
local MenuMusic = state.MenuMusic

local M = {}

function M.scanMenuMusicTracks()
    MenuMusic.tracks = {}
    local dirInfo = love.filesystem.getInfo(config.MENU_MUSIC_DIR)
    if not dirInfo or dirInfo.type ~= "directory" then
        return
    end
    local names = love.filesystem.getDirectoryItems(config.MENU_MUSIC_DIR)
    table.sort(names)
    for _, name in ipairs(names) do
        local ext = name:lower():match("%.%w+$")
        if ext and config.MENU_MUSIC_EXT[ext] then
            MenuMusic.tracks[#MenuMusic.tracks + 1] = config.MENU_MUSIC_DIR .. "/" .. name
        end
    end
    MenuMusic.trackIndex = math.max(1, math.min(math.max(1, #MenuMusic.tracks), MenuMusic.trackIndex))
end

function M.releaseMenuMusicSource()
    if MenuMusic.source then
        MenuMusic.source:stop()
        MenuMusic.source:release()
        MenuMusic.source = nil
    end
end

function M.applyMenuMusicVolume(UI_)
    if MenuMusic.source then
        MenuMusic.source:setVolume(UI_.settings.music)
    end
end

function M.playMenuTrackAt(idx)
    local paths = MenuMusic.tracks
    local n = #paths
    if n < 1 then
        return
    end
    idx = math.max(1, math.min(n, math.floor(idx)))
    M.releaseMenuMusicSource()
    local path = paths[idx]
    local ok, src = pcall(love.audio.newSource, path, "stream")
    if not ok or not src then
        return
    end
    src:setLooping(false)
    MenuMusic.source = src
    MenuMusic.trackIndex = idx
    MenuMusic.playShieldT = 0.4
    M.applyMenuMusicVolume(UI)
    src:play()
end

function M.advanceMenuTrack()
    local n = #MenuMusic.tracks
    if n < 1 then
        return
    end
    if UI.settings.menuMusicShuffle then
        local nextIdx = MenuMusic.trackIndex
        if n > 1 then
            repeat
                nextIdx = love.math.random(1, n)
            until nextIdx ~= MenuMusic.trackIndex
        else
            nextIdx = 1
        end
        MenuMusic.trackIndex = nextIdx
    else
        MenuMusic.trackIndex = (MenuMusic.trackIndex % n) + 1
    end
    M.playMenuTrackAt(MenuMusic.trackIndex)
end

function M.updateMenuMusic(dt)
    if UI.view ~= "menu" then
        if MenuMusic.source and MenuMusic.source:isPlaying() then
            MenuMusic.source:stop()
        end
        MenuMusic.gatePlaying = false
        return
    end

    if MenuMusic.playShieldT > 0 then
        MenuMusic.playShieldT = math.max(0, MenuMusic.playShieldT - dt)
    end

    if not UI.settings.menuBgMusic or #MenuMusic.tracks < 1 then
        if MenuMusic.source and MenuMusic.source:isPlaying() then
            MenuMusic.source:stop()
        end
        MenuMusic.gatePlaying = false
        return
    end

    local src = MenuMusic.source
    local playing = src and src:isPlaying()
    if not playing then
        local endedNaturally = MenuMusic.gatePlaying and MenuMusic.playShieldT <= 0
        if endedNaturally then
            M.advanceMenuTrack()
        else
            M.playMenuTrackAt(MenuMusic.trackIndex)
        end
    end

    M.applyMenuMusicVolume(UI)
    MenuMusic.gatePlaying = MenuMusic.source and MenuMusic.source:isPlaying()
end

function M.toggleMenuBgMusicSetting()
    UI.settings.menuBgMusic = not UI.settings.menuBgMusic
    if not UI.settings.menuBgMusic then
        MenuMusic.gatePlaying = false
        if MenuMusic.source then
            MenuMusic.source:stop()
        end
    end
    settings_persist.saveSettings(UI)
end

function M.toggleMenuMusicShuffleSetting()
    UI.settings.menuMusicShuffle = not UI.settings.menuMusicShuffle
    settings_persist.saveSettings(UI)
end

return M
