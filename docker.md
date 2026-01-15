# Homelab – Docker Structure & Services

Este documento descreve a estrutura de pastas, organização de dados persistentes e stack de containers do servidor **oinqserver**. O objetivo é facilitar manutenção, troubleshooting, backups e futuras migrações.

---

## 🖥️ Servidor

* Hostname: `oinqserver`
* OS: Ubuntu 24.04 LTS
* Docker data-root: `/mnt/raid/docker-data` (uso interno do Docker)
* Dados persistentes das aplicações: `/mnt/raid/containers`
* Docker Engine: 27.5.1
* Docker Compose: v2.40.1


> Regra de ouro: **Nunca editar ou apagar manualmente nada em `/mnt/raid/docker-data`**. Apenas usar comandos Docker.

---

## 📁 Estrutura principal de dados

```
/mnt/raid/containers/
├── arrstack/          ← Stack multimédia principal
│   ├── radarr/config
│   ├── sonarr/config
│   ├── sabnzbd/config
│   ├── prowlarr/config
│   ├── bazarr/config
│   ├── lingarr/config
│   ├── libretranslate/
│   └── downloads/
│       ├── complete/
│       └── incomplete/
│
├── jellyfin/
│   ├── config/
│   └── cache/
│
├── immich/
│   ├── upload/
│   └── postgres/
│
├── azerothcore/
│   └── dados do servidor WoW
│
└── minecraft-data/
```

Todos os serviços importantes usam **bind mounts explícitos** para estas pastas.

---

## 📦 Stack Arr (Media Automation)

Local: `/mnt/raid/containers/arrstack`

| Serviço        | Porta   | Função                     |
| -------------- | ------- | -------------------------- |
| SABnzbd        | 8080    | Downloader Usenet          |
| Radarr         | 7878    | Gestão de filmes           |
| Sonarr         | 8989    | Gestão de séries           |
| Prowlarr       | 9696    | Gestão central de indexers |
| Bazarr         | 6767    | Legendas automáticas       |
| Lingarr        | ?       | Tradução (experimental)    |
| LibreTranslate | interno | Backend tradução           |

Todos usam:

* Restart policy: `unless-stopped`
* Dados persistentes em subpastas de `arrstack`

---

## 🔄 Política de restart (resiliência)

Todos os containers críticos estão configurados com:

```
--restart unless-stopped
```

Confirmado para:

* sabnzbd
* radarr
* sonarr
* prowlarr
* bazarr
* lingarr
* jellyfin
* immich services

Resultado:

* Reboot → tudo volta sozinho
* Crash → reinicia sozinho
* Falha de energia → recuperação automática

---

## 🐳 Docker data-root (`/mnt/raid/docker-data`)

Contém apenas dados internos do Docker:

* `overlay2/` → layers de imagens
* `containers/` → logs e metadata
* `volumes/` → volumes nomeados

⚠️ Nunca manipular manualmente. Para limpeza usar apenas:

```
docker system prune
```

---

## 💾 Backups recomendados

Deves incluir em backup regular:

* `/mnt/raid/containers/arrstack/**/config`
* `/mnt/raid/containers/jellyfin/config`
* `/mnt/raid/containers/immich`
* `/mnt/raid/minecraft-data`

Não é necessário fazer backup de:

* `/mnt/raid/docker-data`
* imagens Docker

---

## 📌 Próximos passos documentados

* [ ] Auditoria e documentação do Jellyfin
* [ ] Validação de backups automáticos
* [ ] Monitorização de containers (alertas)
* [ ] Export final para Git (infra documentation)

---

Documento vivo – pode (e deve) ser atualizado à medida que o homelab evolui.
