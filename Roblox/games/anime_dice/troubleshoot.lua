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
log("[GENESIS DIAG V21] PROMPT POSITION & DISTANCE PROBE")
log("==================================================")

local lp = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hrp = char:FindFirstChild("HumanoidRootPart")

local pcMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Plot.PlotController
local myPlot = nil
if pcMod then
    local ok, pc = pcall(require, pcMod)
    if ok and pc and pc.plot then
        myPlot = pc.plot
    end
end

if myPlot and hrp then
    local slotsFolder = myPlot:FindFirstChild("Slots")
    if slotsFolder then
        for i = 1, 5 do
            local sModel = slotsFolder:FindFirstChild(tostring(i))
            if sModel then
                local prompt = sModel:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt then
                    local pPart = prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent.Parent
                    local pPos = (pPart and pPart:IsA("BasePart")) and pPart.Position or Vector3.zero
                    local dist = (hrp.Position - pPos).Magnitude
                    log(string.format("Slot [%d]: Action='%s' Enabled=%s MaxDist=%.1f CurrentDist=%.1f RequiresLineOfSight=%s",
                        i, prompt.ActionText, tostring(prompt.Enabled), prompt.MaxActivationDistance, dist, tostring(prompt.RequiresLineOfSight)))
                end
            end
        end
    end
end

-- Inspect Backpack EntryTemplate attributes and click connections
local pg = lp:FindFirstChild("PlayerGui")
local bpMenu = pg and pg:FindFirstChild("Root") and pg.Root:FindFirstChild("Menus") and pg.Root.Menus:FindFirstChild("Backpack")
if bpMenu then
    local scroller = bpMenu:FindFirstChild("ScrollingFrame", true)
    if scroller then
        local firstEntry = scroller:FindFirstChildWhichIsA("ImageButton")
        if firstEntry then
            log("First Entry in Backpack:", firstEntry.Name)
            for ak, av in pairs(firstEntry:GetAttributes()) do
                log(string.format("  Entry Attr: %s = %s", ak, tostring(av)))
            end
            if getconnections then
                local actConns = getconnections(firstEntry.Activated)
                local clickConns = getconnections(firstEntry.MouseButton1Click)
                log("  Activated conns:", #actConns, "MouseButton1Click conns:", #clickConns)
            end
        end
    end
end

log("==================================================")
log("[GENESIS DIAG V21] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V21.txt"
if writefile then
    pcall(function() writefile(fileName, fullOutput) end)
    print("[GENESIS] Log saved to: " .. fileName)
end
