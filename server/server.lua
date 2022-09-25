-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")
vC = Tunnel.getInterface("cpx-exercicio")
vS = {}
Tunnel.bindInterface("cpx-exercicio",vS)
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIÁVEIS
-----------------------------------------------------------------------------------------------------------------------------------------
local active = {}
local missionRunning = {}
local inMission = {}
Citizen.CreateThread(function()
    for i,_ in ipairs(cfg.missions) do
        missionRunning[i] = 0
    end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- FUNÇÕES
-----------------------------------------------------------------------------------------------------------------------------------------
local function requestSpawnVeh(source,selectedMission)
    local vehModels = cfg.missions[selectedMission].allowedVehicles
    return vC.spawnMissionVeh(source,vehModels[math.random(#vehModels)],selectedMission,vRP.generateStringNumber("LLDDDLLL"))
end

local function spawnEnemys(mission)
    local tbl = {}
    local n = math.random(10,20)
    local defaultCds = cfg.missions[mission].finishCds
    local info = cfg.missions[mission].npcInfo
    local modelsAmount = #info.models
    local weaponsAmount = #info.weapons
    for i=1,n do
        local xx = math.random(parseInt(defaultCds.x)-info.spawnRange,parseInt(defaultCds.x)+info.spawnRange)
        local yy = math.random(parseInt(defaultCds.y)-info.spawnRange,parseInt(defaultCds.y)+info.spawnRange)
        local ped = CreatePed(0,info.models[math.random(modelsAmount)],xx+0.0,yy+0.0,defaultCds.z,0.0,true)
        if info.weapons[1] then
            GiveWeaponToPed(ped,info.weapons[math.random(weaponsAmount)],250,false,true)
        end
        table.insert(tbl,NetworkGetNetworkIdFromEntity(ped))
    end
    return tbl
end

local function abortMission(source,force)
    missionRunning[inMission[source][1]] = 0
    local veh = NetworkGetEntityFromNetworkId(inMission[source][2])
    async(function()
        Citizen.Wait(30000)
        DeleteEntity(veh)
    end)
    if force then
        local enemyTbl = inMission[source][3]
        for i=#enemyTbl,1,-1 do
            local _e = NetworkGetEntityFromNetworkId(enemyTbl[i])
            if DoesEntityExist(_e) then
                DeleteEntity(_e)
            end
            table.remove(enemyTbl,i)
        end
    end
    inMission[source] = inMission[source][1]
    TriggerClientEvent("cpx-exercicio:finishMission",source,force)
    TriggerClientEvent("cpx-exercicio:missionFinished",-1,inMission[source])
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- EXECUÇÃO
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("cpx-exercicio:initMission")
AddEventHandler("cpx-exercicio:initMission",function()
    local source = source
    if not active[source] then
        active[source] = true
        if not inMission[source] or tonumber(inMission[source]) then
            local ped = GetPlayerPed(source)
            local cds = GetEntityCoords(ped)
            local cb = 0
            local mission = 0
            local vehSvId = 0
            for i,v in ipairs(cfg.missions) do
                if #(cds-v.cdsCheck) <= 50.0 and missionRunning[i] == 0 and math.random(100) <= 20 then 
                    if inMission[source] and inMission[source] == i then
                        goto skip
                    end
                    missionRunning[i] = source
                    local vehNet = requestSpawnVeh(source,i)
                    vehSvId = NetworkGetEntityFromNetworkId(vehNet)
                    inMission[source] = {i,vehNet,{}}
                    cb = vC.missionFirstStep(source,vehNet,i)
                    mission = i
                    break
                end
                ::skip::
            end
            if cb == 1 then
                TriggerClientEvent("cpx-exercicio:missionStarted",-1,mission)
                if vC.missionSecondStep(source) == 1 then
                    local enemyTbl = spawnEnemys(mission)
                    inMission[source][3] = enemyTbl
                    TriggerClientEvent("cpx-exercicio:manageAgressivePeds",source,enemyTbl)
                    if vC.missionThirdStep(source) == 1 then
                        for i=#enemyTbl,1,-1 do
                            local _e = NetworkGetEntityFromNetworkId(enemyTbl[i])
                            if GetEntityHealth(_e) == 0 then
                                DeleteEntity(_e)
                                table.remove(enemyTbl,i)
                            end
                        end
                        if #enemyTbl == 0 then
                            inMission[source][3] = enemyTbl
                            if #(GetEntityCoords(vehSvId)-cfg.missions[mission].finishCds) > 10 then
                                if vC.missionFourthStep(source) ~= 1 then
                                    abortMission(source,true)
                                    active[source] = nil
                                    return
                                end
                            end
                            FreezeEntityPosition(vehSvId,true)
                            TriggerClientEvent("Notify",source,"azul","Missão concluída com sucesso!")
                            abortMission(source)
                        end
                    else
                        abortMission(source,true)
                    end
                else
                    abortMission(source,true)
                end
            else
                abortMission(source,true)
            end
        end
        active[source] = nil
    end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DESCONEXÃO
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("playerDisconnect",function(_,source)
    if active[source] then
        active[source] = nil
    end
    if inMission[source] and type(inMission[source]) == "table" then
        abortMission(source,true)
    end
end)