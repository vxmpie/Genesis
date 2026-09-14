local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local DataController = require(ReplicatedStorage.Framework.Features.Data.DataController)

print("==================================================")
print("[GENESIS DIAG V3] RAWGET METATABLE BYPASS PROBE")
print("==================================================")

local rawInv = nil
local dcC = rawget(DataController, "___C")
if dcC then
    local invObj = rawget(dcC, "Inventory")
    if invObj then
        rawInv = rawget(invObj, "___C") or invObj
    end
end

local sampleGuid = nil
local sampleItem = nil
if rawInv and type(rawInv) == "table" then
    for g, it in pairs(rawInv) do
        sampleGuid = g
        sampleItem = it
        break
    end
end

print("Sample GUID: " .. tostring(sampleGuid))

local function inspectRaw(obj, label, depth)
    depth = depth or 0
    local indent = string.rep("  ", depth)
    if depth > 4 then
        return
    end

    if obj == nil then
        print(indent .. label .. " = nil")
        return
    end

    if type(obj) ~= "table" then
        print(indent .. label .. " = (" .. type(obj) .. ") " .. tostring(obj))
        return
    end

    print(indent .. label .. " (table " .. tostring(obj) .. "):")
    for k, v in pairs(obj) do
        local kStr = tostring(k)
        if kStr ~= "___P" and kStr ~= "___X" and kStr ~= "_P" and kStr ~= "_X" then
            if type(v) == "table" then
                inspectRaw(v, kStr, depth + 1)
            else
                print(indent .. "  " .. kStr .. " = (" .. type(v) .. ") " .. tostring(v))
            end
        end
    end
end

if sampleItem and type(sampleItem) == "table" then
    local nameField = rawget(sampleItem, "name") or sampleItem.name
    print("--- [1] sampleItem.name RAW DUMP ---")
    inspectRaw(nameField, "nameField", 0)

    local attrField = rawget(sampleItem, "attributes") or sampleItem.attributes
    print("--- [2] sampleItem.attributes RAW DUMP ---")
    inspectRaw(attrField, "attrField", 0)
end

local rawSlots = nil
if dcC then
    local slotsObj = rawget(dcC, "Slots")
    if slotsObj then
        rawSlots = rawget(slotsObj, "___C") or slotsObj
    end
end

if rawSlots and type(rawSlots) == "table" then
    for slotId, slotVal in pairs(rawSlots) do
        print("--- [3] Slots[" .. tostring(slotId) .. "].unitId RAW DUMP ---")
        local uidField = nil
        if type(slotVal) == "table" then
            uidField = rawget(slotVal, "unitId") or slotVal.unitId
        end
        inspectRaw(uidField, "unitIdField", 0)
        break
    end
end

print("==================================================")
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "GENESIS DIAG V3",
        Text = "V3 Raw Probe Complete! Check F9.",
        Duration = 5
    })
end)
