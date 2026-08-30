--[[
    GENESIS UNIVERSAL DEEP DUMPER (DELTA / UNC OPTIMIZED)
    High-Performance Game Reverse-Engineering & Architecture Extractor
    Designed for Dungeon Quest Reborn & Universal Roblox Games
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local CollectionService = game:GetService("CollectionService")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "GENESIS DUMP",
            Text = text or "",
            Duration = duration or 4
        })
    end)
    print(string.format("[GENESIS DUMP] %s: %s", tostring(title), tostring(text)))
end

notify("GENESIS EXTRACTOR", "Initializing Universal Deep Extraction Engine...", 4)

local MasterDump = {
    DumpInfo = {
        Timestamp = os.date("%Y-%m-%d %X"),
        PlaceId = game.PlaceId,
        GameId = game.GameId,
        JobId = game.JobId,
        PlayerName = LocalPlayer.Name,
        UserId = LocalPlayer.UserId,
        Executor = (identifyexecutor and identifyexecutor()) or "Delta/Standard"
    },
    SystemMemory = {},
    RemotesHierarchy = {},
    ModulesDatabase = {},
    WorkspaceMap = {},
    PlayerGuiSummary = {},
    TagsAndCollections = {},
    StatsBreakdown = {}
}

-- High-Efficiency Safe Serializer with Cycle Protection & Metatable Bypass
local function deepSerialize(val, maxDepth, currentDepth, seen)
    currentDepth = currentDepth or 0
    seen = seen or {}

    if currentDepth > (maxDepth or 4) then return "<MaxDepthReached>" end

    local t = typeof(val)
    if t == "number" then
        if val ~= val then return "<NaN>" end
        if val == math.huge then return "<Infinity>" end
        if val == -math.huge then return "<-Infinity>" end
        return val
    elseif t == "string" or t == "boolean" then
        return val
    elseif t == "Vector3" then
        return { X = math.floor(val.X * 100) / 100, Y = math.floor(val.Y * 100) / 100, Z = math.floor(val.Z * 100) / 100 }
    elseif t == "Vector2" then
        return { X = math.floor(val.X * 100) / 100, Y = math.floor(val.Y * 100) / 100 }
    elseif t == "CFrame" then
        local p = val.Position
        local lv = val.LookVector
        return {
            Pos = { X = math.floor(p.X * 100) / 100, Y = math.floor(p.Y * 100) / 100, Z = math.floor(p.Z * 100) / 100 },
            Look = { X = math.floor(lv.X * 100) / 100, Y = math.floor(lv.Y * 100) / 100, Z = math.floor(lv.Z * 100) / 100 }
        }
    elseif t == "Color3" then
        return { R = math.floor(val.R * 255), G = math.floor(val.G * 255), B = math.floor(val.B * 255) }
    elseif t == "EnumItem" then
        return tostring(val)
    elseif t == "Instance" then
        local instInfo = { Name = val.Name, Class = val.ClassName, Path = val:GetFullName() }
        if val:IsA("BasePart") then
            instInfo.Size = { X = math.floor(val.Size.X * 10) / 10, Y = math.floor(val.Size.Y * 10) / 10, Z = math.floor(val.Size.Z * 10) / 10 }
            instInfo.Transparency = val.Transparency
            instInfo.CanCollide = val.CanCollide
            instInfo.Material = tostring(val.Material)
        end
        return instInfo
    elseif t == "table" then
        if seen[val] then return "<CyclicRef>" end
        seen[val] = true

        local clean = {}
        local count = 0
        for k, v in pairs(val) do
            count = count + 1
            if count > 300 then
                clean["__truncated__"] = "...more items truncated"
                break
            end
            local keyStr = tostring(k)
            clean[keyStr] = deepSerialize(v, maxDepth, currentDepth + 1, seen)
        end
        return clean
    else
        return tostring(val)
    end
end

-- ================= STEP 1: ENGINE MEMORY & PERFORMANCE =================
task.spawn(function()
    pcall(function()
        local totalRAM = 0
        local luaHeap = 0
        pcall(function() totalRAM = Stats:GetTotalMemoryUsageMb() end)
        pcall(function() luaHeap = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.LuaHeap) end)

        MasterDump.SystemMemory = {
            TotalGameRAM_MB = math.floor(totalRAM * 100) / 100,
            LuaHeap_MB = math.floor(luaHeap * 100) / 100
        }
    end)
end)

-- ================= STEP 2: NETWORK REMOTES MAP =================
task.spawn(function()
    pcall(function()
        local remoteCount = 0
        local remotesTree = {}

        local targetServices = {
            ReplicatedStorage,
            game:GetService("StarterGui"),
            game:GetService("Players"),
            workspace
        }

        for _, svc in ipairs(targetServices) do
            if svc then
                for _, obj in ipairs(svc:GetDescendants()) do
                    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("BindableEvent") or obj:IsA("BindableFunction") then
                        remoteCount = remoteCount + 1
                        local category = obj.Parent and obj.Parent.Name or "Root"
                        if not remotesTree[category] then remotesTree[category] = {} end
                        
                        table.insert(remotesTree[category], {
                            Name = obj.Name,
                            Type = obj.ClassName,
                            Path = obj:GetFullName(),
                            Attributes = obj:GetAttributes()
                        })
                    end
                end
            end
        end

        MasterDump.RemotesHierarchy = remotesTree
        print(string.format("[GENESIS DUMP] Mapped %d Remotes across all game services.", remoteCount))
    end)
end)

-- ================= STEP 3: UNIVERSAL MODULESCRIPT AUTO-REQUIRE =================
task.spawn(function()
    pcall(function()
        local allModules = {}
        local moduleCandidates = {}

        -- 1. Gather all ModuleScripts from ReplicatedStorage & PlayerScripts
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("ModuleScript") then
                table.insert(moduleCandidates, obj)
            end
        end

        local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
        if playerScripts then
            for _, obj in ipairs(playerScripts:GetDescendants()) do
                if obj:IsA("ModuleScript") then
                    table.insert(moduleCandidates, obj)
                end
            end
        end

        -- 2. If executor has getloadedmodules, add them
        if getloadedmodules then
            pcall(function()
                local loaded = getloadedmodules()
                if type(loaded) == "table" then
                    for _, mod in ipairs(loaded) do
                        if typeof(mod) == "Instance" and mod:IsA("ModuleScript") then
                            local alreadyHave = false
                            for _, existing in ipairs(moduleCandidates) do
                                if existing == mod then
                                    alreadyHave = true
                                    break
                                end
                            end
                            if not alreadyHave then
                                table.insert(moduleCandidates, mod)
                            end
                        end
                    end
                end
            end)
        end

        print(string.format("[GENESIS DUMP] Found %d ModuleScripts. Extracting data tables...", #moduleCandidates))

        local extractedCount = 0
        for _, mod in ipairs(moduleCandidates) do
            local modName = mod.Name
            local modPath = mod:GetFullName()

            -- Filter out UI utility noise if unnecessary, or extract everything safely
            local success, result = pcall(function()
                return require(mod)
            end)

            if success and result ~= nil then
                extractedCount = extractedCount + 1
                if type(result) == "table" then
                    allModules[modName] = {
                        Path = modPath,
                        Type = "table",
                        KeysCount = #result > 0 and #result or nil,
                        Data = deepSerialize(result, 3, 0, {})
                    }
                else
                    allModules[modName] = {
                        Path = modPath,
                        Type = typeof(result),
                        Value = tostring(result)
                    }
                end
            end
        end

        MasterDump.ModulesDatabase = allModules
        print(string.format("[GENESIS DUMP] Successfully required and dumped %d ModuleScripts.", extractedCount))
    end)
end)

-- ================= STEP 4: WORKSPACE, DUNGEON, & HITBOX SCANNER =================
task.spawn(function()
    pcall(function()
        local wsTree = {}

        local function inspectObject(inst, depth, maxD)
            depth = depth or 0
            if depth > (maxD or 3) then return { Name = inst.Name, Class = inst.ClassName } end

            local node = {
                Name = inst.Name,
                Class = inst.ClassName,
                Attributes = inst:GetAttributes()
            }

            -- Check for CollectionService Tags (Crucial for Bosses, Spells, Hitbox Zones)
            local tags = CollectionService:GetTags(inst)
            if tags and #tags > 0 then
                node.Tags = tags
            end

            if inst:IsA("BasePart") then
                node.Position = { X = math.floor(inst.Position.X * 100) / 100, Y = math.floor(inst.Position.Y * 100) / 100, Z = math.floor(inst.Position.Z * 100) / 100 }
                node.Size = { X = math.floor(inst.Size.X * 100) / 100, Y = math.floor(inst.Size.Y * 100) / 100, Z = math.floor(inst.Size.Z * 100) / 100 }
                node.Transparency = inst.Transparency
                node.CanCollide = inst.CanCollide
                node.Material = tostring(inst.Material)
                node.Color = { R = math.floor(inst.Color.R * 255), G = math.floor(inst.Color.G * 255), B = math.floor(inst.Color.B * 255) }

                -- Special Flag for Potential Hitbox / Warning Telegraph Zones
                if not inst.CanCollide and (inst.Transparency > 0 or inst.Material == Enum.Material.Neon or string.find(string.lower(inst.Name), "hitbox") or string.find(string.lower(inst.Name), "zone") or string.find(string.lower(inst.Name), "spell") or string.find(string.lower(inst.Name), "aoe")) then
                    node.IsTelegraphZone = true
                end
            elseif inst:IsA("Model") then
                local pp = inst.PrimaryPart or inst:FindFirstChild("HumanoidRootPart") or inst:FindFirstChild("Torso")
                if pp then
                    node.Position = { X = math.floor(pp.Position.X * 100) / 100, Y = math.floor(pp.Position.Y * 100) / 100, Z = math.floor(pp.Position.Z * 100) / 100 }
                end
                local hum = inst:FindFirstChildOfClass("Humanoid")
                if hum then
                    node.Humanoid = {
                        Health = hum.Health,
                        MaxHealth = hum.MaxHealth,
                        WalkSpeed = hum.WalkSpeed
                    }
                end
            end

            local prompt = inst:FindFirstChildOfClass("ProximityPrompt")
            if prompt then
                node.Prompt = {
                    Action = prompt.ActionText,
                    Object = prompt.ObjectText,
                    HoldDuration = prompt.HoldDuration,
                    MaxDistance = prompt.MaxActivationDistance
                }
            end

            local children = inst:GetChildren()
            if #children > 0 and depth < (maxD or 3) then
                node.Children = {}
                for idx, child in ipairs(children) do
                    if idx > 80 then
                        table.insert(node.Children, { Name = "...truncated " .. tostring(#children - 80) .. " children" })
                        break
                    end
                    table.insert(node.Children, inspectObject(child, depth + 1, maxD))
                end
            end

            return node
        end

        for _, child in ipairs(workspace:GetChildren()) do
            if child ~= LocalPlayer.Character and child.Name ~= "Camera" and child.Name ~= "Terrain" then
                wsTree[child.Name] = inspectObject(child, 0, 3)
            end
        end

        MasterDump.WorkspaceMap = wsTree
        print("[GENESIS DUMP] Workspace & Map Hierarchy extraction completed.")
    end)
end)

-- ================= STEP 5: PLAYER GUI & UI STATE =================
task.spawn(function()
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            local guiTree = {}
            for _, screen in ipairs(pg:GetChildren()) do
                if screen:IsA("ScreenGui") and not string.find(screen.Name, "Genesis") then
                    local elements = {}
                    for _, desc in ipairs(screen:GetDescendants()) do
                        if desc:IsA("GuiButton") or desc:IsA("TextBox") or desc:IsA("TextLabel") then
                            local elem = {
                                Name = desc.Name,
                                Class = desc.ClassName,
                                Path = desc:GetFullName()
                            }
                            if desc:IsA("TextLabel") and desc.Text and #desc.Text > 0 and #desc.Text < 80 then
                                elem.Text = desc.Text
                            end
                            table.insert(elements, elem)
                        end
                    end
                    guiTree[screen.Name] = {
                        Enabled = screen.Enabled,
                        ElementsCount = #elements,
                        Elements = elements
                    }
                end
            end
            MasterDump.PlayerGuiSummary = guiTree
        end
    end)
end)

-- ================= STEP 6: ASYNC EXPORT & MULTI-FILE SAVE =================
task.delay(4.5, function()
    notify("GENESIS DUMP", "Serializing & Saving JSON datasets...", 3)

    -- 1. Save Master Full Dump
    local okEncMaster, jsonMaster = pcall(function() return HttpService:JSONEncode(MasterDump) end)
    if okEncMaster and jsonMaster then
        if writefile then
            writefile("Genesis_DungeonQuest_MasterDump.json", jsonMaster)
        end
        local kb = math.floor(#jsonMaster / 1024)
        print(string.format("[GENESIS DUMP] SAVED Genesis_DungeonQuest_MasterDump.json (%d KB)", kb))
    end

    -- 2. Save Dedicated Modules Database
    if MasterDump.ModulesDatabase and next(MasterDump.ModulesDatabase) ~= nil then
        local okEncMod, jsonMod = pcall(function() return HttpService:JSONEncode(MasterDump.ModulesDatabase) end)
        if okEncMod and jsonMod and writefile then
            writefile("Genesis_DungeonQuest_Modules.json", jsonMod)
            print(string.format("[GENESIS DUMP] SAVED Genesis_DungeonQuest_Modules.json (%d KB)", math.floor(#jsonMod / 1024)))
        end
    end

    -- 3. Save Dedicated Remotes Network Hierarchy
    if MasterDump.RemotesHierarchy and next(MasterDump.RemotesHierarchy) ~= nil then
        local okEncRem, jsonRem = pcall(function() return HttpService:JSONEncode(MasterDump.RemotesHierarchy) end)
        if okEncRem and jsonRem and writefile then
            writefile("Genesis_DungeonQuest_Remotes.json", jsonRem)
            print(string.format("[GENESIS DUMP] SAVED Genesis_DungeonQuest_Remotes.json (%d KB)", math.floor(#jsonRem / 1024)))
        end
    end

    -- 4. Save Dedicated Workspace Map & Hitboxes
    if MasterDump.WorkspaceMap and next(MasterDump.WorkspaceMap) ~= nil then
        local okEncWs, jsonWs = pcall(function() return HttpService:JSONEncode(MasterDump.WorkspaceMap) end)
        if okEncWs and jsonWs and writefile then
            writefile("Genesis_DungeonQuest_Workspace.json", jsonWs)
            print(string.format("[GENESIS DUMP] SAVED Genesis_DungeonQuest_Workspace.json (%d KB)", math.floor(#jsonWs / 1024)))
        end
    end

    notify("EXTRACTION COMPLETE", "All JSON Dump files successfully saved to executor workspace!", 7)
    print("
=======================================================")
    print("[GENESIS DUMP COMPLETE] ALL GAME DATA SAVED SUCCESSFULLY!")
    print("Files created in your Delta workspace folder:")
    print(" 1. Genesis_DungeonQuest_MasterDump.json")
    print(" 2. Genesis_DungeonQuest_Modules.json")
    print(" 3. Genesis_DungeonQuest_Remotes.json")
    print(" 4. Genesis_DungeonQuest_Workspace.json")
    print("=======================================================
")
end)
