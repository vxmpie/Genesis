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
log("[GENESIS DIAG V5] LOGGING TO FILE PROBE")
log("==================================================")

local ClientData = nil
pcall(function()
    ClientData = require(ReplicatedStorage.Packages.Data.Client)
end)
local DataController = nil
pcall(function()
    DataController = require(ReplicatedStorage.Framework.Features.Data.DataController)
end)

log("[1] ClientData loaded:", ClientData ~= nil)
if ClientData then
    for k, v in pairs(ClientData) do
        log("  ClientData key:", k, "type:", type(v))
    end
    
    local ok, res = pcall(function() return ClientData:get() end)
    log("  ClientData:get() -> ok:", ok, "type:", type(res))
    if ok and type(res) == "table" then
        for k, _ in pairs(res) do
            log("    root key:", k)
        end
    end
    
    local okInv, resInv = pcall(function() return ClientData:get("Inventory") end)
    log("  ClientData:get('Inventory') -> ok:", okInv, "type:", type(resInv))
    if okInv and type(resInv) == "table" then
        local count = 0
        for guid, item in pairs(resInv) do
            count = count + 1
            if count <= 5 then
                log("    [Inv Item] guid:", guid, "type:", type(item))
                if type(item) == "table" then
                    for ik, iv in pairs(item) do
                        log("      item key:", ik, "valType:", type(iv), "val:", tostring(iv))
                    end
                end
            end
        end
        log("    Total Inv Items via ClientData:get('Inventory'):", count)
    end
end

log("--------------------------------------------------")
log("[2] Inspecting Data.Value Internal Structure")
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
        local nameNode = rawget(itemNode, "name")
        log("  nameNode:", tostring(nameNode), "type:", type(nameNode))
        if type(nameNode) == "table" then
            for k, v in pairs(nameNode) do
                log("    nameNode raw key:", k, "val:", tostring(v), "type:", type(v))
            end
            local cNode = rawget(nameNode, "___C")
            log("    nameNode.___C:", tostring(cNode), "type:", type(cNode))
            if type(cNode) == "table" then
                for k, v in pairs(cNode) do
                    log("      cNode key:", k, "val:", tostring(v), "type:", type(v))
                    if type(v) == "table" then
                        for subK, subV in pairs(v) do
                            log("        subKey:", subK, "val:", tostring(subV), "type:", type(subV))
                        end
                    end
                end
            end
        end
        
        if type(nameNode) == "table" and type(nameNode.get) == "function" and debug and debug.getupvalues then
            local u = debug.getupvalues(nameNode.get)
            log("    nameNode.get upvalues count:", #u)
            for i, uv in ipairs(u) do
                log("      upval #" .. i .. ":", tostring(uv), "type:", type(uv))
            end
        end
        if sampleCount >= 2 then
            break
        end
    end
end

log("==================================================")
log("[GENESIS DIAG V5] COMPLETED")
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
else
    print("[GENESIS] writefile is not supported in this executor environment")
end
