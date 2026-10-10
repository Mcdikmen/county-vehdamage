-- Limp mode flag: set by the emergency repair kit, cleared when the engine is healthy again.
-- Written on the server so every client sees it (state bag), whoever drives the vehicle later.
RegisterNetEvent('county-vehdamage:server:setLimp', function(netId, value)
    local src = source
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > 15.0 then return end

    Entity(vehicle).state:set('countyLimp', value and true or nil, true)
end)
