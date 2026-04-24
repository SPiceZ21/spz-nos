local VehicleNitrous = {}

RegisterNetEvent('nitrous:server:LoadNitrous', function(Plate)
    VehicleNitrous[Plate] = {
        hasnitro = true,
        level = 100,
    }
    TriggerClientEvent('nitrous:client:LoadNitrous', -1, Plate)
end)

RegisterNetEvent('nitrous:server:RequestNosData', function()
    local src = source
    TriggerClientEvent('nitrous:client:GetNosLoadedVehs', src, VehicleNitrous)
end)

RegisterNetEvent('nitrous:server:SyncFlames', function(netId)
    TriggerClientEvent('nitrous:client:SyncFlames', -1, netId, source)
end)

RegisterNetEvent('nitrous:server:UnloadNitrous', function(Plate)
    VehicleNitrous[Plate] = nil
    TriggerClientEvent('nitrous:client:UnloadNitrous', -1, Plate)
end)

RegisterNetEvent('nitrous:server:UpdateNitroLevel', function(Plate, level)
    if VehicleNitrous[Plate] then
        VehicleNitrous[Plate].level = level
        TriggerClientEvent('nitrous:client:UpdateNitroLevel', -1, Plate, level)
    end
end)

RegisterNetEvent('nitrous:server:StopSync', function(plate)
    TriggerClientEvent('nitrous:client:StopSync', -1, plate)
end)