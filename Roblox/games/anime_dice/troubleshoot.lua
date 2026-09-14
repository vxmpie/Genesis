local ReplicatedStorage = game:GetService("ReplicatedStorage")
local unitConfigMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit:FindFirstChild("UnitConfig")
if unitConfigMod then
    local uc = require(unitConfigMod)
    local entries = uc.entries or uc
    for _, name in ipairs({"Okarin", "Titanic Okarin", "Gon", "Titanic Gon", "Killer", "Titanic Killer", "Levy", "Titanic Levy"}) do
        local entry = entries[name]
        if entry then
            local ch = entry.chance
            local chVal = nil
            if type(ch) == "function" then
                local ok, res = pcall(ch)
                chVal = tostring(ok) .. " -> " .. tostring(res)
            else
                chVal = tostring(ch)
            end
            print(string.format("Entry '%s' -> Rarity: %s | Chance: %s", name, tostring(entry.rarity), chVal))
        else
            print("Entry NOT FOUND:", name)
        end
    end
end
