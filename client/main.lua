-----------------------------------------------------------------------------------------
-- ESTADO INTERNO (CLIENT)
-----------------------------------------------------------------------------------------

local inMatch = false
local currentArena = nil
local countdownActive = false
local inQueue = false
local myScore, opponentScore = 0, 0
local deadReported = false -- Evita o disparo de múltiplos eventos
local myPlayerNum = 0 -- Índice do jogador na partida (1 ou 2)
local lastDeathReport = 0 -- Timestamp do último report de morte (cooldown)

-- EXPORT: Permite outros scripts (como survival) verificarem se está em PvP
exports('InPvPMatch', function() return inMatch end)

local queueCount = GlobalState.PvPQueueCount or 0
local activeMatchesCount = GlobalState.PvPActiveMatches or 0

-- Atualizações reativas do HUD via State Bags
AddStateBagChangeHandler('PvPQueueCount', 'global', function(_, _, value) queueCount = value end)
AddStateBagChangeHandler('PvPActiveMatches', 'global', function(_, _, value) activeMatchesCount = value end)

-----------------------------------------------------------------------------------------
-- UTILITÁRIOS CORE
-----------------------------------------------------------------------------------------

local function ShowScaleform(title, msg, sec)
    local scaleform = RequestScaleformMovie("MP_BIG_MESSAGE_FREEMODE")
    while not HasScaleformMovieLoaded(scaleform) do Wait(0) end
    
    BeginScaleformMovieMethod(scaleform, "SHOW_SHARD_CENTERED_MP_MESSAGE")
    PushScaleformMovieMethodParameterString(title)
    PushScaleformMovieMethodParameterString(msg)
    EndScaleformMovieMethod()

    local endTimer = GetGameTimer() + (sec * 1000)
    while GetGameTimer() < endTimer do
        Wait(0)
        DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255)
    end
end

local function setupPlayerPvP(arena, playerNum, isNewRound)
    local ped = PlayerPedId()
    local spawn = (playerNum == 1) and arena.spawn1 or arena.spawn2
    
    if not isNewRound then
        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do Wait(10) end
    end

    -- Lógica de Teleporte e Ressurreição
    if IsEntityDead(ped) then
        NetworkResurrectLocalPlayer(spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    else
        SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, true)
        SetEntityHeading(ped, spawn.w)
    end
    
    FreezeEntityPosition(ped, true)
    
    -- Reset de Estado (Vida reduzida para combate mais letal)
    SetEntityMaxHealth(ped, 200)
    SetEntityHealth(ped, 150) -- Vida reduzida (50 de vida real)
    SetPedArmour(ped, 0) -- Sem colete para morrer mais rápido
    
    -- Remove modificadores de dano que possam atrapalhar
    SetPlayerWeaponDamageModifier(PlayerId(), 2.0) -- Dobra o dano causado
    SetPlayerMeleeWeaponDamageModifier(PlayerId(), 2.0)
    
    GiveWeaponToPed(ped, GetHashKey(Config.Weapon), Config.Ammo, false, true)

    if not isNewRound then DoScreenFadeIn(1000) end

    -- Contagem Regressiva Interativa
    countdownActive = true
    local timer = Config.CountdownTime
    while timer > 0 do
        countdownActive = timer
        PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
        Wait(1000)
        timer = timer - 1
    end
    countdownActive = false

    FreezeEntityPosition(ped, false)
    PlaySoundFrontend(-1, "Challenge_Can_Start", "HUD_AWARDS", 1)
end

-----------------------------------------------------------------------------------------
-- PROTOCOLOS DE REDE (NETWORK)
-----------------------------------------------------------------------------------------

RegisterNetEvent('pfl:pvp:syncQueueState', function(state) inQueue = state end)

RegisterNetEvent('pfl:pvp:notify', function(msg) 
    SetNotificationTextEntry("STRING")
    AddTextComponentString(msg)
    DrawNotification(false, false)
end)

RegisterNetEvent('pfl:pvp:updateScore', function(p1, p2)
    myScore, opponentScore = p1, p2
end)

RegisterNetEvent('pfl:pvp:startMatch', function(arena, bucket, playerNum)
    inQueue = false
    inMatch = true
    deadReported = false -- Reset state
    myPlayerNum = playerNum -- Armazena o índice
    currentArena = arena
    myScore, opponentScore = 0, 0
    
    -- HABILITAR PVP: Permite dano entre jogadores
    NetworkSetFriendlyFireOption(true)
    SetCanAttackFriendly(PlayerPedId(), true, true)
    SetEntityInvincible(PlayerPedId(), false)
    LocalPlayer.state.Invincible = false
    
    SetTimecycleModifier("MP_match_start")
    SetTimecycleModifierStrength(0.8)

    setupPlayerPvP(arena, playerNum, false)
    
    CreateThread(function()
        ShowScaleform("~g~LUTE!", "Melhor de 3 - Prepare-se!", 2)
    end)
end)

RegisterNetEvent('pfl:pvp:nextRound', function(playerNum)
    deadReported = false -- Reset state for new round
    myPlayerNum = playerNum
    
    DoScreenFadeOut(500)
    Wait(600)
    
    -- Configura jogador para o novo round (com contagem regressiva)
    setupPlayerPvP(currentArena, playerNum, false) -- false = faz a contagem regressiva
    
    DoScreenFadeIn(1000)
    
    -- Exibe mensagem de round
    CreateThread(function()
        local roundNum = myScore + opponentScore + 1
        ShowScaleform("~y~ROUND " .. roundNum, "LUTE!", 2)
    end)
end)

RegisterNetEvent('pfl:pvp:finishMatch', function(originalPos)
    local ped = PlayerPedId()
    local won = GetEntityHealth(ped) > 0
    
    ShowScaleform(won and "~g~VITÓRIA" or "~r~DERROTA", won and "Você venceu a partida!" or "Dessa vez não deu!", 3)

    DoScreenFadeOut(800)
    Wait(1000)

    -- Limpeza e Restituição Total
    if IsEntityDead(ped) then
        NetworkResurrectLocalPlayer(originalPos.x, originalPos.y, originalPos.z, 0.0, true, false)
    else
        SetEntityCoords(ped, originalPos.x, originalPos.y, originalPos.z, false, false, false, true)
    end

    FreezeEntityPosition(ped, false)
    RemoveAllPedWeapons(ped, true)
    SetEntityHealth(ped, 200)
    SetPedArmour(ped, 0)
    
    inMatch = false
    currentArena = nil
    ClearTimecycleModifier()
    
    DoScreenFadeIn(1000)
end)

-----------------------------------------------------------------------------------------
-- THREADS OTIMIZADAS
-----------------------------------------------------------------------------------------

-- Loop de Renderização da UI
CreateThread(function()
    while true do
        local sleep = 500
        
        if inQueue and not inMatch then
            sleep = 0
            drawNativeHUD(0.83, 0.05, "FILA PVP", queueCount, {r = 0, g = 150, b = 255})
        end
        
        if activeMatchesCount > 0 or inMatch then
            sleep = 0
            drawNativeHUD(0.83, 0.09, "PARTIDAS", activeMatchesCount, {r = 255, g = 150, b = 0})
        end

        if inMatch and currentArena then
            sleep = 0
            local ped = PlayerPedId()
            if countdownActive then drawTxt(0.5, 0.4, 1.2, tostring(countdownActive)) end
            
            -- Visualização de Limite de Raio da Arena
            local center = (vector3(currentArena.spawn1.x, currentArena.spawn1.y, currentArena.spawn1.z) + vector3(currentArena.spawn2.x, currentArena.spawn2.y, currentArena.spawn2.z)) / 2
            local dist = #(GetEntityCoords(ped) - center)
            if dist > currentArena.radius then
                drawTxt(0.5, 0.8, 0.6, Config.Locales['out_of_bounds'])
            end

            -- Visualização dos Spawns (Apenas durante a contagem regressiva para organizar o início)
            if countdownActive then
                DrawMarker(1, currentArena.spawn1.x, currentArena.spawn1.y, currentArena.spawn1.z - 1.0, 0, 0, 0, 0, 0, 0, 2.0, 2.0, 1.0, 0, 255, 0, 100, false, false, 2, false, nil, nil, false)
                DrawMarker(1, currentArena.spawn2.x, currentArena.spawn2.y, currentArena.spawn2.z - 1.0, 0, 0, 0, 0, 0, 0, 2.0, 2.0, 1.0, 255, 0, 0, 100, false, false, 2, false, nil, nil, false)
            end

            -- HUD da Partida
            drawNativeHUD(0.83, 0.13, "SUA VIDA", math.max(0, GetEntityHealth(ped)-100), {r = 200, g = 0, b = 0})
            drawNativeHUD(0.83, 0.17, "PLACAR", string.format("%d - %d", myScore, opponentScore), {r = 255, g = 255, b = 255})
        end

        Wait(sleep)
    end
end)

-- Thread Principal de Lógica: Lida com detecção de morte e limites da arena
CreateThread(function()
    while true do
        local sleep = 1000
        if inMatch then
            sleep = 100 -- Verificação mais rápida durante a luta
            local ped = PlayerPedId()
            local health = GetEntityHealth(ped)
            
            -- Detecção Robusta de Morte com COOLDOWN
            local currentTime = GetGameTimer()
            local cooldownActive = (currentTime - lastDeathReport) < 5000 -- 5 segundos de cooldown
            
            if IsEntityDead(ped) and not deadReported and not cooldownActive then
                deadReported = true
                lastDeathReport = currentTime
                print(('[PvP Client] Morte detectada! Cooldown ativo por 5s. Timer: %d'):format(currentTime))
                TriggerServerEvent('pfl:pvp:reportDeath')
            end

            -- Lógica de Anti-Fuga: Teleporta de volta em vez de matar
            if currentArena and not deadReported then
                local center = (vector3(currentArena.spawn1.x, currentArena.spawn1.y, currentArena.spawn1.z) + vector3(currentArena.spawn2.x, currentArena.spawn2.y, currentArena.spawn2.z)) / 2
                if #(GetEntityCoords(ped) - center) > currentArena.radius + 5.0 then
                    local spawn = (myPlayerNum == 1) and currentArena.spawn1 or currentArena.spawn2
                    
                    DoScreenFadeOut(200)
                    while not IsScreenFadedOut() do Wait(10) end
                    
                    SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, true)
                    SetEntityHeading(ped, spawn.w)
                    PlaySoundFrontend(-1, "CHECKPOINT_MISSED", "HUD_MINI_GAME_SOUNDSET", 1)
                    
                    Wait(300)
                    DoScreenFadeIn(400)
                end
            end
        end
        Wait(sleep)
    end
end)

-----------------------------------------------------------------------------------------
-- MOTOR DE DESENHO NATIVO (DRAWING)
-----------------------------------------------------------------------------------------

function drawNativeHUD(x, y, label, value, color)
    local width, height = 0.15, 0.028
    DrawRect(x + width/2, y + height/2, width, height, 0, 0, 0, 180)
    DrawRect(x, y + height/2, 0.003, height, color.r, color.g, color.b, 255)
    
    local function renderText(txt, offX, col)
        SetTextFont(4)
        SetTextScale(0.3, 0.3)
        SetTextColour(col.r, col.g, col.b, 255)
        if offX > 0 then 
            SetTextRightJustify(true) 
            SetTextWrap(0.0, x + width - 0.005) 
        end
        SetTextEntry("STRING")
        AddTextComponentString(tostring(txt))
        DrawText(x + 0.005, y + 0.003)
    end

    renderText(label, 0, {r=255, g=255, b=255})
    renderText(value, 0.1, color)
end

function drawTxt(x, y, scale, text)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextOutline()
    SetTextCentre(true)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end
