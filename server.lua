-- Admin check for the debug bar (Config.Debug): the bar and the debug prints are only shown to admins.
local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateCallback('county-vehdamage:isAdmin', function(source, cb)
    cb(QBCore.Functions.HasPermission(source, 'admin') or QBCore.Functions.HasPermission(source, 'god'))
end)

-- /motorcan [0-100]: admin command to set the engine health of the vehicle you drive in percent (100 = full repair).
-- Without a number it shows the current value. Handy for testing the damage tiers.
QBCore.Commands.Add('motorcan', 'Aracın motor canını yüzde olarak ayarla (100 = tam tamir, boş = göster)', {
    { name = 'yuzde', help = '0-100 arası motor canı yüzdesi (boş bırak = mevcut değeri göster)' },
}, false, function(source, args)
    local pct = args[1] and tonumber(args[1]) or nil
    TriggerClientEvent('county-vehdamage:client:setHealth', source, pct)
end, 'admin')
