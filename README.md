# Erebor Homelab — Single Source of Truth

> **Regra principal:** este ficheiro é a fonte única de verdade. Se não está aqui, oficialmente não existe.

Este documento substitui documentação antiga e passa a ser a referência única e atual para o servidor **erebor**. Objetivo: evitar informação dispersa, manter tudo coerente e permitir que qualquer mudança futura seja refletida aqui primeiro.

---

## Resumo rápido

* **Sistema**: Ubuntu Server 24.04.3 LTS com boot UEFI e LVM.
* **Dados críticos**: ZFS mirror 18TB + 18TB montado em `/mnt/critical` (estado saudável).
* **Storage auxiliar ativo**:

  * `/srv/docker-data` (SSD 250GB) para dados do Docker
  * `/mnt/media/movies` (HDD 4TB)
  * `/mnt/media/tv` (HDD 4TB)
  * `/srv/data/scratch` (HDD 320GB)
* **Rede**: gateway OPNSense `192.168.1.1`, Erebor em `192.168.1.6`.
* **Serviços ativos**: Docker, Minecraft, Glances, Tailscale, SABnzbd, Prowlarr.
* **Regra de ouro**: se não está neste ficheiro, oficialmente não existe.

---

## Índice

* [1) Visão geral](#1-visão-geral)
* [2) Hardware atual](#2-hardware-atual-fonte-de-verdade)
* [3) Princípios de arquitetura](#3-princípios-de-arquitetura)
* [4) Layout lógico de paths](#4-layout-lógico-de-paths-abstração-estável)
* [5) Docker](#5-docker)
* [6) Serviços atualmente ativos](#6-serviços-atualmente-ativos)
* [7) Estrutura planeada (media stack e Immich)](#7-estrutura-planeada-media-stack-e-immich)
* [8) Backups](#8-backups-estratégia-real-e-operacional)
* [9) Regra operacional](#9-regra-operacional)
* [10) Rede](#10-rede-fonte-de-verdade)
* [11) OPNSense, DNS e AdGuard](#11-opnsense-dns-e-adguard)
* [12) Home Assistant](#12-home-assistant)
* [13) Victron & MQTT Integration](#13-victron--mqtt-integration-infraestrutura-crítica)
* [14) Regra estrutural de documentação](#14-regra-estrutural-de-documentação)
* [15) Storage real e estado atual (ZFS)](#15-storage-real-e-estado-atual-zfs--fonte-de-verdade)
* [16) Storage não-ZFS (discos auxiliares)](#16-storage-não-zfs-discos-auxiliares)
* [17) Política de snapshots ZFS (implementada)](#17-política-de-snapshots-zfs-implementada)

---

## 1) Visão geral

| Item     | Valor                                                  |
| -------- | ------------------------------------------------------ |
| Hostname | erebor                                                 |
| OS       | Ubuntu Server 24.04.3 LTS                              |
| Boot     | UEFI com /boot e /boot/efi separados                   |
| LVM      | 100 GB root, ~362 GB livre                             |
| Updates  | unattended-upgrades ativo                              |
| Estado   | Sistema estável, Docker validado, pronto para expansão |

---

## 2) Hardware atual (fonte de verdade)

> Qualquer alteração física de discos deve ser refletida aqui.

| Disco                    | Função                                |
| ------------------------ | ------------------------------------- |
| SSD 500 GB (Samsung 860) | Sistema operativo (LVM + /boot + EFI) |
| SSD 250 GB (Samsung 750) | Docker internals (`/srv/docker-data`) |
| SSD 250 GB (Samsung 850) | Livre / reservado                     |
| HDD 320 GB (WD)          | Scratch (`/srv/data/scratch`)         |
| HDD 4 TB (WD)            | Media – Filmes (`/mnt/media/movies`)  |
| HDD 4 TB (WD)            | Media – Séries (`/mnt/media/tv`)      |
| ZFS mirror 18 + 18 TB    | Dados críticos (`/mnt/critical`)      |
| Bays livres              | 5 / 12                                |

Nota: O ZFS mirror encontra-se operacional e validado (ver secção 15).

---

## 3) Princípios de arquitetura

**Redundância onde importa**
Os dados críticos vivem em ZFS mirror para tolerância a falhas de disco.

**Isolamento de risco**
Dados recuperáveis (media, downloads, temporários) vivem em discos independentes.

**Separação de dados descartáveis**
Scratch, downloads, staging e dados temporários nunca se misturam com dados importantes.

**Containers são descartáveis**
O container pode morrer. Os dados persistentes sobrevivem sempre fora do Docker.

**Bind mounts sempre explícitos**
Nada de volumes anónimos difíceis de rastrear. Paths claros e legíveis.

**Nada crítico em `/var/lib/docker`**
O Docker pode ser apagado e reconstruído sem perda de dados importantes.

---

## 4) Layout lógico de paths (abstração estável)

> Estes paths são contratos estáveis. O disco físico por trás pode mudar sem afetar containers.

```
/srv/docker/              → configs persistentes de containers
/srv/docker/services/     → stacks organizados por função
/srv/docker-data/         → data-root do Docker
/srv/data/scratch/         → temporários, downloads, staging
/mnt/media/movies          → filmes
/mnt/media/tv              → séries
/mnt/critical              → dados críticos (ZFS mirror)
```

Se um mount mudar de disco, este documento deve ser atualizado.

---

## 5) Docker

### Estado atual

* Docker Engine instalado via repositório oficial
* Docker Compose (plugin) funcional
* Restart policy padrão: `unless-stopped`
* **Docker data-root configurado em** `/srv/docker-data` (migrado de `/var/lib/docker`)

---

### Regras obrigatórias

* Nenhum serviço com dados importantes pode usar volumes anónimos
* Todos os serviços usam bind mounts explícitos
* Cada stack vive na sua própria pasta
* `docker-compose.yml`, `.env` e dados vivem juntos

---

### Convenções operacionais (contrato técnico)

#### Estrutura de stacks

Cada serviço vive em:

```
/srv/docker/services/<nome-do-serviço>
```

Dentro da pasta existem sempre:

* `docker-compose.yml`
* `config/` (quando aplicável)
* `data/` ou bind mounts documentados

---

#### Redes Docker

* Evitar a rede bridge default quando não for necessária
* Stacks multi-container usam rede própria definida no compose
* Expor apenas as portas estritamente necessárias

---

#### Persistência de dados

* Tudo o que precisa sobreviver a rebuild deve estar em bind mount
* Os paths devem respeitar a secção 4 deste documento

---

#### Gestão de versões

* Serviços críticos usam tags explícitas (evitar `latest`)
* Atualizações feitas de forma controlada, com possibilidade de rollback

---

#### Segurança básica

* Containers como utilizador não-root sempre que possível
* Portas expostas minimizadas
* Segredos nunca hardcoded em `docker-compose.yml` (usar `.env`)

---

### Princípio estrutural

Docker é tratado como camada descartável. O que é durável:

* Dados persistentes nos bind mounts
* `docker-compose.yml`
* Estrutura de diretórios em `/srv/docker/`

Se for necessário apagar `/var/lib/docker`, todos os serviços devem ser reconstruíveis com:

```
docker compose up -d
```

---

### Gestão de logs (prevenção de enchimento de disco)

#### journald (systemd)

Configuração ativa em `/etc/systemd/journald.conf`:

```
SystemMaxUse=150M
SystemKeepFree=500M
```

Efeito:

* O total de logs do sistema nunca ultrapassa ~150 MB
* O sistema garante sempre pelo menos 500 MB livres no disco

---

#### Docker (rotação de logs de containers)

Configurado em `/etc/docker/daemon.json`:

```json
{
  "data-root": "/srv/docker-data",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}
```

---

## 6) Serviços atualmente ativos

### Minecraft

| Item         | Valor                                                    |
| ------------ | -------------------------------------------------------- |
| Stack        | `/srv/docker/services/minecraft`                         |
| Dados        | `/srv/docker/services/minecraft/data`                    |
| Container    | itzg/minecraft-server                                    |
| Gestão       | `docker compose up -d`                                   |
| Autenticação | Modo offline (`ONLINE_MODE=FALSE`)                       |
| Validação    | Mundo real recuperado do oinqserver e confirmado in-game |
| Estado       | Serviço funcional e validado                             |

### SABnzbd

(ativo, stack operacional em `/srv/docker/services/sabnzbd`)

### Prowlarr

| Item       | Valor                                    |
| ---------- | ---------------------------------------- |
| Stack      | `/srv/docker/services/prowlarr`          |
| Config     | `/srv/docker/services/prowlarr/config`   |
| Container  | `lscr.io/linuxserver/prowlarr:1.21.2`    |
| Porta      | `9696` (LAN)                             |
| Gestão     | `docker compose up -d`                   |
| Integração | Ligado ao SABnzbd via `192.168.1.6:8080` |
| Categoria  | Usa `prowlarr` como default              |
| Validação  | Teste de ligação aprovado no UI          |
| Estado     | Serviço funcional e integrado            |

### Monitoring

* Glances como serviço systemd
* Home Assistant ligado via integração Glances
* Métricas visíveis: CPU, RAM, disco, temperaturas, rede, uptime

### Tailscale

* Erebor como node ativo
* Subnet routing: `192.168.1.0/24`
* Conectividade validada externamente

---

## 7) Estrutura planeada (media stack e Immich)

### Media stack (dados não críticos, fora de ZFS)

Estrutura alvo para serviços de media:

```
/srv/docker/services/media/
  sabnzbd/
    docker-compose.yml
    config/
  radarr/
    docker-compose.yml
    config/
  sonarr/
    docker-compose.yml
    config/
```

Dados partilhados entre serviços:

```
/srv/data/scratch/downloads/incomplete
/srv/data/scratch/downloads/complete
/mnt/media/movies
/mnt/media/tv
```

Justificação documentada:

* Filmes e séries são considerados **dados não críticos**
* Perda é inconveniente mas recuperável
* Não justificam consumo de espaço nem complexidade em ZFS

---

### Immich (arquitetura híbrida aprovada)

Princípio adotado:

> **Os dados pertencem ao utilizador, não à aplicação.**

Separação explícita entre:

* **Dados importantes (fotos e vídeos originais)** → ZFS
* **Dados derivados e operacionais (metadados, cache, DB)** → fora de ZFS

#### Localização dos dados de utilizador (críticos)

```
/mnt/critical/photos/
```

Regras:

* Estes ficheiros **não são propriedade do Immich**
* Immich apenas consome este path por bind mount
* Estes dados estão protegidos por ZFS + política de backup + snapshots

#### Localização dos dados operacionais do Immich (não críticos)

```
/srv/docker/services/immich/
  docker-compose.yml
  config/
  data/   → base de dados, thumbnails, cache, ML, redis, etc.
```

Justificação:

* Base de dados pode ser reconstruída
* Thumbnails e cache são regeneráveis
* Perda implica incómodo, não perda de dados irreparável

---

## 8) Backups (estratégia real e operacional)

### 8.1 Estado atual (proteção do tesouro)

Ativo mais crítico: **fotos de família**.

Cópias existentes atualmente:

* NAS (fonte principal)
* oinqserver (segunda cópia histórica)
* Erebor (disco interno de 1 TB)
* Disco externo 2 TB (cópia offline em criação)

Objetivo desta fase:

* Permitir reestruturação de discos sem risco
* Garantir pelo menos **duas cópias offline e fisicamente separadas**

Estado considerado seguro:

* 1 cópia online ativa
* 2 cópias offline guardadas

Enquanto esta condição não estiver garantida, **não são feitas operações destrutivas em nenhum disco**.

---

### 8.2 Política de backup permanente (pós-reestruturação)

Dados considerados críticos:

* `/mnt/critical/**`
* Configurações importantes (HA, containers críticos, configs manuais)

Regras estruturais:

* 1 cópia primária no Erebor
* 1 cópia secundária automática noutro sistema
* 1 cópia offline periódica

> Redundância (ex: ZFS mirror) **não é backup**.

---

### 8.3 Mecanismo técnico previsto (a implementar)

* Ferramenta: `rsync` ou `restic`
* Origem: `/mnt/critical`
* Destino: NAS ou disco dedicado
* Frequência: diária ou semanal
* Logs verificáveis

Backup offline:

* Discos USB dedicados a backup
* Ligados apenas durante cópia
* Guardados fisicamente separados

---

### 8.4 Regra operacional de segurança

Nunca:

* Reestruturar storage
* Destruir pools
* Reutilizar discos
* Formatar volumes

Sem antes confirmar:

* Existem múltiplas cópias válidas
* Pelo menos uma é offline

Se houver dúvida, assume-se que **não está seguro**.

---

## 9) Regra operacional

Sempre que mudar:

* discos físicos
* mounts
* estrutura de paths
* serviços
* decisões de arquitetura

→ Este documento deve ser atualizado primeiro.

---

## 10) Rede (fonte de verdade)

| Elemento      | Valor                         |
| ------------- | ----------------------------- |
| Subnet        | 192.168.1.0/24                |
| Gateway       | 192.168.1.1 (OPNSense)        |
| DHCP dinâmico | 192.168.1.235 – 192.168.1.253 |

IPs críticos:

| Dispositivo    | IP           |
| -------------- | ------------ |
| OPNSense       | 192.168.1.1  |
| Home Assistant | 192.168.1.2  |
| NAS            | 192.168.1.3  |
| Erebor         | 192.168.1.6  |
| Cerbo GX       | 192.168.1.13 |
| NVR            | 192.168.1.51 |
| Switch GS748T  | 192.168.1.81 |

Regra absoluta:

* Apenas o OPNSense fornece DHCP

---

## 11) OPNSense, DNS e AdGuard

Arquitetura de DNS:

```
Clientes LAN → AdGuard Home (OPNSense :53)
↓
Unbound (OPNSense :5353)
↓
Internet
```

Implementação:

* AdGuard Home no OPNSense (binário FreeBSD oficial)
* Serviço ativo na porta 53
* Interface Web: [http://192.168.1.1:3000](http://192.168.1.1:3000)
* Unbound como upstream na porta 5353

Resultado:

* DNS funcional mesmo sem servidores ligados
* Filtragem ao nível da infraestrutura
* Observabilidade por cliente

---

## 12) Home Assistant — Energia (Utility Meters)

### Estado atual (fonte de verdade)

Toda a medição e agregação de energia foi **consolidada em YAML**. O Home Assistant deixou de usar Utility Meters criados via UI (Helpers). Estes foram removidos após validação de continuidade de dados.

Princípios aplicados:

* Single source of truth em YAML
* Nenhum Utility Meter crítico é criado via UI
* `entity_id` mantidos para preservar estatísticas históricas
* Sensores de energia usam sempre `device_class: energy` e `state_class` compatível

### Sensores fonte (contadores acumulados)

* `sensor.grid_energy_consumed_total`
* `sensor.grid_energy_exported_total`
* `sensor.victron_pv_energy`
* `sensor.victron_battery_energy`
* `sensor.victron_ac_loads_energy`
* `sensor.battery_charging_energy`
* `sensor.battery_discharging_energy`
* `sensor.gas_consumed_belgium`

### Utility meters ativos (YAML)

Definidos em:

```
/homeassistant/packages/active/energy_meters.yaml
```

Cobertura:

* Rede (import/export, tarifas)
* Solar (PV)
* Bateria (total, charge, discharge)
* AC loads
* EV charger
* Gás (m³ e kWh)

Todos com ciclos `daily / monthly / yearly`.

### Histórico

Os meters YAML herdaram corretamente os **statistics existentes** (visível como *5-minute aggregated*). Não houve perda de dados históricos relevantes.

### Regra operacional (energia)

* Nunca criar Utility Meters via UI
* Qualquer novo meter deve ser adicionado em `energy_meters.yaml`
* Antes de apagar entidades de energia: confirmar `entity_id` e `state_class`

---

## 13) Victron & MQTT Integration (infraestrutura crítica)

### Resumo técnico

* Cerbo GX integrado via MQTT local (bridge Mosquitto)
* Tópicos nativos Venus OS: `N/<serial>/#` e `R/<serial>/#`
* Sensores definidos via packages YAML
* Integração totalmente local (sem cloud)

### Arquitetura operacional

O Cerbo publica tópicos no formato:

* `N/<serial>/<service>/<path>`

Exemplo real:

* `N/<serial>/battery/0/Soc`

Comunicação bidirecional:

* Leitura: `N/<serial>/#`
* Escrita: `R/<serial>/#`

### Como adicionar um sensor novo

```yaml
sensor:
  - platform: mqtt
    name: "Victron Battery Power"
    state_topic: "N/<serial>/system/0/Dc/Battery/Power"
    unit_of_measurement: "W"
    device_class: power
    state_class: measurement
```

Regras:

* Não duplicar sensores para o mesmo tópico
* Manter nomenclatura consistente
* Cada sensor novo deve ser documentado aqui

### Localização real da bridge Mosquitto

```
\\192.168.1.2\share\mosquitto\mosquitto.conf
```

Procedimento se o Cerbo mudar de IP documentado.

---

## 14) Regra estrutural de documentação

* Este ficheiro é a única fonte de verdade
* Docs antigos passam a ser material histórico
* Qualquer alteração real deve ser refletida aqui no mesmo dia
* Se documento e realidade divergirem, o documento está errado

---

## 15) Storage real e estado atual (ZFS — fonte de verdade)

### Pool ZFS de dados críticos

* Pool: `critical`
* Tipo: mirror
* Discos: 2 × 18 TB (WD)
* Mountpoint: `/mnt/critical`
* Estado: ONLINE, 0 erros

### Datasets

| Dataset            | Mountpoint              | Função        | recordsize |
| ------------------ | ----------------------- | ------------- | ---------- |
| critical/photos    | /mnt/critical/photos    | Fotos/vídeos  | 1M         |
| critical/documents | /mnt/critical/documents | Documentos    | 128K       |
| critical/configs   | /mnt/critical/configs   | Configurações | 16K        |
| critical/backups   | /mnt/critical/backups   | Backups       | 1M         |

Integridade validada.

---

## 16) Storage não-ZFS (discos auxiliares)

### Filesystems

| Disco | Label       | FS   | Função           | Mountpoint        |
| ----- | ----------- | ---- | ---------------- | ----------------- |
| sda   | docker-data | ext4 | Docker data-root | /srv/docker-data  |
| sde   | movies      | ext4 | Media (filmes)   | /mnt/media/movies |
| sdf   | tv          | ext4 | Media (séries)   | /mnt/media/tv     |
| sdg   | scratch     | ext4 | Temporários      | /srv/data/scratch |

### fstab

```
LABEL=docker-data  /srv/docker-data  ext4  defaults,noatime  0 2
LABEL=movies       /mnt/media/movies ext4  defaults,noatime  0 2
LABEL=tv           /mnt/media/tv     ext4  defaults,noatime  0 2
LABEL=scratch      /srv/data/scratch ext4  defaults,noatime  0 2
```

---

## 17) Política de snapshots ZFS (implementada)

### Política

| Tipo    | Frequência | Retenção |
| ------- | ---------- | -------- |
| hourly  | 1h         | 24       |
| daily   | 1d         | 14       |
| weekly  | 1w         | 8        |
| monthly | 1m         | 6        |

Timers systemd ativos e validados.

---

## Nota final

Este documento reflete o estado **real e operacional** do servidor Erebor após a consolidação completa da camada de energia e da infraestrutura descrita acima.
