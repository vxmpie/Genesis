local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local AuctionModule = {}
local pickupThread = nil
local smartWarpThread = nil
local boundWashModule = nil

local TARGET_FOLDERS = { "AuctionItems", "WonItems", "StorageItems", "Auction", "WonStorage" }

local AUCTION_AREAS = {
    Vector3.new(-820, 15, -1200),
    Vector3.new(1250, 15, 850),
    Vector3.new(-450, 15, 600),
    Vector3.new(780, 15, -950),
    Vector3.new(210, 15, -340),
    Vector3.new(-1100, 15, 300),
    Vector3.new(1500, 20, -1400),
    Vector3.new(920, 15, 1400),
    Vector3.new(-1400, 25, -500),
    Vector3.new(-320, 15, -780),
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

    return false
end

function AuctionModule.InstantLootAll(items, State)
    if not items or #items == 0 then return end

    AuctionModule.EnsureInVehicle()

    local events = ReplicatedStorage:FindFirstChild("Events")
    local auctionEvents = events and events:FindFirstChild("Auction")
    local draggingEvents = events and events:FindFirstChild("Dragging")

    local pickupStart = auctionEvents and auctionEvents:FindFirstChild("AuctionPickupStart")
    local pickupItem = auctionEvents and auctionEvents:FindFirstChild("AuctionPickupItem")
    local pickupEnd = auctionEvents and auctionEvents:FindFirstChild("AuctionPickupEnd")
    local pickUpDrag = draggingEvents and draggingEvents:FindFirstChild("PickUpItem")

    if pickupStart then
        pcall(function() pickupStart:FireServer() end)
    end

    for _, obj in ipairs(items) do
        task.spawn(function()
            if fireproximityprompt then
                local prompt = obj:FindFirstChildOfClass("ProximityPrompt") or (obj:IsA("BasePart") and obj:FindFirstChildOfClass("ProximityPrompt"))
                if prompt then
                    pcall(function() fireproximityprompt(prompt, 0) end)
                end
            end
            if pickupItem then
                pcall(function() pickupItem:FireServer(obj) end)
            end
            if pickUpDrag then
                pcall(function() pickUpDrag:FireServer(obj) end)
            end
        end)
    end

    if pickupEnd then
        task.defer(function()
            pcall(function() pickupEnd:FireServer() end)
        end)
    end

    if boundWashModule and State and State.AutoWash then
        task.spawn(function()
            boundWashModule.QuickWash(State)
        end)
    end
end

function AuctionModule.ScanAndLoot(State)
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local myPos = hrp and hrp.Position

    local itemsToPick = {}
    local processed = {}

    for _, folderName in ipairs(TARGET_FOLDERS) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do
                if not processed[obj] then
                    processed[obj] = true
                    table.insert(itemsToPick, obj)
                end
            end
        end
    end

    if myPos then
        local bounds = workspace:GetPartBoundsInRadius(myPos, 60)
        for _, part in ipairs(bounds) do
            local model = part:FindFirstAncestorOfClass("Model")
            local target = model or part

            if target and not processed[target] and target ~= character and not target:IsDescendantOf(character) then
                local isWon = target:GetAttribute("AuctionItemId") or target:GetAttribute("WonItem") or target:GetAttribute("ItemId")
                local prompt = target:FindFirstChildOfClass("ProximityPrompt") or part:FindFirstChildOfClass("ProximityPrompt")

                if isWon or prompt then
                    processed[target] = true
                    table.insert(itemsToPick, target)
                end
            end
        end
    end

    if #itemsToPick > 0 then
        AuctionModule.InstantLootAll(itemsToPick, State)
    end
end

function AuctionModule.HasItemsToStock()
    local events = ReplicatedStorage:FindFirstChild("Events")
    local plotEvents = events and events:FindFirstChild("Plot")
    if plotEvents and plotEvents:FindFirstChild("GetDraggingInventory") then
        local ok, list = pcall(function() return plotEvents.GetDraggingInventory:InvokeServer() end)
        if ok and type(list) == "table" and #list > 0 then
            return true
        end
    end

    local invEvents = events and events:FindFirstChild("Inventory")
    if invEvents and invEvents:FindFirstChild("GetPlayerInventory") then
        local ok2, inv = pcall(function() return invEvents.GetPlayerInventory:InvokeServer() end)
        if ok2 and type(inv) == "table" then
            local count = 0
            for _, _ in pairs(inv) do
                count = count + 1
            end
            if count > 0 then
                return true
            end
        end
    end

    return false
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
        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
    end
end

function AuctionModule.IsAtPlot()
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local myPos = hrp.Position
    local plots = workspace:FindFirstChild("Plots")
    if plots then
        local myPlot = plots:FindFirstChild(LocalPlayer.Name) or plots:FindFirstChild(LocalPlayer.Name .. "'s Plot")
        if myPlot then
            local plotPart = myPlot:FindFirstChildWhichIsA("BasePart", true)
            if plotPart and (plotPart.Position - myPos).Magnitude < 120 then
                return true
            end
        end
    end

    for _, obj in ipairs(workspace:GetChildren()) do
        if string.find(obj.Name, "Plot") and obj:IsA("Model") then
            local pPart = obj:FindFirstChildWhichIsA("BasePart", true)
            if pPart and (pPart.Position - myPos).Magnitude < 100 then
                return true
            end
        end
    end

    return false
end

function AuctionModule.StartFastPickupLoop(State, washMod)
    if washMod then
        boundWashModule = washMod
    end

    AuctionModule.StopFastPickupLoop()

    pickupThread = task.spawn(function()
        while State.FastPickup do
            pcall(function() AuctionModule.ScanAndLoot(State) end)
            task.wait(0.8)
        end
    end)

    smartWarpThread = task.spawn(function()
        while State.SmartWarp do
            pcall(function()
                if AuctionModule.IsAtPlot() then
                    if not AuctionModule.HasItemsToStock() then
                        task.wait(0.2)
                        AuctionModule.TeleportToNextAuction()
                        task.wait(2)
                    end
                end
            end)
            task.wait(1)
        end
    end)
end

function AuctionModule.StopFastPickupLoop()
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
