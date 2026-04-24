-- SPiceZ Nitrous System
local VehicleNitrous = {}
local Fxs = {}
local purgeflowrate = 0.1
local nitroflowrate = 1.0
local NitrousActivated = false
local PurgeMode = false
local NitroMode = true

local function Notify(msg, type)
    exports["spz-lib"]:Notify(msg, type or "info")
end

local function trim(value)
	if not value then return nil end
    return (string.gsub(value, '^%s*(.-)%s*$', '%1'))
end

RegisterNetEvent('SPZ:Client:OnPlayerLoaded', function()
    -- Request NOS data for vehicles if needed (server-side sync)
    TriggerServerEvent('nitrous:server:RequestNosData')
end)

RegisterNetEvent('nitrous:client:GetNosLoadedVehs', function(vehs)
    VehicleNitrous = vehs
end)

-- Command to install/refill NOS (No item required as per user request)
RegisterCommand('nos', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped)

    if veh ~= 0 then
        if GetPedInVehicleSeat(veh, -1) == ped then
            if not NitrousActivated then
                -- Optional: Check for Turbo if you want to keep that restriction
                -- if IsToggleModOn(veh, 18) then
                    Notify("Installing Nitrous System...", "info")
                    -- Simple wait for installation
                    Citizen.Wait(2000) 
                    
                    local Plate = trim(GetVehicleNumberPlateText(veh))
                    TriggerServerEvent('nitrous:server:LoadNitrous', Plate)
                    Notify("Nitrous System Installed/Refilled", "success")
                -- else
                --     Notify("Vehicle needs a Turbo to use NOS!", "error")
                -- end
            else
                Notify("NOS is already active!", "error")
            end
        else
            Notify("You must be the driver!", "error")
        end
    else
        Notify("You are not in a vehicle!", "error")
    end
end)

-- Event to install NOS (Simplified)
RegisterNetEvent('spz-nos:client:LoadNitrous', function()
    ExecuteCommand('nos')
end)

local nosupdated = false
local PurgeMode = false
local NitroMode = true
local ActiveKey = false

-- Key Mapping Functions
RegisterCommand('+activateNos', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped)
    if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
        local Plate = trim(GetVehicleNumberPlateText(veh))
        if VehicleNitrous[Plate] and VehicleNitrous[Plate].hasnitro then
            ActiveKey = true
        end
    end
end, false)

RegisterCommand('-activateNos', function()
    ActiveKey = false
    NitrousActivated = false
    local veh = GetVehiclePedIsIn(PlayerPedId())
    if veh ~= 0 then
        SetVehicleBoostActive(veh, 0)
        SetVehicleEnginePowerMultiplier(veh, 1.0)
        SetVehicleEngineTorqueMultiplier(veh, 1.0)
        SetVehicleNitroPurgeEnabled(veh, false)
        for index,_ in pairs(Fxs) do
            StopParticleFxLooped(Fxs[index], 1)
            TriggerServerEvent('nitrous:server:StopSync', trim(GetVehicleNumberPlateText(veh)))
            Fxs[index] = nil
        end
    end
end, false)

-- Toggle Mode Command kept but might be redundant now with contextual switching
RegisterCommand('toggleNosMode', function()
    -- Optional: allow manual toggle if desired, but user wants contextual now
end, false)

RegisterCommand('cycleNosFlow', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped)
    if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
        local Plate = trim(GetVehicleNumberPlateText(veh))
        if VehicleNitrous[Plate] and VehicleNitrous[Plate].hasnitro then
            -- Contextual cycle based on current auto-selected mode
            if IsControlPressed(0, 71) then -- If accelerating, cycle nitro
                nitroflowrate = nitroflowrate + 1.0
                if nitroflowrate > 3.0 then nitroflowrate = 1.0 end
                Notify('Nitro Flowrate: ' .. nitroflowrate)
            else -- If not accelerating, cycle purge
                purgeflowrate = purgeflowrate + 0.1
                if purgeflowrate > 1.05 then purgeflowrate = 0.1 end
                Notify('Purge Spray Flowrate: ' .. string.format("%.1f", purgeflowrate))
            end
        end
    end
end, false)

RegisterKeyMapping('+activateNos', 'Use Nitrous (X)', 'keyboard', 'X')
RegisterKeyMapping('cycleNosFlow', 'Cycle Flow Rate', 'keyboard', 'B')

-- Main Processing Thread
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local CurrentVehicle = GetVehiclePedIsIn(ped)
        if CurrentVehicle ~= 0 then
            local Plate = trim(GetVehicleNumberPlateText(CurrentVehicle))
            if VehicleNitrous[Plate] ~= nil and VehicleNitrous[Plate].hasnitro then
                -- Contextual Mode Selection (Always update for UI)
                if IsControlPressed(0, 71) then -- W (Accelerate)
                    NitroMode = true
                    PurgeMode = false
                else
                    NitroMode = false
                    PurgeMode = true
                end

                if ActiveKey then
                    if NitroMode then
                        NitrousActivated = true
                        SetEntityMaxSpeed(CurrentVehicle, 999.0)
                    else
                        NitrousActivated = false
                        SetVehicleBoostActive(CurrentVehicle, 0)
                        SetVehicleEnginePowerMultiplier(CurrentVehicle, 1.0)
                        SetVehicleEngineTorqueMultiplier(CurrentVehicle, 1.0)
                        -- Stop flames
                        for index,_ in pairs(Fxs) do
                            StopParticleFxLooped(Fxs[index], 1)
                            TriggerServerEvent('nitrous:server:StopSync', Plate)
                            Fxs[index] = nil
                        end
                    end

                    -- Execution
                    if NitroMode and NitrousActivated then
                        if VehicleNitrous[Plate].level > 0 then
                            local boostMult = 1.0 + nitroflowrate
                            SetVehicleEnginePowerMultiplier(CurrentVehicle, boostMult)
                            SetVehicleEngineTorqueMultiplier(CurrentVehicle, boostMult)
                            
                            local consumption = 0.3 * nitroflowrate
                            VehicleNitrous[Plate].level = VehicleNitrous[Plate].level - consumption
                            
                            if VehicleNitrous[Plate].level <= 0 then
                                VehicleNitrous[Plate].level = 0
                                ExecuteCommand('-activateNos')
                                TriggerServerEvent('nitrous:server:UnloadNitrous', Plate)
                            else
                                TriggerServerEvent('nitrous:server:UpdateNitroLevel', Plate, VehicleNitrous[Plate].level)
                            end
                        end
                    elseif PurgeMode then
                        if VehicleNitrous[Plate].level > 0 then
                            SetVehicleBoostActive(CurrentVehicle, 1)
                            SetVehicleNitroPurgeEnabled(CurrentVehicle, true)
                            
                            local consumption = 1.5 * (purgeflowrate * 10)
                            VehicleNitrous[Plate].level = VehicleNitrous[Plate].level - (consumption / 10)
                            
                            if VehicleNitrous[Plate].level <= 0 then
                                VehicleNitrous[Plate].level = 0
                                ExecuteCommand('-activateNos')
                                TriggerServerEvent('nitrous:server:UnloadNitrous', Plate)
                            else
                                TriggerServerEvent('nitrous:server:UpdateNitroLevel', Plate, VehicleNitrous[Plate].level)
                            end
                        else
                            SetVehicleNitroPurgeEnabled(CurrentVehicle, false)
                        end
                    end
                end
                nosupdated = false
            else
                if not nosupdated then
                    nosupdated = true
                end
            end
        else
            Wait(1000)
        end
        Wait(100)
    end
end)

----------PURGE--------------

local vehicles = {}
local particles = {}

function IsVehicleNitroPurgeEnabled(vehicle)
    return vehicles[vehicle] == true
end

function SetVehicleNitroPurgeEnabled(vehicle, enabled)
    if IsVehicleNitroPurgeEnabled(vehicle) == enabled then
      return
    end
  
    if enabled then
      local boneleft = GetEntityBoneIndexByName(vehicle, 'wheel_lf')
      local posleft = GetWorldPositionOfEntityBone(vehicle, boneleft)
      local offleft = GetOffsetFromEntityGivenWorldCoords(vehicle, posleft.x, posleft.y, posleft.z)
      local boneright = GetEntityBoneIndexByName(vehicle, 'wheel_rf')
      local posright = GetWorldPositionOfEntityBone(vehicle, boneright)
      local offright = GetOffsetFromEntityGivenWorldCoords(vehicle, posright.x, posright.y, posright.z)
      local ptfxs = {}
  
      for i=0,1 do
        local leftPurge = CreateVehiclePurgeSpray(vehicle, offleft.x - 0.1, offleft.y + 0.5, offleft.z + 0.05, 30.0, -50.0, 0.5, purgeflowrate)
        local rightPurge = CreateVehiclePurgeSpray(vehicle, offright.x + 0.1, offright.y + 0.5, offright.z + 0.05, 30.0, 50.0, 0.5, purgeflowrate)
  
        table.insert(ptfxs, leftPurge)
        table.insert(ptfxs, rightPurge)
      end
  
      vehicles[vehicle] = true
      particles[vehicle] = ptfxs
    else
      if particles[vehicle] and #particles[vehicle] > 0 then
        for _, particleId in ipairs(particles[vehicle]) do
          StopParticleFxLooped(particleId)
        end
      end
  
      vehicles[vehicle] = nil
      particles[vehicle] = nil
    end
end

function CreateVehiclePurgeSpray(vehicle, xOffset, yOffset, zOffset, xRot, yRot, zRot, scale)
    UseParticleFxAssetNextCall('core')
    return StartParticleFxLoopedOnEntity('ent_sht_steam', vehicle, xOffset, yOffset, zOffset, xRot, yRot, zRot, scale, false, false, false)
  end

p_flame_location = {
	"exhaust",
	"exhaust_2",
	"exhaust_3",
	"exhaust_4",
	"exhaust_5",
	"exhaust_6",
	"exhaust_7",
	"exhaust_8",
	"exhaust_9",
	"exhaust_10",
	"exhaust_11",
	"exhaust_12",
	"exhaust_13",
	"exhaust_14",
	"exhaust_15",
	"exhaust_16",
}

ParticleDict = "veh_xs_vehicle_mods"
ParticleFx = "veh_nitrous"
ParticleSize = 1.3

-- Preload PTFX once at startup so the flame loop never blocks
CreateThread(function()
    RequestNamedPtfxAsset(ParticleDict)
    while not HasNamedPtfxAssetLoaded(ParticleDict) do
        Wait(100)
    end
end)

local _lastFlameSync = 0

CreateThread(function()
    while true do
        if not NitrousActivated then
            Wait(300)
        else
            local veh = GetVehiclePedIsIn(PlayerPedId())
            if veh ~= 0 then
                local now = GetGameTimer()
                if now - _lastFlameSync >= 100 then
                    _lastFlameSync = now
                    TriggerServerEvent('nitrous:server:SyncFlames', VehToNet(veh))
                end
                for _, bones in pairs(p_flame_location) do
                    if GetEntityBoneIndexByName(veh, bones) ~= -1 then
                        if Fxs[bones] == nil then
                            UseParticleFxAssetNextCall(ParticleDict)
                            Fxs[bones] = StartParticleFxLoopedOnEntityBone(ParticleFx, veh, 0.0, -0.02, 0.0, 0.0, 0.0, 0.0, GetEntityBoneIndexByName(veh, bones), ParticleSize, 0.0, 0.0, 0.0)
                        end
                    end
                end
            end
            Wait(75)
        end
    end
end)

local NOSPFX = {}

RegisterNetEvent('nitrous:client:SyncFlames', function(netid, nosid)
    local veh = NetToVeh(netid)
    if veh == 0 then return end
    if not HasNamedPtfxAssetLoaded(ParticleDict) then return end

    local myid = GetPlayerServerId(PlayerId())
    if myid == nosid then return end

    local plate = trim(GetVehicleNumberPlateText(veh))
    if NOSPFX[plate] == nil then NOSPFX[plate] = {} end

    for _, bones in pairs(p_flame_location) do
        if NOSPFX[plate][bones] == nil then NOSPFX[plate][bones] = {} end
        if GetEntityBoneIndexByName(veh, bones) ~= -1 then
            if NOSPFX[plate][bones].pfx == nil then
                UseParticleFxAssetNextCall(ParticleDict)
                NOSPFX[plate][bones].pfx = StartParticleFxLoopedOnEntityBone(ParticleFx, veh, 0.0, -0.05, 0.0, 0.0, 0.0, 0.0, GetEntityBoneIndexByName(veh, bones), ParticleSize, 0.0, 0.0, 0.0)
            end
        end
    end
end)

RegisterNetEvent('nitrous:client:StopSync', function(plate)
    if NOSPFX[plate] then
        for k, v in pairs(NOSPFX[plate]) do
            StopParticleFxLooped(v.pfx, 1)
            NOSPFX[plate][k].pfx = nil
        end
    end
end)

RegisterNetEvent('nitrous:client:UpdateNitroLevel', function(Plate, level)
    VehicleNitrous[Plate].level = level
end)

RegisterNetEvent('nitrous:client:LoadNitrous', function(Plate)
    VehicleNitrous[Plate] = {
        hasnitro = true,
        level = 100,
    }
    local CurrentVehicle = GetVehiclePedIsIn(PlayerPedId())
    local CPlate = trim(GetVehicleNumberPlateText(CurrentVehicle))
    if CPlate == Plate then
        TriggerEvent('hud:client:UpdateNitrous', VehicleNitrous[Plate].hasnitro,  VehicleNitrous[Plate].level, false)
    end
end)

RegisterNetEvent('nitrous:client:UnloadNitrous', function(Plate)
    VehicleNitrous[Plate] = nil
    local CurrentVehicle = GetVehiclePedIsIn(PlayerPedId())
    local CPlate = trim(GetVehicleNumberPlateText(CurrentVehicle))
    if CPlate == Plate then
        NitrousActivated = false
        TriggerEvent('hud:client:UpdateNitrous', false, nil, false)
    end
end)

-- Exports for speedometer
exports('GetNosData', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped)
    if veh ~= 0 then
        local Plate = trim(GetVehicleNumberPlateText(veh))
        if VehicleNitrous[Plate] then
            return {
                hasNitro = true,
                level = VehicleNitrous[Plate].level,
                purgeLevel = VehicleNitrous[Plate].level, -- Shared for now
                mode = NitroMode and "nitro" or "purge",
                flowRate = NitroMode and nitroflowrate or purgeflowrate
            }
        end
    end
    return nil
end)
