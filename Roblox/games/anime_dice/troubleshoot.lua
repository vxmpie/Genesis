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
log("[GENESIS DIAG V12] UNITCONTROLLER EQUIP DEEP PROBE")
log("==================================================")

local targetGuid = "abedb4ae-f150-4bfb-ac12-e5ae44928f23"
local DataController = nil
pcall(function()
    DataController = require(ReplicatedStorage.Framework.Features.Data.DataController)
end)

if DataController then
    local dcC = rawget(DataController, "___C")
    if dcC and rawget(dcC, "Inventory") then
        local invNode = rawget(dcC, "Inventory")
        local rawInv = rawget(invNode, "___C")
        if rawInv then
            for guid, itemNode in pairs(rawInv) do
                local itemC = rawget(itemNode, "___C")
                local nameNode = itemC and rawget(itemC, "name")
                local xData = nameNode and rawget(nameNode, "___X")
                local rawName = (type(xData) == "table" and rawget(xData, "name")) or (type(xData) == "string" and xData)
                if rawName and (string.find(rawName, "Okarin") or string.find(rawName, "Gon") or string.find(rawName, "Killer")) then
                    targetGuid = tostring(guid)
                    log(string.format("Selected Target Unit: %s [GUID %s]", rawName, targetGuid))
                    break
                end
            end
        end
    end
end

-- [1] Inspect UnitController module
local ucMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitController
if ucMod then
    local uc = require(ucMod)
    log("UnitController found. Testing uc:Equip directly:")

    -- Inspect uc.Equip constants and upvalues if debug library exists
    if debug and debug.getupvalues and uc.Equip then
        log("Inspecting uc.Equip upvalues:")
        for i, v in ipairs(debug.getupvalues(uc.Equip)) do
            log("  upval #" .. i .. ":", tostring(v), "type:", type(v))
        end
    end
    if debug and debug.getconstants and uc.Equip then
        log("Inspecting uc.Equip constants:")
        for i, c in ipairs(debug.getconstants(uc.Equip)) do
            log("  const #" .. i .. ":", tostring(c))
        end
    end

    -- Test calling uc:Equip
    log("Calling uc:Equip(1, targetGuid):")
    local ok1, res1 = pcall(function() return uc:Equip(1, targetGuid) end)
    log("  uc:Equip(1, guid) -> ok:", ok1, "res:", tostring(res1))

    log("Calling uc:Equip(targetGuid, 1):")
    local ok2, res2 = pcall(function() return uc:Equip(targetGuid, 1) end)
    log("  uc:Equip(guid, 1) -> ok:", ok2, "res:", tostring(res2))

    log("Calling uc:Equip(targetGuid):")
    local ok3, res3 = pcall(function() return uc:Equip(targetGuid) end)
    log("  uc:Equip(guid) -> ok:", ok3, "res:", tostring(res3))

    -- Check if UnitController has Unequip
    if uc.Unequip then
        log("Calling uc:Unequip(1):")
        local oku, resu = pcall(function() return uc:Unequip(1) end)
        log("  uc:Unequip(1) -> ok:", oku, "res:", tostring(resu))
    end
end

-- [2] Check RemoteFunction Equip error or signature
local rfEquip = ReplicatedStorage:FindFirstChild("Network") and ReplicatedStorage.Network:FindFirstChild("UnitService") and ReplicatedStorage.Network.UnitService:FindFirstChild("RF") and ReplicatedStorage.Network.UnitService.RF:FindFirstChild("Equip")
if rfEquip then
    log("----------------------------------------")
    log("Detailed RF Equip testing:")
    -- Maybe slot 1 is locked or occupied? Let's check Slot 14 or first empty slot
    for testSlot = 1, 14 do
        local ok, res = pcall(function() return rfEquip:InvokeServer(testSlot, targetGuid) end)
        if res == true then
            log(string.format("SUCCESS!! InvokeServer(%d, guid) returned true!", testSlot))
            break
        end
    end
    for testSlot = 1, 14 do
        local ok, res = pcall(function() return rfEquip:InvokeServer(targetGuid, testSlot) end)
        if res == true then
            log(string.format("SUCCESS!! InvokeServer(guid, %d) returned true!", testSlot))
            break
        end
    end
end

log("==================================================")
log("[GENESIS DIAG V12] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V12.txt"
if writefile then
    pcall(function() writefile(fileName, fullOutput) end)
    print("[GENESIS] Log saved to: " .. fileName)
end
