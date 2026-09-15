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

log("====================================")
log("[DIAG V33] INVENTORY STRUCTURE PROBE")
log("====================================")

local dcMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Data.DataController
if not dcMod then
    log("DataController not found!")
else
    local ok, dc = pcall(require, dcMod)
    if not ok or not dc then
        log("Require DataController failed:", tostring(dc))
    else
        local xInv = dc.___X and dc.___X.Inventory
        log("dc.___X.Inventory type:", type(xInv))
        if type(xInv) == "table" then
            local count = 0
            for k, v in pairs(xInv) do
                count = count + 1
                if count <= 3 then
                    log("  xInv[" .. tostring(k) .. "] type: " .. type(v))
                    if type(v) == "table" then
                        for subK, subV in pairs(v) do
                            log("    ." .. tostring(subK) .. " = " .. tostring(subV) .. " (" .. type(subV) .. ")")
                        end
                    end
                end
            end
            log("Total items in dc.___X.Inventory:", count)
        end

        local cInvNode = dc.___C and dc.___C.Inventory
        local cInv = cInvNode and cInvNode.___C
        log("dc.___C.Inventory.___C type:", type(cInv))
        if type(cInv) == "table" then
            local count = 0
            for k, v in pairs(cInv) do
                count = count + 1
                if count <= 3 then
                    log("  cInv[" .. tostring(k) .. "] type: " .. type(v))
                    if type(v) == "table" then
                        for subK, subV in pairs(v) do
                            log("    ." .. tostring(subK) .. " = " .. tostring(subV) .. " (" .. type(subV) .. ")")
                        end
                    end
                end
            end
            log("Total items in dc.___C.Inventory.___C:", count)
        end
    end
end

log("====================================")
log("[DIAG V33] COMPLETED")
log("====================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V33.txt"
if writefile then
    pcall(function() writefile(fileName, fullOutput) end)
    print("[GENESIS] Saved log to Workspace folder: " .. fileName)
end
