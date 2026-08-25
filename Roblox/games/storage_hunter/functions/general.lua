local General = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

local function clickGuiButton(btn)
    if not btn or not btn:IsA("GuiButton") then return false end
    local clicked = false
    pcall(function()
        if getconnections then
            for _, conn in pairs(getconnections(btn.MouseButton1Click)) do
                conn:Fire()
                clicked = true
            end
            for _, conn in pairs(getconnections(btn.Activated)) do
                conn:Fire()
                clicked = true
            end
        end
    end)
    pcall(function()
        if firesignal then
            firesignal(btn.MouseButton1Click)
            clicked = true
        end
    end)
    return clicked
end

function General.Init(Config)
    print("[GENESIS] General Automation Initialized (AutoPlay & AutoClaimPlot Active)")
    task.spawn(function()
        while task.wait(0.5) do
            if not Config.Get("StopAllAutomation", false) then
                if Config.Get("AutoPlay", true) then
                    pcall(function()
                        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                        if playerGui then
                            for _, gui in ipairs(playerGui:GetChildren()) do
                                if gui:IsA("ScreenGui") and gui.Enabled then
                                    local playBtn = gui:FindFirstChild("PlayButton", true) or gui:FindFirstChild("Play", true) or gui:FindFirstChild("Start", true)
                                    if playBtn and playBtn:IsA("GuiButton") and playBtn.Visible then
                                        print("[GENESIS] Title screen Play button found. Clicking Play...")
                                        clickGuiButton(playBtn)
                                    end
                                end
                            end
                        end
                    end)
                end

                if Config.Get("AutoClaimPlot", true) then
                    pcall(function()
                        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                        if playerGui then
                            local uiCtrl = playerGui:FindFirstChild("UIControllerGui")
                            local plotFrame = uiCtrl and uiCtrl:FindFirstChild("PlotSelectionFrame")
                            if not plotFrame then
                                for _, gui in ipairs(playerGui:GetChildren()) do
                                    if gui:IsA("ScreenGui") then
                                        local found = gui:FindFirstChild("PlotSelectionFrame", true)
                                        if found and found.Visible then
                                            plotFrame = found
                                            break
                                        end
                                    end
                                end
                            end

                            if plotFrame and plotFrame.Visible then
                                local claimBtn = plotFrame:FindFirstChild("ClaimButton", true) or plotFrame:FindFirstChild("Claim", true)
                                if claimBtn and claimBtn:IsA("GuiButton") then
                                    print("[GENESIS] PlotSelectionFrame detected! Clicking ClaimButton...")
                                    clickGuiButton(claimBtn)
                                    pcall(function()
                                        StarterGui:SetCore("SendNotification", {
                                            Title = "GENESIS",
                                            Text = "Claimed Plot via Screen Button!",
                                            Duration = 4
                                        })
                                    end)
                                end
                            end
                        end

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
                                        print("[GENESIS] Auto Claiming available plot via Remote:", tostring(target))
                                        local res = claimPlot:InvokeServer(target)
                                        print("[GENESIS] ClaimPlot Response:", tostring(res))
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
