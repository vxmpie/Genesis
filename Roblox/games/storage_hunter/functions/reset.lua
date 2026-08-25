local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local ResetModule = {}
local trackerThread = nil

local function getStateVal(StoreOrState, key, defaultVal)
    if type(StoreOrState) == "table" then
        if StoreOrState.Get then
            local v = StoreOrState.Get(key)
            if v ~= nil then return v end
        elseif StoreOrState[key] ~= nil then
            return StoreOrState[key]
        end
    end
    return defaultVal
end

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

function ResetModule.StartTracker(StoreOrState)
    if trackerThread then
        pcall(function() task.cancel(trackerThread) end)
    end

    trackerThread = task.spawn(function()
        local lastPos = nil
        local idleSeconds = 0

        while true do
            local isEnabled = getStateVal(StoreOrState, "AntiStuck", true)
            local maxSeconds = tonumber(getStateVal(StoreOrState, "AntiStuckSeconds", 15)) or 15

            if isEnabled then
                local character = LocalPlayer.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")

                if not hrp or not humanoid or humanoid.Health <= 0 then
                    lastPos = nil
                    idleSeconds = 0
                else
                    local currentPos = hrp.Position

                    if not lastPos then
                        lastPos = currentPos
                        idleSeconds = 0
                    end

                    local distance = (currentPos - lastPos).Magnitude

                    if distance > 3 then
                        lastPos = currentPos
                        idleSeconds = 0
                    else
                        idleSeconds = idleSeconds + 1
                        if idleSeconds >= maxSeconds then
                            ResetModule.ResetCharacter()
                            task.wait(3)
                            lastPos = nil
                            idleSeconds = 0
                        end
                    end
                end
            end
            task.wait(1)
        end
    end)
end

function ResetModule.StopTracker()
    if trackerThread then
        pcall(function() task.cancel(trackerThread) end)
        trackerThread = nil
    end
end

return ResetModule
