# Validação

## Verificações automáticas

`bash tests/run.sh` executa sintaxe Bash, ShellCheck quando disponível, checksums, conformidade dos recursos Juno e testes de instalação, aplicativos, backup, GNOME e shell. Serviços, gerenciador de pacotes e downloads são simulados nos testes portáteis.

Os testes Python verificam equivalência de pixels PNG com compressão diferente, rejeição de arquivos inválidos, reprodutibilidade do pacote, LF/permissões executáveis e preservação da distribuição anterior em caso de falha.

No Windows, permissões POSIX, links reais, `flock`, D-Bus e serviços GNOME não podem ser considerados validados. Casos ignorados ou simulados devem ser registrados. `bash tests/native.sh` exige Arch Linux e usuário comum; suas verificações não substituem aceitação gráfica.

## Aceitação no Arch

Use um Arch de teste antes de aplicar ao ambiente principal:

- Instalar pelo TTY; conferir logs, fontes e backup. Reexecutar sem edições e conferir idempotência.
- Confirmar que o gerenciador de login existente permanece configurado; sem outro gerenciador e sem máscara do GDM, conferir GDM habilitado. Nenhum serviço de login deve ser iniciado ou reiniciado pelo instalador. O alvo de boot existente deve ser preservado.
- Entrar em GNOME Wayland. Conferir visão geral, notificações, painel, monitores, escala e atalhos nativos. Conferir preservação das preferências anteriores de teclado, tema, animações, bloqueio e suspensão.
- Conferir Roboto na interface e documentos, Space Mono nos aplicativos monoespaçados GNOME, JetBrains Mono no editor e Nerd Font Mono nos terminais, sem glifos ausentes. Testar Kitty com Bash/Oh My Posh e o terminal integrado do VS Code.
- Conferir preservação de `.bashrc`, comentários JSONC, preferências e perfis de editor não gerenciados. Abrir Bash interativo e não interativo; remover temporariamente o executável Posh e confirmar shell funcional. Conferir que o shell de login da conta permanece o mesmo.
- Testar áudio, mute, microfone, brilho, bateria e rede nas interfaces GNOME. Equipamentos sem controle de brilho/bateria não devem depender de scripts Juno.
- Testar capturas nativas e cancelamento. Conferir arquivo salvo e clipboard conforme a operação escolhida.
- Testar seleção de arquivos e compartilhamento de tela no Firefox e em aplicativos Flatpak; conferir portais GNOME.
- Bloquear com `Super + L`, suspender manualmente e retomar; conferir autenticação antes de visualizar a sessão, conforme as preferências GNOME da conta.
- Conferir wallpaper inicial Ghibli · Vale tranquilo e selecionar outra imagem pelas Configurações nativas. Validar persistência após login e caminhos com espaços e caracteres especiais. Testar JPG, PNG, WebP e AVIF quando seus decoders estiverem disponíveis.
- Abrir Firefox, Nautilus, Steam, Discord, Spotify e VS Code nos aplicativos. Conferir `code --version`, linguagens e Marketplace original.
- Conferir multilib e seu backup, provider Vulkan de 32 bits e atualização Flatpak sem substituir remotes existentes por outra origem.
- Editar arquivo/preferência gerenciada e restaurar backup v2; conferir arquivos, valores GNOME e backup das edições substituídas. Preferências sem valor explícito devem voltar ao padrão. Restaurar backup legado v1 sem exigir snapshots GNOME inexistentes.
- Interromper instalação de teste e confirmar recuperação do diário; testar alteração concorrente e conferir interrupção sem perda de arquivos ou preferências divergentes.
- Conferir preservação das configurações e pacotes Hyprland existentes. Testar essa sessão separadamente caso continue em uso; Kitty, fontes e wallpapers são compartilhados.

## Estado da validação

[RESULTADOS.md](RESULTADOS.md) registra somente comandos efetivamente executados e distingue a baseline Hyprland dos novos testes. Resultados portáteis não homologam autenticação, suspensão, serviços, gráficos ou hardware.
