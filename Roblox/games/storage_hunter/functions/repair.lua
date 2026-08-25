local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RepairModule = {}
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

function RepairModule.Process(StoreOrState)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local repairEvents = events and events:FindFirstChild("Repair")
    local wrenchEvents = events and events:FindFirstChild("WrenchShop")

    if getStateVal(StoreOrState, "AutoWrench", false) and wrenchEvents and wrenchEvents:FindFirstChild("RepairWonItem") then
        pcall(function()
            wrenchEvents.RepairWonItem:InvokeServer()
        end)
    end

    if not getStateVal(StoreOrState, "AutoRepair", false) or not repairEvents then return end

    local getSlotState = repairEvents:FindFirstChild("GetSlotState")
    local getRepairable = repairEvents:FindFirstChild("GetRepairableItems")
    local startRepair = repairEvents:FindFirstChild("StartRepair")
    local claimRepaired = repairEvents:FindFirstChild("ClaimRepairedItem") or repairEvents:FindFirstChild("CollectRepair")

    if not getSlotState or not getRepairable or not startRepair then return end

    local ok, slotState = pcall(function() return getSlotState:InvokeServer() end)
    if ok and type(slotState) == "table" then
        for slotIdx, data in pairs(slotState) do
            if type(data) == "table" then
                local isDone = data.IsComplete or data.Status == "Complete" or data.Status == "Ready" or (data.EndTime and os.time() >= tonumber(data.EndTime or 0))
                if isDone and claimRepaired then
                    pcall(function() claimRepaired:InvokeServer(slotIdx) end)
                    task.wait(0.15)
                end
            end
        end
    end

    local ok2, refreshed = pcall(function() return getSlotState:InvokeServer() end)
    if ok2 and type(refreshed) == "table" then
        local ok3, items = pcall(function() return getRepairable:InvokeServer() end)
        if ok3 and type(items) == "table" and #items > 0 then
            local itemIdx = 1
            for slotIdx, data in pairs(refreshed) do
                local isEmpty = data == nil or data == false or (type(data) == "table" and (data.IsEmpty or not data.Item or data.Status == "Empty" or data.Status == nil))
                if isEmpty and items[itemIdx] then
                    local target = items[itemIdx]
                    local targetId = (type(target) == "table" and (target.Id or target.ItemId or target.UUID or target.id)) or target
                    pcall(function() startRepair:InvokeServer(slotIdx, targetId) end)
                    itemIdx = itemIdx + 1
                    task.wait(0.15)
                end
            end
        end
    end
end

function RepairModule.StartLoop(StoreOrState)
    if loopThread then
        pcall(function() task.cancel(loopThread) end)
    end

    loopThread = task.spawn(function()
        while true do
            local autoRep = getStateVal(StoreOrState, "AutoRepair", false)
            local autoWr = getStateVal(StoreOrState, "AutoWrench", false)
            if autoRep or autoWr then
                pcall(function() RepairModule.Process(StoreOrState) end)
            end
            task.wait(3)
        end
    end)
end

function RepairModule.StopLoop()
    if loopThread then
        pcall(function() task.cancel(loopThread) end)
        loopThread = nil
    end
end

return RepairModule
