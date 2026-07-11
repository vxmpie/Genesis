local u = "https://raw.githubusercontent.com/vxmpie/storage_hunter/main/src/main.lua?t=" .. tostring(tick())
local s, c = pcall(function() return game:HttpGet(u) end)

if not s then
    warn("NetworkFetchError")
else
    local f, e = loadstring(c)
    if not f then
        warn("SyntaxError: " .. tostring(e))
    else
        local ok, r = pcall(f)
        if not ok then
            warn("RuntimeError: " .. tostring(r))
        end
    end
end