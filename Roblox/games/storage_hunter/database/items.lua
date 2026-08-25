local ItemsDB = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local cachedItems = {}
local itemsByName = {}

local function sanitizeString(str)
    if typeof(str) ~= "string" then return tostring(str or "") end
    return str:gsub("^%s*(.-)%s*$", "%1")
end

local function normalizeRarity(rarity)
    if not rarity then return "Junk" end
    local r = string.lower(sanitizeString(rarity))
    if r == "junk" then return "Junk"
    elseif r == "uncommon" then return "Uncommon"
    elseif r == "rare" then return "Rare"
    elseif r == "epic" then return "Epic"
    elseif r == "legendary" then return "Legendary"
    elseif r == "mythical" or r == "mythic" then return "Mythical"
    elseif r == "lost" then return "Lost"
    elseif r == "exclusive" then return "Exclusive"
    end
    return "Junk"
end

local function loadLiveItems()
    local success, result = pcall(function()
        local modulesFolder = ReplicatedStorage:FindFirstChild("Modules")
        if not modulesFolder then return nil end
        local itemsModule = modulesFolder:FindFirstChild("Items")
        if not itemsModule or not itemsModule:IsA("ModuleScript") then return nil end
        return require(itemsModule)
    end)
    if success and typeof(result) == "table" then
        for id, data in pairs(result) do
            if typeof(data) == "table" then
                local numId = tonumber(id) or id
                local name = sanitizeString(data.Name or data.name or ("Item_" .. tostring(id)))
                local itemEntry = {
                    Id = numId,
                    Name = name,
                    BasePrice = tonumber(data.BasePrice or data.Price or data.Value or 0) or 0,
                    Weight = tonumber(data.Weight or 0) or 0,
                    Rarity = normalizeRarity(data.Rarity or data.rarity),
                    Category = sanitizeString(data.Category or data.category or "Misc"),
                    Area = sanitizeString(data.Area or data.area or "Any"),
                    Garages = typeof(data.Garages) == "table" and data.Garages or {},
                    IsLimited = data.IsLimited or data.Limited or false,
                    IsVehiclePart = data.IsVehiclePart or false
                }
                cachedItems[numId] = itemEntry
                itemsByName[string.lower(name)] = itemEntry
            end
        end
        return true
    end
    return false
end

loadLiveItems()

function ItemsDB.GetItemById(id)
    local numId = tonumber(id)
    if numId and cachedItems[numId] then
        return cachedItems[numId]
    end
    if cachedItems[id] then
        return cachedItems[id]
    end
    loadLiveItems()
    return cachedItems[numId or id]
end

function ItemsDB.GetItemByName(name)
    if not name then return nil end
    local lower = string.lower(sanitizeString(name))
    if itemsByName[lower] then
        return itemsByName[lower]
    end
    loadLiveItems()
    return itemsByName[lower]
end

function ItemsDB.GetAllItems()
    loadLiveItems()
    return cachedItems
end

function ItemsDB.GetItemNamesList()
    loadLiveItems()
    local list = {}
    for _, item in pairs(cachedItems) do
        table.insert(list, item.Name)
    end
    table.sort(list)
    return list
end

function ItemsDB.EstimateLotValue(itemModels)
    if typeof(itemModels) ~= "table" then return 0 end
    local total = 0
    for _, model in ipairs(itemModels) do
        local itemName = model.Name
        local itemInfo = ItemsDB.GetItemByName(itemName)
        if itemInfo then
            local multiplier = 1
            local rarity = itemInfo.Rarity
            if rarity == "Uncommon" then multiplier = 1.2
            elseif rarity == "Rare" then multiplier = 1.5
            elseif rarity == "Epic" then multiplier = 2.0
            elseif rarity == "Legendary" then multiplier = 3.0
            elseif rarity == "Mythical" then multiplier = 5.0
            elseif rarity == "Lost" then multiplier = 10.0
            end
            total = total + (itemInfo.BasePrice * multiplier)
        end
    end
    return total
end

return ItemsDB
