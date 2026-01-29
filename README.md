# Erebor Homelab — Single Source of Truth

> **Regra principal:** este ficheiro é a fonte única de verdade. Se não está aqui, oficialmente não existe.

Este documento substitui documentação antiga (oinqserver) e passa a ser a referência única e atual para o servidor **erebor**. Objetivo: evitar informação dispersa, manter tudo coerente e permitir que qualquer mudança futura seja refletida aqui primeiro.

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
* **Serviços ativos**: Docker, Minecraft, Glances, Tailscale.
* **Regra de ouro**: se não está neste ficheiro, oficialmente não existe.

---

## Índice

* [1) Visão geral](#1-visão-geral)
* [2) Hardware atual](#2-hardware-atual-fonte-de-verdade)
* [3) Princípios de arquitetura](#3-princípios-de-arquitetura)
* [4) Layout lógico de paths](#4-layout-lógico-de-paths-abstração-estável)
* [5) Docker](#5-docker)
* [6) Serviços atualmente ativos](#6-serviços-atualmente-ativos)
* [7) Estrutura planeada (media stack)](#7-estrutura-planeada-para-media-stack-exemplo-futuro)
* [8) Backups](#8-backups-estratégia-real-e-operacional)
* [9) Regra operacional](#9-regra-operacional)
* [10) Rede](#10-rede-fonte-de-verdade)
* [11) OPNSense, DNS e AdGuard](#11-opnsense-dns-e-adguard)
* [12) Home Assistant](#12-home-assistant)
* [13) Victron & MQTT Integration](#13-victron--mqtt-integration-infraestrutura-crítica)
* [14) Regra estrutural de documentação](#14-regra-estrutural-de-documentação)
* [15) Storage real e estado atual (ZFS)](#15-storage-real-e-estado-atual-zfs--fonte-de-verdade)
* [16) Storage não-ZFS (discos auxiliares)](#16-storage-não-zfs-discos-auxiliares)

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

**Nada crítico em **``
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

Esta configuração foi aplicada **no sistema real** para evitar repetição do problema histórico de logs a encher o disco de sistema.

#### journald (systemd)

Configuração ativa em `/etc/systemd/journald.conf`:

```
SystemMaxUse=150M
SystemKeepFree=500M
```

Efeito:

* O total de logs do sistema nunca ultrapassa ~150 MB
* O sistema garante sempre pelo menos 500 MB livres no disco

Serviço recarregado com:

```
systemctl restart systemd-journald
```

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

Efeito:

* Cada container nunca pode ultrapassar ~150 MB de logs
* Logs antigos são automaticamente rodados e descartados
* Elimina o risco de consumo silencioso de dezenas de GB

Serviço recarregado com:

```
systemctl restart docker
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

| Item                         | Valor                                                         |
| ---------------------------- | ------------------------------------------------------------- |
| Stack                        | `/srv/docker/services/prowlarr`                               |
| Config                       | `/srv/docker/services/prowlarr/config`                        |
| Container                    | lscr.io/linuxserver/prowlarr:1.21.2                           |
| Porta                        | 9696 (apenas LAN)                                             |
| Gestão                       | `docker compose up -d`                                        |
| Integração                   | Ligado funcionalmente ao SABnzbd via LAN (`192.168.1.6:8080`) |
| Categoria                    | Categoria `prowlarr` criada no SABnzbd e usada como default   |
| Validação                    | Teste de ligação aprovado no UI do Prowlarr                   |
| Estado                       | Serviço funcional e integrado                                 |
| Serviço funcional e validado |                                                               |

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

Este diretório contém:

* Fotos originais
* Vídeos originais
* Estrutura de álbuns do utilizador

Regras:

* Estes ficheiros **não são propriedade do Immich**
* Immich apenas consome este path por bind mount
* Estes dados estão protegidos por ZFS + política de backup

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

#### Consequência arquitetural importante

* Se o Immich for destruído, atualizado ou reconstruído:

  * As fotos continuam intactas em `/mnt/critical/photos-library`
  * O serviço pode ser recriado apontando novamente para os mesmos dados

Este modelo cumpre simultaneamente:

* Separação entre dados e aplicação
* Proteção máxima para dados pessoais
* Flexibilidade operacional para containers

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

---

## 8) Backups (estratégia real e operacional)

### 8.1 Estado atual (proteção do tesouro)

Ativo mais crítico: **fotos de família**.

Cópias existentes atualmente:

- NAS (fonte principal)

- oinqserver (segunda cópia histórica)

- Erebor (disco interno de 1 TB)

- Disco externo 2 TB (cópia offline em criação)

Objetivo desta fase:

- Permitir reestruturação de discos sem risco

- Garantir pelo menos **duas cópias offline e fisicamente separadas**

Estado considerado seguro:

- 1 cópia online ativa

- 2 cópias offline guardadas

Enquanto esta condição não estiver garantida, **não são feitas operações destrutivas em nenhum disco**.

---

### 8.2 Política de backup permanente (pós-reestruturação)

Dados considerados críticos:

- `/mnt/critical/**`

- Configurações importantes (HA, containers críticos, configs manuais)

Regras estruturais:

- 1 cópia primária no Erebor

- 1 cópia secundária automática noutro sistema

- 1 cópia offline periódica

> Redundância (ex: ZFS mirror) **não é backup**.

---

### 8.3 Mecanismo técnico previsto (a implementar)

- Ferramenta: `rsync` ou `restic`

- Origem: `/mnt/critical`

- Destino: NAS ou disco dedicado

- Frequência: diária ou semanal (a definir)

- Logs verificáveis

Backup offline:

- Discos USB dedicados a backup

- Ligados apenas durante cópia

- Guardados fisicamente separados

---

### 8.4 Regra operacional de segurança

Nunca:

- Reestruturar storage

- Destruir pools

- Reutilizar discos

- Formatar volumes

Sem antes confirmar:

- Existem múltiplas cópias válidas

- Pelo menos uma é offline

Se houver dúvida, assume-se que **não está seguro**.

---

## 9) Regra operacional

Sempre que mudar:

- discos físicos
- mounts
- estrutura de paths
- serviços
- decisões de arquitetura

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

- Apenas o OPNSense fornece DHCP

---

## 11) OPNSense, DNS e AdGuard

Arquitetura de DNS:

```

Clientes LAN → AdGuard Home (OPNSense :53)
↓
Unbound (OPNSense :5353)
↓
Internet

````

Implementação:

- AdGuard Home no OPNSense (binário FreeBSD oficial)
- Serviço ativo na porta 53
- Interface Web: [http://192.168.1.1:3000](http://192.168.1.1:3000)
- Unbound como upstream na porta 5353

Resultado:

- DNS funcional mesmo sem servidores ligados
- Filtragem ao nível da infraestrutura
- Observabilidade por cliente

---

## 12) Home Assistant

| Item          | Valor                            |
| ------------- | -------------------------------- |
| Plataforma    | Home Assistant OS                |
| IP            | 192.168.1.2                      |
| Acesso remoto | Tailscale                        |
| Função        | Controlador central de automação |

Escopo:

- Plataforma HA
- Integrações genéricas (Glances, notificações, dashboards)
- Estrutura base (não específica de sistemas externos)

---

## 13) Victron & MQTT Integration (infraestrutura crítica)

### Resumo técnico

- Cerbo GX integrado via MQTT local (bridge Mosquitto)

- Tópicos nativos Venus OS: `N/<serial>/#` e `R/<serial>/#`

- Sensores definidos via packages YAML

- Integração totalmente local (sem cloud)

---

### Arquitetura operacional

O Cerbo publica tópicos no formato:

- `N/<serial>/<service>/<path>`

Exemplo real:

- `N/<serial>/battery/0/Soc`

O Home Assistant consome diretamente estes tópicos.

A comunicação é bidirecional:

- Leitura: `N/<serial>/#`

- Escrita: `R/<serial>/#`

---

### Como adicionar um sensor novo

Modelo base:

```yaml
sensor:
  - platform: mqtt
    name: "Victron Battery Power"
    state_topic: "N/<serial>/system/0/Dc/Battery/Power"
    unit_of_measurement: "W"
    device_class: power
    state_class: measurement
````

Regras obrigatórias:

* Não duplicar sensores para o mesmo tópico

* Manter nomenclatura consistente

* Cada sensor novo deve ser documentado aqui

---

### Localização real da bridge Mosquitto

A bridge vive no add-on oficial **Mosquitto broker** do HA.

Caminho real do ficheiro:

```
\\192.168.1.2\share\mosquitto\mosquitto.conf
```

Alterações neste ficheiro sobrevivem a reboots e updates do add-on.

---

### Procedimento se o Cerbo mudar de IP

1. Descobrir novo IP no OPNSense (DHCP leases)

2. Abrir o ficheiro:

   ```
   \\192.168.1.2\share\mosquitto\mosquitto.conf
   ```

3. Alterar a linha `address x.x.x.x`

4. Guardar o ficheiro

5. Reiniciar o add-on Mosquitto no HA

Resultado esperado:

* Bridge reconecta

* Tópicos reaparecem

* Sensores retomam automaticamente

> Nota: o Cerbo deve ter sempre reserva DHCP. Este procedimento é apenas recuperação de falha.

---

### Capacidade energética (contexto)

| Elemento   | Valor                    |
| ---------- | ------------------------ |
| Inversores | 3 × MultiPlus 48/5000-70 |
| MPPT       | 450/200                  |
| Baterias   | 4 × 5 kWh                |
| Autonomia  | ~8 meses off-grid        |

Sistema considerado **infraestrutura crítica da casa**.

---

## 14) Regra estrutural de documentação

* Este ficheiro é a única fonte de verdade
* Docs antigos passam a ser material histórico
* Qualquer alteração real deve ser refletida aqui no mesmo dia
* Se documento e realidade divergirem, o documento está errado

---

## 15) Storage real e estado atual (ZFS — fonte de verdade)

### Pool ZFS de dados críticos

Pool ativo:

* Nome: `critical`
* Tipo: mirror
* Discos:

  * WDC WD180EDGZ (18 TB)
  * WDC WD180EDGZ (18 TB)
* Identificação via: `/dev/disk/by-id`
* Mountpoint: `/mnt/critical`
* Estado: ONLINE, 0 erros (`zpool status` limpo)

Propriedades ativas no pool:

* ashift=12
* compression=lz4
* atime=off
* autotrim=on
* ACL e xattrs ativos

O pool foi validado após:

* limpeza destrutiva dos discos (mdadm, sgdisk, wipefs)
* criação nova do mirror
* mudança física de cabos SATA → backplane
* Sem necessidade de reimportação e sem degradação

Conclusão: configuração robusta e independente da ordem das portas.

### Integridade dos dados migrados

Dados já migrados para ZFS:

* Fotos de família (~963 GB)

Cópia realizada com `rsync` e verificada com execução incremental posterior:

Resultado confirmado:

* 69 995 ficheiros
* ~963 GB
* 0 diferenças
* Estrutura, timestamps e tamanhos coerentes

Os dados em `/mnt/critical` são considerados consistentes.

### Estado SMART dos discos validados

Discos atualmente considerados saudáveis:

* SSD Samsung 750 EVO 250 GB
* SSD Samsung 850 EVO 250 GB
* HDD WD 320 GB
* HDD WD 4 TB (x2)
* Dois discos 18 TB do pool ZFS

Nenhum disco apresenta:

* sectores realocados
* sectores pendentes
* sectores incorrigíveis

---

## 16) Storage não-ZFS (discos auxiliares)

Esta secção reflete o estado **real implementado** dos discos auxiliares após limpeza completa, formatação e montagem persistente.

### Filesystems criados

| Disco | Label       | FS   | Função           | Mountpoint          |
| ----- | ----------- | ---- | ---------------- | ------------------- |
| sda   | docker-data | ext4 | Docker data-root | `/srv/docker-data`  |
| sdd   | —           | —    | Reservado        | —                   |
| sde   | movies      | ext4 | Media (filmes)   | `/mnt/media/movies` |
| sdf   | tv          | ext4 | Media (séries)   | `/mnt/media/tv`     |
| sdg   | scratch     | ext4 | Temporários      | `/srv/data/scratch` |

### Montagem persistente (`/etc/fstab`)

Entradas ativas:

```
LABEL=docker-data  /srv/docker-data      ext4  defaults,noatime  0 2
LABEL=movies       /mnt/media/movies     ext4  defaults,noatime  0 2
LABEL=tv           /mnt/media/tv         ext4  defaults,noatime  0 2
LABEL=scratch      /srv/data/scratch     ext4  defaults,noatime  0 2
```

### Estado validado

* Todos os mounts testados com `umount` + `mount -a`
* Todos reaparecem corretamente após reload do systemd
* `df -h` confirma tamanhos e localizações corretas
* Nenhum impacto nos discos ZFS ou no disco de sistema

Conclusão: a camada de storage auxiliar está **concluída e estável**.

---

## Nota final

Este documento reflete o estado **real e operacional** do servidor Erebor após:

* Limpeza controlada dos discos
* Reestruturação completa do layout de storage
* Implementação de mounts persistentes alinhados com a arquitetura

A partir daqui, qualquer evolução (Docker, serviços, automações, backups, etc.) deve ser documentada aqui primeiro.
