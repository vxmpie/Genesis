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
log("[GENESIS DIAG V19] PROMPT TRIGGER & CONTROLLER DISSECT")
log("==================================================")

local lp = Players.LocalPlayer
local pg = lp:FindFirstChild("PlayerGui")

-- [1] Find My Plot and inspect Slot 1 prompt before and after
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
        local slot1 = slotsFolder:FindFirstChild("1")
        if slot1 then
            local prompt = slot1:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then
                log(string.format("Slot 1 Prompt Before: Action='%s' Key='%s' Enabled=%s Parent=%s",
                    prompt.ActionText, tostring(prompt.KeyboardKeyCode), tostring(prompt.Enabled), prompt.Parent:GetFullName()))
                
                -- Test fireproximityprompt directly on slot 1 prompt!
                if fireproximityprompt then
                    log("Invoking fireproximityprompt(prompt)...")
                    pcall(function()
                        fireproximityprompt(prompt)
                    end)
                    task.wait(0.5)
                    log(string.format("Slot 1 Prompt After 0.5s: Action='%s' Enabled=%s", prompt.ActionText, tostring(prompt.Enabled)))
                end
            end
        end
    end
end

-- [2] Check if PutBack button can be clicked via firesignal or activate
local putBack = pg and pg:FindFirstChild("Root") and pg.Root:FindFirstChild("HUD") and pg.Root.HUD:FindFirstChild("PutBack")
if putBack then
    log("PutBack Visible after prompt fire:", tostring(putBack.Visible))
    if putBack.Visible then
        log("Testing clicking PutBack...")
        if firesignal then
            pcall(function() firesignal(putBack.Activated) end)
            pcall(function() firesignal(putBack.MouseButton1Click) end)
        end
    end
end

-- [3] Dissect uc.Equip upvalues & constants
local ucMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitController
if ucMod then
    local ok, uc = pcall(require, ucMod)
    if ok and uc then
        if debug and debug.getupvalues then
            local ups = debug.getupvalues(uc.Equip)
            log("uc.Equip upvalues count:", #ups)
            for idx, val in ipairs(ups) do
                log(string.format("  up #%d: %s (%s)", idx, tostring(val), typeof(val)))
            end
        end
        if debug and debug.getconstants then
            local consts = debug.getconstants(uc.Equip)
            log("uc.Equip constants:", table.concat(consts, ", "))
        end
        if debug and debug.getupvalues then
            local unUps = debug.getupvalues(uc.Unequip)
            log("uc.Unequip upvalues count:", #unUps)
            for idx, val in ipairs(unUps) do
                log(string.format("  unUp #%d: %s (%s)", idx, tostring(val), typeof(val)))
            end
        end
    end
end

log("==================================================")
log("[GENESIS DIAG V19] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V19.txt"
if writefile then
    pcall(function() writefile(fileName, fullOutput) end)
    print("[GENESIS] Log saved to: " .. fileName)
end
