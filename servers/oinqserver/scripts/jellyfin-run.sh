#!/usr/bin/env bash
set -euo pipefail
docker stop jellyfin 2>/dev/null || true
docker rm jellyfin 2>/dev/null || true

docker run -d \
  --name jellyfin \
  --restart unless-stopped \
  -p 8096:8096 \
  -e PUID=1000 -e PGID=1000 -e TZ=Europe/Brussels \
  -e NVIDIA_VISIBLE_DEVICES=all \
  -e NVIDIA_DRIVER_CAPABILITIES=compute,video,utility \
  --gpus all \
  -v /mnt/raid/containers/jellyfin/config:/config \
  -v /mnt/raid/containers/jellyfin/cache:/cache \
  -v /mnt/nas_media:/media \
  lscr.io/linuxserver/jellyfin:latest
