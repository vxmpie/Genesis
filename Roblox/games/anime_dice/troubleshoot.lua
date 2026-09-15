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
log("[GENESIS DIAG V23] PICKUP, PUTBACK & PLACE CYCLE")
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

log(string.format("Initial: Dist=%.1f | Action='%s' | Enabled=%s", 
    (hrp.Position - pPos).Magnitude, prompt1.ActionText, tostring(prompt1.Enabled)))

-- Test Pickup action on Slot 1
if prompt1.ActionText == "Pick Up" and fireproximityprompt then
    log("Step 2: Firing Pick Up on Slot 1...")
    fireproximityprompt(prompt1)
    task.wait(0.5)
    log(string.format("After Pick Up: Action='%s' | Enabled=%s", prompt1.ActionText, tostring(prompt1.Enabled)))
    
    local pg = lp:FindFirstChild("PlayerGui")
    local putBack = pg and pg:FindFirstChild("Root") and pg.Root:FindFirstChild("HUD") and pg.Root.HUD:FindFirstChild("PutBack")
    log("PutBack Button Visible:", tostring(putBack and putBack.Visible))
    
    -- Now that the slot is empty (Action is Place or empty), test putting it back or placing
    if prompt1.ActionText == "Place" then
        log("Slot is now empty! Step 3: Firing Place on Slot 1...")
        fireproximityprompt(prompt1)
        task.wait(0.5)
        log(string.format("After Place: Action='%s' | Enabled=%s", prompt1.ActionText, tostring(prompt1.Enabled)))
    elseif putBack and putBack.Visible then
        log("Testing PutBack click to bag...")
        if firesignal then
            firesignal(putBack.Activated)
            firesignal(putBack.MouseButton1Click)
        end
        task.wait(0.5)
        log("PutBack Button Visible after click:", tostring(putBack.Visible))
    end
end

log("Returning to original position...")
hrp.CFrame = originalCFrame

log("==================================================")
log("[GENESIS DIAG V23] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V23.txt"
if writefile then
    pcall(function() writefile(fileName, fullOutput) end)
    print("[GENESIS] Log saved to: " .. fileName)
end
