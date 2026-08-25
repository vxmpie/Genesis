local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local AuctionModule = {}
local pickupThread = nil
local connections = {}

local TARGET_FOLDERS = { "AuctionItems", "WonItems", "StorageItems", "Auction", "WonStorage" }

local function attemptPick(target)
    if not target then return end
    local events = ReplicatedStorage:FindFirstChild("Events")
    local auctionEvents = events and events:FindFirstChild("Auction")
    local draggingEvents = events and events:FindFirstChild("Dragging")

    local auctionPickupItem = auctionEvents and auctionEvents:FindFirstChild("AuctionPickupItem")
    local pickUpItem = draggingEvents and draggingEvents:FindFirstChild("PickUpItem")

    if auctionPickupItem then
        pcall(function() auctionPickupItem:FireServer(target) end)
    end
    if pickUpItem then
        pcall(function() pickUpItem:FireServer(target) end)
    end
end

function AuctionModule.ProcessNearby()
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local myPos = hrp.Position
    local bounds = workspace:GetPartBoundsInRadius(myPos, 35)

    local checked = {}
    for _, part in ipairs(bounds) do
        local model = part:FindFirstAncestorOfClass("Model")
        local target = model or part

        if target and not checked[target] and target ~= character and not target:IsDescendantOf(character) then
            checked[target] = true
            local isWon = target:GetAttribute("AuctionItemId") or target:GetAttribute("WonItem") or target:GetAttribute("ItemId")
            local hasPrompt = target:FindFirstChildOfClass("ProximityPrompt") or part:FindFirstChildOfClass("ProximityPrompt")

            if isWon or hasPrompt then
                attemptPick(target)
            end
        end
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
                    task.defer(function()
                        attemptPick(child)
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
                            task.defer(function()
                                attemptPick(subChild)
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
            pcall(AuctionModule.ProcessNearby)
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
