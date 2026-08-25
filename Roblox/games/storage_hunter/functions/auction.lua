local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AuctionModule = {}
local pickupThread = nil

function AuctionModule.FastPickup()
    local events = ReplicatedStorage:FindFirstChild("Events")
    local auctionEvents = events and events:FindFirstChild("Auction")
    local draggingEvents = events and events:FindFirstChild("Dragging")

    local auctionPickupItem = auctionEvents and auctionEvents:FindFirstChild("AuctionPickupItem")
    local pickUpItem = draggingEvents and draggingEvents:FindFirstChild("PickUpItem")

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            local isWon = obj:GetAttribute("AuctionItemId") or obj:GetAttribute("WonItem") or obj:GetAttribute("ItemId")
            local isAuctionParent = obj.Parent and (obj.Parent.Name == "AuctionItems" or obj.Parent.Name == "WonItems" or obj.Parent.Name == "StorageItems")
            local hasPrompt = obj:FindFirstChildOfClass("ProximityPrompt") or obj:FindFirstChild("PromptPart")

            if isWon or isAuctionParent or hasPrompt then
                if auctionPickupItem then
                    pcall(function() auctionPickupItem:FireServer(obj) end)
                end
                if pickUpItem then
                    pcall(function() pickUpItem:FireServer(obj) end)
                end
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
            task.wait(0.3)
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
