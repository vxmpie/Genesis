local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RewardsModule = {}
local loopThread = nil

function RewardsModule.Process(State)
    local events = ReplicatedStorage:FindFirstChild("Events")
    if not events then return end

    if State.AutoMuseum then
        local museumEvents = events:FindFirstChild("Museum")
        if museumEvents and museumEvents:FindFirstChild("Collect") then
            pcall(function()
                museumEvents.Collect:InvokeServer()
            end)
        end
    end

    if State.AutoCollections then
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

    if State.AutoDailyReward then
        local dailyEvents = events:FindFirstChild("DailyReward")
        if dailyEvents and dailyEvents:FindFirstChild("ClaimReward") then
            pcall(function() dailyEvents.ClaimReward:InvokeServer() end)
        end
    end

    if State.AutoLostFound then
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

function RewardsModule.StartLoop(State)
    if loopThread then
        pcall(function() task.cancel(loopThread) end)
    end

    loopThread = task.spawn(function()
        while true do
            if State.AutoMuseum or State.AutoCollections or State.AutoDailyReward or State.AutoLostFound then
                pcall(function() RewardsModule.Process(State) end)
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
