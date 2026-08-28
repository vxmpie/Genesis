if _G.GenesisUnload then
    pcall(_G.GenesisUnload)
end

local BASE_URL = "https://raw.githubusercontent.com/vxmpie/Genesis/main/Roblox/games/storage_hunter/"

local modulePaths = {
    "config.lua",
    "functions/reset.lua",
    "functions/wash.lua",
    "functions/grading.lua",
    "functions/teleport.lua",
    "ui.lua"
}

local loadedModules = {}
local remaining = #modulePaths

for _, relPath in ipairs(modulePaths) do
    task.spawn(function()
        local fullUrl = BASE_URL .. relPath .. "?t=" .. tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
        local success, code = pcall(function()
            return game:HttpGet(fullUrl)
        end)
        if success and code and #code > 0 then
            local fn, err = loadstring(code)
            if fn then
                local res = fn()
                loadedModules[relPath] = res
            end
        end
        remaining = remaining - 1
    end)
end

local startWait = os.clock()
while remaining > 0 and (os.clock() - startWait < 6) do
    task.wait(0.02)
end

local Config = loadedModules["config.lua"]
if Config and Config.Load then
    Config.Load()
end

local ResetModule = loadedModules["functions/reset.lua"]
local WashModule = loadedModules["functions/wash.lua"]
local GradingModule = loadedModules["functions/grading.lua"]
local TeleportModule = loadedModules["functions/teleport.lua"]
local UI = loadedModules["ui.lua"]

if UI and UI.Create then
    UI.Create(Config, ResetModule, WashModule, GradingModule, TeleportModule)
end

if Config and Config.Get("AutoWash", false) and WashModule and WashModule.StartAutoWashLoop then
    WashModule.StartAutoWashLoop(Config.GetState())
end

if Config and Config.Get("AutoGrade", false) and GradingModule and GradingModule.StartAutoGradeLoop then
    GradingModule.StartAutoGradeLoop(Config.GetState())
end
