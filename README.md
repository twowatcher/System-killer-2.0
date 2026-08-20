# System-killer-2.0

Você já deve ter ouvido falar em algum jogo assimétrico do Roblox, né?

Se você quer criar um jogo assimétrico no Roblox e não sabe por onde começar, **RELAXA!** Este guia te mostra o passo a passo de como montar a base do sistema — sem precisar reinventar a roda.

## O que é um jogo assimétrico?

É um modo de jogo onde os jogadores são divididos em papéis diferentes e desbalanceados de propósito — geralmente **1 Killer contra vários Survivors** (tipo Dead by Daylight, Forsaken, etc). Um jogador caça, os outros fogem e tentam sobreviver até o tempo acabar.

Esse projeto já traz pronta a lógica de:
- Intermission (espera entre rodadas)
- Sorteio do Killer (com sistema de chance que aumenta pra quem não é sorteado)
- Troca automática de personagem (modelo de Killer / modelo de Survivor)
- Teleporte pros spawns corretos
- Detecção de morte e condição de vitória
- Timer sincronizado com o cliente

## Pré-requisitos

- Roblox Studio instalado
- Conhecimento básico de Explorer (criar Folders, Models, Parts)
- Não precisa saber programar pra montar a estrutura — só pra mexer nas configurações do script

## Passo a passo

### 1. Estrutura de pastas no `ServerStorage`

Crie a seguinte hierarquia dentro do `ServerStorage`:

```
ServerStorage
└── Personagens
    ├── Sobreviventes
    │   ├── (Model do personagem 1)
    │   ├── (Model do personagem 2)
    │   └── ...
    └── Assassinos
        ├── (Model do killer 1)
        └── ...
```

Cada **Model** precisa ter dentro dele:
- Um `Humanoid`
- Uma `HumanoidRootPart` (parte principal do corpo)

Sem esses dois, o sistema não consegue transformar o jogador nesse personagem.

Você pode colocar quantos modelos quiser em cada pasta — o sistema escolhe um aleatoriamente pra cada jogador a cada rodada.

### 2. Estrutura de spawns no `Workspace`

Crie a seguinte hierarquia dentro do `Workspace`:

```
Workspace
└── Spawns
    ├── Survivors        (ou "Sobreviventes")
    │   └── (Parts onde os survivors vão aparecer)
    ├── Killer            (ou "Assassino")
    │   └── (Parts onde o killer vai aparecer)
    └── Lobby             (opcional — pra onde os jogadores voltam depois da rodada)
        └── (Parts do lobby)
```

Dentro de cada pasta, coloque uma ou mais `Part` (podem ser invisíveis, tipo `SpawnLocation` sem colisão). O sistema escolhe uma aleatoriamente e teleporta o jogador pra cima dela.

### 3. RemoteEvents

O sistema cria os `RemoteEvent`s automaticamente dentro do `ReplicatedStorage` na primeira vez que roda, então você não precisa criar nenhum manualmente. Os nomes usados são:

- `RoundTimer` — manda o tempo restante pro cliente
- `AnunciarKiller` — avisa quem é o killer da rodada
- `MensagemFinal` — manda o resultado da rodada (quem ganhou)
- `RoundState` — manda o estado atual (Waiting, Intermission, Starting, Preparing, Playing, Ended)
- `RoundCountdown` — contagem regressiva antes de começar
- `RoundPlayerStatus` — status de cada jogador (Killer, Survivor, Dead, etc)

Se você for criar telas de interface (GUI), é nesses eventos que você vai conectar (`OnClientEvent`) pra atualizar o que aparece na tela.

### 4. Script principal

Coloque o script do sistema (fornecido separadamente) dentro de:

```
ServerScriptService
```

Ele precisa ser um **Script** normal (não LocalScript, não ModuleScript), porque roda no servidor.

### 5. Configurações

No topo do script tem algumas variáveis que você pode ajustar sem mexer no resto da lógica:

| Variável | O que faz |
|---|---|
| `MIN_PLAYERS` | Quantos jogadores mínimos pra rodada começar |
| `INTERMISSION` | Segundos de espera entre rodadas |
| `START_COUNTDOWN` | Contagem regressiva antes da rodada começar |
| `ROUND_TIME` | Duração máxima da rodada, em segundos |
| `RESULT_TIME` | Quanto tempo a tela de resultado fica visível |
| `USE_KILLER_CHANCE` | Se `true`, quem não é sorteado ganha mais chance na próxima vez |
| `KILLER_CHANCE_INCREMENT` | O quanto a chance aumenta por rodada não sorteada |

### 6. GUIs (opcional, mas recomendado)

Crie LocalScripts que escutem os RemoteEvents do passo 3 pra mostrar na tela:
- Timer da rodada
- Quem é o killer (só pro próprio killer, ou anúncio geral — sua escolha)
- Status de vida (vivo/morto)
- Mensagem de vitória/derrota no final

### 7. Testando

No Roblox Studio, use **Test > Clients and Servers** com pelo menos o número de `MIN_PLAYERS` configurado, pra simular uma rodada completa. Acompanhe o **Output** (View > Output) — o script imprime cada mudança de estado (`[KILLER] Estado: ...`), o que ajuda bastante a identificar em qual etapa algo travou, se travar.

## Problemas comuns

- **Aviso de spawn não encontrado**: confira se os nomes das pastas em `Workspace.Spawns` batem com o que o script espera (`Killer`/`Assassino`, `Survivors`/`Sobreviventes`, `Lobby`).
- **Personagem não troca**: confira se os Models em `ServerStorage.Personagens` têm `Humanoid` e `HumanoidRootPart`.
- **Rodada nunca começa**: confira se você tem jogadores suficientes conectados (`MIN_PLAYERS`) e se o script está mesmo dentro de `ServerScriptService`.

---

Qualquer dúvida, abre uma issue por aqui.
