local BASE = "https://raw.githubusercontent.com/vxmpie/Genesis/main/Roblox/games/storage_hunter/"

local function loadModule(path)
    return loadstring(game:HttpGet(BASE .. path))()
end

local Config = loadModule("config.lua")
Config.Load()

local ResetModule = loadModule("functions/reset.lua")
local WashModule = loadModule("functions/wash.lua")
local AuctionModule = loadModule("functions/auction.lua")
local TeleportModule = loadModule("functions/teleport.lua")
local UI = loadModule("ui.lua")

UI.Create(Config, ResetModule, WashModule, AuctionModule, TeleportModule)

warn("[GENESIS] Storage Hunter Hub loaded successfully!")
