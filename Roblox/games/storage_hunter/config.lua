local Config = {}
local HttpService = game:GetService("HttpService")

local SETTINGS_FILE = "Genesis/StorageHunter_Config.json"

local defaultState = {
    StopAllAutomation = false,
    AutoPlay = true,
    AutoClaimPlot = true,

    AuctionAreas = {},
    ContainerOverrides = {},
    AutoStartAuction = false,
    WalkToNearbyAuction = false,
    MaxAuctionWalkDistance = 150,
    AccessoryLoadoutBeforeAuction = "Disabled",
    WaitUntilInventoryBelow = false,
    StartAuctionsBelowPercent = 80,
    DelayAuctionsAfterWin = false,
    DelayAfterWinSeconds = 1,
    IncludeCargoShip = true,
    IncludeAlienInvasion = true,
    PreferBestGarage = true,
    GrabLostAndFoundFirst = true,
    AutoBid = false,
    StopNPCBid = false,
    StopNPCBidMode = "Consistent",
    MinBid = 10000,
    MinBidConfirmed = false,
    MaxBid = 0,
    BidDelay = 0.5,
    LeaveIfBidOverMax = true,
    LeaveIfBidUnderMin = false,
    LeaveIfLotUnderValue = false,
    MinLotValue = 0,
    LeaveDelay = 0,
    UnloadMethod = "Unload when Full",
    UnloadTruckAtPercent = 100,
    EnableThresholdBypass = false,
    BypassItems = {},
    BypassMutations = {},
    BypassCategories = {},
    BypassRarity = {},
    AutoXRay = false,
    AutoCalculator = false,
    AutoKickTopBidder = false,
    AutoBuyPowers = false,
    PowersToBuy = "Calculator",
    BuyPowersBelow = 5,

    AutoCollectWorldLoot = false,
    LootRange = 150,
    LootMinRarity = "Any",
    AlwaysGrabMutatedLoot = true,
    LootOnlyItems = {},
    InstantCollect = true,
    AutoUnloadTruckWhenFull = true,
    AutoClaimAuctionWinnings = true,
    MinWinningsValue = 0,
    WinningsMinRarity = "Any",
    MinWinningsCondition = 0,
    AutoOpenSafes = false,
    SpeedUpSafes = false,
    AutoPicklockSafes = false,
    AutoBuyBestLockpick = false,
    SafesToOpen = {},
    OnlyOpenGradedSafes = false,

    AutoFish = false,
    SpeedUpFishing = false,
    AutoReel = false,
    ReelMethod = "Smart",
    CastPosition = "Randomise",
    AutoEquipRod = true,
    AutoSwapBrokenRod = true,
    PreferredRods = {"Carbon Fishing Rod", "Scrap Fishing Rod", "Fishing Rod"},
    SkipFishingAnimation = true,
    AutoWashRods = true,
    AutoSellBrokenRods = true,
    BrokenRodSellMethod = "Quick Sell",

    AutoGradeItems = false,
    GradeMinValue = 0,
    GradeMinRarity = "Any",
    GradePriority = "Value",
    GradeSkipCategories = {},
    GradeOnlyCategories = {},
    GradeOnlyItems = {},
    AccessoryLoadoutBeforeGrade = "Disabled",
    GradeMaxValue = 0,
    GradeOnlyMutations = {},
    GradeAlwaysGradeLimited = true,
    GradeClaimFinishedEvenIfFull = false,
    AutoRepairItems = false,
    RepairMinValue = 0,
    RepairMinRarity = "Any",
    AutoRepairLowDurability = true,
    AutoWashItems = false,
    WashMinValue = 0,
    WashMinRarity = "Any",
    WashAlwaysIncludeSafes = true,
    WashPrioritizeVaultsAndDrinks = true,
    AutoTimeCapsule = false,
    CapsuleMinValue = 0,
    CapsuleMinRarity = "Mythical",
    CapsuleOnlyMutations = {},
    AutoCollectFinishedProcessing = true,
    AutoAuthenticateAccessories = false,
    AuthSkipEquipped = true,
    AuthSkipFavorited = true,
    AuthOnlyRarities = {},
    AutoSpeedUpSlots = false,
    AutoUnlockSlots = false,

    AutoSell = false,
    SellItemsInTruck = false,
    OnlySellAtGoodRate = false,
    MinSellRatePercent = 0,
    MinSellValue = 0,
    MaxSellValue = 0,
    KeepItemsByValue = "Disabled",
    KeepValueThreshold = 3000,
    OnlySellCategories = {},
    OnlySellRarities = {},
    NeverSellCategories = {"Exclusives", "Trophy", "Safes"},
    NeverSellItems = {"Cow", "Luxury Storage Box"},
    NeverSellMutations = {
        "Silver", "Gold", "Corrupted", "Diamond", "Gem", "Chrome", "Hologram",
        "Black", "Void", "Secret", "Rainbow", "Huge", "Tiny", "Cobwebbed",
        "Antique", "Ancient", "Timeless", "Limited", "Quest", "Showcased",
        "Moonlit", "Wet", "Exclusive", "Fish", "Acid", "Sandy", "Mint",
        "Artifact", "Firefly", "Shocked", "Caustic", "Dune", "Extraterrestrial",
        "Abducted", "Redacted", "Spotless", "Broken", "Trophy", "Probed",
        "Fossil", "Pure", "Dirty", "Perfect"
    },
    NeverSellGrades = {},
    AutoStockShopShelves = false,
    MinStockValue = 0,
    MaxStockValue = 0,
    AutoPlaceMethod = "Place selected",
    FilterMatchMode = "Match any filter",
    StockPriority = "Highest value",
    StockCategories = {},
    StockRarities = {},
    StockMutations = {},
    StockGrades = {},
    StockItems = {},
    NeverStockCategories = {"Drinks", "Safes"},
    NeverStockItems = {"Airforce Dominus"},
    ShelfPricePercent = 150,
    AutoRepriceExistingStock = true,
    ItemsPerRestock = 25,
    KeepCopiesInInventory = 0,
    MaxCopiesPerItem = 0,
    RestockEverySeconds = 1,
    StayOnPlotForStocking = 0,
    HideStockPlacementNotifications = true,
    AutoExpandShelfSlots = false,
    AutoExpandShopFloor = false,
    AutoExpandItemCapacity = false,
    OtherUpgrades = {"Advertising", "PriceTags", "StorageBoxCapacity", "TrophyCapacity", "CelebritySpawns", "SecondFloor", "TipJar"},
    MaxDiamondsPerBuy = 0,
    AutoPickUpGroundItems = false,
    GroundPickUpCategories = {},
    GroundPickUpOnlyItems = {"Luck Drink 1", "Luck Drink 2", "Luck Drink 3"},
    GroundDontPickUpTypes = {"Accessories", "Certificates"},
    GroundMinMatchingItems = 1,
    AutoAcceptNPCOffers = false,
    MinOfferPercentAboveBase = 20,
    MinOfferValue = 0,
    AutoDeclineLowOffers = true,
    IgnoreFavoritedItemsEverywhere = true,
    AutoFavouriteMatchingItems = false,
    ItemsToFavourite = {"Carbon Fishing Rod", "Fishing Rod"},
    MutationsToFavourite = {"Quest"},
    MutationMatchMode = "Any Selected Mutation",
    AutoFavouriteTrophyRule = true,
    TrophyRuleItems = {"Gavel Trophy"},
    TrophyRuleMutations = {"Hologram", "Black", "Void"},
    AutoPlaceOnPlot = false,
    GroundPlaceTypes = {},
    GroundPlaceRarities = {},
    GroundPlaceSpecificItems = {"Luck Drink 1", "Luck Drink 2", "Luck Drink 3"},
    GroundDontPlaceItems = {},
    GroundPlaceMinValue = 0,
    GroundPlaceMaxValue = 0,
    GroundPlaceStartFullness = 0,
    ItemsPerPlacementPass = 25,
    GroundPlacementSpacing = 5,
    PlacementPointX = -47,
    PlacementPointZ = 23,
    AutoStoreSelectedItems = false,
    ItemsToStore = {"Certificate Of Alien"},

    AutoClaimDailyReward = true,
    AutoCollectLostAndFound = true,
    MinLostAndFoundValue = 0,
    LostAndFoundMinRarity = "Any",
    AutoClaimAchievements = true,
    AutoClaimCollections = true,
    AutoClaimMuseumRewards = true,
    AutoClaimMeteorDrops = true,
    AutoClaimClubQuests = true,
    AutoSubmitCows = false,
    AutoRollAlienMarket = false,
    AutoBuyLuckEnergyDrinks = false,
    DrinksToBuy = {"Luck Drink 1", "Luck Drink 2", "Luck Drink 3"},
    KeepExactDrinkStock = true,
    LuckDrink1Target = 5,
    LuckDrink2Target = 5,
    LuckDrink3Target = 5,
    AutoUseLuckEnergyDrinks = false,
    AutoUnfavoriteLuckDrinks = true,
    DrinksToUse = {"Luck Drink 1", "Luck Drink 2", "Luck Drink 3"},
    DrinkUseMethod = "Use when active runs out",
    AccessoryLoadoutBeforeDrink = "Disabled",
    AutoBuyShopUpgrades = false,
    AutoHireStaff = false,
    MinDiamondsToKeep = 100,

    QuestNPCs = {},
    QuestTaskTypes = {},
    EnableAutoQuestEngine = false,
    AutoGetQuests = false,
    AutoClaimQuestRewards = true,
    QuestDebugLogging = false,
    AutoInstallReactorParts = false,
    BidOnlyForNeededReactorParts = false,
    ReactorMutationRule = "Skip selected",
    ReactorPartMutations = {},
    AutoFeedUranium = false,

    IndexToComplete = {"Back Alley", "Shipyard", "Cargo Ship", "Farmyard", "Lucky Beach", "Power Plant", "Fish", "Lost", "Exclusive", "Junk Yard"},
    SkipItemsOverOneInX = 0,
    EnableAutoIndexCompletion = false,
    LiveIndexStatusUpdates = true,

    WalkSpeedToggle = false,
    WalkSpeedValue = 100,
    JumpPowerToggle = false,
    JumpPowerValue = 50,
    InfiniteJump = false,
    Noclip = false,
    AntiGameplayPause = true,
    RareFindNotifier = false,
    RareFindNotifyValue = 50000,
    DiscordWebhookURL = "",
    SendWebhookAlerts = false,
    WebhookMinItemValue = 0,
    WebhookItemsToSend = {},
    WebhookSendGrading = true,
    WebhookSendWinnings = true,
    LostItemESP = false,
    CarryableESP = false,
    SafeESP = false,
    AuctionGarageESP = false,
    ShopNPCESP = false,
    ESPMaxDistance = 1500,
    ESPMinValue = 0,
    DeleteContainers = false,
    DeleteTrees = false,
    DeleteNPCs = false,
    EnableFPSCap = false,
    FPSCapValue = 360,
    SelectedWaypoint = "Shop: Cleaning Shop",
    SelectedVehicle = "Flying UFO",
    HideCarNoclip = false,

    UIKeybind = "LeftControl",
    AntiAFK = true,
    AntiRejoin = false,
    CurrentTheme = "Monochrome"
}

local state = {}
for k, v in pairs(defaultState) do
    state[k] = v
end

function Config.Get(key, default)
    if state[key] ~= nil then
        return state[key]
    end
    return default
end

function Config.Set(key, value)
    state[key] = value
end

function Config.GetAll()
    return state
end

function Config.Reset()
    for k, v in pairs(defaultState) do
        state[k] = v
    end
end

function Config.Save(customPath)
    local targetPath = customPath or SETTINGS_FILE
    pcall(function()
        if makefolder then
            makefolder("Genesis")
        end
        if writefile then
            writefile(targetPath, HttpService:JSONEncode(state))
        end
    end)
end

function Config.Load(customPath)
    local targetPath = customPath or SETTINGS_FILE
    pcall(function()
        if isfile and readfile and isfile(targetPath) then
            local data = HttpService:JSONDecode(readfile(targetPath))
            if typeof(data) == "table" then
                for k, v in pairs(data) do
                    state[k] = v
                end
            end
        end
    end)
end

function Config.ExportClipboard()
    local encoded = HttpService:JSONEncode(state)
    if setclipboard then
        setclipboard(encoded)
    end
    return encoded
end

function Config.ImportClipboard(text)
    local success, result = pcall(function()
        return HttpService:JSONDecode(text)
    end)
    if success and typeof(result) == "table" then
        for k, v in pairs(result) do
            state[k] = v
        end
        return true
    end
    return false
end

Config.Load()

return Config
