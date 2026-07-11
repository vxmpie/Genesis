local FarmModule = {}
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

function FarmModule.init(Config, Utils, WashModule)
    function FarmModule.startAuctionAndCollect(zoneName)
        local debris = Workspace:FindFirstChild("_Debris")
        local garages = debris and debris:FindFirstChild("Garages")
        local carryables = Workspace:FindFirstChild("_Carryables")
        if not garages or not carryables then return end

        if Config.AutoUnload then
            local currentVehicle = Utils.getCurrentVehicle()
            if currentVehicle then
                local cargoWeight = currentVehicle:GetAttribute("CargoWeight") or 0
                local cargoLimit = currentVehicle:GetAttribute("CargoWeightLimit") or math.huge
                if cargoWeight >= (cargoLimit * 0.95) then
                    WashModule.warpToUnpack()
                    task.wait(1)
                end
            end
        end

        local targetPrompt, targetGarage = nil, nil
        local nw = Utils.getNetWorth()

        for _, g in pairs(garages:GetChildren()) do
            local sq = g:FindFirstChild("EntrySquare")
            if sq and sq:FindFirstChild("PromptPart") and sq.PromptPart:FindFirstChild("EnterAuction") then
                local prompt = sq.PromptPart.EnterAuction
                if zoneName == "Back Alley" then
                    if g.Name:match("Camo") and nw >= 10000 then targetPrompt = prompt; targetGarage = g; break end
                    if g.Name:match("Shop Front") then targetPrompt = prompt; targetGarage = g; end
                elseif zoneName == "Farmyard" then
                    if g.Name:match("Barn") and nw >= 50000 then targetPrompt = prompt; targetGarage = g; break end
                    if g.Name:match("Stable") then targetPrompt = prompt; targetGarage = g; end
                elseif zoneName == "Shipyard" then
                    if g.Name:match("Large") and nw >= 400000 then targetPrompt = prompt; targetGarage = g; break end
                    if g.Name:match("Small") then targetPrompt = prompt; targetGarage = g; end
                elseif zoneName == "Junk Yard" then
                    if g.Name:match("Scrap") or g.Name == "Garage" then targetPrompt = prompt; targetGarage = g; break end
                end
            end
        end

        if targetPrompt and targetGarage then
            local savedGarageCFrame = targetPrompt.Parent.CFrame
            Utils.warpTo(savedGarageCFrame)
            task.wait(0.5)
            
            if type(fireproximityprompt) == "function" then 
                pcall(function() fireproximityprompt(targetPrompt) end) 
            end
            
            local pGui = LocalPlayer:FindFirstChild("PlayerGui")
            local uiController = pGui and pGui:FindFirstChild("UIControllerGui")
            local auctionUI = uiController and uiController:FindFirstChild("AuctionBiddingContainer")
            
            local uiWait = 0
            while auctionUI and not auctionUI.Visible and uiWait < 8 and Config.IsFarming do
                task.wait(0.5)
                uiWait = uiWait + 0.5
            end
            
            if auctionUI and auctionUI.Visible then
                local noneVisibleCount = 0
                while Config.IsFarming do
                    if auctionUI.Visible then 
                        noneVisibleCount = 0 
                    else 
                        noneVisibleCount = noneVisibleCount + 1 
                    end
                    if noneVisibleCount >= 2 then break end
                    task.wait(0.5)
                end
                task.wait(0.5)
            else
                task.wait(0.5)
                return
            end
            
            local garagePos = targetPrompt.Parent.Position
            local emptyChecks = 0
            local hasCollected = false
            local ghostBlacklist = {}
            
            while Config.IsFarming do
                warn("DIAG_FARM_COL_LOOP_E_" .. tostring(emptyChecks) .. "_C_" .. tostring(hasCollected))
                
                if Config.AutoUnload then
                    local currentVehicle = Utils.getCurrentVehicle()
                    if currentVehicle then
                        local cargoWeight = currentVehicle:GetAttribute("CargoWeight") or 0
                        local cargoLimit = currentVehicle:GetAttribute("CargoWeightLimit") or math.huge
                        
                        if cargoWeight >= (cargoLimit * 0.95) then
                            WashModule.warpToUnpack()
                            task.wait(1)
                            if currentVehicle then 
                                currentVehicle:PivotTo(savedGarageCFrame) 
                            else 
                                Utils.warpTo(savedGarageCFrame) 
                            end
                            task.wait(0.5)
                        end
                    end
                end

                local itemsToCollect = {}
                local totalSeen = 0
                for _, item in pairs(carryables:GetChildren()) do
                    local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
                    local basePart = item:FindFirstChildWhichIsA("BasePart", true)
                    if prompt and prompt.Enabled and basePart then
                        local dist = (basePart.Position - garagePos).Magnitude
                        if dist <= 60 then
                            totalSeen = totalSeen + 1
                            if not ghostBlacklist[item] or ghostBlacklist[item] < 5 then
                                local weight = 0
                                local weightValue = item:FindFirstChild("Weight") or item:FindFirstChild("Mass")
                                if weightValue and (weightValue:IsA("NumberValue") or weightValue:IsA("IntValue")) then 
                                    weight = weightValue.Value
                                else 
                                    weight = tonumber(item:GetAttribute("Weight")) or tonumber(item:GetAttribute("Mass")) or 0 
                                end
                                table.insert(itemsToCollect, { itemObj = item, prompt = prompt, basePart = basePart, weight = weight })
                            end
                        end
                    end
                end
                
                warn("DIAG_FARM_ITEMS_SEEN_" .. tostring(totalSeen) .. "_VALID_" .. tostring(#itemsToCollect))
                
                if #itemsToCollect > 0 then
                    hasCollected = true
                    emptyChecks = 0
                    table.sort(itemsToCollect, function(a, b) return a.weight < b.weight end)
                    for _, data in ipairs(itemsToCollect) do
                        if not Config.IsFarming then break end
                        
                        ghostBlacklist[data.itemObj] = (ghostBlacklist[data.itemObj] or 0) + 1
                        
                        Utils.warpTo(data.basePart.CFrame)
                        task.wait(0.05) 
                        if type(fireproximityprompt) == "function" then 
                            pcall(function() fireproximityprompt(data.prompt) end) 
                        end
                        task.wait(0.05) 
                    end
                else
                    emptyChecks = emptyChecks + 1
                    if hasCollected and emptyChecks >= 3 then
                        warn("DIAG_FARM_EXIT_CLEAN")
                        break
                    elseif not hasCollected and emptyChecks >= 100 then
                        warn("DIAG_FARM_EXIT_TIMEOUT")
                        break
                    end
                    task.wait(0.1) 
                end
            end
        end
    end
end

return FarmModule