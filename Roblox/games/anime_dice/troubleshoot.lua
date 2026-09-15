local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local fileName = "Genesis_AnimeDice_Diag_V36.txt"
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

    if writefile then
        pcall(function()
            writefile(fileName, table.concat(logLines, "\n"))
        end)
    end
end

log("==================================================")
log("[GENESIS DIAG V36] DEEP DISSECTION OF EQUIP & PROMPT")
log("==================================================")

local lp = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hrp = char:FindFirstChild("HumanoidRootPart")
local pg = lp:FindFirstChild("PlayerGui")

-- Part 1: Dissect UnitController.Equip
pcall(function()
    local ucMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitController
    if ucMod then
        local uc = require(ucMod)
        log("Dissecting uc.Equip:")
        if debug and debug.getconstants then
            local consts = debug.getconstants(uc.Equip)
            log("  uc.Equip constants count:", #consts)
            for i, c in ipairs(consts) do
                log(string.format("    Const #%d = %s (%s)", i, tostring(c), type(c)))
            end
        end
        if debug and debug.getupvalues then
            local ups = debug.getupvalues(uc.Equip)
            log("  uc.Equip upvalues count:", #ups)
            for i, u in ipairs(ups) do
                log(string.format("    Up #%d = %s (%s)", i, tostring(u), type(u)))
                if type(u) == "function" and debug.getconstants then
                    local subConsts = debug.getconstants(u)
                    log(string.format("      Sub-function #%d constants:", i))
                    for sci, sc in ipairs(subConsts) do
                        log(string.format("        %s", tostring(sc)))
                    end
                end
            end
        end

        -- Test calling with (isagoGuid) vs (uc, isagoGuid)
        local isagoGuid = "abece858-d655-4b73-9b20-6bb38fa607f1"
        log("Testing uc.Equip(isagoGuid) [without self]:")
        local ok1, res1 = pcall(function() return uc.Equip(isagoGuid) end)
        log("  Result without self -> ok:", ok1, "res:", res1)

        log("Testing uc:Equip(isagoGuid) [with self]:")
        local ok2, res2 = pcall(function() return uc:Equip(isagoGuid) end)
        log("  Result with self -> ok:", ok2, "res:", res2)
    end
end)

-- Part 2: Dissect Backpack Button Conn #1 Function
local bpMenu = pg and pg:FindFirstChild("Root") and pg.Root:FindFirstChild("Menus") and pg.Root.Menus:FindFirstChild("Backpack")
local scroller = bpMenu and bpMenu:FindFirstChild("ScrollingFrame", true)
if scroller and getconnections and debug then
    local btn = scroller:FindFirstChildWhichIsA("ImageButton")
    if btn then
        local conns = getconnections(btn.Activated)
        if #conns > 0 and conns[1].Function then
            log("Dissecting Button Activated Function:")
            if debug.getconstants then
                local consts = debug.getconstants(conns[1].Function)
                log("  Button Activated constants count:", #consts)
                for i, c in ipairs(consts) do
                    log(string.format("    Const #%d = %s", i, tostring(c)))
                end
            end
        end
    end
end

-- Part 3: Test placing with Button Activated vs uc:Equip
local pcMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Plot.PlotController
local myPlot = nil
if pcMod then
    local ok, pc = pcall(require, pcMod)
    if ok and pc and pc.plot then myPlot = pc.plot end
end

if myPlot and hrp then
    local slot1 = myPlot:FindFirstChild("Slots") and myPlot.Slots:FindFirstChild("1")
    local prompt1 = slot1 and slot1:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt1 then
        local pPart = prompt1.Parent:IsA("BasePart") and prompt1.Parent or prompt1.Parent.Parent
        local pPos = (pPart and pPart:IsA("BasePart")) and pPart.Position or Vector3.zero
        local origCF = hrp.CFrame
        hrp.CFrame = CFrame.new(pPos + Vector3.new(0, 3, 3))
        task.wait(0.3)

        log(string.format("Testing Button Activated Placement on Slot 1 (Current Action='%s')...", prompt1.ActionText))
        local targetBtn = scroller and scroller:FindFirstChildWhichIsA("ImageButton")
        if targetBtn and firesignal then
            log("Firesignal on backpack button:", targetBtn.Name)
            firesignal(targetBtn.Activated)
            task.wait(0.4)
            log(string.format("Prompt after button click -> Action='%s' | Enabled=%s", prompt1.ActionText, tostring(prompt1.Enabled)))
            if fireproximityprompt then
                log("Firing fireproximityprompt...")
                fireproximityprompt(prompt1)
                task.wait(0.6)
                log(string.format("Prompt after fire -> Action='%s' | Enabled=%s", prompt1.ActionText, tostring(prompt1.Enabled)))
            end
        end
        hrp.CFrame = origCF
    end
end

log("==================================================")
log("[GENESIS DIAG V36] COMPLETED")
log("==================================================")
log("File successfully saved to workspace:", fileName)
