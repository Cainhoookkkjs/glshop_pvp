-----------------------------------------------------------------------------------------
-- GERENCIAMENTO DE ESTADO
-----------------------------------------------------------------------------------------

-- GlobalState fornece sincronização eficiente entre clientes para o HUD
GlobalState.PvPQueueCount = 0
GlobalState.PvPActiveMatches = 0

local playersInQueue = {}
local activeMatches = {}
local activeMatchesCount = 0
local nextBucketId = Config.MatchBucketStart

-----------------------------------------------------------------------------------------
-- UTILITÁRIOS INTERNOS
-----------------------------------------------------------------------------------------

local function notify(source, message)
    TriggerClientEvent('pfl:pvp:notify', source, message)
end

local function updateGlobalStats()
    GlobalState.PvPQueueCount = #playersInQueue
    GlobalState.PvPActiveMatches = activeMatchesCount
end

-----------------------------------------------------------------------------------------
-- LÓGICA CORE: MATCHMAKING E CICLO DE VIDA DA PARTIDA
-----------------------------------------------------------------------------------------

-- Instancia uma nova partida em um bucket isolado
function createMatch(p1Src, p2Src)
    local arena = Config.Arenas[math.random(#Config.Arenas)]
    local bucketId = nextBucketId
    nextBucketId = nextBucketId + 1

    local match = {
        id = bucketId,
        arena = arena,
        score = { p1 = 0, p2 = 0 },
        players = {
            [1] = { 
                source = p1Src, 
                pos = GetEntityCoords(GetPlayerPed(p1Src)), 
                oldBucket = GetPlayerRoutingBucket(p1Src) 
            },
            [2] = { 
                source = p2Src, 
                pos = GetEntityCoords(GetPlayerPed(p2Src)), 
                oldBucket = GetPlayerRoutingBucket(p2Src) 
            }
        }
    }

    activeMatches[bucketId] = match
    activeMatchesCount = activeMatchesCount + 1

    -- Decisão Técnica: Routing Buckets para isolamento de entidades e rede
    SetPlayerRoutingBucket(p1Src, bucketId)
    SetPlayerRoutingBucket(p2Src, bucketId)

    TriggerClientEvent('pfl:pvp:startMatch', p1Src, arena, bucketId, 1)
    TriggerClientEvent('pfl:pvp:startMatch', p2Src, arena, bucketId, 2)
    
    updateGlobalStats()
end

-- Comando: Alternar status do jogador na fila
RegisterCommand(Config.Command, function(source, args)
    if source == 0 then return end
    local src = source

    -- Validação: Garantir que o jogador não esteja já em combate
    for bucketId, match in pairs(activeMatches) do
        if match.players[1].source == src or match.players[2].source == src then
            notify(src, "~r~ERRO: ~w~Você já está em combate!")
            return
        end
    end

    local alreadyInQueue = false
    for i, pSrc in ipairs(playersInQueue) do
        if pSrc == src then
            table.remove(playersInQueue, i)
            alreadyInQueue = true
            notify(src, Config.Locales['left_queue'])
            TriggerClientEvent('pfl:pvp:syncQueueState', src, false)
            break
        end
    end

    if not alreadyInQueue then
        table.insert(playersInQueue, src)
        notify(src, Config.Locales['in_queue'])
        TriggerClientEvent('pfl:pvp:syncQueueState', src, true)
    end

    updateGlobalStats()
end)

-- Thread de Segundo Plano: Matchmaking Automático
CreateThread(function()
    while true do
        Wait(2000)
        if #playersInQueue >= 2 then
            local p1 = table.remove(playersInQueue, 1)
            local p2 = table.remove(playersInQueue, 1)

            if GetPlayerName(p1) and GetPlayerName(p2) then
                createMatch(p1, p2)
            else
                -- Tratamento gracioso para jogadores que desconectaram durante o pareamento
                if GetPlayerName(p1) then table.insert(playersInQueue, 1, p1) end
                if GetPlayerName(p2) then table.insert(playersInQueue, 1, p2) end
            end
            updateGlobalStats()
        end
    end
end)

-----------------------------------------------------------------------------------------
-- HANDLERS DE REDE (NETWORK)
-----------------------------------------------------------------------------------------

-- Lida de forma segura com vitórias de rounds e encerramento final da partida
RegisterNetEvent('pfl:pvp:reportDeath')
AddEventHandler('pfl:pvp:reportDeath', function()
    local src = source
    local bucketId = GetPlayerRoutingBucket(src)
    local match = activeMatches[bucketId]

    -- Verificação de Segurança: O jogador deve estar registrado na partida do bucket atual
    if match and (match.players[1].source == src or match.players[2].source == src) then
        local p1 = match.players[1].source
        local p2 = match.players[2].source
        
        local winnerIdx = (src == p1) and 2 or 1
        local winnerKey = (winnerIdx == 1) and "p1" or "p2"
        local winnerSrc = match.players[winnerIdx].source
        local loserSrc = src

        match.score[winnerKey] = match.score[winnerKey] + 1
        
        local p1Score = match.score.p1
        local p2Score = match.score.p2

        print(("[PvP] Partida %d: %d (%d) vs %d (%d)"):format(bucketId, p1, p1Score, p2, p2Score))

        -- Sincronizar placar (Cada um recebe o seu placar primeiro e dps o do oponente)
        TriggerClientEvent('pfl:pvp:updateScore', p1, p1Score, p2Score)
        TriggerClientEvent('pfl:pvp:updateScore', p2, p2Score, p1Score)

        -- Caso Terminal: Primeiro a vencer 2 rounds
        if match.score[winnerKey] >= 2 then
            notify(winnerSrc, Config.Locales['match_ended_won'])
            notify(loserSrc, Config.Locales['match_ended_lost'])

            TriggerClientEvent('pfl:pvp:finishMatch', p1, match.players[1].pos)
            TriggerClientEvent('pfl:pvp:finishMatch', p2, match.players[2].pos)

            SetTimeout(1500, function()
                if GetPlayerName(p1) then SetPlayerRoutingBucket(p1, match.players[1].oldBucket or Config.DefaultBucket) end
                if GetPlayerName(p2) then SetPlayerRoutingBucket(p2, match.players[2].oldBucket or Config.DefaultBucket) end
            end)

            activeMatches[bucketId] = nil
            activeMatchesCount = math.max(0, activeMatchesCount - 1)
            updateGlobalStats()
        else
            -- Caso de Reset de Round
            notify(winnerSrc, "~g~ROUND VENCIDO! ~w~Prepando próximo...")
            notify(loserSrc, "~r~ROUND PERDIDO! ~w~Prepare-se para renascer...")
            
            SetTimeout(3000, function()
                if activeMatches[bucketId] then
                    TriggerClientEvent('pfl:pvp:nextRound', p1, 1)
                    TriggerClientEvent('pfl:pvp:nextRound', p2, 2)
                end
            end)
        end
    end
end)

-----------------------------------------------------------------------------------------
-- LIMPEZA AO DESCONECTAR (playerDropped)
-----------------------------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    
    -- Cleanup Queue
    for i, pSrc in ipairs(playersInQueue) do
        if pSrc == src then
            table.remove(playersInQueue, i)
            break
        end
    end

    -- Limpar Partida
    for bucketId, match in pairs(activeMatches) do
        if match.players[1].source == src or match.players[2].source == src then
            local other = (match.players[1].source == src) and match.players[2].source or match.players[1].source
            
            if GetPlayerName(other) then
                notify(other, "~r~OPONENTE DESCONECTOU! ~w~Você venceu a partida.")
                local otherIdx = (match.players[1].source == other) and 1 or 2
                TriggerClientEvent('pfl:pvp:finishMatch', other, match.players[otherIdx].pos)
                SetPlayerRoutingBucket(other, match.players[otherIdx].oldBucket or Config.DefaultBucket)
            end

            activeMatches[bucketId] = nil
            activeMatchesCount = math.max(0, activeMatchesCount - 1)
            break
        end
    end

    updateGlobalStats()
end)
