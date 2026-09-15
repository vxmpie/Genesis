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
log("[GENESIS DIAG V14] UI INTERACTION & PLOT PROBE")
log("==================================================")

local lp = Players.LocalPlayer
local pg = lp:FindFirstChild("PlayerGui")

-- [1] Inspect PutBack Frame in HUD
log("[1] Inspecting PutBack UI:")
local putBackObj = pg and pg:FindFirstChild("Root") and pg.Root:FindFirstChild("HUD") and pg.Root.HUD:FindFirstChild("PutBack")
if putBackObj then
    log("PutBack Object found:", putBackObj:GetFullName())
    for _, desc in ipairs(putBackObj:GetDescendants()) do
        log(string.format("  child: %s (%s) visible=%s", desc.Name, desc.ClassName, tostring(rawget(desc, "Visible"))))
    end
else
    log("PutBack Object not found in HUD!")
end

-- [2] Inspect Backpack UI in Menus
log("----------------------------------------")
log("[2] Inspecting Backpack Menu:")
local bpMenu = pg and pg:FindFirstChild("Root") and pg.Root:FindFirstChild("Menus") and pg.Root.Menus:FindFirstChild("Backpack")
if bpMenu then
    log("Backpack Menu found:", bpMenu:GetFullName())
    -- Look for Equip / Hold / Place buttons
    local foundBtns = 0
    for _, desc in ipairs(bpMenu:GetDescendants()) do
        if desc:IsA("TextButton") or desc:IsA("ImageButton") then
            foundBtns = foundBtns + 1
            if foundBtns <= 15 then
                local txt = desc:IsA("TextButton") and desc.Text or desc.Name
                log(string.format("  btn #%d: Name='%s' | Text='%s' | Path=%s", foundBtns, desc.Name, txt, desc.Name))
            end
        end
    end
    log("Total buttons in Backpack Menu:", foundBtns)
end

-- [3] Find player's specific Plot in Workspace.Plots.Claimed
log("----------------------------------------")
log("[3] Inspecting Claimed Plots:")
local claimed = Workspace:FindFirstChild("Plots") and Workspace.Plots:FindFirstChild("Claimed")
if claimed then
    log("Claimed plots count:", #claimed:GetChildren())
    for _, plot in ipairs(claimed:GetChildren()) do
        local owner = plot:FindFirstChild("Owner") or plot:GetAttribute("Owner") or plot:FindFirstChild("Player")
        local ownerName = "nil"
        if owner then
            ownerName = tostring(owner:IsA("ValueBase") and owner.Value or owner)
        end
        log(string.format("  Plot: %s | Owner: %s", plot.Name, ownerName))
        
        -- Check if this plot belongs to us or inspect its children (Podiums/Slots)
        local slotsFolder = plot:FindFirstChild("Slots") or plot:FindFirstChild("Podiums") or plot
        local podiumCount = 0
        for _, ch in ipairs(slotsFolder:GetChildren()) do
            if string.find(ch.Name, "Slot") or string.find(ch.Name, "Podium") or tonumber(ch.Name) then
                podiumCount = podiumCount + 1
                if podiumCount <= 5 then
                    log(string.format("    Slot/Podium: %s (%s)", ch.Name, ch.ClassName))
                    for _, sub in ipairs(ch:GetDescendants()) do
                        if sub:IsA("ProximityPrompt") then
                            log(string.format("      ProximityPrompt in %s: Action='%s', Object='%s', HoldDuration=%.2f", ch.Name, sub.ActionText, sub.ObjectText, sub.HoldDuration))
                        end
                    end
                end
            end
        end
        log("    Total podiums/slots in this plot:", podiumCount)
    end
end

log("==================================================")
log("[GENESIS DIAG V14] COMPLETED")
log("==================================================")

local fullOutput = table.concat(logLines, "\n")
local fileName = "Genesis_AnimeDice_Diag_V14.txt"
if writefile then
    pcall(function() writefile(fileName, fullOutput) end)
    print("[GENESIS] Log saved to: " .. fileName)
end
