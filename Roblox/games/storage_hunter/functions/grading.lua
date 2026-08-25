local GradingModule = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local gradingThread = nil

local SAFE_IDS = {
    ["117"] = "Junk Safe",
    ["354"] = "Wooden Safe",
    ["355"] = "Metal Safe",
    ["356"] = "Code Safe",
    ["357"] = "Diamond Safe",
    ["358"] = "Diamond Vault"
}

local SAFE_RARITIES = {
    ["Junk Safe"] = "Epic",
    ["Wooden Safe"] = "Rare",
    ["Metal Safe"] = "Epic",
    ["Code Safe"] = "Epic",
    ["Diamond Safe"] = "Epic",
    ["Diamond Vault"] = "Legendary"
}

function GradingModule.IsSafe(itemEntry)
    if not itemEntry then return false end
    if typeof(itemEntry) == "Instance" then
        local name = string.lower(itemEntry.Name)
        return string.find(name, "safe") ~= nil or string.find(name, "vault") ~= nil
    end

    if type(itemEntry) == "table" then
        local data = itemEntry.data or itemEntry
        local name = data.Name or data.name or ""
        local lowerName = string.lower(tostring(name))
        if string.find(lowerName, "safe") ~= nil or string.find(lowerName, "vault") ~= nil then
            return true
        end

        local id = tostring(data.ItemId or data.itemId or data.Id or data.id or "")
        if SAFE_IDS[id] then
            return true
        end

        if data.SafeId ~= nil then
            return true
        end
    end

    if type(itemEntry) == "string" then
        local lower = string.lower(itemEntry)
        if string.find(lower, "safe") ~= nil or string.find(lower, "vault") ~= nil then
            return true
        end
        if SAFE_IDS[itemEntry] then
            return true
        end
    end

    return false
end

function GradingModule.GetSafeName(itemEntry)
    if typeof(itemEntry) == "Instance" then
        return itemEntry.Name
    end
    if type(itemEntry) == "table" then
        local data = itemEntry.data or itemEntry
        if data.Name then return data.Name end
        if data.name then return data.name end
        local id = tostring(data.ItemId or data.itemId or data.Id or data.id or "")
        if SAFE_IDS[id] then return SAFE_IDS[id] end
    end
    if type(itemEntry) == "string" then
        if SAFE_IDS[itemEntry] then return SAFE_IDS[itemEntry] end
        return itemEntry
    end
    return "Unknown Safe"
end

function GradingModule.IsSafeAllowed(safeName, State)
    if not State or not State.AllowedSafes then return true end
    for k, v in pairs(State.AllowedSafes) do
        if string.find(string.lower(safeName), string.lower(k)) and v == true then
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
        local rawSafes = {}

        if getGradableItems then
            local ok3, rawGradable = pcall(function() return getGradableItems:InvokeServer() end)
            if ok3 and type(rawGradable) == "table" then
                local itemList = rawGradable.items or rawGradable
                if type(itemList) == "table" then
                    for _, itemEntry in pairs(itemList) do
                        if GradingModule.IsSafe(itemEntry) then
                            table.insert(rawSafes, itemEntry)
                        end
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
                        if GradingModule.IsSafe(itemEntry) then
                            table.insert(rawSafes, itemEntry)
                        end
                    end
                end
            end)
        end

        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then
            for _, item in ipairs(backpack:GetChildren()) do
                if GradingModule.IsSafe(item) then
                    table.insert(rawSafes, {
                        Name = item.Name,
                        ItemId = item.Name,
                        guid = item:GetAttribute("GUID") or item:GetAttribute("UUID") or item.Name
                    })
                end
            end
        end

        local eligible = {}
        for _, safeEntry in ipairs(rawSafes) do
            local safeName = GradingModule.GetSafeName(safeEntry)
            if GradingModule.IsSafeAllowed(safeName, State) then
                table.insert(eligible, safeEntry)
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
