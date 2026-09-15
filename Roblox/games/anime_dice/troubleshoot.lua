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
log("[GENESIS DIAG V26] ALL SLOTS & PROMPT AUDIT")
log("==================================================")

local lp = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hrp = char:FindFirstChild("HumanoidRootPart")

local pcMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Plot.PlotController
local myPlot = nil
if pcMod then
    local ok, pc = pcall(require, pcMod)
    if ok and pc and pc.plot then myPlot = pc.plot end
end

if not myPlot then
    log("Error: Plot not found!")
    return
end

local slotsFolder = myPlot:FindFirstChild("Slots")
if not slotsFolder then
    log("Error: Slots folder not found!")
    return
end

log("Total children in Slots folder:", #slotsFolder:GetChildren())
for _, slotObj in ipairs(slotsFolder:GetChildren()) do
    local prompt = slotObj:FindFirstChildWhichIsA("ProximityPrompt", true)
    local pInfo = "No Prompt"
    if prompt then
        local pPart = prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent.Parent
        local pPos = (pPart and pPart:IsA("BasePart")) and pPart.Position or Vector3.zero
        local dist = hrp and (hrp.Position - pPos).Magnitude or -1
        pInfo = string.format("Action='%s' Enabled=%s MaxDist=%.1f CurrentDist=%.1f", 
            prompt.ActionText, tostring(prompt.Enabled), prompt.MaxActivationDistance, dist)
    end
    log(string.format("  Slot [%s] Class=%s -> %s", slotObj.Name, slotObj.ClassName, pInfo))
end

-- Inspect Floor2 if any
local floor2 = myPlot:FindFirstChild("Floor2")
if floor2 then
    log("Floor2 found! Children count:", #floor2:GetChildren())
    for _, ch in ipairs(floor2:GetChildren()) do
        if string.find(ch.Name, "Slot") or ch:FindFirstChildWhichIsA("ProximityPrompt", true) then
            log("  Floor2 item:", ch.Name, ch.ClassName)
        end
    end
end

-- Inspect Backpack units & UI buttons
local pg = lp:FindFirstChild("PlayerGui")
local bpMenu = pg and pg:FindFirstChild("Root") and pg.Root:FindFirstChild("Menus") and pg.Root.Menus:FindFirstChild("Backpack")
local scroller = bpMenu and bpMenu:FindFirstChild("ScrollingFrame", true)
if scroller then
    local btns = {}
    for _, c in ipairs(scroller:GetChildren()) do
        if c:IsA("ImageButton") or c:IsA("TextButton") then
            table.insert(btns, c)
        end
    end
    log(string.format("Backpack buttons in scroller: %d", #btns))
    for idx = 1, math.min(5, #btns) do
        local b = btns[idx]
        local top = b:FindFirstChild("TopLabel", true)
        local bot = b:FindFirstChild("BottomLabel", true)
        local guidVal = nil
        if getconnections then
            local conns = getconnections(b.Activated)
            for _, conn in ipairs(conns) do
                if conn.Function and debug and debug.getupvalues then
                    local ups = debug.getupvalues(conn.Function)
                    for _, uv in ipairs(ups) do
                        if type(uv) == "string" and string.len(uv) > 20 and string.find(uv, "-") then
                            guidVal = uv
                            break
                        end
                    end
                end
            end
        end
        log(string.format("  Button #%d: Top='%s' Bot='%s' GUID='%s'", 
            idx, top and top.Text or "n/a", bot and bot.Text or "n/a", tostring(guidVal)))
    end
end

log("==================================================")
log("[GENESIS DIAG V26] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V26.txt"
if writefile then
    pcall(function() writefile(fileName, fullOutput) end)
    print("[GENESIS] Log saved to: " .. fileName)
end
