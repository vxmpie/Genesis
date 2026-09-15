local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local logLines = {}
local function log(...)
    local args = {...}
    local strList = {}
    for i = 1, #args do
        strList[i] = tostring(args[i])
    end
    local line = table.concat(strList, " ")
    table.insert(logLines, line)
    print(line)
end

log("==================================================")
log("[GENESIS DIAG V27] DATA REFRESH & INVENTORY PROBE")
log("==================================================")

local lp = Players.LocalPlayer

-- [1] Inspect DataController methods
local dcMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Data.DataController
if dcMod then
    local ok, dc = pcall(require, dcMod)
    if ok and dc then
        log("DataController methods & keys:")
        for k, v in pairs(dc) do
            log(string.format("  dc.%s = %s (%s)", tostring(k), tostring(v), typeof(v)))
        end
        if dc.Get then
            local gOk, gRes = pcall(function() return dc:Get() end)
            log("dc:Get() ->", gOk, typeof(gRes))
        end
        if dc.GetData then
            local gOk2, gRes2 = pcall(function() return dc:GetData() end)
            log("dc:GetData() ->", gOk2, typeof(gRes2))
        end
    end
end

-- [2] Compare raw DC inventory count vs Backpack UI count
local pg = lp:FindFirstChild("PlayerGui")
local bpMenu = pg and pg:FindFirstChild("Root") and pg.Root:FindFirstChild("Menus") and pg.Root.Menus:FindFirstChild("Backpack")
local scroller = bpMenu and bpMenu:FindFirstChild("ScrollingFrame", true)

if scroller then
    local uiCount = 0
    for _, c in ipairs(scroller:GetChildren()) do
        if c:IsA("ImageButton") or c:IsA("TextButton") then
            uiCount = uiCount + 1
        end
    end
    log("Backpack UI items count:", uiCount)
end

-- [3] Inspect direct items in DataController
if dcMod then
    local ok, dc = pcall(require, dcMod)
    if ok and dc and rawget(dc, "___C") then
        local dcC = rawget(dc, "___C")
        local invNode = rawget(dcC, "Inventory")
        if invNode then
            local rawInv = rawget(invNode, "___C")
            local rawCount = 0
            if rawInv and type(rawInv) == "table" then
                for k, v in pairs(rawInv) do
                    rawCount = rawCount + 1
                end
            end
            log("DataController rawInventory count:", rawCount)
        end
    end
end

log("==================================================")
log("[GENESIS DIAG V27] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V27.txt"
if writefile then
    pcall(function() writefile(fileName, fullOutput) end)
    print("[GENESIS] Log saved to: " .. fileName)
end
