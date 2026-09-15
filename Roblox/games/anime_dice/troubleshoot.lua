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
log("[GENESIS DIAG V28] LIVE INVENTORY INSPECTION")
log("==================================================")

local lp = Players.LocalPlayer

-- Check DataController reference
local dcMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Data.DataController
if dcMod then
    local dc = require(dcMod)
    log("dc table pointer:", tostring(dc))
    local dcC = rawget(dc, "___C")
    local invNode = dcC and rawget(dcC, "Inventory")
    local rawInv = invNode and rawget(invNode, "___C")
    
    log("invNode pointer:", tostring(invNode), "rawInv pointer:", tostring(rawInv))
    
    local count = 0
    local sampleUnits = {}
    if rawInv then
        for guid, item in pairs(rawInv) do
            count = count + 1
            if count <= 5 then
                local name = nil
                local iC = rawget(item, "___C")
                if iC and rawget(iC, "name") then
                    local nNode = rawget(iC, "name")
                    local x = rawget(nNode, "___X")
                    name = type(x) == "table" and rawget(x, "name") or x
                end
                table.insert(sampleUnits, string.format("[%s] %s", tostring(guid):sub(1,8), tostring(name)))
            end
        end
    end
    log("Total items in rawInv:", count)
    log("First 5 items:", table.concat(sampleUnits, ", "))
end

-- Inspect Backpack UI Scroller children names and titles
local pg = lp:FindFirstChild("PlayerGui")
local bpMenu = pg and pg:FindFirstChild("Root") and pg.Root:FindFirstChild("Menus") and pg.Root.Menus:FindFirstChild("Backpack")
local scroller = bpMenu and bpMenu:FindFirstChild("ScrollingFrame", true)
if scroller then
    local uiList = {}
    for _, ch in ipairs(scroller:GetChildren()) do
        if ch:IsA("ImageButton") then
            local top = ch:FindFirstChild("TopLabel", true)
            local bot = ch:FindFirstChild("BottomLabel", true)
            table.insert(uiList, string.format("%s (%s, %s)", ch.Name, top and top.Text or "", bot and bot.Text or ""))
            if #uiList >= 5 then break end
        end
    end
    log("Top 5 items in Backpack UI:", table.concat(uiList, " | "))
end

log("==================================================")
log("[GENESIS DIAG V28] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V28.txt"
if writefile then
    pcall(function() writefile(fileName, fullOutput) end)
    print("[GENESIS] Log saved to: " .. fileName)
end
