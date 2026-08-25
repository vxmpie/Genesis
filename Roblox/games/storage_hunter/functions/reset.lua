local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local ResetModule = {}
local trackerThread = nil

function ResetModule.ResetCharacter()
    local character = LocalPlayer.Character
    if not character then return end

    local success = pcall(function()
        character:BreakJoints()
    end)

    if not success then
        pcall(function()
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.Health = 0
            end
        end)
    end

    if character and character:FindFirstChild("HumanoidRootPart") then
        pcall(function()
            character.HumanoidRootPart:Destroy()
        end)
    end
end

function ResetModule.StartTracker(State, countdownLabel, statusLabel)
    if trackerThread then
        pcall(function() task.cancel(trackerThread) end)
    end

    trackerThread = task.spawn(function()
        local lastPos = nil
        local idleSeconds = 0
        local timerCountdown = State.IntervalSeconds

        while State.IsActive do
            local character = LocalPlayer.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")

            if not hrp or not humanoid or humanoid.Health <= 0 then
                if statusLabel then
                    statusLabel.Text = "RESPAWNING..."
                    statusLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
                end
                lastPos = nil
                idleSeconds = 0
                task.wait(1)
            else
                if State.Mode == "Anti-Stuck" then
                    local currentPos = hrp.Position

                    if not lastPos then
                        lastPos = currentPos
                        idleSeconds = 0
                    end

                    local distance = (currentPos - lastPos).Magnitude

                    if distance > 3 then
                        lastPos = currentPos
                        idleSeconds = 0
                        if statusLabel then
                            statusLabel.Text = "FARMING (MOVING)"
                            statusLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
                        end
                        if countdownLabel then
                            countdownLabel.Text = "00:00"
                        end
                    else
                        idleSeconds = idleSeconds + 1
                        local remaining = math.max(0, State.IntervalSeconds - idleSeconds)

                        if countdownLabel then
                            local mins = math.floor(remaining / 60)
                            local secs = remaining % 60
                            countdownLabel.Text = string.format("%02d:%02d", mins, secs)
                        end

                        if remaining <= 0 then
                            if statusLabel then
                                statusLabel.Text = "STUCK! RESETTING..."
                                statusLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
                            end
                            ResetModule.ResetCharacter()
                            task.wait(3)
                            lastPos = nil
                            idleSeconds = 0
                        else
                            if statusLabel then
                                statusLabel.Text = string.format("IDLE (%ds / %ds)", idleSeconds, State.IntervalSeconds)
                                statusLabel.TextColor3 = Color3.fromRGB(255, 180, 60)
                            end
                        end
                    end
                else
                    if timerCountdown <= 0 then
                        if statusLabel then
                            statusLabel.Text = "RESETTING..."
                            statusLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
                        end
                        ResetModule.ResetCharacter()
                        task.wait(3)
                        timerCountdown = State.IntervalSeconds
                        if statusLabel then
                            statusLabel.Text = "ACTIVE"
                            statusLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
                        end
                    end

                    if countdownLabel then
                        local mins = math.floor(timerCountdown / 60)
                        local secs = timerCountdown % 60
                        countdownLabel.Text = string.format("%02d:%02d", mins, secs)
                    end

                    timerCountdown = timerCountdown - 1
                end

                task.wait(1)
            end
        end
    end)
end

function ResetModule.StopTracker(State, countdownLabel, statusLabel)
    State.IsActive = false
    if trackerThread then
        pcall(function() task.cancel(trackerThread) end)
        trackerThread = nil
    end
    if countdownLabel then countdownLabel.Text = "00:00" end
    if statusLabel then
        statusLabel.Text = "INACTIVE"
        statusLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
    end
end

return ResetModule
