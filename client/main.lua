-- Variables

local QBCore = exports['qb-core']:GetCoreObject()
local HasVehicleKey = false
local IsRobbing = false
local IsHotwiring = false
local AlertSend = false
local lockpicked = false
local lockpickedPlate = nil
local usingAdvanced

-- Functions

local function loadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Wait(0)
    end
end

local function HasVehicleKey(plate)
	QBCore.Functions.TriggerCallback('vehiclekeys:server:CheckHasKey', function(result)
		if result then
			HasVehicleKey = true
		else
			HasVehicleKey = false
		end
	end, plate)
	return HasVehicleKey
end

local function LockVehicle()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local veh = QBCore.Functions.GetClosestVehicle(pos)
    local plate = QBCore.Functions.GetPlate(veh)
    local vehpos = GetEntityCoords(veh)
    if IsPedInAnyVehicle(ped) then
        veh = GetVehiclePedIsIn(ped)
    end
    if veh ~= nil and #(pos - vehpos) < 7.5 then
        QBCore.Functions.TriggerCallback('vehiclekeys:server:CheckHasKey', function(result)
            if result then
                local vehLockStatus = GetVehicleDoorLockStatus(veh)
                loadAnimDict("anim@mp_player_intmenu@key_fob@")
                TaskPlayAnim(ped, 'anim@mp_player_intmenu@key_fob@', 'fob_click', 3.0, 3.0, -1, 49, 0, false, false,
                    false)

                if vehLockStatus == 1 then
                    Wait(750)
                    ClearPedTasks(ped)
                    TriggerServerEvent("InteractSound_SV:PlayWithinDistance", 5, "lock", 0.3)
                    SetVehicleDoorsLocked(veh, 2)
                    if (GetVehicleDoorLockStatus(veh) == 2) then
                        SetVehicleLights(veh, 2)
                        Wait(250)
                        SetVehicleLights(veh, 1)
                        Wait(200)
                        SetVehicleLights(veh, 0)
                        QBCore.Functions.Notify("Vehicle locked!")
                    else
                        QBCore.Functions.Notify("Something went wrong with the locking system!")
                    end
                else
                    Wait(750)
                    ClearPedTasks(ped)
                    TriggerServerEvent("InteractSound_SV:PlayWithinDistance", 5, "unlock", 0.3)
                    SetVehicleDoorsLocked(veh, 1)
                    if (GetVehicleDoorLockStatus(veh) == 1) then
                        SetVehicleLights(veh, 2)
                        Wait(250)
                        SetVehicleLights(veh, 1)
                        Wait(200)
                        SetVehicleLights(veh, 0)
                        QBCore.Functions.Notify("Vehicle unlocked!")
                    else
                        QBCore.Functions.Notify("Something went wrong with the locking system!")
                    end
                end
            else
                QBCore.Functions.Notify('You don\'t have the keys of the vehicle..', 'error')
            end
        end, plate)
    end
end

local function GetNearbyPed()
    local retval = nil
    local PlayerPeds = {}
    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        PlayerPeds[#PlayerPeds+1] = ped
    end
    local player = PlayerPedId()
    local coords = GetEntityCoords(player)
    local closestPed, closestDistance = QBCore.Functions.GetClosestPed(coords, PlayerPeds)
    if not IsEntityDead(closestPed) and closestDistance < 30.0 then
        retval = closestPed
    end
    return retval
end

local function PoliceCall()
    if not AlertSend then
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local chance = Config.PoliceAlertChance
        if GetClockHours() >= 1 and GetClockHours() <= 6 then
            chance = Config.PoliceNightAlertChance
        end
        if math.random() <= chance then
            local closestPed = GetNearbyPed()
            if closestPed ~= nil then
                local msg = ""
                local s1, s2 = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
                local streetLabel = GetStreetNameFromHashKey(s1)
                local street2 = GetStreetNameFromHashKey(s2)
                if street2 ~= nil and street2 ~= "" then
                    streetLabel = streetLabel .. " " .. street2
                end
                local alertTitle = ""
                if IsPedInAnyVehicle(ped) then
                    local vehicle = GetVehiclePedIsIn(ped, false)
                    local netId = VehToNet(vehicle)
                    local modelName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)):lower()
                    if QBCore.Shared.Vehicles[modelName] ~= nil then
                        Name = QBCore.Shared.Vehicles[modelName]["brand"] .. ' ' .. QBCore.Shared.Vehicles[modelName]["name"]
                    else
                        Name = "Unknown"
                    end
                    local modelPlate = QBCore.Functions.GetPlate(vehicle)
                    local msg = "Vehicle theft attempt at " .. streetLabel .. ". Vehicle: " .. Name .. ", Licenseplate: " .. modelPlate
                    local alertTitle = "Vehicle theft attempt at"
                    local doors = GetVehicleModelNumberOfSeats(vehicle)
                    local class = GetVehicleClass(vehicle)
                    local vehicleColour1, vehicleColour2 = GetVehicleColours(vehicle)
                    data = {dispatchCode = 'autotheft', caller = 'en', coords = pos, netId = netId,
                	info = ('[%s] %s%s'):format(modelPlate, doors, class)}
                    --TriggerServerEvent('wf-alerts:svNotify', data)

                    local wanted = 1 local warrant = 1 local dispatch = 2
                    TriggerEvent("qb-cnr:client:policeAlert", pos, "Vehicle Theft", wanted, dispatch, warrant)
                    --TriggerServerEvent("setWantedLevel", 1)
                else
                    local vehicle = QBCore.Functions.GetClosestVehicle()
                    local modelName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)):lower()
                    local modelPlate = QBCore.Functions.GetPlate(vehicle)
                    if QBCore.Shared.Vehicles[modelName] ~= nil then
                        Name = QBCore.Shared.Vehicles[modelName]["brand"] .. ' ' .. QBCore.Shared.Vehicles[modelName]["name"]
                    else
                        Name = "Unknown"
                    end
                    local msg = "Vehicle theft attempt at " .. streetLabel .. ". Vehicle: " .. Name .. ", Licenseplate: " .. modelPlate
                    local alertTitle = "Vehicle theft attempt at"
                    local netId = PedToNet(ped)
                    local doors = GetVehicleModelNumberOfSeats(vehicle)
                    local class = GetVehicleClass(vehicle)
                    local vehicleColour1, vehicleColour2 = GetVehicleColours(vehicle)
                    data = {dispatchCode = 'autotheft', caller = 'en', coords = pos, netId = netId,
                	info = ('[%s] %s%s'):format(modelPlate, doors, class)}
                    TriggerServerEvent('wf-alerts:svNotify', data)
                    TriggerServerEvent("setWantedLevel", 1)
                end
            end
        end
        AlertSend = true
        SetTimeout(Config.AlertCooldown, function()
            AlertSend = false
        end)
    end
end

local function lockpickFinish(success)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local vehicle = QBCore.Functions.GetClosestVehicle(pos)
    local chance = math.random()
    StopAnimTask(PlayerPedId(), "missheistfbisetup1", "unlock_loop_janitor", 1.0)
    if success then
        TriggerServerEvent('hud:server:GainStress', math.random(1, 4))
        QBCore.Functions.Notify('Opened Door!', 'success')
        SetVehicleDoorsLocked(vehicle, 1)
        lockpicked = true
        lockpickedPlate = QBCore.Functions.GetPlate(vehicle)
    else
        PoliceCall()
        TriggerServerEvent('hud:server:GainStress', math.random(1, 4))
        QBCore.Functions.Notify('Someone Called The Police!', 'error')
    end
    if usingAdvanced then
        if chance <= Config.RemoveLockpickAdvanced then
            TriggerEvent('inventory:client:ItemBox', QBCore.Shared.Items["advancedlockpick"], "remove")
            TriggerServerEvent("QBCore:Server:RemoveItem", "advancedlockpick", 1)
        end
    else
        if chance <= Config.RemoveLockpickNormal then
            TriggerEvent('inventory:client:ItemBox', QBCore.Shared.Items["lockpick"], "remove")
            TriggerServerEvent("QBCore:Server:RemoveItem", "lockpick", 1)
        end
    end
end

local function LockpickDoor(isAdvanced)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local vehicle = QBCore.Functions.GetClosestVehicle(pos)
    if vehicle ~= nil and vehicle ~= 0 then
        local vehpos = GetEntityCoords(vehicle)
        if #(pos - vehpos) < 2.5 then
            local vehLockStatus = GetVehicleDoorLockStatus(vehicle)
            if (vehLockStatus > 0) then
                usingAdvanced = isAdvanced
                loadAnimDict('missheistfbisetup1')
                while not HasAnimDictLoaded('missheistfbisetup1') do
                    Wait(100)
                end
                TaskPlayAnim(PlayerPedId(), "missheistfbisetup1", "unlock_loop_janitor", 8.0, 1.0, -1, 1)
                
                TriggerEvent('qb-lockpick:client:openLockpick', lockpickFinish)
            end
        end
    end
end

local function Hotwire()
    if not HasVehicleKey then
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, true)
        IsHotwiring = true
        lockpickedPlate = nil
        local hotwireTime = math.random(2000, 4000)
        SetVehicleAlarm(vehicle, true)
        SetVehicleAlarmTimeLeft(vehicle, 100000)
        PoliceCall()
        RequestAnimDict("anim@amb@clubhouse@tutorial@bkr_tut_ig3@")

        while not HasAnimDictLoaded("anim@amb@clubhouse@tutorial@bkr_tut_ig3@") do 
            Wait(10)
            RequestAnimDict("anim@amb@clubhouse@tutorial@bkr_tut_ig3@")
        end
        TaskPlayAnim(ped, "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", "machinic_loop_mechandplayer", 1.0, 8.0, 100000, 16, -1, false, false, false)
        --TriggerEvent("qb-carhack:starthack", function(result)
        SetFollowVehicleCamViewMode(4)
        local class = GetVehicleClass(vehicle)
        print("class:"..class)
        if class == 8 or class == 6 or class == 7 or class == 18 or class == 16 or class == 15 then 
            TriggerEvent("qb-carhack:starthack", function(result)
                print("result: " .. tostring(result))
                    if result == 1 then 
                        SetVehicleEngineOn(vehicle, true, false, true)
                        TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(vehicle))
                        QBCore.Functions.Notify("Hotwire succeeded!")
                        lockpicked = false
                    else
                        SetVehicleEngineOn(vehicle, false, false, true)
                        QBCore.Functions.Notify("Hotwire failed!", "error")
                    end
                    StopAnimTask(ped, "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", "machinic_loop_mechandplayer", 1.0)
                    SetFollowVehicleCamViewMode(1)
                    IsHotwiring = false
                    SetVehicleAlarm(vehicle, false)
            end)
        else 

            TriggerEvent('qb-hotwire:start', function(result)
                print("result: " .. tostring(result))
                    if result == 1 then 
                        SetVehicleEngineOn(vehicle, true, false, true)
                        TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(vehicle))
                        QBCore.Functions.Notify("Hotwire succeeded!")
                        lockpicked = false
                    else
                        SetVehicleEngineOn(vehicle, false, false, true)
                        QBCore.Functions.Notify("Hotwire failed!", "error")
                    end
                    StopAnimTask(ped, "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", "machinic_loop_mechandplayer", 1.0)
                    SetFollowVehicleCamViewMode(1)
                    IsHotwiring = false
                    SetVehicleAlarm(vehicle, false)
            end)
        end
      
--[[         QBCore.Functions.Progressbar("hotwire_vehicle", "Engaging the ignition switch", hotwireTime, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true
        }, {
            animDict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@",
            anim = "machinic_loop_mechandplayer",
            flags = 16
        }, {}, {}, function() -- Done
            StopAnimTask(ped, "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", "machinic_loop_mechandplayer", 1.0)
            if (math.random() <= Config.HotwireChance) then
                lockpicked = false
                TriggerServerEvent('hud:server:GainStress', math.random(1, 4))
                TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(vehicle))
                QBCore.Functions.Notify("Hotwire succeeded!")
            else
                SetVehicleEngineOn(veh, false, false, true)
                TriggerServerEvent('hud:server:GainStress', math.random(1, 4))
                QBCore.Functions.Notify("Hotwire failed!", "error")
            end
            IsHotwiring = false
        end, function() -- Cancel
            StopAnimTask(ped, "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", "machinic_loop_mechandplayer", 1.0)
            SetVehicleEngineOn(veh, false, false, true)
            QBCore.Functions.Notify("Hotwire failed!", "error")
            IsHotwiring = false
        end) ]]
    end
end

local function RobVehicle(target)
    IsRobbing = true
    loadAnimDict('mp_am_hold_up')
    while not HasAnimDictLoaded('mp_am_hold_up') do
        Wait(100)
    end 
    TaskPlayAnim(target, "mp_am_hold_up", "holdup_victim_20s", 8.0, -8.0, -1, 2, 0, false, false, false)
    Wait(100)
    local veh = GetVehiclePedIsUsing(target)
    FreezeEntityPosition(veh, true)
    FreezeEntityPosition(target, true)
    QBCore.Functions.Progressbar("rob_keys", "Attempting Robbery..", 2000, false, true, {}, {}, {}, {}, function()
        local chance = math.random()
        if chance <= Config.RobberyChance then
            SetVehicleDoorsLocked(veh, 1)
            FreezeEntityPosition(target, false)
            Wait(1000)
            TaskEveryoneLeaveVehicle(veh)
            Wait(500)
            ClearPedTasksImmediately(target)
            TaskReactAndFleePed(target, PlayerPedId())
            FreezeEntityPosition(veh, false)
            local plate = QBCore.Functions.GetPlate(GetVehiclePedIsIn(target, true))
            TriggerEvent('vehiclekeys:client:SetOwner', plate)
            QBCore.Functions.Notify('You Got The Keys!', 'success')
            Wait(10000)
            IsRobbing = false
        else
            FreezeEntityPosition(veh, false)
            Wait(1000)
            FreezeEntityPosition(target, false)
            PoliceCall()
            ClearPedTasks(target)
            TaskReactAndFleePed(target, PlayerPedId())
            TriggerServerEvent('hud:server:GainStress', math.random(1, 4))
            QBCore.Functions.Notify('They Called The Cops!', 'error')
            Wait(10000)
            IsRobbing = false
        end
    end)
end

local function IsBlacklistedWeapon()
    local weapon = GetSelectedPedWeapon(PlayerPedId())
    if weapon ~= nil then
        for _, v in pairs(Config.NoRobWeapons) do
            if weapon == GetHashKey(v) then
                return true
            end
        end
    end
    return false
end

local function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0 + 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

-- Events

--[[ RegisterNetEvent('lockpicks:UseLockpick', function(isAdvanced)
    LockpickDoor(isAdvanced)
end) ]]

RegisterNetEvent('vehiclekeys:client:SetOwner', function(plate)
    local VehPlate = plate
    local CurrentVehPlate = QBCore.Functions.GetPlate(GetVehiclePedIsIn(PlayerPedId(), true))
    if VehPlate == nil then
        VehPlate = CurrentVehPlate
    end
    TriggerServerEvent('vehiclekeys:server:SetVehicleOwner', VehPlate)
    if IsPedInAnyVehicle(PlayerPedId()) and plate == CurrentVehPlate then
        SetVehicleEngineOn(GetVehiclePedIsIn(PlayerPedId(), true), true, false, true)
    end
    HasVehicleKey = true
end)

RegisterNetEvent('vehiclekeys:client:GiveKeys', function(target)
    local vehicles = IsPedInAnyVehicle(PlayerPedId())
    if vehicles then
        local plate = QBCore.Functions.GetPlate(GetVehiclePedIsIn(PlayerPedId(), true))
        TriggerServerEvent('vehiclekeys:server:GiveVehicleKeys', plate, target)
    else
        QBCore.Functions.Notify('you need to be in a vehicle to give key', 'error')
    end
end)

RegisterNetEvent('vehiclekeys:client:ToggleEngine', function()
    local EngineOn = IsVehicleEngineOn(GetVehiclePedIsIn(PlayerPedId()))
    local veh = GetVehiclePedIsIn(PlayerPedId(), true)
    if HasVehicleKey then
        if EngineOn then
            SetVehicleEngineOn(veh, false, false, true)
        else
            SetVehicleEngineOn(veh, true, false, true)
        end
    end
end)

-- command

RegisterKeyMapping('togglelocks', 'Toggle Vehicle Locks', 'keyboard', 'L')
RegisterCommand('togglelocks', function()
    LockVehicle()
end)

-- thread

CreateThread(function()
    while true do
        local sleep = 100
        if LocalPlayer.state.isLoggedIn then
            local ped = PlayerPedId()
            local entering = GetVehiclePedIsTryingToEnter(ped)
            if entering ~= 0 and not Entity(entering).state.ignoreLocks then
                sleep = 2000
                local plate = QBCore.Functions.GetPlate(entering)
                QBCore.Functions.TriggerCallback('vehiclekeys:server:CheckOwnership', function(result)
                    if not result then -- if not player owned
                        HasVehicleKey = false
                        SetVehicleDoorsLocked(entering, 7)
                        local driver = GetPedInVehicleSeat(entering, -1)
                        if driver ~= 0 and not IsPedAPlayer(driver) then
                            print(GetVehicleClass(entering))
               
                            if Config.Rob and not exports["qb-cnr"]:isACop() then
                                if IsEntityDead(driver) then
                                    TriggerEvent("vehiclekeys:client:SetOwner", plate)
                                    SetVehicleDoorsLocked(entering, 7)
                                    HasVehicleKey = true
                                elseif GetVehicleClass(entering) == 8 and driver then 
                                    TriggerEvent("vehiclekeys:client:SetOwner", plate)
                                    SetVehicleDoorsLocked(entering, 1)
                                    HasVehicleKey = true
                                else
                                    SetVehicleDoorsLocked(entering, 2)
                                end
                            else
                                TriggerEvent("vehiclekeys:client:SetOwner", plate)
                                SetVehicleDoorsLocked(entering, 2)
                                HasVehicleKey = false
                            end
                        else
                            QBCore.Functions.TriggerCallback('vehiclekeys:server:CheckHasKey', function(result)
                                if not lockpicked and lockpickedPlate ~= plate then
                                    if result == false then
                                        print("triggered carlockshit")
                                        SetVehicleDoorsLocked(entering, 7)
                                        HasVehicleKey = false
                                        lockpicked = true -- this is a dirty hack. you probably dont want to replicate this.
                                    else 
                                        HasVehicleKey = true
                                    end
                                elseif lockpicked and lockpickedPlate == plate then
                                    if result == false then
                                        HasVehicleKey = false
                                    else 
                                        HasVehicleKey = true
                                    end
                                end
                            end, plate)
                        end
                    else 
                        print("owns car")
                        SetVehicleDoorsLocked(entering, 1)
                        HasVehicleKey = true
                    end
                end, plate)
            end

            if IsPedInAnyVehicle(ped, false) and lockpicked and not IsHotwiring and not HasVehicleKey then
                sleep = 5
                local veh = GetVehiclePedIsIn(ped)
                local vehpos = GetOffsetFromEntityInWorldCoords(veh, 0.0, 2.0, 1.0)
                SetVehicleEngineOn(veh, false, false, true)
                if GetPedInVehicleSeat(veh, -1) == PlayerPedId()  then
                    DrawText3D(vehpos.x, vehpos.y, vehpos.z, "~g~[H]~w~ - Hotwire")
                    local class = GetVehicleClass(veh)
                    if IsControlJustPressed(0, 74) and not exports["qb-cnr"]:isACop() then
                        Hotwire()
                    elseif IsControlJustPressed(0, 74) and exports["qb-cnr"]:isACop() and not (class == 8 or class == 6 or class == 7 or class == 16 or class == 15)  then 
--[[                         QBCore.Functions.Progressbar("hotwire", "Hotwiring..", 20000, false, true, {
                                disableMovement = true, --
                                disableCarMovement = true,
                                disableMouse = false,
                                disableCombat = true,
                            }, {}, {}, {}, function() 
                                SetVehicleEngineOn(veh, true, false, true)
                                TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(veh))
                                QBCore.Functions.Notify("Hotwire succeeded!")
                                lockpicked = false
                            end, function() -- Cancel
                        end) ]]
                        Hotwire()
                    elseif IsControlJustPressed(0, 74) and exports["qb-cnr"]:isACop() and (class == 8 or class == 6 or class == 7 or class == 16 or class == 15) then 
                        QBCore.Functions.Notify("Can't hotwire this!","error")
                    end
                end
            end

            if Config.Rob then
                if not IsRobbing then
                    local playerid = PlayerId()
                    local aiming, target = GetEntityPlayerIsFreeAimingAt(playerid, target)
                    local isCop = exports["qb-cnr"]:isACop()
                    if aiming and not isCop and (target ~= nil and target ~= 0) then
                        if DoesEntityExist(target) and not IsEntityDead(target) and not IsPedAPlayer(target) and not isTargetACop(target) then
                            if IsPedInAnyVehicle(target, false) then
                                local targetveh = GetVehiclePedIsIn(target)
                                if GetPedInVehicleSeat(targetveh, -1) == target and GetEntitySpeed(targetveh) * 3.6 < 30 then
                                    if not IsBlacklistedWeapon() then
                                        local pos = GetEntityCoords(ped, true)
                                        local targetpos = GetEntityCoords(target, true)
                                        if #(pos - targetpos) < 5.0 then
                                            RobVehicle(target)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

function isTargetACop(ped)
    if (GetEntityArchetypeName(ped) == 's_m_y_cop_01') then return true else return false end
end

