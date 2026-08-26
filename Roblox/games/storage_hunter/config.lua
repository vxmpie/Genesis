local Config = {}
local HttpService = game:GetService("HttpService")

local FILE_NAME = "Genesis_StorageHunter_Config.json"

local DEFAULT_STATE = {
    AutoWash = false,
    AutoGrade = false,
    GradeFromVehicle = true,
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
    },
    AllowedSafes = {
        ["Junk Safe"] = true,
        ["Wooden Safe"] = true,
        ["Metal Safe"] = true,
        ["Code Safe"] = true,
        ["Diamond Safe"] = true,
        ["Diamond Vault"] = true
    }
}

Config.State = HttpService:JSONDecode(HttpService:JSONEncode(DEFAULT_STATE))

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
                    if type(v) == "table" and type(Config.State[k]) == "table" then
                        for subK, subV in pairs(v) do
                            Config.State[k][subK] = subV
                        end
                    else
                        Config.State[k] = v
                    end
                end
            end
        end)
    end
    return Config.State
end

function Config.Reset()
    local fresh = HttpService:JSONDecode(HttpService:JSONEncode(DEFAULT_STATE))
    for k in pairs(Config.State) do
        Config.State[k] = nil
    end
    for k, v in pairs(fresh) do
        Config.State[k] = v
    end
    return Config.State
end

return Config
