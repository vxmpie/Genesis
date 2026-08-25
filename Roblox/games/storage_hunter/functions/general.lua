local General = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

function General.Init(Config)
    print("[GENESIS] General Automation Initialized!")
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
                                        print("[GENESIS] Auto Play detected title screen button. Clicking Play...")
                                        for _, conn in pairs(getconnections(playBtn.MouseButton1Click or playBtn.Activated)) do
                                            conn:Fire()
                                        end
                                        pcall(function()
                                            StarterGui:SetCore("SendNotification", {
                                                Title = "GENESIS",
                                                Text = "Auto Play Triggered!",
                                                Duration = 3
                                            })
                                        end)
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
                                    for idx, plotId in pairs(available) do
                                        local target = typeof(plotId) == "table" and (plotId.Id or plotId.Name or plotId.PlotId or idx) or plotId
                                        print("[GENESIS] Claiming available plot:", tostring(target))
                                        local res = claimPlot:InvokeServer(target)
                                        print("[GENESIS] ClaimPlot Server Response:", tostring(res))
                                        pcall(function()
                                            StarterGui:SetCore("SendNotification", {
                                                Title = "GENESIS",
                                                Text = "Plot Claimed: " .. tostring(target),
                                                Duration = 4
                                            })
                                        end)
                                        break
                                    end
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
