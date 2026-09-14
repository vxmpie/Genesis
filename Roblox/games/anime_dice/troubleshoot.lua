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
log("[GENESIS DIAG V7] LEAF VALUE RESOLUTION PROBE")
log("==================================================")

local DataController = nil
pcall(function()
    DataController = require(ReplicatedStorage.Framework.Features.Data.DataController)
end)

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
        log("----------------------------------------")
        log("Sample #" .. sampleCount .. " GUID: " .. tostring(guid))
        
        local itemC = rawget(itemNode, "___C")
        if type(itemC) == "table" then
            local nameNode = rawget(itemC, "name")
            local amountNode = rawget(itemC, "amount")
            local attrNode = rawget(itemC, "attributes")
            
            log("[1] Testing nameNode calls:")
            if nameNode then
                -- test __call: nameNode()
                local callOk, callRes = pcall(function() return nameNode() end)
                log("  nameNode() -> ok:", callOk, "res:", tostring(callRes), "type:", type(callRes))
                
                -- test nameNode:get()
                local getOk, getRes = pcall(function() return nameNode:get() end)
                log("  nameNode:get() -> ok:", getOk, "res:", tostring(getRes), "type:", type(getRes))
                
                -- test raw pairs inside nameNode
                for k, v in pairs(nameNode) do
                    log("  nameNode raw key:", tostring(k), "valType:", type(v), "val:", tostring(v))
                end
                
                -- test nameNode.___C contents
                local nameC = rawget(nameNode, "___C")
                log("  nameNode.___C type:", type(nameC), "val:", tostring(nameC))
                if type(nameC) == "table" then
                    for k, v in pairs(nameC) do
                        log("    nameC key:", tostring(k), "valType:", type(v), "val:", tostring(v))
                        if type(v) == "table" then
                            local subCallOk, subCallRes = pcall(function() return v() end)
                            log("      v() -> ok:", subCallOk, "res:", tostring(subCallRes))
                        end
                    end
                end
                
                -- test nameNode metatable
                local mt = getmetatable(nameNode)
                if mt and type(mt) == "table" then
                    for mk, mv in pairs(mt) do
                        log("  nameNode mt key:", tostring(mk), "valType:", type(mv))
                    end
                end
            end
            
            log("[2] Testing amountNode:")
            if amountNode then
                local aCallOk, aCallRes = pcall(function() return amountNode() end)
                local aGetOk, aGetRes = pcall(function() return amountNode:get() end)
                log("  amountNode() -> ok:", aCallOk, "res:", tostring(aCallRes))
                log("  amountNode:get() -> ok:", aGetOk, "res:", tostring(aGetRes))
            end
            
            log("[3] Testing attrNode (attributes):")
            if attrNode then
                local attrC = rawget(attrNode, "___C")
                log("  attrNode.___C type:", type(attrC))
                if type(attrC) == "table" then
                    for ak, av in pairs(attrC) do
                        log("    attr key:", tostring(ak), "valType:", type(av))
                        if type(av) == "table" then
                            local aCallOk, aCallRes = pcall(function() return av() end)
                            local aGetOk, aGetRes = pcall(function() return av:get() end)
                            log("      attr " .. tostring(ak) .. "() -> ok:", aCallOk, "res:", tostring(aCallRes))
                            log("      attr " .. tostring(ak) .. ":get() -> ok:", aGetOk, "res:", tostring(aGetRes))
                        end
                    end
                end
            end
        end
        
        if sampleCount >= 2 then
            break
        end
    end
end

log("==================================================")
log("[GENESIS DIAG V7] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_" .. tostring(os.time()) .. ".txt"

if writefile then
    local ok, err = pcall(function()
        writefile(fileName, fullOutput)
    end)
    if ok then
        print("[GENESIS] Successfully saved log file to: " .. fileName)
    end
end
