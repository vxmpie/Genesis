local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local AuctionModule = {}
local pickupThread = nil
local smartWarpThread = nil
local cacheThread = nil
local boundWashModule = nil

local lastWonTime = 0
local cachedAuctionItems = {}

local AUCTION_AREAS = {
    Vector3.new(-820, 18, -1200),
    Vector3.new(1250, 18, 850),
    Vector3.new(-450, 18, 600),
    Vector3.new(780, 18, -950),
    Vector3.new(210, 18, -340),
    Vector3.new(-1100, 18, 300),
    Vector3.new(1500, 22, -1400),
    Vector3.new(920, 18, 1400),
    Vector3.new(-1400, 28, -500),
    Vector3.new(-320, 18, -780),
}

local currentAreaIdx = 1

function AuctionModule.SetWashModule(washMod)
    boundWashModule = washMod
end

function AuctionModule.GetPlayerVehicle()
    local vehiclesFolder = workspace:FindFirstChild("Vehicles")
    if vehiclesFolder then
        local myVeh = vehiclesFolder:FindFirstChild(LocalPlayer.Name) or vehiclesFolder:FindFirstChild(LocalPlayer.Name .. "'s Vehicle")
        if myVeh then return myVeh end
        for _, veh in ipairs(vehiclesFolder:GetChildren()) do
            if veh:GetAttribute("Owner") == LocalPlayer.Name or veh:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
                return veh
            end
        end
    end
    return nil
end

function AuctionModule.EnsureInVehicle()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end

    if humanoid.Sit and humanoid.SeatPart then
        return true
    end

    local myVeh = AuctionModule.GetPlayerVehicle()
    if myVeh then
        local seat = myVeh:FindFirstChildOfClass("VehicleSeat") or myVeh:FindFirstChildWhichIsA("Seat", true)
        if seat then
            seat:Sit(humanoid)
            return true
        end
    end

    local events = ReplicatedStorage:FindFirstChild("Events")
    local vehEvents = events and events:FindFirstChild("Vehicles")
    if vehEvents and vehEvents:FindFirstChild("RequestSpawn") then
        pcall(function() vehEvents.RequestSpawn:InvokeServer() end)
        task.wait(0.15)
        myVeh = AuctionModule.GetPlayerVehicle()
        if myVeh then
            local seat = myVeh:FindFirstChildOfClass("VehicleSeat") or myVeh:FindFirstChildWhichIsA("Seat", true)
            if seat then
                seat:Sit(humanoid)
                return true
            end
        end
    end

    return false
end

function AuctionModule.LootTarget(target)
    if not target or not target.Parent then return end

    local events = ReplicatedStorage:FindFirstChild("Events")
    local auctionEvents = events and events:FindFirstChild("Auction")
    local draggingEvents = events and events:FindFirstChild("Dragging")

    local pickupItem = auctionEvents and auctionEvents:FindFirstChild("AuctionPickupItem")
    local pickUpDrag = draggingEvents and draggingEvents:FindFirstChild("PickUpItem")

    if fireproximityprompt then
        local prompt = target:FindFirstChildOfClass("ProximityPrompt") or (target:IsA("BasePart") and target:FindFirstChildOfClass("ProximityPrompt"))
        if prompt then
            pcall(function() fireproximityprompt(prompt, 0) end)
        end
    end

    if pickupItem then
        pcall(function() pickupItem:FireServer(target) end)
    end
    if pickUpDrag then
        pcall(function() pickUpDrag:FireServer(target) end)
    end
end

function AuctionModule.VacuumLootAll(items, State)
    if not items or #items == 0 then return end

    lastWonTime = os.time()
    AuctionModule.EnsureInVehicle()

    local events = ReplicatedStorage:FindFirstChild("Events")
    local auctionEvents = events and events:FindFirstChild("Auction")
    local pickupStart = auctionEvents and auctionEvents:FindFirstChild("AuctionPickupStart")
    local pickupEnd = auctionEvents and auctionEvents:FindFirstChild("AuctionPickupEnd")

    if pickupStart then
        pcall(function() pickupStart:FireServer() end)
    end

    for _, obj in ipairs(items) do
        task.spawn(function()
            AuctionModule.LootTarget(obj)
        end)
    end

    if pickupEnd then
        task.defer(function()
            pcall(function() pickupEnd:FireServer() end)
        end)
    end

    if boundWashModule and State and State.AutoWash then
        task.spawn(function()
            task.wait(0.2)
            boundWashModule.QuickWash(State)
        end)
    end
end

function AuctionModule.UpdateItemCache()
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local myPos = hrp.Position
    local isNearAuction = false

    for _, areaPos in ipairs(AUCTION_AREAS) do
        if (areaPos - myPos).Magnitude < 180 then
            isNearAuction = true
            break
        end
    end

    if isNearAuction then
        local bounds = workspace:GetPartBoundsInRadius(myPos, 100)
        local seen = {}
        for _, part in ipairs(bounds) do
            local model = part:FindFirstAncestorOfClass("Model")
            local target = model or part
            if target and not seen[target] and target ~= character and not target:IsDescendantOf(character) then
                seen[target] = true
                local isWon = target:GetAttribute("AuctionItemId") or target:GetAttribute("WonItem") or target:GetAttribute("ItemId")
                local prompt = target:FindFirstChildOfClass("ProximityPrompt") or part:FindFirstChildOfClass("ProximityPrompt")
                if isWon or prompt then
                    table.insert(cachedAuctionItems, target)
                end
            end
        end
    end
end

function AuctionModule.ExecuteInstantLoot(State)
    local itemsToLoot = {}
    local seen = {}

    for _, obj in ipairs(cachedAuctionItems) do
        if obj and obj.Parent and not seen[obj] then
            seen[obj] = true
            table.insert(itemsToLoot, obj)
        end
    end

    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if hrp then
        local bounds = workspace:GetPartBoundsInRadius(hrp.Position, 80)
        for _, part in ipairs(bounds) do
            local model = part:FindFirstAncestorOfClass("Model")
            local target = model or part
            if target and not seen[target] and target ~= character and not target:IsDescendantOf(character) then
                seen[target] = true
                local isWon = target:GetAttribute("AuctionItemId") or target:GetAttribute("WonItem") or target:GetAttribute("ItemId")
                local prompt = target:FindFirstChildOfClass("ProximityPrompt") or part:FindFirstChildOfClass("ProximityPrompt")
                if isWon or prompt then
                    table.insert(itemsToLoot, target)
                end
            end
        end
    end

    if #itemsToLoot > 0 then
        AuctionModule.VacuumLootAll(itemsToLoot, State)
    end
    cachedAuctionItems = {}
end

function AuctionModule.TeleportToNextAuction()
    currentAreaIdx = currentAreaIdx + 1
    if currentAreaIdx > #AUCTION_AREAS then
        currentAreaIdx = 1
    end
    local targetPos = AUCTION_AREAS[currentAreaIdx]
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if hrp and targetPos then
        for _ = 1, 3 do
            hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
            task.wait(0.08)
        end
    end
end

function AuctionModule.IsAtBasePlot()
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local pos = hrp.Position
    if math.abs(pos.X) < 380 and math.abs(pos.Z) < 380 then
        return true
    end

    return false
end

function AuctionModule.SetupAuctionHooks(State)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local auctionEvents = events and events:FindFirstChild("Auction")

    if auctionEvents then
        local feePaid = auctionEvents:FindFirstChild("AuctionFeePaid")
        if feePaid then
            feePaid.OnClientEvent:Connect(function()
                if State.FastPickup then
                    task.spawn(function()
                        AuctionModule.ExecuteInstantLoot(State)
                    end)
                end
            end)
        end

        local winBid = auctionEvents:FindFirstChild("UpdateCurrentWinningBid")
        if winBid then
            winBid.OnClientEvent:Connect(function(bidder)
                if tostring(bidder) == LocalPlayer.Name and State.FastPickup then
                    task.spawn(function()
                        AuctionModule.ExecuteInstantLoot(State)
                    end)
                end
            end)
        end

        local toggleBidding = auctionEvents:FindFirstChild("ToggleBiddingUI")
        if toggleBidding then
            toggleBidding.OnClientEvent:Connect(function(isOpen)
                if not isOpen and State.FastPickup then
                    task.spawn(function()
                        AuctionModule.ExecuteInstantLoot(State)
                    end)
                end
            end)
        end
    end
end

function AuctionModule.StartFastPickupLoop(State, washMod)
    if washMod then
        boundWashModule = washMod
    end

    AuctionModule.StopFastPickupLoop()
    AuctionModule.SetupAuctionHooks(State)

    cacheThread = task.spawn(function()
        while State.FastPickup do
            pcall(AuctionModule.UpdateItemCache)
            task.wait(0.2)
        end
    end)

    pickupThread = task.spawn(function()
        while State.FastPickup do
            pcall(function()
                AuctionModule.ExecuteInstantLoot(State)
            end)
            task.wait(0.3)
        end
    end)

    smartWarpThread = task.spawn(function()
        while State.SmartWarp do
            pcall(function()
                if AuctionModule.IsAtBasePlot() then
                    local timeSinceWon = os.time() - lastWonTime
                    if timeSinceWon > 12 then
                        AuctionModule.TeleportToNextAuction()
                        task.wait(2.5)
                    end
                end
            end)
            task.wait(0.4)
        end
    end)
end

function AuctionModule.StopFastPickupLoop()
    if cacheThread then
        pcall(function() task.cancel(cacheThread) end)
        cacheThread = nil
    end
    if pickupThread then
        pcall(function() task.cancel(pickupThread) end)
        pickupThread = nil
    end
    if smartWarpThread then
        pcall(function() task.cancel(smartWarpThread) end)
        smartWarpThread = nil
    end
end

return AuctionModule
