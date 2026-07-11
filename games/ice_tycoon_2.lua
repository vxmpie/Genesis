local IceTycoonModule = {}
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local _autoFarmEnabled = false

local function getMyTycoon()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "Owner" and (obj:IsA("ObjectValue") or obj:IsA("StringValue")) then
            if obj.Value == LocalPlayer or obj.Value == LocalPlayer.Name or tostring(obj.Value) == tostring(LocalPlayer.UserId) then
                return obj.Parent
            end
        end
    end
    return nil
end

local function getWaterSource()
    local map = Workspace:FindFirstChild("Map")
    local waters = map and map:FindFirstChild("Waters")
    if waters then
        for _, water in ipairs(waters:GetDescendants()) do
            if water:IsA("ProximityPrompt") and water.Enabled then
                if water.Parent and water.Parent:IsA("BasePart") then
                    return water
                end
            end
        end
    end
    return nil
end

local function getPumpPrompt(tycoon)
    local essentials = tycoon:FindFirstChild("Essentials")
    if essentials then
        local pump = essentials:FindFirstChild("Pump")
        if pump then
            return pump:FindFirstChildWhichIsA("ProximityPrompt", true)
        end
    end
    return nil
end

local function processAutoBuy(tycoon)
    local rootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    
    local boughtSomething = false
    local buyFolders = {"CanBuy", "ExtraCanBuy"}
    
    for _, folderName in ipairs(buyFolders) do
        local folder = tycoon:FindFirstChild(folderName)
        if folder then
            for _, btn in ipairs(folder:GetChildren()) do
                local head = btn:FindFirstChild("Head") or btn:FindFirstChildWhichIsA("BasePart")
                if head then
                    rootPart.CFrame = head.CFrame + Vector3.new(0, 3, 0)
                    task.wait(0.2)
                    
                    if type(firetouchinterest) == "function" then
                        pcall(function() 
                            firetouchinterest(rootPart, head, 0)
                            task.wait(0.01)
                            firetouchinterest(rootPart, head, 1) 
                        end)
                    end
                    boughtSomething = true
                    task.wait(0.3)
                end
            end
        end
    end
    return boughtSomething
end

local function startAutoFarmLoop()
    task.spawn(function()
        while _autoFarmEnabled do
            local tycoon = getMyTycoon()
            if tycoon then
                local rootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    local isBuying = processAutoBuy(tycoon)
                    
                    if not isBuying then
                        local waterPrompt = getWaterSource()
                        local pumpPrompt = getPumpPrompt(tycoon)
                        
                        if waterPrompt and pumpPrompt then
                            rootPart.CFrame = waterPrompt.Parent.CFrame + Vector3.new(0, 3, 0)
                            task.wait(0.4)
                            pcall(function() fireproximityprompt(waterPrompt) end)
                            task.wait(0.5)
                            
                            rootPart.CFrame = pumpPrompt.Parent.CFrame + Vector3.new(0, 3, 0)
                            task.wait(0.4)
                            pcall(function() fireproximityprompt(pumpPrompt) end)
                            task.wait(0.5)
                        end
                    end
                end
            end
            task.wait(0.1)
        end
    end)
end

function IceTycoonModule.initUI(Rayfield)
    local Window = Rayfield:CreateWindow({
        Name = "Genesis Hub | Ice Tycoon 2",
        LoadingTitle = "Genesis System",
        LoadingSubtitle = "Initializing Module...",
        ConfigurationSaving = {
            Enabled = false
        },
        KeySystem = false
    })

    local MainTab = Window:CreateTab("Automation", 4483362458)

    MainTab:CreateToggle({
        Name = "Enable Auto Farm",
        CurrentValue = false,
        Flag = "AutoFarm",
        Callback = function(Value)
            _autoFarmEnabled = Value
            if _autoFarmEnabled then
                startAutoFarmLoop()
            end
        end,
    })
end

return IceTycoonModule