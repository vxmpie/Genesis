if not game:IsLoaded() then
    game.Loaded:Wait()
end

local BASE = "https://raw.githubusercontent.com/vxmpie/Genesis/main/Roblox/games/"

local games = {
    [9640154] = "storage_hunter/main.lua",
    [98800969324557] = "storage_hunter/main.lua",
}

local file = games[game.PlaceId] or games[game.GameId] or games[game.CreatorId]

if file then
    loadstring(game:HttpGet(BASE .. file))()
else
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "GENESIS",
            Text = "Game not supported (" .. tostring(game.PlaceId) .. ")",
            Duration = 5,
        })
    end)
end
