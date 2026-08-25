local HttpService = game:GetService("HttpService")

local SETTINGS_FOLDER = "Genesis"
local SETTINGS_FILE = SETTINGS_FOLDER .. "/settings.json"

local Config = {}

Config.State = {
    IsActive = false,
    AutoWash = false,
    FastPickup = false,
    SmartWarp = true,
    Mode = "Anti-Stuck",
    IntervalSeconds = 15,
    IntervalValue = 15,
    TimeRemaining = 0,
    Unit = "Seconds",
    TeleportTarget = "Auction: Shipyard",
    WashRarities = {
        Common = true,
        Uncommon = true,
        Rare = true,
        Epic = true,
        Legendary = true,
        Mythic = true,
        Exotic = true,
        Secret = true,
    },
}

function Config.EnsureFolder()
    pcall(function()
        if not isfolder(SETTINGS_FOLDER) then
            makefolder(SETTINGS_FOLDER)
        end
    end)
end

function Config.Save()
    pcall(function()
        Config.EnsureFolder()
        local data = HttpService:JSONEncode({
            IntervalValue = Config.State.IntervalValue,
            Unit = Config.State.Unit,
            Mode = Config.State.Mode,
            IsActive = Config.State.IsActive,
            AutoWash = Config.State.AutoWash,
            FastPickup = Config.State.FastPickup,
            SmartWarp = Config.State.SmartWarp,
            WashRarities = Config.State.WashRarities,
            TeleportTarget = Config.State.TeleportTarget,
        })
        writefile(SETTINGS_FILE, data)
    end)
end

function Config.Load()
    local ok, data = pcall(function()
        return readfile(SETTINGS_FILE)
    end)
    if ok and data then
        local success, decoded = pcall(function()
            return HttpService:JSONDecode(data)
        end)
        if success and decoded then
            if decoded.IntervalValue then
                Config.State.IntervalValue = tonumber(decoded.IntervalValue) or 15
            end
            if decoded.Unit == "Minutes" or decoded.Unit == "Seconds" then
                Config.State.Unit = decoded.Unit
            end
            if decoded.Mode == "Anti-Stuck" or decoded.Mode == "Timer" then
                Config.State.Mode = decoded.Mode
            end
            if decoded.IsActive ~= nil then
                Config.State.IsActive = decoded.IsActive
            end
            if decoded.AutoWash ~= nil then
                Config.State.AutoWash = decoded.AutoWash
            end
            if decoded.FastPickup ~= nil then
                Config.State.FastPickup = decoded.FastPickup
            end
            if decoded.SmartWarp ~= nil then
                Config.State.SmartWarp = decoded.SmartWarp
            end
            if decoded.TeleportTarget then
                Config.State.TeleportTarget = tostring(decoded.TeleportTarget)
            end
            if decoded.WashRarities and type(decoded.WashRarities) == "table" then
                for k, v in pairs(decoded.WashRarities) do
                    Config.State.WashRarities[k] = v
                end
            end
        end
    end

    if Config.State.Unit == "Minutes" then
        Config.State.IntervalSeconds = Config.State.IntervalValue * 60
    else
        Config.State.IntervalSeconds = Config.State.IntervalValue
    end
end

return Config
