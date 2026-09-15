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
        local vis = "n/a"
        if desc:IsA("GuiObject") then
            vis = tostring(desc.Visible)
        end
        log(string.format("  child: %s (%s) visible=%s", desc.Name, desc.ClassName, vis))
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
    local foundBtns = 0
    for _, desc in ipairs(bpMenu:GetDescendants()) do
        if desc:IsA("TextButton") or desc:IsA("ImageButton") then
            foundBtns = foundBtns + 1
            if foundBtns <= 15 then
                local txt = desc:IsA("TextButton") and desc.Text or desc.Name
                log(string.format("  btn #%d: Name='%s' | Text='%s'", foundBtns, desc.Name, txt))
            end
        end
    end
    log("Total buttons in Backpack Menu:", foundBtns)
end

-- [3] Find player's specific Plot in Workspace.Plots.Claimed
log("----------------------------------------")
log("[3] Inspecting Claimed Plots & Podiums:")
local claimed = Workspace:FindFirstChild("Plots") and Workspace.Plots:FindFirstChild("Claimed")
if claimed then
    log("Claimed plots count:", #claimed:GetChildren())
    for _, plot in ipairs(claimed:GetChildren()) do
        local isMyPlot = false
        local owner = plot:FindFirstChild("Owner") or plot:FindFirstChild("Player")
        if owner and owner:IsA("ValueBase") and tostring(owner.Value) == lp.Name then
            isMyPlot = true
        elseif tostring(plot:GetAttribute("Owner")) == lp.Name or tostring(plot:GetAttribute("OwnerId")) == tostring(lp.UserId) then
            isMyPlot = true
        elseif string.find(plot.Name, lp.Name) then
            isMyPlot = true
        end

        log(string.format("  Plot: %s | isMyPlot: %s", plot.Name, tostring(isMyPlot)))
        
        -- Inspect Podiums/Slots in plot
        local count = 0
        for _, desc in ipairs(plot:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                count = count + 1
                local parentPart = desc.Parent
                local partName = parentPart and parentPart.Name or "nil"
                local modelName = parentPart and parentPart.Parent and parentPart.Parent.Name or "nil"
                log(string.format("    Prompt #%d: Action='%s' Object='%s' in Model='%s' Part='%s'", count, desc.ActionText, desc.ObjectText, modelName, partName))
            end
        end
        log(string.format("    Total ProximityPrompts in Plot '%s': %d", plot.Name, count))
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
