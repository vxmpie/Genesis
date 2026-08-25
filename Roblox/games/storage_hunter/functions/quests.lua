local Quests = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

Quests.Status = {
    Accepted = 0,
    Completed = 0,
    RewardsReady = 0,
    State = "idle",
    ActiveQuests = {},
    Progress = {}
}

local function getEventsFolder()
    return ReplicatedStorage:FindFirstChild("Events")
end

function Quests.Init(Config, DB)
    task.spawn(function()
        while task.wait(2) do
            if not Config.Get("StopAllAutomation", false) then
                local events = getEventsFolder()
                if events then
                    local questFolder = events:FindFirstChild("Quest") or events:FindFirstChild("Quests")
                    if questFolder then
                        if Config.Get("AutoClaimQuestRewards", true) then
                            pcall(function()
                                local claim = questFolder:FindFirstChild("ClaimReward")
                                if claim then
                                    claim:InvokeServer()
                                    Quests.Status.Completed = Quests.Status.Completed + 1
                                end
                            end)
                        end

                        if Config.Get("AutoGetQuests", false) then
                            pcall(function()
                                local accept = questFolder:FindFirstChild("AcceptQuest")
                                if accept then
                                    accept:InvokeServer()
                                    Quests.Status.Accepted = Quests.Status.Accepted + 1
                                end
                            end)
                        end
                    end

                    if Config.Get("AutoInstallReactorParts", false) then
                        pcall(function()
                            local special = events:FindFirstChild("SpecialEvent") or events:FindFirstChild("PowerPlant")
                            local install = special and (special:FindFirstChild("InstallPowerPlantPart") or special:FindFirstChild("InstallPart"))
                            if install then
                                for tier = 1, 5 do
                                    install:InvokeServer(tier)
                                end
                            end
                            if Config.Get("AutoFeedUranium", false) then
                                local feed = special and special:FindFirstChild("FeedUranium")
                                if feed then
                                    feed:InvokeServer()
                                end
                            end
                        end)
                    end
                end
            end
        end
    end)
end

return Quests
