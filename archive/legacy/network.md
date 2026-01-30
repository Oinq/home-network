\# Network Overview



\## Subnet

\- Network: 192.168.1.0/24

\- Gateway: 192.168.1.1 (OPNSense)



\## DHCP

\- DHCP Server: OPNSense

\- Dynamic range: 192.168.1.235 – 192.168.1.253



\## DNS

\- Primary DNS: OPNSense

\- Filtering DNS: AdGuard Home



\## Critical IPs

\- OPNSense: 192.168.1.1

\- Home Assistant: 192.168.1.2

\- NAS: 192.168.1.3

\- oinqserver: 192.168.1.5

\- Cerbo GX: 192.168.1.13

\- Switch (GS748T): 192.168.1.81

\- NVR: 192.168.1.51



\## Rules

\- Only OPNSense provides DHCP

\- No other device should ever run DHCP



