\# AdGuard Home



\## Role

\- DNS filtering (ads, tracking, malware)

\- Não faz DHCP



\## Integração com a rede

\- Recebe queries DNS do OPNSense

\- Atua apenas como upstream DNS filtrado



\## Regras importantes

\- DHCP deve estar sempre desativado no AdGuard

\- Nunca deve distribuir IPs

\- Se algo na rede ficar instável, confirmar primeiro:

&nbsp; - DHCP desligado

&nbsp; - DNS configurado corretamente



\## Manutenção

\- Atualizar listas de bloqueio regularmente

\- Fazer backup da configuração antes de upgrades grandes



