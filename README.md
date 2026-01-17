# 🎮 PvP System Challenge (Standalone)

Sistema de fila e gerenciamento de partidas PvP 1v1 desenvolvido para o desafio técnico da **PLF PVP**. Projetado com foco em **performance**, **isolamento**, **OOP** e **experiência do usuário**.

## 🏗️ Arquitetura OOP (v2.0)

Sistema refatorado utilizando **Programação Orientada a Objetos** em Lua com metatables:

```
glshop_pvp/
├── shared/config.lua           # Configurações
├── client/main.lua             # Lógica client-side
└── server/
    ├── classes/
    │   ├── Match.lua           # 📦 Classe OOP - Partida
    │   └── QueueManager.lua    # 📦 Classe OOP - Fila
    └── main.lua                # Orquestrador
```

### 📦 Classes OOP

| Classe | Métodos Principais |
|--------|-------------------|
| **Match** | `:new()`, `:start()`, `:reportDeath()`, `:prepareNextRound()`, `:finish()`, `:handleDisconnect()` |
| **QueueManager** | `:new()`, `:add()`, `:remove()`, `:toggle()`, `:tryMatchPair()` |

### 🎯 Padrões Aplicados
- Metatables com `__index`
- Singleton Pattern
- Dependency Injection
- Documentação LuaDoc

---

## ⚔️ Sistema Melhor de 3

- **Formato:** Primeiro a 2 vitórias
- **Contagem Regressiva:** 5, 4, 3, 2, 1 em CADA round
- **Proteção contra duplicatas:** Cooldown de 5s entre mortes + flag `roundProcessing`
- **Scaleform dinâmico:** "ROUND 1", "ROUND 2", etc.

## 🛡️ Recursos Técnicos

| Recurso | Descrição |
|---------|-----------|
| **Routing Buckets** | Isolamento total entre partidas |
| **GlobalState** | Sincronização eficiente do HUD |
| **Export `InPvPMatch()`** | Integração com survival |
| **Anti-Fuga** | Teleporta jogador de volta à arena |
| **Friendly Fire** | Habilitado automaticamente na partida |

## 🔧 Integração com Survival

O sistema exporta uma função para desabilitar o survival durante PvP:

```lua
-- No seu script de survival:
if exports.glshop_pvp:InPvPMatch() then
    return -- Ignora nocaute
end
```

---

**Desenvolvido por:** Caio William Oliveira Faria  
**Versão:** 2.0.0 (OOP + Melhor de 3)
