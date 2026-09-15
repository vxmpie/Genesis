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
log("[GENESIS DIAG V18] EQUIPPEDUNIT CONTENTS & PROMPT FIRE")
log("==================================================")

local lp = Players.LocalPlayer

-- [1] Deep inspect uc:EquippedUnit()
local ucMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitController
if ucMod then
    local ok, uc = pcall(require, ucMod)
    if ok and uc and uc.EquippedUnit then
        local eq = uc:EquippedUnit()
        log("EquippedUnit table type:", type(eq))
        if type(eq) == "table" then
            for k, v in pairs(eq) do
                log(string.format("  eq.%s = %s (%s)", tostring(k), tostring(v), typeof(v)))
            end
            if eq.___X and type(eq.___X) == "table" then
                for xk, xv in pairs(eq.___X) do
                    log(string.format("    eq.___X.%s = %s (%s)", tostring(xk), tostring(xv), typeof(xv)))
                end
            end
        end
    end
end

-- [2] Check PlotController refreshSlots or prompt triggers
local pcMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Plot.PlotController
local myPlot = nil
if pcMod then
    local ok, pc = pcall(require, pcMod)
    if ok and pc and pc.plot then
        myPlot = pc.plot
    end
end

if myPlot then
    local slotsFolder = myPlot:FindFirstChild("Slots")
    if slotsFolder then
        for i = 1, #slotsFolder:GetChildren() do
            local sModel = slotsFolder:FindFirstChild(tostring(i))
            if sModel then
                local prompt = sModel:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt then
                    log(string.format("Slot [%d]: Action='%s' Key='%s' Enabled=%s", 
                        i, prompt.ActionText, tostring(prompt.KeyboardKeyCode), tostring(prompt.Enabled)))
                end
            end
        end
    end
end

-- [3] Check PutBack GUI parent hierarchy & signals
local pg = lp:FindFirstChild("PlayerGui")
local putBack = pg and pg:FindFirstChild("Root") and pg.Root:FindFirstChild("HUD") and pg.Root.HUD:FindFirstChild("PutBack")
if putBack then
    log("PutBack parent:", putBack.Parent:GetFullName())
    -- check if it has scripts or parent has scripts
    for _, ch in ipairs(putBack:GetChildren()) do
        log("  PutBack child:", ch.Name, ch.ClassName)
    end
end

log("==================================================")
log("[GENESIS DIAG V18] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V18.txt"
if writefile then
    pcall(function() writefile(fileName, fullOutput) end)
    print("[GENESIS] Log saved to: " .. fileName)
end
