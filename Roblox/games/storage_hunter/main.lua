local BASE = "https://raw.githubusercontent.com/vxmpie/Genesis/main/Roblox/games/storage_hunter/"

local function loadModule(path)
    return loadstring(game:HttpGet(BASE .. path))()
end

local Config = loadModule("config.lua")
Config.Load()

local ResetModule = loadModule("functions/reset.lua")
local AuctionModule = loadModule("functions/auction.lua")
local WashModule = loadModule("functions/wash.lua")
local RepairModule = loadModule("functions/repair.lua")
local GradingModule = loadModule("functions/grading.lua")
local LocksmithModule = loadModule("functions/locksmith.lua")
local StockModule = loadModule("functions/stock.lua")
local RewardsModule = loadModule("functions/rewards.lua")
local UtilsModule = loadModule("functions/utils.lua")
local UI = loadModule("ui.lua")

UI.Create(Config, ResetModule, AuctionModule, WashModule, RepairModule, GradingModule, LocksmithModule, StockModule, RewardsModule, UtilsModule)

warn("[GENESIS] Storage Hunter Hub loaded successfully!")
