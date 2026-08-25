local Loot = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local function getCharacterPosition()
    if LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp.Position end
    end
    return Vector3.new(0, 0, 0)
end

function Loot.Init(Config, DB)
    local eventsFolder = ReplicatedStorage:WaitForChild("Events")
    local dragEvents = eventsFolder:WaitForChild("Dragging")
    local pickupRemote = dragEvents:WaitForChild("PickUpItem")
    local auctionEvents = eventsFolder:FindFirstChild("Auction")
    local auctionPickup = auctionEvents and auctionEvents:FindFirstChild("AuctionPickupItem")

    local function vacuumItem(item)
        if not item or not item:IsA("Instance") then return end
        pcall(function()
            if auctionPickup then
                auctionPickup:FireServer(item)
            end
            pickupRemote:FireServer(item)
        end)
    end

    task.spawn(function()
        while task.wait(0.1) do
            if Config.Get("AutoCollectWorldLoot", false) and not Config.Get("StopAllAutomation", false) then
                local charPos = getCharacterPosition()
                local maxDist = Config.Get("LootRange", 150)
                local minRarity = Config.Get("LootMinRarity", "Any")
                local alwaysGrabMutated = Config.Get("AlwaysGrabMutatedLoot", true)

                local lootFolders = {
                    Workspace:FindFirstChild("Debris"),
                    Workspace:FindFirstChild("Loot"),
                    Workspace:FindFirstChild("DroppedItems"),
                    Workspace:FindFirstChild("Garages")
                }

                for _, folder in ipairs(lootFolders) do
                    if folder then
                        for _, item in ipairs(folder:GetChildren()) do
                            if item:IsA("Model") or item:IsA("BasePart") then
                                local primaryPart = item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")) or item
                                if primaryPart then
                                    local dist = (primaryPart.Position - charPos).Magnitude
                                    if dist <= maxDist then
                                        local isMutated = item:GetAttribute("Mutation") ~= nil or item:GetAttribute("Variant") ~= nil
                                        local itemData = DB.GetItem(item.Name)
                                        local itemRarity = itemData and itemData.Rarity or "Junk"
                                        
                                        local shouldGrab = false
                                        if alwaysGrabMutated and isMutated then
                                            shouldGrab = true
                                        elseif minRarity == "Any" then
                                            shouldGrab = true
                                        else
                                            local r1 = DB.GetRarityMultiplier(itemRarity)
                                            local r2 = DB.GetRarityMultiplier(minRarity)
                                            if r1 >= r2 then shouldGrab = true end
                                        end

                                        if shouldGrab then
                                            task.spawn(vacuumItem, item)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    task.spawn(function()
        while task.wait(0.5) do
            if Config.Get("AutoOpenSafes", false) and not Config.Get("StopAllAutomation", false) then
                pcall(function()
                    local safesFolder = Workspace:FindFirstChild("Safes") or Workspace
                    for _, safe in ipairs(safesFolder:GetDescendants()) do
                        if safe:IsA("Model") and string.find(string.lower(safe.Name), "safe") then
                            local prompt = safe:FindFirstChildWhichIsA("ProximityPrompt", true)
                            if prompt and fireproximityprompt then
                                fireproximityprompt(prompt)
                            end
                        end
                    end
                end)
            end
        end
    end)
end

return Loot
