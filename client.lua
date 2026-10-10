local function notify(msg, kind)
    TriggerEvent('QBCore:Notify', msg, kind or 'error')
end

local function tierOf(health)
    if health < Config.DeadBelow then return 3 end
    if health < Config.Tiers.heavy.below then return 2 end
    if health < Config.Tiers.light.below then return 1 end
    return 0
end

local tierMsg = {
    [1] = Config.Tiers.light.msg,
    [2] = Config.Tiers.heavy.msg,
    [3] = Config.DeadMsg,
}

-- Burst one random tyre (wheel indexes: 0/1 front, 4/5 rear, bikes 0 and 4). Tyres that cannot burst (bulletproof) are skipped.
local function burstRandomTyre(vehicle)
    if not GetVehicleTyresCanBurst(vehicle) then return end
    local wheels = IsThisModelABike(GetEntityModel(vehicle)) and { 0, 4 } or { 0, 1, 4, 5 }
    local index = wheels[math.random(#wheels)]
    if not IsVehicleTyreBurst(vehicle, index, false) then
        SetVehicleTyreBurst(vehicle, index, false, 1000.0)
        notify(Config.TyreBurstMsg)
    end
end

-- Emergency repair: lifts a dead engine so the car can limp. Used by jg-mechanic's repair_kit.
exports('EmergencyRepair', function(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    if GetVehicleEngineHealth(vehicle) < Config.EmergencyRepairHealth then
        SetVehicleEngineHealth(vehicle, Config.EmergencyRepairHealth + 0.0)
    end
    SetVehicleUndriveable(vehicle, false)
    return true
end)

CreateThread(function()
    local lastVeh, lastBody, lastTier = 0, 0.0, 0
    local undriveableSet = false
    local capVeh = 0 -- vehicle that currently has our top-speed cap
    local lastStartMsg = 0
    local speedHist = { 0.0, 0.0, 0.0 } -- km/h of the last three samples

    while true do
        local wait = 250
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and not Config.SkipClasses[GetVehicleClass(veh)] then
            wait = 50

            if veh ~= lastVeh then
                lastVeh = veh
                lastBody = GetVehicleBodyHealth(veh)
                lastTier = tierOf(GetVehicleEngineHealth(veh))
                undriveableSet = false
            end

            -- crash detection: body health only goes down through damage, repairs raise it
            local body = GetVehicleBodyHealth(veh)
            local loss = lastBody - body
            local kmh = GetEntitySpeed(veh) * 3.6
            local peak = math.max(kmh, speedHist[1], speedHist[2], speedHist[3])
            speedHist[3], speedHist[2], speedHist[1] = speedHist[2], speedHist[1], kmh
            if loss >= Config.MinBodyLoss then
                if peak > Config.TyreBurstSpeedKmh and math.random(100) <= Config.TyreBurstChance then
                    burstRandomTyre(veh)
                end
                local health = GetVehicleEngineHealth(veh) - loss * Config.EngineDamagePerBodyLoss
                SetVehicleEngineHealth(veh, health + 0.0)
            end
            lastBody = body

            -- tier effects
            local health = GetVehicleEngineHealth(veh)
            local tier = tierOf(health)

            if tier > lastTier then
                notify(tierMsg[tier])
            end
            lastTier = tier

            if tier == 3 then
                wait = 0
                SetVehicleEngineOn(veh, false, true, true)
                if not undriveableSet then
                    SetVehicleUndriveable(veh, true)
                    undriveableSet = true
                end
                if IsControlJustPressed(0, 71) and GetGameTimer() - lastStartMsg > 8000 then
                    lastStartMsg = GetGameTimer()
                    notify(Config.DeadStartMsg)
                end
            else
                if undriveableSet then
                    SetVehicleUndriveable(veh, false)
                    undriveableSet = false
                end
                local cap = (tier == 2 and Config.Tiers.heavy.maxKmh) or (tier == 1 and Config.Tiers.light.maxKmh) or nil
                if cap then
                    SetVehicleMaxSpeed(veh, cap / 3.6)
                    capVeh = veh
                elseif capVeh == veh then
                    SetVehicleMaxSpeed(veh, 0.0)
                    capVeh = 0
                end
                if tier == 2 then
                    wait = 0
                    SetVehicleEngineTorqueMultiplier(veh, Config.Tiers.heavy.torque)
                elseif tier == 1 then
                    wait = 0
                    SetVehicleEngineTorqueMultiplier(veh, Config.Tiers.light.torque)
                end
            end
        else
            if capVeh ~= 0 then
                if DoesEntityExist(capVeh) then SetVehicleMaxSpeed(capVeh, 0.0) end
                capVeh = 0
            end
            lastVeh = 0
        end

        Wait(wait)
    end
end)
