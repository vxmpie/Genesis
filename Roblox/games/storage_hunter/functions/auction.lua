local Auction = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local RateLimiter = {
    Tokens = 10,
    MaxTokens = 10,
    RefillRate = 10,
    LastRefill = os.clock()
}

function RateLimiter:Consume()
    local now = os.clock()
    local delta = now - self.LastRefill
    self.Tokens = math.min(self.MaxTokens, self.Tokens + delta * self.RefillRate)
    self.LastRefill = now
    if self.Tokens >= 1 then
        self.Tokens = self.Tokens - 1
        return true
    end
    return false
end

function Auction.Init(Config, DB)
    local eventsFolder = ReplicatedStorage:WaitForChild("Events")
    local auctionEvents = eventsFolder:WaitForChild("Auction")
    local bidRemote = auctionEvents:WaitForChild("Bid")
    local leaveRemote = auctionEvents:WaitForChild("LeaveAuction")
    local xrayRemote = auctionEvents:WaitForChild("UseXRay")
    local calcRemote = auctionEvents:WaitForChild("UseCalculator")
    local kickRemote = auctionEvents:WaitForChild("UseKickNPC")
    local buyPowerRemote = auctionEvents:WaitForChild("BuyPower")

    local activeAuction = {
        IsRunning = false,
        CurrentBid = 0,
        TopBidder = nil,
        LotValue = 0,
        LotItemsCount = 0,
        LastBidTime = 0
    }

    local function computeLotValue(garageModel)
        if not garageModel then return 0 end
        local totalVal = 0
        local count = 0
        local itemsFolder = garageModel:FindFirstChild("Items") or garageModel:FindFirstChild("Storage") or garageModel
        for _, item in ipairs(itemsFolder:GetDescendants()) do
            if item:IsA("Model") or item:IsA("BasePart") then
                local itemName = item.Name
                local itemData = DB.GetItem(itemName)
                if itemData then
                    local basePrice = itemData.Price or 50
                    local rarityMult = DB.GetRarityMultiplier(itemData.Rarity)
                    local mutMult = 1.0
                    local mutAttr = item:GetAttribute("Mutation") or item:GetAttribute("Variant")
                    if mutAttr and typeof(mutAttr) == "string" then
                        mutMult = 2.5
                    end
                    totalVal = totalVal + math.floor(basePrice * rarityMult * mutMult)
                    count = count + 1
                end
            end
        end
        return totalVal, count
    end

    if auctionEvents:FindFirstChild("UpdateCurrentWinningBid") then
        auctionEvents.UpdateCurrentWinningBid.OnClientEvent:Connect(function(bidAmount, bidderName)
            activeAuction.IsRunning = true
            activeAuction.CurrentBid = tonumber(bidAmount) or activeAuction.CurrentBid
            activeAuction.TopBidder = tostring(bidderName or "")
            
            if Config.Get("AutoBid", false) and not Config.Get("StopAllAutomation", false) then
                local maxBid = Config.Get("MaxBid", 0)
                local minBid = Config.Get("MinBid", 10000)
                local minLotVal = Config.Get("MinLotValue", 0)
                local bidDelay = Config.Get("BidDelay", 0.5)

                if Config.Get("LeaveIfBidOverMax", true) and maxBid > 0 and activeAuction.CurrentBid >= maxBid then
                    pcall(function() leaveRemote:InvokeServer() end)
                    return
                end

                if Config.Get("LeaveIfLotUnderValue", false) and minLotVal > 0 and activeAuction.LotValue > 0 and activeAuction.LotValue < minLotVal then
                    pcall(function() leaveRemote:InvokeServer() end)
                    return
                end

                if activeAuction.TopBidder ~= LocalPlayer.Name and os.clock() - activeAuction.LastBidTime >= bidDelay then
                    if RateLimiter:Consume() then
                        activeAuction.LastBidTime = os.clock()
                        pcall(function()
                            bidRemote:FireServer()
                        end)
                    end
                end
            end
        end)
    end

    if auctionEvents:FindFirstChild("ToggleBiddingUI") then
        auctionEvents.ToggleBiddingUI.OnClientEvent:Connect(function(isOpen, garageData)
            activeAuction.IsRunning = isOpen
            if isOpen and typeof(garageData) == "Instance" then
                local val, count = computeLotValue(garageData)
                activeAuction.LotValue = val
                activeAuction.LotItemsCount = count

                if Config.Get("AutoXRay", false) then
                    task.spawn(function() pcall(function() xrayRemote:InvokeServer() end) end)
                end
                if Config.Get("AutoCalculator", false) then
                    task.spawn(function() pcall(function() calcRemote:InvokeServer() end) end)
                end
                if Config.Get("AutoKickTopBidder", false) then
                    task.spawn(function() pcall(function() kickRemote:InvokeServer() end) end)
                end
            end
        end)
    end

    task.spawn(function()
        while task.wait(5) do
            if Config.Get("AutoBuyPowers", false) and not Config.Get("StopAllAutomation", false) then
                local powerType = Config.Get("PowersToBuy", "Calculator")
                pcall(function()
                    buyPowerRemote:InvokeServer(powerType, 1)
                end)
            end
        end
    end)
end

return Auction
