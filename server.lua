-- Admin check for the debug bar (Config.Debug): the bar and the debug prints are only shown to admins.
local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateCallback('county-vehdamage:isAdmin', function(source, cb)
    cb(QBCore.Functions.HasPermission(source, 'admin') or QBCore.Functions.HasPermission(source, 'god'))
end)
