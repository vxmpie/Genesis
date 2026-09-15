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
log("[GENESIS DIAG V20] PLACE & PICKUP CYCLE PROBE")
log("==================================================")

local lp = Players.LocalPlayer
local pg = lp:FindFirstChild("PlayerGui")

-- [1] Find My Plot
local pcMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features.Plot.PlotController
local myPlot = nil
if pcMod then
    local ok, pc = pcall(require, pcMod)
    if ok and pc and pc.plot then
        myPlot = pc.plot
    end
end

-- [2] Check Slot 1 prompt state right now
if myPlot then
    local slotsFolder = myPlot:FindFirstChild("Slots")
    local slot1 = slotsFolder and slotsFolder:FindFirstChild("1")
    local prompt1 = slot1 and slot1:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt1 then
        log(string.format("Slot 1 Prompt Current: Action='%s' Key='%s' Enabled=%s", prompt1.ActionText, tostring(prompt1.KeyboardKeyCode), tostring(prompt1.Enabled)))
        
        -- If prompt is 'Place', test fireproximityprompt to see if it places held unit!
        if prompt1.ActionText == "Place" and fireproximityprompt then
            log("Prompt is 'Place'! Firing fireproximityprompt to place held unit...")
            fireproximityprompt(prompt1)
            task.wait(0.5)
            log(string.format("Slot 1 Prompt after Place fire: Action='%s' Enabled=%s", prompt1.ActionText, tostring(prompt1.Enabled)))
        end
    end
end

-- [3] Check PutBack button action
local putBack = pg and pg:FindFirstChild("Root") and pg.Root:FindFirstChild("HUD") and pg.Root.HUD:FindFirstChild("PutBack")
if putBack then
    log("PutBack Button Visible:", tostring(putBack.Visible))
end

-- [4] Inspect Backpack EntryTemplate click behavior
local bpMenu = pg and pg:FindFirstChild("Root") and pg.Root:FindFirstChild("Menus") and pg.Root.Menus:FindFirstChild("Backpack")
if bpMenu then
    local scroller = bpMenu:FindFirstChild("ScrollingFrame", true)
    if scroller then
        local entries = {}
        for _, c in ipairs(scroller:GetChildren()) do
            if c:IsA("ImageButton") or c:IsA("TextButton") then
                table.insert(entries, c)
            end
        end
        log(string.format("Backpack scroller has %d entries", #entries))
        if #entries > 0 then
            local firstEntry = entries[1]
            local topLbl = firstEntry:FindFirstChild("TopLabel", true)
            local botLbl = firstEntry:FindFirstChild("BottomLabel", true)
            log(string.format("First Entry: Name='%s' Top='%s' Bot='%s' Class='%s'", 
                firstEntry.Name, topLbl and topLbl.Text or "n/a", botLbl and botLbl.Text or "n/a", firstEntry.ClassName))
        end
    end
end

log("==================================================")
log("[GENESIS DIAG V20] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V20.txt"
if writefile then
    pcall(function() writefile(fileName, fullOutput) end)
    print("[GENESIS] Log saved to: " .. fileName)
end
