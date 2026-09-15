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
log("[GENESIS DIAG V25] BACKPACK HOLD & PLACE ON EMPTY SLOT")
log("==================================================")

local lp = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hrp = char:FindFirstChild("HumanoidRootPart")
local pg = lp:FindFirstChild("PlayerGui")

-- [1] Method A: Test holding unit via UnitController
local ucMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitController
local uc = nil
if ucMod then
    local ok, res = pcall(require, ucMod)
    if ok and res then uc = res end
end

-- [2] Find My Plot and Slot 1
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

local slotsFolder = myPlot:FindFirstChild("Slots")
local slot1 = slotsFolder and slotsFolder:FindFirstChild("1")
local prompt1 = slot1 and slot1:FindFirstChildWhichIsA("ProximityPrompt", true)

local pPart = prompt1.Parent:IsA("BasePart") and prompt1.Parent or prompt1.Parent.Parent
local pPos = (pPart and pPart:IsA("BasePart")) and pPart.Position or Vector3.zero

log("Step 1: Teleporting near Slot 1 podium...")
local originalCFrame = hrp.CFrame
hrp.CFrame = CFrame.new(pPos + Vector3.new(0, 3, 3))
task.wait(0.3)

log(string.format("Initial Slot 1 Prompt: Action='%s' | Enabled=%s", prompt1.ActionText, tostring(prompt1.Enabled)))

-- Step 2: Look at Backpack UI buttons
local bpMenu = pg and pg:FindFirstChild("Root") and pg.Root:FindFirstChild("Menus") and pg.Root.Menus:FindFirstChild("Backpack")
local scroller = bpMenu and bpMenu:FindFirstChild("ScrollingFrame", true)

if scroller then
    local entries = {}
    for _, c in ipairs(scroller:GetChildren()) do
        if c:IsA("ImageButton") or c:IsA("TextButton") then
            table.insert(entries, c)
        end
    end
    log(string.format("Backpack has %d unit buttons in scroller", #entries))
    if #entries > 0 then
        local targetEntry = entries[1]
        log(string.format("Step 2: Activating backpack entry '%s'...", targetEntry.Name))
        
        -- Inspect upvalues of Activated connection if getconnections available
        if getconnections then
            local conns = getconnections(targetEntry.Activated)
            log("Activated connections count:", #conns)
            for _, conn in ipairs(conns) do
                if conn.Function and debug and debug.getupvalues then
                    local ups = debug.getupvalues(conn.Function)
                    log("  Conn upvalues count:", #ups)
                    for uidx, uval in ipairs(ups) do
                        log(string.format("    u#%d: %s (%s)", uidx, tostring(uval), typeof(uval)))
                    end
                end
            end
        end

        if firesignal then
            firesignal(targetEntry.Activated)
        end
        task.wait(0.4)

        local putBack = pg and pg.Root and pg.Root:FindFirstChild("HUD") and pg.Root.HUD:FindFirstChild("PutBack")
        log("After clicking unit: PutBack Visible =", tostring(putBack and putBack.Visible))
        log(string.format("Slot 1 Prompt after unit selected: Action='%s' | Enabled=%s", prompt1.ActionText, tostring(prompt1.Enabled)))

        -- Step 3: If prompt is enabled and Action is Place, fire it!
        if prompt1.ActionText == "Place" and fireproximityprompt then
            log("Step 3: Firing Place on Slot 1!")
            fireproximityprompt(prompt1)
            task.wait(0.5)
            log(string.format("After Place: Action='%s' | Enabled=%s", prompt1.ActionText, tostring(prompt1.Enabled)))
        end
    end
end

log("Returning to original position...")
hrp.CFrame = originalCFrame

log("==================================================")
log("[GENESIS DIAG V25] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V25.txt"
if writefile then
    pcall(function() writefile(fileName, fullOutput) end)
    print("[GENESIS] Log saved to: " .. fileName)
end
