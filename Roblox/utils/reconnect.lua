local Reconnect = {}

local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local isReconnecting = false
local initialized = false

local LOADER_URL = "https://raw.githubusercontent.com/vxmpie/Genesis/main/Roblox/loader.lua"

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

    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "GENESIS AUTO-RECONNECT",
            Text = "Connection lost! Auto-rejoining in 3s...",
            Duration = 5
        })
    end)

    queueScriptOnTeleport()

    task.spawn(function()
        task.wait(2)
        local placeId = game.PlaceId
        local jobId = game.JobId

        for attempt = 1, 10 do
            warn("[GENESIS AUTO-RECONNECT] Rejoin attempt " .. attempt .. "/10...")
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

    print("[GENESIS] Universal Auto-Reconnect & Anti-AFK Active.")

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
                        if child.Name == "ErrorPrompt" or string.find(child.Name, "Prompt") then
                            task.wait(0.5)
                            executeRejoin("Roblox ErrorPrompt Detected: " .. child.Name)
                        end
                    end)
                end
            end
        end)
    end)
end

return Reconnect
