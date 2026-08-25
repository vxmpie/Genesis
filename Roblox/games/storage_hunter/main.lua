local Genesis = {}

local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")

print("==========================================")
print("[GENESIS] STORAGE HUNTERS HUB STARTING...")
print("==========================================")

pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "GENESIS HUB",
        Text = "Initializing Storage Hunters Hub...",
        Duration = 4
    })
end)

local BASE_URL = "https://raw.githubusercontent.com/vxmpie/Genesis/main/Roblox/games/storage_hunter/"

local function loadModule(relPath)
    local localPath = "Roblox/games/storage_hunter/" .. relPath
    if isfile and isfile(localPath) then
        local fn, err = loadstring(readfile(localPath))
        if fn then
            print("[GENESIS] Loaded local module:", relPath)
            return fn()
        end
    end
    local fullUrl = BASE_URL .. relPath
    local success, code = pcall(function()
        return game:HttpGet(fullUrl)
    end)
    if success and code and #code > 0 then
        local fn, err = loadstring(code)
        if fn then
            print("[GENESIS] Loaded remote module:", relPath)
            return fn()
        end
    end
    warn("[GENESIS] Failed to load module:", relPath)
    return nil
end

local Config = loadModule("config.lua")
local DB = loadModule("database/items.lua")

local General = loadModule("functions/general.lua")
local Auction = loadModule("functions/auction.lua")
local Loot = loadModule("functions/loot.lua")
local Fishing = loadModule("functions/fishing.lua")
local Processing = loadModule("functions/processing.lua")
local Shop = loadModule("functions/shop.lua")
local Reward = loadModule("functions/reward.lua")
local Quests = loadModule("functions/quests.lua")
local Index = loadModule("functions/index.lua")
local Utilities = loadModule("functions/utilities.lua")
local Optimization = loadModule("functions/optimization.lua")

local UI = loadModule("ui.lua")

local Modules = {
    Config = Config,
    DB = DB,
    General = General,
    Auction = Auction,
    Loot = Loot,
    Fishing = Fishing,
    Processing = Processing,
    Shop = Shop,
    Reward = Reward,
    Quests = Quests,
    Index = Index,
    Utilities = Utilities,
    Optimization = Optimization
}

if General and General.Init then General.Init(Config) end
if Auction and Auction.Init then Auction.Init(Config, DB) end
if Loot and Loot.Init then Loot.Init(Config, DB) end
if Fishing and Fishing.Init then Fishing.Init(Config, DB) end
if Processing and Processing.Init then Processing.Init(Config, DB) end
if Shop and Shop.Init then Shop.Init(Config, DB) end
if Reward and Reward.Init then Reward.Init(Config, DB) end
if Quests and Quests.Init then Quests.Init(Config, DB) end
if Index and Index.Init then Index.Init(Config, DB) end
if Utilities and Utilities.Init then Utilities.Init(Config, DB) end
if Optimization and Optimization.Init then Optimization.Init(Config) end

if UI and UI.Init then
    UI.Init(Config, DB, Modules)
end

print("[GENESIS] ALL MODULES LOADED SUCCESSFULLY!")

return Genesis
