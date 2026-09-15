
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ucMod = ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitController
local uc = require(ucMod)
local isagoGuid = 'abece858-d655-4b73-9b20-6bb38fa607f1'

print('=============================================')
print('[DIAG V34] DIRECT UNIT HOLD VIA CONTROLLER')
print('=============================================')

print('Calling uc:Equip(isagoGuid)...')
local ok, res = pcall(function()
    return uc:Equip(isagoGuid)
end)
print('uc:Equip result -> ok:', ok, 'res:', res)

local eq = nil
pcall(function() eq = uc:EquippedUnit() end)
print('uc:EquippedUnit() after equip:', eq)

local lp = game:GetService('Players').LocalPlayer
local pg = lp:FindFirstChild('PlayerGui')
local putBack = pg and pg:FindFirstChild('Root') and pg.Root:FindFirstChild('HUD') and pg.Root.HUD:FindFirstChild('PutBack')
print('PutBack Visible after uc:Equip:', putBack and putBack.Visible)
