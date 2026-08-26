local Reconnect = {}

local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local isReconnecting = false
local initialized = false

local LOADER_URL = "https://raw.githubusercontent.com/vxmpie/Genesis/main/Roblox/loader.lua"

local function sendDashboardHeartbeat(status, extra)
    pcall(function()
        local req = (syn and syn.request) or (http and http.request) or http_request or request
        if not req then return end
        
        local payload = {
            status = status or "playing",
            place_id = game.PlaceId,
            job_id = game.JobId,
            player = LocalPlayer and LocalPlayer.Name or "Player",
            timestamp = os.time(),
            extra = extra or {}
        }
        
        local body = HttpService:JSONEncode(payload)
        
        task.spawn(function()
            pcall(function()
                req({
                    Url = "http://10.0.2.2:7700/api/bot/heartbeat",
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = body,
                    Timeout = 3
                })
            end)
        end)
    end)
end

local function clickNativeReconnectButton()
    local success, clicked = pcall(function()
        local promptGui = CoreGui:FindFirstChild("RobloxPromptGui")
        if not promptGui then return false end
        
        local promptOverlay = promptGui:FindFirstChild("promptOverlay")
        if not promptOverlay then return false end
        
        local function searchAndClick(parent)
            for _, child in ipairs(parent:GetChildren()) do
                if child:IsA("GuiButton") or child:IsA("TextButton") or child:IsA("ImageButton") then
                    local text = (child:IsA("TextButton") and child.Text) or child.Name
                    if string.find(text:lower(), "reconnect") or string.find(text:lower(), "retry") then
                        warn("[GENESIS AUTO-RECONNECT] Found Native Reconnect Button: " .. child:GetFullName())
                        
                        pcall(function()
                            if firesignal then
                                firesignal(child.Activated)
                                firesignal(child.MouseButton1Click)
                            end
                        end)
                        
                        pcall(function()
                            if VirtualInputManager then
                                local pos = child.AbsolutePosition + (child.AbsoluteSize / 2)
                                VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 1)
                                task.wait(0.05)
                                VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 1)
                            end
                        end)
                        
                        return true
                    end
                end
                if searchAndClick(child) then
                    return true
                end
            end
            return false
        end
        
        return searchAndClick(promptOverlay)
    end)
    return success and clicked
end

local function queueScriptOnTeleport()
    pcall(function()
        local code = 'loadstring(game:HttpGet("' .. LOADER_URL .. '?t=' .. tostring(os.time()) .. '"))()'
        if queue_on_teleport then
            queue_on_teleport(code)
        elseif syn and syn.queue_on_teleport then
            syn.queue_on_teleport(code)
        elseif fluxus and fluxus.queue_on_teleport then
            fluxus.queue_on_teleport(code)
        end
    end)
end

local function executeRejoin(reason)
    if isReconnecting then return end
    isReconnecting = true
    warn("[GENESIS AUTO-RECONNECT] Triggered: " .. tostring(reason or "Connection lost"))

    sendDashboardHeartbeat("disconnected", { reason = tostring(reason) })

    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "GENESIS AUTO-RECONNECT",
            Text = "Disconnect detected! Auto-rejoining...",
            Duration = 5
        })
    end)

    queueScriptOnTeleport()

    task.spawn(function()
        for i = 1, 5 do
            local clicked = clickNativeReconnectButton()
            if clicked then
                warn("[GENESIS AUTO-RECONNECT] Successfully clicked native modal Reconnect button.")
                break
            end
            task.wait(0.5)
        end
    end)

    task.spawn(function()
        task.wait(2)
        local placeId = game.PlaceId
        local jobId = game.JobId

        for attempt = 1, 6 do
            warn("[GENESIS AUTO-RECONNECT] Teleport attempt " .. attempt .. "/6...")
            local success = pcall(function()
                if jobId and #jobId > 0 and #Players:GetPlayers() <= 1 then
                    TeleportService:TeleportToPlaceInstance(placeId, jobId, LocalPlayer)
                else
                    TeleportService:Teleport(placeId, LocalPlayer)
                end
            end)

            if success then
                break
            end
            task.wait(attempt * 2)
        end
    end)
end

function Reconnect.Start()
    if initialized then return end
    initialized = true

    print("[GENESIS] Universal Smart Auto-Reconnect & Anti-AFK Active.")

    pcall(function()
        LocalPlayer.Idled:Connect(function()
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                task.wait(0.2)
                VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            end)
        end)
    end)

    pcall(function()
        GuiService.ErrorMessageChanged:Connect(function(errorMessage)
            if errorMessage and #errorMessage > 0 then
                pcall(function()
                    GuiService:ClearError()
                end)
                executeRejoin("GuiService Error: " .. tostring(errorMessage))
            end
        end)
    end)

    task.spawn(function()
        pcall(function()
            local promptGui = CoreGui:WaitForChild("RobloxPromptGui", 10)
            if promptGui then
                local promptOverlay = promptGui:WaitForChild("promptOverlay", 10)
                if promptOverlay then
                    promptOverlay.ChildAdded:Connect(function(child)
                        if child.Name == "ErrorPrompt" or string.find(child.Name:lower(), "prompt") or string.find(child.Name:lower(), "error") then
                            task.wait(0.2)
                            executeRejoin("Roblox ErrorPrompt Detected: " .. child.Name)
                        end
                    end)
                end
            end
        end)
    end)

    task.spawn(function()
        sendDashboardHeartbeat("playing")
        
        while task.wait(15) do
            if not isReconnecting then
                sendDashboardHeartbeat("playing")
            end
        end
    end)
end

return Reconnect
