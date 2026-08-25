local Shop = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

function Shop.Init(Config, DB)
    local eventsFolder = ReplicatedStorage:WaitForChild("Events")
    local plotEvents = eventsFolder:WaitForChild("Plot")
    local pawnEvents = eventsFolder:FindFirstChild("Pawn") or eventsFolder:FindFirstChild("Shop")
    
    local placeStockRemote = plotEvents:FindFirstChild("PlaceStockItem")
    local changePriceRemote = plotEvents:FindFirstChild("ChangeStockPrice")
    local expandShelfRemote = plotEvents:FindFirstChild("PurchaseShelfPack")
    local expandFloorRemote = plotEvents:FindFirstChild("ExpandPlot")
    local sellRemote = pawnEvents and (pawnEvents:FindFirstChild("SellItems") or pawnEvents:FindFirstChild("QuickSell"))

    task.spawn(function()
        while task.wait(1) do
            if Config.Get("AutoStockShopShelves", false) and not Config.Get("StopAllAutomation", false) then
                local markup = Config.Get("ShelfPricePercent", 150) / 100
                pcall(function()
                    local backpack = LocalPlayer:FindFirstChild("Backpack")
                    if backpack and placeStockRemote then
                        for _, item in ipairs(backpack:GetChildren()) do
                            local itemData = DB.GetItem(item.Name)
                            local basePrice = itemData and itemData.Price or 100
                            local targetPrice = math.floor(basePrice * markup)
                            
                            placeStockRemote:FireServer(item)
                            if changePriceRemote then
                                changePriceRemote:FireServer(item, targetPrice)
                            end
                            task.wait(0.05)
                        end
                    end
                end)
            end
        end
    end)

    task.spawn(function()
        while task.wait(2) do
            if not Config.Get("StopAllAutomation", false) then
                if Config.Get("AutoExpandShelfSlots", false) and expandShelfRemote then
                    pcall(function() expandShelfRemote:InvokeServer() end)
                end
                if Config.Get("AutoExpandShopFloor", false) and expandFloorRemote then
                    pcall(function() expandFloorRemote:FireServer() end)
                end
            end
        end
    end)
end

return Shop
