Config = {}

-- Engine health is the GTA native 0-1000 value stored on the vehicle (it is saved with the vehicle props,
-- so garage store/spawn keeps it). Crashes remove engine health, tiers below describe what the engine does.

-- A crash counts when the body health drops by at least this much in one sample (ignores scrapes and rain).
Config.MinBodyLoss = 8.0

-- Engine health removed per point of body health lost in a crash.
-- 8 body loss = -48, 20 = -120, 50 = -300, 100 = -600 engine health (of 1000)
Config.EngineDamagePerBodyLoss = 6.0

-- Tiers (engine health 0-1000 below the value). torque = power multiplier. light = engine below 50% (strange noises,
-- speed loss starts), heavy = below 25%. The engine only dies at 100% damage (health 0), see DeadBelow.
Config.Tiers = {
    light = { below = 500.0, torque = 0.92, msg = 'Motordan garip sesler geliyor, araç yavaşladı.' },
    heavy = { below = 250.0, torque = 0.70, msg = 'Motor ciddi hasar aldı, araç güçten düştü ve iyice yavaşladı.' },
}
Config.DeadBelow = 1.0 -- engine health 0 = 100% damaged = the engine dies
Config.DeadMsg = 'Motor çöktü! Tamirci ya da acil onarım kiti gerekiyor.'
Config.DeadStartMsg = 'Motor bozuk, çalışmıyor.'

-- Emergency repair (repair_kit): lifts a dead engine to this health so the car can limp (heavy tier, ~24% speed loss).
-- Never lowers a healthier engine and does not touch the body. Full repair is a mechanic job (full_repair_kit).
Config.EmergencyRepairHealth = 150.0

-- Vehicle classes ignored: cycles, boats, helicopters, planes, trains
Config.SkipClasses = { [13] = true, [14] = true, [15] = true, [16] = true, [21] = true }

-- High speed crashes burst one random tyre (needs a real crash, see MinBodyLoss).
-- Speed is the peak of the last few samples before the impact, in km/h.
Config.TyreBurstSpeedKmh = 150.0
Config.TyreBurstChance = 100 -- % chance that one tyre bursts on such a crash
Config.TyreBurstMsg = 'Çarpmanın şiddetiyle lastik patladı!'

-- Top speed loss: starts the moment the engine makes noises (light tier) and grows with the damage, from
-- SpeedLossMinPct at that point up to SpeedLossMaxPct when the engine is about to die. It stays until a FULL repair
-- (engine health back above the light tier): the emergency kit only unlocks a dead engine and does not give the speed back.
-- Stored in the engine health itself, so it survives garage store/spawn.
Config.SpeedLossMinPct = 10.0
Config.SpeedLossMaxPct = 30.0
