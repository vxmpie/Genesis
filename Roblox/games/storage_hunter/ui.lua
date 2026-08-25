local UI = {}
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

local function getObsidian()
    local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
    local libSuccess, Library = pcall(function()
        return loadstring(game:HttpGet(repo .. "Library.lua"))()
    end)
    if not libSuccess or not Library then
        local fallbackUrl = "https://raw.githubusercontent.com/vxmpie/Genesis/main/Roblox/libraries/obsidian.lua"
        local s, lib = pcall(function()
            return loadstring(game:HttpGet(fallbackUrl))()
        end)
        if s and lib then return lib, nil, nil end
        return nil, nil, nil
    end

    local themeSuccess, ThemeManager = pcall(function()
        return loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
    end)
    local saveSuccess, SaveManager = pcall(function()
        return loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
    end)

    return Library, ThemeManager, SaveManager
end

function UI.Init(Config, DB, Modules)
    print("[GENESIS] Loading Official Obsidian UI Library...")
    local Library, ThemeManager, SaveManager = getObsidian()
    if not Library then
        warn("[GENESIS] Failed to load Obsidian UI Library!")
        return
    end

    local Window = Library:CreateWindow({
        Title = "GENESIS",
        SubTitle = "Storage Hunters",
        TabWidth = 160,
        AutoShow = true
    })

    print("[GENESIS] Official Obsidian Window Created!")
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "GENESIS HUB",
            Text = "Obsidian UI Loaded! Press LeftControl to toggle.",
            Duration = 5
        })
    end)

    local Tabs = {
        Info = Window:AddTab("Info"),
        Farming = Window:AddTab("Farming"),
        Management = Window:AddTab("Management"),
        Utilities = Window:AddTab("Utilities"),
        Setting = Window:AddTab("Setting")
    }

    local infoLeft = Tabs.Info:AddLeftGroupbox("Account Details")
    infoLeft:AddLabel("Player: " .. LocalPlayer.Name)
    infoLeft:AddLabel("User ID: " .. tostring(LocalPlayer.UserId))
    infoLeft:AddLabel("Account Age: " .. tostring(LocalPlayer.AccountAge) .. " days")

    local infoRight = Tabs.Info:AddRightGroupbox("Game Session")
    infoRight:AddLabel("Place ID: " .. tostring(game.PlaceId))
    infoRight:AddLabel("Job ID: " .. string.sub(game.JobId, 1, 12) .. "...")
    infoRight:AddLabel("Version: Genesis Hub v1.0")

    local farmGeneral = Tabs.Farming:AddLeftGroupbox("General Automation")
    farmGeneral:AddToggle("StopAllAutomation", {
        Text = "Stop All Automation",
        Default = Config.Get("StopAllAutomation", false),
        Tooltip = "Master emergency kill switch",
        Callback = function(val)
            Config.Set("StopAllAutomation", val)
            Config.Save()
        end
    })
    farmGeneral:AddToggle("AutoPlay", {
        Text = "Auto Play (Start Screen)",
        Default = Config.Get("AutoPlay", true),
        Tooltip = "Automatically clicks Play on startup screen",
        Callback = function(val)
            Config.Set("AutoPlay", val)
            Config.Save()
        end
    })
    farmGeneral:AddToggle("AutoClaimPlot", {
        Text = "Auto Claim Available Plot",
        Default = Config.Get("AutoClaimPlot", true),
        Tooltip = "Automatically claims empty shop plot on join",
        Callback = function(val)
            Config.Set("AutoClaimPlot", val)
            Config.Save()
        end
    })

    local farmAuctions = Tabs.Farming:AddLeftGroupbox("Auctions & Navigation")
    farmAuctions:AddDropdown("AuctionAreas", {
        Values = {"Junk Yard", "Farmyard", "Lucky Beach", "Cargo Ship", "Business Bay", "Back Alley", "Shipyard", "Power Plant", "Jurassic", "Alien Invasion"},
        Default = Config.Get("AuctionAreas", {}),
        Multi = true,
        Text = "Auction Areas"
    })
    farmAuctions:AddDropdown("ContainerOverrides", {
        Values = {
            "Scrap Garage 2 | $0", "Scrap Garage 3 | $0", "Shop Front | $750", "Alien Garage 1 | $2,000",
            "Camo Shop Front | $3,000", "Wooden Cargo Container | $7,000", "Power Plant Tier 1 Garage | $7,500",
            "Stable Garage | $10,000", "Jurassic Stable Garage | $10,000", "Alien Garage 2 | $20,000",
            "Barn Garage | $50,000", "Jurassic Barn Garage | $50,000", "Power Plant Tier 2 Garage | $65,000",
            "Cargo Container | $65,000", "Small Container Garage | $125,000", "Alien Garage 3 | $250,000",
            "Steel Cargo Container | $275,000", "Large Container Garage | $400,000", "Power Plant Tier 3 Garage | $600,000",
            "Warehouse Garage | $1,250,000", "Alien Garage 4 | $2,000,000", "Luxury Cargo Container | $2,000,000",
            "Beach Hut Garage | $2,500,000", "Power Plant Tier 4 Garage | $3,500,000", "Surf Shack Garage | $5,000,000",
            "Boat House Garage | $10,000,000", "High End Apartment | $17,500,000", "Luxury Hotel | $30,000,000", "The Pointer | $50,000,000"
        },
        Default = Config.Get("ContainerOverrides", {}),
        Multi = true,
        Text = "Containers (Overrides Area)"
    })
    farmAuctions:AddToggle("AutoStartAuction", {
        Text = "Auto Start Auction",
        Default = Config.Get("AutoStartAuction", false),
        Callback = function(val) Config.Set("AutoStartAuction", val) end
    })
    farmAuctions:AddToggle("WalkToNearbyAuction", {
        Text = "Walk to Nearby Auction",
        Default = Config.Get("WalkToNearbyAuction", false),
        Callback = function(val) Config.Set("WalkToNearbyAuction", val) end
    })
    farmAuctions:AddSlider("MaxAuctionWalkDistance", {
        Text = "Maximum Walk Distance",
        Default = Config.Get("MaxAuctionWalkDistance", 150),
        Min = 0,
        Max = 500,
        Rounding = 0,
        Suffix = " studs",
        Callback = function(val) Config.Set("MaxAuctionWalkDistance", val) end
    })
    farmAuctions:AddDropdown("AccessoryLoadoutBeforeAuction", {
        Values = {"Disabled", "Loadout 1", "Loadout 2", "Loadout 3"},
        Default = Config.Get("AccessoryLoadoutBeforeAuction", "Disabled"),
        Multi = false,
        Text = "Accessory Loadout Before Auction"
    })
    farmAuctions:AddToggle("WaitUntilInventoryBelow", {
        Text = "Wait Until Inventory Below %",
        Default = Config.Get("WaitUntilInventoryBelow", false),
        Callback = function(val) Config.Set("WaitUntilInventoryBelow", val) end
    })
    farmAuctions:AddSlider("StartAuctionsBelowPercent", {
        Text = "Start Auctions Below %",
        Default = Config.Get("StartAuctionsBelowPercent", 80),
        Min = 1,
        Max = 100,
        Rounding = 0,
        Suffix = "%",
        Callback = function(val) Config.Set("StartAuctionsBelowPercent", val) end
    })
    farmAuctions:AddToggle("DelayAuctionsAfterWin", {
        Text = "Delay Auctions After Winning",
        Default = Config.Get("DelayAuctionsAfterWin", false),
        Callback = function(val) Config.Set("DelayAuctionsAfterWin", val) end
    })
    farmAuctions:AddSlider("DelayAfterWinSeconds", {
        Text = "Delay After Win",
        Default = Config.Get("DelayAfterWinSeconds", 1),
        Min = 1,
        Max = 300,
        Rounding = 0,
        Suffix = "s",
        Callback = function(val) Config.Set("DelayAfterWinSeconds", val) end
    })
    farmAuctions:AddToggle("IncludeCargoShip", {
        Text = "Include Cargo Ship Event",
        Default = Config.Get("IncludeCargoShip", true),
        Callback = function(val) Config.Set("IncludeCargoShip", val) end
    })
    farmAuctions:AddToggle("IncludeAlienInvasion", {
        Text = "Include Alien Invasion Event",
        Default = Config.Get("IncludeAlienInvasion", true),
        Callback = function(val) Config.Set("IncludeAlienInvasion", val) end
    })
    farmAuctions:AddToggle("PreferBestGarage", {
        Text = "Prefer Best Garage",
        Default = Config.Get("PreferBestGarage", true),
        Callback = function(val) Config.Set("PreferBestGarage", val) end
    })
    farmAuctions:AddToggle("GrabLostAndFoundFirst", {
        Text = "Grab Lost & Found First",
        Default = Config.Get("GrabLostAndFoundFirst", true),
        Callback = function(val) Config.Set("GrabLostAndFoundFirst", val) end
    })

    local farmBidding = Tabs.Farming:AddRightGroupbox("Bidding Engine")
    farmBidding:AddToggle("AutoBid", {
        Text = "Auto Bid",
        Default = Config.Get("AutoBid", false),
        Callback = function(val) Config.Set("AutoBid", val) end
    })
    farmBidding:AddToggle("StopNPCBid", {
        Text = "Stop NPC Bid",
        Default = Config.Get("StopNPCBid", false),
        Callback = function(val) Config.Set("StopNPCBid", val) end
    })
    farmBidding:AddDropdown("StopNPCBidMode", {
        Values = {"Consistent (Slightly Slower)", "Potentially Bugged (Faster)"},
        Default = Config.Get("StopNPCBidMode", "Consistent (Slightly Slower)"),
        Multi = false,
        Text = "Stop NPC Bid Mode"
    })
    farmBidding:AddInput("MinBid", {
        Text = "Min Bid ($)",
        Default = tostring(Config.Get("MinBid", 10000)),
        Numeric = true,
        Finished = false,
        Callback = function(val) Config.Set("MinBid", tonumber(val) or 0) end
    })
    farmBidding:AddButton({
        Text = "Confirm Min Bid",
        Func = function()
            Config.Set("MinBidConfirmed", true)
            Library:Notify("Min Bid Confirmed: $" .. tostring(Config.Get("MinBid", 10000)))
        end
    })
    farmBidding:AddInput("MaxBid", {
        Text = "Max Bid ($, 0 = no limit)",
        Default = tostring(Config.Get("MaxBid", 0)),
        Numeric = true,
        Finished = false,
        Callback = function(val) Config.Set("MaxBid", tonumber(val) or 0) end
    })
    farmBidding:AddSlider("BidDelay", {
        Text = "Bid Delay",
        Default = Config.Get("BidDelay", 0.5),
        Min = 0.1,
        Max = 3.0,
        Rounding = 1,
        Suffix = "s",
        Callback = function(val) Config.Set("BidDelay", val) end
    })
    farmBidding:AddToggle("LeaveIfBidOverMax", {
        Text = "Leave If Bid Over Max",
        Default = Config.Get("LeaveIfBidOverMax", true),
        Callback = function(val) Config.Set("LeaveIfBidOverMax", val) end
    })
    farmBidding:AddToggle("LeaveIfBidUnderMin", {
        Text = "Leave If Bid Under Min",
        Default = Config.Get("LeaveIfBidUnderMin", false),
        Callback = function(val) Config.Set("LeaveIfBidUnderMin", val) end
    })
    farmBidding:AddToggle("LeaveIfLotUnderValue", {
        Text = "Leave If Lot Under Value",
        Default = Config.Get("LeaveIfLotUnderValue", false),
        Callback = function(val) Config.Set("LeaveIfLotUnderValue", val) end
    })
    farmBidding:AddInput("MinLotValue", {
        Text = "Min Lot Value ($)",
        Default = tostring(Config.Get("MinLotValue", 0)),
        Numeric = true,
        Finished = false,
        Callback = function(val) Config.Set("MinLotValue", tonumber(val) or 0) end
    })
    farmBidding:AddSlider("LeaveDelay", {
        Text = "Leave Delay",
        Default = Config.Get("LeaveDelay", 0),
        Min = 0,
        Max = 30,
        Rounding = 0,
        Suffix = "s",
        Callback = function(val) Config.Set("LeaveDelay", val) end
    })

    local farmPowers = Tabs.Farming:AddRightGroupbox("Powers & Threshold Bypass")
    farmPowers:AddToggle("AutoXRay", {
        Text = "Auto X-Ray",
        Default = Config.Get("AutoXRay", false),
        Callback = function(val) Config.Set("AutoXRay", val) end
    })
    farmPowers:AddToggle("AutoCalculator", {
        Text = "Auto Calculator",
        Default = Config.Get("AutoCalculator", false),
        Callback = function(val) Config.Set("AutoCalculator", val) end
    })
    farmPowers:AddToggle("AutoKickTopBidder", {
        Text = "Auto Kick Top Bidder",
        Default = Config.Get("AutoKickTopBidder", false),
        Callback = function(val) Config.Set("AutoKickTopBidder", val) end
    })
    farmPowers:AddToggle("AutoBuyPowers", {
        Text = "Auto Buy Powers",
        Default = Config.Get("AutoBuyPowers", false),
        Callback = function(val) Config.Set("AutoBuyPowers", val) end
    })
    farmPowers:AddDropdown("PowersToBuy", {
        Values = {"Calculator", "X-Ray", "Kick NPC"},
        Default = Config.Get("PowersToBuy", "Calculator"),
        Multi = false,
        Text = "Powers To Buy"
    })
    farmPowers:AddSlider("BuyPowersBelow", {
        Text = "Buy When Below",
        Default = Config.Get("BuyPowersBelow", 5),
        Min = 1,
        Max = 25,
        Rounding = 0,
        Callback = function(val) Config.Set("BuyPowersBelow", val) end
    })
    farmPowers:AddToggle("EnableThresholdBypass", {
        Text = "Enable Threshold Bypass",
        Default = Config.Get("EnableThresholdBypass", false),
        Callback = function(val) Config.Set("EnableThresholdBypass", val) end
    })

    local farmLoot = Tabs.Farming:AddLeftGroupbox("Loot & Safes")
    farmLoot:AddToggle("AutoCollectWorldLoot", {
        Text = "Auto Collect World Loot",
        Default = Config.Get("AutoCollectWorldLoot", false),
        Callback = function(val) Config.Set("AutoCollectWorldLoot", val) end
    })
    farmLoot:AddSlider("LootRange", {
        Text = "Loot Range (studs)",
        Default = Config.Get("LootRange", 150),
        Min = 10,
        Max = 500,
        Rounding = 0,
        Suffix = " studs",
        Callback = function(val) Config.Set("LootRange", val) end
    })
    farmLoot:AddDropdown("LootMinRarity", {
        Values = {"Any", "Junk", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Lost"},
        Default = Config.Get("LootMinRarity", "Any"),
        Multi = false,
        Text = "Loot Minimum Rarity"
    })
    farmLoot:AddToggle("AlwaysGrabMutatedLoot", {
        Text = "Always Grab Mutated Loot",
        Default = Config.Get("AlwaysGrabMutatedLoot", true),
        Callback = function(val) Config.Set("AlwaysGrabMutatedLoot", val) end
    })
    farmLoot:AddToggle("InstantCollect", {
        Text = "Instant Collect (No Wind-Up)",
        Default = Config.Get("InstantCollect", true),
        Callback = function(val) Config.Set("InstantCollect", val) end
    })
    farmLoot:AddToggle("AutoUnloadTruckWhenFull", {
        Text = "Auto Unload Truck When Full",
        Default = Config.Get("AutoUnloadTruckWhenFull", true),
        Callback = function(val) Config.Set("AutoUnloadTruckWhenFull", val) end
    })
    farmLoot:AddToggle("AutoClaimAuctionWinnings", {
        Text = "Auto Claim Auction Winnings",
        Default = Config.Get("AutoClaimAuctionWinnings", true),
        Callback = function(val) Config.Set("AutoClaimAuctionWinnings", val) end
    })
    farmLoot:AddToggle("AutoOpenSafes", {
        Text = "Auto Open Safes (Locksmith)",
        Default = Config.Get("AutoOpenSafes", false),
        Callback = function(val) Config.Set("AutoOpenSafes", val) end
    })
    farmLoot:AddToggle("SpeedUpSafes", {
        Text = "Speed Up Safes (Diamonds)",
        Default = Config.Get("SpeedUpSafes", false),
        Callback = function(val) Config.Set("SpeedUpSafes", val) end
    })
    farmLoot:AddToggle("AutoPicklockSafes", {
        Text = "Auto Picklock Safes",
        Default = Config.Get("AutoPicklockSafes", false),
        Callback = function(val) Config.Set("AutoPicklockSafes", val) end
    })
    farmLoot:AddDropdown("SafesToOpen", {
        Values = {"Code Safe", "Diamond Vault", "Metal Safe", "Diamond Safe", "Junk Safe", "Wooden Safe"},
        Default = Config.Get("SafesToOpen", {}),
        Multi = true,
        Text = "Safes / Vaults To Open"
    })

    local farmFish = Tabs.Farming:AddRightGroupbox("Fishing & Processing")
    farmFish:AddToggle("AutoFish", {
        Text = "Auto Fish",
        Default = Config.Get("AutoFish", false),
        Callback = function(val) Config.Set("AutoFish", val) end
    })
    farmFish:AddToggle("SpeedUpFishing", {
        Text = "Speed Up Fishing",
        Default = Config.Get("SpeedUpFishing", false),
        Callback = function(val) Config.Set("SpeedUpFishing", val) end
    })
    farmFish:AddToggle("AutoReel", {
        Text = "Auto Reel",
        Default = Config.Get("AutoReel", false),
        Callback = function(val) Config.Set("AutoReel", val) end
    })
    farmFish:AddDropdown("ReelMethod", {
        Values = {"Smart (track zone)", "Aggressive (edge lock)"},
        Default = Config.Get("ReelMethod", "Smart (track zone)"),
        Multi = false,
        Text = "Reel Method"
    })
    farmFish:AddDropdown("CastPosition", {
        Values = {"Randomise", "Closest", "Lock In First Pos", "Furthest"},
        Default = Config.Get("CastPosition", "Randomise"),
        Multi = false,
        Text = "Cast Position"
    })
    farmFish:AddToggle("AutoWashItems", {
        Text = "Auto Wash Items",
        Default = Config.Get("AutoWashItems", false),
        Callback = function(val) Config.Set("AutoWashItems", val) end
    })
    farmFish:AddToggle("AutoRepairItems", {
        Text = "Auto Repair Items",
        Default = Config.Get("AutoRepairItems", false),
        Callback = function(val) Config.Set("AutoRepairItems", val) end
    })
    farmFish:AddToggle("AutoGradeItems", {
        Text = "Auto Grade Items (PSA)",
        Default = Config.Get("AutoGradeItems", false),
        Callback = function(val) Config.Set("AutoGradeItems", val) end
    })
    farmFish:AddToggle("AutoCollectFinishedProcessing", {
        Text = "Auto Collect Finished Items",
        Default = Config.Get("AutoCollectFinishedProcessing", true),
        Callback = function(val) Config.Set("AutoCollectFinishedProcessing", val) end
    })

    local shopLeft = Tabs.Management:AddLeftGroupbox("Shop Merchandising")
    shopLeft:AddToggle("AutoSell", {
        Text = "Auto Sell (Quick Sell)",
        Default = Config.Get("AutoSell", false),
        Callback = function(val) Config.Set("AutoSell", val) end
    })
    shopLeft:AddToggle("SellItemsInTruck", {
        Text = "Also Sell Items In Truck",
        Default = Config.Get("SellItemsInTruck", false),
        Callback = function(val) Config.Set("SellItemsInTruck", val) end
    })
    shopLeft:AddToggle("AutoStockShopShelves", {
        Text = "Auto Stock Shop Shelves",
        Default = Config.Get("AutoStockShopShelves", false),
        Callback = function(val) Config.Set("AutoStockShopShelves", val) end
    })
    shopLeft:AddSlider("ShelfPricePercent", {
        Text = "Shelf Price (% of Value)",
        Default = Config.Get("ShelfPricePercent", 150),
        Min = 100,
        Max = 150,
        Rounding = 0,
        Suffix = "%",
        Callback = function(val) Config.Set("ShelfPricePercent", val) end
    })
    shopLeft:AddToggle("AutoRepriceExistingStock", {
        Text = "Auto Reprice Existing Stock",
        Default = Config.Get("AutoRepriceExistingStock", true),
        Callback = function(val) Config.Set("AutoRepriceExistingStock", val) end
    })
    shopLeft:AddToggle("AutoAcceptNPCOffers", {
        Text = "Auto Accept NPC Offers",
        Default = Config.Get("AutoAcceptNPCOffers", false),
        Callback = function(val) Config.Set("AutoAcceptNPCOffers", val) end
    })
    shopLeft:AddSlider("MinOfferPercentAboveBase", {
        Text = "Minimum Offer % Above Base",
        Default = Config.Get("MinOfferPercentAboveBase", 20),
        Min = 0,
        Max = 100,
        Rounding = 0,
        Suffix = "%",
        Callback = function(val) Config.Set("MinOfferPercentAboveBase", val) end
    })
    shopLeft:AddToggle("AutoDeclineLowOffers", {
        Text = "Auto Decline Low Offers",
        Default = Config.Get("AutoDeclineLowOffers", true),
        Callback = function(val) Config.Set("AutoDeclineLowOffers", val) end
    })
    shopLeft:AddToggle("AutoExpandShelfSlots", {
        Text = "Auto Expand Shelf Slots",
        Default = Config.Get("AutoExpandShelfSlots", false),
        Callback = function(val) Config.Set("AutoExpandShelfSlots", val) end
    })
    shopLeft:AddToggle("AutoExpandShopFloor", {
        Text = "Auto Expand Shop Floor",
        Default = Config.Get("AutoExpandShopFloor", false),
        Callback = function(val) Config.Set("AutoExpandShopFloor", val) end
    })

    local rewardRight = Tabs.Management:AddRightGroupbox("Rewards & Quests")
    rewardRight:AddToggle("AutoClaimDailyReward", {
        Text = "Auto Claim Daily Reward",
        Default = Config.Get("AutoClaimDailyReward", true),
        Callback = function(val) Config.Set("AutoClaimDailyReward", val) end
    })
    rewardRight:AddToggle("AutoClaimAchievements", {
        Text = "Auto Claim Achievements",
        Default = Config.Get("AutoClaimAchievements", true),
        Callback = function(val) Config.Set("AutoClaimAchievements", val) end
    })
    rewardRight:AddToggle("AutoClaimMuseumRewards", {
        Text = "Auto Claim Museum Rewards",
        Default = Config.Get("AutoClaimMuseumRewards", true),
        Callback = function(val) Config.Set("AutoClaimMuseumRewards", val) end
    })
    rewardRight:AddToggle("AutoClaimClubQuests", {
        Text = "Auto Claim Club Quests",
        Default = Config.Get("AutoClaimClubQuests", true),
        Callback = function(val) Config.Set("AutoClaimClubQuests", val) end
    })
    rewardRight:AddToggle("AutoBuyLuckEnergyDrinks", {
        Text = "Auto Buy Luck Energy Drinks",
        Default = Config.Get("AutoBuyLuckEnergyDrinks", false),
        Callback = function(val) Config.Set("AutoBuyLuckEnergyDrinks", val) end
    })
    rewardRight:AddToggle("AutoUseLuckEnergyDrinks", {
        Text = "Auto Use Luck Energy Drinks",
        Default = Config.Get("AutoUseLuckEnergyDrinks", false),
        Callback = function(val) Config.Set("AutoUseLuckEnergyDrinks", val) end
    })
    rewardRight:AddToggle("EnableAutoQuestEngine", {
        Text = "Enable Auto Quest Engine",
        Default = Config.Get("EnableAutoQuestEngine", false),
        Callback = function(val) Config.Set("EnableAutoQuestEngine", val) end
    })
    rewardRight:AddToggle("AutoGetQuests", {
        Text = "Auto Get Quests",
        Default = Config.Get("AutoGetQuests", false),
        Callback = function(val) Config.Set("AutoGetQuests", val) end
    })
    rewardRight:AddToggle("AutoClaimQuestRewards", {
        Text = "Auto Claim Quest Rewards",
        Default = Config.Get("AutoClaimQuestRewards", true),
        Callback = function(val) Config.Set("AutoClaimQuestRewards", val) end
    })
    rewardRight:AddToggle("AutoInstallReactorParts", {
        Text = "Auto Install Reactor Parts",
        Default = Config.Get("AutoInstallReactorParts", false),
        Callback = function(val) Config.Set("AutoInstallReactorParts", val) end
    })
    rewardRight:AddToggle("EnableAutoIndexCompletion", {
        Text = "Enable Auto Index Completion",
        Default = Config.Get("EnableAutoIndexCompletion", false),
        Callback = function(val) Config.Set("EnableAutoIndexCompletion", val) end
    })

    local moveLeft = Tabs.Utilities:AddLeftGroupbox("Player & Movement")
    moveLeft:AddToggle("WalkSpeedToggle", {
        Text = "WalkSpeed Toggle",
        Default = Config.Get("WalkSpeedToggle", false),
        Callback = function(val) Config.Set("WalkSpeedToggle", val) end
    })
    moveLeft:AddSlider("WalkSpeedValue", {
        Text = "Walk Speed Value",
        Default = Config.Get("WalkSpeedValue", 100),
        Min = 16,
        Max = 300,
        Rounding = 0,
        Callback = function(val) Config.Set("WalkSpeedValue", val) end
    })
    moveLeft:AddToggle("JumpPowerToggle", {
        Text = "JumpPower Toggle",
        Default = Config.Get("JumpPowerToggle", false),
        Callback = function(val) Config.Set("JumpPowerToggle", val) end
    })
    moveLeft:AddSlider("JumpPowerValue", {
        Text = "Jump Power Value",
        Default = Config.Get("JumpPowerValue", 50),
        Min = 50,
        Max = 500,
        Rounding = 0,
        Callback = function(val) Config.Set("JumpPowerValue", val) end
    })
    moveLeft:AddToggle("InfiniteJump", {
        Text = "Infinite Jump",
        Default = Config.Get("InfiniteJump", false),
        Callback = function(val) Config.Set("InfiniteJump", val) end
    })
    moveLeft:AddToggle("Noclip", {
        Text = "Noclip",
        Default = Config.Get("Noclip", false),
        Callback = function(val) Config.Set("Noclip", val) end
    })
    moveLeft:AddToggle("DeleteContainers", {
        Text = "Delete Containers (Lag Reducer)",
        Default = Config.Get("DeleteContainers", false),
        Callback = function(val) Config.Set("DeleteContainers", val) end
    })
    moveLeft:AddToggle("DeleteTrees", {
        Text = "Delete Trees & Foliage",
        Default = Config.Get("DeleteTrees", false),
        Callback = function(val) Config.Set("DeleteTrees", val) end
    })

    local tpRight = Tabs.Utilities:AddRightGroupbox("Teleport & Waypoints")
    tpRight:AddDropdown("SelectedWaypoint", {
        Values = Modules.Utilities.GetWaypointsList(),
        Default = Config.Get("SelectedWaypoint", "Item Cleaning Services (Wash)"),
        Multi = false,
        Text = "Waypoint"
    })
    tpRight:AddButton({
        Text = "Teleport To Waypoint",
        Func = function()
            local wp = Config.Get("SelectedWaypoint", "Item Cleaning Services (Wash)")
            Modules.Utilities.TeleportTo(wp)
        end
    })
    tpRight:AddDropdown("SelectedVehicle", {
        Values = {"Flying UFO", "Kei Truck", "STARTER-DUSTER"},
        Default = Config.Get("SelectedVehicle", "Flying UFO"),
        Multi = false,
        Text = "Vehicle"
    })
    tpRight:AddButton({
        Text = "Spawn Vehicle",
        Func = function()
            local veh = Config.Get("SelectedVehicle", "Flying UFO")
            Modules.Utilities.SpawnVehicle(veh)
        end
    })

    local setLeft = Tabs.Setting:AddLeftGroupbox("Menu & Safety")
    setLeft:AddToggle("AntiAFK", {
        Text = "Anti-AFK Guard",
        Default = Config.Get("AntiAFK", true),
        Callback = function(val) Config.Set("AntiAFK", val) end
    })
    setLeft:AddButton({
        Text = "Export Config to Clipboard",
        Func = function()
            Config.ExportClipboard()
            Library:Notify("Config exported to clipboard!")
        end
    })
    setLeft:AddButton({
        Text = "Unload Genesis Hub",
        Func = function()
            Library:Unload()
        end
    })

    if ThemeManager then
        ThemeManager:SetLibrary(Library)
        ThemeManager:SetFolder("Genesis")
        ThemeManager:ApplyToTab(Tabs.Setting)
    end

    if SaveManager then
        SaveManager:SetLibrary(Library)
        SaveManager:IgnoreThemeSettings()
        SaveManager:SetIgnoreIndexes({"MenuKeybind"})
        SaveManager:SetFolder("Genesis/StorageHunters")
        SaveManager:BuildConfigSection(Tabs.Setting)
    end
end

return UI
