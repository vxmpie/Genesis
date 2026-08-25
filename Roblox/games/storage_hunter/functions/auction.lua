local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local AuctionModule = {}
local pickupThread = nil
local connections = {}

local TARGET_FOLDERS = { "AuctionItems", "WonItems", "StorageItems", "Auction", "WonStorage" }

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

function AuctionModule.InstantLootAll(items)
    if not items or #items == 0 then return end

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
end

function AuctionModule.ScanAndLoot()
    AuctionModule.EnsureInVehicle()

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
        local bounds = workspace:GetPartBoundsInRadius(myPos, 40)
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
        AuctionModule.InstantLootAll(itemsToPick)
    end
end

function AuctionModule.SetupEventListeners(State)
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections = {}

    for _, folderName in ipairs(TARGET_FOLDERS) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            local c = folder.ChildAdded:Connect(function(child)
                if State.FastPickup then
                    task.spawn(function()
                        AuctionModule.EnsureInVehicle()
                        AuctionModule.InstantLootAll({ child })
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
                                AuctionModule.EnsureInVehicle()
                                AuctionModule.InstantLootAll({ subChild })
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

function AuctionModule.StartFastPickupLoop(State)
    AuctionModule.StopFastPickupLoop()
    AuctionModule.SetupEventListeners(State)

    pickupThread = task.spawn(function()
        while State.FastPickup do
            pcall(AuctionModule.ScanAndLoot)
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
