AdGuard Home no OPNsense (DNS resiliente local)
Objetivo

Remover a dependência do servidor para DNS e passar o serviço diretamente para o firewall (OPNsense), mantendo controlo total, filtragem e observabilidade.

Arquitetura final
Clientes LAN → AdGuard Home (OPNsense :53)
                      ↓
                 Unbound (OPNsense :5353)
                      ↓
                   Internet

Implementação

AdGuard Home instalado diretamente no OPNsense (binário FreeBSD oficial)

Serviço ativo na porta 53 (DNS principal da rede)

Interface Web disponível em:

http://192.168.1.1:3000


Unbound movido para a porta 5353 e usado como upstream do AdGuard:

upstream_dns:
  - 127.0.0.1:5353


AdGuard configurado para escutar em:

bind_hosts:
  - 0.0.0.0
port: 53

Resultado

Todos os clientes usam automaticamente o DNS do OPNsense

Bloqueio funcional de trackers/ads (ex: doubleclick.net → 0.0.0.0)

Logs por cliente disponíveis no AdGuard

Servidor pode ser desligado sem impacto na conectividade

Infraestrutura mais simples e resiliente

Segurança adicional aplicada
chmod 700 /root/AdGuardHome
chmod 600 /root/AdGuardHome/AdGuardHome.yaml
