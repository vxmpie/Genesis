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
log("[GENESIS DIAG V30] EMPTY SLOT PLACEMENT TRACE")
log("==================================================")

local lp = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hrp = char:FindFirstChild("HumanoidRootPart")
local pg = lp:FindFirstChild("PlayerGui")

local pcMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Plot.PlotController
local myPlot = nil
if pcMod then
    local ok, pc = pcall(require, pcMod)
    if ok and pc and pc.plot then myPlot = pc.plot end
end

if not myPlot or not hrp then
    log("Error: Plot or HRP not found!")
    return
end

-- Inspect Slot 1
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
local origCF = hrp.CFrame
hrp.CFrame = CFrame.new(pPos + Vector3.new(0, 3, 3))
task.wait(0.3)

log(string.format("Initial Slot 1 -> Action='%s' | Enabled=%s | Key='%s'", 
    prompt1.ActionText, tostring(prompt1.Enabled), tostring(prompt1.KeyboardKeyCode)))

-- Step 2: Open Backpack Menu and inspect buttons
local bpMenu = pg and pg:FindFirstChild("Root") and pg.Root:FindFirstChild("Menus") and pg.Root.Menus:FindFirstChild("Backpack")
log("Backpack Menu Visible:", tostring(bpMenu and bpMenu.Visible))

local scroller = bpMenu and bpMenu:FindFirstChild("ScrollingFrame", true)
local targetBtn = nil
if scroller then
    for _, btn in ipairs(scroller:GetChildren()) do
        if btn:IsA("ImageButton") or btn:IsA("TextButton") then
            targetBtn = btn
            break
        end
    end
end

if targetBtn then
    log("Found target backpack button:", targetBtn.Name, "ClassName:", targetBtn.ClassName)
    log("Activating backpack button...")
    if firesignal then
        firesignal(targetBtn.Activated)
    end
    task.wait(0.4)
    
    local putBack = pg and pg.Root and pg.Root:FindFirstChild("HUD") and pg.Root.HUD:FindFirstChild("PutBack")
    log("PutBack Button Visible after click:", tostring(putBack and putBack.Visible))
    log(string.format("Slot 1 Prompt after unit selected -> Action='%s' | Enabled=%s", 
        prompt1.ActionText, tostring(prompt1.Enabled)))
    
    -- Step 3: Test placing
    if prompt1.ActionText == "Place" then
        if not prompt1.Enabled then
            log("Prompt was disabled, enabling it forcibly...")
            prompt1.Enabled = true
        end
        log("Firing fireproximityprompt on Slot 1...")
        if fireproximityprompt then
            fireproximityprompt(prompt1)
        end
        task.wait(0.5)
        log(string.format("After Fire -> Action='%s' | Enabled=%s", 
            prompt1.ActionText, tostring(prompt1.Enabled)))
    end
else
    log("No unit buttons found in Backpack scroller!")
end

log("Returning to original position...")
hrp.CFrame = origCF

log("==================================================")
log("[GENESIS DIAG V30] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V30.txt"
if writefile then
    pcall(function() writefile(fileName, fullOutput) end)
    print("[GENESIS] Log saved to: " .. fileName)
end
