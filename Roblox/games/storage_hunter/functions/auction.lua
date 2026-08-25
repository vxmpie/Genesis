local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local AuctionModule = {}
local pickupThread = nil
local connections = {}
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

    local events = ReplicatedStorage:FindFirstChild("Events")
    local vehEvents = events and events:FindFirstChild("Vehicles")
    if vehEvents and vehEvents:FindFirstChild("RequestSpawn") then
        pcall(function() vehEvents.RequestSpawn:InvokeServer() end)
        task.wait(0.2)
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
        local bounds = workspace:GetPartBoundsInRadius(myPos, 50)
        for _, part in ipairs(bounds) do
            local model = part:FindFirstAncestorOfClass("Model")
            local target = model or part

            if target and not processed[target] and target ~= character and not target:IsDescendantOf(character) then
                local isWon = target:GetAttribute("AuctionItemId") or target:GetAttribute("WonItem") or target:GetAttribute("ItemId")
                local hasPrompt = target:FindFirstChildOfClass("ProximityPrompt") or part:FindFirstChildOfClass("ProximityPrompt")

                if isWon or hasPrompt then
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

function AuctionModule.SetupEventListeners(State)
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections = {}

    local events = ReplicatedStorage:FindFirstChild("Events")
    local auctionEvents = events and events:FindFirstChild("Auction")
    local plotEvents = events and events:FindFirstChild("Plot")

    if auctionEvents then
        local feePaid = auctionEvents:FindFirstChild("AuctionFeePaid")
        if feePaid then
            local cFee = feePaid.OnClientEvent:Connect(function()
                if State.FastPickup then
                    task.spawn(function()
                        AuctionModule.ScanAndLoot(State)
                    end)
                end
            end)
            table.insert(connections, cFee)
        end

        local winBid = auctionEvents:FindFirstChild("UpdateCurrentWinningBid")
        if winBid then
            local cWin = winBid.OnClientEvent:Connect(function(bidderName)
                if bidderName == LocalPlayer.Name and State.FastPickup then
                    task.spawn(function()
                        task.wait(0.1)
                        AuctionModule.ScanAndLoot(State)
                    end)
                end
            end)
            table.insert(connections, cWin)
        end

        local toggleBidding = auctionEvents:FindFirstChild("ToggleBiddingUI")
        if toggleBidding then
            local cTog = toggleBidding.OnClientEvent:Connect(function(isOpen)
                if not isOpen and State.FastPickup then
                    task.spawn(function()
                        task.wait(0.05)
                        AuctionModule.ScanAndLoot(State)
                    end)
                end
            end)
            table.insert(connections, cTog)
        end
    end

    if plotEvents and plotEvents:FindFirstChild("TeleportToPlot") then
        local cTele = plotEvents.TeleportToPlot.OnClientEvent:Connect(function()
            if State.SmartWarp then
                task.spawn(function()
                    task.wait(0.3)
                    if not AuctionModule.HasItemsToStock() then
                        AuctionModule.TeleportToNextAuction()
                    end
                end)
            end
        end)
        table.insert(connections, cTele)
    end

    for _, folderName in ipairs(TARGET_FOLDERS) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            local c = folder.ChildAdded:Connect(function(child)
                if State.FastPickup then
                    task.spawn(function()
                        AuctionModule.InstantLootAll({ child }, State)
                    end)
                end
            end)
            table.insert(connections, c)
        end
    end

    local cMain = workspace.ChildAdded:Connect(function(child)
        if State.FastPickup then
            for _, fName in ipairs(TARGET_FOLDERS) do
                if child.Name == fName then
                    local subC = child.ChildAdded:Connect(function(subChild)
                        if State.FastPickup then
                            task.spawn(function()
                                AuctionModule.InstantLootAll({ subChild }, State)
                            end)
                        end
                    end)
                    table.insert(connections, subC)
                end
            end
        end
    end)
    table.insert(connections, cMain)
end

function AuctionModule.StartFastPickupLoop(State, washMod)
    if washMod then
        boundWashModule = washMod
    end

    AuctionModule.StopFastPickupLoop()
    AuctionModule.SetupEventListeners(State)

    pickupThread = task.spawn(function()
        while State.FastPickup do
            pcall(function() AuctionModule.ScanAndLoot(State) end)
            task.wait(1.5)
        end
    end)
end

function AuctionModule.StopFastPickupLoop()
    if pickupThread then
        pcall(function() task.cancel(pickupThread) end)
        pickupThread = nil
    end
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections = {}
end

return AuctionModule
