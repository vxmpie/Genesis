local UI = {}
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

local function loadObsidianLib()
    local localPath = "Roblox/libraries/obsidian.lua"
    if isfile and isfile(localPath) then
        local fn = loadstring(readfile(localPath))
        if fn then return fn() end
    end
    local remoteUrl = "https://raw.githubusercontent.com/vxmpie/Genesis/main/Roblox/libraries/obsidian.lua"
    local success, code = pcall(function()
        return game:HttpGet(remoteUrl)
    end)
    if success and code and #code > 0 then
        local fn = loadstring(code)
        if fn then return fn() end
    end
    local fallbackUrl = "https://raw.githubusercontent.com/vxmpie/Genesis/main/Roblox/lib/obsidian.lua"
    local s2, code2 = pcall(function()
        return game:HttpGet(fallbackUrl)
    end)
    if s2 and code2 and #code2 > 0 then
        local fn2 = loadstring(code2)
        if fn2 then return fn2() end
    end
    return nil
end

function UI.Init(Config, DB, Modules)
    print("[GENESIS] Initializing Obsidian UI Library...")
    local Obsidian = loadObsidianLib()
    if not Obsidian then
        warn("[GENESIS] Failed to load Obsidian UI Library!")
        return
    end

    local Window = Obsidian:CreateWindow({
        Title = "[+] GENESIS",
        SubTitle = "Storage Hunters",
        TabWidth = 160
    })

    print("[GENESIS] Obsidian Window Created Successfully!")
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "GENESIS HUB",
            Text = "Storage Hunters UI Loaded! Press LeftControl to toggle.",
            Duration = 5
        })
    end)

    local Tabs = {
        Info = Window:AddTab("Info", "[i]"),
        Farming = Window:AddTab("Farming", "[*]"),
        Management = Window:AddTab("Management", "[$]"),
        Utilities = Window:AddTab("Utilities", "[#]"),
        Setting = Window:AddTab("Setting", "[%]")
    }

    local infoLeft = Tabs.Info:AddLeftGroupbox("Account Details")
    infoLeft:AddLabel("Player: " .. LocalPlayer.Name)
    infoLeft:AddLabel("User ID: " .. tostring(LocalPlayer.UserId))

    local infoRight = Tabs.Info:AddRightGroupbox("Game Session")
    infoRight:AddLabel("Place ID: " .. tostring(game.PlaceId))
    infoRight:AddLabel("Job ID: " .. string.sub(game.JobId, 1, 10) .. "...")

    local farmGeneral = Tabs.Farming:AddLeftGroupbox("General Automation")
    farmGeneral:AddToggle("StopAllAutomation", {
        Text = "Stop All Automation",
        Default = Config.Get("StopAllAutomation", false),
        Callback = function(val)
            Config.Set("StopAllAutomation", val)
            Config.Save()
            print("[GENESIS] StopAllAutomation set to:", val)
        end
    })
    farmGeneral:AddToggle("AutoPlay", {
        Text = "Auto Play (Start Screen)",
        Default = Config.Get("AutoPlay", true),
        Callback = function(val)
            Config.Set("AutoPlay", val)
            Config.Save()
            print("[GENESIS] AutoPlay set to:", val)
        end
    })
    farmGeneral:AddToggle("AutoClaimPlot", {
        Text = "Auto Claim Available Plot",
        Default = Config.Get("AutoClaimPlot", true),
        Callback = function(val)
            Config.Set("AutoClaimPlot", val)
            Config.Save()
            print("[GENESIS] AutoClaimPlot set to:", val)
        end
    })

    local farmAuction = Tabs.Farming:AddLeftGroupbox("Auctions & Bidding")
    farmAuction:AddToggle("AutoStartAuction", {
        Text = "Auto Start Auction",
        Default = Config.Get("AutoStartAuction", false),
        Callback = function(val)
            Config.Set("AutoStartAuction", val)
            Config.Save()
        end
    })
    farmAuction:AddToggle("AutoBid", {
        Text = "Auto Bid",
        Default = Config.Get("AutoBid", false),
        Callback = function(val)
            Config.Set("AutoBid", val)
            Config.Save()
        end
    })
    farmAuction:AddToggle("StopNPCBid", {
        Text = "Stop NPC Bid",
        Default = Config.Get("StopNPCBid", false),
        Callback = function(val)
            Config.Set("StopNPCBid", val)
            Config.Save()
        end
    })
    farmAuction:AddToggle("AutoXRay", {
        Text = "Auto X-Ray",
        Default = Config.Get("AutoXRay", false),
        Callback = function(val)
            Config.Set("AutoXRay", val)
            Config.Save()
        end
    })
    farmAuction:AddToggle("AutoCalculator", {
        Text = "Auto Calculator",
        Default = Config.Get("AutoCalculator", false),
        Callback = function(val)
            Config.Set("AutoCalculator", val)
            Config.Save()
        end
    })
    farmAuction:AddToggle("AutoKickTopBidder", {
        Text = "Auto Kick Top Bidder",
        Default = Config.Get("AutoKickTopBidder", false),
        Callback = function(val)
            Config.Set("AutoKickTopBidder", val)
            Config.Save()
        end
    })

    local farmLoot = Tabs.Farming:AddRightGroupbox("Loot & Safes")
    farmLoot:AddToggle("AutoCollectWorldLoot", {
        Text = "Auto Collect World Loot",
        Default = Config.Get("AutoCollectWorldLoot", false),
        Callback = function(val)
            Config.Set("AutoCollectWorldLoot", val)
            Config.Save()
        end
    })
    farmLoot:AddToggle("InstantCollect", {
        Text = "Instant Collect (No Wind-Up)",
        Default = Config.Get("InstantCollect", true),
        Callback = function(val)
            Config.Set("InstantCollect", val)
            Config.Save()
        end
    })
    farmLoot:AddToggle("AutoClaimAuctionWinnings", {
        Text = "Auto Claim Auction Winnings",
        Default = Config.Get("AutoClaimAuctionWinnings", true),
        Callback = function(val)
            Config.Set("AutoClaimAuctionWinnings", val)
            Config.Save()
        end
    })
    farmLoot:AddToggle("AutoOpenSafes", {
        Text = "Auto Open Safes (Locksmith)",
        Default = Config.Get("AutoOpenSafes", false),
        Callback = function(val)
            Config.Set("AutoOpenSafes", val)
            Config.Save()
        end
    })
    farmLoot:AddToggle("AutoPicklockSafes", {
        Text = "Auto Picklock Safes",
        Default = Config.Get("AutoPicklockSafes", false),
        Callback = function(val)
            Config.Set("AutoPicklockSafes", val)
            Config.Save()
        end
    })

    local farmFishing = Tabs.Farming:AddRightGroupbox("Fishing & Processing")
    farmFishing:AddToggle("AutoFish", {
        Text = "Auto Fish",
        Default = Config.Get("AutoFish", false),
        Callback = function(val)
            Config.Set("AutoFish", val)
            Config.Save()
        end
    })
    farmFishing:AddToggle("SpeedUpFishing", {
        Text = "Speed Up Fishing",
        Default = Config.Get("SpeedUpFishing", false),
        Callback = function(val)
            Config.Set("SpeedUpFishing", val)
            Config.Save()
        end
    })
    farmFishing:AddToggle("AutoWashItems", {
        Text = "Auto Wash Items",
        Default = Config.Get("AutoWashItems", false),
        Callback = function(val)
            Config.Set("AutoWashItems", val)
            Config.Save()
        end
    })
    farmFishing:AddToggle("AutoRepairItems", {
        Text = "Auto Repair Items",
        Default = Config.Get("AutoRepairItems", false),
        Callback = function(val)
            Config.Set("AutoRepairItems", val)
            Config.Save()
        end
    })
    farmFishing:AddToggle("AutoGradeItems", {
        Text = "Auto Grade Items (PSA)",
        Default = Config.Get("AutoGradeItems", false),
        Callback = function(val)
            Config.Set("AutoGradeItems", val)
            Config.Save()
        end
    })

    local shopLeft = Tabs.Management:AddLeftGroupbox("Shop Merchandising")
    shopLeft:AddToggle("AutoSell", {
        Text = "Auto Sell (Quick Sell)",
        Default = Config.Get("AutoSell", false),
        Callback = function(val)
            Config.Set("AutoSell", val)
            Config.Save()
        end
    })
    shopLeft:AddToggle("AutoStockShopShelves", {
        Text = "Auto Stock Shop Shelves",
        Default = Config.Get("AutoStockShopShelves", false),
        Callback = function(val)
            Config.Set("AutoStockShopShelves", val)
            Config.Save()
        end
    })
    shopLeft:AddToggle("AutoAcceptNPCOffers", {
        Text = "Auto Accept NPC Offers",
        Default = Config.Get("AutoAcceptNPCOffers", false),
        Callback = function(val)
            Config.Set("AutoAcceptNPCOffers", val)
            Config.Save()
        end
    })
    shopLeft:AddToggle("AutoExpandShelfSlots", {
        Text = "Auto Expand Shelf Slots",
        Default = Config.Get("AutoExpandShelfSlots", false),
        Callback = function(val)
            Config.Set("AutoExpandShelfSlots", val)
            Config.Save()
        end
    })

    local rewardsRight = Tabs.Management:AddRightGroupbox("Rewards & Quests")
    rewardsRight:AddToggle("AutoClaimDailyReward", {
        Text = "Auto Claim Daily Reward",
        Default = Config.Get("AutoClaimDailyReward", true),
        Callback = function(val)
            Config.Set("AutoClaimDailyReward", val)
            Config.Save()
        end
    })
    rewardsRight:AddToggle("AutoClaimAchievements", {
        Text = "Auto Claim Achievements",
        Default = Config.Get("AutoClaimAchievements", true),
        Callback = function(val)
            Config.Set("AutoClaimAchievements", val)
            Config.Save()
        end
    })
    rewardsRight:AddToggle("AutoClaimMuseumRewards", {
        Text = "Auto Claim Museum Rewards",
        Default = Config.Get("AutoClaimMuseumRewards", true),
        Callback = function(val)
            Config.Set("AutoClaimMuseumRewards", val)
            Config.Save()
        end
    })
    rewardsRight:AddToggle("AutoClaimClubQuests", {
        Text = "Auto Claim Club Quests",
        Default = Config.Get("AutoClaimClubQuests", true),
        Callback = function(val)
            Config.Set("AutoClaimClubQuests", val)
            Config.Save()
        end
    })
    rewardsRight:AddToggle("EnableAutoQuestEngine", {
        Text = "Enable Auto Quest Engine",
        Default = Config.Get("EnableAutoQuestEngine", false),
        Callback = function(val)
            Config.Set("EnableAutoQuestEngine", val)
            Config.Save()
        end
    })
    rewardsRight:AddToggle("AutoInstallReactorParts", {
        Text = "Auto Install Reactor Parts",
        Default = Config.Get("AutoInstallReactorParts", false),
        Callback = function(val)
            Config.Set("AutoInstallReactorParts", val)
            Config.Save()
        end
    })

    local utilLeft = Tabs.Utilities:AddLeftGroupbox("Movement & Optimization")
    utilLeft:AddToggle("WalkSpeedToggle", {
        Text = "WalkSpeed Toggle (100)",
        Default = Config.Get("WalkSpeedToggle", false),
        Callback = function(val)
            Config.Set("WalkSpeedToggle", val)
            Config.Save()
        end
    })
    utilLeft:AddToggle("JumpPowerToggle", {
        Text = "JumpPower Toggle (50)",
        Default = Config.Get("JumpPowerToggle", false),
        Callback = function(val)
            Config.Set("JumpPowerToggle", val)
            Config.Save()
        end
    })
    utilLeft:AddToggle("InfiniteJump", {
        Text = "Infinite Jump",
        Default = Config.Get("InfiniteJump", false),
        Callback = function(val)
            Config.Set("InfiniteJump", val)
            Config.Save()
        end
    })
    utilLeft:AddToggle("Noclip", {
        Text = "Noclip",
        Default = Config.Get("Noclip", false),
        Callback = function(val)
            Config.Set("Noclip", val)
            Config.Save()
        end
    })
    utilLeft:AddToggle("DeleteContainers", {
        Text = "Delete Containers (Lag Reducer)",
        Default = Config.Get("DeleteContainers", false),
        Callback = function(val)
            Config.Set("DeleteContainers", val)
            Config.Save()
        end
    })
    utilLeft:AddToggle("DeleteTrees", {
        Text = "Delete Trees & Foliage",
        Default = Config.Get("DeleteTrees", false),
        Callback = function(val)
            Config.Set("DeleteTrees", val)
            Config.Save()
        end
    })

    local utilRight = Tabs.Utilities:AddRightGroupbox("Teleport Network (23 POIs)")
    utilRight:AddButton({
        Text = "Teleport to Cleaning Shop",
        Callback = function()
            Modules.Utilities.TeleportTo("Item Cleaning Services (Wash)")
        end
    })
    utilRight:AddButton({
        Text = "Teleport to Repair Shop",
        Callback = function()
            Modules.Utilities.TeleportTo("Repair Shop")
        end
    })
    utilRight:AddButton({
        Text = "Teleport to Grading Store",
        Callback = function()
            Modules.Utilities.TeleportTo("Grading Store")
        end
    })
    utilRight:AddButton({
        Text = "Teleport to My Plot / Shop",
        Callback = function()
            Modules.Utilities.TeleportTo("My Plot / Shop")
        end
    })

    local setLeft = Tabs.Setting:AddLeftGroupbox("Menu & Safety")
    setLeft:AddToggle("AntiAFK", {
        Text = "Anti-AFK Guard",
        Default = Config.Get("AntiAFK", true),
        Callback = function(val)
            Config.Set("AntiAFK", val)
            Config.Save()
        end
    })
    setLeft:AddButton({
        Text = "Export Config to Clipboard",
        Callback = function()
            Config.ExportClipboard()
        end
    })
    setLeft:AddButton({
        Text = "Unload Genesis Hub",
        Callback = function()
            Window.ScreenGui:Destroy()
        end
    })
end

return UI
