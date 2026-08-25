local Config = {}
local HttpService = game:GetService("HttpService")

local FILE_NAME = "Genesis_StorageHunter_Config.json"

local State = {
    AutoWash = false,
    AntiAFK = true,
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
    if State[key] ~= nil then
        return State[key]
    end
    return default
end

function Config.Set(key, value)
    State[key] = value
end

function Config.GetState()
    return State
end

function Config.Save()
    if writefile then
        pcall(function()
            local data = HttpService:JSONEncode(State)
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
                    State[k] = v
                end
            end
        end)
    end
    return State
end

return Config
