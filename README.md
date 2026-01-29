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

### Radarr

| Item       | Valor                                      |
| ---------- | ------------------------------------------ |
| Stack      | `/srv/docker/services/media/radarr`        |
| Config     | `/srv/docker/services/media/radarr/config` |
| Container  | `lscr.io/linuxserver/radarr`               |
| Porta      | `7878` (LAN)                               |
| Root       | `/mnt/media/movies`                        |
| Integração | SABnzbd + Prowlarr                         |
| Validação  | Import automático confirmado               |
| Estado     | Serviço funcional e validado               |

### Sonarr

| Item       | Valor                                      |
| ---------- | ------------------------------------------ |
| Stack      | `/srv/docker/services/media/sonarr`        |
| Config     | `/srv/docker/services/media/sonarr/config` |
| Container  | `lscr.io/linuxserver/sonarr`               |
| Porta      | `8989` (LAN)                               |
| Root       | `/mnt/media/tv`                            |
| Integração | SABnzbd + Prowlarr                         |
| Validação  | Import automático confirmado               |
| Estado     | Serviço funcional e validado               |

### Prowlarr

| Item       | Valor                                  |
| ---------- | -------------------------------------- |
| Stack      | `/srv/docker/services/prowlarr`        |
| Config     | `/srv/docker/services/prowlarr/config` |
| Container  | `lscr.io/linuxserver/prowlarr`         |
| Porta      | `9696` (LAN)                           |
| Integração | Ligado ao SABnzbd, Radarr e Sonarr     |
| Estado     | Serviço funcional e integrado          |

### Monitoring

* Glances como serviço systemd
* Integração ativa no Home Assistant
* Métricas visíveis: CPU, RAM, disco, temperaturas, rede, uptime

### Tailscale

* Erebor como node ativo
* Subnet routing: `192.168.1.0/24`
* Conectividade externa validada

---

## 7) Estrutura implementada (media stack e Immich)

### Media stack (dados não críticos, fora de ZFS)

Estrutura real implementada:

```
/srv/docker/services/media/
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

Estado:

* Pipeline SABnzbd → ARRs → media final validado
* Import automático confirmado para filmes e séries
* Downloads de teste realizados em 1080p **apenas para validação técnica**

### Nota sobre perfis

Os perfis atuais **não representam o estado final desejado**.

Próximo passo obrigatório:

* Definir perfis finais de qualidade
* Documentar explicitamente esses perfis neste ficheiro
* Remover media de teste após validação

---

### Jellyfin (planeado)

Estado: **não instalado**.

Planeado como servidor de media, consumindo exclusivamente:

```
/mnt/media/movies
/mnt/media/tv
```

Sem escrita nesses paths.

### Overseerr (planeado)

Estado: **não instalado**.

Planeado como interface de pedidos de media, integrado com Radarr e Sonarr, sem acesso direto ao filesystem.


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

## 12) Home Assistant

| Item          | Valor                            |
| ------------- | -------------------------------- |
| Plataforma    | Home Assistant OS                |
| IP            | 192.168.1.2                      |
| Acesso remoto | Tailscale                        |
| Função        | Controlador central de automação |

Escopo:

* Plataforma HA como orquestrador central da casa
* Integrações genéricas (Glances, notificações, dashboards)
* Integrações críticas locais (energia, sensores, atuadores)
* Estrutura declarativa e versionável via YAML (packages)

### Princípio estrutural

O Home Assistant é tratado como **camada de controlo e observabilidade**, não como fonte primária de dados.

Regra fundamental:

> **Os sensores base (contadores físicos, inversores, medidores) são a verdade.**
> O Home Assistant apenas agrega, deriva e apresenta.

Qualquer lógica que possa ser reconstruída **deve ser reconstruível**.

---

### Energia — modelo adotado (fonte de verdade)

A gestão de energia no Home Assistant segue um modelo estritamente hierárquico e auditável.

1. **Sensores base**
   Contadores físicos e lógicos que representam valores reais e cumulativos (kWh), tipicamente com `state_class: total_increasing`.

2. **Sensores de conveniência (template)**
   Sensores derivados usados apenas para:

   * somas (ex: tarifário 1 + 2)
   * conversões (ex: m³ → kWh)
   * normalização de nomes

   Estes sensores **não criam histórico próprio relevante** e podem ser recriados a qualquer momento.

3. **Utility meters**
   Único mecanismo autorizado para:

   * daily / monthly / yearly roll-ups
   * dashboards históricos
   * estatísticas de consumo e produção

---

### Consolidação de utility meters

Decisão arquitetural tomada:

> **Todos os utility meters passam a ser definidos exclusivamente em YAML, via packages.**

Implicações:

* Utility meters criados pela UI foram removidos
* O histórico manteve-se intacto (baseado em estatísticas)
* A UI deixa de ser fonte de verdade para energia

Benefícios:

* Configuração versionável em Git
* Reprodutibilidade total em caso de rebuild
* Eliminação de duplicações e nomes ambíguos

---

### Organização prática

Os utility meters de energia encontram-se organizados por domínio funcional:

* Rede elétrica (importação / exportação)
* Produção fotovoltaica
* Baterias (carga / descarga / energia acumulada)
* Consumos dedicados (EV charger, boiler, cargas AC)
* Gás (m³ e conversão para kWh)

Cada domínio segue as mesmas regras:

* Sensor base cumulativo
* Zero lógica na UI
* Roll-ups apenas via `utility_meter`

---

### Regra operacional

* Nunca criar utility meters pela UI
* Nunca apagar sensores base com histórico sem auditoria prévia
* Qualquer alteração energética deve ser refletida:

  * no package YAML correspondente
  * e neste documento

Se o Home Assistant for destruído e reinstalado, **toda a camada energética deve ser reconstruível apenas com YAML + histórico do recorder**.

---

---------- | -------------------------------- |
| Plataforma    | Home Assistant OS                |
| IP            | 192.168.1.2                      |
| Acesso remoto | Tailscale                        |
| Função        | Controlador central de automação |

Escopo:

* Plataforma HA
* Integrações genéricas (Glances, notificações, dashboards)
* Estrutura base (não específica de sistemas externos)

---

## 13) Victron & MQTT Integration (infraestrutura crítica)

### Resumo técnico

* Cerbo GX integrado via MQTT local (bridge Mosquitto)
* Tópicos nativos Venus OS: `N/<serial>/#` e `R/<serial>/#`
* Sensores definidos via packages YAML
* Integração totalmente local (sem cloud)

---

### Arquitetura operacional

O Cerbo publica tópicos no formato:

* `N/<serial>/<service>/<path>`

Exemplo real:

* `N/<serial>/battery/0/Soc`

O Home Assistant consome diretamente estes tópicos.

A comunicação é bidirecional:

* Leitura: `N/<serial>/#`
* Escrita: `R/<serial>/#`

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
```

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
   \\\\192.168.1.2\\share\\mosquitto\\mosquitto.conf
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

### Datasets existentes

| Dataset            | Mountpoint                | Função        | recordsize |
| ------------------ | ------------------------- | ------------- | ---------- |
| critical/photos    | `/mnt/critical/photos`    | Fotos/vídeos  | 1M         |
| critical/documents | `/mnt/critical/documents` | Documentos    | 128K       |
| critical/configs   | `/mnt/critical/configs`   | Configurações | 16K        |
| critical/backups   | `/mnt/critical/backups`   | Backups       | 1M         |

### Integridade dos dados migrados

Dados migrados e verificados para ZFS:

* Fotos de família (~963 GB)
* Verificação via `rsync --dry-run --delete` sem diferenças

Conclusão: dados consistentes.

### Estado SMART dos discos validados

Nenhum disco apresenta sectores realocados, pendentes ou incorrigíveis.

---

## 16) Storage não-ZFS (discos auxiliares)

### Filesystems criados

| Disco | Label       | FS   | Função           | Mountpoint          |
| ----- | ----------- | ---- | ---------------- | ------------------- |
| sda   | docker-data | ext4 | Docker data-root | `/srv/docker-data`  |
| sdd   | —           | —    | Reservado        | —                   |
| sde   | movies      | ext4 | Media (filmes)   | `/mnt/media/movies` |
| sdf   | tv          | ext4 | Media (séries)   | `/mnt/media/tv`     |
| sdg   | scratch     | ext4 | Temporários      | `/srv/data/scratch` |

### Montagem persistente (`/etc/fstab`)

```
LABEL=docker-data  /srv/docker-data      ext4  defaults,noatime  0 2
LABEL=movies       /mnt/media/movies     ext4  defaults,noatime  0 2
LABEL=tv           /mnt/media/tv         ext4  defaults,noatime  0 2
LABEL=scratch      /srv/data/scratch     ext4  defaults,noatime  0 2
```

Conclusão: camada de storage auxiliar concluída e estável.

---

## 17) Política de snapshots ZFS (implementada)

### Objetivo

Proteger dados críticos contra apagamentos acidentais, corrupção lógica e erro humano, com retenção previsível e mecanismo totalmente auditável.

### Implementação técnica real

* Mecanismo próprio baseado em script + systemd timers (não dependente de pacotes externos instáveis).
* Script de gestão de snapshots:

```
/usr/local/sbin/zfs-snapshot.sh
```

Datasets protegidos pelo mecanismo:

* `critical/photos`
* `critical/documents`
* `critical/configs`

Dataset excluído explicitamente:

* `critical/backups`

### Política de retenção ativa

| Tipo    | Frequência | Retenção |
| ------- | ---------- | -------- |
| hourly  | 1 hora     | 24       |
| daily   | 1 dia      | 14       |
| weekly  | 1 semana   | 8        |
| monthly | 1 mês      | 6        |

### Integração com systemd

Timers ativos:

* `zfs-snapshot-hourly.timer`
* `zfs-snapshot-daily.timer`
* `zfs-snapshot-weekly.timer`
* `zfs-snapshot-monthly.timer`

Cada timer executa o script com os parâmetros apropriados de retenção.

### Validação

* Execução manual confirmada com criação real de snapshots
* `systemctl list-timers` confirma timers ativos
* `zfs list -t snapshot` mostra snapshots coerentes por dataset

Conclusão: camada de snapshots funcional, previsível e sob controlo direto.

---

## Nota final

Este documento reflete o estado **real e operacional** do servidor Erebor após:

* Limpeza controlada dos discos
* Reestruturação completa do layout de storage
* Implementação de datasets ZFS
* Afinação de propriedades por tipo de dado
* Implementação de snapshots automáticos com retenção definida
* Implementação de mounts persistentes alinhados com a arquitetura

A partir daqui, qualquer evolução (Docker, serviços, automações, backups, etc.) deve ser documentada aqui primeiro.
