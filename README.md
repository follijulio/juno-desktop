# Juno Desktop

Ambiente para **Arch Linux e Zorin OS 18.x Core/Pro, x86_64, com GNOME**. O GNOME fornece painel, aplicativos, notificações, capturas, bloqueio e energia. O Juno configura fontes, ícones de aplicativos, wallpaper, Kitty e ferramentas de desenvolvimento, sem instalar extensões ou atalhos globais adicionais.

No Zorin 18, use Core ou Pro com GNOME e GDM já instalados. A edição Lite usa XFCE e fica fora deste perfil, assim como Zorin 17 e outras distribuições derivadas do Ubuntu. O instalador mantém o ambiente, os layouts e as extensões já existentes do Zorin; as alterações do Juno são as mesmas fontes, ícones, wallpaper, terminais e preferências descritas abaixo. A versão Zorin possui verificações portáteis; a aceitação em uma instalação Zorin real ainda precisa ser feita. Consulte os [resultados efetivos](docs/RESULTADOS.md).

A interface e os documentos usam Roboto; aplicativos monoespaçados GNOME usam Space Mono. **JetBrains Mono** é usada no editor do VS Code, e **JetBrainsMono Nerd Font Mono** no Kitty e no terminal integrado. Kitty usa tamanho 12; os tamanhos existentes do editor são preservados. Os terminais usam Bash com Oh My Posh, sem mudar o shell de login da conta.

## Instalar

Use uma conta comum com `sudo` e diretórios XDG padrão. O mesmo `install.sh` detecta a distribuição. No Arch, atualiza **todo o sistema** pelo pacman. No Zorin, atualiza o índice APT e instala somente dependências ausentes com `--no-upgrade --no-remove`, sem atualizar a versão da distribuição, adicionar PPAs ou substituir a pilha de áudio. Arquivos gerenciados e preferências GNOME alteradas recebem backup.

1. Extraia o projeto. Na distribuição, confira o checksum antes de extrair:

   ```bash
   sha256sum --check SHA256SUMS
   tar -xzf juno-desktop.tar.gz
   cd juno-desktop
   ```

2. Confira a simulação, que não grava configurações nem executa `sudo`:

   ```bash
   bash install.sh --dry-run
   ```

3. Encerre a sessão gráfica da conta. Entre em um TTY com `Ctrl + Alt + F3`, faça login e execute:

   ```bash
   bash install.sh
   ```

4. Confira o resultado e entre novamente na sessão GNOME, ou na sessão Zorin existente. Reinicie quando as atualizações do sistema exigirem.

O GDM é habilitado somente quando nenhum outro gerenciador de login está configurado. Gerenciadores existentes, máscaras de serviço e alvo de boot são preservados. O instalador informa quando é preciso revisá-los manualmente e não inicia nem reinicia serviços de login.

Não execute `sudo bash install.sh`. Alternar para um TTY mantendo a sessão gráfica aberta não é suficiente: o instalador procura sessões gráficas da conta, inclusive em outros TTYs.

São necessários `sudo`, `curl`, `tar`, `gzip`, `coreutils`, `findutils`, `util-linux`, um `awk` e a biblioteca C para as verificações iniciais, além de pacman no Arch ou APT/dpkg no Zorin. `diffutils` é instalado com as dependências; recuperação e rollback exigem que já esteja disponível. Instale ferramentas faltantes pelo gerenciador da distribuição. Diretório pessoal e ancestrais dos destinos precisam pertencer à conta e impedir gravação por terceiros.

## GNOME e migração

O perfil gerencia sete preferências: fontes da interface, documentos e aplicativos monoespaçados, tema de ícones, duas URIs de wallpaper e modo de preenchimento. Reinstalar reaplica essas preferências, incluindo o wallpaper inicial, com backup do estado anterior.

Aparência clara/escura, teclado, animações, bloqueio, suspensão, atalhos e monitores permanecem nas Configurações do GNOME. Use as interfaces nativas para áudio, rede, brilho, energia e captura de tela. Nenhum atalho global Juno é acrescentado.

A migração preserva arquivos e pacotes Hyprland existentes. A instalação GNOME não aplica configurações de Hyprland, Waybar, Rofi, Mako, Hypridle ou Hyprlock. Os arquivos históricos do repositório permanecem para compatibilidade com o ambiente anterior e seus backups; não são iniciados pelo perfil GNOME. Kitty, fontes e wallpapers continuam compartilhados.

## Ícones dos aplicativos

O tema **Juno** usa cartões coloridos de cantos arredondados, desenhos creme com contornos escuros e pequenas sombras sólidas. São 49 desenhos vetoriais originais para os aplicativos do Juno e os principais aplicativos GNOME, com aliases para diferentes nomes de lançadores. Aplicativos sem desenho próprio usam seus ícones disponíveis pelo fallback Adwaita/hicolor.

O tema fica em `~/.local/share/icons/Juno` e é selecionado pelo GNOME. Seus arquivos e o tema anterior entram no backup. Os ícones de ações e estados continuam usando o fallback nativo. O VS Code usa um nome de ícone temático, mantendo uma cópia do PNG original em hicolor para funcionar também com outros temas.

Os SVGs locais têm licença CC0 e checksums; não há download de tema durante a instalação. Para gerar uma prévia ou conferir os recursos:

```bash
python3 tools/generate_icons.py --preview .cache/icons-preview.svg
python3 tools/generate_icons.py --check
```

## Terminal e aplicativos

Kitty abre `/bin/bash` com JetBrainsMono Nerd Font Mono e variantes Bold, Italic e Bold Italic. Mantém fundo tinta, texto papel e as 16 cores ANSI da paleta Juno.

Oh My Posh é instalado por usuário em `~/.local/share/juno-apps/oh-my-posh/`, a partir de uma release oficial estável. SHA-256 e versão são verificados antes da ativação; releases anteriores são preservadas. O tema local mostra diretório, branch Git e falhas de comandos, sem downloads ao abrir o terminal. Um bloco identificado em `.bashrc` inicializa o prompt apenas no Bash interativo, preservando o restante do arquivo. Se o executável não estiver disponível, o shell continua funcional. O instalador não executa o `.bashrc` existente.

O VS Code recebe JetBrains Mono no editor, Nerd Font Mono no terminal integrado e um perfil padrão **Juno Bash**. Comentários JSONC, outras preferências e outros perfis são preservados. JSONC inválido interrompe a preparação sem substituir o original. O parser JSONC da Microsoft acompanha o projeto com licença e checksums.

| Grupo | Aplicativos e ferramentas |
| --- | --- |
| Uso diário | Firefox no Arch; navegador existente no Zorin; Nautilus, mpv e pavucontrol |
| Entretenimento | Spotify, Steam e Discord |
| Editor | **Visual Studio Code original da Microsoft**, estável, com Marketplace original |
| Python | Python, pip e ambientes virtuais; uv no Arch |
| JavaScript | Node.js e npm |
| C e C++ | GCC, Make, Clang, CMake, Ninja, pkgconf, GDB e LLDB |
| Go e Rust | Go, Rust e Cargo |
| Desenvolvimento | Git, GitHub CLI, SQLite, ripgrep, fd, ShellCheck e shfmt |

No Arch, o VS Code fica em `~/.local/share/juno-apps/vscode/`, com versões anteriores preservadas. No Zorin, usa o pacote `.deb` oficial da Microsoft, verificado por SHA-256 e instalado via APT, sem adicionar o repositório Microsoft. O executável usa o caminho do pacote para a integração nativa de sandbox; não é aplicado `--no-sandbox`. Releases antigas instaladas por usuário são preservadas. Ambas as versões fornecem `~/.local/bin/code` e entrada nos aplicativos. Code-OSS e VSCodium não substituem a distribuição Microsoft.

Um arquivo gerenciado em `~/.config/environment.d/90-juno.conf` prepara os caminhos dos comandos locais e dos aplicativos Flatpak na próxima sessão GNOME.

Spotify é opcional e usa Flatpak por usuário via Flathub; seu empacotamento é comunitário. Cancelar a instalação ou encontrar uma falha gera um aviso e permite continuar com VS Code, Oh My Posh e o perfil GNOME. Um remote `flathub` existente com outra origem ou sem verificação de assinaturas é recusado. Para atualizar:

```bash
flatpak update --user
```

No Arch, Steam habilita `multilib` quando necessário e preserva `/etc/pacman.conf` em um backup registrado. O pacman pode pedir um provider Vulkan de 32 bits: escolha o correspondente à sua GPU. No Zorin, Steam e Discord são opcionais e usam Flatpak por usuário quando ainda não estão instalados. Instalações nativas ou Flatpak existentes são preservadas; recusa ou falha na instalação desses aplicativos permite continuar o perfil. O Juno não adiciona arquitetura i386 nem altera repositórios APT para eles. O instalador não escolhe drivers de vídeo nem habilita repositórios de teste.

Para Python, use ambientes isolados por projeto:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install nome-do-pacote
```

No Arch, `uv` também é instalado. No Zorin, o pacote `fd-find` fornece o comando `fdfind`.

Extensões de editor, pacotes globais pip/npm e serviços de contêiner não são instalados automaticamente.

## Wallpapers

A galeria tem **32 arquivos e 31 imagens únicas**, preservando pixels e a cópia duplicada. **Ghibli · Vale tranquilo** é o padrão inicial; o wallpaper editorial creme também acompanha o projeto.

Troque o fundo nas Configurações do GNOME, adicionando uma imagem de `~/.local/share/juno-desktop/wallpapers/gallery/`. Não há galeria personalizada integrada às Configurações ou script para reaplicar a seleção no login. Formatos como AVIF dependem dos decoders instalados no sistema.

Para acrescentar imagens ao projeto, use nomes minúsculos sem espaços em `wallpapers/`, atualize o catálogo e reinstale:

```bash
python3 tools/catalog_wallpapers.py
bash install.sh
```

Catálogo e checksums são conferidos antes da aplicação. A paleta editorial é validada nos recursos controlados pelo Juno; fotografias e ilustrações mantêm suas cores.

## Backup e restauração

```bash
bash install.sh --list-backups
bash install.sh --rollback ID-DO-BACKUP
```

Use um ID listado e execute fora da sessão gráfica. A restauração não depende de internet nem de `sudo`; o estado substituído recebe outro backup para preservar suas edições. Backups v2 exigem as dependências locais de GSettings para restaurar preferências GNOME.

Backups, manifestos, diário e logs ficam em `~/.local/state/juno-desktop/`, com acesso privado. Backups **v2** incluem arquivos gerenciados e as preferências GNOME. Backups anteriores com seis preferências mantêm esse escopo e preservam o tema de ícones atual ao serem restaurados; os novos incluem as sete. Backups **v1** legados continuam restauráveis com seus destinos originais, sem snapshots GNOME inexistentes.

Somente as chaves gerenciadas são restauradas, sem substituir a base dconf inteira. Arquivos originalmente ausentes voltam a ficar ausentes; preferências sem valor explícito voltam ao padrão do sistema.

Uma execução interrompida é recuperada pelo diário antes da próxima aplicação. Alterações concorrentes ou recuperação ambígua interrompem a operação e preservam os arquivos envolvidos. Não apague diário ou backups para forçar a instalação. Consulte [arquitetura e recuperação](docs/ARQUITETURA.md).

**Pacotes, aplicativos, versões do Oh My Posh, atualizações do sistema e habilitação do GDM não são revertidos pelo rollback de configurações.** Backups de multilib e registros de pacotes/GDM ficam disponíveis separadamente. Para desfazer somente uma habilitação do GDM feita pelo Juno, confira o serviço registrado: `gdm.service` no Arch ou `gdm3.service` no Zorin.

## Verificar e distribuir

```bash
# Sintaxe, ShellCheck quando disponível e testes com serviços simulados.
bash tests/run.sh

# Verificações disponíveis no sistema alvo, como usuário comum.
bash tests/native.sh

# Distribuição com LF, permissões POSIX e SHA-256.
python3 tools/package.py
```

O pacote fica em `dist/juno-desktop.tar.gz`, acompanhado de `SHA256SUMS`. Falhas de preparação não substituem uma distribuição anterior. A reprodução do wallpaper compara estrutura e pixels, tolerando diferenças de compressão entre versões de zlib.

Testes no Windows não certificam uma sessão GNOME real. Veja [resultados efetivos](docs/RESULTADOS.md) e [aceitação no Arch e no Zorin](docs/VALIDACAO.md).

Space Mono permanece em `assets/fonts/spacemono/`, com quatro arquivos originais, licença e checksums. Roboto e JetBrains Mono vêm dos pacotes da distribuição. No Arch, a Nerd Font também vem do pacote oficial. No Zorin, as quatro variantes de JetBrainsMono Nerd Font Mono acompanham o projeto em `assets/fonts/jetbrainsmono-nerd/`, provenientes da release oficial Nerd Fonts 3.5.1, com licença e SHA-256. São instaladas junto à Space Mono no destino gerenciado de fontes e entram no backup; esses TTFs locais não exigem download durante a instalação. Todas as famílias são conferidas antes da aplicação do perfil.

Referências: [identidade visual](docs/IDENTIDADE-VISUAL.md), [GNOME](https://www.gnome.org/), [pacotes oficiais Arch](https://archlinux.org/packages/), [versões e ambientes do Zorin](https://zorin.com/os/details/), [Oh My Posh](https://ohmyposh.dev/docs/installation/linux), [VS Code Linux](https://code.visualstudio.com/docs/setup/linux), [Spotify no Flathub](https://flathub.org/en/apps/com.spotify.Client).
