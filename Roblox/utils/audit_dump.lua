--[[
    GENESIS GAME CENSUS & MEMORY AUDITOR
    Real-Time Engine Diagnostics & Object Census for Dungeon Quest & Universal Games
]]

local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GenesisAuditHUD"
screenGui.ResetOnSpawn = false
pcall(function()
    if gethui then
        screenGui.Parent = gethui()
    else
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end)

local label = Instance.new("TextLabel")
label.Size = UDim2.new(0, 440, 0, 110)
label.Position = UDim2.new(0.5, -220, 0.08, 0)
label.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
label.TextColor3 = Color3.fromRGB(0, 255, 180)
label.Font = Enum.Font.GothamBold
label.TextSize = 13
label.Text = "[GENESIS AUDIT] Initializing Engine Census..."
label.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = label

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(45, 200, 105)
stroke.Thickness = 1.5
stroke.Parent = label

local function updateHUD(txt)
    print("[GENESIS AUDIT] " .. txt)
    label.Text = "[GENESIS ENGINE AUDIT]
" .. txt
end

task.spawn(function()
    -- STEP 1: วัด Memory
    updateHUD("[Step 1/4] Reading Engine Memory & RAM...")
    local totalRAM = 0
    local luaHeap = 0
    pcall(function() totalRAM = Stats:GetTotalMemoryUsageMb() end)
    pcall(function() luaHeap = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.LuaHeap) end)
    print(string.format("  -> Total Game RAM: %.2f MB", totalRAM))
    print(string.format("  -> Lua Script Memory (Heap): %.2f MB", luaHeap))
    task.wait(0.4)

    -- STEP 2: ตรวจนับ ModuleScripts, Remotes, และ Tags
    updateHUD("[Step 2/4] Counting Modules, Remotes & Collection Tags...")
    local allModules = {}
    local allRemotes = {}
    local allTags = {}
    
    pcall(function()
        for _, obj in ipairs(game:GetDescendants()) do
            if obj:IsA("ModuleScript") then
                table.insert(allModules, obj:GetFullName())
            elseif obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("BindableEvent") or obj:IsA("BindableFunction") then
                table.insert(allRemotes, obj:GetFullName())
            end
        end
    end)

    pcall(function()
        allTags = CollectionService:GetAllTags()
    end)

    print(string.format("  -> Total Modules in Game: %d", #allModules))
    print(string.format("  -> Total Remotes in Game: %d", #allRemotes))
    print(string.format("  -> Total CollectionService Tags: %d", #allTags))
    task.wait(0.4)

    -- STEP 3: ตรวจนับ Instance ในแต่ละ Service
    updateHUD("[Step 3/4] Counting Total Instances across Services...")
    local serviceCounts = {}
    local totalInstances = 0
    
    local targetServices = {
        workspace,
        game:GetService("ReplicatedStorage"),
        game:GetService("Lighting"),
        game:GetService("SoundService"),
        game:GetService("StarterPlayer"),
        game:GetService("StarterGui"),
        LocalPlayer:FindFirstChild("PlayerGui")
    }
    
    for _, svc in ipairs(targetServices) do
        if svc then
            local c = 0
            pcall(function()
                c = #svc:GetDescendants()
            end)
            serviceCounts[svc.Name] = c
            totalInstances = totalInstances + c
            print(string.format("  -> Service [%s]: %d objects", svc.Name, c))
        end
    end
    print(string.format("  -> Total Objects in Game: %d", totalInstances))
    task.wait(0.4)

    -- STEP 4: บันทึกลง JSON
    updateHUD("[Step 4/4] Saving Report to Genesis_GameMemoryAudit.json...")
    local reportData = {
        Timestamp = os.date("%Y-%m-%d %X"),
        PlaceId = game.PlaceId,
        GameId = game.GameId,
        Memory_Total_MB = math.floor(totalRAM * 100) / 100,
        Memory_LuaHeap_MB = math.floor(luaHeap * 100) / 100,
        TotalInstances = totalInstances,
        TotalModules = #allModules,
        TotalRemotes = #allRemotes,
        TotalTags = #allTags,
        CollectionTags = allTags,
        ServiceBreakdown = serviceCounts,
        ModulesList = allModules,
        RemotesList = allRemotes
    }
    
    local okEnc, jsonStr = pcall(function() return HttpService:JSONEncode(reportData) end)
    if okEnc and jsonStr and writefile then
        writefile("Genesis_GameMemoryAudit.json", jsonStr)
        print("  -> Successfully saved Genesis_GameMemoryAudit.json! Size: " .. math.floor(#jsonStr / 1024) .. " KB")
    end

    -- แสดงผลสรุปปิดท้าย
    local finalMsg = string.format("COMPLETED!
RAM: %.1f MB | Lua: %.1f MB
Objects: %d | Modules: %d | Remotes: %d | Tags: %d", 
        totalRAM, luaHeap, totalInstances, #allModules, #allRemotes, #allTags
    )
    updateHUD(finalMsg)
    print("
==========================================")
    print("[GENESIS AUDIT SUMMARY]")
    print(finalMsg)
    print("==========================================
")

    task.wait(8)
    pcall(function() screenGui:Destroy() end)
end)
