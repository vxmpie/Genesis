local GradingModule = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local RarityCache = {}
local gradingThread = nil

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

function GradingModule.GetItemRarity(itemEntry)
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

function GradingModule.IsRarityAllowed(rarityName, State)
    if not State or not State.GradingRarities then return true end
    local norm = normalizeRarity(rarityName)
    if State.GradingRarities[norm] ~= nil then
        return State.GradingRarities[norm] == true
    end
    for k, v in pairs(State.GradingRarities) do
        if normalizeRarity(k) == norm and v == true then
            return true
        end
    end
    return true
end

function GradingModule.ProcessGrading(State)
    if not State.AutoGrade then return end

    local events = ReplicatedStorage:FindFirstChild("Events")
    local gradingEvents = events and events:FindFirstChild("Grading")
    local vehicleEvents = events and events:FindFirstChild("Vehicles")
    if not gradingEvents then return end

    local getSlotState = gradingEvents:FindFirstChild("GetSlotState")
    local getGradableItems = gradingEvents:FindFirstChild("GetGradableItems")
    local startGrading = gradingEvents:FindFirstChild("StartGrading")
    local claimGraded = gradingEvents:FindFirstChild("ClaimGradedItem")
    local collectGrade = gradingEvents:FindFirstChild("CollectGrade")

    if not getSlotState or not startGrading then return end

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
                    if claimGraded then
                        pcall(function() claimGraded:InvokeServer(slotIdx) end)
                        pcall(function() claimGraded:InvokeServer(tostring(slotIdx)) end)
                    end
                    if collectGrade then
                        pcall(function() collectGrade:InvokeServer(slotIdx) end)
                        pcall(function() collectGrade:InvokeServer(tostring(slotIdx)) end)
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
        local flatItems = {}

        if getGradableItems then
            local ok3, rawGradable = pcall(function() return getGradableItems:InvokeServer() end)
            if ok3 and type(rawGradable) == "table" then
                local itemList = rawGradable.items or rawGradable
                if type(itemList) == "table" then
                    for _, itemEntry in pairs(itemList) do
                        table.insert(flatItems, itemEntry)
                    end
                end
            end
        end

        if State.GradeFromVehicle and vehicleEvents and vehicleEvents:FindFirstChild("GetVehicleItems") then
            pcall(function()
                local vehItems = vehicleEvents.GetVehicleItems:InvokeServer()
                if type(vehItems) == "table" then
                    local list = vehItems.items or vehItems
                    for _, itemEntry in pairs(list) do
                        table.insert(flatItems, itemEntry)
                    end
                end
            end)
        end

        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then
            for _, item in ipairs(backpack:GetChildren()) do
                local isSafe = string.find(string.lower(item.Name), "safe") ~= nil
                local itemData = RarityCache[item.Name]
                if isSafe or itemData then
                    table.insert(flatItems, {
                        Name = item.Name,
                        ItemId = item.Name,
                        guid = item:GetAttribute("GUID") or item:GetAttribute("UUID") or item.Name,
                        Rarity = itemData or "Rare"
                    })
                end
            end
        end

        local eligible = {}
        for _, itemEntry in ipairs(flatItems) do
            local rarity = GradingModule.GetItemRarity(itemEntry)
            if GradingModule.IsRarityAllowed(rarity, State) then
                table.insert(eligible, itemEntry)
            end
        end

        for i, slotIdx in ipairs(emptySlots) do
            local target = eligible[i]
            if target then
                local guid = target.guid or (type(target) == "table" and (target.UUID or target.Id or target.ItemId or target.id)) or target
                pcall(function() startGrading:InvokeServer(slotIdx, guid) end)
                pcall(function() startGrading:InvokeServer(tostring(slotIdx), guid) end)
                task.wait(0.1)
            end
        end
    end
end

function GradingModule.StartAutoGradeLoop(State)
    if gradingThread then
        pcall(function() task.cancel(gradingThread) end)
    end
    gradingThread = task.spawn(function()
        while State.AutoGrade do
            pcall(function()
                GradingModule.ProcessGrading(State)
            end)
            task.wait(2.5)
        end
    end)
end

function GradingModule.StopAutoGradeLoop()
    if gradingThread then
        pcall(function() task.cancel(gradingThread) end)
        gradingThread = nil
    end
end

return GradingModule
