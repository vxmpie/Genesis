local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("==================================================")
print("[GENESIS DIAG V4] VALUE LEAF AND CLIENT PROBE")
print("==================================================")

local ClientData = nil
pcall(function()
    ClientData = require(ReplicatedStorage.Packages.Data.Client)
end)
local DataController = nil
pcall(function()
    DataController = require(ReplicatedStorage.Framework.Features.Data.DataController)
end)

print("[1] ClientData loaded:", ClientData ~= nil)
if ClientData then
    for k, v in pairs(ClientData) do
        print("  ClientData key:", k, "type:", type(v))
    end
    
    local ok, res = pcall(function() return ClientData:get() end)
    print("  ClientData:get() -> ok:", ok, "type:", type(res))
    if ok and type(res) == "table" then
        for k, _ in pairs(res) do
            print("    root key:", k)
        end
    end
    
    local okInv, resInv = pcall(function() return ClientData:get("Inventory") end)
    print("  ClientData:get('Inventory') -> ok:", okInv, "type:", type(resInv))
    if okInv and type(resInv) == "table" then
        local count = 0
        for guid, item in pairs(resInv) do
            count = count + 1
            if count <= 2 then
                print("    [Inv Item] guid:", guid, "type:", type(item))
                if type(item) == "table" then
                    for ik, iv in pairs(item) do
                        print("      item key:", ik, "valType:", type(iv), "val:", tostring(iv))
                    end
                end
            end
        end
        print("    Total Inv Items via ClientData:get('Inventory'):", count)
    end
end

print("--------------------------------------------------")
print("[2] Inspecting Data.Value Internal Structure")
local rawInv = nil
if DataController then
    local dcC = rawget(DataController, "___C")
    if dcC and rawget(dcC, "Inventory") then
        local invNode = rawget(dcC, "Inventory")
        rawInv = rawget(invNode, "___C")
    end
end

if rawInv then
    for guid, itemNode in pairs(rawInv) do
        print("Sample GUID:", guid)
        local nameNode = rawget(itemNode, "name")
        print("  nameNode:", tostring(nameNode), "type:", type(nameNode))
        if type(nameNode) == "table" then
            for k, v in pairs(nameNode) do
                print("    nameNode raw key:", k, "val:", tostring(v), "type:", type(v))
            end
            local cNode = rawget(nameNode, "___C")
            print("    nameNode.___C:", tostring(cNode), "type:", type(cNode))
            if type(cNode) == "table" then
                for k, v in pairs(cNode) do
                    print("      cNode key:", k, "val:", tostring(v), "type:", type(v))
                    if type(v) == "table" then
                        for subK, subV in pairs(v) do
                            print("        subKey:", subK, "val:", tostring(subV), "type:", type(subV))
                        end
                    end
                end
            end
        end
        
        if type(nameNode) == "table" and type(nameNode.get) == "function" and debug and debug.getupvalues then
            local u = debug.getupvalues(nameNode.get)
            print("    nameNode.get upvalues count:", #u)
            for i, uv in ipairs(u) do
                print("      upval #" .. i .. ":", tostring(uv), "type:", type(uv))
            end
        end
        break
    end
end

print("==================================================")
print("[GENESIS DIAG V4] COMPLETED")
print("==================================================")
