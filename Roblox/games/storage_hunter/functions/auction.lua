local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local AuctionModule = {}
local loopThread = nil

local function getStateVal(StoreOrState, key, defaultVal)
    if type(StoreOrState) == "table" then
        if StoreOrState.Get then
            local v = StoreOrState.Get(key)
            if v ~= nil then return v end
        elseif StoreOrState[key] ~= nil then
            return StoreOrState[key]
        end
    end
    return defaultVal
end

local function getAuctionEvents()
    local events = ReplicatedStorage:FindFirstChild("Events")
    return events and events:FindFirstChild("Auction")
end

function AuctionModule.Bid(auctionId)
    local events = getAuctionEvents()
    if events and events:FindFirstChild("Bid") then
        pcall(function()
            events.Bid:FireServer("BiddingUIClosed", nil, auctionId or "")
        end)
    end
end

function AuctionModule.UsePowers()
    local events = getAuctionEvents()
    if not events then return end
    
    if events:FindFirstChild("UseXRay") then
        pcall(function() events.UseXRay:InvokeServer() end)
    end
    if events:FindFirstChild("UseCalculator") then
        pcall(function() events.UseCalculator:InvokeServer() end)
    end
    if events:FindFirstChild("UseKickNPC") then
        pcall(function() events.UseKickNPC:InvokeServer() end)
    end
end

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

function AuctionModule.StartLoop(StoreOrState)
    if loopThread then
        pcall(function() task.cancel(loopThread) end)
    end

    loopThread = task.spawn(function()
        while true do
            if getStateVal(StoreOrState, "FastPickup", true) then
                pcall(AuctionModule.FastPickup)
            end

            local useXRay = getStateVal(StoreOrState, "AutoXRay", false)
            local useCalc = getStateVal(StoreOrState, "AutoCalculator", false)
            local useKick = getStateVal(StoreOrState, "AutoKickNPC", false)

            if useXRay or useCalc or useKick then
                pcall(AuctionModule.UsePowers)
            end

            local delayVal = tonumber(getStateVal(StoreOrState, "BidDelay", 0.1)) or 0.1
            task.wait(math.max(0.1, delayVal))
        end
    end)
end

function AuctionModule.StopLoop()
    if loopThread then
        pcall(function() task.cancel(loopThread) end)
        loopThread = nil
    end
end

return AuctionModule
