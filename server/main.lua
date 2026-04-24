local VehicleNitrous = {}
-- Tracks which server-source owns which plate (for targeted events)
local PlateOwner = {}
-- Flame sync debounce: last broadcast time per netId
local _lastFlameSync = {}

RegisterNetEvent('nitrous:server:LoadNitrous', function(Plate)
    local src = source
    VehicleNitrous[Plate] = { hasnitro = true, level = 100 }
    PlateOwner[Plate] = src
    TriggerClientEvent('nitrous:client:LoadNitrous', -1, Plate)
end)

RegisterNetEvent('nitrous:server:RequestNosData', function()
    local src = source
    TriggerClientEvent('nitrous:client:GetNosLoadedVehs', src, VehicleNitrous)
end)

RegisterNetEvent('nitrous:server:SyncFlames', function(netId)
    local src = source
    local now = GetGameTimer()
    if (now - (_lastFlameSync[netId] or 0)) < 150 then return end
    _lastFlameSync[netId] = now
    TriggerClientEvent('nitrous:client:SyncFlames', -1, netId, src)
end)

RegisterNetEvent('nitrous:server:UnloadNitrous', function(Plate)
    VehicleNitrous[Plate] = nil
    PlateOwner[Plate] = nil
    _lastFlameSync[Plate] = nil
    TriggerClientEvent('nitrous:client:UnloadNitrous', -1, Plate)
end)

RegisterNetEvent('nitrous:server:UpdateNitroLevel', function(Plate, level)
    local src = source
    if VehicleNitrous[Plate] then
        VehicleNitrous[Plate].level = level
        -- Only the owner needs their own live level; others see it via SyncFlames
        TriggerClientEvent('nitrous:client:UpdateNitroLevel', src, Plate, level)
    end
end)

RegisterNetEvent('nitrous:server:StopSync', function(plate)
    _lastFlameSync[plate] = nil
    TriggerClientEvent('nitrous:client:StopSync', -1, plate)
end)

-- Cleanup NOS state when a player disconnects so ghost state can't linger
AddEventHandler('playerDropped', function()
    local src = source
    for plate, owner in pairs(PlateOwner) do
        if owner == src then
            VehicleNitrous[plate] = nil
            PlateOwner[plate] = nil
            _lastFlameSync[plate] = nil
            TriggerClientEvent('nitrous:client:StopSync', -1, plate)
            TriggerClientEvent('nitrous:client:UnloadNitrous', -1, plate)
        end
    end
end)