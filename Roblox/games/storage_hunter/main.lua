if _G.GenesisUnload then
    pcall(_G.GenesisUnload)
end

local BASE_URL = "https://raw.githubusercontent.com/vxmpie/Genesis/main/Roblox/games/storage_hunter/"

local function loadModule(relPath)
    local localPath = "Roblox/games/storage_hunter/" .. relPath
    if isfile and isfile(localPath) then
        local fn, err = loadstring(readfile(localPath))
        if fn then return fn() end
    end
    local fullUrl = BASE_URL .. relPath .. "?t=" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
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

local ResetModule = loadModule("functions/reset.lua")
local WashModule = loadModule("functions/wash.lua")
local GradingModule = loadModule("functions/grading.lua")
local UI = loadModule("ui.lua")

if UI and UI.Create then
    UI.Create(Config, ResetModule, WashModule, GradingModule)
end

if Config.Get("AutoWash", false) and WashModule and WashModule.StartAutoWashLoop then
    WashModule.StartAutoWashLoop(Config.GetState())
end

if Config.Get("AutoGrade", false) and GradingModule and GradingModule.StartAutoGradeLoop then
    GradingModule.StartAutoGradeLoop(Config.GetState())
end
