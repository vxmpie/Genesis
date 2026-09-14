local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "DIAG",
            Text = tostring(text or ""),
            Duration = 5
        })
    end)
end

print("==================================================")
print("[GENESIS DIAG] ANIME DICE VALUE EXTRACTION PROBE")
print("==================================================")

local DataController = require(ReplicatedStorage.Framework.Features.Data.DataController)
local DataClient = require(ReplicatedStorage.Packages.Data.Client)
local UnitConfig = require(ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitConfig)
local UnitController = require(ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitController)

local sampleItem = nil
if DataController and DataController.___C and DataController.___C.Inventory then
    local inv = DataController.___C.Inventory.___C or DataController.___C.Inventory
    for guid, it in pairs(inv) do
        sampleItem = it
        print("Sample GUID:", guid)
        break
    end
end

if sampleItem and type(sampleItem) == "table" then
    print("[1] Inspecting sampleItem.name:")
    local nameVal = sampleItem.name
    print("  type(nameVal):", type(nameVal))
    if type(nameVal) == "table" then
        for k, v in pairs(nameVal) do
            print("    nameVal key:", tostring(k), "type:", type(v), "val:", tostring(v))
        end
        local ok, gRes = pcall(function() return nameVal:get() end)
        print("    nameVal:get() -> ok:", ok, "res:", tostring(gRes))
        if nameVal.___C ~= nil then
            print("    nameVal.___C -> type:", type(nameVal.___C), "val:", tostring(nameVal.___C))
        end
    end

    print("[2] Inspecting sampleItem.attributes:")
    local attrVal = sampleItem.attributes
    print("  type(attrVal):", type(attrVal))
    if type(attrVal) == "table" then
        for k, v in pairs(attrVal) do
            print("    attrVal key:", tostring(k), "type:", type(v), "val:", tostring(v))
        end
        local ok, gRes = pcall(function() return attrVal:get() end)
        print("    attrVal:get() -> ok:", ok, "res:", tostring(gRes))
        if attrVal.___C ~= nil then
            print("    attrVal.___C -> type:", type(attrVal.___C))
            if type(attrVal.___C) == "table" then
                for ak, av in pairs(attrVal.___C) do
                    print("      attr.___C key:", tostring(ak), "valType:", type(av), "val:", tostring(av))
                end
            end
        end
    end
end

-- Inspect Slots unitId
print("[3] Inspecting Slots:")
local rawSlots = DataController.___C.Slots.___C or DataController.___C.Slots
for slotId, slotVal in pairs(rawSlots) do
    print("  Slot", tostring(slotId))
    if type(slotVal) == "table" then
        local uidVal = slotVal.unitId
        print("    unitId type:", type(uidVal))
        if type(uidVal) == "table" then
            for k, v in pairs(uidVal) do
                print("      uidVal key:", tostring(k), "valType:", type(v), "val:", tostring(v))
            end
            local ok, gRes = pcall(function() return uidVal:get() end)
            print("      uidVal:get() -> ok:", ok, "res:", tostring(gRes))
            if uidVal.___C ~= nil then
                print("      uidVal.___C -> type:", type(uidVal.___C), "val:", tostring(uidVal.___C))
            end
        end
    end
    break
end

notify("GENESIS DIAG", "Extraction probe finished! Check F9.")
