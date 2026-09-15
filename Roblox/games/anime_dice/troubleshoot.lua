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
log("[GENESIS DIAG V15] PLOT OWNER, PODIUM & PUTBACK PROBE")
log("==================================================")

local lp = Players.LocalPlayer
local pg = lp:FindFirstChild("PlayerGui")

-- [1] Inspect Claimed Plot Attributes & Children
log("[1] Inspecting Plot Properties & Attributes:")
local claimed = Workspace:FindFirstChild("Plots") and Workspace.Plots:FindFirstChild("Claimed")
if claimed then
    for _, plot in ipairs(claimed:GetChildren()) do
        log("Plot Name:", plot.Name, "ClassName:", plot.ClassName)
        local attrs = plot:GetAttributes()
        for k, v in pairs(attrs) do
            log(string.format("  Attr: %s = %s (%s)", tostring(k), tostring(v), typeof(v)))
        end
        for _, ch in ipairs(plot:GetChildren()) do
            if not ch:IsA("Model") or ch.Name ~= "Spawn" then
                log("  Direct child:", ch.Name, "ClassName:", ch.ClassName)
            end
        end
    end
end

-- [2] Inspect PlotController or PlotService
log("----------------------------------------")
log("[2] Inspecting Framework Plot Controllers:")
local pcMod = ReplicatedStorage:FindFirstChild("Framework") and ReplicatedStorage.Framework.Features:FindFirstChild("Plot")
if pcMod then
    for _, desc in ipairs(pcMod:GetDescendants()) do
        if desc:IsA("ModuleScript") then
            log("  Plot Module:", desc.Name, desc:GetFullName())
            local ok, m = pcall(require, desc)
            if ok and type(m) == "table" then
                local keys = {}
                for k, v in pairs(m) do
                    table.insert(keys, tostring(k) .. ":" .. typeof(v))
                end
                log("    keys:", table.concat(keys, ", "))
            end
        end
    end
end

-- [3] Inspect PutBack connections / click handlers
log("----------------------------------------")
log("[3] Inspecting PutBack UI Object:")
local putBackObj = pg and pg:FindFirstChild("Root") and pg.Root:FindFirstChild("HUD") and pg.Root.HUD:FindFirstChild("PutBack")
if putBackObj then
    log("PutBack Object ClassName:", putBackObj.ClassName)
    for _, d in ipairs(putBackObj:GetDescendants()) do
        if d:IsA("GuiButton") or d:IsA("TextButton") or d:IsA("ImageButton") then
            log("  Clickable in PutBack:", d.Name, d.ClassName, "Visible:", d.Visible)
        end
    end
end

-- [4] Inspect ProximityPrompt properties on Podiums
log("----------------------------------------")
log("[4] Inspecting Podiums ProximityPrompts:")
if claimed then
    for _, plot in ipairs(claimed:GetChildren()) do
        local pCount = 0
        for _, desc in ipairs(plot:GetDescendants()) do
            if desc:IsA("ProximityPrompt") and pCount < 5 then
                pCount = pCount + 1
                log(string.format("  Prompt #%d: Action='%s' Object='%s' Key='%s' HoldDuration=%.2f Enabled=%s", 
                    pCount, desc.ActionText, desc.ObjectText, tostring(desc.KeyboardKeyCode), desc.HoldDuration, tostring(desc.Enabled)))
                log("    Parent:", desc.Parent:GetFullName())
                -- Check if parent model has slot number or attributes
                local mParent = desc.Parent.Parent
                if mParent then
                    log("    Model Parent:", mParent.Name)
                    for ak, av in pairs(mParent:GetAttributes()) do
                        log("      Model Attr:", ak, "=", tostring(av))
                    end
                end
            end
        end
    end
end

-- [5] Inspect Backpack EntryTemplate button click
log("----------------------------------------")
log("[5] Inspecting Backpack EntryTemplate:")
local bpMenu = pg and pg:FindFirstChild("Root") and pg.Root:FindFirstChild("Menus") and pg.Root.Menus:FindFirstChild("Backpack")
if bpMenu then
    local entry = bpMenu:FindFirstChild("EntryTemplate", true)
    if entry then
        log("  Found EntryTemplate:", entry:GetFullName(), "ClassName:", entry.ClassName)
        for _, c in ipairs(entry:GetChildren()) do
            log("    child:", c.Name, c.ClassName)
        end
    end
end

log("==================================================")
log("[GENESIS DIAG V15] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V15.txt"
if writefile then
    pcall(function() writefile(fileName, fullOutput) end)
    print("[GENESIS] Log saved to: " .. fileName)
end
