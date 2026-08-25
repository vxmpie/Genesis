local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WashModule = {}
local washThread = nil

local ItemsCache = nil
local function getItemsModule()
    if ItemsCache then return ItemsCache end
    pcall(function()
        local mod = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Items")
        if mod then
            ItemsCache = require(mod)
        end
    end)
    return ItemsCache
end

function WashModule.GetItemRarity(item)
    if type(item) == "table" then
        if item.Rarity then return tostring(item.Rarity) end
        if item.rarity then return tostring(item.rarity) end
        if item.ItemData and item.ItemData.Rarity then return tostring(item.ItemData.Rarity) end
    end

    local itemName = type(item) == "table" and (item.Name or item.ItemName or item.Id) or tostring(item)
    local items = getItemsModule()
    if items and type(items) == "table" and items[itemName] then
        local data = items[itemName]
        if type(data) == "table" and data.Rarity then
            return tostring(data.Rarity)
        end
    end

    return "Common"
end

function WashModule.RunAutoWash(State)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local washEvents = events and events:FindFirstChild("Wash")
    if not washEvents then return end

    local getSlotState = washEvents:FindFirstChild("GetSlotState")
    local getWashableItems = washEvents:FindFirstChild("GetWashableItems")
    local startWash = washEvents:FindFirstChild("StartWash")
    local claimWashed = washEvents:FindFirstChild("ClaimWashedItem") or washEvents:FindFirstChild("CollectWash")

    if not getSlotState or not getWashableItems or not startWash then return end

    local ok, slotState = pcall(function() return getSlotState:InvokeServer() end)
    if ok and type(slotState) == "table" then
        for slotIndex, slotData in pairs(slotState) do
            if type(slotData) == "table" then
                local isDone = slotData.IsComplete or slotData.Status == "Complete" or slotData.Status == "Ready" or (slotData.EndTime and os.time() >= tonumber(slotData.EndTime or 0))
                if isDone and claimWashed then
                    pcall(function()
                        claimWashed:InvokeServer(slotIndex)
                    end)
                    task.wait(0.15)
                end
            end
        end
    end

    local ok2, refreshedSlots = pcall(function() return getSlotState:InvokeServer() end)
    if ok2 and type(refreshedSlots) == "table" then
        local ok3, washable = pcall(function() return getWashableItems:InvokeServer() end)
        if ok3 and type(washable) == "table" and #washable > 0 then
            local eligibleItems = {}
            for _, item in ipairs(washable) do
                local rarity = WashModule.GetItemRarity(item)
                if State.WashRarities == nil or State.WashRarities[rarity] == true then
                    table.insert(eligibleItems, item)
                end
            end

            local itemIdx = 1
            for slotIndex, slotData in pairs(refreshedSlots) do
                local isEmpty = false
                if slotData == nil or slotData == false then
                    isEmpty = true
                elseif type(slotData) == "table" then
                    isEmpty = slotData.IsEmpty or not slotData.Item or slotData.Status == "Empty" or slotData.Status == nil
                end

                if isEmpty and eligibleItems[itemIdx] then
                    local target = eligibleItems[itemIdx]
                    local targetId = (type(target) == "table" and (target.Id or target.ItemId or target.UUID or target.id)) or target
                    pcall(function()
                        startWash:InvokeServer(slotIndex, targetId)
                    end)
                    itemIdx = itemIdx + 1
                    task.wait(0.15)
                end
            end
        end
    end
end

function WashModule.StartAutoWashLoop(State)
    if washThread then
        pcall(function() task.cancel(washThread) end)
    end
    washThread = task.spawn(function()
        while State.AutoWash do
            pcall(function()
                WashModule.RunAutoWash(State)
            end)
            task.wait(3)
        end
    end)
end

function WashModule.StopAutoWashLoop()
    if washThread then
        pcall(function() task.cancel(washThread) end)
        washThread = nil
    end
end

return WashModule
