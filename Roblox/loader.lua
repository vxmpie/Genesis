if not game:IsLoaded() then
    game.Loaded:Wait()
end

print("[GENESIS] LOADER EXECUTED - Checking game compatibility...")

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "GENESIS",
        Text = "Executing Genesis Loader...",
        Duration = 4
    })
end)

local BASE = "https://raw.githubusercontent.com/vxmpie/Genesis/main/Roblox/games/"

local games = {
    [9640154] = "storage_hunter/main.lua",
    [98800969324557] = "storage_hunter/main.lua",
}

local file = games[game.PlaceId] or games[game.GameId] or games[game.CreatorId]

if file then
    print("[GENESIS] Game matched: Storage Hunters (" .. tostring(game.PlaceId) .. "). Loading main hub...")
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
