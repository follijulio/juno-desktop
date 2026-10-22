# Validação

## Verificações automáticas

`bash tests/run.sh` executa sintaxe Bash, ShellCheck quando disponível, checksums, conformidade dos recursos Juno e testes de instalação, aplicativos, backup, GNOME e shell. Serviços, gerenciador de pacotes e downloads são simulados nos testes portáteis.

Os testes Python verificam equivalência de pixels PNG com compressão diferente, rejeição de arquivos inválidos, reprodutibilidade do pacote, LF/permissões executáveis e preservação da distribuição anterior em caso de falha.

O perfil otimizado acrescenta testes de seleção essencial/ferramentas opcionais, inventário DPKG em lote e renovação após APT, pacotes retidos e estados incompletos, limites do segmento Git e atualização restrita do cache de fontes. Snapshots GNOME de seis, sete e oito chaves são testados com restauração e recuperação em seus próprios escopos, incluindo o valor booleano de animações e alterações concorrentes.

No Windows, permissões POSIX, links reais, `flock`, D-Bus e serviços GNOME não podem ser considerados validados. Casos ignorados ou simulados devem ser registrados. `bash tests/native.sh` exige uma plataforma aceita pelo instalador e usuário comum; suas verificações não substituem aceitação gráfica.

## Aceitação GNOME

Use uma instalação de teste da distribuição alvo antes de aplicar ao ambiente principal. Os resultados do Arch não certificam o Zorin; a versão para Zorin OS 18.x Core/Pro precisa passar pelos itens comuns abaixo e pelos itens próprios da distribuição.

- Instalar pelo TTY; conferir logs, fontes e backup. Reexecutar sem edições e conferir idempotência.
- Cancelar a instalação do runtime do Spotify e conferir o aviso: VS Code, Oh My Posh, fontes e perfil GNOME devem ser instalados normalmente. Falhas no Spotify opcional também devem permitir continuar.
- Confirmar que o gerenciador de login existente permanece configurado; sem outro gerenciador e sem máscara do GDM, conferir GDM habilitado. Nenhum serviço de login deve ser iniciado ou reiniciado pelo instalador. O alvo de boot existente deve ser preservado.
- Entrar na sessão GNOME ou Zorin. Conferir visão geral, notificações, painel, monitores, escala e atalhos nativos, inclusive Wayland quando disponível. Conferir preservação das preferências anteriores de teclado, tema, bloqueio e suspensão. No Arch, conferir também preservação das animações; no Zorin, conferir animações ativadas e valor anterior no backup, mantendo ícones, fontes, cores e wallpaper do perfil.
- Conferir Roboto na interface e documentos, Space Mono nos aplicativos monoespaçados GNOME, JetBrains Mono no editor e Nerd Font Mono nos terminais, sem glifos ausentes. Testar Kitty com Bash/Oh My Posh e o terminal integrado do VS Code.
- Conferir os ícones Juno na grade de aplicativos e no dock em 32/64 px e na escala do monitor. Validar Firefox, Nautilus, Kitty, VS Code, Steam, Discord e Spotify quando instalado; aplicativos sem desenho próprio e ícones simbólicos de ações devem continuar resolvendo pelo fallback nativo.
- Conferir preservação de `.bashrc`, comentários JSONC, preferências e perfis de editor não gerenciados. Abrir Bash interativo e não interativo; remover temporariamente o executável Posh e confirmar shell funcional. Conferir que o shell de login da conta permanece o mesmo.
- Em repositório grande, conferir diretório, branch/HEAD Git e indicação de erro no prompt, sem consulta de arquivos modificados ou ícone de upstream. Testar também diretório sem Git e HEAD destacado. Registrar medições no ambiente alvo sem inferir ganhos de RAM ou boot a partir delas.
- Testar áudio, mute, microfone, brilho, bateria e rede nas interfaces GNOME. Equipamentos sem controle de brilho/bateria não devem depender de scripts Juno.
- Testar capturas nativas e cancelamento. Conferir arquivo salvo e clipboard conforme a operação escolhida.
- Testar seleção de arquivos e compartilhamento de tela no Firefox e em aplicativos Flatpak; conferir portais GNOME.
- Bloquear com `Super + L`, suspender manualmente e retomar; conferir autenticação antes de visualizar a sessão, conforme as preferências GNOME da conta.
- Conferir wallpaper inicial Ghibli · Vale tranquilo e selecionar outra imagem pelas Configurações nativas. Validar persistência após login e caminhos com espaços e caracteres especiais. Testar JPG, PNG, WebP e AVIF quando seus decoders estiverem disponíveis.
- Abrir Firefox, Nautilus e VS Code nos aplicativos; testar Steam, Discord e Spotify quando instalados. Conferir `code --version`, linguagens e Marketplace original.
- Conferir atualização Flatpak sem substituir remotes existentes por outra origem.
- Editar arquivo/preferência gerenciada e restaurar backup v2; conferir arquivos, valores GNOME e backup das edições substituídas. Preferências sem valor explícito devem voltar ao padrão. Restaurar backup legado v1 sem exigir snapshots GNOME inexistentes.
- Restaurar um backup novo e conferir o tema de ícones anterior; no Zorin, conferir também o valor anterior de animações, incluindo ausência explícita. Restaurar backups v2 antigos com snapshots GNOME de seis e sete chaves e conferir que animações permanecem como estão; o de seis também deve preservar o tema de ícones atual. Verificar recuperação interrompida nos três escopos e o ícone original do VS Code com outro tema.
- Conferir famílias de fontes após instalar, restaurar e recuperar uma interrupção, incluindo rollback que remove o diretório gerenciado ou restaura link anterior. A reconstrução forçada deve se limitar a `~/.local/share/fonts/juno`; os demais caches usam descoberta incremental.
- Interromper instalação de teste e confirmar recuperação do diário; testar alteração concorrente e conferir interrupção sem perda de arquivos ou preferências divergentes.
- Conferir preservação das configurações e pacotes Hyprland existentes. Testar essa sessão separadamente caso continue em uso; Kitty, fontes e wallpapers são compartilhados.

## Itens específicos do Arch

- Conferir atualização completa via pacman, lista de dependências instaladas e registros de versões anteriores/posteriores.
- Conferir multilib e seu backup, provider Vulkan de 32 bits e execução nativa de Steam e Discord.
- Conferir identificação de `gdm.service` e preservação de outros gerenciadores, máscaras e alvo de boot.

## Itens específicos do Zorin

- Usar Zorin OS 18.x Core/Pro x86_64 com GNOME e GDM já instalados. Conferir recusa antes de alterações para Zorin 17, versões desconhecidas, Lite sem GNOME e outras distribuições Ubuntu/derivadas.
- Rodar `--dry-run` e `--dry-run --with-dev-tools` na sessão Zorin aberta e conferir que os planos usam APT/Flatpak, selecionam respectivamente 39 dependências essenciais e mais 20 ferramentas, não gravam arquivos, não usam `sudo` e não alteram fontes APT ou arquiteturas dpkg. A opção de ferramentas não deve acompanhar listagem ou rollback.
- Encerrar a sessão gráfica, entrar no TTY e instalar. Conferir `apt-get update` somente quando houver dependências ausentes e instalação apenas delas com `--no-install-recommends --no-upgrade --no-remove`. Instalação padrão não deve acrescentar compiladores, npm ou Qt6 Wayland; uma execução com `--with-dev-tools` deve complementar as ferramentas ausentes sem remover as existentes. Conferir preservação de fontes de pacotes, pilha de áudio e gerenciador de login. Conferir também os efeitos dos scripts de manutenção dos pacotes; eles não são homologados pelos testes simulados.
- Reinstalar com dependências presentes e confirmar ausência de `sudo`/APT na etapa de dependências. Conferir inventário nativo em lote, reconhecimento de pacotes retidos e independentes de arquitetura, rejeição de bibliotecas somente i386 ou instalação incompleta e validação por novo inventário após APT. Uma nova operação deve consultar o estado atual.
- Conferir Steam e Discord via Flatpak por usuário quando ausentes, preservando instalações existentes nativas ou Flatpak. Recusar/cancelar essas instalações e a do Spotify deve permitir continuar o perfil. Remotes Flathub com origem inesperada ou assinatura desativada devem continuar recusados antes de instalar aplicativos por eles.
- Conferir checksum, identidade, arquitetura e versão do `.deb` oficial do VS Code; abrir o editor e terminal integrado pela sessão Zorin, sem `--no-sandbox`. Conferir que nenhuma fonte APT Microsoft foi adicionada e que releases anteriores por usuário foram preservadas.
- Conferir Roboto, JetBrains Mono e JetBrainsMono Nerd Font Mono, incluindo variantes, acentos e glifos do prompt. Conferir presença de licenças/checksums dos recursos locais.
- Entrar novamente na sessão Zorin e conferir que os layouts e extensões existentes foram preservados. Validar os ícones Juno no menu, painel e grade que o layout apresentar.
- Conferir `gsettings get org.gnome.desktop.interface enable-animations` retornando `true`, inclusive após reinstalar sobre a versão anterior que aplicava `false`. Restaurar o backup Zorin de oito chaves e conferir o valor anterior, inclusive `false` ou ausência explícita; reinstalar deve reaplicar `true` com backup. Confirmar preservação de serviços, indexadores, segurança, parâmetros do kernel e políticas de energia.
- Conferir `gdm3.service`, preservação do gerenciador e alvo de boot existentes e ausência de comandos de início/reinício executados pelo Juno. Testar reinstalação, rollback e recuperação de interrupção na própria distribuição.

## Estado da validação

[RESULTADOS.md](RESULTADOS.md) registra somente comandos efetivamente executados e distingue a baseline Hyprland dos novos testes. Resultados portáteis não homologam autenticação, suspensão, serviços, gráficos ou hardware.

Não há VM Zorin disponível para a validação nativa desta otimização. As medições portáteis executadas no Windows não comprovam redução de RAM, tempo de boot ou ganho percentual no Zorin; esses resultados exigem medição no sistema alvo.
