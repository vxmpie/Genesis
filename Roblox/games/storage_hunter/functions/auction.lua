local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local AuctionModule = {}
local pickupThread = nil

local TARGET_FOLDERS = { "AuctionItems", "WonItems", "StorageItems", "Auction", "WonStorage" }

function AuctionModule.FastPickup()
    local events = ReplicatedStorage:FindFirstChild("Events")
    local auctionEvents = events and events:FindFirstChild("Auction")
    local draggingEvents = events and events:FindFirstChild("Dragging")

    local auctionPickupItem = auctionEvents and auctionEvents:FindFirstChild("AuctionPickupItem")
    local pickUpItem = draggingEvents and draggingEvents:FindFirstChild("PickUpItem")

    if not auctionPickupItem and not pickUpItem then return end

    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local myPos = hrp and hrp.Position

    local itemsToPick = {}

    for _, folderName in ipairs(TARGET_FOLDERS) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do
                table.insert(itemsToPick, obj)
            end
        end
    end

    if myPos then
        local bounds = workspace:GetPartBoundsInRadius(myPos, 35)
        for _, part in ipairs(bounds) do
            local parentModel = part:FindFirstAncestorOfClass("Model")
            local target = parentModel or part

            if target and target ~= character and not target:IsDescendantOf(character) then
                local isWon = target:GetAttribute("AuctionItemId") or target:GetAttribute("WonItem") or target:GetAttribute("ItemId")
                local hasPrompt = target:FindFirstChildOfClass("ProximityPrompt") or part:FindFirstChildOfClass("ProximityPrompt")

                if isWon or hasPrompt then
                    table.insert(itemsToPick, target)
                end
            end
        end
    end

    local processed = {}
    for _, obj in ipairs(itemsToPick) do
        if not processed[obj] then
            processed[obj] = true
            if auctionPickupItem then
                pcall(function() auctionPickupItem:FireServer(obj) end)
            end
            if pickUpItem then
                pcall(function() pickUpItem:FireServer(obj) end)
            end
        end
    end
end

function AuctionModule.StartFastPickupLoop(State)
    if pickupThread then
        pcall(function() task.cancel(pickupThread) end)
    end
    pickupThread = task.spawn(function()
        while State.FastPickup do
            pcall(AuctionModule.FastPickup)
            task.wait(1)
        end
    end)
end

function AuctionModule.StopFastPickupLoop()
    if pickupThread then
        pcall(function() task.cancel(pickupThread) end)
        pickupThread = nil
    end
end

return AuctionModule
