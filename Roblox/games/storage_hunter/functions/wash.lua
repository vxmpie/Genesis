local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WashModule = {}
local washThread = nil
local RarityCache = {}

local function buildRarityCache()
    pcall(function()
        local mod = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Items")
        if mod then
            local items = require(mod)
            if type(items) == "table" then
                for name, data in pairs(items) do
                    if type(data) == "table" and data.Rarity then
                        RarityCache[name] = tostring(data.Rarity)
                    end
                end
            end
        end
    end)
end

buildRarityCache()

function WashModule.GetItemRarity(item)
    if type(item) == "table" then
        if item.Rarity then return tostring(item.Rarity) end
        if item.rarity then return tostring(item.rarity) end
        if item.ItemData and item.ItemData.Rarity then return tostring(item.ItemData.Rarity) end
    end

    local itemName = type(item) == "table" and (item.Name or item.ItemName or item.Id) or tostring(item)
    return RarityCache[itemName] or "Common"
end

local function extractItemId(target)
    if type(target) == "table" then
        return target.UUID or target.ItemId or target.Id or target.id or target.Name or target
    end
    return target
end

function WashModule.RunCycle(State)
    if not State.AutoWash then return 5 end

    local events = ReplicatedStorage:FindFirstChild("Events")
    local washEvents = events and events:FindFirstChild("Wash")
    if not washEvents then return 5 end

    local getSlotState = washEvents:FindFirstChild("GetSlotState")
    local getWashableItems = washEvents:FindFirstChild("GetWashableItems")
    local startWash = washEvents:FindFirstChild("StartWash")
    local claimWashed = washEvents:FindFirstChild("ClaimWashedItem")
    local collectWash = washEvents:FindFirstChild("CollectWash")

    if not getSlotState or not getWashableItems or not startWash then return 5 end

    local ok, slotState = pcall(function() return getSlotState:InvokeServer() end)
    local minSleep = 5

    if ok and type(slotState) == "table" then
        local now = os.time()
        for slotIndex, slotData in pairs(slotState) do
            if type(slotData) == "table" then
                local isDone = slotData.IsComplete or slotData.Status == "Complete" or slotData.Status == "Ready" or (slotData.EndTime and now >= tonumber(slotData.EndTime or 0))
                if isDone then
                    if claimWashed then
                        pcall(function() claimWashed:InvokeServer(slotIndex) end)
                        pcall(function() claimWashed:InvokeServer(tonumber(slotIndex) or slotIndex) end)
                    end
                    if collectWash then
                        pcall(function() collectWash:InvokeServer(slotIndex) end)
                    end
                    task.wait(0.15)
                elseif slotData.EndTime then
                    local rem = tonumber(slotData.EndTime) - now
                    if rem > 0 and rem < minSleep then
                        minSleep = rem
                    end
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
                    local targetId = extractItemId(target)
                    pcall(function() startWash:InvokeServer(slotIndex, targetId) end)
                    pcall(function() startWash:InvokeServer(tonumber(slotIndex) or slotIndex, targetId) end)
                    pcall(function() startWash:InvokeServer(slotIndex, target) end)
                    itemIdx = itemIdx + 1
                    task.wait(0.2)
                end
            end
        end
    end

    return math.clamp(minSleep, 1, 5)
end

function WashModule.StartAutoWashLoop(State)
    if washThread then
        pcall(function() task.cancel(washThread) end)
    end
    washThread = task.spawn(function()
        while State.AutoWash do
            local nextSleep = 5
            pcall(function()
                nextSleep = WashModule.RunCycle(State)
            end)
            task.wait(nextSleep)
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
