# MeTube (yt-dlp Web UI) — Setup + Auto-Sorter

## Objetivo

- MeTube descarrega conteúdo (YouTube/audio/video) para um disco de scratch
- Um sorter automático move os ficheiros completos para as bibliotecas finais no RAID
- Evita misturar com SABnzbd e mantém staging separado

---

## Paths (Host)

### Scratch (staging temporário)

```
/srv/data/scratch/metube
```

Montado no container como:

```
/downloads
```

### Serviço (config persistente)

```
/srv/docker/services/metube/config
```

Montado no container como:

```
/config
```

### Destinos finais (RAID)

```
/mnt/raid/media/music
/mnt/raid/media/homevideo
/mnt/raid/media/books
```

---

## 1. Criar diretórios

```bash
sudo mkdir -p /srv/data/scratch/metube
sudo chown -R oinq:oinq /srv/data/scratch/metube

sudo mkdir -p /srv/docker/services/metube/config
sudo chown -R oinq:oinq /srv/docker/services/metube

sudo mkdir -p /mnt/raid/media/music
sudo mkdir -p /mnt/raid/media/homevideo
sudo mkdir -p /mnt/raid/media/books
sudo chown -R oinq:oinq /mnt/raid/media
```

---

## 2. Docker Compose (MeTube)

Ficheiro:

```
/srv/docker/services/metube/docker-compose.yml
```

Conteúdo:

```yaml
services:
  metube:
    image: ghcr.io/alexta69/metube:latest
    container_name: metube
    restart: unless-stopped

    ports:
      - "8081:8081"

    volumes:
      - /srv/data/scratch/metube:/downloads
      - /srv/docker/services/metube/config:/config

    environment:
      - UID=1000
      - GID=1000
      - UMASK=022
```

Subir:

```bash
cd /srv/docker/services/metube
docker compose up -d
```

Confirmar mounts:

```bash
docker inspect metube --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'
```

Esperado:

```
/srv/data/scratch/metube -> /downloads
/srv/docker/services/metube/config -> /config
```

---

## 3. Sorter automático (staging → RAID)

Script:

```
/srv/docker/services/metube/sort-metube.sh
```

```bash
#!/usr/bin/env bash
set -euo pipefail

INBOX="/srv/data/scratch/metube"

MUSIC="/mnt/raid/media/music"
VIDEO="/mnt/raid/media/homevideo"
BOOKS="/mnt/raid/media/books"

# Longform threshold: >100MB = audiobook/podcast
AUDIOBOOK_MIN_SIZE=$((100 * 1024 * 1024))

echo "== MeTube sorter $(date) =="

# Process only stable files (not modified in last 60s)
is_stable() {
  local file="$1"
  local now mtime age
  now=$(date +%s)
  mtime=$(stat -c %Y "$file")
  age=$((now - mtime))
  [ "$age" -ge 60 ]
}

shopt -s nullglob

# --- AUDIO ---
for f in "$INBOX"/*.mp3 "$INBOX"/*.m4a "$INBOX"/*.flac; do
  [ -e "$f" ] || continue

  if ! is_stable "$f"; then
    echo "Skipping (still writing): $(basename "$f")"
    continue
  fi

  size=$(stat -c %s "$f")

  if [ "$size" -ge "$AUDIOBOOK_MIN_SIZE" ]; then
    echo "Audio (big) -> books: $(basename "$f")"
    mv -n "$f" "$BOOKS/"
  else
    echo "Audio -> music: $(basename "$f")"
    mv -n "$f" "$MUSIC/"
  fi
done

# --- AUDIOBOOK FORMAT ---
for f in "$INBOX"/*.m4b; do
  [ -e "$f" ] || continue

  if ! is_stable "$f"; then
    continue
  fi

  echo "Audiobook -> books: $(basename "$f")"
  mv -n "$f" "$BOOKS/"
done

# --- VIDEO ---
for f in "$INBOX"/*.mp4 "$INBOX"/*.mkv "$INBOX"/*.webm; do
  [ -e "$f" ] || continue

  if ! is_stable "$f"; then
    continue
  fi

  echo "Video -> homevideo: $(basename "$f")"
  mv -n "$f" "$VIDEO/"
done

# --- CLEANUP leftovers ---
for f in "$INBOX"/*.opus; do
  [ -e "$f" ] || continue

  if ! is_stable "$f"; then
    continue
  fi

  echo "Deleting leftover: $(basename "$f")"
  rm -f "$f"
done

echo "== Done =="
```

Permissões:

```bash
chmod +x /srv/docker/services/metube/sort-metube.sh
```

Teste manual:

```bash
/srv/docker/services/metube/sort-metube.sh
```

---

## 4. Automação via Cron

Editar crontab:

```bash
crontab -e
```

Adicionar:

```cron
*/2 * * * * /srv/docker/services/metube/sort-metube.sh >> /srv/docker/services/metube/sorter.log 2>&1
```

Confirmar:

```bash
crontab -l
```

Logs:

```bash
tail -f /srv/docker/services/metube/sorter.log
```

Cron é persistente após reboot (Ubuntu service `cron`).

---

## Resultado Final

- MeTube descarrega para scratch (`/srv/data/scratch/metube`)
- Sorter move automaticamente para RAID
- Audiobooks detectados por tamanho (>100MB)
- Ficheiros incompletos são ignorados (60s stability window)
- `.opus` intermédios são removidos
