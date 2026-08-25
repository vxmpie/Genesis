local Fishing = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

Fishing.Status = {
    Casts = 0,
    Caught = 0,
    State = "idle"
}

local function getFishingFolder()
    local events = ReplicatedStorage:FindFirstChild("Events")
    return events and events:FindFirstChild("Fishing")
end

function Fishing.Init(Config, DB)
    task.spawn(function()
        while task.wait(0.5) do
            if not Config.Get("StopAllAutomation", false) and Config.Get("AutoFish", false) then
                pcall(function()
                    local fishingEvents = getFishingFolder()
                    if fishingEvents then
                        local castEvent = fishingEvents:FindFirstChild("CastLine") or fishingEvents:FindFirstChild("StartFishing")
                        local reelEvent = fishingEvents:FindFirstChild("ReelLine") or fishingEvents:FindFirstChild("CompleteFishing")

                        if castEvent then
                            castEvent:FireServer(Config.Get("CastPosition", "Randomise"))
                            Fishing.Status.Casts = Fishing.Status.Casts + 1
                            Fishing.Status.State = "fishing"
                        end

                        if Config.Get("AutoReel", false) and reelEvent then
                            task.wait(Config.Get("SpeedUpFishing", false) and 0.5 or 1.5)
                            reelEvent:FireServer(true)
                            Fishing.Status.Caught = Fishing.Status.Caught + 1
                            Fishing.Status.State = "caught"
                        end
                    end
                end)
            end
        end
    end)
end

return Fishing
