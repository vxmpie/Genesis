local AutoEquipModule = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

local RARITY_RANKS = {
    ["Common"] = 1,
    ["Uncommon"] = 2,
    ["Rare"] = 3,
    ["Epic"] = 4,
    ["Legendary"] = 5,
    ["Mythical"] = 6,
    ["Divine"] = 7,
    ["Exotic"] = 8,
    ["Celestial"] = 9,
    ["Secret I"] = 10,
    ["Secret1"] = 10,
    ["Secret II"] = 11,
    ["Secret2"] = 11,
    ["Exclusive"] = 12
}

local VARIANT_BONUS = {
    ["Titanic"] = 1000,
    ["Huge"] = 500,
    ["Normal"] = 0
}

local loopThread = nil
local isProcessing = false

local function sendNotice(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "GENESIS AUTO EQUIP",
            Text = text or "",
            Duration = 3
        })
    end)
end

function AutoEquipModule.GetUnitConfig()
    local ok, res = pcall(function()
        local mod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitConfig
        if mod then
            return require(mod)
        end
        return nil
    end)
    return (ok and res) or nil
end

function AutoEquipModule.GetMyPlot()
    local ok, plot = pcall(function()
        local pcMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Plot.PlotController
        if pcMod then
            local pc = require(pcMod)
            if pc and pc.plot then
                return pc.plot
            end
        end
        return nil
    end)
    if ok and plot then return plot end

    local claimedFolder = workspace:FindFirstChild("Plots") and workspace.Plots:FindFirstChild("Claimed")
    if claimedFolder then
        for _, p in ipairs(claimedFolder:GetChildren()) do
            local nameLower = string.lower(LocalPlayer.Name)
            for _, desc in ipairs(p:GetDescendants()) do
                if desc:IsA("TextLabel") or desc:IsA("SurfaceGui") then
                    local txt = desc.Text or ""
                    if string.find(string.lower(txt), nameLower) then
                        return p
                    end
                end
            end
        end
        local children = claimedFolder:GetChildren()
        if #children == 1 then
            return children[1]
        end
    end
    return nil
end

function AutoEquipModule.GetUnlockedSlotsCount()
    local ok, slotsData = pcall(function()
        local dcMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Data.DataController
        if dcMod then
            local dc = require(dcMod)
            local rawSlots = dc.___C and dc.___C.Slots and dc.___C.Slots.___C
            if rawSlots then
                local count = 0
                for _ in pairs(rawSlots) do
                    count = count + 1
                end
                return count
            end
        end
        return nil
    end)
    if ok and slotsData and slotsData > 0 then
        return slotsData
    end
    return 14
end

function AutoEquipModule.GetInventoryUnits()
    local units = {}

    pcall(function()
        local clientMod = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Data") and ReplicatedStorage.Packages.Data:FindFirstChild("Client")
        if clientMod then
            local clientData = require(clientMod)
            local inv = clientData:get("Inventory") or (clientData.data and clientData.data.___C and clientData.data.___C.Inventory and clientData.data.___C.Inventory.___C)
            if inv then
                for guid, item in pairs(inv) do
                    if type(item) == "table" and (item.kind == "Unit" or item.entry ~= nil) then
                        table.insert(units, {
                            GUID = tostring(guid),
                            Name = item.entry or item.Name or "Unknown",
                            Level = item.level or 1,
                            Data = item
                        })
                    end
                end
            end
        end
    end)

    if #units == 0 then
        pcall(function()
            local dcMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Data.DataController
            if dcMod then
                local dc = require(dcMod)
                local inv = dc.___C and dc.___C.Inventory and dc.___C.Inventory.___C
                if inv then
                    for guid, item in pairs(inv) do
                        if type(item) == "table" and (item.kind == "Unit" or item.entry ~= nil) then
                            table.insert(units, {
                                GUID = tostring(guid),
                                Name = item.entry or item.Name or "Unknown",
                                Level = item.level or 1,
                                Data = item
                            })
                        end
                    end
                end
            end
        end)
    end

    return units
end

function AutoEquipModule.CalculateUnitScore(unitEntry, State)
    local unitConfig = AutoEquipModule.GetUnitConfig()
    local meta = unitConfig and unitConfig.entries and unitConfig.entries[unitEntry.Name]

    local rarity = (meta and meta.rarity) or "Common"
    local order = (meta and meta.order) or 1
    local variant = (meta and meta.variant) or "Normal"
    local level = unitEntry.Level or 1

    local rarityAllowed = State.RarityAllowed or {}
    if rarityAllowed[rarity] == false then
        return -1
    end

    local rRank = RARITY_RANKS[rarity] or 1
    local vBonus = VARIANT_BONUS[variant] or 0

    local mode = State.EquipMode or "RarestFirst"
    local score = 0

    if mode == "RarestFirst" then
        score = (rRank * 10000) + (State.PrioritizeVariants and vBonus or 0) + (order * 10) + level
    elseif mode == "VariantFirst" then
        score = (vBonus * 100) + (rRank * 1000) + (order * 10) + level
    elseif mode == "OrderRank" then
        score = (order * 1000) + (rRank * 100) + (State.PrioritizeVariants and vBonus or 0) + level
    else
        score = (rRank * 10000) + (order * 10) + level
    end

    return score, rarity, variant, order
end

function AutoEquipModule.EquipUnitToSlot(slotId, unitGuid)
    local ucMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitController
    if ucMod then
        local ok1, uc = pcall(require, ucMod)
        if ok1 and uc and uc.Equip then
            local s = pcall(function() uc:Equip(slotId, unitGuid) end)
            if s then return true end
            local s2 = pcall(function() uc:Equip(unitGuid, slotId) end)
            if s2 then return true end
        end
    end

    local rf = ReplicatedStorage:FindFirstChild("Network") and ReplicatedStorage.Network:FindFirstChild("UnitService") and ReplicatedStorage.Network.UnitService:FindFirstChild("RF") and ReplicatedStorage.Network.UnitService.RF:FindFirstChild("Equip")
    if rf and rf:IsA("RemoteFunction") then
        local ok2 = pcall(function() rf:InvokeServer(slotId, unitGuid) end)
        if not ok2 then
            pcall(function() rf:InvokeServer(unitGuid, slotId) end)
        end
        return true
    end

    return false
end

function AutoEquipModule.NativeEquipBest()
    local re = ReplicatedStorage:FindFirstChild("Network") and ReplicatedStorage.Network:FindFirstChild("PlotService") and ReplicatedStorage.Network.PlotService:FindFirstChild("RE") and ReplicatedStorage.Network.PlotService.RE:FindFirstChild("EquipBest")
    if re and re:IsA("RemoteEvent") then
        pcall(function()
            re:FireServer()
        end)
        sendNotice("Native Equip", "Fired game native EquipBest!")
        return true
    end
    return false
end

function AutoEquipModule.ProcessAutoEquip(State)
    if isProcessing then return end
    isProcessing = true

    local success, err = pcall(function()
        if State.EquipMode == "NativeBest" then
            AutoEquipModule.NativeEquipBest()
            return
        end

        local units = AutoEquipModule.GetInventoryUnits()
        if #units == 0 then
            return
        end

        local rankedUnits = {}
        for _, u in ipairs(units) do
            local score, rName, vName, ord = AutoEquipModule.CalculateUnitScore(u, State)
            if score >= 0 then
                u.Score = score
                u.Rarity = rName
                u.Variant = vName
                u.Order = ord
                table.insert(rankedUnits, u)
            end
        end

        table.sort(rankedUnits, function(a, b)
            return a.Score > b.Score
        end)

        local maxSlots = AutoEquipModule.GetUnlockedSlotsCount()
        local slotsToFill = math.min(maxSlots, #rankedUnits)

        local equippedCount = 0
        for i = 1, slotsToFill do
            local targetUnit = rankedUnits[i]
            local slotIndex = tostring(i)

            local ok = AutoEquipModule.EquipUnitToSlot(slotIndex, targetUnit.GUID)
            if ok then
                equippedCount = equippedCount + 1
            end
            task.wait(0.12)
        end

        if equippedCount > 0 then
            sendNotice("Auto Equip", string.format("Equipped %d top tier units to plot!", equippedCount))
        end
    end)

    if not success then
        warn("[GENESIS AUTO EQUIP] Error:", err)
    end

    isProcessing = false
end

function AutoEquipModule.StartLoop(State)
    if loopThread then
        pcall(task.cancel, loopThread)
        loopThread = nil
    end

    State.AutoEquip = true

    loopThread = task.spawn(function()
        while State.AutoEquip do
            AutoEquipModule.ProcessAutoEquip(State)
            local waitTime = tonumber(State.IntervalSeconds) or 5
            task.wait(math.max(1, waitTime))
        end
    end)

    sendNotice("Auto Equip Loop", "Auto Equip loop started!")
end

function AutoEquipModule.StopLoop(State)
    State.AutoEquip = false
    if loopThread then
        pcall(task.cancel, loopThread)
        loopThread = nil
    end
    sendNotice("Auto Equip Loop", "Auto Equip loop stopped.")
end

return AutoEquipModule
