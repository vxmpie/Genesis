local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StockModule = {}
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

function StockModule.Process(StoreOrState)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local plotEvents = events and events:FindFirstChild("Plot")
    local pawnEvents = events and events:FindFirstChild("Pawn")

    if getStateVal(StoreOrState, "AutoStock", false) and plotEvents and plotEvents:FindFirstChild("PlaceStockItem") then
        pcall(function()
            local getDragging = plotEvents:FindFirstChild("GetDraggingInventory")
            if getDragging then
                local items = getDragging:InvokeServer()
                if items and type(items) == "table" then
                    for _, item in ipairs(items) do
                        plotEvents.PlaceStockItem:FireServer(item)
                        task.wait(0.1)
                    end
                end
            end
        end)
    end

    if getStateVal(StoreOrState, "AutoSell", false) and pawnEvents and pawnEvents:FindFirstChild("SellItems") then
        pcall(function()
            local getSellable = pawnEvents:FindFirstChild("GetSellableItems")
            if getSellable then
                local sellable = getSellable:InvokeServer()
                if sellable and type(sellable) == "table" and #sellable > 0 then
                    pawnEvents.SellItems:InvokeServer(sellable)
                end
            end
        end)
    end
end

function StockModule.StartLoop(StoreOrState)
    if loopThread then
        pcall(function() task.cancel(loopThread) end)
    end

    loopThread = task.spawn(function()
        while true do
            local autoStock = getStateVal(StoreOrState, "AutoStock", false)
            local autoSell = getStateVal(StoreOrState, "AutoSell", false)
            if autoStock or autoSell then
                pcall(function() StockModule.Process(StoreOrState) end)
            end
            task.wait(4)
        end
    end)
end

function StockModule.StopLoop()
    if loopThread then
        pcall(function() task.cancel(loopThread) end)
        loopThread = nil
    end
end

return StockModule
