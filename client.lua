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
    local changed = false

    -- lifts the engine to EmergencyRepairHealth (25%); it does not stack, a healthier engine is left alone
    if GetVehicleEngineHealth(vehicle) < Config.EmergencyRepairHealth then
        SetVehicleEngineHealth(vehicle, Config.EmergencyRepairHealth + 0.0)
        changed = true
    end

    -- wheel indexes 0-5, 45/47 are the extra axles of big vehicles
    for _, index in ipairs({ 0, 1, 2, 3, 4, 5, 45, 47 }) do
        if IsVehicleTyreBurst(vehicle, index, false) or IsVehicleTyreBurst(vehicle, index, true) then
            SetVehicleTyreFixed(vehicle, index)
            changed = true
        end
    end

    if not changed then return false end -- nothing to patch, the kit is not used up

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
    local nextStallRoll, stallUntil = 0, 0

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
                SetVehicleEngineCanDegrade(veh, false) -- GTA slowly drains a low engine on its own; only crashes should change the health
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
                if Config.TyreBurstEnabled and peak > Config.TyreBurstSpeedKmh and math.random(100) <= Config.TyreBurstChance then
                    burstRandomTyre(veh)
                end
                local before = GetVehicleEngineHealth(veh)
                local health = before - loss * Config.EngineDamagePerBodyLoss
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
                SetVehicleUndriveable(veh, true) -- every frame, GTA resets it when the engine is touched
                undriveableSet = true
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

                -- random stalls in the last stretch before the engine dies (Config.Stall); the driver can restart it
                local stall = Config.Stall
                if stall.enabled and health < stall.belowPct * 10.0 then
                    local now = GetGameTimer()
                    if now < stallUntil then
                        wait = 0
                        SetVehicleEngineOn(veh, false, true, true)
                    elseif now >= nextStallRoll then
                        nextStallRoll = now + stall.checkMs
                        if GetIsVehicleEngineRunning(veh) and math.random(100) <= stall.chancePct then
                            SetVehicleEngineOn(veh, false, true, true)
                            stallUntil = now + stall.restartDelayMs
                            notify(stall.msg)
                        end
                    end
                end
            end
        else
            if capVeh ~= 0 then clearCap(capVeh) end
            lastVeh = 0
        end

        Wait(wait)
    end
end)

-- /motorcan: set (or show) the engine health of the vehicle the player is in, in percent. 100 = full repair.
RegisterNetEvent('county-vehdamage:client:setHealth', function(pct)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then
        return notify('Önce bir araca bin.')
    end

    if pct == nil then
        return notify(('Motor canı: %%%.0f (hasar %%%.0f)'):format(GetVehicleEngineHealth(veh) / 10.0, 100.0 - GetVehicleEngineHealth(veh) / 10.0), 'primary')
    end

    pct = math.max(0.0, math.min(100.0, pct))
    if pct >= 100.0 then
        -- full repair, the same things the mechanic's full repair kit does
        SetVehicleUndriveable(veh, false)
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleBodyHealth(veh, 1000.0)
        SetVehiclePetrolTankHealth(veh, 1000.0)
        notify('Araç tam tamir edildi (%100).', 'success')
    else
        SetVehicleEngineHealth(veh, pct * 10.0)
        notify(('Motor canı %%%.0f olarak ayarlandı.'):format(pct), 'primary')
    end

    -- read the value back a second later: if GTA or another script changed it, say so
    local wanted = (pct >= 100.0) and 1000.0 or pct * 10.0
    Wait(1000)
    if DoesEntityExist(veh) then
        local now = GetVehicleEngineHealth(veh)
        if math.abs(now - wanted) > 30.0 then
            notify(('Dikkat: motor canı %%%.0f okundu, ayarlanan %%%.0f. Başka bir şey değiştirdi.'):format(now / 10.0, wanted / 10.0), 'error')
        end
    end
end)
