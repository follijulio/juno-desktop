# Juno Desktop

Sessão editorial para **Arch Linux x86_64 e Hyprland 0.56.x**, baseada no manual Netuno: papel creme, tinta, recortes retos e contornos marcados. Roboto organiza a interface; Space Mono identifica números, metadados e terminal.

## Instalar

O Arch já deve estar instalado, com uma conta comum e acesso a `sudo`. Use os diretórios XDG padrão. O instalador atualiza **todo o sistema**, instala dependências oficiais e substitui integralmente os diretórios gerenciados após gerar e verificar um backup.

1. Extraia o projeto em um diretório do seu usuário. Se usar a distribuição, confira sua integridade:

   ```bash
   sha256sum --check SHA256SUMS
   tar -xzf juno-desktop.tar.gz
   cd juno-desktop
   ```

2. Confira a simulação. Ela verifica plataforma, recursos e HTTPS, sem gravar arquivos nem executar `sudo`:

   ```bash
   bash install.sh --dry-run
   ```

3. Saia da sessão gráfica. Entre em um terminal de texto com `Ctrl + Alt + F3`, faça login e execute:

   ```bash
   bash install.sh
   ```

4. Revise as confirmações do pacman. Depois, inicie a sessão pelo seletor de sessões já instalado ou pelo TTY:

   ```bash
   start-hyprland
   ```

Não execute `sudo bash install.sh`. Não basta alternar para outro TTY mantendo o Hyprland aberto: o instalador verifica processos da sua conta para impedir recargas parciais.

Os utilitários básicos `sudo`, `curl`, `diffutils`, `tar`, `gzip`, `coreutils`, `findutils`, `util-linux`, `gawk` e `glibc` precisam estar disponíveis para as verificações. Se faltar algum, instale-o pelo pacman antes de executar o instalador. O diretório pessoal e os ancestrais gerenciados devem pertencer à sua conta e não permitir gravação por grupo ou outros usuários. A atualização verifica um mínimo de espaço, e o pacman verifica o espaço adicional da transação.

## O que acompanha a sessão

- Hyprland modular, teclado ABNT2, monitores automáticos e espaços de trabalho.
- Waybar com launcher, janela ativa, relógio, CPU, memória, rede e áudio. Brilho e bateria entram apenas quando o hardware é detectado.
- Rofi para aplicativos e menu de sessão; Mako para notificações; Kitty para terminal.
- Áudio PipeWire/WirePlumber, portais para compartilhamento de tela e seleção de arquivos, agente de autenticação e clipboard Wayland.
- Captura de região ou tela, bloqueio Hyprlock, inatividade Hypridle e wallpaper original.

O bloqueio ocorre após **5 minutos**; os monitores apagam após **10 minutos**. Suspensões solicitadas pelo sistema passam pela integração de bloqueio. O Juno não agenda suspensão automática.

## Aplicativos e desenvolvimento

O instalador também prepara os seguintes programas:

| Grupo | Aplicativos e ferramentas |
| --- | --- |
| Uso diário | Firefox, Thunar, mpv e pavucontrol |
| Entretenimento | Spotify, Steam e Discord |
| Editor | **Visual Studio Code original da Microsoft**, estável, com Marketplace original |
| Python | Python, pip, uv e ambientes virtuais |
| JavaScript | Node.js e npm |
| C e C++ | GCC, Make, Clang, CMake, Ninja, pkgconf, GDB e LLDB |
| Go e Rust | Go, Rust e Cargo |
| Desenvolvimento | Git, GitHub CLI, SQLite, ripgrep, fd, ShellCheck e shfmt |

Steam habilita o repositório oficial `multilib` quando necessário, preservando `/etc/pacman.conf` em um backup identificado no log. O pacman pode pedir a escolha do driver Vulkan de **32 bits**: escolha o correspondente à sua GPU. O instalador não escolhe um driver de vídeo automaticamente nem habilita repositórios de teste.

Discord e os demais pacotes usam os repositórios oficiais do Arch. Spotify é instalado por usuário via Flathub: o cliente vem do fornecedor, mas o empacotamento é comunitário, sem afirmar verificação pelo Spotify. Um remote `flathub` existente com outro endereço ou sem verificação de assinaturas é recusado. Para atualizar depois:

```bash
flatpak update --user
```

O VS Code é baixado diretamente da Microsoft, com versão estável, SHA-256 e identidade conferidos antes da ativação. Não instala o pacote `code` do Arch, Code-OSS ou VSCodium. Fica em `~/.local/share/juno-apps/vscode/`, com versões anteriores preservadas, comando `~/.local/bin/code` e entrada no launcher. Reexecutar o instalador atualiza a versão; launchers anteriores são preservados em `~/.local/state/juno-desktop/apps/backups/`.

Na sessão Juno, `~/.local/bin` e os aplicativos Flatpak são incluídos nos caminhos da sessão. Em um TTY já aberto, use `~/.local/bin/code` ou atualize o PATH do seu shell. Não são instaladas extensões de editor, pacotes globais pip/npm, contas ou serviços de contêiner automaticamente.

Para Python, use um ambiente isolado por projeto, preservando o Python do sistema:

```bash
uv venv
source .venv/bin/activate
uv pip install nome-do-pacote
```

Instalações de aplicativos, habilitação de multilib e seus dados ficam fora do rollback dos dotfiles. Falhas obrigatórias interrompem a aplicação da nova sessão, e os programas já instalados permanecem registrados.

## Wallpapers e bloqueio

A pasta `wallpapers/` fornecida foi integrada com **32 arquivos e 31 imagens únicas**. Os nomes foram organizados sem alterar pixels nem apagar a cópia duplicada. A paisagem **Ghibli · Vale tranquilo** é a seleção inicial.

Use **Super + W** para escolher uma imagem. A preferência persiste entre sessões e acompanha o bloqueio, que agora tem cartão creme, moldura de 4 px, sombra sólida, faixa menta, relógio, data, usuário e campo de senha.

```bash
bash ~/.config/juno/bin/wallpaper list
bash ~/.config/juno/bin/wallpaper set ghibli-vale
```

JPG, PNG e WebP são usados no desktop e no bloqueio. AVIF é oferecido no desktop; o bloqueio usa a imagem padrão JPG por compatibilidade com o decoder disponível no Arch. Se a galeria estiver indisponível, o bloqueio continua disponível sobre papel creme.

Para adicionar imagens ao projeto, coloque arquivos com nomes minúsculos, sem espaços, em `wallpapers/`, gere novamente o catálogo e execute o instalador:

```bash
python3 tools/catalog_wallpapers.py
bash install.sh
```

O catálogo e os checksums são verificados antes da aplicação. As fotografias/ilustrações fornecidas são uma exceção autorizada à paleta dos fundos; controles, painéis e tipografia preservam a identidade Netuno.

## Atalhos

| Atalho | Ação |
| --- | --- |
| `Super + Enter` | Abrir Kitty |
| `Super + E` | Abrir Thunar |
| `Super + B` | Abrir Firefox |
| `Super + C` | Abrir VS Code original |
| `Super + D` | Abrir aplicativos |
| `Super + W` | Escolher wallpaper |
| `Super + Q` | Fechar a janela ativa |
| `Super + F` | Alternar tela cheia |
| `Super + V` | Alternar janela flutuante |
| `Super + J` | Alternar divisão do layout |
| `Super + setas` | Mover foco |
| `Super + Shift + setas` | Mover janela |
| `Super + 1…0` | Abrir espaço de trabalho 1…10 |
| `Super + Shift + 1…0` | Enviar janela ao espaço 1…10 |
| `Super + botão esquerdo/direito` | Mover/redimensionar janela |
| `Super + L` | Bloquear sessão |
| `Super + Esc` | Abrir menu de sessão |
| `Print` | Salvar captura de região |
| `Shift + Print` | Salvar captura de tela inteira |
| `Ctrl + Print` | Copiar captura de região |
| Teclas de volume, microfone e brilho | Controlar o dispositivo correspondente |

Capturas salvas vão para `Juno`, dentro do diretório de imagens definido por `xdg-user-dir`, com fallback para `~/Pictures`. O clipboard não mantém um histórico adicional em disco.

## Personalizar

Os módulos de `~/.config/hypr/conf/` separam aparência, teclado, monitores, atalhos e sessão. Ajuste monitores em `monitors.lua`, mantendo a configuração automática como ponto de partida. Horários de inatividade ficam em `~/.config/hypr/hypridle.conf`.

Waybar usa `~/.config/waybar/config.jsonc` e `style.css`. O arquivo `.jsonc` fornecido contém JSON estrito; mantenha essa compatibilidade com `jq`. A sessão cria uma cópia de execução para inserir bateria e brilho, sem editar o arquivo base.

O terminal usa o esquema **técnico editorial**: fundo tinta e texto papel. Essa variante mantém contraste para as cores ANSI dentro da paleta. Interfaces internas de aplicativos e cores truecolor emitidas por programas têm seus próprios temas.

Uma nova instalação substitui personalizações dos diretórios gerenciados e cria um backup delas. O instalador não tenta mesclar arquivos arbitrários. Não altere a configuração durante instalação ou recuperação.

## Backup e restauração

```bash
bash install.sh --list-backups
bash install.sh --rollback 20261015T120000Z-XXXXXXXX
```

Substitua o ID de exemplo pelo ID listado. A restauração deve ocorrer fora da sessão gráfica e funciona sem internet ou `sudo`. Antes de restaurar, o estado atual é salvo em outro backup, preservando suas edições. Arquivos originalmente ausentes voltam a ficar ausentes.

Backups compactados, manifestos, diário e registros ficam em `~/.local/state/juno-desktop/`, com acesso privado. Não apague esse diretório durante uma recuperação. Links simbólicos de configurações existentes são preservados como links, sem copiar ou modificar seus destinos externos.

Se houver uma operação interrompida, a próxima execução recuperará o diário antes de aplicar novos arquivos. Se detectar alterações que tornem a recuperação ambígua, o instalador para e mantém os arquivos envolvidos; consulte [arquitetura e recuperação](docs/ARQUITETURA.md).

**Restauração cobre configurações, fontes e recursos Juno. Pacotes instalados e atualizações do Arch não são revertidos.** As versões antes e depois do pacman ficam nos registros de pacotes.

## Verificar e distribuir

```bash
# Verificações portáveis: Bash, ShellCheck, Python 3 e utilitários GNU.
bash tests/run.sh

# Parser real, somente no Arch, como usuário comum.
bash tests/native.sh

# Distribuição reproduzível, com scripts executáveis e finais de linha LF.
python3 tools/package.py
```

O pacote fica em `dist/juno-desktop.tar.gz`, acompanhado de `SHA256SUMS`. [Validação e roteiro de aceitação](docs/VALIDACAO.md) distinguem testes locais de verificações gráficas pendentes.

## Fontes e compatibilidade

Space Mono acompanha os quatro arquivos originais, licença OFL, revisão imutável e checksums em `assets/fonts/spacemono/`. Roboto vem do pacote oficial `ttf-roboto`. Não é necessário instalar yay ou paru.

O projeto usa `rofi` com Wayland e `awww`, os nomes atuais dos pacotes antes citados como rofi-wayland e swww. Não instala gerenciador de login ou drivers de GPU. A rede é exibida sem substituir seu gerenciador de conexão.

Referências: [identidade visual e aplicação do manual Netuno](docs/IDENTIDADE-VISUAL.md), [Hyprland](https://wiki.hypr.land/configuring/core/), [pacotes oficiais do Arch](https://archlinux.org/packages/), [Google Fonts — Space Mono](https://github.com/google/fonts/tree/main/ofl/spacemono). O projeto preserva o nome Juno Desktop, sem criar assinatura comercial conjunta.

Fontes dos aplicativos: [distribuição Microsoft do VS Code](https://code.visualstudio.com/docs/setup/linux), [Spotify no Flathub](https://flathub.org/en/apps/com.spotify.Client) e [Steam no Arch](https://archlinux.org/packages/multilib/x86_64/steam/).
