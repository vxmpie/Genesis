local Auction = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local ItemsDB = nil

Auction.Status = {
    CurrentAuction = "idle",
    WinningBid = 0,
    NextBid = 0,
    LotValue = 0,
    Powers = {XRay = 0, Calc = 0, Kick = 0},
    Events = {
        Moonlit = "in 0:00",
        Rain = "in 0:00",
        Sandstorm = "in 0:00",
        CargoShip = "in 0:00",
        AlienInvasion = "in 0:00",
        FishingSeason = "in 0:00"
    },
    LostAndFound = 0,
    Filters = {Kept = 0, Skipped = 0}
}

local function getAuctionFolder()
    local events = ReplicatedStorage:FindFirstChild("Events")
    return events and events:FindFirstChild("Auction")
end

local function scanAuctionUnits()
    local units = {}
    local auctionsFolder = Workspace:FindFirstChild("Auctions") or Workspace:FindFirstChild("Garages") or Workspace:FindFirstChild("Map")
    if auctionsFolder then
        for _, obj in ipairs(auctionsFolder:GetDescendants()) do
            if obj.Name == "AuctionPad" or obj.Name == "AuctionZone" or obj:FindFirstChild("AuctionTrigger") then
                table.insert(units, obj)
            end
        end
    end
    return units
end

function Auction.Init(Config, DB)
    ItemsDB = DB
    task.spawn(function()
        while task.wait(0.5) do
            if not Config.Get("StopAllAutomation", false) then
                local auctionFolder = getAuctionFolder()
                if auctionFolder then
                    if Config.Get("AutoBuyPowers", false) then
                        pcall(function()
                            local buyPower = auctionFolder:FindFirstChild("BuyPower") or auctionFolder:FindFirstChild("BuyPowerPack")
                            if buyPower then
                                local targetPower = Config.Get("PowersToBuy", "Calculator")
                                local threshold = Config.Get("BuyPowersBelow", 5)
                                local currentCount = Auction.Status.Powers[targetPower] or 0
                                if currentCount < threshold then
                                    buyPower:InvokeServer(targetPower)
                                end
                            end
                        end)
                    end

                    if Config.Get("AutoXRay", false) then
                        pcall(function()
                            local xRay = auctionFolder:FindFirstChild("UseXRay")
                            if xRay then
                                xRay:InvokeServer()
                            end
                        end)
                    end

                    if Config.Get("AutoCalculator", false) then
                        pcall(function()
                            local calc = auctionFolder:FindFirstChild("UseCalculator")
                            if calc then
                                calc:InvokeServer()
                            end
                        end)
                    end

                    if Config.Get("AutoKickTopBidder", false) then
                        pcall(function()
                            local kick = auctionFolder:FindFirstChild("UseKickNPC")
                            if kick then
                                kick:InvokeServer()
                            end
                        end)
                    end

                    if Config.Get("AutoBid", false) then
                        pcall(function()
                            local bidEvent = auctionFolder:FindFirstChild("Bid")
                            if bidEvent then
                                local minBid = Config.Get("MinBid", 10000)
                                local maxBid = Config.Get("MaxBid", 0)
                                local currentBid = Auction.Status.WinningBid or 0
                                local shouldBid = true

                                if maxBid > 0 and currentBid >= maxBid then
                                    shouldBid = false
                                    if Config.Get("LeaveIfBidOverMax", true) then
                                        task.wait(Config.Get("LeaveDelay", 0))
                                    end
                                end

                                if shouldBid then
                                    local mode = Config.Get("StopNPCBidMode", "Consistent")
                                    if mode == "Potentially Bugged" then
                                        for i = 1, 3 do
                                            bidEvent:FireServer()
                                        end
                                    else
                                        bidEvent:FireServer()
                                    end
                                end
                            end
                        end)
                    end
                end
            end
            task.wait(Config.Get("BidDelay", 0.5))
        end
    end)
end

return Auction
