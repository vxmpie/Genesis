local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RewardsModule = {}
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

function RewardsModule.Process(StoreOrState)
    local events = ReplicatedStorage:FindFirstChild("Events")
    if not events then return end

    if getStateVal(StoreOrState, "AutoMuseum", false) then
        local museumEvents = events:FindFirstChild("Museum")
        if museumEvents and museumEvents:FindFirstChild("Collect") then
            pcall(function()
                museumEvents.Collect:InvokeServer()
            end)
        end
    end

    if getStateVal(StoreOrState, "AutoCollections", false) then
        local collEvents = events:FindFirstChild("Collections")
        if collEvents then
            if collEvents:FindFirstChild("ClaimCollectionReward") then
                pcall(function() collEvents.ClaimCollectionReward:InvokeServer() end)
            end
            if collEvents:FindFirstChild("ClaimMilestoneReward") then
                pcall(function() collEvents.ClaimMilestoneReward:InvokeServer() end)
            end
            if collEvents:FindFirstChild("ClaimTierReward") then
                pcall(function() collEvents.ClaimTierReward:InvokeServer() end)
            end
        end
    end

    if getStateVal(StoreOrState, "AutoDailyReward", false) then
        local dailyEvents = events:FindFirstChild("DailyReward")
        if dailyEvents and dailyEvents:FindFirstChild("ClaimReward") then
            pcall(function() dailyEvents.ClaimReward:InvokeServer() end)
        end
    end

    if getStateVal(StoreOrState, "AutoLostFound", false) then
        local uiEvents = events:FindFirstChild("UI")
        if uiEvents and uiEvents:FindFirstChild("GetLostItems") and uiEvents:FindFirstChild("ClaimLostItem") then
            for _, area in ipairs({"Junk Yard", "Jurassic", "Business Bay", "Farmyard", "Power Plant"}) do
                pcall(function()
                    local lost = uiEvents.GetLostItems:InvokeServer(area)
                    if lost and type(lost) == "table" then
                        for idx, item in pairs(lost) do
                            uiEvents.ClaimLostItem:InvokeServer(area, idx)
                            task.wait(0.1)
                        end
                    end
                end)
            end
        end
    end
end

function RewardsModule.StartLoop(StoreOrState)
    if loopThread then
        pcall(function() task.cancel(loopThread) end)
    end

    loopThread = task.spawn(function()
        while true do
            local autoMus = getStateVal(StoreOrState, "AutoMuseum", false)
            local autoCol = getStateVal(StoreOrState, "AutoCollections", false)
            local autoDaily = getStateVal(StoreOrState, "AutoDailyReward", false)
            local autoLost = getStateVal(StoreOrState, "AutoLostFound", false)

            if autoMus or autoCol or autoDaily or autoLost then
                pcall(function() RewardsModule.Process(StoreOrState) end)
            end
            task.wait(5)
        end
    end)
end

function RewardsModule.StopLoop()
    if loopThread then
        pcall(function() task.cancel(loopThread) end)
        loopThread = nil
    end
end

return RewardsModule
