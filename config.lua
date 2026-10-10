Config = {}

-- Engine health is the GTA native 0-1000 value stored on the vehicle (it is saved with the vehicle props,
-- so garage store/spawn keeps it). Crashes remove engine health, tiers below describe what the engine does.

-- A crash counts when the body health drops by at least this much in one sample (ignores scrapes and rain).
Config.MinBodyLoss = 8.0

-- Engine health removed per point of body health lost in a crash.
-- 8 body loss = -48, 20 = -120, 50 = -300, 100 = -600 engine health
Config.EngineDamagePerBodyLoss = 6.0

-- Tiers (engine health below the value). torque = power multiplier.
-- The engine is dead below DeadBelow.
Config.Tiers = {
    light = { below = 700.0, torque = 0.92, msg = 'Motordan garip sesler geliyor.' },
    heavy = { below = 500.0, torque = 0.70, msg = 'Motor ciddi hasar aldı, araç güçten düştü.' },
}
Config.DeadBelow = 300.0
Config.DeadMsg = 'Motor çöktü! Tamirci ya da acil onarım kiti gerekiyor.'
Config.DeadStartMsg = 'Motor bozuk, çalışmıyor.'

-- Emergency repair (repair_kit): lifts a dead engine to this health so the car can limp (heavy tier).
-- Never lowers a healthier engine and does not touch the body. Full repair is a mechanic job (full_repair_kit).
Config.EmergencyRepairHealth = 450.0

-- Vehicle classes ignored: cycles, boats, helicopters, planes, trains
Config.SkipClasses = { [13] = true, [14] = true, [15] = true, [16] = true, [21] = true }

-- High speed crashes burst one random tyre (needs a real crash, see MinBodyLoss).
-- Speed is the peak of the last few samples before the impact, in km/h.
Config.TyreBurstSpeedKmh = 150.0
Config.TyreBurstChance = 100 -- % chance that one tyre bursts on such a crash
Config.TyreBurstMsg = 'Çarpmanın şiddetiyle lastik patladı!'

-- Limp mode: after an emergency repair (repair_kit) the vehicle is capped at this speed (km/h) until the engine is
-- healthy again (full repair by a mechanic). Crash damage alone does NOT cap the top speed, it only costs power.
Config.LimpMaxKmh = 70.0
