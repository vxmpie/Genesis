local Utilities = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

Utilities.Status = {
    Finds = 0,
    Alerts = 0,
    SpawnedVehicle = "Flying UFO"
}

local WAYPOINTS = {
    ["Junk Yard"] = Vector3.new(-1022.42, 1722, 114.73),
    ["Back Alley"] = Vector3.new(-65.73, 1722, -1004.99),
    ["Farmyard"] = Vector3.new(789.28, 1722, 574.65),
    ["Shipyard"] = Vector3.new(-551.48, 1722, 698.81),
    ["Shopping Mall"] = Vector3.new(-103.88, 1722, -153.25),
    ["Lucky Beach"] = Vector3.new(895.73, 1722, -316.32),
    ["Power Plant"] = Vector3.new(206.18, 1722, 856.24),
    ["Alien Invasion"] = Vector3.new(-155.67, 1722, -788.66),
    ["Business Bay"] = Vector3.new(-180.23, 1722, 450.12),
    ["Item Cleaning Services (Wash)"] = Vector3.new(441.52, 1722, -277.62),
    ["Repair Shop"] = Vector3.new(458.12, 1722, -79.35),
    ["Grading Store"] = Vector3.new(336.85, 1722, -308.19),
    ["Locksmith"] = Vector3.new(420.31, 1722, -195.44),
    ["Quick Sell Shop"] = Vector3.new(380.15, 1722, -250.60),
    ["Authenticator"] = Vector3.new(-678.92, 1722, -924.15),
    ["Museum"] = Vector3.new(-220.45, 1722, -350.80),
    ["Energy Drink Shop"] = Vector3.new(290.15, 1722, -120.40),
    ["Car Shop"] = Vector3.new(510.60, 1722, -180.90),
    ["Car Customisation"] = Vector3.new(540.20, 1722, -150.30),
    ["Trailer Store"] = Vector3.new(480.75, 1722, -210.10),
    ["Club"] = Vector3.new(-310.50, 1722, -420.75),
    ["Lake"] = Vector3.new(631.58, 1722, -852.10),
    ["My Plot / Shop"] = Vector3.new(-453.88, 1722, -1097.45)
}

function Utilities.GetWaypointsList()
    local list = {}
    for name, _ in pairs(WAYPOINTS) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

function Utilities.TeleportTo(name)
    local targetPos = WAYPOINTS[name]
    if targetPos then
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
            return true
        end
    end
    return false
end

function Utilities.SpawnVehicle(vehicleName)
    pcall(function()
        local events = ReplicatedStorage:FindFirstChild("Events")
        local vehFolder = events and events:FindFirstChild("Vehicles")
        local reqSpawn = vehFolder and vehFolder:FindFirstChild("RequestSpawn")
        if reqSpawn then
            reqSpawn:InvokeServer(vehicleName or "Flying UFO")
            Utilities.Status.SpawnedVehicle = vehicleName or "Flying UFO"
        end
    end)
end

function Utilities.SendWebhook(url, title, description, color)
    if not url or url == "" or not string.find(url, "discord.com/api/webhooks") then return end
    pcall(function()
        local payload = {
            embeds = {{
                title = title or "Genesis Hub Notification",
                description = description or "",
                color = color or 5814783,
                timestamp = DateTime.now():ToIsoDate()
            }}
        }
        local req = request or http_request or (syn and syn.request) or (http and http.request)
        if req then
            req({
                Url = url,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(payload)
            })
            Utilities.Status.Alerts = Utilities.Status.Alerts + 1
        end
    end)
end

function Utilities.Init(Config, DB)
    RunService.RenderStepped:Connect(function()
        if not Config.Get("StopAllAutomation", false) then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildWhichIsA("Humanoid")
            if hum then
                if Config.Get("WalkSpeedToggle", false) then
                    hum.WalkSpeed = Config.Get("WalkSpeedValue", 100)
                end
                if Config.Get("JumpPowerToggle", false) then
                    hum.JumpPower = Config.Get("JumpPowerValue", 50)
                end
            end
        end
    end)

    UserInputService.JumpRequest:Connect(function()
        if not Config.Get("StopAllAutomation", false) and Config.Get("InfiniteJump", false) then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildWhichIsA("Humanoid")
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end)

    RunService.Stepped:Connect(function()
        if not Config.Get("StopAllAutomation", false) and Config.Get("Noclip", false) then
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end
    end)
end

return Utilities
