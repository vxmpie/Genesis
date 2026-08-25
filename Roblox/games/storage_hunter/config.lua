local Config = {}
local HttpService = game:GetService("HttpService")

local FILE_NAME = "Genesis_StorageHunter_Config.json"

Config.State = {
    AutoWash = false,
    IsActive = false,
    Mode = "Anti-Stuck",
    IntervalSeconds = 15,
    IntervalValue = 15,
    WashRarities = {
        Common = true,
        Uncommon = true,
        Rare = true,
        Epic = true,
        Legendary = true,
        Mythical = true,
        Lost = true,
        Exclusive = true
    }
}

function Config.Get(key, default)
    if Config.State[key] ~= nil then
        return Config.State[key]
    end
    return default
end

function Config.Set(key, value)
    Config.State[key] = value
end

function Config.GetState()
    return Config.State
end

function Config.Save()
    if writefile then
        pcall(function()
            local data = HttpService:JSONEncode(Config.State)
            writefile(FILE_NAME, data)
        end)
    end
end

function Config.Load()
    if isfile and isfile(FILE_NAME) then
        pcall(function()
            local content = readfile(FILE_NAME)
            local decoded = HttpService:JSONDecode(content)
            if type(decoded) == "table" then
                for k, v in pairs(decoded) do
                    Config.State[k] = v
                end
            end
        end)
    end
    return Config.State
end

return Config
