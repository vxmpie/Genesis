local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

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

function WashModule.RunCycle(State)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local washEvents = events and events:FindFirstChild("Wash")
    if not washEvents then return 5 end

    local getSlotState = washEvents:FindFirstChild("GetSlotState")
    local getWashableItems = washEvents:FindFirstChild("GetWashableItems")
    local startWash = washEvents:FindFirstChild("StartWash")
    local claimWashed = washEvents:FindFirstChild("ClaimWashedItem") or washEvents:FindFirstChild("CollectWash")

    if not getSlotState or not getWashableItems or not startWash then return 5 end

    local ok, slotState = pcall(function() return getSlotState:InvokeServer() end)
    local minSleep = 5

    if ok and type(slotState) == "table" then
        local now = os.time()
        for slotIndex, slotData in pairs(slotState) do
            if type(slotData) == "table" then
                local isDone = slotData.IsComplete or slotData.Status == "Complete" or slotData.Status == "Ready" or (slotData.EndTime and now >= tonumber(slotData.EndTime or 0))
                if isDone and claimWashed then
                    pcall(function() claimWashed:InvokeServer(slotIndex) end)
                    task.wait(0.1)
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
        local hasEmpty = false
        for _, sData in pairs(refreshedSlots) do
            if sData == nil or sData == false or (type(sData) == "table" and (sData.IsEmpty or not sData.Item or sData.Status == "Empty" or sData.Status == nil)) then
                hasEmpty = true
                break
            end
        end

        if hasEmpty then
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
                    local isEmpty = slotData == nil or slotData == false or (type(slotData) == "table" and (slotData.IsEmpty or not slotData.Item or slotData.Status == "Empty" or slotData.Status == nil))
                    if isEmpty and eligibleItems[itemIdx] then
                        local target = eligibleItems[itemIdx]
                        local targetId = (type(target) == "table" and (target.Id or target.ItemId or target.UUID or target.id)) or target
                        pcall(function() startWash:InvokeServer(slotIndex, targetId) end)
                        itemIdx = itemIdx + 1
                        task.wait(0.1)
                    end
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
