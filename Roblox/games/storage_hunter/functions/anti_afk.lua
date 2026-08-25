local AntiAFK = {}
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local idledConnection = nil

function AntiAFK.Init(Config)
    if idledConnection then
        idledConnection:Disconnect()
        idledConnection = nil
    end

    idledConnection = LocalPlayer.Idled:Connect(function()
        if Config.Get("AntiAFK", true) then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end
    end)
end

function AntiAFK.Destroy()
    if idledConnection then
        idledConnection:Disconnect()
        idledConnection = nil
    end
end

return AntiAFK
