local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local TeleportModule = {}

local LOCATIONS = {
    ["Auction: Shipyard"] = Vector3.new(-820, 15, -1200),
    ["Auction: Jurassic"] = Vector3.new(1250, 15, 850),
    ["Auction: Business Bay"] = Vector3.new(-450, 15, 600),
    ["Auction: Farmyard"] = Vector3.new(780, 15, -950),
    ["Auction: Back Alley"] = Vector3.new(210, 15, -340),
    ["Auction: Lucky Beach"] = Vector3.new(-1100, 15, 300),
    ["Auction: Alien Invasion"] = Vector3.new(1500, 20, -1400),
    ["Auction: Power Plant"] = Vector3.new(920, 15, 1400),
    ["Auction: Cargo Ship"] = Vector3.new(-1400, 25, -500),
    ["Auction: Junk Yard"] = Vector3.new(-320, 15, -780),
    
    ["Service: Item Cleaning (Wash)"] = Vector3.new(50, 15, 120),
    ["Service: Repair Shop (Mechanic)"] = Vector3.new(-80, 15, 210),
    ["Service: Grading Shop (PSA)"] = Vector3.new(180, 15, 90),
    ["Service: Locksmith & Safes"] = Vector3.new(-150, 15, -80),
    ["Service: Pawn Shop (Sell)"] = Vector3.new(20, 15, -190),
    ["Service: Museum"] = Vector3.new(340, 15, 450),
    ["Service: Energy Drinks"] = Vector3.new(-60, 15, 310),
    ["Service: Gas Station"] = Vector3.new(450, 15, -200),
    ["Service: Dealership"] = Vector3.new(-290, 15, 480),
}

function TeleportModule.GetLocationList()
    local list = { "My Plot / Shop" }
    for name, _ in pairs(LOCATIONS) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

function TeleportModule.TeleportTo(targetName)
    if targetName == "My Plot / Shop" then
        local events = ReplicatedStorage:FindFirstChild("Events")
        local plotEvents = events and events:FindFirstChild("Plot")
        if plotEvents and plotEvents:FindFirstChild("TeleportToPlot") then
            pcall(function() plotEvents.TeleportToPlot:FireServer() end)
            return true
        end
    end

    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if (obj:IsA("Model") or obj:IsA("BasePart")) and string.find(string.lower(obj.Name), string.lower(string.gsub(targetName, ".*: ", ""))) then
            local pos = obj:IsA("BasePart") and obj.Position or (obj.PrimaryPart and obj.PrimaryPart.Position)
            if pos then
                hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
                return true
            end
        end
    end

    local fallback = LOCATIONS[targetName]
    if fallback then
        hrp.CFrame = CFrame.new(fallback)
        return true
    end

    return false
end

return TeleportModule
