local Optimization = {}
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

Optimization.Status = {
    PropsRemoved = 0,
    TreesRemoved = 0,
    NPCsRemoved = 0
}

function Optimization.ApplyFPSCap(fps)
    pcall(function()
        if setfpscap then
            setfpscap(fps or 360)
        end
    end)
end

function Optimization.CleanWorldProps(Config)
    pcall(function()
        if Config.Get("DeleteTrees", false) then
            local map = Workspace:FindFirstChild("Map")
            local trees = map and (map:FindFirstChild("Trees") or map:FindFirstChild("Foliage"))
            if trees then
                Optimization.Status.TreesRemoved = #trees:GetChildren()
                trees:Destroy()
            end
        end

        if Config.Get("DeleteNPCs", false) then
            local map = Workspace:FindFirstChild("Map")
            local npcs = map and map:FindFirstChild("NPCs")
            if npcs then
                Optimization.Status.NPCsRemoved = #npcs:GetChildren()
                npcs:Destroy()
            end
        end

        if Config.Get("DeleteContainers", false) then
            local auctions = Workspace:FindFirstChild("Auctions") or Workspace:FindFirstChild("Garages")
            if auctions then
                for _, container in ipairs(auctions:GetChildren()) do
                    if container:IsA("Model") and not container:FindFirstChild("Item") then
                        container:Destroy()
                        Optimization.Status.PropsRemoved = Optimization.Status.PropsRemoved + 1
                    end
                end
            end
        end
    end)
end

function Optimization.Init(Config)
    LocalPlayer.Idled:Connect(function()
        if Config.Get("AntiAFK", true) then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)

    task.spawn(function()
        while task.wait(5) do
            if not Config.Get("StopAllAutomation", false) then
                Optimization.CleanWorldProps(Config)
                if Config.Get("EnableFPSCap", false) then
                    Optimization.ApplyFPSCap(Config.Get("FPSCapValue", 360))
                end
            end
        end
    end)
end

return Optimization
