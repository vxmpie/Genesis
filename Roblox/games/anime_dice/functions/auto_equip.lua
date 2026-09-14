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

local loopThread = nil
local isProcessing = false
local lastScanResults = {}

local function sendNotice(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "GENESIS AUTO EQUIP",
            Text = text or "",
            Duration = 3
        })
    end)
end

local function safeUnwrap(val, depth)
    depth = depth or 0
    if depth > 10 then return val end
    if val == nil then return nil end
    if type(val) ~= "table" then return val end

    local ok, res = pcall(function()
        if type(val.get) == "function" then
            local g = val:get()
            if g ~= nil and g ~= val then
                return safeUnwrap(g, depth + 1)
            end
        end

        local rawC = rawget(val, "___C")
        if rawC ~= nil and rawC ~= val then
            return safeUnwrap(rawC, depth + 1)
        end

        local rawVal = rawget(val, "Value")
        if rawVal ~= nil and type(rawVal) ~= "function" and rawVal ~= val then
            return safeUnwrap(rawVal, depth + 1)
        end

        return nil
    end)

    if ok and res ~= nil then
        return res
    end

    return val
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
            local rawSlots = dc.___C and dc.___C.Slots and (dc.___C.Slots.___C or dc.___C.Slots)
            if rawSlots then
                local c = 0
                for _ in pairs(rawSlots) do
                    c = c + 1
                end
                return c
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
            local rawSlots = dc.___C and dc.___C.Slots and (dc.___C.Slots.___C or dc.___C.Slots)
            if rawSlots and type(rawSlots) == "table" then
                for sIndex, sData in pairs(rawSlots) do
                    local unwrappedSlot = safeUnwrap(sData)
                    if type(unwrappedSlot) == "table" then
                        local uid = safeUnwrap(rawget(unwrappedSlot, "unitId") or unwrappedSlot.unitId)
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
            if dc and dc.___C and dc.___C.Inventory then
                rawInventory = dc.___C.Inventory.___C or dc.___C.Inventory
            end
        end
    end)

    if not rawInventory or type(rawInventory) ~= "table" or next(rawInventory) == nil then
        pcall(function()
            local clientMod = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Data") and ReplicatedStorage.Packages.Data:FindFirstChild("Client")
            if clientMod then
                local clientData = require(clientMod)
                if clientData then
                    local inv = clientData:get("Inventory")
                    if inv then
                        rawInventory = inv.___C or inv
                    elseif clientData.data and clientData.data.___C and clientData.data.___C.Inventory then
                        rawInventory = clientData.data.___C.Inventory.___C or clientData.data.___C.Inventory
                    end
                end
            end
        end)
    end

    if not rawInventory or type(rawInventory) ~= "table" then
        warn("[GENESIS AUTO EQUIP] Warning: Could not locate Inventory data table!")
        return units
    end

    local unitConfig = AutoEquipModule.GetUnitConfig()
    local entries = (unitConfig and unitConfig.entries) or {}

    for guid, itemWrapper in pairs(rawInventory) do
        local item = safeUnwrap(itemWrapper)
        if type(item) == "table" then
            local rawName = safeUnwrap(rawget(item, "name") or item.name or rawget(item, "entry") or item.entry or rawget(item, "Name") or item.Name)
            local rawAttrs = safeUnwrap(rawget(item, "attributes") or item.attributes) or {}
            local rawAmount = safeUnwrap(rawget(item, "amount") or item.amount) or 1
            local rawLocked = safeUnwrap(rawget(item, "locked") or item.locked) or false

            if type(rawName) == "string" and rawName ~= "" then
                local meta = entries[rawName]
                local resolvedVariant = nil

                if not meta and type(rawAttrs) == "table" and rawAttrs.variant then
                    local vName = tostring(safeUnwrap(rawAttrs.variant))
                    local comboName = vName .. " " .. rawName
                    if entries[comboName] then
                        meta = entries[comboName]
                        resolvedVariant = vName
                    end
                end

                if meta then
                    local level = (type(rawAttrs) == "table" and safeUnwrap(rawAttrs.level)) or 1
                    local mutation = (type(rawAttrs) == "table" and safeUnwrap(rawAttrs.mutation)) or nil
                    local trait = (type(rawAttrs) == "table" and safeUnwrap(rawAttrs.trait)) or nil
                    local variant = resolvedVariant or meta.variant or (type(rawAttrs) == "table" and safeUnwrap(rawAttrs.variant)) or "Normal"

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
        end
    end

    return units
end

function AutoEquipModule.CalculateUnitOdds(unitObj)
    local meta = unitObj.Meta
    if not meta then return 0, "1 in 1" end

    local rarity = meta.rarity or "Common"
    local order = tonumber(meta.order) or 1
    local variant = unitObj.Variant or meta.variant or "Normal"
    local mutation = unitObj.Mutation
    local attrs = unitObj.Attributes or {}

    local exactChance = 0

    if type(meta.chance) == "function" then
        local ok, res = pcall(meta.chance, attrs)
        if not ok or type(res) ~= "number" then
            ok, res = pcall(meta.chance)
        end
        if ok and type(res) == "number" and res > 0 then
            exactChance = res
        end
    elseif type(meta.chance) == "number" and meta.chance > 0 then
        exactChance = meta.chance
    end

    if exactChance > 0 and exactChance < 1 then
        exactChance = 1 / exactChance
    end

    if exactChance > 0 then
        if mutation and MUTATION_CHANCES[mutation] and not string.find(string.lower(unitObj.Name), string.lower(mutation)) then
            exactChance = exactChance * MUTATION_CHANCES[mutation]
        end
    else
        local vMult = VARIANT_MULTIPLIERS[variant] or 1
        local mMult = (mutation and MUTATION_CHANCES[mutation]) or 1
        local base = math.pow(10, (order / 5.75)) * 1.5
        exactChance = base * vMult * mMult
    end

    local formatted = AutoEquipModule.FormatOdds(exactChance)
    return exactChance, formatted
end

function AutoEquipModule.UnequipSlot(slotId)
    local slotNum = tonumber(slotId)
    local slotStr = tostring(slotId)

    local ucMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitController
    if ucMod then
        local ok, uc = pcall(require, ucMod)
        if ok and uc and uc.Unequip then
            pcall(function() uc:Unequip(slotStr) end)
            if slotNum then pcall(function() uc:Unequip(slotNum) end) end
        end
    end

    local rf = ReplicatedStorage:FindFirstChild("Network") and ReplicatedStorage.Network:FindFirstChild("UnitService") and ReplicatedStorage.Network.UnitService:FindFirstChild("RF") and ReplicatedStorage.Network.UnitService.RF:FindFirstChild("Unequip")
    if rf and rf:IsA("RemoteFunction") then
        pcall(function() rf:InvokeServer(slotStr) end)
        if slotNum then pcall(function() rf:InvokeServer(slotNum) end) end
    end
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
            warn("[GENESIS AUTO EQUIP] 0 units found in inventory! Check if inventory is empty or locked.")
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
