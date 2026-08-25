local BASE = "https://raw.githubusercontent.com/vxmpie/Genesis/main/Roblox/games/storage_hunter/"

local function loadModule(path)
    return loadstring(game:HttpGet(BASE .. path))()
end

local Store = loadModule("core/Store.lua")
Store.Load()

local EventBus = loadModule("core/EventBus.lua")

local Components = {
    Card = loadModule("components/Card.lua"),
    Toggle = loadModule("components/Toggle.lua"),
    Slider = loadModule("components/Slider.lua"),
    Dropdown = loadModule("components/Dropdown.lua"),
    Input = loadModule("components/Input.lua"),
}

local Modules = {
    ResetModule = loadModule("functions/reset.lua"),
    AuctionModule = loadModule("functions/auction.lua"),
    WashModule = loadModule("functions/wash.lua"),
    RepairModule = loadModule("functions/repair.lua"),
    GradingModule = loadModule("functions/grading.lua"),
    LocksmithModule = loadModule("functions/locksmith.lua"),
    StockModule = loadModule("functions/stock.lua"),
    RewardsModule = loadModule("functions/rewards.lua"),
    TeleportModule = loadModule("functions/teleport.lua"),
    UtilsModule = loadModule("functions/utils.lua"),
}

local UI = loadModule("ui.lua")
UI.Create(Store, EventBus, Components, Modules)

warn("[GENESIS] Storage Hunter Hub loaded successfully!")
