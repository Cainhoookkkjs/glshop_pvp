Config = {}

-- Main Command
Config.Command = "pvp" 

-- Arena Definitions
Config.Arenas = {
    -- {
    --     name = "Arena Região",
    --     spawn1 = vector4(163.66, -1004.99, 29.35, 344.42),
    --     spawn2 = vector4(180.25, -1035.79, 29.33, 161.42),
    --     radius = 50.0 
    -- },
    {
        name = "Arena Aeroporto",
        spawn1 = vector4(-1036.19, -3051.05, 13.94, 230.12),
        spawn2 = vector4(-1084.77, -3004.29, 13.94, 58.74),
        radius = 60.0
    }
}

-- Match Settings
Config.CountdownTime = 5 
Config.MatchBucketStart = 100 -- Starting ID for Routing Buckets
Config.DefaultBucket = 0 -- Target bucket after match concludes
Config.Weapon = "WEAPON_PISTOL" 
Config.Ammo = 250 

-- Localization (Standalone, no external dictionary needed)
Config.Locales = {
    ['in_queue'] = "~g~[PVP]~w~ Você entrou na fila.",
    ['left_queue'] = "~r~[PVP]~w~ Você saiu da fila.",
    ['match_found'] = "~y~[PVP]~w~ Partida encontrada!",
    ['match_ended_won'] = "~g~VITORIA FINAL! ~w~Você venceu o PvP.",
    ['match_ended_lost'] = "~r~DERROTA FINAL! ~w~Não foi dessa vez.",
    ['out_of_bounds'] = "~r~ARENA: ~w~Volte para a área de combate!"
}
