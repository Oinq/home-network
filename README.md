Erebor Homelab — Single Source of TruthRegra principal: este ficheiro é a fonte única de verdade. Se não está aqui, oficialmente não existe.
Este documento substitui documentação antiga (oinqserver) e passa a ser a referência única e atual para o servidor erebor.
Objetivo: evitar informação dispersa, manter tudo coerente e permitir que qualquer mudança futura seja refletida aqui primeiro.
Resumo rápidoSistema: Ubuntu Server 24.04.3 LTS com boot UEFI e LVM.
Dados críticos: ZFS mirror 18TB + 18TB montado em /mnt/critical (estado saudável).
Storage auxiliar ativo:
/srv/docker-data (SSD 250GB) para dados do Docker
/mnt/media/movies (HDD 4TB)
/mnt/media/tv (HDD 4TB)
/srv/data/scratch (HDD 320GB)
Rede: gateway OPNSense 192.168.1.1, Erebor em 192.168.1.6.
Serviços ativos: Docker, Minecraft, Glances, Tailscale.
Regra de ouro: se não está neste ficheiro, oficialmente não existe.
Índice1) Visão geral
2) Hardware atual
3) Princípios de arquitetura
4) Layout lógico de paths
5) Docker
6) Serviços atualmente ativos
7) Estrutura planeada (media stack)
8) Backups
9) Regra operacional
10) Rede
11) OPNSense, DNS e AdGuard
12) Home Assistant
13) Victron & MQTT Integration
14) Regra estrutural de documentação
15) Storage real e estado atual (ZFS)
16) Storage não-ZFS (discos auxiliares)
1) Visão geralItemValorHostnameereborOSUbuntu Server 24.04.3 LTSBootUEFI com /boot e /boot/efi separadosLVM100 GB root, ~362 GB livreUpdatesunattended-upgrades ativoEstadoSistema estável, Docker validado, pronto para expansão2) Hardware atual (fonte de verdade)Qualquer alteração física de discos deve ser refletida aqui.
DiscoFunçãoSSD 500 GB (Samsung 860)Sistema operativo (LVM + /boot + EFI)SSD 250 GB (Samsung 750)Docker internals (/srv/docker-data)SSD 250 GB (Samsung 850)Livre / reservadoHDD 320 GB (WD)Scratch (/srv/data/scratch)HDD 4 TB (WD)Media – Filmes (/mnt/media/movies)HDD 4 TB (WD)Media – Séries (/mnt/media/tv)ZFS mirror 18 + 18 TBDados críticos (/mnt/critical)Bays livres5 / 12Nota: O ZFS mirror encontra-se operacional e validado (ver secção 15).
3) Princípios de arquiteturaRedundância onde importa (ZFS mirror para dados críticos)
Isolamento de risco em dados recuperáveis (discos independentes)
Dados descartáveis separados (scratch, downloads, NVR, etc)
Containers são descartáveis; dados persistentes vivem sempre fora do Docker
Bind mounts explícitos e legíveis, nunca volumes implícitos
Nada importante fica preso em /var/lib/docker
4) Layout lógico de paths (abstração estável)Estes paths são contratos estáveis. O disco físico por trás pode mudar sem afetar containers.
/srv/docker/              → configs persistentes de containers
/srv/docker/services/     → stacks organizados por função
/srv/docker-data/         → data-root do Docker
/srv/data/scratch/         → temporários, downloads, staging
/mnt/media/movies          → filmes
/mnt/media/tv              → séries
/mnt/critical              → dados críticos (ZFS mirror)Se um mount mudar de disco, este documento deve ser atualizado.
5) DockerEstado atual
Docker Engine instalado via repositório oficial
Docker Compose (plugin) funcional
Restart policy padrão: unless-stopped
Regras obrigatóriasNenhum serviço com dados importantes pode usar volumes anónimos
Todos os serviços usam bind mounts explícitos
Cada stack vive na sua própria pasta
docker-compose.yml + .env + subpastas de dados ficam juntos
Convenções operacionais (contrato técnico)Estrutura de stacks
Cada serviço em: /srv/docker/services/<nome-do-serviço>
Dentro da pasta existem sempre, no mínimo:
docker-compose.yml
config/ (quando aplicável)
data/ ou paths de bind mounts claramente documentados
Redes Docker
Evitar usar a rede default bridge sem necessidade
Stacks multi-container devem usar rede própria definida no compose
Expor portas apenas quando necessário (princípio do menor privilégio)
Persistência de dados
Tudo o que precisa sobreviver a rebuild de container deve estar em bind mount
Paths usados devem respeitar a secção 4
Gestão de versões
Serviços críticos devem usar tags explícitas (evitar latest)
Atualizações feitas de forma controlada, com possibilidade de rollback
Segurança básica
Containers como utilizador não-root sempre que possível
Portas expostas minimizadas
Segredos nunca hardcoded em docker-compose.yml (usar .env)
Princípio estruturalDocker é tratado como camada descartável. O que é durável:
Dados persistentes nos bind mounts
docker-compose.yml
Estrutura de diretórios em /srv/docker/
Se for necessário apagar /var/lib/docker, todos os serviços devem ser reconstruíveis com:
docker compose up -d6) Serviços atualmente ativosMinecraftItemValorStack/srv/docker/services/minecraftDados/srv/docker-data/minecraft (temporário)Containeritzg/minecraft-serverEstadoValidado com reboot + cliente realMonitoringGlances como serviço systemd
Home Assistant ligado via integração Glances
Métricas visíveis: CPU, RAM, disco, temperaturas, rede, uptime
TailscaleErebor como node ativo
Subnet routing: 192.168.1.0/24
Conectividade validada externamente
7) Estrutura planeada para media stack (exemplo futuro)Estrutura alvo:
/srv/docker/services/media/
  sabnzbd/
    docker-compose.yml
    config/
  radarr/
    docker-compose.yml
    config/
  sonarr/
    docker-compose.yml
    config/Dados partilhados entre serviços:
/srv/data/scratch/downloads/incomplete
/srv/data/scratch/downloads/complete
/mnt/media/movies
/mnt/media/tv8) Backups (estratégia real e operacional)8.1 Estado atual (proteção do tesouro)Ativo mais crítico: fotos de família.
Cópias existentes atualmente:
NAS (fonte principal)
oinqserver (segunda cópia histórica)
Erebor (disco interno de 1 TB)
Disco externo 2 TB (cópia offline em criação)
Objetivo desta fase:
Permitir reestruturação de discos sem risco
Garantir pelo menos duas cópias offline e fisicamente separadas
Estado considerado seguro:
1 cópia online ativa
2 cópias offline guardadas
Enquanto esta condição não estiver garantida, não são feitas operações destrutivas em nenhum disco.
8.2 Política de backup permanente (pós-reestruturação)Dados críticos:
/mnt/critical/**
Configurações importantes (HA, containers críticos, configs manuais)
Regras:
1 cópia primária no Erebor
1 cópia secundária automática noutro sistema
1 cópia offline periódica
Redundância (ex: ZFS mirror) não é backup.
8.3 Mecanismo técnico previsto (a implementar)Ferramenta: rsync ou restic
Origem: /mnt/critical
Destino: NAS ou disco dedicado
Frequência: diária ou semanal (a definir)
Logs verificáveis
Backup offline:
Discos USB dedicados a backup
Ligados apenas durante cópia
Guardados fisicamente separados
8.4 Regra operacional de segurançaNunca:
Reestruturar storage
Destruir pools
Reutilizar discos
Formatar volumes
Sem antes confirmar:
Existem múltiplas cópias válidas
Pelo menos uma é offline
Se houver dúvida, assume-se que não está seguro.
9) Regra operacionalSempre que mudar:
discos físicos
mounts
estrutura de paths
serviços
decisões de arquitetura
→ Este documento deve ser atualizado primeiro.
10) Rede (fonte de verdade)ElementoValorSubnet192.168.1.0/24Gateway192.168.1.1 (OPNSense)DHCP dinâmico192.168.1.235 – 192.168.1.253IPs críticos:
DispositivoIPOPNSense192.168.1.1Home Assistant192.168.1.2NAS192.168.1.3Erebor192.168.1.6Cerbo GX192.168.1.13NVR192.168.1.51Switch GS748T192.168.1.81Regra absoluta:
Apenas o OPNSense fornece DHCP
11) OPNSense, DNS e AdGuardArquitetura de DNS:
Clientes LAN → AdGuard Home (OPNSense :53)
                    ↓
               Unbound (OPNSense :5353)
                    ↓
                 InternetImplementação:
AdGuard Home no OPNSense (binário FreeBSD oficial)
Serviço ativo na porta 53
Interface Web: http://192.168.1.1:3000
Unbound como upstream na porta 5353
Resultado:
DNS funcional mesmo sem servidores ligados
Filtragem ao nível da infraestrutura
Observabilidade por cliente
12) Home AssistantItemValorPlataformaHome Assistant OSIP192.168.1.2Acesso remotoTailscaleFunçãoControlador central de automaçãoEscopo:
Plataforma HA
Integrações genéricas (Glances, notificações, dashboards)
Estrutura base (não específica de sistemas externos)
13) Victron & MQTT Integration (infraestrutura crítica)Resumo técnicoCerbo GX integrado via MQTT local (bridge Mosquitto)
Tópicos nativos Venus OS: N/<serial>/# e R/<serial>/#
Sensores definidos via packages YAML
Integração totalmente local (sem cloud)
Arquitetura operacionalCerbo publica:
N/<serial>/<service>/<path>
Exemplo:
N/<serial>/battery/0/Soc
HA consome diretamente os tópicos
Comunicação bidirecional:
Leitura: N/<serial>/#
Escrita: R/<serial>/#
Como adicionar um sensor novoModelo base (exemplo):
sensor:
  - platform: mqtt
    name: "Victron Battery Power"
    state_topic: "N/<serial>/system/0/Dc/Battery/Power"
    unit_of_measurement: "W"
    device_class: power
    state_class: measurementRegras:
Não duplicar sensores para o mesmo tópico
Manter nomenclatura consistente
Cada sensor novo deve ser documentado aqui
Localização real da bridge MosquittoA bridge vive no add-on oficial Mosquitto broker do HA.
Caminho real do ficheiro:
\\192.168.1.2\share\mosquitto\mosquitto.confAlterações neste ficheiro sobrevivem a reboots e updates do add-on.
Procedimento se o Cerbo mudar de IPDescobrir novo IP no OPNSense (DHCP leases)
Abrir:
\\192.168.1.2\share\mosquitto\mosquitto.confAlterar linha address x.x.x.x
Guardar ficheiro
Reiniciar add-on Mosquitto no HA
Resultado esperado:
Bridge reconecta
Tópicos reaparecem
Sensores retomam automaticamente
Nota: o Cerbo deve ter sempre reserva DHCP. Este procedimento é apenas recuperação de falha.
Capacidade energética (contexto)ElementoValorInversores3 × MultiPlus 48/5000-70MPPT450/200Baterias4 × 5 kWhAutonomia~8 meses off-gridSistema considerado infraestrutura crítica da casa.
14) Regra estrutural de documentaçãoEste ficheiro é a única fonte de verdade
Docs antigos passam a ser material histórico
Qualquer alteração real deve ser refletida aqui no mesmo dia
Se documento e realidade divergirem, o documento está errado
15) Storage real e estado atual (ZFS — fonte de verdade)Pool ZFS de dados críticosPool ativo:
Nome: critical
Tipo: mirror
Discos:
WDC WD180EDGZ (18 TB)
WDC WD180EDGZ (18 TB)
Identificação via: /dev/disk/by-id
Mountpoint: /mnt/critical
Estado: ONLINE, 0 erros (zpool status limpo)
Propriedades ativas no pool:
ashift=12
compression=lz4
atime=off
autotrim=on
ACL e xattrs ativos
O pool foi validado após:
limpeza destrutiva dos discos (mdadm, sgdisk, wipefs)
criação nova do mirror
mudança física de cabos SATA → backplane
Sem necessidade de reimportação e sem degradação
Conclusão: configuração robusta e independente da ordem das portas.
Integridade dos dados migradosDados já migrados para ZFS:
Fotos de família (~963 GB)
Cópia realizada com rsync e verificada com execução incremental posterior:
Resultado confirmado:
69 995 ficheiros
~963 GB
0 diferenças
Estrutura, timestamps e tamanhos coerentes
Os dados em /mnt/critical são considerados consistentes.
Estado SMART dos discos validadosDiscos atualmente considerados saudáveis:
SSD Samsung 750 EVO 250 GB
SSD Samsung 850 EVO 250 GB
HDD WD 320 GB
HDD WD 4 TB (x2)
Dois discos 18 TB do pool ZFS
Nenhum disco apresenta:
sectores realocados
sectores pendentes
sectores incorrigíveis
16) Storage não-ZFS (discos auxiliares)Esta secção reflete o estado real implementado dos discos auxiliares após limpeza completa, formatação e montagem persistente.
Filesystems criadosDiscoLabelFSFunçãoMountpointsdadocker-dataext4Docker data-root/srv/docker-datasdd——Reservado—sdemoviesext4Media (filmes)/mnt/media/moviessdftvext4Media (séries)/mnt/media/tvsdgscratchext4Temporários/srv/data/scratchMontagem persistente (/etc/fstab)Entradas ativas:
LABEL=docker-data  /srv/docker-data      ext4  defaults,noatime  0 2
LABEL=movies       /mnt/media/movies     ext4  defaults,noatime  0 2
LABEL=tv           /mnt/media/tv         ext4  defaults,noatime  0 2
LABEL=scratch      /srv/data/scratch     ext4  defaults,noatime  0 2Estado validadoTodos os mounts testados com umount + mount -a
Todos reaparecem corretamente após reload do systemd
df -h confirma tamanhos e localizações corretas
Nenhum impacto nos discos ZFS ou no disco de sistema
Conclusão: a camada de storage auxiliar está concluída e estável.
Nota finalEste documento reflete o estado real e operacional do servidor Erebor após:
Limpeza controlada dos discos
Reestruturação completa do layout de storage
Implementação de mounts persistentes alinhados com a arquitetura
A partir daqui, qualquer evolução (Docker, serviços, automações, backups, etc.) deve ser documentada aqui primeiro.
