\# oinqserver



\## Role

Main home server running Docker services, storage, and infrastructure tooling.



\## Hardware

\- Model: HP ProLiant MicroServer Gen8

\- CPU: Intel Xeon E3-1265L v2 (4 cores / 8 threads)

\- RAM: 16 GB DDR3 ECC



\## Operating System

\- Ubuntu 24.04.2 LTS (x86\_64)

\- Kernel: 6.8.0-90-generic



\## Storage Layout

\- System disk:  

&nbsp; - 60 GB ADATA SP900 SSD  

&nbsp; - Mounted at `/` (ext4)



\- Local array:  

&nbsp; - RAID5 (4 × 3 TB)  

&nbsp; - Mounted at `/mnt/raid` (~8.2 TB, ext4)



\- NAS mount:  

&nbsp; - Synology DS920+  

&nbsp; - Mounted at `/mnt/nas\_media`  

&nbsp; - Source: `//192.168.20.3/data/media`  

&nbsp; - Approx size: ~20 TB



\## Network

\- Hostname: `oinqserver`

\- Interface: bond0

\- IP address: 192.168.1.5

\- Gateway: 192.168.1.1

\- DNS: 192.168.1.1

\- Tailscale IP: 100.126.192.110

\- Tailscale DNS: 100.100.100.100



\## Docker Environment

\- Docker Engine: 27.5.1

\- Docker Compose: v2.40.1

\- Docker root directory: `/mnt/raid/docker-data`



\### Docker Networks

\- docker0: 172.17.0.1

\- Custom bridge: 172.18.0.0/16

\- Custom bridge: 172.20.0.0/16



\### Active Stacks / Services

\- Immich

\- Media stack:

&nbsp; - Radarr

&nbsp; - Sonarr

&nbsp; - Bazarr

&nbsp; - Prowlarr

&nbsp; - SABnzbd

&nbsp; - Jellyfin

\- LibreTranslate

\- Lingarr (unhealthy – SQLite lock / Hangfire issue)

\- Minecraft server  

&nbsp; - Data path: `/mnt/raid/minecraft-data`

\- Bumper (Ecovacs integration)

\- AzerothCore services



\## Notes

\- Prefer local services over cloud equivalents

\- Avoid breaking mounts: `/mnt/raid` and `/mnt/nas\_media` are critical

\- All containers currently running and expected to auto-restart



