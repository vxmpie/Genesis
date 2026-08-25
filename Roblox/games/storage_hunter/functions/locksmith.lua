local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocksmithModule = {}
local loopThread = nil

function LocksmithModule.Process(State)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local locksmithEvents = events and events:FindFirstChild("Locksmith")
    if not locksmithEvents then return end

    local getSlotState = locksmithEvents:FindFirstChild("GetSlotState")
    local getLockable = locksmithEvents:FindFirstChild("GetLockableItems")
    local startLocksmith = locksmithEvents:FindFirstChild("StartLocksmith") or locksmithEvents:FindFirstChild("OpenSafe")
    local claimItem = locksmithEvents:FindFirstChild("ClaimItem")

    if State.AutoOpenSafes and locksmithEvents:FindFirstChild("PicklockInventorySafe") then
        pcall(function()
            locksmithEvents.PicklockInventorySafe:InvokeServer()
        end)
    end

    if not State.AutoLocksmith or not getSlotState then return end

    local ok, slotState = pcall(function() return getSlotState:InvokeServer() end)
    if ok and type(slotState) == "table" then
        for slotIdx, data in pairs(slotState) do
            if type(data) == "table" then
                local isDone = data.IsComplete or data.Status == "Complete" or data.Status == "Ready" or (data.EndTime and os.time() >= tonumber(data.EndTime or 0))
                if isDone and claimItem then
                    pcall(function() claimItem:InvokeServer(slotIdx) end)
                    task.wait(0.15)
                end
            end
        end
    end

    if getLockable and startLocksmith then
        local ok2, refreshed = pcall(function() return getSlotState:InvokeServer() end)
        if ok2 and type(refreshed) == "table" then
            local ok3, items = pcall(function() return getLockable:InvokeServer() end)
            if ok3 and type(items) == "table" and #items > 0 then
                local itemIdx = 1
                for slotIdx, data in pairs(refreshed) do
                    local isEmpty = data == nil or data == false or (type(data) == "table" and (data.IsEmpty or not data.Item or data.Status == "Empty" or data.Status == nil))
                    if isEmpty and items[itemIdx] then
                        local target = items[itemIdx]
                        local targetId = (type(target) == "table" and (target.Id or target.ItemId or target.UUID or target.id)) or target
                        pcall(function() startLocksmith:InvokeServer(slotIdx, targetId) end)
                        itemIdx = itemIdx + 1
                        task.wait(0.15)
                    end
                end
            end
        end
    end
end

function LocksmithModule.StartLoop(State)
    if loopThread then
        pcall(function() task.cancel(loopThread) end)
    end

    loopThread = task.spawn(function()
        while true do
            if State.AutoLocksmith or State.AutoOpenSafes then
                pcall(function() LocksmithModule.Process(State) end)
            end
            task.wait(3)
        end
    end)
end

function LocksmithModule.StopLoop()
    if loopThread then
        pcall(function() task.cancel(loopThread) end)
        loopThread = nil
    end
end

return LocksmithModule
