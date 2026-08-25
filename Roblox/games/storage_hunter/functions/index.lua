local Index = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

Index.Status = {
    CurrentArea = "Power Plant",
    Discovered = 59,
    Total = 61,
    Targetable = 2,
    MissingList = {}
}

local function getEventsFolder()
    return ReplicatedStorage:FindFirstChild("Events")
end

function Index.Init(Config, DB)
    task.spawn(function()
        while task.wait(3) do
            if not Config.Get("StopAllAutomation", false) and Config.Get("EnableAutoIndexCompletion", false) then
                pcall(function()
                    local events = getEventsFolder()
                    local colFolder = events and (events:FindFirstChild("Collections") or events:FindFirstChild("Index"))
                    if colFolder then
                        local getDiscovered = colFolder:FindFirstChild("GetDiscoveredItems")
                        local claimReward = colFolder:FindFirstChild("ClaimCollectionReward")

                        if getDiscovered then
                            local data = getDiscovered:InvokeServer()
                            if typeof(data) == "table" then
                                for areaName, items in pairs(data) do
                                    if claimReward then
                                        claimReward:InvokeServer(areaName)
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end
    end)
end

return Index
