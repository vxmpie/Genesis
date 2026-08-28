local TeleportModule = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

-- Static POI Database extracted from Genesis_UltraFullDump.json
local STATIC_POIS = {
    -- Areas & Zones
    ["junk_yard"] = {
        Id = "1",
        Name = "Junk Yard",
        Category = "Area",
        Position = Vector3.new(19.87, 1719.72, -24.30),
        Description = "Starter storage lot and scrap yard"
    },
    ["back_alley"] = {
        Id = "2",
        Name = "Back Alley",
        Category = "Area",
        Position = Vector3.new(-571.19, 1719.33, -399.96),
        Description = "Mid-tier auction storage area"
    },
    ["farmyard"] = {
        Id = "3",
        Name = "Farmyard",
        Category = "Area",
        Position = Vector3.new(-89.33, 1720.27, -1153.02),
        Description = "Farm auctions and barns"
    },
    ["shipyard"] = {
        Id = "4",
        Name = "Shipyard",
        Category = "Area",
        Position = Vector3.new(-551.00, 1719.43, 698.22),
        Description = "Shipping containers and dock auctions"
    },
    ["shopping_mall"] = {
        Id = "5",
        Name = "Shopping Mall",
        Category = "Area",
        Position = Vector3.new(346.72, 1719.38, -172.74),
        Description = "Commercial district and central shops"
    },
    ["lucky_beach"] = {
        Id = "6",
        Name = "Lucky Beach",
        Category = "Area",
        Position = Vector3.new(-222.61, 1686.77, -1784.81),
        Description = "Coastal auctions and fishing spot"
    },
    ["power_plant"] = {
        Id = "7",
        Name = "Power Plant",
        Category = "Area",
        Position = Vector3.new(-2115.65, 1719.05, -955.84),
        Description = "High-tier industrial auction site"
    },
    ["alien_invasion"] = {
        Id = "8",
        Name = "Alien Invasion",
        Category = "Area",
        Position = Vector3.new(-154.81, 1719.05, -787.54),
        Description = "UFO crash zone and Alien Market"
    },
    ["business_bay"] = {
        Id = "9",
        Name = "Business Bay",
        Category = "Area",
        Position = Vector3.new(1924.37, 1708.79, -3928.25),
        Description = "High-end executive auction lots"
    },

    -- Shops & Facilities
    ["item_cleaning"] = {
        Id = "18",
        Name = "Item Cleaning Services",
        Category = "Shop",
        Position = Vector3.new(440.53, 1721.91, -277.27),
        Description = "Wash station for dirty and rare items"
    },
    ["grading_store"] = {
        Id = "15",
        Name = "Grading Store",
        Category = "Shop",
        Position = Vector3.new(336.45, 1721.91, -308.22),
        Description = "Grade safes and unlock high-value loot"
    },
    ["locksmith"] = {
        Id = "13",
        Name = "Locksmith",
        Category = "Shop",
        Position = Vector3.new(394.72, 1722.11, -22.09),
        Description = "Picklock and open locked safes"
    },
    ["quick_sell"] = {
        Id = "16",
        Name = "Quick Sell Shop",
        Category = "Shop",
        Position = Vector3.new(366.48, 1721.92, -21.55),
        Description = "Pawn shop to sell items instantly"
    },
    ["car_shop"] = {
        Id = "19",
        Name = "Car Shop",
        Category = "Shop",
        Position = Vector3.new(-222.94, 1721.91, -170.54),
        Description = "Purchase new cars and trucks"
    },
    ["car_customisation"] = {
        Id = "20",
        Name = "Car Customisation",
        Category = "Shop",
        Position = Vector3.new(-72.57, 1722.09, 237.34),
        Description = "Customize paint, wheels, horns"
    },
    ["trailer_store"] = {
        Id = "14",
        Name = "Trailer Store",
        Category = "Shop",
        Position = Vector3.new(484.92, 1721.37, -1371.87),
        Description = "Buy larger trailers for storage transport"
    },
    ["museum"] = {
        Id = "12",
        Name = "Museum",
        Category = "Shop",
        Position = Vector3.new(506.39, 1725.05, -185.04),
        Description = "Donate relics and collect passive earnings"
    },
    ["energy_drink"] = {
        Id = "11",
        Name = "Energy Drink Shop",
        Category = "Shop",
        Position = Vector3.new(337.17, 1721.92, -7.12),
        Description = "Buy stamina and speed boosts"
    },
    ["repair_shop"] = {
        Id = "21",
        Name = "Repair Shop",
        Category = "Shop",
        Position = Vector3.new(458.13, 1721.91, -79.29),
        Description = "Buy wrenches and repair damaged items"
    },
    ["authenticator"] = {
        Id = "17",
        Name = "Authenticator",
        Category = "Shop",
        Position = Vector3.new(-677.50, 1723.32, -923.76),
        Description = "Certify high-rarity items"
    },
    ["club"] = {
        Id = "10",
        Name = "Club",
        Category = "Shop",
        Position = Vector3.new(-693.77, 1721.55, -1020.48),
        Description = "Night club and VIP facilities"
    },
    ["lake"] = {
        Id = "22",
        Name = "Lake (Fishing)",
        Category = "Shop",
        Position = Vector3.new(631.58, 1713.33, -852.10),
        Description = "Fishing spot and lakeside market"
    },

    -- Player Dynamic Spots
    ["player_shop"] = {
        Id = "23",
        Name = "Player Shop (Default)",
        Category = "Player Shop",
        Position = Vector3.new(-453.13, 1720.16, -1096.56),
        Description = "Personal plot and display shop"
    }
}

TeleportModule.STATIC_POIS = STATIC_POIS

local activeTween = nil

local function sendNotice(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "GENESIS TP",
            Text = text or "",
            Duration = 3
        })
    end)
end

function TeleportModule.GetCharacter()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    return char, hrp, hum
end

function TeleportModule.Unseat()
    local _, _, hum = TeleportModule.GetCharacter()
    if hum and hum.Sit then
        hum.Sit = false
        task.wait(0.05)
    end
end

function TeleportModule.ResetVelocity(hrp)
    if not hrp then return end
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    pcall(function()
        hrp.Velocity = Vector3.zero
        hrp.RotVelocity = Vector3.zero
    end)
end

function TeleportModule.TeleportToPosition(targetPos, altitudeOffset, smooth, speed)
    local char, hrp, hum = TeleportModule.GetCharacter()
    if not char or not hrp or not hum or hum.Health <= 0 then
        sendNotice("Teleport Error", "Character not ready or dead!")
        return false
    end

    if activeTween then
        pcall(function() activeTween:Cancel() end)
        activeTween = nil
    end

    TeleportModule.Unseat()

    local offset = tonumber(altitudeOffset) or 3.5
    local safeY = targetPos.Y + offset
    local destinationCFrame = CFrame.new(targetPos.X, safeY, targetPos.Z)

    if smooth then
        local distance = (hrp.Position - destinationCFrame.Position).Magnitude
        local moveSpeed = tonumber(speed) or 250
        local duration = math.clamp(distance / moveSpeed, 0.2, 8.0)

        TeleportModule.ResetVelocity(hrp)

        local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
        activeTween = TweenService:Create(hrp, tweenInfo, { CFrame = destinationCFrame })

        activeTween.Completed:Connect(function()
            activeTween = nil
            TeleportModule.ResetVelocity(hrp)
        end)

        activeTween:Play()
        return true
    else
        TeleportModule.ResetVelocity(hrp)
        pcall(function()
            char:PivotTo(destinationCFrame)
        end)
        hrp.CFrame = destinationCFrame
        TeleportModule.ResetVelocity(hrp)
        return true
    end
end

function TeleportModule.TeleportToPOI(poiKeyOrId, State)
    local poi = STATIC_POIS[poiKeyOrId]
    if not poi then
        for _, p in pairs(STATIC_POIS) do
            if tostring(p.Id) == tostring(poiKeyOrId) or string.lower(p.Name) == string.lower(tostring(poiKeyOrId)) then
                poi = p
                break
            end
        end
    end

    if not poi then
        sendNotice("Teleport Error", "POI not found: " .. tostring(poiKeyOrId))
        return false
    end

    local isSmooth = State and (State.TeleportMode == "Tween")
    local offset = State and (State.TeleportSafeOffset or 3.5) or 3.5

    local ok = TeleportModule.TeleportToPosition(poi.Position, offset, isSmooth)
    if ok then
        sendNotice("Teleported", "Arrived at " .. poi.Name)
    end
    return ok
end

function TeleportModule.TeleportToPlot(State)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local plotEvents = events and events:FindFirstChild("Plot")
    local tpRemote = plotEvents and plotEvents:FindFirstChild("TeleportToPlot")

    if tpRemote and tpRemote:IsA("RemoteEvent") then
        pcall(function()
            tpRemote:FireServer()
        end)
    end

    local gpsEvents = events and events:FindFirstChild("GPS")
    local getPOIs = gpsEvents and gpsEvents:FindFirstChild("GetPOIs")
    if getPOIs and getPOIs:IsA("RemoteFunction") then
        local success, pois = pcall(function() return getPOIs:InvokeServer() end)
        if success and type(pois) == "table" then
            local poiList = pois.pois or pois
            for _, p in pairs(poiList) do
                if type(p) == "table" and p.position then
                    local isMine = (p.ownerUserId == LocalPlayer.UserId) or (p.category == "Player Shop" and string.find(string.lower(tostring(p.name)), string.lower(LocalPlayer.Name)))
                    if isMine then
                        local pos = Vector3.new(p.position.X, p.position.Y, p.position.Z)
                        TeleportModule.TeleportToPosition(pos, State and State.TeleportSafeOffset or 3.5, State and State.TeleportMode == "Tween")
                        sendNotice("Teleported", "Arrived at your Plot Shop!")
                        return true
                    end
                end
            end
        end
    end

    return TeleportModule.TeleportToPOI("player_shop", State)
end

function TeleportModule.TeleportToVehicle(State)
    local myName = LocalPlayer.Name
    local myUserId = LocalPlayer.UserId

    local foundVehicle = nil
    local containers = {
        workspace:FindFirstChild("Vehicles"),
        workspace:FindFirstChild("SpawnedVehicles"),
        workspace:FindFirstChild("Cars"),
        workspace
    }

    for _, container in ipairs(containers) do
        if container then
            for _, obj in ipairs(container:GetChildren()) do
                if obj:IsA("Model") then
                    local seat = obj:FindFirstChildOfClass("VehicleSeat") or obj:FindFirstChild("DriveSeat")
                    if seat then
                        local ownerVal = obj:FindFirstChild("Owner") or obj:FindFirstChild("OwnerUserId") or obj:FindFirstChild("OwnerName")
                        local objName = string.lower(obj.Name)

                        local isMatch = false
                        if ownerVal then
                            if ownerVal:IsA("IntValue") or ownerVal:IsA("NumberValue") then
                                isMatch = (ownerVal.Value == myUserId)
                            elseif ownerVal:IsA("StringValue") then
                                isMatch = (string.lower(ownerVal.Value) == string.lower(myName))
                            end
                        end

                        if not isMatch and (string.find(objName, string.lower(myName)) or string.find(objName, tostring(myUserId))) then
                            isMatch = true
                        end

                        if isMatch then
                            foundVehicle = obj
                            break
                        end
                    end
                end
            end
        end
        if foundVehicle then break end
    end

    if foundVehicle then
        local seat = foundVehicle:FindFirstChildOfClass("VehicleSeat") or foundVehicle:FindFirstChild("DriveSeat")
        local targetCFrame = seat and (seat.CFrame + Vector3.new(0, 2, 0)) or (foundVehicle:GetPivot() + Vector3.new(0, 3.5, 0))
        
        local ok = TeleportModule.TeleportToPosition(targetCFrame.Position, 0, State and State.TeleportMode == "Tween")
        if ok then
            sendNotice("Vehicle TP", "Teleported to your vehicle: " .. foundVehicle.Name)
        end
        return ok
    else
        sendNotice("Vehicle Not Found", "Could not find your spawned vehicle in workspace!")
        return false
    end
end

function TeleportModule.TeleportToPlayer(targetPlayer, State)
    if not targetPlayer then return false end
    local targetChar = targetPlayer.Character
    local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    if not targetHrp then
        sendNotice("Player TP", targetPlayer.DisplayName .. " has no valid character!")
        return false
    end

    local destPos = targetHrp.Position + (targetHrp.CFrame.LookVector * -3) + Vector3.new(0, 1, 0)
    local ok = TeleportModule.TeleportToPosition(destPos, 0, State and State.TeleportMode == "Tween")
    if ok then
        sendNotice("Player TP", "Teleported to " .. targetPlayer.DisplayName)
    end
    return ok
end

function TeleportModule.SaveWaypoint(name, State)
    if not name or string.len(string.gsub(name, "%s+", "")) == 0 then
        sendNotice("Waypoint Error", "Please enter a valid waypoint name!")
        return false
    end

    local _, hrp, _ = TeleportModule.GetCharacter()
    if not hrp then
        sendNotice("Waypoint Error", "Character not found!")
        return false
    end

    if not State.Waypoints then
        State.Waypoints = {}
    end

    local pos = hrp.Position
    State.Waypoints[name] = {
        X = math.floor(pos.X * 100) / 100,
        Y = math.floor(pos.Y * 100) / 100,
        Z = math.floor(pos.Z * 100) / 100,
        SavedAt = os.date("%H:%M:%S")
    }

    sendNotice("Waypoint Saved", "Saved waypoint: " .. name)
    return true
end

function TeleportModule.DeleteWaypoint(name, State)
    if State.Waypoints and State.Waypoints[name] then
        State.Waypoints[name] = nil
        sendNotice("Waypoint Deleted", "Removed waypoint: " .. name)
        return true
    end
    return false
end

function TeleportModule.TeleportToWaypoint(name, State)
    if not State.Waypoints or not State.Waypoints[name] then
        sendNotice("Waypoint Error", "Waypoint not found: " .. tostring(name))
        return false
    end

    local wp = State.Waypoints[name]
    local pos = Vector3.new(wp.X, wp.Y, wp.Z)
    local isSmooth = State.TeleportMode == "Tween"
    local offset = State.TeleportSafeOffset or 3.5

    local ok = TeleportModule.TeleportToPosition(pos, offset, isSmooth)
    if ok then
        sendNotice("Waypoint TP", "Arrived at waypoint: " .. name)
    end
    return ok
end

return TeleportModule
