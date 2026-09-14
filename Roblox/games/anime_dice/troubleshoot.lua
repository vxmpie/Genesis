local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local DataController = require(ReplicatedStorage.Framework.Features.Data.DataController)

print("==================================================")
print("[GENESIS DIAG] DEEP VALUE INNER DUMP")
print("==================================================")

local inv = DataController.___C.Inventory.___C or DataController.___C.Inventory
local sampleGuid, sampleItem = nil, nil
for g, it in pairs(inv) do
    sampleGuid, sampleItem = g, it
    break
end

local function dumpTable(tbl, name, maxDepth, currentDepth)
    currentDepth = currentDepth or 0
    if currentDepth > maxDepth then return end
    local indent = string.rep("  ", currentDepth)

    if type(tbl) ~= "table" then
        print(string.format("%s%s = (%s) %s", indent, name, type(tbl), tostring(tbl)))
        return
    end

    print(string.format("%s%s (table):", indent, name))
    for k, v in pairs(tbl) do
        local kStr = tostring(k)
        if kStr ~= "___P" and kStr ~= "___X" and kStr ~= "_P" and kStr ~= "_X" then
            if type(v) == "table" then
                if currentDepth < maxDepth then
                    dumpTable(v, kStr, maxDepth, currentDepth + 1)
                else
                    print(string.format("%s  %s = (table) %s", indent, kStr, tostring(v)))
                end
            else
                print(string.format("%s  %s = (%s) %s", indent, kStr, type(v), tostring(v)))
            end
        end
    end
end

if sampleItem then
    print("--- [1] sampleItem.name Deep Dump ---")
    dumpTable(sampleItem.name, "nameObj", 4)

    print("--- [2] sampleItem.attributes Deep Dump ---")
    dumpTable(sampleItem.attributes, "attrObj", 4)
end

print("--- [3] Slots[1].unitId Deep Dump ---")
local rawSlots = DataController.___C.Slots.___C or DataController.___C.Slots
for slotId, slotVal in pairs(rawSlots) do
    if type(slotVal) == "table" and slotVal.unitId then
        dumpTable(slotVal.unitId, "slot1_unitId", 4)
        break
    end
end

print("==================================================")
