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
log("[GENESIS DIAG V8] UPVALUE & ROOT STORE INSPECTION")
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
    for guid, itemNode in pairs(rawInv) do
        log("Sample GUID: " .. tostring(guid))
        local itemC = rawget(itemNode, "___C")
        if type(itemC) == "table" then
            local nameNode = rawget(itemC, "name")
            if nameNode then
                -- [1] Inspect ___X (Root Store / State container)
                local xNode = rawget(nameNode, "___X")
                log("[1] nameNode.___X type:", type(xNode), "val:", tostring(xNode))
                if type(xNode) == "table" then
                    for xk, xv in pairs(xNode) do
                        log("  ___X key:", tostring(xk), "valType:", type(xv), "val:", tostring(xv))
                        if type(xv) == "table" then
                            local count = 0
                            for subK, subV in pairs(xv) do
                                count = count + 1
                                if count <= 10 then
                                    log("    subKey:", tostring(subK), "valType:", type(subV), "val:", tostring(subV))
                                end
                            end
                            log("    total sub-items in ___X." .. tostring(xk) .. ":", count)
                        end
                    end
                end
                
                -- [2] Inspect Metatable functions upvalues
                local mt = getmetatable(nameNode)
                if mt and type(mt) == "table" and debug and debug.getupvalues then
                    if type(mt.__call) == "function" then
                        log("[2] Inspecting mt.__call upvalues:")
                        local upvals = debug.getupvalues(mt.__call)
                        for i, uv in ipairs(upvals) do
                            log("  upval #" .. i .. ":", tostring(uv), "type:", type(uv))
                            if type(uv) == "table" then
                                for uk, uv2 in pairs(uv) do
                                    log("    table key:", tostring(uk), "valType:", type(uv2), "val:", tostring(uv2))
                                end
                            end
                        end
                    end
                    if type(mt.__index) == "function" then
                        log("[3] Inspecting mt.__index upvalues:")
                        local upvals = debug.getupvalues(mt.__index)
                        for i, uv in ipairs(upvals) do
                            log("  upval #" .. i .. ":", tostring(uv), "type:", type(uv))
                        end
                    end
                end
                
                -- [3] Inspect get() upvalues if get exists
                local getFunc = nameNode.get
                if type(getFunc) == "function" and debug and debug.getupvalues then
                    log("[4] Inspecting nameNode.get upvalues:")
                    local upvals = debug.getupvalues(getFunc)
                    for i, uv in ipairs(upvals) do
                        log("  upval #" .. i .. ":", tostring(uv), "type:", type(uv))
                    end
                end
            end
        end
        break
    end
end

-- [4] Check UnitController or other game controllers for Active/Equipped/Inventory list
log("----------------------------------------")
log("[5] Checking UnitController / UnitService:")
local UnitController = nil
pcall(function()
    UnitController = require(ReplicatedStorage.Framework.Features.Unit.UnitController)
end)
if UnitController then
    log("UnitController keys:")
    for k, v in pairs(UnitController) do
        log("  UC key:", tostring(k), "type:", type(v))
    end
end

log("==================================================")
log("[GENESIS DIAG V8] COMPLETED")
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
