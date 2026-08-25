local Shop = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local ItemsDB = nil

Shop.Status = {
    Sold = 0,
    Earned = 0,
    Stocked = 0,
    Repriced = 0,
    OffersAccepted = 0,
    OffersDeclined = 0,
    GroundPlaced = 0,
    GroundPickedUp = 0,
    Stored = 0
}

local function getEventsFolder()
    return ReplicatedStorage:FindFirstChild("Events")
end

function Shop.Init(Config, DB)
    ItemsDB = DB
    task.spawn(function()
        while task.wait(1) do
            if not Config.Get("StopAllAutomation", false) then
                local events = getEventsFolder()
                if events then
                    if Config.Get("AutoSell", false) then
                        pcall(function()
                            local pawn = events:FindFirstChild("Pawn")
                            local sellItems = pawn and pawn:FindFirstChild("SellItems")
                            if sellItems then
                                sellItems:InvokeServer()
                            end
                        end)
                    end

                    if Config.Get("AutoStockShopShelves", false) then
                        pcall(function()
                            local plot = events:FindFirstChild("Plot")
                            local placeStock = plot and plot:FindFirstChild("PlaceStockItem")
                            if placeStock then
                                placeStock:FireServer()
                                Shop.Status.Stocked = Shop.Status.Stocked + 1
                            end
                        end)
                    end

                    if Config.Get("AutoAcceptNPCOffers", false) then
                        pcall(function()
                            local shopper = events:FindFirstChild("NPCShopper") or events:FindFirstChild("Shopper")
                            if shopper then
                                local accept = shopper:FindFirstChild("AcceptOffer")
                                local decline = shopper:FindFirstChild("DeclineOffer")
                                if accept then
                                    accept:FireServer()
                                    Shop.Status.OffersAccepted = Shop.Status.OffersAccepted + 1
                                end
                            end
                        end)
                    end

                    if Config.Get("AutoExpandShelfSlots", false) or Config.Get("AutoExpandShopFloor", false) then
                        pcall(function()
                            local plot = events:FindFirstChild("Plot")
                            local expand = plot and (plot:FindFirstChild("ExpandPlot") or plot:FindFirstChild("PurchaseShelfPack"))
                            if expand then
                                expand:InvokeServer()
                            end
                        end)
                    end

                    if Config.Get("AutoPickUpGroundItems", false) then
                        pcall(function()
                            local plot = events:FindFirstChild("Plot")
                            local pickGround = plot and plot:FindFirstChild("PickUpItem")
                            if pickGround then
                                pickGround:FireServer()
                                Shop.Status.GroundPickedUp = Shop.Status.GroundPickedUp + 1
                            end
                        end)
                    end
                end
            end
        end
    end)
end

return Shop
