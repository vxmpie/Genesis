local HttpService = game:GetService("HttpService")

local SETTINGS_FOLDER = "Genesis"
local SETTINGS_FILE = SETTINGS_FOLDER .. "/settings.json"

local Config = {}

Config.State = {
    IsActive = true,
    AntiStuck = true,
    AntiStuckSeconds = 15,
    
    AutoBid = false,
    MinimumBid = 1000,
    MaximumBid = 1000000,
    BidDelay = 0.1,
    AutoXRay = false,
    AutoCalculator = false,
    AutoKickNPC = false,
    FastPickup = true,
    AlwaysGrabMutated = true,
    AutoEnterAuctions = false,
    
    AutoWash = false,
    WashRarities = {
        Common = true,
        Uncommon = true,
        Rare = true,
        Epic = true,
        Legendary = true,
        Mythic = true,
        Exotic = true,
        Secret = true,
    },
    
    AutoRepair = false,
    AutoWrench = false,
    AutoGrade = false,
    GradeMinRarity = "Rare",
    AutoLocksmith = false,
    AutoOpenSafes = false,
    
    AutoStock = false,
    StockPricePercent = 150,
    AutoSell = false,
    SellUpToRarity = {
        Junk = true,
        Common = true,
        Uncommon = true,
        Rare = false,
        Epic = false,
    },
    
    AutoMuseum = false,
    AutoQuests = false,
    AutoCollections = false,
    AutoDailyReward = false,
    AutoLostFound = false,
    
    AutoBuyDrinks = false,
    AutoUseDrinks = false,
    AutoBuyPowers = false,
    AutoBuyUpgrades = false,
    
    WalkSpeedEnabled = false,
    WalkSpeedValue = 16,
    JumpPowerEnabled = false,
    JumpPowerValue = 50,
    Noclip = false,
    InfiniteJump = false,
}

function Config.EnsureFolder()
    pcall(function()
        if not isfolder(SETTINGS_FOLDER) then
            makefolder(SETTINGS_FOLDER)
        end
    end)
end

function Config.Save()
    pcall(function()
        Config.EnsureFolder()
        local data = HttpService:JSONEncode(Config.State)
        writefile(SETTINGS_FILE, data)
    end)
end

function Config.Load()
    local ok, data = pcall(function()
        return readfile(SETTINGS_FILE)
    end)
    if ok and data then
        local success, decoded = pcall(function()
            return HttpService:JSONDecode(data)
        end)
        if success and decoded and type(decoded) == "table" then
            for k, v in pairs(decoded) do
                if type(v) == "table" and Config.State[k] and type(Config.State[k]) == "table" then
                    for subK, subV in pairs(v) do
                        Config.State[k][subK] = subV
                    end
                else
                    Config.State[k] = v
                end
            end
        end
    end
end

return Config
