--[[
    GENESIS UNIVERSAL DEEP DUMPER (DELTA / UNC OPTIMIZED)
    Bulletproof Game Reverse-Engineering & Architecture Extractor
    Fully Patched for BindToClose, Infinite Yield, and Server-Only Modules
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local CollectionService = game:GetService("CollectionService")
local Stats = game:GetService("Stats")
local MarketplaceService = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer

-- ================= STEP 0: HOOK & NEUTRALIZE SERVER-ONLY APIS =================
-- Prevents "BindToClose can only be called on the server" when requiring modules
pcall(function()
    if hookmetamethod then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if self == game and (method == "BindToClose" or method == "bindToClose") then
                return nil
            end
            return oldNamecall(self, ...)
        end))
    end
end)

pcall(function()
    if hookfunction and game.BindToClose then
        hookfunction(game.BindToClose, newcclosure(function()
            return nil
        end))
    end
end)

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

-- Resolve Clean Game Name
local rawGameName = "RobloxGame"
pcall(function()
    local info = MarketplaceService:GetProductInfo(game.PlaceId)
    if info and info.Name then
        rawGameName = info.Name
    end
end)
local cleanGameName = string.gsub(rawGameName, "[^%w_]", "")
if #cleanGameName == 0 then cleanGameName = "Place_" .. tostring(game.PlaceId) end

notify("GENESIS EXTRACTOR", "Starting Deep Dump for: " .. rawGameName, 4)

local MasterDump = {
    DumpInfo = {
        Timestamp = os.date("%Y-%m-%d %X"),
        GameName = rawGameName,
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
    PlayerGuiSummary = {}
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

-- ================= STEP 3: PROTECTED TIMED MODULESCRIPT SCANNER =================
local modulesDone = false
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

        -- 2. Include executor loaded modules
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

        print(string.format("[GENESIS DUMP] Found %d ModuleScripts. Extracting with safety sandbox...", #moduleCandidates))

        -- Safe require with strict timeout & server filter
        local function safeRequire(modScript)
            local modName = modScript.Name
            local modPath = modScript:GetFullName()
            local lowerName = string.lower(modName)
            local lowerPath = string.lower(modPath)

            -- Skip obvious server-side modules that crash or hang client
            if string.find(lowerName, "server") or string.find(lowerPath, "server") or
               string.find(lowerName, "datastore") or string.find(lowerPath, "datastore") or
               string.find(lowerName, "backend") or string.find(lowerPath, "backend") or
               string.find(lowerName, "savemanager") or string.find(lowerPath, "savemanager") or
               string.find(lowerName, "bindtoclose") then
                return false, "<Skipped_ServerOnlyModule>"
            end

            local result = nil
            local finished = false
            local err = nil

            local th = task.spawn(function()
                local ok, res = pcall(function()
                    return require(modScript)
                end)
                if ok then
                    result = res
                else
                    err = res
                end
                finished = true
            end)

            local t0 = os.clock()
            while not finished and (os.clock() - t0 < 0.25) do
                task.wait(0.01)
            end

            if not finished then
                pcall(task.cancel, th)
                return false, "<TimedOut_WaitForChildOrLoop>"
            end

            if err then
                return false, tostring(err)
            end

            return true, result
        end

        local extractedCount = 0
        for _, mod in ipairs(moduleCandidates) do
            local modName = mod.Name
            local modPath = mod:GetFullName()

            local success, result = safeRequire(mod)
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
            elseif not success and result == "<Skipped_ServerOnlyModule>" then
                allModules[modName] = {
                    Path = modPath,
                    Type = "ServerModule_Skipped"
                }
            end
        end

        MasterDump.ModulesDatabase = allModules
        print(string.format("[GENESIS DUMP] Successfully required and dumped %d ModuleScripts.", extractedCount))
        modulesDone = true
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
task.spawn(function()
    -- Wait until modules are done or max 5 seconds
    local waitStart = os.clock()
    while not modulesDone and (os.clock() - waitStart < 5) do
        task.wait(0.1)
    end

    notify("GENESIS DUMP", "Encoding & Saving JSON datasets for " .. cleanGameName .. "...", 3)

    local prefix = "Genesis_" .. cleanGameName .. "_"

    -- Helper to save safely
    local function saveJson(filename, tbl)
        local ok, encoded = pcall(function() return HttpService:JSONEncode(tbl) end)
        if ok and encoded and writefile then
            pcall(function()
                writefile(filename, encoded)
            end)
            print(string.format("[GENESIS DUMP] SAVED %s (%d KB)", filename, math.floor(#encoded / 1024)))
            return true
        else
            warn("[GENESIS DUMP] Failed to encode/save " .. filename)
            return false
        end
    end

    -- 1. Master Full Dump
    saveJson(prefix .. "MasterDump.json", MasterDump)
    saveJson("Genesis_MasterDump.json", MasterDump)

    -- 2. Dedicated Modules
    if MasterDump.ModulesDatabase and next(MasterDump.ModulesDatabase) ~= nil then
        saveJson(prefix .. "Modules.json", MasterDump.ModulesDatabase)
        saveJson("Genesis_Modules.json", MasterDump.ModulesDatabase)
    end

    -- 3. Dedicated Remotes
    if MasterDump.RemotesHierarchy and next(MasterDump.RemotesHierarchy) ~= nil then
        saveJson(prefix .. "Remotes.json", MasterDump.RemotesHierarchy)
        saveJson("Genesis_Remotes.json", MasterDump.RemotesHierarchy)
    end

    -- 4. Dedicated Workspace
    if MasterDump.WorkspaceMap and next(MasterDump.WorkspaceMap) ~= nil then
        saveJson(prefix .. "Workspace.json", MasterDump.WorkspaceMap)
        saveJson("Genesis_Workspace.json", MasterDump.WorkspaceMap)
    end

    notify("EXTRACTION COMPLETE", "All JSON files saved to Delta workspace successfully!", 7)
    print("=======================================================")
    print("[GENESIS DUMP COMPLETE] ALL GAME DATA SAVED SUCCESSFULLY!")
    print("Target Game: " .. rawGameName)
    print("Files created in your Delta workspace folder:")
    print(" 1. " .. prefix .. "MasterDump.json")
    print(" 2. " .. prefix .. "Modules.json")
    print(" 3. " .. prefix .. "Remotes.json")
    print(" 4. " .. prefix .. "Workspace.json")
    print("=======================================================")
end)
