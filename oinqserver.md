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





## Disk write-cache benchmarking

We ran controlled fio benchmarks on the main storage array (**mdadm RAID5, 4× HDD, ext4, `/dev/md127` mounted at `/mnt/raid`**) to quantify the impact of enabling drive write-cache.  
Write cache was toggled explicitly using `hdparm -W0` (off) and `hdparm -W1` (on) across all member disks (`/dev/sda`–`/dev/sdd`), and each workload was executed twice with identical parameters.

Two representative workloads were tested:

- **Test A (sync workload, fsync-heavy)** simulates SQLite/journaling/Docker metadata behavior.  
  Results improved from **41 → 74 IOPS (+80%)** and average latency dropped from **24.35 ms → 13.4 ms (-45%)**.

- **Test B (concurrent workload, multiple writers)** simulates several services writing in parallel.  
  Results improved from **49 → 90 IOPS (+84%)**, bandwidth from **793 KiB/s → 1442 KiB/s (+82%)**, and average latency reduced from **634 ms → 353 ms (-44%)**.

Across both independent workloads, enabling write cache consistently delivered **~80–85% throughput improvement** and **~40–50% latency reduction**, demonstrating a measurable and repeatable performance gain on this hardware.

---

### Commands used

#### Toggle write cache
```bash
# Disable write cache (baseline)
for d in /dev/sda /dev/sdb /dev/sdc /dev/sdd; do
  sudo hdparm -W0 $d
done

# Enable write cache (test)
for d in /dev/sda /dev/sdb /dev/sdc /dev/sdd; do
  sudo hdparm -W1 $d
done

# Verify state
for d in /dev/sda /dev/sdb /dev/sdc /dev/sdd; do
  sudo hdparm -W $d
done


sudo fio --name=baseline \
  --filename=/mnt/raid/fio-testfile \
  --size=2G \
  --rw=randwrite \
  --bs=4k \
  --iodepth=32 \
  --numjobs=1 \
  --direct=1 \
  --time_based \
  --runtime=30 \
  --group_reporting


sudo fio --name=realworld \
  --filename=/mnt/raid/fio-testfile \
  --size=2G \
  --rw=randwrite \
  --bs=16k \
  --iodepth=8 \
  --numjobs=4 \
  --ioengine=libaio \
  --direct=1 \
  --time_based \
  --runtime=30 \
  --group_reporting
