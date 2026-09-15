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

function AutoEquipModule.GetMyPlot()
    local pcMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Plot.PlotController
    if pcMod then
        local ok, pc = pcall(require, pcMod)
        if ok and pc and pc.plot then
            return pc.plot
        end
    end
    local claimed = game:GetService("Workspace"):FindFirstChild("Plots") and game:GetService("Workspace").Plots:FindFirstChild("Claimed")
    if claimed and #claimed:GetChildren() > 0 then
        return claimed:GetChildren()[1]
    end
    return nil
end

function AutoEquipModule.GetUnlockedSlotsCount()
    local count = 0
    pcall(function()
        local myPlot = AutoEquipModule.GetMyPlot()
        if myPlot then
            local sFolder = myPlot:FindFirstChild("Slots")
            if sFolder then
                for _, sObj in ipairs(sFolder:GetChildren()) do
                    local num = tonumber(sObj.Name)
                    if num then
                        local prompt = sObj:FindFirstChildWhichIsA("ProximityPrompt", true)
                        if prompt and (prompt.ActionText == "Pick Up" or prompt.ActionText == "Place") then
                            if num > count then
                                count = num
                            end
                        end
                    end
                end
            end
        end
    end)
    if count and count > 0 then
        return count
    end
    return 12
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
                            if sX and type(sX) == "table" then
                                uid = rawget(sX, "unitId")
                            end
                        end

                        if uid and tostring(uid) ~= "" then
                            slotsMap[tostring(sIndex)] = tostring(uid)
                        end
                    end
                end
            end
        end
    end)
    return slotsMap
end

-- --- Inventory Hydration & Retrieval ---
function AutoEquipModule.GetInventoryUnits()
    local units = {}
    local rawInventory = nil

    -- [1] Always fetch the latest live table directly from DataController
    pcall(function()
        local dcMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Data.DataController
        if dcMod then
            local dc = require(dcMod)
            if dc.___X and type(dc.___X.Inventory) == "table" then
                rawInventory = dc.___X.Inventory
            end
            if not rawInventory then
                local dcC = rawget(dc, "___C")
                if dcC and rawget(dcC, "Inventory") then
                    local invNode = rawget(dcC, "Inventory")
                    rawInventory = rawget(invNode, "___C")
                end
            end
        end
    end)

    local unitConfig = AutoEquipModule.GetUnitConfig()
    local entries = (unitConfig and unitConfig.entries) or {}

    if rawInventory and type(rawInventory) == "table" then
        for guid, itemNode in pairs(rawInventory) do
            local rawName = nil
            local rawAttrs = {}
            local rawAmount = 1
            local rawLocked = false

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

                if rawAttrs.variant and tostring(rawAttrs.variant) ~= "" then
                    local vName = tostring(rawAttrs.variant)
                    local comboName = vName .. " " .. rawName
                    if entries[comboName] then
                        meta = entries[comboName]
                        resolvedVariant = vName
                    end
                end

                if not meta then
                    meta = entries[rawName]
                end

                local variantStr = resolvedVariant or rawAttrs.variant or "Normal"
                local mutationStr = rawAttrs.mutation or "Normal"
                local displayName = rawName
                if variantStr ~= "Normal" and not string.find(displayName, variantStr) then
                    displayName = variantStr .. " " .. displayName
                end
                if mutationStr ~= "Normal" and not string.find(displayName, mutationStr) then
                    displayName = mutationStr .. " " .. displayName
                end

                if meta then
                    table.insert(units, {
                        GUID = tostring(guid),
                        Name = displayName,
                        BaseName = rawName,
                        Meta = meta,
                        Attributes = rawAttrs,
                        Variant = variantStr,
                        Mutation = mutationStr,
                        Level = tonumber(rawAttrs.level) or 1,
                        Locked = (rawLocked == true),
                        Amount = tonumber(rawAmount) or 1,
                        Rarity = meta.rarity or "Common"
                    })
                else
                    local fallbackRarity = "Common"
                    for rName, _ in pairs(RARITY_RANKS) do
                        if string.find(rawName, rName) then
                            fallbackRarity = rName
                            break
                        end
                    end
                    table.insert(units, {
                        GUID = tostring(guid),
                        Name = displayName,
                        BaseName = rawName,
                        Meta = { rarity = fallbackRarity, chance = 1 },
                        Attributes = rawAttrs,
                        Variant = variantStr,
                        Mutation = mutationStr,
                        Level = tonumber(rawAttrs.level) or 1,
                        Locked = (rawLocked == true),
                        Amount = tonumber(rawAmount) or 1,
                        Rarity = fallbackRarity
                    })
                end
            end
        end
    end

    return units
end

-- --- True Odds Calculation ---
function AutoEquipModule.CalculateUnitOdds(unit)
    local meta = unit.Meta
    local baseOdds = 1

    if meta then
        if type(meta.chance) == "function" then
            local ok, val = pcall(meta.chance)
            if ok and type(val) == "number" and val > 0 then
                baseOdds = val
            end
        elseif type(meta.chance) == "number" and meta.chance > 0 then
            baseOdds = meta.chance
        end
    end

    local finalOdds = baseOdds

    -- Apply Mutation Multipliers (e.g. Silver = x10, Gold = x100, Rainbow = x1,000,000)
    local mutation = unit.Mutation or (unit.Attributes and unit.Attributes.mutation)
    if mutation and MUTATION_CHANCES[mutation] then
        finalOdds = finalOdds * MUTATION_CHANCES[mutation]
    end

    local formatted = AutoEquipModule.FormatOdds(finalOdds)
    return finalOdds, formatted
end

-- --- Slot Prompt & Teleport Actions ---
local function getSlotPrompt(slotId)
    local myPlot = AutoEquipModule.GetMyPlot()
    if not myPlot then return nil end
    local slotsFolder = myPlot:FindFirstChild("Slots")
    local slotModel = slotsFolder and slotsFolder:FindFirstChild(tostring(slotId))
    if slotModel then
        return slotModel:FindFirstChildWhichIsA("ProximityPrompt", true)
    end
    return nil
end

local function clickPutBackButton()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local putBack = pg and pg:FindFirstChild("Root") and pg.Root:FindFirstChild("HUD") and pg.Root.HUD:FindFirstChild("PutBack")
    if putBack and putBack.Visible then
        if firesignal then
            pcall(function() firesignal(putBack.Activated) end)
            pcall(function() firesignal(putBack.MouseButton1Click) end)
            pcall(function() firesignal(putBack.MouseButton1Up) end)
        end
        return true
    end
    return false
end

function AutoEquipModule.UnequipSlot(slotId)
    local slotNum = tonumber(slotId)
    if not slotNum then return false end

    -- Try Network RF first
    local rf = ReplicatedStorage:FindFirstChild("Network") and ReplicatedStorage.Network:FindFirstChild("UnitService") and ReplicatedStorage.Network.UnitService:FindFirstChild("RF") and ReplicatedStorage.Network.UnitService.RF:FindFirstChild("Unequip")
    if rf and rf:IsA("RemoteFunction") then
        local ok, res = pcall(function() return rf:InvokeServer(slotNum) end)
        if ok and res == true then return true end
    end

    -- Physical Prompt Pick Up & PutBack execution
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local prompt = getSlotPrompt(slotNum)
    if hrp and prompt and fireproximityprompt then
        local pPart = prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent.Parent
        local pPos = (pPart and pPart:IsA("BasePart")) and pPart.Position or Vector3.zero

        local origCF = hrp.CFrame
        hrp.CFrame = CFrame.new(pPos + Vector3.new(0, 3, 3))
        task.wait(0.2)

        if prompt.ActionText == "Pick Up" and prompt.Enabled then
            fireproximityprompt(prompt)
            task.wait(0.3)
            clickPutBackButton()
            task.wait(0.2)
        end

        hrp.CFrame = origCF
        return true
    end

    return false
end

function AutoEquipModule.PickAll()
    local myPlot = AutoEquipModule.GetMyPlot()
    local totalPicked = 0

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not myPlot or not hrp or not fireproximityprompt then
        for s = 1, 14 do
            AutoEquipModule.UnequipSlot(s)
            task.wait(0.04)
        end
        sendNotice("Pick All", "Sent unequip request for all slots!")
        return 14
    end

    local origCF = hrp.CFrame
    local slotsFolder = myPlot:FindFirstChild("Slots")
    if slotsFolder then
        for s = 1, 14 do
            local sModel = slotsFolder:FindFirstChild(tostring(s))
            local prompt = sModel and sModel:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt and prompt.ActionText == "Pick Up" and prompt.Enabled then
                local pPart = prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent.Parent
                local pPos = (pPart and pPart:IsA("BasePart")) and pPart.Position or Vector3.zero

                hrp.CFrame = CFrame.new(pPos + Vector3.new(0, 3, 3))
                task.wait(0.15)

                if prompt.ActionText == "Pick Up" and prompt.Enabled then
                    fireproximityprompt(prompt)
                    task.wait(0.25)
                    clickPutBackButton()
                    task.wait(0.15)
                    totalPicked = totalPicked + 1
                end
            end
        end
    end

    hrp.CFrame = origCF
    sendNotice("Pick All", string.format("Picked up all %d units to inventory!", totalPicked))
    return totalPicked
end

-- --- Backpack Unit Selection & Placing ---
local function holdUnitFromBackpack(targetGuid)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local root = pg and pg:FindFirstChild("Root")
    local bpMenu = root and root:FindFirstChild("Menus") and root.Menus:FindFirstChild("Backpack")
    local scroller = bpMenu and bpMenu:FindFirstChild("ScrollingFrame", true)

    if scroller and firesignal and getconnections then
        for _, btn in ipairs(scroller:GetChildren()) do
            if btn:IsA("ImageButton") or btn:IsA("TextButton") then
                local conns = getconnections(btn.Activated)
                for _, conn in ipairs(conns) do
                    if conn.Function and debug and debug.getupvalues then
                        local ups = debug.getupvalues(conn.Function)
                        -- Up #4 is the exact unit GUID string
                        if ups[4] and tostring(ups[4]) == tostring(targetGuid) then
                            firesignal(btn.Activated)
                            task.wait(0.2)
                            return true
                        end
                        -- General fallback check across all upvalues
                        for _, uval in ipairs(ups) do
                            if tostring(uval) == tostring(targetGuid) then
                                firesignal(btn.Activated)
                                task.wait(0.2)
                                return true
                            end
                        end
                    end
                end
            end
        end
    end

    -- Fallback: click first button if specific GUID not found in scroller
    if scroller and firesignal then
        local firstBtn = scroller:FindFirstChildWhichIsA("ImageButton")
        if firstBtn then
            firesignal(firstBtn.Activated)
            task.wait(0.2)
            return true
        end
    end

    return false
end

function AutoEquipModule.EquipUnitToSlot(slotId, unitGuid)
    local slotNum = tonumber(slotId)
    if not slotNum then return false end

    -- [1] Try RemoteFunction Equip first
    local rf = ReplicatedStorage:FindFirstChild("Network") and ReplicatedStorage.Network:FindFirstChild("UnitService") and ReplicatedStorage.Network.UnitService:FindFirstChild("RF") and ReplicatedStorage.Network.UnitService.RF:FindFirstChild("Equip")
    if rf and rf:IsA("RemoteFunction") then
        local ok, res = pcall(function() return rf:InvokeServer(slotNum, unitGuid) end)
        if ok and res == true then return true end
    end

    -- [2] Physical Prompt & Backpack Equip execution
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local prompt = getSlotPrompt(slotNum)

    if hrp and prompt and fireproximityprompt then
        local pPart = prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent.Parent
        local pPos = (pPart and pPart:IsA("BasePart")) and pPart.Position or Vector3.zero

        local origCF = hrp.CFrame
        hrp.CFrame = CFrame.new(pPos + Vector3.new(0, 3, 3))
        task.wait(0.2)

        -- If slot currently has another unit, pick it up and put back first
        if prompt.ActionText == "Pick Up" and prompt.Enabled then
            fireproximityprompt(prompt)
            task.wait(0.25)
            clickPutBackButton()
            task.wait(0.2)
        end

        -- Hold desired unit from backpack
        holdUnitFromBackpack(unitGuid)
        task.wait(0.3)

        -- Place held unit onto podium
        if prompt.ActionText == "Place" then
            if not prompt.Enabled then
                prompt.Enabled = true
            end
            fireproximityprompt(prompt)
            task.wait(0.35)
        end

        hrp.CFrame = origCF
        return (prompt.ActionText == "Pick Up")
    end

    return false
end

function AutoEquipModule.NativeEquipBest()
    local re = ReplicatedStorage:FindFirstChild("Network") and ReplicatedStorage.Network:FindFirstChild("PlotService") and ReplicatedStorage.Network.PlotService:FindFirstChild("RE") and ReplicatedStorage.Network.PlotService.RE:FindFirstChild("EquipBest")
    if re and re:IsA("RemoteEvent") then
        pcall(function() re:FireServer() end)
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

            local prompt = getSlotPrompt(i)
            local slotNeedsPlacement = false

            if prompt then
                if prompt.ActionText == "Place" then
                    slotNeedsPlacement = true
                elseif prompt.ActionText == "Pick Up" and currentUnitInSlot ~= targetUnit.GUID then
                    slotNeedsPlacement = true
                end
            else
                if currentUnitInSlot ~= targetUnit.GUID then
                    slotNeedsPlacement = true
                end
            end

            if slotNeedsPlacement then
                local ok = AutoEquipModule.EquipUnitToSlot(i, targetUnit.GUID)
                if ok then
                    equippedCount = equippedCount + 1
                    currentSlots[targetSlotStr] = targetUnit.GUID
                end
                task.wait(0.15)
            end

            if i <= 3 then
                table.insert(topReport, string.format("#%d %s (%s)", i, targetUnit.Name, targetUnit.FormattedOdds))
            end
        end

        local summaryMsg = string.format("Placed %d units! %s", equippedCount, table.concat(topReport, ", "))
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
