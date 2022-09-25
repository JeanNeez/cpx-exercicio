-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")
vS = Tunnel.getInterface("cpx-exercicio")
vC = {}
Tunnel.bindInterface("cpx-exercicio",vC)
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIÁVEIS
-----------------------------------------------------------------------------------------------------------------------------------------
local inMission = nil
local ableToCheck = true
local lastCheck = GetGameTimer()
local ped
local vehBlip
local cdsBlip
local missionVehNetId
local enemys = {}
local enemysReady = false
local textInScreen = false
local tempMissionBlip = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- FUNÇÕES
-----------------------------------------------------------------------------------------------------------------------------------------
local function newVehBlip(entity)
    if vehBlip and DoesBlipExist(vehBlip) then
        RemoveBlip(vehBlip)
        vehBlip = nil
    end
    if DoesEntityExist(entity) then
        vehBlip = AddBlipForEntity(entity)
        SetBlipAsFriendly(vehBlip,true)
        SetBlipSprite(vehBlip,523)
        SetBlipAsShortRange(vehBlip,false)
        SetBlipScale(vehBlip,0.8)
        SetBlipColour(vehBlip,38)
        SetBlipRoute(vehBlip,true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Veículo abandonado")
        EndTextCommandSetBlipName(vehBlip)
    end
end

local function clearVehBlip()
    if vehBlip and DoesBlipExist(vehBlip) then
        RemoveBlip(vehBlip)
        vehBlip = nil
    end
end

local function newCdsBlip(mission)
    local cds = cfg.missions[mission].finishCds
    if cdsBlip and DoesBlipExist(cdsBlip) then
        RemoveBlip(cdsBlip)
        cdsBlip = nil
    end
    cdsBlip = AddBlipForCoord(cds.x,cds.y,cds.z)
    SetBlipSprite(cdsBlip,1)
    SetBlipAsShortRange(cdsBlip,false)
    SetBlipScale(cdsBlip,0.7)
    SetBlipColour(cdsBlip,5)
    SetBlipRoute(cdsBlip,true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Entrega do veículo")
    EndTextCommandSetBlipName(cdsBlip)
end

local function showText(text,font,x,y)
    if textInScreen then
        textInScreen = false
        Citizen.Wait(500)
    end
    textInScreen = true
    async(function()
        while textInScreen do
            SetTextFont(font)
            SetTextScale(0.5,0.5)
            SetTextColour(255,255,255,200)
            SetTextOutline()
            SetTextCentre(1)
            SetTextEntry("STRING")
            AddTextComponentString(text)
            DrawText(x,y)
            Citizen.Wait(1)
        end
    end)
end

local function checkAlive()
    return GetEntityHealth(ped) > 101
end

local function vC.spawnMissionVeh(model,selected,plate)
    local spawnCds = cfg.missions[selected].vehSpawn
    local vehNet
    local timeout = GetGameTimer()
    RequestModel(model)
    repeat
        Citizen.Wait(10)
    until HasModelLoaded(model) or GetGameTimer()-timeout >= 20000

    if HasModelLoaded(model) then
        ClearAreaOfVehicles(spawnCds.x,spawnCds.y,spawnCds.z,5.0)
        local veh = CreateVehicle(model,spawnCds.x,spawnCds.y,spawnCds.z,spawnCds.w,true,true)

        repeat
            Citizen.Wait(10)
        until NetworkGetEntityIsNetworked(veh) or GetGameTimer()-timeout >= 20000

        SetVehicleOnGroundProperly(veh)
        SetVehicleNumberPlateText(veh,plate)
        SetVehicleDirtLevel(veh,15.0)
        SetVehicleFuelLevel(veh,80.0)
        vehNet = VehToNet(veh)
        SetNetworkIdExistsOnAllMachines(vehNet,true)
        NetworkSetNetworkIdDynamic(vehNet,true)
        SetNetworkIdCanMigrate(vehNet,false)
        for _,i in ipairs(GetActivePlayers()) do
            SetNetworkIdSyncToPlayer(vehNet,i,true)
        end
        SetModelAsNoLongerNeeded(model)
    end
    return vehNet or 0
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- EXECUÇÃO
-----------------------------------------------------------------------------------------------------------------------------------------
Citizen.CreateThread(function()
    while true do
        if not inMission and ableToCheck then
            local cds = GetEntityCoords(PlayerPedId())
            for i,v in ipairs(cfg.missions) do
                if #(cds-v.cdsCheck) <= 50 then
                    ableToCheck = false
                    lastCheck = GetGameTimer()
                    TriggerServerEvent("cpx-exercicio:initMission")
                    break
                end
            end
        else
            if GetGameTimer()-lastCheck >= 60000 then
                ableToCheck = true
            end
        end
        Citizen.Wait(1000)
    end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- ESTÁGIOS DA MISSÃO
-----------------------------------------------------------------------------------------------------------------------------------------
function vC.missionFirstStep(vehNet,mission)
    local cb = 0
    if NetworkDoesEntityExistWithNetworkId(vehNet) then
        inMission = mission
        missionVehNetId = vehNet
        local missionVeh = NetToVeh(missionVehNetId)
        newVehBlip(missionVeh)
        showText("~q~MISSÃO: ~w~Entregue o ~b~VEÍCULO ~w~no ~y~DESTINO",4,0.5,0.93)
        ped = PlayerPedId()
        local missionCds = cfg.missions[mission].cdsCheck
        local timeout = GetGameTimer()
        while inMission and cb == 0 do
            if GetVehiclePedIsIn(ped) == missionVeh then
                cb = 1
                clearVehBlip()
                newCdsBlip(mission)
                break
            elseif #(GetEntityCoords(ped)-missionCds) >= 250 or GetGameTimer()-timeout >= 300000 or not checkAlive() then
                cb = 2
                break
            end
            Citizen.Wait(1000)
        end
    end
    return cb
end

function vC.missionSecondStep()
    if inMission then
        local finishCds = cfg.missions[inMission].finishCds
        local timer = GetGameTimer()
        local missionVeh = NetToVeh(missionVehNetId)
        while inMission do
            if GetVehiclePedIsIn(ped) == missionVeh and #(GetEntityCoords(ped)-finishCds) <= 200 then
                return 1
            elseif GetGameTimer()-timer > 600000 or GetVehicleEngineHealth(missionVeh) <= 0 or not checkAlive() then
                return 2
            end
            Citizen.Wait(1000)
        end
    end
end

function vC.missionThirdStep()
    if inMission then
        repeat
            Citizen.Wait(100)
        until enemysReady
        if cdsBlip and DoesBlipExist(cdsBlip) then
            RemoveBlip(cdsBlip)
            cdsBlip = nil
        end
        showText("Derrote todos os ~r~INIMIGOS",4,0.5,0.93)
        local finishCds = cfg.missions[inMission].finishCds
        while inMission do
            for i=#enemys,1,-1 do
                if DoesEntityExist(enemys[i]) then
                    if IsPedDeadOrDying(enemys[i]) then
                        table.remove(enemys,i)
                    end
                end
            end
            if #enemys == 0 then
                enemysReady = false
                return 1
            elseif #(GetEntityCoords(ped)-finishCds) >= 270 or not checkAlive() then
                return 2
            end
            Citizen.Wait(1000)
        end
    end
end

function vC.missionFourthStep()
    if inMission then
        local missionVeh
        local finishCds = cfg.missions[inMission].finishCds
        showText("Estacione o ~b~VEÍCULO ~w~na ~y~MARCAÇÃO",4,0.5,0.93)
        while inMission do
            if NetworkDoesEntityExistWithNetworkId(missionVehNetId) then
                if not missionVeh or not DoesEntityExist(missionVeh) then
                    missionVeh = NetToVeh(missionVehNetId)
                end
                DrawMarker(1,finishCds.x,finishCds.y,finishCds.z-0.9,0.0,0.0,0.0,0.0,0.0,0.0,15.0,15.0,0.8,255,230,0,180)
                if #(GetEntityCoords(missionVeh)-finishCds) <= 10 and IsVehicleSeatFree(missionVeh,-1) then
                    textInScreen = false
                    return 1
                end
            end
            if not checkAlive() then
                return 2
            end
            Citizen.Wait(5)
        end
    end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- EVENTOS DO HOST DA MISSÃO
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("cpx-exercicio:manageAgressivePeds")
AddEventHandler("cpx-exercicio:manageAgressivePeds",function(tbl)
    local _,rls = AddRelationshipGroup('MISSION_ENEMY')
    local pRls = `PLAYER`
    for i,v in ipairs(tbl) do
        local _t = GetGameTimer()+5000
        while not NetworkDoesEntityExistWithNetworkId(v) and GetGameTimer() < _t do
            Citizen.Wait(100)
        end
        local _e = NetToPed(v)
        table.insert(enemys,_e)
        SetPedRelationshipGroupHash(_e,rls)
        SetPedCombatAttributes(_e,46,1) -- CA_CAN_FIGHT_ARMED_PEDS_WHEN_NOT_ARMED
        TaskCombatPed(_e,ped,0,16)
        local _b = AddBlipForEntity(_e)
        SetBlipSprite(_b,270)
        SetBlipColour(_b,1)
        SetBlipAsShortRange(_b,false)
    end
    SetRelationshipBetweenGroups(5,rls,pRls)
    enemysReady = true
end)

RegisterNetEvent("cpx-exercicio:finishMission")
AddEventHandler("cpx-exercicio:finishMission",function(abort)
    inMission = nil
    if vehBlip and DoesBlipExist(vehBlip) then
        RemoveBlip(vehBlip)
        vehBlip = nil
    end
    if cdsBlip and DoesBlipExist(cdsBlip) then
        RemoveBlip(cdsBlip)
        cdsBlip = nil
    end
    if abort then
        local veh = NetToVeh(missionVehNetId)
        if DoesEntityExist(veh) then
            local cds = GetEntityCoords(veh)
            AddExplosion(cds,2,1.0,true,true,true)
        end
    end
    missionVehNetId = nil
    enemys = {}
    enemysReady = false
    textInScreen = false
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- EVENTOS DOS DEMAIS PLAYERS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("cpx-exercicio:missionStarted")
AddEventHandler("cpx-exercicio:missionStarted",function(mission)
    if not inMission or inMission ~= mission then
        local cds = cfg.missions[mission].finishCds
        local blip = AddBlipForCoord(cds.x,cds.y,cds.z)
        SetBlipSprite(blip,303)
        SetBlipScale(blip,0.6)
        SetBlipColour(blip,1)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Missão de entrega de veículo")
        EndTextCommandSetBlipName(blip)
        tempMissionBlip[mission] = blip
    end
end)

RegisterNetEvent("cpx-exercicio:missionFinished")
AddEventHandler("cpx-exercicio:missionFinished",function(mission)
    if not inMission or inMission ~= mission then
        local blip = tempMissionBlip[mission]
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
            tempMissionBlip[mission] = nil
        end
    end
end)