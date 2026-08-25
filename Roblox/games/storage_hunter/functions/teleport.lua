local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local TeleportModule = {}

local EXACT_POIS = {
    ["Auction: Junk Yard"] = Vector3.new(20, 1722, -24),
    ["Auction: Back Alley"] = Vector3.new(-571, 1722, -400),
    ["Auction: Farmyard"] = Vector3.new(-89, 1722, -1153),
    ["Auction: Shipyard"] = Vector3.new(-551, 1722, 698),
    ["Auction: Shopping Mall"] = Vector3.new(347, 1722, -173),
    ["Auction: Lucky Beach"] = Vector3.new(-223, 1690, -1785),
    ["Auction: Power Plant"] = Vector3.new(-2116, 1722, -956),
    ["Auction: Alien Invasion"] = Vector3.new(-155, 1722, -788),
    ["Auction: Business Bay"] = Vector3.new(1924, 1712, -3928),

    ["Service: Item Cleaning (Wash)"] = Vector3.new(441, 1724, -277),
    ["Service: Repair Shop"] = Vector3.new(458, 1724, -79),
    ["Service: Grading Store"] = Vector3.new(336, 1724, -308),
    ["Service: Locksmith"] = Vector3.new(395, 1724, -22),
    ["Service: Quick Sell (Pawn)"] = Vector3.new(366, 1724, -22),
    ["Service: Authenticator"] = Vector3.new(-678, 1725, -924),
    ["Service: Museum"] = Vector3.new(506, 1727, -185),
    ["Service: Energy Drinks"] = Vector3.new(337, 1724, -7),
    ["Service: Car Shop (Dealership)"] = Vector3.new(-223, 1724, -171),
    ["Service: Car Customisation"] = Vector3.new(-73, 1724, 237),
    ["Service: Trailer Store"] = Vector3.new(485, 1723, -1372),
    ["Service: Club"] = Vector3.new(-694, 1724, -1020),
    ["Service: Lake"] = Vector3.new(632, 1715, -852),
    ["🏡 My Plot / Shop"] = Vector3.new(-453, 1722, -1097),
}

function TeleportModule.GetLocationList()
    local list = {}
    for name, _ in pairs(EXACT_POIS) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

function TeleportModule.TeleportTo(targetName)
    if targetName == "🏡 My Plot / Shop" or string.find(targetName, "Plot") then
        local events = ReplicatedStorage:FindFirstChild("Events")
        local plotEvents = events and events:FindFirstChild("Plot")
        if plotEvents and plotEvents:FindFirstChild("TeleportToPlot") then
            pcall(function() plotEvents.TeleportToPlot:FireServer() end)
        end
    end

    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local targetPos = EXACT_POIS[targetName]
    if targetPos then
        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
        return true
    end

    for name, pos in pairs(EXACT_POIS) do
        if string.find(string.lower(name), string.lower(targetName)) or string.find(string.lower(targetName), string.lower(name)) then
            hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
            return true
        end
    end

    return false
end

return TeleportModule
