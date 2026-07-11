local WaterFarm = {}
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function equipCup()
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChild("Humanoid")
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    
    if not humanoid or not backpack then return false end
    
    local cupTool = backpack:FindFirstChild("Cup") or char:FindFirstChild("Cup")
    
    if cupTool and cupTool.Parent == backpack then
        humanoid:EquipTool(cupTool)
        task.wait(0.2)
        return true
    elseif cupTool and cupTool.Parent == char then
        return true 
    end
    
    return false
end

function WaterFarm.doFarm(tycoon, rootPart, getWaterSource, getPumpPrompt)
    local waterPrompt = getWaterSource()
    local pumpPrompt = getPumpPrompt(tycoon)
    
    if waterPrompt and pumpPrompt then
        equipCup() 
        
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

return WaterFarm