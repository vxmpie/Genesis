if not game:IsLoaded() then
    game.Loaded:Wait()
end

if _G.GenesisUnload then
    pcall(_G.GenesisUnload)
end

print("[GENESIS] LOADER EXECUTED - Initializing Core Genesis Infrastructure...")

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "GENESIS",
        Text = "Executing Genesis Core Loader...",
        Duration = 4
    })
end)

local UTILS_URL = "https://raw.githubusercontent.com/vxmpie/Genesis/main/Roblox/utils/reconnect.lua"
pcall(function()
    local recCode = game:HttpGet(UTILS_URL .. "?t=" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999)))
    local recFn = loadstring(recCode)
    if recFn then
        local recMod = recFn()
        if recMod and recMod.Start then
            recMod.Start()
        end
    end
end)

local BASE = "https://raw.githubusercontent.com/vxmpie/Genesis/main/Roblox/games/"

local games = {
    [9640154] = "storage_hunter/main.lua",
    [98800969324557] = "storage_hunter/main.lua",
}

local file = games[game.PlaceId] or games[game.GameId] or games[game.CreatorId]

if file then
    print("[GENESIS] Game matched: (" .. tostring(game.PlaceId) .. "). Loading hub...")
    local url = BASE .. file .. "?t=" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
    loadstring(game:HttpGet(url))()
else
    warn("[GENESIS] Game not supported! PlaceId:", game.PlaceId, "GameId:", game.GameId)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "GENESIS",
            Text = "Game not supported (" .. tostring(game.PlaceId) .. ")",
            Duration = 5,
        })
    end)
end
