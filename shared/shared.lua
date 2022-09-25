cfg = {}

cfg.missions = {
    {
        cdsCheck = vector3(-1191.59,-630.32,24.15), -- Coordenadas em que o player inicia a missão
        vehSpawn = vector4(-1221.77,-675.46,35.17,311.82), -- Coordenadas de spawn do veículo (x,y,z,heading)
        allowedVehicles = {`windsor2`,`previon`,`diablous`,`hermes`,`slamvan3`,`superd`,`btype3`,`ztype`}, -- Modelos de veículos que podem spawnar
        finishCds = vector3(1152.43,-3279.01,5.53), -- Coordenadas de finalização da missão
        npcInfo = {
            spawnRange = 20, -- Tamanho da área de spawn dos npcs (Ex.: quadrado entre x-20 y-20 até x+20 e y+20 do ponto central)
            models = {`cs_amandatownley`,`a_m_y_beach_03`}, -- Peds que podem ser spawnados
            weapons = {`WEAPON_BAT`,`WEAPON_BOTTLE`,`WEAPON_GOLFCLUB`,`WEAPON_HATCHET`,`WEAPON_MACHETE`,`WEAPON_WRENCH`,`WEAPON_BATTLEAXE`}, -- Armas que os peds podem usar
        }
    }
}