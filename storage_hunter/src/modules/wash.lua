local WashModule = {}
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")

local itemDB
pcall(function()
    itemDB = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Items"))
end)

function WashModule.init(Config, Utils)
    local function getWashPromptObj()
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                local name = string.lower(obj.Name)
                local action = string.lower(obj.ActionText)
                if string.find(name, "wash") or string.find(action, "wash") or string.find(name, "clean") or string.find(action, "clean") then
                    return obj
                end
            end
        end
        return nil
    end

    local function getWashStationCFrame()
        local prompt = getWashPromptObj()
        if prompt and prompt.Parent and prompt.Parent:IsA("BasePart") then
            return prompt.Parent.CFrame
        end
        return nil
    end

    local function clickUI(btn)
        if not btn then return end
        pcall(function()
            if type(firesignal) == "function" then
                pcall(function() firesignal(btn.MouseButton1Click) end)
                pcall(function() firesignal(btn.Activated) end)
            end
            
            local absPos = btn.AbsolutePosition
            local absSize = btn.AbsoluteSize
            if absSize.X > 0 and absSize.Y > 0 then
                local inset = GuiService:GetGuiInset()
                local x = absPos.X + (absSize.X / 2)
                local y = absPos.Y + (absSize.Y / 2) + inset.Y
                VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
                task.wait(0.02)
                VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
            end
        end)
    end

    local function clickDialogOption(targetStr)
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        if not pGui then return false end
        
        local clicked = false
        for _, obj in pairs(pGui:GetDescendants()) do
            if obj:IsA("TextButton") and obj.AbsoluteSize.X > 0 and obj.AbsoluteSize.Y > 0 then
                local textStr = string.lower(obj.Text)
                if textStr == "" or textStr == " " then
                    for _, child in pairs(obj:GetDescendants()) do
                        if child:IsA("TextLabel") or child:IsA("TextBox") then
                            if child.Text and child.Text ~= "" then
                                textStr = textStr .. " " .. string.lower(child.Text)
                            end
                        end
                    end
                end
                
                if string.find(textStr, targetStr) then
                    clickUI(obj)
                    clicked = true
                end
            end
        end
        return clicked
    end

    local function processWashUI()
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        local uiC = pGui and pGui:FindFirstChild("UIControllerGui")
        if not uiC then return false end

        local washShop = uiC:FindFirstChild("WashShopPanel")
        if not washShop or not washShop.Visible then return false end

        local isBusy = false
        if washShop:FindFirstChild("SlotsContainer") then
            for i = 1, 3 do
                local slot = washShop.SlotsContainer:FindFirstChild("Slot" .. tostring(i))
                if slot and slot:FindFirstChild("Content") then
                    local content = slot.Content
                    local colBtn = content:FindFirstChild("CollectBtn")
                    local clmBtn = content:FindFirstChild("ClaimBtn")
                    local spdBtn = content:FindFirstChild("SpeedUpBtn")
                    local timer = content:FindFirstChild("TimerText")
                    local itemName = content:FindFirstChild("ItemName")
                    
                    local hasTimer = timer and timer.Visible and timer.Text ~= "" and timer.Text ~= "0s" and timer.Text ~= "0" and timer.Text ~= "00:00" and timer.Text ~= "0:00"
                    
                    if (spdBtn and spdBtn.Visible) or hasTimer then 
                        isBusy = true 
                        if hasTimer and timer.Text ~= "00:00" then
                            local iName = (itemName and itemName.Text) or "Item"
                            warn("WASH_TIMER_" .. iName .. "_" .. timer.Text)
                        end
                    end
                    
                    if colBtn and colBtn.Visible then 
                        isBusy = true 
                        clickUI(colBtn) 
                    end
                    
                    task.wait(0.05)
                    
                    if clmBtn and clmBtn.Visible then 
                        isBusy = true 
                        clickUI(clmBtn) 
                    end
                end
            end
        end

        local washReveal = uiC:FindFirstChild("WashReveal")
        if washReveal and washReveal.Visible and washReveal:FindFirstChild("Content") then
            local clmBtn = washReveal.Content:FindFirstChild("ClaimBtn")
            if clmBtn and clmBtn.Visible then 
                isBusy = true
                clickUI(clmBtn) 
            end
        end
        
        return isBusy
    end

    local function forceClaimRemotes(washFolder, guid)
        local rems = {washFolder:FindFirstChild("CollectWash"), washFolder:FindFirstChild("ClaimWashedItem")}
        for _, rem in ipairs(rems) do
            if rem then
                pcall(function()
                    for slot = 1, 3 do
                        if rem:IsA("RemoteFunction") then 
                            pcall(function() rem:InvokeServer(slot, guid) end) 
                            pcall(function() rem:InvokeServer(guid, slot) end) 
                            pcall(function() rem:InvokeServer(slot) end) 
                            pcall(function() rem:InvokeServer(guid) end)
                        elseif rem:IsA("RemoteEvent") then 
                            pcall(function() rem:FireServer(slot, guid) end) 
                            pcall(function() rem:FireServer(guid, slot) end) 
                            pcall(function() rem:FireServer(slot) end) 
                            pcall(function() rem:FireServer(guid) end) 
                        end
                    end
                end)
            end
        end
    end

    function WashModule.washInventoryItems()
        warn("WASH_EXECUTE_START")
        local events = ReplicatedStorage:FindFirstChild("Events")
        local wash = events and events:FindFirstChild("Wash")
        if not wash then return end
        
        local getWashable = wash:FindFirstChild("GetWashableItems")
        local startWash = wash:FindFirstChild("StartWash")
        
        if getWashable and startWash then
            local success, data = pcall(function()
                if getWashable:IsA("RemoteFunction") then return getWashable:InvokeServer()
                elseif getWashable:IsA("RemoteEvent") then getWashable:FireServer() end
            end)
            
            if success and type(data) == "table" and data.items then
                local itemsToWash = {}
                for _, item in pairs(data.items) do
                    if item.guid then table.insert(itemsToWash, item.guid) end
                end
                
                if #itemsToWash > 0 then
                    warn("WASH_ITEMS_FOUND_" .. tostring(#itemsToWash))
                    local originalCFrame = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.CFrame
                    local washCFrame = getWashStationCFrame()
                    
                    if washCFrame then Utils.warpTo(washCFrame); task.wait(0.8) end
                    
                    local guid = itemsToWash[1]
                    
                    pcall(function()
                        if startWash:IsA("RemoteFunction") then
                            for slot = 1, 3 do startWash:InvokeServer(slot, guid); startWash:InvokeServer(guid, slot) end
                            startWash:InvokeServer(guid)
                        elseif startWash:IsA("RemoteEvent") then
                            for slot = 1, 3 do startWash:FireServer(slot, guid); startWash:FireServer(guid, slot) end
                            startWash:FireServer(guid)
                        end
                    end)
                    
                    task.wait(1) 
                    
                    local prompt = getWashPromptObj()
                    if prompt then
                        pcall(function() fireproximityprompt(prompt) end)
                        task.wait(0.5)
                        clickDialogOption("clean an item")
                        task.wait(0.5)
                    end
                    
                    local maxWait = 20000 
                    local currentWait = 0
                    local emptyChecks = 0
                    
                    while currentWait < maxWait do
                        task.wait(0.5)
                        
                        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
                        local uiC = pGui and pGui:FindFirstChild("UIControllerGui")
                        local washShop = uiC and uiC:FindFirstChild("WashShopPanel")
                        
                        if washShop and not washShop.Visible then
                            if prompt then pcall(function() fireproximityprompt(prompt) end) end
                            task.wait(0.5)
                            clickDialogOption("clean an item")
                            task.wait(0.5)
                            
                            pGui = LocalPlayer:FindFirstChild("PlayerGui")
                            uiC = pGui and pGui:FindFirstChild("UIControllerGui")
                            washShop = uiC and uiC:FindFirstChild("WashShopPanel")
                        end
                        
                        if washShop and washShop.Visible then
                            local stillWashing = processWashUI()
                            if not stillWashing then 
                                emptyChecks = emptyChecks + 1
                            else
                                emptyChecks = 0
                            end
                        end
                        
                        forceClaimRemotes(wash, guid)
                        
                        if emptyChecks >= 4 then break end
                        currentWait = currentWait + 1
                    end
                    
                    warn("WASH_SWEEP_START")
                    for finalSweep = 1, 3 do
                        task.wait(0.5)
                        processWashUI()
                        forceClaimRemotes(wash, guid)
                    end
                    
                    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
                    local uiC = pGui and pGui:FindFirstChild("UIControllerGui")
                    local washShop = uiC and uiC:FindFirstChild("WashShopPanel")
                    if washShop and washShop.Visible then
                        local closeBtn = washShop:FindFirstChild("HeaderBar") and washShop.HeaderBar:FindFirstChild("CloseButton")
                        if closeBtn then clickUI(closeBtn) end
                        task.wait(0.3)
                    end
                    
                    clickDialogOption("maybe later")
                    
                    if originalCFrame then task.wait(0.5); Utils.warpTo(originalCFrame) end
                    warn("WASH_FINISHED")
                end
            end
        end
    end

    function WashModule.warpToUnpack()
        local uz = Workspace:FindFirstChild("UnpackZone")
        if not uz then return end
        
        local pad = uz:FindFirstChild("Pad")
        if not pad then return end

        local targetCFrame = pad.CFrame + Vector3.new(0, 4, 0)
        local char = LocalPlayer.Character
        local humanoid = char and char:FindFirstChild("Humanoid")

        if humanoid and humanoid.SeatPart then
            local vehicle = humanoid.SeatPart:FindFirstAncestorWhichIsA("Model")
            if vehicle then 
                vehicle:PivotTo(targetCFrame) 
            else 
                humanoid.SeatPart.CFrame = targetCFrame 
            end
        else
            Utils.warpTo(pad.CFrame)
        end
        
        task.wait(1)
        
        local vehiclesEvents = ReplicatedStorage:FindFirstChild("Events")
        if not vehiclesEvents then return end
        
        local vehicleFolder = vehiclesEvents:FindFirstChild("Vehicles")
        if not vehicleFolder then return end
        
        local getOwnedVehicles = vehicleFolder:FindFirstChild("GetOwnedVehicles")
        local getVehicleItems = vehicleFolder:FindFirstChild("GetVehicleItems")
        local transferItems = vehicleFolder:FindFirstChild("TransferVehicleItemsToInventory")
        
        if getOwnedVehicles and getVehicleItems and transferItems then
            local successV, resultV = pcall(function() return getOwnedVehicles:InvokeServer() end)
            if successV and type(resultV) == "table" and resultV.equippedGuid then
                local vehicleId = tostring(resultV.equippedGuid)
                local successI, resultI = pcall(function() return getVehicleItems:InvokeServer(vehicleId) end)
                
                if successI and type(resultI) == "table" then
                    local itemsToUnload = {}
                    for itemGuid, _ in pairs(resultI) do 
                        table.insert(itemsToUnload, itemGuid) 
                    end
                    
                    if #itemsToUnload > 0 then
                        transferItems:FireServer(itemsToUnload)
                        task.wait(0.5)
                        
                        if humanoid and humanoid.Sit then 
                            humanoid.Sit = false 
                        end
                    end
                end
            end
        end
    end

    task.spawn(function()
        while task.wait(5) do
            if Config.AutoWash then
                WashModule.washInventoryItems()
            end
        end
    end)
end

return WashModule