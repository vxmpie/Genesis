local Core = {}
local Players = game:GetService("Players")
local PlaceId = game.PlaceId

local REPO_URL = "https://raw.githubusercontent.com/vxmpie/Genesis/main/"

local function loadModule(path)
    local success, result = pcall(function()
        return loadstring(game:HttpGet(REPO_URL .. path))()
    end)
    
    if success then 
        return result 
    else 
        warn("[GENESIS HUB] Failed to load module: " .. path) 
        return nil 
    end
end

local SupportedGames = {
    [124757309017950] = "games/ice_tycoon_2.lua"
}

function Core.init()
    local UILibrary = loadModule("ui/library.lua")
    
    local gameModulePath = SupportedGames[PlaceId]
    
    if not gameModulePath then
        warn("[GENESIS HUB] Game not supported yet! PlaceId: " .. tostring(PlaceId))
        return
    end

    local GameLogic = loadModule(gameModulePath)

    if GameLogic and UILibrary then
        if GameLogic.initUI then
            GameLogic.initUI(UILibrary)
        end
    end
end

Core.init()