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
log("[GENESIS DIAG V17] EQUIPPEDUNIT & PROMPT FIRE TEST")
log("==================================================")

local lp = Players.LocalPlayer
local pg = lp:FindFirstChild("PlayerGui")

-- [1] Check UnitController methods & upvalues
local ucMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitController
if ucMod then
    local ok, uc = pcall(require, ucMod)
    if ok and uc then
        if uc.EquippedUnit then
            local eqOk, eqRes = pcall(function() return uc:EquippedUnit() end)
            log("uc:EquippedUnit() ->", eqOk, tostring(eqRes), typeof(eqRes))
        end
    end
end

-- [2] Check Plot Slots Models and Prompt Objects
local pcMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Plot.PlotController
local myPlot = nil
if pcMod then
    local ok, pc = pcall(require, pcMod)
    if ok and pc and pc.plot then
        myPlot = pc.plot
        log("My Plot confirmed:", myPlot:GetFullName())
    end
end

if myPlot then
    local slotsFolder = myPlot:FindFirstChild("Slots")
    if slotsFolder then
        local slot1 = slotsFolder:FindFirstChild("1")
        if slot1 then
            local prompt = slot1:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then
                log(string.format("Slot 1 Prompt: Action='%s' Object='%s' Key='%s' Enabled=%s", 
                    prompt.ActionText, prompt.ObjectText, tostring(prompt.KeyboardKeyCode), tostring(prompt.Enabled)))
                
                -- Check what happens if we fireproximityprompt on Slot 1
                if fireproximityprompt then
                    log("fireproximityprompt function exists! Testing fire on Slot 1 prompt...")
                    -- We won't trigger immediately, just confirm capability
                    log("fireproximityprompt capability: true")
                else
                    log("fireproximityprompt not supported by executor!")
                end
            end
        end
    end
end

-- [3] Check PutBack Button Click
local putBackObj = pg and pg:FindFirstChild("Root") and pg.Root:FindFirstChild("HUD") and pg.Root.HUD:FindFirstChild("PutBack")
if putBackObj then
    log("PutBack Button: Visible =", tostring(putBackObj.Visible))
    if getconnections then
        local conns = getconnections(putBackObj.MouseButton1Click) or getconnections(putBackObj.Activated)
        log("PutBack connections count:", #conns)
    end
end

log("==================================================")
log("[GENESIS DIAG V17] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V17.txt"
if writefile then
    pcall(function() writefile(fileName, fullOutput) end)
    print("[GENESIS] Log saved to: " .. fileName)
end
