\# OPNSense



\## Role

\- Gateway da rede

\- Firewall principal

\- DHCP master

\- DNS base



\## IP \& Interface

\- IP LAN: 192.168.1.1

\- Subnet: 192.168.1.0/24



\## DHCP

\- Serviço ativo: Kea DHCP

\- Range dinâmico: 192.168.1.235 – 192.168.1.253

\- Reservas DHCP: exportadas separadamente em `dhcp-reservations.md`



\## DNS

\- Atua como DNS primário para a rede

\- Encaminha pedidos filtrados para o AdGuard



\## Regras importantes

\- Nunca ativar DHCP em mais nenhum equipamento

\- Sempre exportar configuração antes de alterações grandes

\- Após alterações de rede, validar:

&nbsp; - DHCP leases

&nbsp; - Gateway

&nbsp; - DNS resolution



\## Backups

\- Sempre exportar config antes de mexer:

&nbsp; - System → Configuration → Backups



