local Core = {}
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local PlaceId = game.PlaceId

local REPO_URL = "https://raw.githubusercontent.com/vxmpie/Genesis/main/"

local function loadModule(path)
    local success, result = pcall(function()
        return loadstring(game:HttpGet(REPO_URL .. path))()
    end)
    if success then return result else warn("[GENESIS] Failed: " .. path) return nil end
end

local function cleanupOldUI()
    if CoreGui:FindFirstChild("Rayfield") then
        CoreGui.Rayfield:Destroy()
    end
end

local SupportedGames = {
    [124757309017950] = "games/ice_tycoon_2/init.lua" 
}

function Core.init()
    cleanupOldUI() 
    
    local UILibrary = loadModule("ui/library.lua")
    local gameModulePath = SupportedGames[PlaceId]
    
    if not gameModulePath then
        warn("[GENESIS] Game not supported!")
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