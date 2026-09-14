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
print("[GENESIS DIAG] STARTING ANIME DICE DEEP DIAGNOSTIC")
print("==================================================")

local DataController, ClientData, UnitConfig, UnitController, PlotController
pcall(function() DataController = require(ReplicatedStorage.Framework.Features.Data.DataController) end)
pcall(function() ClientData = require(ReplicatedStorage.Packages.Data.Client) end)
pcall(function() UnitConfig = require(ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitConfig) end)
pcall(function() UnitController = require(ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitController) end)
pcall(function() PlotController = require(ReplicatedStorage.Framework.Features.Plot.PlotController) end)

print("[1] Modules Loaded:")
print("  DataController:", DataController ~= nil)
print("  ClientData:", ClientData ~= nil)
print("  UnitConfig:", UnitConfig ~= nil)
print("  UnitController:", UnitController ~= nil)
print("  PlotController:", PlotController ~= nil)

local rawInv = nil
if DataController and DataController.___C and DataController.___C.Inventory then
    rawInv = DataController.___C.Inventory.___C or DataController.___C.Inventory
end

if not rawInv and ClientData then
    pcall(function() rawInv = ClientData:get("Inventory") end)
    if not rawInv and ClientData.data and ClientData.data.___C and ClientData.data.___C.Inventory then
        rawInv = ClientData.data.___C.Inventory.___C or ClientData.data.___C.Inventory
    end
end

print("[2] Inventory Raw:", rawInv ~= nil, "Type:", type(rawInv))

local foundUnits = {}
if rawInv and type(rawInv) == "table" then
    local entries = (UnitConfig and UnitConfig.entries) or {}
    local totalKeys = 0
    for guid, itemObj in pairs(rawInv) do
        totalKeys = totalKeys + 1
        local raw = itemObj
        if type(itemObj) == "table" and itemObj.___C then
            raw = itemObj.___C
        end

        local name = raw.name or raw.entry or raw.Name or (itemObj.name and itemObj.name.___C)
        if type(name) == "table" and name.___C then name = name.___C end
        if type(name) == "table" and name.get then pcall(function() name = name:get() end) end

        local attrs = raw.attributes or (itemObj.attributes and itemObj.attributes.___C) or {}
        if type(attrs) == "table" and attrs.___C then attrs = attrs.___C end

        if totalKeys <= 3 then
            print(string.format("  [Sample Item %d] guid=%s, type=%s, name=%s", totalKeys, tostring(guid), type(raw), tostring(name)))
            if type(raw) == "table" then
                for k, v in pairs(raw) do
                    print("    key:", tostring(k), "valType:", type(v), "val:", tostring(v))
                end
            end
        end

        if type(name) == "string" and name ~= "" then
            local meta = entries[name]
            local odds = 0
            if meta and type(meta.chance) == "function" then
                local ok, res = pcall(meta.chance, attrs)
                if not ok or type(res) ~= "number" then
                    ok, res = pcall(meta.chance)
                end
                if ok and type(res) == "number" then
                    odds = (res > 0 and res < 1) and (1 / res) or res
                end
            end

            table.insert(foundUnits, {
                GUID = tostring(guid),
                Name = name,
                Odds = odds,
                MetaExists = (meta ~= nil)
            })
        end
    end
    print(string.format("  Total raw keys in Inventory table: %d", totalKeys))
end

table.sort(foundUnits, function(a, b) return a.Odds > b.Odds end)
print(string.format("[3] Scanned Units: %d", #foundUnits))
for i = 1, math.min(5, #foundUnits) do
    local u = foundUnits[i]
    print(string.format("  #%d: %s | Odds: %s | GUID: %s", i, u.Name, tostring(u.Odds), u.GUID))
end

local rawSlots = nil
if DataController and DataController.___C and DataController.___C.Slots then
    rawSlots = DataController.___C.Slots.___C or DataController.___C.Slots
end
print("[4] Slots in DataController:")
if rawSlots and type(rawSlots) == "table" then
    for k, v in pairs(rawSlots) do
        local slotData = v
        if type(v) == "table" and v.___C then slotData = v.___C end
        local uid = slotData.unitId or (v.unitId and v.unitId.___C)
        print(string.format("  Slot %s => unitId: %s", tostring(k), tostring(uid)))
    end
end

if #foundUnits > 0 then
    local testUnit = foundUnits[1]
    local targetSlot = "1"
    print(string.format("[5] Probing Equip Calls on #1: %s (GUID: %s)", testUnit.Name, testUnit.GUID))

    local rfEquip = ReplicatedStorage:FindFirstChild("Network") and ReplicatedStorage.Network:FindFirstChild("UnitService") and ReplicatedStorage.Network.UnitService:FindFirstChild("RF") and ReplicatedStorage.Network.UnitService.RF:FindFirstChild("Equip")

    local probes = {
        {"UnitController:Equip('1', guid)", function() return UnitController:Equip(targetSlot, testUnit.GUID) end},
        {"UnitController:Equip(1, guid)", function() return UnitController:Equip(1, testUnit.GUID) end},
        {"UnitController:Equip(guid, '1')", function() return UnitController:Equip(testUnit.GUID, targetSlot) end},
        {"UnitController:Equip(guid, 1)", function() return UnitController:Equip(testUnit.GUID, 1) end},
        {"UnitController:Equip(guid)", function() return UnitController:Equip(testUnit.GUID) end},
        {"RF.Equip:InvokeServer('1', guid)", function() return rfEquip:InvokeServer(targetSlot, testUnit.GUID) end},
        {"RF.Equip:InvokeServer(1, guid)", function() return rfEquip:InvokeServer(1, testUnit.GUID) end},
        {"RF.Equip:InvokeServer(guid, '1')", function() return rfEquip:InvokeServer(testUnit.GUID, targetSlot) end},
        {"RF.Equip:InvokeServer(guid, 1)", function() return rfEquip:InvokeServer(testUnit.GUID, 1) end},
        {"RF.Equip:InvokeServer(guid)", function() return rfEquip:InvokeServer(testUnit.GUID) end},
        {"PlotService.RE.EquipBest", function()
            local re = ReplicatedStorage.Network.PlotService.RE.EquipBest
            re:FireServer()
            return "Fired EquipBest"
        end}
    }

    for idx, p in ipairs(probes) do
        local name, fn = p[1], p[2]
        local ok, res = pcall(fn)
        print(string.format("  Probe [%d] %s => ok: %s | res: %s", idx, name, tostring(ok), tostring(res)))
        task.wait(0.25)
    end
end

print("==================================================")
print("[GENESIS DIAG] DONE! CHECK F9 CONSOLE")
print("==================================================")
notify("GENESIS DIAG", "Check F9 Developer Console for report!")
