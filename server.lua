-- Admin check for the debug bar (Config.Debug): the bar and the debug prints are only shown to admins.
local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateCallback('county-vehdamage:isAdmin', function(source, cb)
    cb(QBCore.Functions.HasPermission(source, 'admin') or QBCore.Functions.HasPermission(source, 'god'))
end)

-- Emergency repair flag: a vehicle whose engine was patched with the repair kit no longer stalls at random.
-- Written on the server so every client sees it (state bag); cleared again after a full repair.
RegisterNetEvent('county-vehdamage:server:setKit', function(netId, value)
    local src = source
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(vehicle)) > 15.0 then return end

    Entity(vehicle).state:set('countyKit', value and true or nil, true)
end)
