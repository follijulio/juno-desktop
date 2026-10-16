# Arquitetura e recuperação

## Fronteiras

O ponto de entrada `install.sh` coordena verificação, pacotes, aplicativos, galeria, validação e transações. Não executa scripts remotos. O pacman e a habilitação controlada de multilib usam `sudo`; downloads e instalação do VS Code/Spotify ocorrem como usuário comum. Nenhuma configuração de usuário é criada como root.

O alvo é Arch Linux x86_64 com diretórios XDG padrão, conta comum e systemd/D-Bus funcionais. O compositor suportado é Hyprland 0.56.x. Versões fora dessa faixa abortam antes da substituição de dotfiles; uma atualização de pacotes já realizada permanece registrada.

## Caminhos gerenciados

Todos os caminhos são relativos ao diretório pessoal canônico:

| Destino | Conteúdo |
| --- | --- |
| `.config/hypr` | Compositor, módulos Lua, bloqueio e inatividade |
| `.config/waybar` | Configuração base e CSS |
| `.config/rofi` | Launcher e tema |
| `.config/mako` | Notificações |
| `.config/kitty` | Terminal |
| `.config/juno` | Scripts e biblioteca da sessão |
| `.config/xdg-desktop-portal` | Seleção dos backends de portal |
| `.local/share/fonts/juno` | Space Mono original e metadados |
| `.local/share/juno-desktop` | Wallpaper editorial, fonte vetorial e galeria do usuário |

Os ancestrais precisam pertencer ao usuário e permanecer dentro do seu diretório pessoal. Um destino gerenciado que já seja link é tratado como objeto; seu conteúdo externo não é seguido. Áreas de staging e estado são privadas.

## Aplicação

1. Validar plataforma, conta, caminhos, sessão encerrada, espaço e HTTPS.
2. Obter bloqueio por usuário e recuperar um diário anterior, se existir.
3. Conferir recursos locais; habilitar multilib com backup quando necessário; instalar/atualizar pacotes oficiais, Spotify e VS Code original.
4. Copiar recursos para staging no mesmo sistema de arquivos de cada destino.
5. Copiar e conferir a galeria, validar scripts, JSON, famílias de fontes e o parser real do Hyprland.
6. Comparar com a instalação atual. Se idêntica, remover staging sem backup duplicado.
7. Criar e verificar backup compactado, manifesto e checksum; guardar cópia anterior para recuperação.
8. Persistir diário e substituir cada destino por renomeação.
9. Atualizar cache das fontes e conferir resolução das famílias.
10. Finalizar o diário e remover áreas temporárias.

Cada renomeação é atômica em seu sistema de arquivos. A mudança de vários destinos é uma transação recuperável, não uma única operação atômica global. Sinais tratáveis disparam restauração; interrupções abruptas dependem do diário na execução seguinte.

## Recuperar uma falha

Após uma falha normal, confira a mensagem e o registro em `logs/`. Se o instalador restaurou os arquivos anteriores, corrija a causa e execute novamente fora da sessão gráfica.

Se existir `pending.tsv`, preserve-o junto das áreas `.juno-stage.*` e dos backups. A próxima execução com bloqueio verifica a correspondência dos caminhos e do conteúdo antes de recuperar. O instalador não executa o conteúdo do diário como código.

Se a recuperação for **ambígua**, pare de editar os destinos. Copie o diretório de estado e as áreas temporárias para outro local seguro antes de qualquer intervenção. Compare o manifesto, as cópias `before`, `old`, `new` e `reference` das áreas indicadas pelo diário e os arquivos atuais. Preserve edições antes de mover arquivos. Não remova manualmente o diário para forçar uma nova instalação.

Os backups usam um manifesto TSV com usuário, diretório pessoal, destinos e tipos originais, além do arquivo `configs.tar.gz` e de `archive.sha256`. IDs e membros do arquivo são validados antes de restaurar. A restauração cria outro backup do estado substituído.

Atualizações do pacman, seus hooks e efeitos de pacotes permanecem fora da transação de arquivos. Registros em `packages/` mostram as versões anteriores e posteriores; falhas do pacman nunca autorizam a aplicação dos dotfiles.

Aplicativos também ficam fora do rollback dos dotfiles. Spotify usa instalação Flatpak por usuário e remote validado. O VS Code original fica em `.local/share/juno-apps/vscode`, separado do destino de recursos visuais; versões anteriores e cópias de launchers substituídos são preservadas. O download exige checksum da API HTTPS da Microsoft, identidade do produto e inspeção de caminhos e links do arquivo antes de extrair.

A habilitação de multilib preserva a configuração anterior do pacman em `/etc/pacman.conf.juno-*.bak`, confere o backup e valida a configuração preparada antes de substituir atomicamente o arquivo. Essa mudança não é desfeita automaticamente após instalação de pacotes. Repositórios personalizados e configurações de teste existentes são preservados.

## Segurança da sessão

O menu de energia usa ações fixas e confirmação; textos vindos do launcher não viram comandos. Capturas usam caminhos e argumentos protegidos, e cancelar a seleção não gera erro nem arquivo parcial. O histórico adicional de clipboard não é habilitado.

Mako desabilita ícones e markup externos para preservar as cores do tema. O bloqueio usa PAM do pacote oficial Hyprlock, sem senha embutida ou configuração de autenticação alternativa. Portais e agente de autenticação usam serviços da sessão, sem matar indiscriminadamente serviços de outros desktops.

A escolha do wallpaper aceita apenas IDs do catálogo e arquivos regulares dentro da galeria instalada. Só é persistida após a aplicação bem-sucedida por awww. O bloqueio gera uma configuração privada com o caminho seguro da imagem selecionada; indisponibilidade da imagem não impede o bloqueio. AVIF usa fallback JPG no bloqueio devido à compatibilidade do decoder. Nenhuma captura do conteúdo da sessão é usada como fundo.
