local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local UtilsModule = {}
local loopThread = nil
local noclipConnection = nil

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

function UtilsModule.Process(StoreOrState)
    local events = ReplicatedStorage:FindFirstChild("Events")
    if not events then return end

    if getStateVal(StoreOrState, "AutoBuyDrinks", false) then
        local energyEvents = events:FindFirstChild("EnergyShop")
        if energyEvents and energyEvents:FindFirstChild("BuyDrink") then
            for drinkId = 1, 3 do
                pcall(function() energyEvents.BuyDrink:InvokeServer(drinkId) end)
            end
        end
    end

    if getStateVal(StoreOrState, "AutoUseDrinks", false) then
        local uiEvents = events:FindFirstChild("UI")
        if uiEvents and uiEvents:FindFirstChild("UseEnergyDrink") then
            pcall(function() uiEvents.UseEnergyDrink:FireServer() end)
        end
    end

    if getStateVal(StoreOrState, "AutoBuyUpgrades", false) then
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
        if getStateVal(StoreOrState, "WalkSpeedEnabled", false) then
            humanoid.WalkSpeed = tonumber(getStateVal(StoreOrState, "WalkSpeedValue", 16)) or 16
        end
        if getStateVal(StoreOrState, "JumpPowerEnabled", false) then
            humanoid.JumpPower = tonumber(getStateVal(StoreOrState, "JumpPowerValue", 50)) or 50
        end
    end
end

function UtilsModule.SetupNoclip(StoreOrState)
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end

    noclipConnection = RunService.Stepped:Connect(function()
        if getStateVal(StoreOrState, "Noclip", false) and LocalPlayer.Character then
            for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

function UtilsModule.StartLoop(StoreOrState)
    if loopThread then
        pcall(function() task.cancel(loopThread) end)
    end

    UtilsModule.SetupNoclip(StoreOrState)

    loopThread = task.spawn(function()
        while true do
            pcall(function() UtilsModule.Process(StoreOrState) end)
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
