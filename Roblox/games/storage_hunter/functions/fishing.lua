local Fishing = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

function Fishing.Init(Config, DB)
    local activeReeling = false

    local function getEquippedRod()
        if LocalPlayer.Character then
            for _, item in ipairs(LocalPlayer.Character:GetChildren()) do
                if item:IsA("Tool") and string.find(string.lower(item.Name), "rod") then
                    return item
                end
            end
        end
        return nil
    end

    local function castRod(rod)
        if not rod then return end
        pcall(function()
            rod:Activate()
        end)
    end

    RunService.RenderStepped:Connect(function()
        if Config.Get("AutoReel", false) and not Config.Get("StopAllAutomation", false) then
            pcall(function()
                local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                if playerGui then
                    local fishGui = playerGui:FindFirstChild("FishingGui") or playerGui:FindFirstChild("FishingMinigame")
                    if fishGui and fishGui.Enabled then
                        local bar = fishGui:FindFirstChild("ReelBar", true) or fishGui:FindFirstChild("Tracker", true)
                        local target = fishGui:FindFirstChild("FishTarget", true) or fishGui:FindFirstChild("Fish", true)
                        if bar and target then
                            bar.Position = target.Position
                        end
                    end
                end
            end)
        end
    end)

    task.spawn(function()
        while task.wait(0.5) do
            if Config.Get("AutoFish", false) and not Config.Get("StopAllAutomation", false) then
                local rod = getEquippedRod()
                if not rod and Config.Get("AutoEquipRod", true) then
                    local backpack = LocalPlayer:FindFirstChild("Backpack")
                    if backpack then
                        for _, item in ipairs(backpack:GetChildren()) do
                            if item:IsA("Tool") and string.find(string.lower(item.Name), "rod") then
                                item.Parent = LocalPlayer.Character
                                rod = item
                                break
                            end
                        end
                    end
                end

                if rod then
                    castRod(rod)
                end
            end
        end
    end)
end

return Fishing
