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
AutoEquipModule.RARITY_RANKS = RARITY_RANKS

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
            local dcC = rawget(dc, "___C")
            if dcC and rawget(dcC, "Slots") then
                local slotsNode = rawget(dcC, "Slots")
                local rawSlots = rawget(slotsNode, "___C")
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
            local dcC = rawget(dc, "___C")
            if dcC and rawget(dcC, "Slots") then
                local slotsNode = rawget(dcC, "Slots")
                local rawSlots = rawget(slotsNode, "___C")
                if rawSlots and type(rawSlots) == "table" then
                    for sIndex, sData in pairs(rawSlots) do
                        local uid = nil
                        local sC = rawget(sData, "___C")
                        if sC and type(sC) == "table" then
                            local uidNode = rawget(sC, "unitId")
                            if uidNode and type(uidNode) == "table" then
                                local uidX = rawget(uidNode, "___X")
                                if type(uidX) == "table" then
                                    uid = rawget(uidX, "unitId")
                                elseif type(uidX) == "string" then
                                    uid = uidX
                                end
                            end
                        end

                        if not uid then
                            local sX = rawget(sData, "___X")
                            if type(sX) == "table" then
                                uid = rawget(sX, "unitId")
                            end
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

    for attempt = 1, 5 do
        pcall(function()
            local dcMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Data.DataController
            if dcMod then
                local dc = require(dcMod)
                local dcC = rawget(dc, "___C")
                if dcC and rawget(dcC, "Inventory") then
                    local invNode = rawget(dcC, "Inventory")
                    rawInventory = rawget(invNode, "___C")
                end
            end
        end)
        if rawInventory and type(rawInventory) == "table" and next(rawInventory) ~= nil then
            break
        end
        task.wait(0.2)
    end

    if not rawInventory or type(rawInventory) ~= "table" then
        warn("[GENESIS AUTO EQUIP] Warning: Could not locate Inventory data table!")
        return units
    end

    local rawCount = 0
    for _ in pairs(rawInventory) do
        rawCount = rawCount + 1
    end

    local unitConfig = AutoEquipModule.GetUnitConfig()
    local entries = (unitConfig and unitConfig.entries) or {}

    for guid, itemNode in pairs(rawInventory) do
        local rawName = nil
        local rawAttrs = {}
        local rawAmount = 1
        local rawLocked = false

        -- [1] Method A: Inspect itemNode.___C.name.___X (Confirmed working via Probe V8)
        local itemC = rawget(itemNode, "___C")
        if type(itemC) == "table" then
            local nameNode = rawget(itemC, "name")
            if type(nameNode) == "table" then
                local xData = rawget(nameNode, "___X")
                if type(xData) == "table" then
                    rawName = rawget(xData, "name")
                    rawAttrs = rawget(xData, "attributes") or rawAttrs
                    rawAmount = rawget(xData, "amount") or rawAmount
                    rawLocked = rawget(xData, "locked") or rawLocked
                elseif type(xData) == "string" then
                    rawName = xData
                end
            end

            -- If attributes node has separate ___X
            if not rawAttrs or type(rawAttrs) ~= "table" or next(rawAttrs) == nil then
                local attrNode = rawget(itemC, "attributes")
                if type(attrNode) == "table" then
                    local attrX = rawget(attrNode, "___X")
                    if type(attrX) == "table" then
                        rawAttrs = rawget(attrX, "attributes") or attrX
                    end
                end
            end
        end

        -- [2] Method B: Fallback directly to itemNode.___X
        if not rawName then
            local itemX = rawget(itemNode, "___X")
            if type(itemX) == "table" then
                rawName = rawget(itemX, "name") or rawget(itemX, "entry")
                rawAttrs = rawget(itemX, "attributes") or rawAttrs
                rawAmount = rawget(itemX, "amount") or rawAmount
                rawLocked = rawget(itemX, "locked") or rawLocked
            end
        end

        if type(rawAttrs) ~= "table" then
            rawAttrs = {}
        end

        if type(rawName) == "string" and rawName ~= "" then
            local meta = nil
            local resolvedVariant = nil

            -- [1] Check combo if variant in attributes
            if rawAttrs.variant and tostring(rawAttrs.variant) ~= "" then
                local vName = tostring(rawAttrs.variant)
                local comboName = vName .. " " .. rawName
                if entries[comboName] then
                    meta = entries[comboName]
                    resolvedVariant = vName
                end
            end

            -- [2] Check rawName directly in entries
            if not meta and entries[rawName] then
                meta = entries[rawName]
                for prefix, _ in pairs(VARIANT_MULTIPLIERS) do
                    if string.sub(rawName, 1, #prefix + 1) == prefix .. " " then
                        resolvedVariant = prefix
                        break
                    end
                end
            end

            -- [3] Strip prefix to match baseName
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

            -- Resolve numeric chance from function or number
            local numChance = 1
            local rawCh = meta.chance or meta.Chance or meta.odds or meta.Odds
            if type(rawCh) == "function" then
                local ok, res = pcall(rawCh)
                if ok and type(res) == "number" then
                    numChance = res
                end
            elseif type(rawCh) == "number" then
                numChance = rawCh
            end

            local level = rawAttrs.level or 1
            local mutation = rawAttrs.mutation or nil
            local trait = rawAttrs.trait or nil
            local variant = resolvedVariant or meta.variant or rawAttrs.variant or "Normal"

            local resolvedRarity = meta.rarity or meta.Rarity or "Common"
            table.insert(units, {
                GUID = tostring(guid),
                Name = rawName,
                Meta = meta,
                Rarity = resolvedRarity,
                BaseOdds = numChance,
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

    if #units == 0 and rawCount > 0 then
        warn(string.format("[GENESIS AUTO EQUIP] Warning: %d items in rawInventory but 0 parsed! Check name/___X format.", rawCount))
    end

    return units
end

function AutoEquipModule.CalculateUnitOdds(unitObj)
    local meta = unitObj.Meta
    if not meta then return 0, "1 in 1" end

    local baseOdds = unitObj.BaseOdds or 1
    if baseOdds <= 1 then
        local rawCh = meta.chance or meta.Chance or meta.odds or meta.Odds
        if type(rawCh) == "function" then
            local ok, res = pcall(rawCh)
            if ok and type(res) == "number" then baseOdds = res end
        elseif type(rawCh) == "number" then
            baseOdds = rawCh
        end
    end

    if baseOdds <= 1 and unitObj.Rarity then
        local rank = RARITY_RANKS[unitObj.Rarity] or 1
        baseOdds = math.floor(10 ^ rank)
    end

    local finalOdds = baseOdds
    local formatted = AutoEquipModule.FormatOdds(finalOdds)
    return finalOdds, formatted
end

-- --- Slot & Remote Actions ---
function AutoEquipModule.UnequipSlot(slotId)
    local slotNum = tonumber(slotId)
    local slotStr = tostring(slotId)

    local rf = ReplicatedStorage:FindFirstChild("Network") and ReplicatedStorage.Network:FindFirstChild("UnitService") and ReplicatedStorage.Network.UnitService:FindFirstChild("RF") and ReplicatedStorage.Network.UnitService.RF:FindFirstChild("Unequip")
    if rf and rf:IsA("RemoteFunction") then
        if slotNum then
            local ok, res = pcall(function() return rf:InvokeServer(slotNum) end)
            if ok and res == true then return true end
        end
        local ok2, res2 = pcall(function() return rf:InvokeServer(slotStr) end)
        if ok2 and res2 == true then return true end
    end

    local ucMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitController
    if ucMod then
        local ok, uc = pcall(require, ucMod)
        if ok and uc and uc.Unequip then
            if slotNum then
                local s, r = pcall(function() return uc:Unequip(slotNum) end)
                if s and r == true then return true end
            end
            local s2, r2 = pcall(function() return uc:Unequip(slotStr) end)
            if s2 and r2 == true then return true end
        end
    end

    return false
end

function AutoEquipModule.PickAll()
    local currentSlots = AutoEquipModule.GetSlotsState()
    local totalPicked = 0
    for sIndex, _ in pairs(currentSlots) do
        local ok = AutoEquipModule.UnequipSlot(sIndex)
        if ok then
            totalPicked = totalPicked + 1
        end
        task.wait(0.04)
    end
    -- Also sweep all slots 1..14 just in case
    for s = 1, 14 do
        if not currentSlots[tostring(s)] then
            AutoEquipModule.UnequipSlot(s)
            task.wait(0.02)
        end
    end
    sendNotice("Pick All", string.format("Picked up all %d units to inventory!", totalPicked))
    return totalPicked
end

function AutoEquipModule.EquipUnitToSlot(slotId, unitGuid)
    local slotNum = tonumber(slotId)
    local slotStr = tostring(slotId)

    local rf = ReplicatedStorage:FindFirstChild("Network") and ReplicatedStorage.Network:FindFirstChild("UnitService") and ReplicatedStorage.Network.UnitService:FindFirstChild("RF") and ReplicatedStorage.Network.UnitService.RF:FindFirstChild("Equip")
    if rf and rf:IsA("RemoteFunction") then
        if slotNum then
            local ok1, res1 = pcall(function() return rf:InvokeServer(slotNum, unitGuid) end)
            if ok1 and res1 == true then return true end
            local ok2, res2 = pcall(function() return rf:InvokeServer(unitGuid, slotNum) end)
            if ok2 and res2 == true then return true end
        end
        local ok3, res3 = pcall(function() return rf:InvokeServer(slotStr, unitGuid) end)
        if ok3 and res3 == true then return true end
        local ok4, res4 = pcall(function() return rf:InvokeServer(unitGuid, slotStr) end)
        if ok4 and res4 == true then return true end
        local ok5, res5 = pcall(function() return rf:InvokeServer(unitGuid) end)
        if ok5 and res5 == true then return true end
    end

    local ucMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitController
    if ucMod then
        local ok, uc = pcall(require, ucMod)
        if ok and uc and uc.Equip then
            if slotNum then
                local s1, r1 = pcall(function() return uc:Equip(slotNum, unitGuid) end)
                if s1 and r1 == true then return true end
                local s2, r2 = pcall(function() return uc:Equip(unitGuid, slotNum) end)
                if s2 and r2 == true then return true end
            end
            local s3, r3 = pcall(function() return uc:Equip(slotStr, unitGuid) end)
            if s3 and r3 == true then return true end
            local s4, r4 = pcall(function() return uc:Equip(unitGuid, slotStr) end)
            if s4 and r4 == true then return true end
            local s5, r5 = pcall(function() return uc:Equip(unitGuid) end)
            if s5 and r5 == true then return true end
        end
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
            local rName = u.Rarity or (u.Meta and u.Meta.rarity) or "Common"
            if rarityAllowed[rName] ~= false then
                local oddsNum, oddsFmt = AutoEquipModule.CalculateUnitOdds(u)
                u.Odds = oddsNum
                u.FormattedOdds = oddsFmt
                u.Rarity = rName
                u.RarityRank = RARITY_RANKS[rName] or 1
                table.insert(rankedUnits, u)
            end
        end

        table.sort(rankedUnits, function(a, b)
            local rankA = a.RarityRank or 1
            local rankB = b.RarityRank or 1
            if rankA ~= rankB then
                return rankA > rankB
            end
            if a.Odds ~= b.Odds then
                return a.Odds > b.Odds
            end
            return (a.Level or 1) > (b.Level or 1)
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
                -- If this target unit is currently equipped in another slot, unequip it from that slot first
                for sIndex, sGuid in pairs(currentSlots) do
                    if sGuid == targetUnit.GUID and sIndex ~= targetSlotStr then
                        AutoEquipModule.UnequipSlot(tonumber(sIndex) or sIndex)
                        currentSlots[sIndex] = nil
                        task.wait(0.05)
                        break
                    end
                end

                -- Force unequip whatever unit is currently in target slot to overwrite it
                if currentUnitInSlot then
                    AutoEquipModule.UnequipSlot(i)
                    currentSlots[targetSlotStr] = nil
                    task.wait(0.05)
                end

                local ok = AutoEquipModule.EquipUnitToSlot(i, targetUnit.GUID)
                if ok then
                    equippedCount = equippedCount + 1
                    currentSlots[targetSlotStr] = targetUnit.GUID
                else
                    -- Fallback attempt string slot
                    local okFallback = AutoEquipModule.EquipUnitToSlot(targetSlotStr, targetUnit.GUID)
                    if okFallback then
                        equippedCount = equippedCount + 1
                        currentSlots[targetSlotStr] = targetUnit.GUID
                    end
                end
                task.wait(0.08)
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
