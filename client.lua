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

-- Share of the vehicle's top speed that is taken away at this engine health: SpeedLossMinPct right when the engine
-- starts making noises (light tier) up to SpeedLossMaxPct at the dead threshold. Healthy engines lose nothing.
local function speedLossFraction(health)
    local from, to = Config.Tiers.light.below, Config.DeadBelow
    if health >= from then return 0.0 end
    local t = (from - health) / (from - to)
    if t > 1.0 then t = 1.0 end
    return (Config.SpeedLossMinPct + (Config.SpeedLossMaxPct - Config.SpeedLossMinPct) * t) / 100.0
end

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

-- Emergency repair: only unlocks a dead engine (lifts it to EmergencyRepairHealth) and puts burst tyres back.
-- The speed loss stays until a full repair (engine health back above the light tier). Used by jg-mechanic's repair_kit.
exports('EmergencyRepair', function(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    if GetVehicleEngineHealth(vehicle) < Config.EmergencyRepairHealth then
        SetVehicleEngineHealth(vehicle, Config.EmergencyRepairHealth + 0.0)
    end
    -- wheel indexes 0-5, 45/47 are the extra axles of big vehicles
    for _, index in ipairs({ 0, 1, 2, 3, 4, 5, 45, 47 }) do
        if IsVehicleTyreBurst(vehicle, index, false) or IsVehicleTyreBurst(vehicle, index, true) then
            SetVehicleTyreFixed(vehicle, index)
        end
    end
    SetVehicleUndriveable(vehicle, false)
    return true
end)

CreateThread(function()
    local lastVeh, lastBody, lastTier = 0, 0.0, 0
    local undriveableSet = false
    local capVeh = 0        -- vehicle that currently has our top-speed cap
    local baseMax = 0.0     -- top speed (m/s) of the current vehicle before our cap
    local lastLoss = -1.0   -- last applied speed loss fraction
    local lastStartMsg = 0
    local speedHist = { 0.0, 0.0, 0.0 } -- km/h of the last three samples

    local function clearCap(vehicle)
        if vehicle ~= 0 and DoesEntityExist(vehicle) then SetVehicleMaxSpeed(vehicle, 0.0) end
        capVeh = 0
        lastLoss = -1.0
    end

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
                baseMax = 0.0
                lastLoss = -1.0
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

            -- top speed loss (10-30%), kept for as long as the engine is below the light tier, i.e. until a full repair
            local frac = speedLossFraction(health)
            if frac > 0.0 then
                if baseMax <= 0.0 then
                    baseMax = GetVehicleEstimatedMaxSpeed(veh)
                    if baseMax <= 0.0 then baseMax = GetVehicleModelEstimatedMaxSpeed(GetEntityModel(veh)) end
                end
                if baseMax > 0.0 and math.abs(frac - lastLoss) > 0.005 then
                    SetVehicleMaxSpeed(veh, baseMax * (1.0 - frac))
                    capVeh = veh
                    lastLoss = frac
                end
            elseif capVeh == veh then
                clearCap(veh)
            end

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
                if tier == 2 then
                    wait = 0
                    SetVehicleEngineTorqueMultiplier(veh, Config.Tiers.heavy.torque)
                elseif tier == 1 then
                    wait = 0
                    SetVehicleEngineTorqueMultiplier(veh, Config.Tiers.light.torque)
                end
            end
        else
            if capVeh ~= 0 then clearCap(capVeh) end
            lastVeh = 0
        end

        Wait(wait)
    end
end)
