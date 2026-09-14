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
log("[GENESIS DIAG V6] CLIENTDATA ERROR & ITEM PROBE")
log("==================================================")

local ClientData = nil
pcall(function()
    ClientData = require(ReplicatedStorage.Packages.Data.Client)
end)
local DataController = nil
pcall(function()
    DataController = require(ReplicatedStorage.Framework.Features.Data.DataController)
end)

log("[1] ClientData Method Errors:")
if ClientData then
    log("  hasLoaded:", tostring(ClientData.hasLoaded))
    log("  data field type:", type(ClientData.data))
    
    local ok1, err1 = pcall(function() return ClientData:get() end)
    log("  ClientData:get() error:", tostring(err1))
    
    local ok2, err2 = pcall(function() return ClientData:get("Inventory") end)
    log("  ClientData:get('Inventory') error:", tostring(err2))
    
    local ok3, err3 = pcall(function() return ClientData.get(ClientData.data, "Inventory") end)
    log("  ClientData.get(ClientData.data, 'Inventory'):", ok3, tostring(err3))

    if type(ClientData.data) == "table" then
        log("  Inspecting ClientData.data table:")
        for k, v in pairs(ClientData.data) do
            log("    ClientData.data key:", tostring(k), "type:", type(v), "val:", tostring(v))
        end
    end
end

log("--------------------------------------------------")
log("[2] Inspecting itemNode Raw Keys from DataController:")
local rawInv = nil
if DataController then
    local dcC = rawget(DataController, "___C")
    if dcC and rawget(dcC, "Inventory") then
        local invNode = rawget(dcC, "Inventory")
        rawInv = rawget(invNode, "___C")
    end
end

if rawInv then
    local sampleCount = 0
    for guid, itemNode in pairs(rawInv) do
        sampleCount = sampleCount + 1
        log("Sample GUID (" .. sampleCount .. "):", guid)
        log("  itemNode type:", type(itemNode), "val:", tostring(itemNode))
        if type(itemNode) == "table" then
            for k, v in pairs(itemNode) do
                log("  [pairs] key:", tostring(k), "type:", type(v), "val:", tostring(v))
                if type(v) == "table" then
                    local vC = rawget(v, "___C")
                    local vK = rawget(v, "___K")
                    log("    child ___K:", tostring(vK), "___C type:", type(vC), "val:", tostring(vC))
                end
            end
            
            local mt = getmetatable(itemNode)
            log("  itemNode metatable:", tostring(mt))
            if mt and type(mt) == "table" then
                for mk, mv in pairs(mt) do
                    log("    mt key:", tostring(mk), "type:", type(mv), "val:", tostring(mv))
                end
            end
            
            local itemC = rawget(itemNode, "___C")
            log("  itemNode.___C:", tostring(itemC), "type:", type(itemC))
            if type(itemC) == "table" then
                for ck, cv in pairs(itemC) do
                    log("    itemC key:", tostring(ck), "type:", type(cv), "val:", tostring(cv))
                end
            end
        end
        if sampleCount >= 2 then
            break
        end
    end
end

log("==================================================")
log("[GENESIS DIAG V6] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_" .. tostring(os.time()) .. ".txt"

if writefile then
    local ok, err = pcall(function()
        writefile(fileName, fullOutput)
    end)
    if ok then
        print("[GENESIS] Successfully saved log file to: " .. fileName)
    else
        print("[GENESIS] Failed to save file via writefile: " .. tostring(err))
    end
end
