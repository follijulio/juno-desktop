# Arquitetura e recuperação

## Fronteiras e destinos

`install.sh` coordena verificações, pacotes, aplicativos, recursos locais, GNOME e transações. Os alvos são Arch Linux e Zorin OS 18.x Core/Pro x86_64, usuário comum, diretórios XDG padrão e systemd/D-Bus funcionais. A seleção vem da identidade e versão em `/etc/os-release`; não é um instalador genérico para Ubuntu ou derivados. Zorin exige GNOME e GDM existentes e não converte a edição Lite/XFCE. As configurações da conta são preparadas como usuário comum. Scripts de instalação remotos e configurações do usuário não são executados.

No Arch, `sudo` é usado para pacman, multilib e habilitação conservadora do GDM. No Zorin, APT instala dependências ausentes com `--no-install-recommends --no-upgrade --no-remove`, após atualizar o índice, e preserva as fontes de pacotes existentes. A seleção padrão contém 39 pacotes essenciais; `--with-dev-tools` acrescenta 20 ferramentas de desenvolvimento e pode acompanhar `--dry-run`. A opção não altera a lista completa do Arch nem remove ferramentas preexistentes. Qt6 Wayland fica fora da seleção Zorin; `xdg-utils` é explícito para integração de arquivos e URLs. Não são adicionados PPAs, arquitetura i386 ou pacotes para substituir áudio e gerenciador de login. A base Ubuntu 24.04 e a distinção entre GNOME e Lite estão descritas nos [detalhes oficiais do Zorin](https://zorin.com/os/details/).

O inventário DPKG é consultado em lote por operação e armazenado somente em um array local. Pacotes `amd64` e `all` com estado instalado e íntegro satisfazem dependências, inclusive os retidos; registros i386 ou incompletos não satisfazem. APT sem dependências ausentes dispensa `sudo`, atualização de índices e reinstalação. Após instalar, o inventário é lido novamente para validar o resultado; uma falha de consulta interrompe a operação antes de aplicar configurações. Os inventários de versões antes/depois permanecem registrados separadamente.

| Destino relativo ao diretório pessoal | Conteúdo |
| --- | --- |
| `.config/kitty` | Terminal Bash, fonte e paleta |
| `.config/juno-gnome` | Tema Oh My Posh e integração local Bash/GNOME |
| `.local/share/fonts/juno` | Space Mono original e metadados; no Zorin, quatro variantes de JetBrainsMono Nerd Font Mono com licença |
| `.local/share/juno-desktop` | Wallpaper editorial e galeria |
| `.bashrc` | Bloco identificado de inicialização interativa |
| `.config/Code/User/settings.json` | Fontes e perfil Juno Bash, preservando JSONC |
| `.config/environment.d/90-juno.conf` | Caminhos dos aplicativos locais e exports Flatpak na sessão GNOME |
| `.local/share/icons/Juno` | Tema SVG local dos ícones de aplicativos e metadados de integridade |

No Arch, as sete chaves GNOME gerenciadas são `font-name`, `document-font-name`, `monospace-font-name` e `icon-theme` de `org.gnome.desktop.interface`, além de `picture-uri`, `picture-uri-dark` e `picture-options` de `org.gnome.desktop.background`. No Zorin, a oitava chave é `org.gnome.desktop.interface enable-animations`, aplicada como booleano `true` para manter animações de janelas e painel. Reinstalar reativa as animações após uma aplicação do perfil anterior com `false`; o valor substituído continua registrado no backup. Nenhuma base dconf inteira é copiada ou carregada.

Ancestrais dos destinos precisam permanecer no diretório pessoal e pertencer à conta. Staging e estado são privados. Arquivos individuais editados, como `.bashrc` e JSONC, devem ser arquivos regulares próprios; links são recusados antes da aplicação. O merge usa uma cópia dos inputs e interrompe se os originais divergirem antes do backup ou da substituição. Destinos Hyprland antigos são aceitos na recuperação de manifestos legados e não fazem parte da aplicação GNOME.

## Aplicação

1. Validar plataforma, conta, caminhos, sessão gráfica encerrada, espaço e HTTPS.
2. Obter bloqueio por usuário e recuperar o diário anterior antes de outra aplicação.
3. Conferir recursos; instalar dependências conforme a distribuição e aplicativos/Oh My Posh com integridade verificada. No Arch, preparar multilib com backup e executar atualização completa. No Zorin, instalar somente dependências ausentes por APT, sem atualização de distribuição.
4. Preparar recursos no sistema de arquivos de cada destino, editar Bash/JSONC sem executar configurações existentes e registrar valores GNOME anteriores e desejados.
5. Validar staging, fontes, scripts, JSONC, schemas, tipos e permissões GNOME. Comparar com o estado atual para evitar backup duplicado quando nada mudou.
6. Criar e verificar backup, manifesto e checksums; conferir que o estado não mudou durante a preparação.
7. Persistir diário, substituir destinos por renomeação e aplicar somente chaves GNOME autorizadas. Sincronizar e conferir persistência.
8. Reconstruir o cache somente do diretório de fontes gerenciado, conferir famílias, finalizar diário e remover temporários. Após rollback sem esse diretório regular, usar descoberta incremental do Fontconfig.
9. Conferir gerenciador de login. Preservar gerenciadores existentes, máscaras e alvo de boot; habilitar GDM somente quando não houver outro gerenciador configurado. Não iniciar ou reiniciar serviços de login.

Cada renomeação é atômica no sistema de arquivos correspondente. A alteração de vários destinos e chaves GNOME é uma transação recuperável. Sinais tratáveis acionam restauração; interrupções abruptas dependem do diário na execução seguinte.

## Backups e recuperação

O estado fica em `~/.local/state/juno-desktop/`. Backups usam manifesto TSV com versão, usuário, diretório pessoal, destinos e tipos originais, além de `configs.tar.gz` e seu SHA-256. Backups e diários v2 também registram a contagem de destinos para detectar truncamento; backups v2 acrescentam snapshot GNOME por chave e checksum. Ausência de valor explícito é distinta do valor padrão efetivo; a restauração usa `reset()` para voltar ao padrão.

IDs, membros do arquivo e destinos são validados antes da extração. Restaurar cria outro backup do estado substituído. Backups e diários v1 continuam usando o conjunto de destinos registrado originalmente, sem snapshot GNOME. Rollback v2 precisa de PyGObject/Gio, schemas e backend dconf locais, sem internet ou `sudo`.

O documento JSON de preferências tem versão independente do manifesto: snapshots GNOME v1 contêm exatamente as seis chaves anteriores; v2 contêm as sete, incluindo `icon-theme`; v3 contêm as oito do Zorin, incluindo o booleano `enable-animations`. O manifesto de arquivos continua v2. Ao restaurar, o snapshot anterior usa o próprio backup como modelo de escopo, independentemente do perfil atual. Assim, backups e diários antigos não passam a alterar uma preferência que nunca registraram: os de seis chaves preservam ícones e animações atuais; os de sete preservam animações. A recuperação recusa conjuntos de chaves divergentes antes de gravar valores.

Após falha, confira mensagem e `logs/`. Se os arquivos anteriores foram restaurados, corrija a causa e execute novamente fora da sessão gráfica. Preserve `pending.tsv`, áreas `.juno-stage.*`, snapshots temporários e backups: a próxima execução verifica caminhos e conteúdo antes de recuperar, sem executar o diário como código.

Se houver recuperação **ambígua**, pare de editar destinos e preserve cópias do estado e temporários. Compare manifesto, snapshots GNOME, cópias `before`, `old`, `new`, `reference` e estado atual antes de intervir. Não remova o diário para forçar outra aplicação. Alterações concorrentes divergentes interrompem a recuperação sem autorizar sua substituição.

## Operações fora do rollback

Operações de pacman/APT, hooks e pacotes não são desfeitos. Registros em `packages/` mostram versões anteriores e posteriores. Falhas do gerenciador de pacotes impedem aplicar configurações. O instalador não inicia nem reinicia serviços; o comportamento dos scripts de manutenção dos pacotes APT precisa ser conferido no teste Zorin real.

Spotify usa Flatpak por usuário com remote validado. No Zorin, Steam e Discord também são opcionais e usam Flatpak por usuário quando ausentes; instalações nativas e Flatpak existentes são preservadas.

No Arch, VS Code original fica em `.local/share/juno-apps/vscode`, com versões anteriores e launchers substituídos preservados. Sua instalação exige checksum HTTPS da Microsoft, identidade do produto e inspeção de caminhos e links do arquivo antes da extração. No Zorin, o `.deb` oficial é verificado por SHA-256, identidade, arquitetura amd64 e versão antes da instalação local via APT. A opção de adicionar o repositório Microsoft fica desativada. O wrapper chama o executável no caminho nativo do pacote para manter sua integração de sandbox, sem `--no-sandbox`; releases anteriores por usuário não são removidas. O pacote instalado e a escolha do executável ficam fora do rollback de configurações.

No Arch, o launcher gerado do VS Code usa `Icon=visual-studio-code`. No Zorin, a entrada nativa do pacote é preservada, incluindo ações e associação de arquivos; o Juno não acrescenta outra entrada visível. Uma entrada Juno anterior gerenciada é preservada em backup e ocultada para evitar duplicação. O tema inclui aliases para o nome de ícone nativo. Seu PNG original é instalado individualmente em `.local/share/icons/hicolor/256x256/apps`, com backup do arquivo substituído. Esse recurso acompanha a instalação do aplicativo e permanece fora do rollback de configurações; os outros ícones hicolor são preservados.

Oh My Posh fica em `.local/share/juno-apps/oh-my-posh`, com releases oficiais verificadas por SHA-256 e versão. A ativação ocorre somente após validar o binário; falhas de download ou verificação preservam a versão atual. Binários, aplicativos e seus apontadores de versão ficam fora do rollback; `.bashrc`, tema e preferências do editor ficam dentro dele.

No Arch, multilib preserva `/etc/pacman.conf` em `/etc/pacman.conf.juno-*.bak`, confere o backup e valida a configuração preparada. Essa mudança não é desfeita automaticamente após instalar pacotes; repositórios personalizados e de teste existentes são preservados. No Zorin, Steam e Discord usam Flatpak por usuário e multilib não é executado.

A habilitação do GDM tem registro separado e não desativa outro gerenciador. O serviço é `gdm.service` no Arch e `gdm3.service` no Zorin. Uma tentativa interrompida é diagnosticada na execução seguinte; não há troca automática de gerenciador nem mudança do alvo de boot. Logs indicam como desfazer somente a habilitação realizada.

## Sessão GNOME

Painel, launcher, notificações, captura, bloqueio, áudio, brilho e energia pertencem ao GNOME. No Zorin, layouts e extensões preexistentes continuam ativos; o Juno não instala nem remove extensões. Scripts históricos Hyprland não são iniciados. A seleção de wallpaper usa GSettings e não é reaplicada no login; reinstalar reaplica o perfil inicial com backup.

Bash recebe integração interativa local, com caminhos protegidos e inicialização sem duplicação. O shell de login da conta não é alterado. O tema compartilhado Oh My Posh mantém diretório, HEAD Git e código de erro; o segmento Git usa `fetch_status=false`, `fetch_upstream_icon=false` e timeout de 200 ms, sem varredura das alterações do repositório. Tema de janelas, teclado, suspensão e atalhos globais permanecem nas Configurações nativas. Animações ficam sem alteração no Arch e são mantidas ativadas com backup no perfil Zorin. Serviços, indexadores, segurança, parâmetros de kernel e políticas de energia permanecem como configurados na distribuição.

O tema de ícones segue a [especificação freedesktop](https://specifications.freedesktop.org/icon-theme/latest/), com SVGs escaláveis no contexto de aplicativos e herança Adwaita/hicolor. A validação confere o índice, todos os checksums, aliases e SVGs antes da substituição; referências externas e conteúdo ativo são recusados. A reinstalação não exige extensões GNOME nem altera arquivos `.desktop` dos pacotes do sistema.

No Zorin, o staging de fontes acrescenta os quatro TTFs JetBrainsMono Nerd Font Mono da release Nerd Fonts 3.5.1, distribuídos localmente com licença e SHA-256. O destino permanece o mesmo conjunto transacional de fontes, com backup e recuperação. No Arch, essa família continua vindo do pacote da distribuição. A validação inspeciona os TTFs locais e confere as famílias disponíveis antes de aplicar as configurações.

`juno_refresh_font_cache` força a reconstrução apenas de `~/.local/share/fonts/juno` quando ele é um diretório regular: a substituição transacional pode manter timestamps antigos, tornando insuficiente uma atualização incremental desse destino. Caches válidos de fontes do sistema permanecem aproveitáveis. Caso o rollback remova esse diretório ou restaure um link anterior, usa `fc-cache` incremental, sem reconstrução global forçada. O mesmo procedimento atende instalação, restauração e recuperação de falhas.
