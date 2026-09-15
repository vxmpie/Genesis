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
log("[GENESIS DIAG V22] TELEPORT & EQUIP EXECUTION TEST")
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

if not prompt1 then
    log("Error: Slot 1 prompt not found!")
    return
end

local pPart = prompt1.Parent:IsA("BasePart") and prompt1.Parent or prompt1.Parent.Parent
local pPos = (pPart and pPart:IsA("BasePart")) and pPart.Position or Vector3.zero

log("Step 1: Teleporting near Slot 1 podium...")
local originalCFrame = hrp.CFrame
hrp.CFrame = CFrame.new(pPos + Vector3.new(0, 3, 3))
task.wait(0.3)

log(string.format("After TP -> Dist=%.1f | Action='%s' | Enabled=%s", 
    (hrp.Position - pPos).Magnitude, prompt1.ActionText, tostring(prompt1.Enabled)))

-- Step 2: Select a unit from Backpack
local pg = lp:FindFirstChild("PlayerGui")
local bpMenu = pg and pg:FindFirstChild("Root") and pg.Root:FindFirstChild("Menus") and pg.Root.Menus:FindFirstChild("Backpack")
local scroller = bpMenu and bpMenu:FindFirstChild("ScrollingFrame", true)

if scroller then
    local firstEntry = scroller:FindFirstChildWhichIsA("ImageButton")
    if firstEntry then
        log("Step 2: Activating Backpack EntryTemplate...")
        if firesignal then
            firesignal(firstEntry.Activated)
        end
        task.wait(0.3)
        log(string.format("After Selecting Unit -> Prompt Action='%s' | Enabled=%s", 
            prompt1.ActionText, tostring(prompt1.Enabled)))
        
        -- Step 3: Fire proximity prompt to Place
        if prompt1.Enabled and fireproximityprompt then
            log("Step 3: Firing prompt to place...")
            fireproximityprompt(prompt1)
            task.wait(0.5)
            log(string.format("After Fire -> Prompt Action='%s' | Enabled=%s", 
                prompt1.ActionText, tostring(prompt1.Enabled)))
        else
            log("Prompt not enabled yet, skipping fire.")
        end
    end
end

log("Step 4: Returning to original position...")
hrp.CFrame = originalCFrame

log("==================================================")
log("[GENESIS DIAG V22] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V22.txt"
if writefile then
    pcall(function() writefile(fileName, fullOutput) end)
    print("[GENESIS] Log saved to: " .. fileName)
end
