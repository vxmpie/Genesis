local AutoEquipModule = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

-- --- Rarity & Multiplier Tables ---
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

local VARIANT_MULTIPLIERS = {
    ["Titanic"] = 100,
    ["Huge"] = 10,
    ["Normal"] = 1
}

local MUTATION_CHANCES = {
    ["Rainbow"] = 1000000,
    ["Ruby"] = 100000,
    ["Diamond"] = 10000,
    ["Emerald"] = 1000,
    ["Gold"] = 100,
    ["Silver"] = 10
}

-- --- Module State ---
local loopThread = nil
local isProcessing = false
local lastScanResults = {}

-- --- Utility Functions ---
local function sendNotice(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "GENESIS AUTO EQUIP",
            Text = text or "",
            Duration = 3
        })
    end)
end

function AutoEquipModule.FormatOdds(num)
    if not num or num <= 0 then return "1 in 1" end
    if num >= 1e15 then
        return string.format("1 in %.2fQ", num / 1e15)
    elseif num >= 1e12 then
        return string.format("1 in %.2fT", num / 1e12)
    elseif num >= 1e9 then
        return string.format("1 in %.2fB", num / 1e9)
    elseif num >= 1e6 then
        return string.format("1 in %.2fM", num / 1e6)
    elseif num >= 1e3 then
        return string.format("1 in %.1fk", num / 1e3)
    else
        return string.format("1 in %d", math.floor(num))
    end
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

function AutoEquipModule.GetUnlockedSlotsCount()
    local ok, count = pcall(function()
        local dcMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Data.DataController
        if dcMod then
            local dc = require(dcMod)
            local dcC = rawget(dc, "___C") or dc.___C
            if dcC and (rawget(dcC, "Slots") or dcC.Slots) then
                local slotsNode = rawget(dcC, "Slots") or dcC.Slots
                local rawSlots = rawget(slotsNode, "___C") or slotsNode.___C or slotsNode
                if rawSlots and type(rawSlots) == "table" then
                    local c = 0
                    for _ in pairs(rawSlots) do
                        c = c + 1
                    end
                    return c
                end
            end
        end
        return nil
    end)
    if ok and count and count > 0 then
        return count
    end
    return 14
end

function AutoEquipModule.GetSlotsState()
    local slotsMap = {}
    pcall(function()
        local dcMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Data.DataController
        if dcMod then
            local dc = require(dcMod)
            local dcC = rawget(dc, "___C") or dc.___C
            if dcC and (rawget(dcC, "Slots") or dcC.Slots) then
                local slotsNode = rawget(dcC, "Slots") or dcC.Slots
                local rawSlots = rawget(slotsNode, "___C") or slotsNode.___C or slotsNode
                if rawSlots and type(rawSlots) == "table" then
                    for sIndex, sData in pairs(rawSlots) do
                        local sC = rawget(sData, "___C") or sData
                        local sX = rawget(sData, "___X")
                        local uid = nil

                        if sC and type(sC) == "table" then
                            local uidNode = rawget(sC, "unitId")
                            if uidNode and type(uidNode) == "table" then
                                uid = rawget(uidNode, "___X")
                            end
                        end

                        if not uid and sX and type(sX) == "table" then
                            uid = rawget(sX, "unitId")
                        end

                        if uid and type(uid) == "string" and uid ~= "" then
                            slotsMap[tostring(sIndex)] = uid
                        end
                    end
                end
            end
        end
    end)
    return slotsMap
end

function AutoEquipModule.GetInventoryUnits()
    local units = {}
    local rawInventory = nil

    pcall(function()
        local dcMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Data.DataController
        if dcMod then
            local dc = require(dcMod)
            local dcC = rawget(dc, "___C") or dc.___C
            if dcC and (rawget(dcC, "Inventory") or dcC.Inventory) then
                local invNode = rawget(dcC, "Inventory") or dcC.Inventory
                rawInventory = rawget(invNode, "___C") or invNode.___C or invNode
            end
        end
    end)

    if not rawInventory or type(rawInventory) ~= "table" then
        warn("[GENESIS AUTO EQUIP] Warning: Could not locate Inventory data table!")
        return units
    end

    local unitConfig = AutoEquipModule.GetUnitConfig()
    local entries = (unitConfig and unitConfig.entries) or {}

    for guid, itemNode in pairs(rawInventory) do
        local itemC = rawget(itemNode, "___C") or itemNode
        local itemX = rawget(itemNode, "___X")

        local rawName = nil
        local rawAttrs = nil
        local rawAmount = 1
        local rawLocked = false

        if itemC and type(itemC) == "table" then
            local nameNode = rawget(itemC, "name")
            if nameNode and type(nameNode) == "table" then
                rawName = rawget(nameNode, "___X")
            end
            local attrNode = rawget(itemC, "attributes")
            if attrNode and type(attrNode) == "table" then
                rawAttrs = rawget(attrNode, "___X") or {}
            end
            local amountNode = rawget(itemC, "amount")
            if amountNode and type(amountNode) == "table" then
                rawAmount = rawget(amountNode, "___X") or 1
            end
            local lockNode = rawget(itemC, "locked")
            if lockNode and type(lockNode) == "table" then
                rawLocked = rawget(lockNode, "___X") or false
            end
        end

        if not rawName and itemX and type(itemX) == "table" then
            rawName = rawget(itemX, "name") or rawget(itemX, "entry")
            rawAttrs = rawAttrs or rawget(itemX, "attributes") or {}
            rawAmount = rawAmount or rawget(itemX, "amount") or 1
            rawLocked = rawLocked or rawget(itemX, "locked") or false
        end

        if type(rawAttrs) ~= "table" then
            rawAttrs = {}
        end

        if type(rawName) == "string" and rawName ~= "" then
            local meta = entries[rawName]
            local resolvedVariant = nil

            if not meta and rawAttrs.variant then
                local vName = tostring(rawAttrs.variant)
                local comboName = vName .. " " .. rawName
                if entries[comboName] then
                    meta = entries[comboName]
                    resolvedVariant = vName
                end
            end

            if not meta then
                for prefix, _ in pairs(VARIANT_MULTIPLIERS) do
                    if string.sub(rawName, 1, #prefix + 1) == prefix .. " " then
                        local baseName = string.sub(rawName, #prefix + 2)
                        if entries[baseName] then
                            meta = entries[baseName]
                            resolvedVariant = prefix
                            break
                        end
                    end
                end
            end

            if not meta then
                meta = {
                    rarity = "Common",
                    chance = 1,
                    variant = "Normal"
                }
            end

            local level = rawAttrs.level or 1
            local mutation = rawAttrs.mutation or nil
            local trait = rawAttrs.trait or nil
            local variant = resolvedVariant or meta.variant or rawAttrs.variant or "Normal"

            table.insert(units, {
                GUID = tostring(guid),
                Name = rawName,
                Meta = meta,
                Attributes = rawAttrs,
                Level = tonumber(level) or 1,
                Mutation = mutation,
                Trait = trait,
                Variant = variant,
                Amount = tonumber(rawAmount) or 1,
                Locked = (rawLocked == true)
            })
        end
    end

    return units
end

-- --- Odds Calculation Engine ---
function AutoEquipModule.CalculateUnitOdds(unitObj)
    local meta = unitObj.Meta
    if not meta then return 0, "1 in 1" end

    local baseOdds = 1
    if meta.chance and type(meta.chance) == "number" and meta.chance > 0 then
        baseOdds = math.floor(1 / meta.chance)
    elseif meta.odds and type(meta.odds) == "number" then
        baseOdds = meta.odds
    elseif meta.rarity then
        local rank = RARITY_RANKS[meta.rarity] or 1
        baseOdds = math.floor(10 ^ rank)
    end

    local finalOdds = baseOdds

    local variantMult = VARIANT_MULTIPLIERS[unitObj.Variant] or 1
    finalOdds = finalOdds * variantMult

    if unitObj.Mutation and MUTATION_CHANCES[unitObj.Mutation] then
        finalOdds = finalOdds * MUTATION_CHANCES[unitObj.Mutation]
    end

    local lvlBonus = (unitObj.Level or 1) * 0.05
    finalOdds = finalOdds * (1 + lvlBonus)

    local formatted = AutoEquipModule.FormatOdds(finalOdds)
    return finalOdds, formatted
end

-- --- Slot & Remote Actions ---
function AutoEquipModule.UnequipSlot(slotId)
    local slotNum = tonumber(slotId)
    local slotStr = tostring(slotId)

    local ucMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitController
    if ucMod then
        local ok, uc = pcall(require, ucMod)
        if ok and uc and uc.Unequip then
            local success = pcall(function() return uc:Unequip(slotStr) end)
            if success then return true end
            if slotNum then
                local success2 = pcall(function() return uc:Unequip(slotNum) end)
                if success2 then return true end
            end
        end
    end

    local rf = ReplicatedStorage:FindFirstChild("Network") and ReplicatedStorage.Network:FindFirstChild("UnitService") and ReplicatedStorage.Network.UnitService:FindFirstChild("RF") and ReplicatedStorage.Network.UnitService.RF:FindFirstChild("Unequip")
    if rf and rf:IsA("RemoteFunction") then
        local success = pcall(function() return rf:InvokeServer(slotStr) end)
        if success then return true end
        if slotNum then
            local success2 = pcall(function() return rf:InvokeServer(slotNum) end)
            if success2 then return true end
        end
    end

    return false
end

function AutoEquipModule.EquipUnitToSlot(slotId, unitGuid)
    local slotNum = tonumber(slotId)
    local slotStr = tostring(slotId)

    local ucMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitController
    if ucMod then
        local ok1, uc = pcall(require, ucMod)
        if ok1 and uc and uc.Equip then
            local s1 = pcall(function() return uc:Equip(slotStr, unitGuid) end)
            if s1 then return true end
            if slotNum then
                local s2 = pcall(function() return uc:Equip(slotNum, unitGuid) end)
                if s2 then return true end
            end
            local s3 = pcall(function() return uc:Equip(unitGuid, slotStr) end)
            if s3 then return true end
            if slotNum then
                local s4 = pcall(function() return uc:Equip(unitGuid, slotNum) end)
                if s4 then return true end
            end
            local s5 = pcall(function() return uc:Equip(unitGuid) end)
            if s5 then return true end
        end
    end

    local rf = ReplicatedStorage:FindFirstChild("Network") and ReplicatedStorage.Network:FindFirstChild("UnitService") and ReplicatedStorage.Network.UnitService:FindFirstChild("RF") and ReplicatedStorage.Network.UnitService.RF:FindFirstChild("Equip")
    if rf and rf:IsA("RemoteFunction") then
        local ok2 = pcall(function() return rf:InvokeServer(slotStr, unitGuid) end)
        if ok2 then return true end
        if slotNum then
            local ok3 = pcall(function() return rf:InvokeServer(slotNum, unitGuid) end)
            if ok3 then return true end
        end
        local ok4 = pcall(function() return rf:InvokeServer(unitGuid, slotStr) end)
        if ok4 then return true end
        if slotNum then
            local ok5 = pcall(function() return rf:InvokeServer(unitGuid, slotNum) end)
            if ok5 then return true end
        end
        local ok6 = pcall(function() return rf:InvokeServer(unitGuid) end)
        if ok6 then return true end
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

function AutoEquipModule.GetLastScanResults()
    return lastScanResults
end

-- --- Main Auto Equip Logic ---
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
            warn("[GENESIS AUTO EQUIP] 0 units found in inventory! Check if inventory is empty.")
            sendNotice("Auto Equip", "Scanned bag: 0 units found!")
            return
        end

        local rarityAllowed = State.RarityAllowed or {}
        local rankedUnits = {}

        for _, u in ipairs(units) do
            local rName = (u.Meta and u.Meta.rarity) or "Common"
            if rarityAllowed[rName] ~= false then
                local oddsNum, oddsFmt = AutoEquipModule.CalculateUnitOdds(u)
                u.Odds = oddsNum
                u.FormattedOdds = oddsFmt
                u.Rarity = rName
                table.insert(rankedUnits, u)
            end
        end

        table.sort(rankedUnits, function(a, b)
            if a.Odds == b.Odds then
                return (a.Level or 1) > (b.Level or 1)
            end
            return a.Odds > b.Odds
        end)

        lastScanResults = rankedUnits

        local maxSlots = AutoEquipModule.GetUnlockedSlotsCount()
        local slotsToFill = math.min(maxSlots, #rankedUnits)

        if slotsToFill == 0 then
            sendNotice("Auto Equip", "No allowed units found to equip based on tier filter.")
            return
        end

        local currentSlots = AutoEquipModule.GetSlotsState()

        print(string.format("[GENESIS AUTO EQUIP] Found %d total units. Equipping top %d to plot...", #rankedUnits, slotsToFill))
        for i = 1, math.min(5, slotsToFill) do
            local u = rankedUnits[i]
            print(string.format("  #%d: %s | %s | %s | Level %d", i, u.Name, u.Rarity, u.FormattedOdds, u.Level or 1))
        end

        local equippedCount = 0
        local topReport = {}

        for i = 1, slotsToFill do
            local targetUnit = rankedUnits[i]
            local targetSlotStr = tostring(i)
            local currentUnitInSlot = currentSlots[targetSlotStr]

            if currentUnitInSlot ~= targetUnit.GUID then
                for sIndex, sGuid in pairs(currentSlots) do
                    if sGuid == targetUnit.GUID and sIndex ~= targetSlotStr then
                        AutoEquipModule.UnequipSlot(sIndex)
                        currentSlots[sIndex] = nil
                        task.wait(0.08)
                        break
                    end
                end

                if currentUnitInSlot then
                    AutoEquipModule.UnequipSlot(targetSlotStr)
                    currentSlots[targetSlotStr] = nil
                    task.wait(0.08)
                end

                local ok = AutoEquipModule.EquipUnitToSlot(targetSlotStr, targetUnit.GUID)
                if ok then
                    equippedCount = equippedCount + 1
                    currentSlots[targetSlotStr] = targetUnit.GUID
                end
                task.wait(0.1)
            end

            if i <= 3 then
                table.insert(topReport, string.format("#%d %s (%s)", i, targetUnit.Name, targetUnit.FormattedOdds))
            end
        end

        local summaryMsg = string.format("Placed %d top units! %s", equippedCount, table.concat(topReport, ", "))
        sendNotice("Auto Equip Complete", summaryMsg)
    end)

    if not success then
        warn("[GENESIS AUTO EQUIP] Error:", err)
    end

    isProcessing = false
end

-- --- Loop Controller ---
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

    sendNotice("Auto Equip Loop", "Auto Equip loop active!")
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
