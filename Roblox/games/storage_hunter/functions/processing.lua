local Processing = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local ItemsDB = nil

Processing.Status = {
    Started = 0,
    Claimed = 0,
    Capsuled = 0,
    Certified = 0,
    UnlockedSlots = 0,
    SpedUpSlots = 0
}

local function getEventsFolder()
    return ReplicatedStorage:FindFirstChild("Events")
end

function Processing.Init(Config, DB)
    ItemsDB = DB
    task.spawn(function()
        while task.wait(1) do
            if not Config.Get("StopAllAutomation", false) then
                local events = getEventsFolder()
                if events then
                    if Config.Get("AutoWashItems", false) then
                        pcall(function()
                            local wash = events:FindFirstChild("Wash")
                            if wash then
                                local startWash = wash:FindFirstChild("StartWash")
                                local claimWash = wash:FindFirstChild("ClaimWashedItem")
                                local getSlots = wash:FindFirstChild("GetSlotState")

                                if Config.Get("AutoCollectFinishedProcessing", true) and claimWash then
                                    for slot = 1, 5 do
                                        claimWash:InvokeServer(slot)
                                    end
                                end

                                if startWash and getSlots then
                                    local slotData = getSlots:InvokeServer()
                                    if typeof(slotData) == "table" then
                                        for slotIndex, slot in pairs(slotData) do
                                            if slot.Occupied == false or slot.State == "Empty" then
                                                startWash:InvokeServer(slotIndex)
                                                Processing.Status.Started = Processing.Status.Started + 1
                                            end
                                        end
                                    end
                                end
                            end
                        end)
                    end

                    if Config.Get("AutoRepairItems", false) then
                        pcall(function()
                            local repair = events:FindFirstChild("Repair")
                            if repair then
                                local startRepair = repair:FindFirstChild("StartRepair")
                                local claimRepair = repair:FindFirstChild("ClaimRepairedItem")
                                if Config.Get("AutoCollectFinishedProcessing", true) and claimRepair then
                                    for slot = 1, 5 do
                                        claimRepair:InvokeServer(slot)
                                    end
                                end
                            end
                        end)
                    end

                    if Config.Get("AutoGradeItems", false) then
                        pcall(function()
                            local grading = events:FindFirstChild("Grading")
                            if grading then
                                local startGrade = grading:FindFirstChild("StartGrading")
                                local claimGrade = grading:FindFirstChild("ClaimGradedItem")
                                if Config.Get("AutoCollectFinishedProcessing", true) and claimGrade then
                                    for slot = 1, 5 do
                                        claimGrade:InvokeServer(slot)
                                    end
                                end
                            end
                        end)
                    end

                    if Config.Get("AutoTimeCapsule", false) then
                        pcall(function()
                            local capsule = events:FindFirstChild("TimeCapsule")
                            if capsule then
                                local claimCapsule = capsule:FindFirstChild("ClaimCapsule")
                                if Config.Get("AutoCollectFinishedProcessing", true) and claimCapsule then
                                    for slot = 1, 3 do
                                        claimCapsule:InvokeServer(slot)
                                    end
                                end
                            end
                        end)
                    end

                    if Config.Get("AutoAuthenticateAccessories", false) then
                        pcall(function()
                            local auth = events:FindFirstChild("Authentication")
                            if auth then
                                local authAccessory = auth:FindFirstChild("AuthenticateAccessory")
                                if authAccessory then
                                    authAccessory:InvokeServer()
                                    Processing.Status.Certified = Processing.Status.Certified + 1
                                end
                            end
                        end)
                    end
                end
            end
        end
    end)
end

return Processing
