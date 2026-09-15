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
log("[GENESIS DIAG V10] CHANCE & BACKPACK INVESTIGATION")
log("==================================================")

-- [1] Inspect UnitConfig entries and evaluate chance()
local unitConfigMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit:FindFirstChild("UnitConfig")
if unitConfigMod then
    local uc = require(unitConfigMod)
    local entries = uc.entries or uc
    local testUnits = {
        "Okarin", "Huge Okarin", "Titanic Okarin",
        "Gon", "Huge Gon", "Titanic Gon",
        "Killer", "Huge Killer", "Titanic Killer",
        "Levy", "Huge Levy", "Titanic Levy",
        "Hasoka", "Titanic Hasoka"
    }
    log("[1] UnitConfig Chance Evaluation:")
    for _, name in ipairs(testUnits) do
        local entry = entries[name]
        if entry then
            local ch = entry.chance
            local chVal = nil
            if type(ch) == "function" then
                local ok, res = pcall(ch)
                chVal = "func -> " .. tostring(ok) .. ", " .. tostring(res)
            else
                chVal = tostring(ch)
            end
            log(string.format("  Entry: %-16s | Rarity: %-10s | Chance: %s", name, tostring(entry.rarity), chVal))
        else
            log(string.format("  Entry: %-16s | NOT FOUND", name))
        end
    end
end

-- [2] Inspect DataController for Bag vs Collection vs Equipped
local DataController = nil
pcall(function()
    DataController = require(ReplicatedStorage.Framework.Features.Data.DataController)
end)

if DataController then
    log("----------------------------------------")
    log("[2] DataController Top Nodes in ___C:")
    local dcC = rawget(DataController, "___C")
    if type(dcC) == "table" then
        for k, v in pairs(dcC) do
            local count = 0
            local subC = rawget(v, "___C")
            if type(subC) == "table" then
                for _ in pairs(subC) do count = count + 1 end
            end
            log(string.format("  dcC key: %-20s | type: %-8s | subItems in ___C: %d", tostring(k), type(v), count))
        end
    end

    -- Sample item from Inventory to check if there is an "equipped", "stored", "inBag", "owner", or "state" field
    if dcC and rawget(dcC, "Inventory") then
        local invNode = rawget(dcC, "Inventory")
        local rawInv = rawget(invNode, "___C")
        if rawInv then
            log("----------------------------------------")
            log("[3] Inspecting Sample Inventory Item Fields:")
            local sampleGuid, sampleItem = next(rawInv)
            if sampleItem then
                log("  Sample GUID: " .. tostring(sampleGuid))
                local itemC = rawget(sampleItem, "___C")
                if type(itemC) == "table" then
                    for ik, iv in pairs(itemC) do
                        local x = rawget(iv, "___X")
                        local xVal = "nil"
                        if type(x) == "table" then
                            local parts = {}
                            for subK, subV in pairs(x) do
                                table.insert(parts, tostring(subK) .. "=" .. tostring(subV))
                            end
                            xVal = "table{" .. table.concat(parts, ", ") .. "}"
                        elseif x ~= nil then
                            xVal = tostring(x)
                        end
                        log(string.format("    itemC key: %-15s | ___X: %s", tostring(ik), xVal))
                    end
                end
            end
        end
    end
end

-- [3] Inspect LocalPlayer Backpack & PlayerGui
log("----------------------------------------")
log("[4] Checking LocalPlayer Instances:")
local lp = Players.LocalPlayer
if lp then
    local bp = lp:FindFirstChild("Backpack")
    log("  Backpack children count:", bp and #bp:GetChildren() or "nil")
    if bp and #bp:GetChildren() > 0 then
        for i, ch in ipairs(bp:GetChildren()) do
            if i <= 5 then
                log("    bp item:", ch.Name, ch.ClassName)
            end
        end
    end
end

log("==================================================")
log("[GENESIS DIAG V10] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V10.txt"
if writefile then
    pcall(function()
        writefile(fileName, fullOutput)
    end)
    print("[GENESIS] Log saved to: " .. fileName)
end
