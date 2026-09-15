local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local logLines = {}
local function log(...)
    local args = {...}
    local strList = {}
    for i = 1, #args do
        strList[i] = tostring(args[i])
    end
    local line = table.concat(strList, " ")
    table.insert(logLines, line)
    print(line)
end

log("==================================================")
log("[GENESIS DIAG V11] LIVE EQUIP & UNEQUIP REMOTE PROBE")
log("==================================================")

-- [1] Inspect Remotes in UnitService and PlotService
local unitRF = ReplicatedStorage:FindFirstChild("Network") and ReplicatedStorage.Network:FindFirstChild("UnitService") and ReplicatedStorage.Network.UnitService:FindFirstChild("RF")
if unitRF then
    log("UnitService.RF children:")
    for _, ch in ipairs(unitRF:GetChildren()) do
        log("  RF name:", ch.Name, "ClassName:", ch.ClassName)
    end
else
    log("UnitService.RF not found!")
end

local plotRE = ReplicatedStorage:FindFirstChild("Network") and ReplicatedStorage.Network:FindFirstChild("PlotService") and ReplicatedStorage.Network.PlotService:FindFirstChild("RE")
if plotRE then
    log("PlotService.RE children:")
    for _, ch in ipairs(plotRE:GetChildren()) do
        log("  RE name:", ch.Name, "ClassName:", ch.ClassName)
    end
end

-- [2] Check current equipped units in Slots
local DataController = nil
pcall(function()
    DataController = require(ReplicatedStorage.Framework.Features.Data.DataController)
end)

local currentSlots = {}
local rawInv = nil
if DataController then
    local dcC = rawget(DataController, "___C")
    if dcC and rawget(dcC, "Slots") then
        local slotsNode = rawget(dcC, "Slots")
        local rawSlots = rawget(slotsNode, "___C")
        if rawSlots and type(rawSlots) == "table" then
            for sIndex, sData in pairs(rawSlots) do
                local sC = rawget(sData, "___C")
                local uid = nil
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
                    if type(sX) == "table" then uid = rawget(sX, "unitId") end
                end
                if uid then
                    currentSlots[tostring(sIndex)] = tostring(uid)
                    log(string.format("  Current Slot [%s] -> unitId: %s", tostring(sIndex), tostring(uid)))
                else
                    log(string.format("  Current Slot [%s] -> (empty)", tostring(sIndex)))
                end
            end
        end
    end

    if dcC and rawget(dcC, "Inventory") then
        local invNode = rawget(dcC, "Inventory")
        rawInv = rawget(invNode, "___C")
    end
end

-- [3] Find first target unit (Okarin / Gon / Killer) in inventory
local targetGuid = nil
local targetName = nil
if rawInv then
    for guid, itemNode in pairs(rawInv) do
        local rawName = nil
        local itemC = rawget(itemNode, "___C")
        if type(itemC) == "table" then
            local nameNode = rawget(itemC, "name")
            if type(nameNode) == "table" then
                local xData = rawget(nameNode, "___X")
                if type(xData) == "table" then rawName = rawget(xData, "name") end
            end
        end
        if not rawName then
            local itemX = rawget(itemNode, "___X")
            if type(itemX) == "table" then rawName = rawget(itemX, "name") end
        end

        if rawName and (string.find(rawName, "Okarin") or string.find(rawName, "Gon") or string.find(rawName, "Killer")) then
            targetGuid = tostring(guid)
            targetName = rawName
            break
        end
    end
end

log(string.format("Selected Test Unit: '%s' [GUID %s]", tostring(targetName), tostring(targetGuid)))

-- [4] Test calling Unequip and Equip with different arg orders
if unitRF and targetGuid then
    local rfEquip = unitRF:FindFirstChild("Equip")
    local rfUnequip = unitRF:FindFirstChild("Unequip")
    
    log("----------------------------------------")
    log("Testing Unequip RF on Slot 1:")
    if rfUnequip then
        -- Test slot 1 (string vs number)
        local ok1, res1 = pcall(function() return rfUnequip:InvokeServer(1) end)
        log("  InvokeServer(1) -> ok:", ok1, "res:", tostring(res1))
        local ok2, res2 = pcall(function() return rfUnequip:InvokeServer("1") end)
        log("  InvokeServer('1') -> ok:", ok2, "res:", tostring(res2))
    end

    log("----------------------------------------")
    log("Testing Equip RF on Slot 1 with target unit:")
    if rfEquip then
        -- Test (slot, guid) vs (guid, slot) vs (guid)
        local okA, resA = pcall(function() return rfEquip:InvokeServer(1, targetGuid) end)
        log("  InvokeServer(1, guid) -> ok:", okA, "res:", tostring(resA))
        local okB, resB = pcall(function() return rfEquip:InvokeServer("1", targetGuid) end)
        log("  InvokeServer('1', guid) -> ok:", okB, "res:", tostring(resB))
        local okC, resC = pcall(function() return rfEquip:InvokeServer(targetGuid, 1) end)
        log("  InvokeServer(guid, 1) -> ok:", okC, "res:", tostring(resC))
        local okD, resD = pcall(function() return rfEquip:InvokeServer(targetGuid, "1") end)
        log("  InvokeServer(guid, '1') -> ok:", okD, "res:", tostring(resD))
        local okE, resE = pcall(function() return rfEquip:InvokeServer(targetGuid) end)
        log("  InvokeServer(guid) -> ok:", okE, "res:", tostring(resE))
    end
end

-- [5] Test UnitController client module if exists
log("----------------------------------------")
log("Checking UnitController client methods:")
pcall(function()
    local ucMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitController
    if ucMod then
        local uc = require(ucMod)
        log("UnitController keys:")
        for k, v in pairs(uc) do
            log("  UC key:", tostring(k), "type:", type(v))
        end
    end
end)

log("==================================================")
log("[GENESIS DIAG V11] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V11.txt"
if writefile then
    pcall(function() writefile(fileName, fullOutput) end)
    print("[GENESIS] Log saved to: " .. fileName)
end
