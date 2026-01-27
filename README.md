# Erebor Homelab — Single Source of Truth

> **Regra principal:** este ficheiro é a fonte única de verdade. Se não está aqui, oficialmente não existe.

Este documento substitui documentação antiga (oinqserver) e passa a ser a referência única e atual para o servidor **erebor**.
Objetivo: evitar informação dispersa, manter tudo coerente e permitir que qualquer mudança futura seja refletida aqui primeiro.

---

## Índice

1. Visão geral
2. Hardware atual
3. Princípios de arquitetura
4. Layout lógico de paths
5. Docker (regras e contrato técnico)
6. Serviços atualmente ativos
7. Estrutura planeada (media stack)
8. Backups
9. Regra operacional
10. Rede
11. OPNSense, DNS e AdGuard
12. Home Assistant
13. Victron & MQTT Integration
14. Regra estrutural de documentação

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

| Disco                 | Função                                    |
| --------------------- | ----------------------------------------- |
| SSD 500 GB            | Sistema operativo                         |
| SSD 250 GB            | Docker internals (data-root)              |
| SSD 250 GB            | Livre / reservado                         |
| HDD 320 GB            | Scratch (temporários, downloads, staging) |
| HDD 4 TB              | Media (filmes)                            |
| HDD 4 TB              | Media (séries)                            |
| ZFS mirror 18 + 18 TB | Dados críticos                            |
| Bays livres           | 5 / 12                                    |

---

## 3) Princípios de arquitetura

* Redundância onde importa (ZFS mirror para dados críticos)
* Isolamento de risco em dados recuperáveis (discos independentes)
* Dados descartáveis separados (scratch, downloads, NVR, etc)
* Containers são descartáveis; dados persistentes vivem sempre fora do Docker
* Bind mounts explícitos e legíveis, nunca volumes implícitos
* Nada importante fica preso em `/var/lib/docker`

---

## 4) Layout lógico de paths (abstração estável)

> Estes paths são contratos estáveis. O disco físico por trás pode mudar sem afetar containers.

```
/srv/docker/              → configs persistentes de containers
/srv/docker/services/     → stacks organizados por função
/srv/data/scratch/         → temporários, downloads, staging
/mnt/media/movies          → filmes
/mnt/media/tv              → séries
/mnt/critical              → dados críticos (ZFS mirror)
```

Se um mount mudar de disco, este documento deve ser atualizado.

---

## 5) Docker

**Estado atual**

* Docker Engine instalado via repositório oficial
* Docker Compose (plugin) funcional
* Restart policy padrão: `unless-stopped`

### Regras obrigatórias

* Nenhum serviço com dados importantes pode usar volumes anónimos
* Todos os serviços usam bind mounts explícitos
* Cada stack vive na sua própria pasta
* `docker-compose.yml` + `.env` + subpastas de dados ficam juntos

### Convenções operacionais (contrato técnico)

**Estrutura de stacks**

* Cada serviço em: `/srv/docker/services/<nome-do-serviço>`
* Dentro da pasta existem sempre, no mínimo:

  * `docker-compose.yml`
  * `config/` (quando aplicável)
  * `data/` ou paths de bind mounts claramente documentados

**Redes Docker**

* Evitar usar a rede default bridge sem necessidade
* Stacks multi-container devem usar rede própria definida no compose
* Expor portas apenas quando necessário (princípio do menor privilégio)

**Persistência de dados**

* Tudo o que precisa sobreviver a rebuild de container deve estar em bind mount
* Paths usados devem respeitar a secção 4

**Gestão de versões**

* Serviços críticos devem usar tags explícitas (evitar `latest`)
* Atualizações feitas de forma controlada, com possibilidade de rollback

**Segurança básica**

* Containers como utilizador não-root sempre que possível
* Portas expostas minimizadas
* Segredos nunca hardcoded em `docker-compose.yml` (usar `.env`)

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

## 6) Serviços atualmente ativos

### Minecraft

| Item      | Valor                                     |
| --------- | ----------------------------------------- |
| Stack     | `/srv/docker/services/minecraft`          |
| Dados     | `/srv/docker-data/minecraft` (temporário) |
| Container | itzg/minecraft-server                     |
| Estado    | Validado com reboot + cliente real        |

### Monitoring

* Glances como serviço systemd
* Home Assistant ligado via integração Glances
* Métricas visíveis: CPU, RAM, disco, temperaturas, rede, uptime

### Tailscale

* Erebor como node ativo
* Subnet routing: `192.168.1.0/24`
* Conectividade validada externamente

---

## 7) Estrutura planeada para media stack (exemplo futuro)

Estrutura alvo:

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

Dados críticos:

* `/mnt/critical/**`
* Configurações importantes (HA, containers críticos, configs manuais)

Regras:

* 1 cópia primária no Erebor
* 1 cópia secundária automática noutro sistema
* 1 cópia offline periódica

> Redundância (ex: ZFS mirror) **não é backup**.

---

### 8.3 Mecanismo técnico previsto (a implementar)

* Ferramenta: `rsync` ou `restic`
* Origem: `/mnt/critical`
* Destino: NAS ou disco dedicado
* Frequência: diária ou semanal (a definir)
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

* Cerbo publica:

  * `N/<serial>/<service>/<path>`

* Exemplo:

  * `N/<serial>/battery/0/Soc`

* HA consome diretamente os tópicos

* Comunicação bidirecional:

  * Leitura: `N/<serial>/#`
  * Escrita: `R/<serial>/#`

---

### Como adicionar um sensor novo

Modelo base (exemplo):

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

---

### Localização real da bridge Mosquitto

A bridge vive no add-on oficial **Mosquitto broker** do HA.

Caminho real do ficheiro:

```
\192.168.1.2\share\mosquitto\mosquitto.conf
```

Alterações neste ficheiro sobrevivem a reboots e updates do add-on.

---

### Procedimento se o Cerbo mudar de IP

1. Descobrir novo IP no OPNSense (DHCP leases)
2. Abrir:

   ```
   \192.168.1.2\share\mosquitto\mosquitto.conf
   ```
3. Alterar linha `address x.x.x.x`
4. Guardar ficheiro
5. Reiniciar add-on Mosquitto no HA

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

Objetivo: nunca mais existir a situação de "tenho outro ficheiro algures com informação diferente".
