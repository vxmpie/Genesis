local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local UtilsModule = {}
local loopThread = nil
local noclipConnection = nil

function UtilsModule.Process(State)
    local events = ReplicatedStorage:FindFirstChild("Events")
    if not events then return end

    if State.AutoBuyDrinks then
        local energyEvents = events:FindFirstChild("EnergyShop")
        if energyEvents and energyEvents:FindFirstChild("BuyDrink") then
            for drinkId = 1, 3 do
                pcall(function() energyEvents.BuyDrink:InvokeServer(drinkId) end)
            end
        end
    end

    if State.AutoUseDrinks then
        local uiEvents = events:FindFirstChild("UI")
        if uiEvents and uiEvents:FindFirstChild("UseEnergyDrink") then
            pcall(function() uiEvents.UseEnergyDrink:FireServer() end)
        end
    end

    if State.AutoBuyUpgrades then
        local upEvents = events:FindFirstChild("Upgrades")
        if upEvents and upEvents:FindFirstChild("BuyUpgrade") then
            pcall(function()
                local list = upEvents.GetUpgrades:InvokeServer()
                if list and type(list) == "table" then
                    for id, _ in pairs(list) do
                        upEvents.BuyUpgrade:InvokeServer(id)
                    end
                end
            end)
        end
    end

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        if State.WalkSpeedEnabled then
            humanoid.WalkSpeed = State.WalkSpeedValue
        end
        if State.JumpPowerEnabled then
            humanoid.JumpPower = State.JumpPowerValue
        end
    end
end

function UtilsModule.SetupNoclip(State)
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end

    noclipConnection = RunService.Stepped:Connect(function()
        if State.Noclip and LocalPlayer.Character then
            for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

function UtilsModule.StartLoop(State)
    if loopThread then
        pcall(function() task.cancel(loopThread) end)
    end

    UtilsModule.SetupNoclip(State)

    loopThread = task.spawn(function()
        while true do
            pcall(function() UtilsModule.Process(State) end)
            task.wait(2)
        end
    end)
end

function UtilsModule.StopLoop()
    if loopThread then
        pcall(function() task.cancel(loopThread) end)
        loopThread = nil
    end
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
end

return UtilsModule
