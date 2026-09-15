local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

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
log("[GENESIS DIAG V13] PODIUM & PROXIMITY PROMPT PROBE")
log("==================================================")

local lp = Players.LocalPlayer

-- [1] Find Player's Plot in Workspace
log("[1] Searching Workspace for Plots / Podiums:")
local foundPlots = {}
for _, obj in ipairs(Workspace:GetChildren()) do
    local name = obj.Name
    if string.find(name, "Plot") or string.find(name, "Podium") or string.find(name, "Island") or string.find(name, "Base") then
        table.insert(foundPlots, obj)
        log("  Found Workspace child:", name, "ClassName:", obj.ClassName)
    end
end

-- Check Workspace.Plots or Plots folder if exists
local plotsFolder = Workspace:FindFirstChild("Plots") or Workspace:FindFirstChild("PlayerPlots")
if plotsFolder then
    log("  Plots folder found with children:", #plotsFolder:GetChildren())
    for _, p in ipairs(plotsFolder:GetChildren()) do
        log("    Plot child:", p.Name, "ClassName:", p.ClassName)
    end
end

-- [2] Search ProximityPrompts in Workspace
log("----------------------------------------")
log("[2] Searching ProximityPrompts near player:")
local pChar = lp.Character or lp.CharacterAdded:Wait()
local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart")

local allPrompts = {}
for _, desc in ipairs(Workspace:GetDescendants()) do
    if desc:IsA("ProximityPrompt") then
        local actionText = desc.ActionText
        local objectText = desc.ObjectText
        local parentName = desc.Parent and desc.Parent.Name or "nil"
        local parentClass = desc.Parent and desc.Parent.ClassName or "nil"
        local dist = 9999
        if pRoot and desc.Parent and desc.Parent:IsA("BasePart") then
            dist = (pRoot.Position - desc.Parent.Position).Magnitude
        end
        log(string.format("  Prompt: Action='%s' | Object='%s' | Parent='%s' (%s) | Dist=%.1f", actionText, objectText, parentName, parentClass, dist))
        table.insert(allPrompts, desc)
    end
end
log("Total ProximityPrompts found in Workspace:", #allPrompts)

-- [3] Check PlotService Remotes specifically InteractSlot
log("----------------------------------------")
log("[3] Inspecting PlotService Remotes:")
local plotService = ReplicatedStorage:FindFirstChild("Network") and ReplicatedStorage.Network:FindFirstChild("PlotService")
if plotService then
    for _, f in ipairs(plotService:GetChildren()) do
        for _, remote in ipairs(f:GetChildren()) do
            log(string.format("  Remote: %s.%s (%s)", f.Name, remote.Name, remote.ClassName))
        end
    end
end

-- [4] Check Character Tools (Equipped item in hand)
log("----------------------------------------")
log("[4] Checking Character & Backpack Tools:")
if pChar then
    for _, ch in ipairs(pChar:GetChildren()) do
        if ch:IsA("Tool") or ch:IsA("Model") then
            if ch.Name ~= "Animate" then
                log("  Character child (held):", ch.Name, "ClassName:", ch.ClassName)
            end
        end
    end
end

-- [5] Check PlayerGui for "Put Back" button
log("----------------------------------------")
log("[5] Searching PlayerGui for 'Put Back' or Pickup UI:")
local pg = lp:FindFirstChild("PlayerGui")
if pg then
    for _, desc in ipairs(pg:GetDescendants()) do
        if desc:IsA("TextButton") or desc:IsA("ImageButton") or desc:IsA("TextLabel") then
            local text = desc:IsA("TextLabel") and desc.Text or (desc:IsA("TextButton") and desc.Text or "")
            if string.find(string.lower(text), "put") or string.find(string.lower(text), "back") or string.find(string.lower(text), "pickup") or string.find(string.lower(text), "place") then
                log(string.format("  Found UI element: Name='%s' | Text='%s' | Path=%s", desc.Name, text, desc:GetFullName()))
            end
        end
    end
end

log("==================================================")
log("[GENESIS DIAG V13] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V13.txt"
if writefile then
    pcall(function() writefile(fileName, fullOutput) end)
    print("[GENESIS] Log saved to: " .. fileName)
end
