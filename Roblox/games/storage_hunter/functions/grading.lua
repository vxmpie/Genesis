local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GradingModule = {}
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

function GradingModule.Process(StoreOrState)
    if not getStateVal(StoreOrState, "AutoGrade", false) then return end

    local events = ReplicatedStorage:FindFirstChild("Events")
    local gradingEvents = events and events:FindFirstChild("Grading")
    if not gradingEvents then return end

    local getSlotState = gradingEvents:FindFirstChild("GetSlotState")
    local getGradable = gradingEvents:FindFirstChild("GetGradableItems")
    local startGrading = gradingEvents:FindFirstChild("StartGrading")
    local claimGrade = gradingEvents:FindFirstChild("ClaimGradedItem") or gradingEvents:FindFirstChild("CollectGrade")

    if not getSlotState or not getGradable or not startGrading then return end

    local ok, slotState = pcall(function() return getSlotState:InvokeServer() end)
    if ok and type(slotState) == "table" then
        for slotIdx, data in pairs(slotState) do
            if type(data) == "table" then
                local isDone = data.IsComplete or data.Status == "Complete" or data.Status == "Ready" or (data.EndTime and os.time() >= tonumber(data.EndTime or 0))
                if isDone and claimGrade then
                    pcall(function() claimGrade:InvokeServer(slotIdx) end)
                    task.wait(0.15)
                end
            end
        end
    end

    local ok2, refreshed = pcall(function() return getSlotState:InvokeServer() end)
    if ok2 and type(refreshed) == "table" then
        local ok3, items = pcall(function() return getGradable:InvokeServer() end)
        if ok3 and type(items) == "table" and #items > 0 then
            local itemIdx = 1
            for slotIdx, data in pairs(refreshed) do
                local isEmpty = data == nil or data == false or (type(data) == "table" and (data.IsEmpty or not data.Item or data.Status == "Empty" or data.Status == nil))
                if isEmpty and items[itemIdx] then
                    local target = items[itemIdx]
                    local targetId = (type(target) == "table" and (target.Id or target.ItemId or target.UUID or target.id)) or target
                    pcall(function() startGrading:InvokeServer(slotIdx, targetId) end)
                    itemIdx = itemIdx + 1
                    task.wait(0.15)
                end
            end
        end
    end
end

function GradingModule.StartLoop(StoreOrState)
    if loopThread then
        pcall(function() task.cancel(loopThread) end)
    end

    loopThread = task.spawn(function()
        while true do
            if getStateVal(StoreOrState, "AutoGrade", false) then
                pcall(function() GradingModule.Process(StoreOrState) end)
            end
            task.wait(3)
        end
    end)
end

function GradingModule.StopLoop()
    if loopThread then
        pcall(function() task.cancel(loopThread) end)
        loopThread = nil
    end
end

return GradingModule
