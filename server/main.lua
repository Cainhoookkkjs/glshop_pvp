-----------------------------------------------------------------------------------------
-- CLASSES (Carregadas globalmente via fxmanifest)
-- Match        -> server/classes/Match.lua
-- QueueManager -> server/classes/QueueManager.lua
-----------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------
-- GERENCIAMENTO DE ESTADO GLOBAL
-----------------------------------------------------------------------------------------

-- GlobalState fornece sincronização eficiente entre clientes para o HUD
GlobalState.PvPQueueCount = 0
GlobalState.PvPActiveMatches = 0

-- Registro de partidas ativas indexado por bucket ID
local activeMatches = {}
local activeMatchesCount = 0
local nextBucketId = Config.MatchBucketStart

-----------------------------------------------------------------------------------------
-- FUNÇÕES DE ATUALIZAÇÃO DE ESTADO
-----------------------------------------------------------------------------------------

local function updateGlobalStats(queueCount)
    GlobalState.PvPQueueCount = queueCount
    GlobalState.PvPActiveMatches = activeMatchesCount
end

local function notify(source, message)
    TriggerClientEvent('pfl:pvp:notify', source, message)
end

-----------------------------------------------------------------------------------------
-- MATCHMAKER: CALLBACK QUANDO UM PAR É FORMADO
-----------------------------------------------------------------------------------------

local function onMatchReady(p1Source, p2Source)
    -- Seleciona arena aleatória
    local arena = Config.Arenas[math.random(#Config.Arenas)]
    
    -- Aloca um novo bucket ID para isolamento de rede
    local bucketId = nextBucketId
    nextBucketId = nextBucketId + 1
    
    -- Instancia o objeto Match usando a classe OOP
    local match = Match:new(bucketId, arena, p1Source, p2Source)
    
    -- Registra a partida no dicionário global
    activeMatches[bucketId] = match
    activeMatchesCount = activeMatchesCount + 1
    
    -- Inicia a partida (move jogadores, envia eventos)
    match:start()
    
    updateGlobalStats(Queue:count())
end

-----------------------------------------------------------------------------------------
-- INSTÂNCIA ÚNICA DO GERENCIADOR DE FILA (SINGLETON PATTERN)
-----------------------------------------------------------------------------------------

Queue = QueueManager:new(onMatchReady)

-----------------------------------------------------------------------------------------
-- COMANDO: TOGGLE DE FILA PVP
-----------------------------------------------------------------------------------------

RegisterCommand(Config.Command, function(source, args)
    if source == 0 then return end
    local src = source

    -- Validação: Garantir que o jogador não esteja em combate ativo
    for bucketId, match in pairs(activeMatches) do
        if match:hasPlayer(src) then
            notify(src, "~r~ERRO: ~w~Você já está em combate!")
            return
        end
    end

    -- Toggle usando método da classe
    local nowInQueue = Queue:toggle(src)
    
    if nowInQueue then
        notify(src, Config.Locales['in_queue'])
        TriggerClientEvent('pfl:pvp:syncQueueState', src, true)
    else
        notify(src, Config.Locales['left_queue'])
        TriggerClientEvent('pfl:pvp:syncQueueState', src, false)
    end

    updateGlobalStats(Queue:count())
end)

-----------------------------------------------------------------------------------------
-- THREAD: MATCHMAKING AUTOMÁTICO
-----------------------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(2000)
        
        -- Tenta formar pares automaticamente
        if Queue:tryMatchPair() then
            updateGlobalStats(Queue:count())
        end
    end
end)

-----------------------------------------------------------------------------------------
-- HANDLER: RELATÓRIO DE MORTE (ROUND RESOLUTION)
-----------------------------------------------------------------------------------------

RegisterNetEvent('pfl:pvp:reportDeath')
AddEventHandler('pfl:pvp:reportDeath', function()
    local src = source
    local bucketId = GetPlayerRoutingBucket(src)
    local match = activeMatches[bucketId]

    -- Verificação de segurança: jogador deve pertencer à partida
    if not match or not match:hasPlayer(src) then
        return
    end

    -- Processa a morte e verifica se a partida acabou
    local matchEnded = match:reportDeath(src)
    
    if matchEnded then
        -- Remove partida do registro
        activeMatches[bucketId] = nil
        activeMatchesCount = math.max(0, activeMatchesCount - 1)
        updateGlobalStats(Queue:count())
    end
end)

-----------------------------------------------------------------------------------------
-- HANDLER: DESCONEXÃO DE JOGADOR
-----------------------------------------------------------------------------------------

AddEventHandler('playerDropped', function()
    local src = source
    
    -- Remove da fila se estiver
    Queue:remove(src)

    -- Verifica se estava em uma partida ativa
    for bucketId, match in pairs(activeMatches) do
        if match:hasPlayer(src) then
            -- Trata a desconexão usando método da classe
            match:handleDisconnect(src)
            
            -- Limpa registro
            activeMatches[bucketId] = nil
            activeMatchesCount = math.max(0, activeMatchesCount - 1)
            break
        end
    end

    updateGlobalStats(Queue:count())
end)
