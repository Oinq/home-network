# Erebor Homelab — Single Source of Truth

> **Regra principal:** este ficheiro é a fonte única de verdade. Se não está aqui, oficialmente não existe.

Este documento define o **estado constitucional** do servidor **erebor**. Substitui documentação antiga e serve como referência única e estável. Documentos derivados podem existir, mas nunca contradizem este ficheiro.

---

## 1) Identidade do sistema

| Item     | Valor                              |
| -------- | ---------------------------------- |
| Hostname | erebor                             |
| OS       | Ubuntu Server 24.04.3 LTS          |
| Boot     | UEFI (/boot e /boot/efi separados) |
| LVM      | Root 100 GB, espaço livre ~362 GB  |
| Updates  | unattended-upgrades ativo          |
| Estado   | Sistema estável e operacional      |

---

## 2) Princípios de arquitetura (imutáveis)

* Dados críticos são protegidos por redundância ao nível de disco.
* Dados recuperáveis vivem fora de mecanismos de alta complexidade.
* Containers são descartáveis; dados persistentes não são.
* Bind mounts explícitos são obrigatórios.
* O Docker é uma camada reconstruível, não uma dependência estrutural.
* Redundância **não** é backup.

---

## 3) Layout lógico de paths (contratos estáveis)

Os seguintes paths são **contratos estáveis**. O backend físico pode mudar sem impacto lógico, desde que este ficheiro seja atualizado.

```
/srv/docker/              → configs persistentes de containers
/srv/docker/services/     → stacks organizados por função
/srv/docker-data/         → data-root do Docker
/srv/data/scratch/        → temporários, downloads, staging
/mnt/media/movies         → filmes
/mnt/media/tv             → séries
/mnt/critical             → dados críticos (ZFS)
```

---

## 4) Storage — visão de alto nível

* Dados críticos residem num pool ZFS em mirror montado em `/mnt/critical`.
* Dados não críticos (media, downloads, temporários) residem fora de ZFS.
* A organização física detalhada do storage é documentada separadamente.

> Detalhe técnico completo: `10-storage-zfs.md`

---

## 5) Docker — modelo operativo

* Docker está instalado via repositório oficial.
* O `data-root` do Docker encontra-se fora de `/var/lib/docker`.
* Serviços são organizados por stack e função.
* Persistência é garantida exclusivamente por bind mounts.

> Implementação detalhada: `20-docker.md`
>
> Media stack: `21-docker-media-stack.md`

---

## 6) Serviços ativos (estado declarativo)

| Serviço / Domínio | Estado | Documento de referência    |
| ----------------- | ------ | -------------------------- |
| Minecraft         | Ativo  | `20-docker.md`             |
| Media stack       | Ativo  | `21-docker-media-stack.md` |
| SABnzbd           | Ativo  | `21-docker-media-stack.md` |
| Monitoring        | Ativo  | `40-home-assistant.md`     |
| Tailscale         | Ativo  | `20-docker.md`             |

---

## 7) Rede (fonte de verdade)

| Elemento | Valor                  |
| -------- | ---------------------- |
| Subnet   | 192.168.1.0/24         |
| Gateway  | 192.168.1.1 (OPNSense) |

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

* Apenas o OPNSense fornece DHCP.

---

## 8) Backups — regras estruturais

* Dados críticos incluem, no mínimo, `/mnt/critical/**`.
* Existem sempre múltiplas cópias válidas.
* Pelo menos uma cópia é offline.

Regra de segurança:

> Sem confirmação de múltiplas cópias válidas (incluindo offline), **não** se executam operações destrutivas.

> Implementação técnica: `30-backups.md`

---

## 9) Home Assistant — papel no sistema

* O Home Assistant é camada de controlo e observabilidade.
* Não é fonte primária de dados.
* Sensores físicos e sistemas externos são a verdade.
* Energia segue um modelo hierárquico e auditável.

> Detalhe completo: `40-home-assistant.md`
>
> Victron & MQTT: `41-victron-mqtt.md`

---

## 10) Regra estrutural de documentação

* Este ficheiro é a fonte única de verdade.
* Documentação derivada explica, mas não redefine.
* Em caso de conflito, este ficheiro prevalece.
* Alterações reais devem ser refletidas aqui **antes** ou **no mesmo dia**.

---

**Estado:** consistente, operativo e alinhado com a arquitetura real do Erebor.



---

## Documentação derivada (referências)

Este ficheiro define o estado constitucional do Erebor.
Os documentos abaixo detalham a implementação por domínio e nunca o contradizem.

* `10-storage-zfs.md` — Storage ZFS e política de snapshots
* `20-docker.md` — Modelo operativo do Docker
* `21-docker-media-stack.md` — Media stack (Radarr, Sonarr, Bazarr, Jellyfin, Jellyseerr)
* `30-backups.md` — Estratégia e estado dos backups
* `40-home-assistant.md` — Modelo operacional do Home Assistant
* `41-victron-mqtt.md` — Integração Victron & MQTT
