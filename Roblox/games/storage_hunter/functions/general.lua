local General = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

function General.Init(Config)
    task.spawn(function()
        while task.wait(2) do
            if Config.Get("StopAllAutomation", false) then
                task.wait(1)
            else
                if Config.Get("AutoPlay", true) then
                    pcall(function()
                        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                        if playerGui then
                            for _, gui in ipairs(playerGui:GetChildren()) do
                                if gui:IsA("ScreenGui") and gui.Enabled then
                                    local playBtn = gui:FindFirstChild("PlayButton", true) or gui:FindFirstChild("Play", true) or gui:FindFirstChild("Start", true)
                                    if playBtn and playBtn:IsA("GuiButton") and playBtn.Visible then
                                        for _, conn in pairs(getconnections(playBtn.MouseButton1Click or playBtn.Activated)) do
                                            conn:Fire()
                                        end
                                    end
                                end
                            end
                        end
                    end)
                end

                if Config.Get("AutoClaimPlot", true) then
                    pcall(function()
                        local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
                        local plotFolder = eventsFolder and eventsFolder:FindFirstChild("Plot")
                        if plotFolder then
                            local getPlots = plotFolder:FindFirstChild("GetAvailablePlots")
                            local claimPlot = plotFolder:FindFirstChild("ClaimPlot")
                            if getPlots and claimPlot then
                                local available = getPlots:InvokeServer()
                                if typeof(available) == "table" and #available > 0 then
                                    claimPlot:InvokeServer(available[1])
                                end
                            end
                        end
                    end)
                end
            end
        end
    end)
end

return General
