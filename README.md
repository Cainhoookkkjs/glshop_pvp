# 🎮 PvP System Challenge (Standalone)

Sistema de fila e gerenciamento de partidas PvP 1v1 desenvolvido para o desafio técnico da **PLF PVP**. Este recurso foi projetado com foco em **performance**, **isolamento** e **experiência do usuário**, seguindo padrões de desenvolvimento Senior.

## 🚀 Funcionamento da Fila

O sistema utiliza uma abordagem de **Matchmaking Reativo**:
1. O jogador entra na fila utilizando o comando configurado (`/pvp`).
2. Uma thread do servidor monitora a fila em intervalos otimizados.
3. Assim que dois jogadores válidos são encontrados, uma partida é instanciada e ambos são removidos da fila.
4. O sistema valida se os jogadores ainda estão online antes de iniciar o teleporte, garantindo que a fila nunca trave por desconexões.

## ⚔️ Gerenciamento das Partidas (Melhor de 3)

As partidas são tratadas como objetos independentes no servidor:
- **Isolamento via Routing Buckets**: Cada partida ocorre em um `RoutingBucket` exclusivo. Isso garante isolamento total entre diferentes duelos simultâneos.
- **Formato de Competição**: Implementado sistema de "Melhor de 3". O primeiro jogador a atingir 2 vitórias é declarado o vencedor final.
- **Restauração de Estado**: O sistema armazena as coordenadas originais e o bucket de origem. Ao finalizar, o jogador é restaurado com vida cheia (200), colete removido, armas do PvP retiradas e posicionado exatamente onde estava antes do duelo.
- **Sistema Anti-Fuga**: Caso um jogador tente sair dos limites da arena durante o combate, ele é automaticamente teleportado de volta para o seu ponto de spawn inicial com um efeito visual de fade, garantindo que a luta continue de forma justa.
- **UX Dinâmica**: Markers de spawn visualmente intuitivos (Verde/Vermelho) aparecem apenas durante o countdown para orientar o posicionamento inicial, desaparecendo assim que o combate começa para garantir um campo de visão limpo.

## 🛠️ Decisões Técnicas Principais

### 1. GlobalState & State Bags
Utilização de `GlobalState` para sincronização do HUD (contagem de fila/partidas). Isso reduz o overhead de rede, pois o cliente acessa os dados de forma síncrona sem necessidade de disparar eventos constantes.

### 2. Otimização de Threads
O loop de renderização da UI possui timers dinâmicos, garantindo que o recurso consuma 0.00ms de CPU quando o jogador não está interagindo com o sistema PvP.

### 3. Segurança Standalone
Desenvolvido sem dependências de frameworks externos (vRP/ESX/QB), utilizando nativas puras para garantir compatibilidade universal. A lógica de morte e renascimento foi blindada no servidor para evitar manipulações via executores.

## 📸 Demonstração do Sistema

Abaixo, os principais componentes visuais e de interface do recurso:

| ![Início da Partida](https://media.discordapp.net/attachments/1461861209526632448/1461861562800279684/market.png?ex=696c182c&is=696ac6ac&hm=738471c28e93a8914aa923be58262bebd2fc047b9a634efebd993168db844ef8&=&format=webp&quality=lossless) | ![Interface de Combate](https://media.discordapp.net/attachments/1461861209526632448/1461861890765619250/PLACAR.png?ex=696c187a&is=696ac6fa&hm=5f1a64edf7d8b8599554424c45ec17be485c335853ac38d8736f0e0a748ac139&=&format=webp&quality=lossless) |
| :---: | :---: |
| **Preparação e Spawns**: Visualização de markers (verde/vermelho) e efeitos de fade no countdown inicial. | **HUD de Combate**: Placar em tempo real, status de vida e contador de partidas ativas via GlobalState. |

### Detalhes de UX e Sincronização
<details>
  <summary>Clique para expandir a galeria completa</summary>

#### ⏳ Gerenciamento de Fila
![Fila PvP](https://media.discordapp.net/attachments/1461861209526632448/1461861238857404446/FILAPVP.png?ex=696c17df&is=696ac65f&hm=ae56a1befcc913f38c8c80be5e14dc5cac2946dad44eb07861d3a3522d9d35cf&=&format=webp&quality=lossless)
*Contador minimalista e sincronização simultânea para múltiplos jogadores na fila.*

#### 🛡️ Sistema Anti-Fuga e Alertas
![Aviso de Limites](https://media.discordapp.net/attachments/1461861209526632448/1461862129702535354/Screenshot_1.png?ex=696c18b3&is=696ac733&hm=997dc3e0b7a335729e53e468f33617be2abc4b35c3d682dc66889d18c0b45bff&=&format=webp&quality=lossless)
*Feedback visual e sonoro imediato caso o jogador tente sair do perímetro delimitado da arena.*

#### 🏆 Resultados e Transições
![Vitória Final](https://media.discordapp.net/attachments/1461861209526632448/1461861495620239525/Final.png?ex=696c181c&is=696ac69c&hm=f304c012d1541623f59d7939ae3100b00890c6e3e60ff8ed268ed776b330b6cf&=&format=webp&quality=lossless)
*Anúncios dinâmicos de round vencido/perdido e finalização da Melhor de 3 com restauração de estado.*

</details>
````

---
**Desenvolvido por:** Caio William Oliveira Faria.
**Status:** Concluído com 100% dos requisitos atingidos e melhorias extras de UX.
