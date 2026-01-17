--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                      CLASSE QUEUE MANAGER (OOP)                           ║
    ║    Gerencia a fila de jogadores e matchmaking automático                  ║
    ║    Autor: Caio William Oliveira Faria                                     ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
]]

---@class QueueManager : table
---@field queue table Lista de sources na fila
---@field onMatchReady function Callback quando um par é encontrado
QueueManager = {}
QueueManager.__index = QueueManager

--[[
    Instancia um novo gerenciador de fila
    @param onMatchReady function - Callback(p1Source, p2Source) chamado quando existem 2 jogadores
    @return QueueManager
]]
function QueueManager:new(onMatchReady)
    local instance = setmetatable({}, QueueManager)
    instance.queue = {}
    instance.onMatchReady = onMatchReady or function() end
    return instance
end

--[[
    Adiciona um jogador à fila
    @param source number
    @return boolean - True se adicionado, False se já estava na fila
]]
function QueueManager:add(source)
    if self:contains(source) then
        return false
    end
    
    table.insert(self.queue, source)
    print(('[PvP Queue] Jogador %s entrou na fila. Total: %d'):format(
        GetPlayerName(source) or source, #self.queue
    ))
    return true
end

--[[
    Remove um jogador da fila
    @param source number
    @return boolean - True se removido, False se não estava
]]
function QueueManager:remove(source)
    for i, pSrc in ipairs(self.queue) do
        if pSrc == source then
            table.remove(self.queue, i)
            print(('[PvP Queue] Jogador %s saiu da fila. Total: %d'):format(
                GetPlayerName(source) or source, #self.queue
            ))
            return true
        end
    end
    return false
end

--[[
    Alterna o status do jogador na fila (toggle)
    @param source number
    @return boolean - True se agora está na fila, False se saiu
]]
function QueueManager:toggle(source)
    if self:remove(source) then
        return false
    else
        self:add(source)
        return true
    end
end

--[[
    Verifica se o jogador está na fila
    @param source number
    @return boolean
]]
function QueueManager:contains(source)
    for _, pSrc in ipairs(self.queue) do
        if pSrc == source then
            return true
        end
    end
    return false
end

--[[
    Retorna o número de jogadores na fila
    @return number
]]
function QueueManager:count()
    return #self.queue
end

--[[
    Tenta formar pares e disparar callbacks
    Chamado periodicamente pelo loop de matchmaking
    @return boolean - True se um par foi formado
]]
function QueueManager:tryMatchPair()
    if #self.queue < 2 then
        return false
    end
    
    local p1 = self.queue[1]
    local p2 = self.queue[2]
    
    -- Valida que ambos jogadores ainda estão conectados
    if not GetPlayerName(p1) then
        table.remove(self.queue, 1)
        return false
    end
    
    if not GetPlayerName(p2) then
        table.remove(self.queue, 2)
        return false
    end
    
    -- Remove ambos da fila e chama callback
    table.remove(self.queue, 1)
    table.remove(self.queue, 1) -- O índice do p2 agora é 1
    
    print(('[PvP Queue] Par formado: %s vs %s'):format(
        GetPlayerName(p1) or p1, 
        GetPlayerName(p2) or p2
    ))
    
    self.onMatchReady(p1, p2)
    return true
end

--[[
    Limpa jogadores desconectados da fila
]]
function QueueManager:cleanup()
    for i = #self.queue, 1, -1 do
        if not GetPlayerName(self.queue[i]) then
            table.remove(self.queue, i)
        end
    end
end

--[[
    Representação string para debug
    @return string
]]
function QueueManager:__tostring()
    return string.format("QueueManager[%d players]", #self.queue)
end

-- Classe QueueManager exportada globalmente para uso via fxmanifest
