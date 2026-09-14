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
log("[GENESIS DIAG V9] UNITCONFIG & EXOTIC UNIT INSPECTION")
log("==================================================")

-- [1] Inspect UnitConfig
local unitConfigMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit:FindFirstChild("UnitConfig")
log("UnitConfig Module exists:", unitConfigMod ~= nil)
if unitConfigMod then
    local ok, uc = pcall(require, unitConfigMod)
    log("UnitConfig require ok:", ok, "type:", type(uc))
    if ok and type(uc) == "table" then
        log("UnitConfig top keys:")
        for k, v in pairs(uc) do
            log("  UC key:", tostring(k), "type:", type(v))
        end
        local entries = uc.entries or uc
        log("Checking entries inside UnitConfig. Total entries count or keys...")
        local count = 0
        local matched = {}
        for name, data in pairs(entries) do
            count = count + 1
            local strName = tostring(name)
            local lowerName = string.lower(strName)
            if string.find(lowerName, "okarin") or string.find(lowerName, "gon") or string.find(lowerName, "killer") or string.find(lowerName, "vegata") or string.find(lowerName, "levy") or string.find(lowerName, "hasoka") then
                local r = (type(data) == "table" and (data.rarity or data.Rarity)) or "nil"
                local ch = (type(data) == "table" and (data.chance or data.Chance or data.odds or data.Odds)) or "nil"
                table.insert(matched, string.format("Matched entry: '%s' -> Rarity: %s | Chance: %s", strName, tostring(r), tostring(ch)))
            end
        end
        log("Total entries in UnitConfig:", count)
        log("Matched relevant units in UnitConfig:")
        for _, m in ipairs(matched) do
            log("  " .. m)
        end
    end
end

-- [2] Inspect Player's Inventory items matching Okarin, Gon, Killer
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
    log("----------------------------------------")
    log("Scanning player rawInventory for Okarin, Gon, Killer...")
    local foundCount = 0
    for guid, itemNode in pairs(rawInv) do
        local rawName = nil
        local rawAttrs = {}
        local itemC = rawget(itemNode, "___C")
        if type(itemC) == "table" then
            local nameNode = rawget(itemC, "name")
            if type(nameNode) == "table" then
                local xData = rawget(nameNode, "___X")
                if type(xData) == "table" then
                    rawName = rawget(xData, "name")
                    rawAttrs = rawget(xData, "attributes") or rawAttrs
                elseif type(xData) == "string" then
                    rawName = xData
                end
            end
        end
        if not rawName then
            local itemX = rawget(itemNode, "___X")
            if type(itemX) == "table" then
                rawName = rawget(itemX, "name")
                rawAttrs = rawget(itemX, "attributes") or rawAttrs
            end
        end

        if rawName then
            local lName = string.lower(tostring(rawName))
            if string.find(lName, "okarin") or string.find(lName, "gon") or string.find(lName, "killer") then
                foundCount = foundCount + 1
                local attrStr = HttpService:JSONEncode(rawAttrs or {})
                log(string.format("Found Bag Unit #%d [GUID %s]: name='%s', attrs=%s", foundCount, tostring(guid), tostring(rawName), attrStr))
            end
        end
    end
    log("Total target units found in bag:", foundCount)
end

log("==================================================")
log("[GENESIS DIAG V9] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V9.txt"
if writefile then
    pcall(function()
        writefile(fileName, fullOutput)
    end)
    print("[GENESIS] Log saved to: " .. fileName)
end
