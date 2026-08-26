local WashModule = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RarityCache = {}
local washThread = nil

local function normalizeRarity(rarity)
    if not rarity then return "Common" end
    local s = string.lower(tostring(rarity))
    if string.find(s, "exclusive") then return "Exclusive" end
    if string.find(s, "lost") then return "Lost" end
    if string.find(s, "myth") then return "Mythical" end
    if string.find(s, "legend") then return "Legendary" end
    if string.find(s, "epic") then return "Epic" end
    if string.find(s, "rare") then return "Rare" end
    if string.find(s, "uncommon") then return "Uncommon" end
    return "Common"
end

local function buildRarityCache()
    pcall(function()
        local mod = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Items")
        if mod then
            local items = require(mod)
            if type(items) == "table" then
                local list = items.Items or items
                for k, data in pairs(list) do
                    if type(data) == "table" then
                        local rarityVal = data.Rarity or data.rarity or data.Tier or data.tier
                        if rarityVal then
                            local rNorm = normalizeRarity(rarityVal)
                            RarityCache[tostring(k)] = rNorm
                            if data.Name then RarityCache[tostring(data.Name)] = rNorm end
                            if data.name then RarityCache[tostring(data.name)] = rNorm end
                            if data.ItemId then RarityCache[tostring(data.ItemId)] = rNorm end
                            if data.itemId then RarityCache[tostring(data.itemId)] = rNorm end
                            if data.Id then RarityCache[tostring(data.Id)] = rNorm end
                            if data.id then RarityCache[tostring(data.id)] = rNorm end
                        end
                    elseif type(data) == "string" then
                        RarityCache[tostring(k)] = normalizeRarity(data)
                    end
                end
            end
        end
    end)
end

buildRarityCache()

function WashModule.GetItemRarity(itemEntry)
    if next(RarityCache) == nil then
        buildRarityCache()
    end

    if type(itemEntry) == "table" then
        local data = itemEntry.data or itemEntry
        local directRarity = data.Rarity or data.rarity or data.Tier or data.tier
        if directRarity then
            return normalizeRarity(directRarity)
        end

        if data.Name and RarityCache[tostring(data.Name)] then return RarityCache[tostring(data.Name)] end
        if data.ItemId and RarityCache[tostring(data.ItemId)] then return RarityCache[tostring(data.ItemId)] end
        if data.Id and RarityCache[tostring(data.Id)] then return RarityCache[tostring(data.Id)] end
        if data.id and RarityCache[tostring(data.id)] then return RarityCache[tostring(data.id)] end
    end
    if type(itemEntry) == "string" and RarityCache[itemEntry] then
        return RarityCache[itemEntry]
    end
    return "Common"
end

function WashModule.IsRarityAllowed(rarityName, State)
    if not State or not State.WashRarities then return true end
    local norm = normalizeRarity(rarityName)
    if State.WashRarities[norm] ~= nil then
        return (State.WashRarities[norm] == true)
    end
    for k, v in pairs(State.WashRarities) do
        if normalizeRarity(k) == norm then
            return (v == true)
        end
    end
    return true
end

function WashModule.ProcessWash(State)
    if not State.AutoWash then return end

    local events = ReplicatedStorage:FindFirstChild("Events")
    local washEvents = events and events:FindFirstChild("Wash")
    if not washEvents then return end

    local getSlotState = washEvents:FindFirstChild("GetSlotState")
    local getWashableItems = washEvents:FindFirstChild("GetWashableItems")
    local startWash = washEvents:FindFirstChild("StartWash")
    local claimWashed = washEvents:FindFirstChild("ClaimWashedItem")
    local collectWash = washEvents:FindFirstChild("CollectWash")

    if not getSlotState or not getWashableItems or not startWash then return end

    local ok1, rawSlotState = pcall(function() return getSlotState:InvokeServer() end)
    if not ok1 or type(rawSlotState) ~= "table" then return end

    local unlockedCount = tonumber(rawSlotState.unlockedCount) or 3
    local activeSlots = rawSlotState.slots or {}
    local now = os.time()

    for slotIdx = 1, unlockedCount do
        local slotData = activeSlots[slotIdx] or activeSlots[tostring(slotIdx)]
        if slotData and type(slotData) == "table" and (slotData.ItemGUID or slotData.StartTime or slotData.Duration or slotData.ItemData) then
            local isDone = false
            if slotData.IsComplete or slotData.Status == "Complete" or slotData.Status == "Ready" then
                isDone = true
            elseif slotData.StartTime and slotData.Duration then
                local endTime = tonumber(slotData.StartTime) + tonumber(slotData.Duration)
                if now >= endTime then
                    isDone = true
                end
            elseif slotData.EndTime then
                if now >= tonumber(slotData.EndTime) then
                    isDone = true
                end
            end

            if isDone then
                task.spawn(function()
                    if claimWashed then
                        pcall(function() claimWashed:InvokeServer(slotIdx) end)
                        pcall(function() claimWashed:InvokeServer(tostring(slotIdx)) end)
                    end
                    if collectWash then
                        pcall(function() collectWash:InvokeServer(slotIdx) end)
                        pcall(function() collectWash:InvokeServer(tostring(slotIdx)) end)
                    end
                end)
            end
        end
    end

    local ok2, refreshed = pcall(function() return getSlotState:InvokeServer() end)
    local currentSlots = (ok2 and type(refreshed) == "table" and refreshed.slots) or activeSlots

    local emptySlots = {}
    for slotIdx = 1, unlockedCount do
        local sData = currentSlots[slotIdx] or currentSlots[tostring(slotIdx)]
        local isOccupied = sData ~= nil and sData ~= false and type(sData) == "table" and (sData.ItemGUID ~= nil or sData.StartTime ~= nil or sData.ItemData ~= nil)
        if not isOccupied then
            table.insert(emptySlots, slotIdx)
        end
    end

    if #emptySlots > 0 then
        local ok3, rawWashable = pcall(function() return getWashableItems:InvokeServer() end)
        if ok3 and type(rawWashable) == "table" then
            local itemList = rawWashable.items or rawWashable
            if type(itemList) == "table" then
                local flatItems = {}
                for _, itemEntry in pairs(itemList) do
                    table.insert(flatItems, itemEntry)
                end

                local eligible = {}
                for _, itemEntry in ipairs(flatItems) do
                    local rarity = WashModule.GetItemRarity(itemEntry)
                    if WashModule.IsRarityAllowed(rarity, State) then
                        table.insert(eligible, itemEntry)
                    end
                end

                for i, slotIdx in ipairs(emptySlots) do
                    local target = eligible[i]
                    if target then
                        local guid = target.guid or (type(target) == "table" and (target.UUID or target.Id or target.ItemId or target.id)) or target
                        pcall(function() startWash:InvokeServer(slotIdx, guid) end)
                        pcall(function() startWash:InvokeServer(tostring(slotIdx), guid) end)
                        task.wait(0.1)
                    end
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
                WashModule.ProcessWash(State)
            end)
            task.wait(2.0)
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
