local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local TeleportModule = {}
local cachedPOIs = {}

function TeleportModule.FetchPOIs()
    cachedPOIs = {}
    local events = ReplicatedStorage:FindFirstChild("Events")
    local gpsEvents = events and events:FindFirstChild("GPS")
    local getPOIs = gpsEvents and gpsEvents:FindFirstChild("GetPOIs")

    if getPOIs then
        local ok, res = pcall(function() return getPOIs:InvokeServer() end)
        if ok and type(res) == "table" then
            for k, v in pairs(res) do
                local name = nil
                local pos = nil

                if type(v) == "table" then
                    name = v.Name or v.Title or v.name or v.Label or tostring(k)
                    pos = v.Position or v.CFrame or v.pos or v.Location or v.Target
                elseif typeof(v) == "Vector3" or typeof(v) == "CFrame" then
                    name = tostring(k)
                    pos = v
                end

                if name and pos then
                    if typeof(pos) == "CFrame" then
                        cachedPOIs[name] = pos.Position
                    elseif typeof(pos) == "Vector3" then
                        cachedPOIs[name] = pos
                    elseif type(pos) == "table" then
                        local x = pos.X or pos.x or pos[1]
                        local y = pos.Y or pos.y or pos[2]
                        local z = pos.Z or pos.z or pos[3]
                        if x and y and z then
                            cachedPOIs[name] = Vector3.new(x, y, z)
                        end
                    end
                end
            end
        end
    end

    local mapFolder = workspace:FindFirstChild("Map") or workspace:FindFirstChild("Zones") or workspace:FindFirstChild("POIs")
    if mapFolder then
        for _, obj in ipairs(mapFolder:GetChildren()) do
            if obj:IsA("BasePart") then
                if not cachedPOIs[obj.Name] then
                    cachedPOIs[obj.Name] = obj.Position
                end
            elseif obj:IsA("Model") and obj.PrimaryPart then
                if not cachedPOIs[obj.Name] then
                    cachedPOIs[obj.Name] = obj.PrimaryPart.Position
                end
            end
        end
    end

    return cachedPOIs
end

TeleportModule.FetchPOIs()

function TeleportModule.GetLocationList()
    TeleportModule.FetchPOIs()
    local list = { "🏡 My Plot / Shop" }

    for name, _ in pairs(cachedPOIs) do
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
            return true
        end
    end

    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local targetPos = cachedPOIs[targetName]
    if targetPos then
        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 4, 0))
        return true
    end

    for name, pos in pairs(cachedPOIs) do
        if string.find(string.lower(name), string.lower(targetName)) or string.find(string.lower(targetName), string.lower(name)) then
            hrp.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
            return true
        end
    end

    return false
end

return TeleportModule
