--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                          CLASSE MATCH (OOP)                               ║
    ║    Encapsula toda a lógica de uma partida PvP individual                  ║
    ║    Autor: Caio William Oliveira Faria                                     ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
]]

---@class Match : table
---@field id number Identificador único da partida (bucket ID)
---@field arena table Configuração da arena selecionada
---@field score table Placar { p1: number, p2: number }
---@field players table Dados dos jogadores [1] e [2]
---@field isActive boolean Estado da partida
Match = {}
Match.__index = Match

--[[
    Instancia um novo objeto Match
    @param bucketId number - ID do routing bucket (serve como ID da partida)
    @param arena table - Configuração da arena
    @param player1Source number - Source do jogador 1
    @param player2Source number - Source do jogador 2
    @return Match
]]
function Match:new(bucketId, arena, player1Source, player2Source)
    local instance = setmetatable({}, Match)
    
    instance.id = bucketId
    instance.arena = arena
    instance.isActive = true
    instance.score = { p1 = 0, p2 = 0 }
    instance.roundsToWin = 2 -- Forçado: Melhor de 3 (primeiro a 2 vitórias)
    
    print(('[PvP] Match #%d criada - RoundsToWin: %d'):format(bucketId, instance.roundsToWin))
    
    -- Captura estado original dos jogadores para restauração posterior
    instance.players = {
        [1] = {
            source = player1Source,
            originalPos = GetEntityCoords(GetPlayerPed(player1Source)),
            originalBucket = GetPlayerRoutingBucket(player1Source)
        },
        [2] = {
            source = player2Source,
            originalPos = GetEntityCoords(GetPlayerPed(player2Source)),
            originalBucket = GetPlayerRoutingBucket(player2Source)
        }
    }
    
    return instance
end

--[[
    Retorna o jogador pelo índice
    @param index number - 1 ou 2
    @return table|nil
]]
function Match:getPlayer(index)
    return self.players[index]
end

--[[
    Encontra o índice do jogador pelo source
    @param source number
    @return number|nil - Índice (1 ou 2) ou nil se não encontrado
]]
function Match:getPlayerIndex(source)
    if self.players[1].source == source then
        return 1
    elseif self.players[2].source == source then
        return 2
    end
    return nil
end

--[[
    Verifica se um jogador pertence a esta partida
    @param source number
    @return boolean
]]
function Match:hasPlayer(source)
    return self:getPlayerIndex(source) ~= nil
end

--[[
    Inicializa a partida: Move jogadores para o bucket isolado e notifica clientes
]]
function Match:start()
    local p1 = self.players[1].source
    local p2 = self.players[2].source
    
    -- Isola jogadores em um routing bucket único
    SetPlayerRoutingBucket(p1, self.id)
    SetPlayerRoutingBucket(p2, self.id)
    
    -- Dispara evento de início para cada cliente
    TriggerClientEvent('pfl:pvp:startMatch', p1, self.arena, self.id, 1)
    TriggerClientEvent('pfl:pvp:startMatch', p2, self.arena, self.id, 2)
    
    print(('[PvP] Match #%d iniciada: %s vs %s na arena "%s"'):format(
        self.id, 
        GetPlayerName(p1) or p1, 
        GetPlayerName(p2) or p2, 
        self.arena.name
    ))
end

--[[
    Registra a morte de um jogador e processa o resultado do round
    @param deadPlayerSource number - Source do jogador que morreu
    @return boolean - True se a partida acabou, False se continua
]]
function Match:reportDeath(deadPlayerSource)
    if not self.isActive then return false end
    
    -- PROTEÇÃO: Evita múltiplos reports no mesmo round
    if self.roundProcessing then 
        print(('[PvP] Match #%d: Morte ignorada (round já processando)'):format(self.id))
        return false 
    end
    
    local loserIdx = self:getPlayerIndex(deadPlayerSource)
    if not loserIdx then 
        return false 
    end
    
    -- VERIFICAÇÃO EXTRA: Confirma que o jogador realmente está morto
    local ped = GetPlayerPed(deadPlayerSource)
    if ped and GetEntityHealth(ped) > 0 and not IsEntityDead(ped) then
        print(('[PvP] Match #%d: Morte rejeitada (jogador %s ainda tem vida: %d)'):format(
            self.id, deadPlayerSource, GetEntityHealth(ped)
        ))
        return false
    end
    
    -- AGORA SIM: Marca como processando APÓS todas as validações
    self.roundProcessing = true
    
    local winnerIdx = (loserIdx == 1) and 2 or 1
    local winnerKey = (winnerIdx == 1) and "p1" or "p2"
    
    self.score[winnerKey] = self.score[winnerKey] + 1
    
    local p1 = self.players[1].source
    local p2 = self.players[2].source
    local winnerSrc = self.players[winnerIdx].source
    local loserSrc = deadPlayerSource
    
    print(('[PvP] Match #%d: Round finalizado! Placar: %d - %d (precisa de %d para vencer)'):format(
        self.id, self.score.p1, self.score.p2, self.roundsToWin
    ))
    
    -- Sincroniza placar com ambos os clientes
    TriggerClientEvent('pfl:pvp:updateScore', p1, self.score.p1, self.score.p2)
    TriggerClientEvent('pfl:pvp:updateScore', p2, self.score.p2, self.score.p1)
    
    -- Verifica condição de vitória (melhor de 3 = primeiro a 2)
    if self.score[winnerKey] >= self.roundsToWin then
        self:finish(winnerSrc, loserSrc)
        return true
    else
        self:prepareNextRound(winnerSrc, loserSrc)
        return false
    end
end

--[[
    Prepara o próximo round após uma morte
    @param winnerSrc number - Source do vencedor do round
    @param loserSrc number - Source do perdedor do round
]]
function Match:prepareNextRound(winnerSrc, loserSrc)
    -- Notifica jogadores sobre o resultado do round
    self:notify(winnerSrc, "~g~ROUND VENCIDO! ~w~Preparando próximo...")
    self:notify(loserSrc, "~r~ROUND PERDIDO! ~w~Prepare-se para renascer...")
    
    -- Delay para respawn
    local matchRef = self -- Captura referência para closure
    SetTimeout(3000, function()
        if matchRef.isActive then
            matchRef.roundProcessing = false -- RESET: Permite novo report de morte
            TriggerClientEvent('pfl:pvp:nextRound', matchRef.players[1].source, 1)
            TriggerClientEvent('pfl:pvp:nextRound', matchRef.players[2].source, 2)
        end
    end)
end

--[[
    Finaliza a partida e restaura jogadores para suas posições originais
    @param winnerSrc number
    @param loserSrc number
]]
function Match:finish(winnerSrc, loserSrc)
    self.isActive = false
    
    -- Notifica resultado final
    self:notify(winnerSrc, Config.Locales['match_ended_won'])
    self:notify(loserSrc, Config.Locales['match_ended_lost'])
    
    local p1 = self.players[1]
    local p2 = self.players[2]
    
    -- Envia evento de finalização com coordenadas originais
    TriggerClientEvent('pfl:pvp:finishMatch', p1.source, p1.originalPos)
    TriggerClientEvent('pfl:pvp:finishMatch', p2.source, p2.originalPos)
    
    -- Restaura routing buckets após um delay para a animação
    local defaultBucket = Config.DefaultBucket or 0
    SetTimeout(1500, function()
        if GetPlayerName(p1.source) then 
            SetPlayerRoutingBucket(p1.source, p1.originalBucket or defaultBucket) 
        end
        if GetPlayerName(p2.source) then 
            SetPlayerRoutingBucket(p2.source, p2.originalBucket or defaultBucket) 
        end
    end)
    
    print(('[PvP] Match #%d finalizada. Placar final: %d - %d'):format(
        self.id, self.score.p1, self.score.p2
    ))
end

--[[
    Encerra a partida devido a desconexão de um jogador
    @param disconnectedSource number - Source do jogador que desconectou
]]
function Match:handleDisconnect(disconnectedSource)
    self.isActive = false
    
    local remainingIdx = (self.players[1].source == disconnectedSource) and 2 or 1
    local remaining = self.players[remainingIdx]
    
    if GetPlayerName(remaining.source) then
        self:notify(remaining.source, "~r~OPONENTE DESCONECTOU! ~w~Você venceu a partida.")
        TriggerClientEvent('pfl:pvp:finishMatch', remaining.source, remaining.originalPos)
        SetPlayerRoutingBucket(remaining.source, remaining.originalBucket or Config.DefaultBucket or 0)
    end
    
    print(('[PvP] Match #%d encerrada por desconexão'):format(self.id))
end

--[[
    Utilitário interno para enviar notificações
    @param source number
    @param message string
]]
function Match:notify(source, message)
    TriggerClientEvent('pfl:pvp:notify', source, message)
end

--[[
    Retorna representação string do objeto (para debug)
    @return string
]]
function Match:__tostring()
    return string.format("Match[#%d] - %s vs %s | Score: %d-%d | Active: %s",
        self.id,
        GetPlayerName(self.players[1].source) or "?",
        GetPlayerName(self.players[2].source) or "?",
        self.score.p1, self.score.p2,
        tostring(self.isActive)
    )
end

-- Classe Match exportada globalmente para uso via fxmanifest
