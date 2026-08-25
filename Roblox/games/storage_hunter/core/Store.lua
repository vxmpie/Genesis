local HttpService = game:GetService("HttpService")

local SETTINGS_FOLDER = "Genesis"
local SETTINGS_FILE = SETTINGS_FOLDER .. "/settings.json"

local Store = {}
Store._state = {
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
    AuctionArea = "Shipyard",
    
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
    AutoAuthenticate = false,
    
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

Store._listeners = {}
Store._saveThread = nil

function Store.EnsureFolder()
    pcall(function()
        if not isfolder(SETTINGS_FOLDER) then
            makefolder(SETTINGS_FOLDER)
        end
    end)
end

function Store.Get(key)
    return Store._state[key]
end

function Store.Set(key, value, silent)
    Store._state[key] = value
    if not silent and Store._listeners[key] then
        for _, cb in ipairs(Store._listeners[key]) do
            task.spawn(cb, value)
        end
    end
    Store.DebouncedSave()
end

function Store.Subscribe(key, callback)
    Store._listeners[key] = Store._listeners[key] or {}
    table.insert(Store._listeners[key], callback)
    return function()
        local list = Store._listeners[key]
        if list then
            for i, cb in ipairs(list) do
                if cb == callback then
                    table.remove(list, i)
                    break
                end
            end
        end
    end
end

function Store.DebouncedSave()
    if Store._saveThread then
        task.cancel(Store._saveThread)
    end
    Store._saveThread = task.delay(0.5, function()
        pcall(function()
            Store.EnsureFolder()
            local json = HttpService:JSONEncode(Store._state)
            writefile(SETTINGS_FILE, json)
        end)
        Store._saveThread = nil
    end)
end

function Store.Load()
    local ok, data = pcall(function()
        return readfile(SETTINGS_FILE)
    end)
    if ok and data then
        local success, decoded = pcall(function()
            return HttpService:JSONDecode(data)
        end)
        if success and decoded and type(decoded) == "table" then
            for k, v in pairs(decoded) do
                if type(v) == "table" and Store._state[k] and type(Store._state[k]) == "table" then
                    for subK, subV in pairs(v) do
                        Store._state[k][subK] = subV
                    end
                else
                    Store._state[k] = v
                end
            end
        end
    end
end

return Store
