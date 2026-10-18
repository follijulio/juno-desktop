# Valida??o

## Verifica??es autom?ticas

`bash tests/run.sh` executa sintaxe Bash, ShellCheck quando dispon?vel, checksums, conformidade dos recursos Juno e testes de instala??o, aplicativos, backup, GNOME e shell. Servi?os, gerenciador de pacotes e downloads s?o simulados nos testes port?veis.

Os testes Python tamb?m verificam a equival?ncia de pixels PNG com compress?o diferente, rejei??o de arquivos inv?lidos, reprodutibilidade do pacote, LF/permiss?es execut?veis e preserva??o da distribui??o anterior em caso de falha.

No Windows, permiss?es POSIX, links reais, `flock`, D-Bus e servi?os GNOME n?o podem ser considerados validados. Casos ignorados ou simulados devem ser registrados. `bash tests/native.sh` exige Arch Linux e usu?rio comum; os checks autom?ticos dispon?veis no alvo n?o substituem aceita??o gr?fica.

## Aceita??o no Arch

Use um Arch de teste antes de aplicar ao ambiente principal:

- Instalar pelo TTY; conferir logs, fontes e backup. Reexecutar sem edi??es e conferir idempot?ncia.
- Confirmar que um gerenciador de login existente permanece habilitado; sem outro gerenciador, conferir GDM habilitado. Nenhum deles deve ser iniciado ou reiniciado pelo instalador.
- Entrar em GNOME Wayland. Conferir vis?o geral, notifica??es, painel, monitores, escala, ABNT2 e atalhos nativos sem atalhos Juno adicionais.
- Conferir apar?ncia clara, Roboto na interface, JetBrains Mono no c?digo e Nerd Font Mono nos terminais, sem glifos ausentes. Testar Kitty com Bash/Oh My Posh e o terminal integrado do VS Code.
- Conferir que `.bashrc` e prefer?ncias de editor n?o relacionadas ao Juno foram preservadas. Abrir Bash interativo e n?o interativo; remover temporariamente o execut?vel Posh e confirmar shell funcional.
- Testar ?udio, mute, microfone, brilho, bateria e rede nas interfaces GNOME; equipamento sem controle de brilho/bateria n?o deve exibir recursos quebrados do Juno.
- Testar captura interativa, janela, tela inteira, cancelamento e grava??o. Conferir arquivo salvo e c?pia para clipboard.
- Testar sele??o de arquivos e compartilhamento de tela no Firefox e em aplicativos Flatpak; conferir portais GNOME.
- Bloquear com `Super + L`, aguardar 5 minutos de inatividade, suspender manualmente e retomar; confirmar autentica??o antes de visualizar a sess?o. N?o deve existir suspens?o autom?tica agendada pelo perfil.
- Escolher JPG, PNG, WebP e AVIF em Configura??es ? Apar?ncia; conferir desktop e bloqueio ap?s novo login, inclusive com caminhos contendo espa?os e caracteres especiais.
- Abrir Firefox, gerenciador de arquivos, Steam, Discord, Spotify e VS Code nos aplicativos. Conferir `code --version`, linguagens e Marketplace original.
- Conferir multilib e seu backup, provider Vulkan de 32 bits e atualiza??o Flatpak sem substituir remotes existentes por outra origem.
- Editar arquivo/prefer?ncia gerenciada e restaurar backup v2; conferir arquivos, valores GNOME e backup das edi??es substitu?das. Restaurar um backup legado v1 sem exigir snapshots GNOME inexistentes.
- Interromper uma instala??o de teste e confirmar recupera??o do di?rio; testar uma altera??o concorrente e conferir interrup??o sem perda dos arquivos divergentes.

## Estado da valida??o

[RESULTADOS.md](RESULTADOS.md) registra somente comandos efetivamente executados e distingue a baseline Hyprland dos novos testes. Os resultados port?veis n?o homologam autentica??o, suspens?o, servi?os, gr?ficos ou hardware.
