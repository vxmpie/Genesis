local Loot = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local ItemsDB = nil

Loot.Status = {
    TruckPercent = 0,
    Collected = 0,
    BoxesOpened = 0,
    Unloaded = 0,
    BestLockpick = "Master Lockpick"
}

local function getDraggingFolder()
    local events = ReplicatedStorage:FindFirstChild("Events")
    return events and events:FindFirstChild("Dragging")
end

local function getLocksmithFolder()
    local events = ReplicatedStorage:FindFirstChild("Events")
    return events and events:FindFirstChild("Locksmith")
end

local function getAuctionFolder()
    local events = ReplicatedStorage:FindFirstChild("Events")
    return events and events:FindFirstChild("Auction")
end

function Loot.Init(Config, DB)
    ItemsDB = DB
    task.spawn(function()
        while task.wait(0.2) do
            if not Config.Get("StopAllAutomation", false) then
                if Config.Get("AutoCollectWorldLoot", false) then
                    pcall(function()
                        local char = LocalPlayer.Character
                        local root = char and char:FindFirstChild("HumanoidRootPart")
                        if root then
                            local range = Config.Get("LootRange", 150)
                            local dragging = getDraggingFolder()
                            local pickupEvent = dragging and dragging:FindFirstChild("PickUpItem")

                            for _, item in ipairs(Workspace:GetChildren()) do
                                if item:IsA("Model") and item:FindFirstChild("PrimaryPart") or item:FindFirstChild("Handle") then
                                    local part = item.PrimaryPart or item:FindFirstChild("Handle") or item:FindFirstChildWhichIsA("BasePart")
                                    if part then
                                        local dist = (part.Position - root.Position).Magnitude
                                        if dist <= range then
                                            local itemInfo = ItemsDB and ItemsDB.GetItemByName(item.Name)
                                            local allow = true

                                            if Config.Get("LootMinRarity", "Any") ~= "Any" and itemInfo then
                                                allow = (itemInfo.Rarity == Config.Get("LootMinRarity"))
                                            end

                                            if allow and pickupEvent then
                                                pickupEvent:FireServer(item)
                                                Loot.Status.Collected = Loot.Status.Collected + 1
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end)
                end

                if Config.Get("AutoClaimAuctionWinnings", true) then
                    pcall(function()
                        local auction = getAuctionFolder()
                        local claimEvent = auction and (auction:FindFirstChild("AuctionPickupItem") or auction:FindFirstChild("ClaimWinnings"))
                        if claimEvent then
                            claimEvent:FireServer()
                        end
                    end)
                end

                if Config.Get("AutoOpenSafes", false) or Config.Get("AutoPicklockSafes", false) then
                    pcall(function()
                        local lockFolder = getLocksmithFolder()
                        if lockFolder then
                            local openSafe = lockFolder:FindFirstChild("StartLockpick") or lockFolder:FindFirstChild("OpenSafe")
                            local claimSafe = lockFolder:FindFirstChild("ClaimItem")
                            if claimSafe then
                                for slot = 1, 5 do
                                    claimSafe:InvokeServer(slot)
                                end
                            end
                            if Config.Get("SpeedUpSafes", false) then
                                local speedup = lockFolder:FindFirstChild("SpeedUpSafe")
                                if speedup then
                                    for slot = 1, 5 do
                                        speedup:InvokeServer(slot)
                                    end
                                end
                            end
                        end
                    end)
                end
            end
        end
    end)
end

return Loot
