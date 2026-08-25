local Processing = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

function Processing.Init(Config, DB)
    local eventsFolder = ReplicatedStorage:WaitForChild("Events")
    local washEvents = eventsFolder:FindFirstChild("Wash")
    local repairEvents = eventsFolder:FindFirstChild("Repair")
    local gradingEvents = eventsFolder:FindFirstChild("Grading")
    local timeCapsuleEvents = eventsFolder:FindFirstChild("TimeCapsule")

    local function runPipeline()
        pcall(function()
            if Config.Get("AutoCollectFinishedProcessing", true) then
                if washEvents and washEvents:FindFirstChild("ClaimWashedItem") then
                    washEvents.ClaimWashedItem:FireServer()
                end
                if repairEvents and repairEvents:FindFirstChild("ClaimRepairedItem") then
                    repairEvents.ClaimRepairedItem:FireServer()
                end
                if gradingEvents and gradingEvents:FindFirstChild("ClaimGradedItem") then
                    gradingEvents.ClaimGradedItem:FireServer()
                end
                if timeCapsuleEvents and timeCapsuleEvents:FindFirstChild("ClaimCapsule") then
                    timeCapsuleEvents.ClaimCapsule:FireServer()
                end
            end

            local backpack = LocalPlayer:FindFirstChild("Backpack")
            if backpack then
                for _, item in ipairs(backpack:GetChildren()) do
                    local itemData = DB.GetItem(item.Name)
                    local basePrice = itemData and itemData.Price or 0
                    local rarity = itemData and itemData.Rarity or "Junk"
                    local rMult = DB.GetRarityMultiplier(rarity)

                    if Config.Get("AutoWashItems", false) and washEvents and washEvents:FindFirstChild("StartWash") then
                        local minVal = tonumber(Config.Get("WashMinValue", 0)) or 0
                        if basePrice >= minVal then
                            washEvents.StartWash:FireServer(item)
                        end
                    end

                    if Config.Get("AutoRepairItems", false) and repairEvents and repairEvents:FindFirstChild("StartRepair") then
                        local minVal = tonumber(Config.Get("RepairMinValue", 0)) or 0
                        if basePrice >= minVal then
                            repairEvents.StartRepair:FireServer(item)
                        end
                    end

                    if Config.Get("AutoGradeItems", false) and gradingEvents and gradingEvents:FindFirstChild("StartGrading") then
                        local minVal = tonumber(Config.Get("GradeMinValue", 0)) or 0
                        if basePrice >= minVal and rMult >= 2.0 then
                            gradingEvents.StartGrading:FireServer(item)
                        end
                    end
                end
            end
        end)
    end

    task.spawn(function()
        while task.wait(1) do
            if not Config.Get("StopAllAutomation", false) then
                runPipeline()
            end
        end
    end)
end

return Processing
