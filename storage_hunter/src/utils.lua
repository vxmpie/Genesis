local Utils = {}
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")

function Utils.warpTo(cframe)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.CFrame = cframe + Vector3.new(0, 3, 0)
    end
end

function Utils.getNetWorth()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    return (ls and ls:FindFirstChild("Net Worth") and tonumber(ls["Net Worth"].Value)) or 0
end

function Utils.getCurrentVehicle()
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChild("Humanoid")
    if humanoid and humanoid.SeatPart then
        return humanoid.SeatPart:FindFirstAncestorWhichIsA("Model")
    end
    return nil
end

function Utils.findMyPlot()
    local plots = Workspace:FindFirstChild("_Plots")
    if not plots then return nil end
    local shortest, closest = math.huge, nil
    for i = 1, 9 do
        local p = plots:FindFirstChild("Plot" .. i)
        if p and p:FindFirstChild("Structures") and p.Structures:FindFirstChild("Asphalt Floor") then
            local fs = p.Structures["Asphalt Floor"]:FindFirstChild("FloorSurface")
            if fs and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local dist = (LocalPlayer.Character.HumanoidRootPart.Position - fs.Position).Magnitude
                if dist < shortest then 
                    shortest = dist
                    closest = i 
                end
            end
        end
    end
    return closest and plots:FindFirstChild("Plot" .. closest) or nil
end

function Utils.warpToMyPlot()
    local plot = Utils.findMyPlot()
    if plot then 
        Utils.warpTo(plot.Structures["Asphalt Floor"].FloorSurface.CFrame) 
    end
end

return Utils