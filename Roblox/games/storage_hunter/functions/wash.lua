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
                        if data.ItemId then
                            RarityCache[tostring(data.ItemId)] = tostring(data.Rarity)
                        end
                        if data.Id then
                            RarityCache[tostring(data.Id)] = tostring(data.Rarity)
                        end
                    end
                end
            end
        end
    end)
end

buildRarityCache()

function WashModule.GetItemRarity(itemEntry)
    if type(itemEntry) == "table" then
        local data = itemEntry.data or itemEntry
        if data.Rarity then return tostring(data.Rarity) end
        if data.rarity then return tostring(data.rarity) end
        if data.Name and RarityCache[data.Name] then return RarityCache[data.Name] end
        if data.ItemId and RarityCache[tostring(data.ItemId)] then return RarityCache[tostring(data.ItemId)] end
    end
    if type(itemEntry) == "string" and RarityCache[itemEntry] then
        return RarityCache[itemEntry]
    end
    return "Common"
end

function WashModule.ProcessWash(State)
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

    local ok1, rawSlotState = pcall(function() return getSlotState:InvokeServer() end)
    if not ok1 or type(rawSlotState) ~= "table" then return 5 end

    local unlockedCount = rawSlotState.unlockedCount or 1
    local activeSlots = rawSlotState.slots or {}
    local now = os.time()
    local minSleep = 5

    for slotIdx = 1, unlockedCount do
        local slotData = activeSlots[slotIdx] or activeSlots[tostring(slotIdx)]
        if slotData and type(slotData) == "table" then
            local isDone = slotData.IsComplete or slotData.Status == "Complete" or slotData.Status == "Ready" or (slotData.EndTime and now >= tonumber(slotData.EndTime or 0))
            if isDone then
                task.spawn(function()
                    if claimWashed then
                        pcall(function() claimWashed:InvokeServer(slotIdx) end)
                    end
                    if collectWash then
                        pcall(function() collectWash:InvokeServer(slotIdx) end)
                    end
                end)
            elseif slotData.EndTime then
                local rem = tonumber(slotData.EndTime) - now
                if rem > 0 and rem < minSleep then
                    minSleep = rem
                end
            end
        end
    end

    local ok2, refreshed = pcall(function() return getSlotState:InvokeServer() end)
    local currentSlots = (ok2 and type(refreshed) == "table" and refreshed.slots) or activeSlots

    local emptySlots = {}
    for slotIdx = 1, unlockedCount do
        local sData = currentSlots[slotIdx] or currentSlots[tostring(slotIdx)]
        if sData == nil or sData == false or (type(sData) == "table" and (sData.IsEmpty or not sData.Item or sData.Status == "Empty" or sData.Status == nil)) then
            table.insert(emptySlots, slotIdx)
        end
    end

    if #emptySlots > 0 then
        local ok3, rawWashable = pcall(function() return getWashableItems:InvokeServer() end)
        if ok3 and type(rawWashable) == "table" then
            local itemList = rawWashable.items or rawWashable
            if type(itemList) == "table" and #itemList > 0 then
                local eligible = {}
                for _, itemEntry in ipairs(itemList) do
                    local rarity = WashModule.GetItemRarity(itemEntry)
                    if State.WashRarities == nil or State.WashRarities[rarity] == true then
                        table.insert(eligible, itemEntry)
                    end
                end

                for i, slotIdx in ipairs(emptySlots) do
                    local target = eligible[i]
                    if target then
                        local guid = target.guid or (type(target) == "table" and (target.UUID or target.Id or target.ItemId or target.id)) or target
                        task.spawn(function()
                            pcall(function() startWash:InvokeServer(slotIdx, guid) end)
                            pcall(function() startWash:InvokeServer(tostring(slotIdx), guid) end)
                        end)
                    end
                end
            end
        end
    end

    return math.clamp(minSleep, 1, 5)
end

function WashModule.QuickWash(State)
    if not State.AutoWash then return end
    task.spawn(function()
        WashModule.ProcessWash(State)
    end)
end

function WashModule.StartAutoWashLoop(State)
    if washThread then
        pcall(function() task.cancel(washThread) end)
    end
    washThread = task.spawn(function()
        while State.AutoWash do
            local nextSleep = 5
            pcall(function()
                nextSleep = WashModule.ProcessWash(State)
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
