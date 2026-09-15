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
log("[GENESIS DIAG V16] PLOTCONTROLLER & PROMPT DEEP DIVE")
log("==================================================")

local lp = Players.LocalPlayer

-- [1] Inspect PlotController instance & methods
local pcMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Plot.PlotController
if pcMod then
    local ok, pc = pcall(require, pcMod)
    if ok and pc then
        log("PlotController require OK:")
        for k, v in pairs(pc) do
            log(string.format("  pc.%s = %s (%s)", tostring(k), tostring(v), typeof(v)))
        end
        if pc.plot then
            log("pc.plot:", pc.plot:GetFullName())
        end
    end
end

-- [2] Inspect Plot Slots & Prompts
local claimed = Workspace:FindFirstChild("Plots") and Workspace.Plots:FindFirstChild("Claimed")
if claimed then
    for _, plot in ipairs(claimed:GetChildren()) do
        local slotsFolder = plot:FindFirstChild("Slots")
        if slotsFolder then
            log("Found Slots Folder in plot:", plot.Name, "Total slots:", #slotsFolder:GetChildren())
            for i = 1, math.min(3, #slotsFolder:GetChildren()) do
                local slotModel = slotsFolder:FindFirstChild(tostring(i))
                if slotModel then
                    log(string.format("  Slot [%d] Name=%s ClassName=%s", i, slotModel.Name, slotModel.ClassName))
                    for _, d in ipairs(slotModel:GetDescendants()) do
                        if d:IsA("ProximityPrompt") then
                            log(string.format("    Prompt in Slot [%d]: Action='%s' Key='%s' Enabled=%s Parent=%s", 
                                i, d.ActionText, tostring(d.KeyboardKeyCode), tostring(d.Enabled), d.Parent.Name))
                        end
                    end
                end
            end
        end
    end
end

-- [3] Inspect UnitController for holding unit / equip logic
local ucMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitController
if ucMod then
    local ok, uc = pcall(require, ucMod)
    if ok and uc then
        log("UnitController inspection:")
        for k, v in pairs(uc) do
            log(string.format("  uc.%s = %s (%s)", tostring(k), tostring(v), typeof(v)))
        end
    end
end

-- [4] Inspect InteractSlot RemoteEvent arguments if possible
local isRE = ReplicatedStorage:FindFirstChild("Network") and ReplicatedStorage.Network:FindFirstChild("PlotService") and ReplicatedStorage.Network.PlotService:FindFirstChild("RE") and ReplicatedStorage.Network.PlotService.RE:FindFirstChild("InteractSlot")
if isRE then
    log("PlotService.RE.InteractSlot found! ClassName:", isRE.ClassName)
end

log("==================================================")
log("[GENESIS DIAG V16] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V16.txt"
if writefile then
    pcall(function() writefile(fileName, fullOutput) end)
    print("[GENESIS] Log saved to: " .. fileName)
end
