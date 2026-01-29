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
/srv/data/scratch/        → temporários, downloads, staging
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

(inalterado — ver histórico do documento)

---

## 7) Estrutura planeada (media stack e Immich)

(inalterado — ver histórico do documento)

---

## 8) Backups (estratégia real e operacional)

(inalterado — ver histórico do documento)

---

## 9) Regra operacional

(inalterado — ver histórico do documento)

---

## 10) Rede (fonte de verdade)

(inalterado — ver histórico do documento)

---

## 11) OPNSense, DNS e AdGuard

(inalterado — ver histórico do documento)

---

## 12) Home Assistant — Energia (Utility Meters)

### Estado atual (fonte de verdade)

Toda a medição e agregação de energia foi **consolidada em YAML**. O Home Assistant deixou de usar Utility Meters criados via UI (Helpers). Estes foram removidos após validação de continuidade de dados.

Princípios aplicados:

* **Single source of truth em YAML**
* Nenhum Utility Meter crítico é criado via UI
* `entity_id` mantidos para preservar estatísticas históricas
* Sensores de energia usam sempre `device_class: energy` e `state_class` compatível

---

### Sensores fonte (contadores acumulados)

* `sensor.grid_energy_consumed_total`
* `sensor.grid_energy_exported_total`
* `sensor.victron_pv_energy`
* `sensor.victron_battery_energy`
* `sensor.victron_ac_loads_energy`
* `sensor.battery_charging_energy`
* `sensor.battery_discharging_energy`
* `sensor.gas_consumed_belgium`

---

### Utility meters ativos (YAML)

Definidos em:

```
/homeassistant/packages/active/energy_meters.yaml
```

* Grid, PV, bateria, AC loads, EV e gás com ciclos daily / monthly / yearly
* Todos os meters UI foram removidos após validação

---

### Nota sobre histórico

Os meters YAML herdaram corretamente os **statistics existentes** (visível como "5-minute aggregated"). Não houve perda de dados históricos relevantes.

---

## 13) Victron & MQTT Integration

(inalterado — ver histórico do documento)

---

## 14) Regra estrutural de documentação

(inalterado — ver histórico do documento)

---

## 15) Storage real e estado atual (ZFS)

(inalterado — ver histórico do documento)

---

## 16) Storage não-ZFS (discos auxiliares)

(inalterado — ver histórico do documento)

---

## 17) Política de snapshots ZFS (implementada)

(inalterado — ver histórico do documento)

---

## Nota final

Este documento reflete o estado **real e operacional** do servidor Erebor, incluindo a consolidação energética realizada neste chat.
