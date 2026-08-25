local BASE_URL = "https://raw.githubusercontent.com/vxmpie/Genesis/main/Roblox/games/storage_hunter/"

local function loadModule(relPath)
    local localPath = "Roblox/games/storage_hunter/" .. relPath
    if isfile and isfile(localPath) then
        local fn, err = loadstring(readfile(localPath))
        if fn then return fn() end
    end
    local fullUrl = BASE_URL .. relPath
    local success, code = pcall(function()
        return game:HttpGet(fullUrl)
    end)
    if success and code and #code > 0 then
        local fn, err = loadstring(code)
        if fn then return fn() end
    end
    return nil
end

local Config = loadModule("config.lua")
Config.Load()

local WashModule = loadModule("functions/wash.lua")
local AntiAFK = loadModule("functions/anti_afk.lua")
local UI = loadModule("ui.lua")

if AntiAFK and AntiAFK.Init then
    AntiAFK.Init(Config)
end

if UI and UI.Create then
    UI.Create(Config, WashModule, AntiAFK)
end

if Config.Get("AutoWash", false) and WashModule and WashModule.StartAutoWashLoop then
    WashModule.StartAutoWashLoop(Config.GetState())
end
