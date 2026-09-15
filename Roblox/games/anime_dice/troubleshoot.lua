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
log("[GENESIS DIAG V24] PUTBACK & BACKPACK SELECTION")
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

if not myPlot or not hrp then
    log("Error: Plot or HRP not found!")
    return
end

local slotsFolder = myPlot:FindFirstChild("Slots")
local slot1 = slotsFolder and slotsFolder:FindFirstChild("1")
local prompt1 = slot1 and slot1:FindFirstChildWhichIsA("ProximityPrompt", true)

local pPart = prompt1.Parent:IsA("BasePart") and prompt1.Parent or prompt1.Parent.Parent
local pPos = (pPart and pPart:IsA("BasePart")) and pPart.Position or Vector3.zero

log("Step 1: Teleporting near Slot 1 podium...")
local originalCFrame = hrp.CFrame
hrp.CFrame = CFrame.new(pPos + Vector3.new(0, 3, 3))
task.wait(0.3)

-- Pick up unit from Slot 1
if prompt1.ActionText == "Pick Up" and fireproximityprompt then
    log("Step 2: Firing Pick Up on Slot 1...")
    fireproximityprompt(prompt1)
    task.wait(0.5)
    log(string.format("After Pick Up -> Action='%s' | Enabled=%s", prompt1.ActionText, tostring(prompt1.Enabled)))
end

-- Test clicking PutBack button to return unit to backpack
local pg = lp:FindFirstChild("PlayerGui")
local putBack = pg and pg:FindFirstChild("Root") and pg.Root:FindFirstChild("HUD") and pg.Root.HUD:FindFirstChild("PutBack")
log("PutBack Button Visible:", tostring(putBack and putBack.Visible))

if putBack and putBack.Visible then
    log("Step 3: Clicking PutBack button...")
    -- Try various click methods
    if firesignal then
        pcall(function() firesignal(putBack.Activated) end)
        pcall(function() firesignal(putBack.MouseButton1Click) end)
        pcall(function() firesignal(putBack.MouseButton1Up) end)
    end
    task.wait(0.5)
    log("PutBack Button Visible after click:", tostring(putBack.Visible))
    log(string.format("Slot 1 Prompt after PutBack: Action='%s' | Enabled=%s", prompt1.ActionText, tostring(prompt1.Enabled)))
end

log("Returning to original position...")
hrp.CFrame = originalCFrame

log("==================================================")
log("[GENESIS DIAG V24] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V24.txt"
if writefile then
    pcall(function() writefile(fileName, fullOutput) end)
    print("[GENESIS] Log saved to: " .. fileName)
end
