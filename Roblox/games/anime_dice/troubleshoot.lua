local ReplicatedStorage = game:GetService('ReplicatedStorage')
local dcMod = ReplicatedStorage.Framework.Features.Data.DataController
local dc = require(dcMod)
local isagoGuid = 'abece858-d655-4b73-9b20-6bb38fa607f1'

print('--- CHECKING ISAGO IN DC.___X.Inventory ---')
local xInv = dc.___X and dc.___X.Inventory
local xIsago = xInv and xInv[isagoGuid]
print('xIsago type:', type(xIsago))
if type(xIsago) == 'table' then
    for k, v in pairs(xIsago) do
        print('  xIsago.' .. tostring(k) .. ' = ' .. tostring(v) .. ' (' .. type(v) .. ')')
    end
end

print('--- CHECKING ISAGO IN DC.___C.Inventory ---')
local cInvNode = dc.___C and dc.___C.Inventory
local cInv = cInvNode and cInvNode.___C
local cIsago = cInv and cInv[isagoGuid]
print('cIsago type:', type(cIsago))
if type(cIsago) == 'table' then
    for k, v in pairs(cIsago) do
        print('  cIsago.' .. tostring(k) .. ' = ' .. tostring(v) .. ' (' .. type(v) .. ')')
    end
    if cIsago.___C then
        for k, v in pairs(cIsago.___C) do
            print('    cIsago.___C.' .. tostring(k) .. ' = ' .. tostring(v) .. ' (' .. type(v) .. ')')
        end
    end
    if cIsago.___X then
        for k, v in pairs(cIsago.___X) do
            print('    cIsago.___X.' .. tostring(k) .. ' = ' .. tostring(v) .. ' (' .. type(v) .. ')')
        end
    end
end
