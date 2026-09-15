local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
log("[GENESIS DIAG V29] INVENTORY UNITS & SORTING AUDIT")
log("==================================================")

local lp = Players.LocalPlayer

local RARITY_RANKS = {
    ["Common"] = 1,
    ["Uncommon"] = 2,
    ["Rare"] = 3,
    ["Epic"] = 4,
    ["Legendary"] = 5,
    ["Mythical"] = 6,
    ["Divine"] = 7,
    ["Exotic"] = 8,
    ["Celestial"] = 9,
    ["Secret I"] = 10,
    ["Secret II"] = 11,
    ["Exclusive"] = 12
}

local function formatOdds(num)
    if not num or num <= 0 then return "1 in 1" end
    if num >= 1e15 then return string.format("1 in %.2fQ", num / 1e15)
    elseif num >= 1e12 then return string.format("1 in %.2fT", num / 1e12)
    elseif num >= 1e9 then return string.format("1 in %.2fB", num / 1e9)
    elseif num >= 1e6 then return string.format("1 in %.2fM", num / 1e6)
    elseif num >= 1e3 then return string.format("1 in %.1fk", num / 1e3)
    else return string.format("1 in %d", math.floor(num)) end
end

local unitConfig = nil
pcall(function()
    unitConfig = require(ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitConfig)
end)
local entries = (unitConfig and unitConfig.entries) or {}

local rawInv = nil
pcall(function()
    local dc = require(ReplicatedStorage.Framework.Features.Data.DataController)
    rawInv = dc.___C.Inventory.___C
end)

if not rawInv then
    log("Error: rawInv not found!")
    return
end

local parsedUnits = {}
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
            rawName = rawget(itemX, "name") or rawget(itemX, "entry")
            rawAttrs = rawget(itemX, "attributes") or rawAttrs
        end
    end

    if type(rawName) == "string" and rawName ~= "" then
        local meta = nil
        local resolvedVariant = nil
        if rawAttrs and rawAttrs.variant then
            local combo = tostring(rawAttrs.variant) .. " " .. rawName
            if entries[combo] then
                meta = entries[combo]
                resolvedVariant = tostring(rawAttrs.variant)
            end
        end
        if not meta then meta = entries[rawName] end

        local rName = (meta and meta.rarity) or "Common"
        local odds = 1
        if meta then
            if type(meta.chance) == "function" then
                local ok, val = pcall(meta.chance)
                if ok and type(val) == "number" then odds = val end
            elseif type(meta.chance) == "number" then
                odds = meta.chance
            end
        end

        table.insert(parsedUnits, {
            Name = resolvedVariant and (resolvedVariant .. " " .. rawName) or rawName,
            Rarity = rName,
            RarityRank = RARITY_RANKS[rName] or 1,
            Odds = odds,
            Formatted = formatOdds(odds),
            Level = rawAttrs and tonumber(rawAttrs.level) or 1
        })
    end
end

table.sort(parsedUnits, function(a, b)
    if a.RarityRank ~= b.RarityRank then return a.RarityRank > b.RarityRank end
    if a.Odds ~= b.Odds then return a.Odds > b.Odds end
    return a.Level > b.Level
end)

log(string.format("Total Parsed Units: %d", #parsedUnits))
log("Top 10 Rarest Units in Player's Entire Inventory:")
for i = 1, math.min(10, #parsedUnits) do
    local u = parsedUnits[i]
    log(string.format("  #%d: %s | %s | %s | Level %d", i, u.Name, u.Rarity, u.Formatted, u.Level))
end

log("==================================================")
log("[GENESIS DIAG V29] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V29.txt"
if writefile then
    pcall(function() writefile(fileName, fullOutput) end)
    print("[GENESIS] Log saved to: " .. fileName)
end
