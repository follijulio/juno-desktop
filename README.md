# Juno Desktop

Ambiente para **Arch Linux e Zorin OS 18.x Core/Pro, x86_64, com GNOME**. O GNOME fornece painel, aplicativos, notificações, capturas, bloqueio e energia. O Juno configura fontes, ícones de aplicativos, wallpaper, Kitty e ferramentas de desenvolvimento, sem instalar extensões. `Super + Enter` abre o Kitty.

No Zorin 18, use Core ou Pro com GNOME e GDM já instalados. A edição Lite usa XFCE e fica fora deste perfil, assim como Zorin 17 e outras distribuições derivadas do Ubuntu. O instalador mantém o ambiente, os layouts e as extensões já existentes do Zorin; configura fontes, ícones, wallpaper e terminais, mantém animações ativadas e usa um conjunto essencial de dependências. A versão Zorin possui verificações portáteis; a aceitação em uma instalação Zorin real ainda precisa ser feita. Consulte os [resultados efetivos](docs/RESULTADOS.md).

A interface e os documentos usam Roboto; aplicativos monoespaçados GNOME usam Space Mono. **JetBrains Mono** é usada no editor do VS Code, e **JetBrainsMono Nerd Font Mono** no Kitty e no terminal integrado. Kitty usa tamanho 12; os tamanhos existentes do editor são preservados. Os terminais usam Bash com Oh My Posh, sem mudar o shell de login da conta.

## Instalar

Use uma conta comum com `sudo` e diretórios XDG padrão. O mesmo `install.sh` detecta a distribuição. No Arch, atualiza **todo o sistema** pelo pacman. No Zorin, consulta as dependências em lote e, havendo ausentes, atualiza o índice APT e instala somente elas com `--no-install-recommends --no-upgrade --no-remove`. A versão da distribuição, os repositórios e a pilha de áudio existentes são preservados. Dependências já presentes dispensam atualização do índice e reinstalação. Arquivos gerenciados e preferências GNOME alteradas recebem backup.

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

No Zorin, a seleção padrão contém 42 dependências essenciais. Para incluir também as 20 ferramentas de desenvolvimento, confira o plano e instale com a mesma opção:

```bash
bash install.sh --dry-run --with-dev-tools
# Após encerrar a sessão gráfica e entrar no TTY:
bash install.sh --with-dev-tools
```

A opção não acompanha `--rollback` nem `--list-backups`. Compiladores e ferramentas já instalados são preservados em qualquer seleção. No Arch, a lista de pacotes permanece completa.

O GDM é habilitado somente quando nenhum outro gerenciador de login está configurado. Gerenciadores existentes, máscaras de serviço e alvo de boot são preservados. O instalador informa quando é preciso revisá-los manualmente e não inicia nem reinicia serviços de login.

Não execute `sudo bash install.sh`. Alternar para um TTY mantendo a sessão gráfica aberta não é suficiente: o instalador procura sessões gráficas da conta, inclusive em outros TTYs.

São necessários `sudo`, `curl`, `tar`, `gzip`, `coreutils`, `findutils`, `util-linux`, um `awk` e a biblioteca C para as verificações iniciais, além de pacman no Arch ou APT/dpkg no Zorin. `diffutils` é instalado com as dependências; recuperação e rollback exigem que já esteja disponível. Instale ferramentas faltantes pelo gerenciador da distribuição. Diretório pessoal e ancestrais dos destinos precisam pertencer à conta e impedir gravação por terceiros.

## GNOME e migração

O perfil gerencia quatorze chaves GNOME: fontes, ícones, wallpaper, aparência escura, animações ativadas e o atalho do terminal. Usa `prefer-dark`, `Adwaita-dark` no Arch e `ZorinBlue-Dark` no Zorin. Todas recebem backup por chave. Reinstalar reaplica o perfil com backup do estado anterior, inclusive quando uma versão anterior desativou as animações.

Após instalar, a aparência pode ser ajustada nas Configurações do GNOME. Teclado, bloqueio, suspensão, atalhos e monitores permanecem nas configurações existentes. Use as interfaces nativas para áudio, rede, brilho, energia e captura de tela. `Super + Enter` abre o Kitty. Os outros atalhos personalizados são preservados; se essa combinação já estiver ocupada por outro atalho personalizado, a instalação informa o conflito antes de alterar configurações.

O perfil Zorin reduz dependências adicionais e trabalho do prompt/cache de fontes. Mantém serviços, indexadores, segurança, parâmetros do kernel e políticas de energia da distribuição. Não há medição de ganho de RAM, tempo de boot ou desempenho em Zorin real; os limites e comandos executados estão nos [resultados](docs/RESULTADOS.md).

A migração preserva arquivos e pacotes Hyprland existentes. A instalação GNOME não aplica configurações de Hyprland, Waybar, Rofi, Mako, Hypridle ou Hyprlock. Os arquivos históricos do repositório permanecem para compatibilidade com o ambiente anterior e seus backups; não são iniciados pelo perfil GNOME. Kitty, fontes e wallpapers continuam compartilhados.

## Ícones dos aplicativos e pastas

O tema **Juno** usa cartões coloridos de cantos arredondados, desenhos creme com contornos escuros e pequenas sombras sólidas. Inclui pastas comuns, pessoais, Documentos, Downloads, Música, Imagens, Vídeos, compartilhamento e modelos, além de categorias e ações do menu. São 105 desenhos e variantes vetoriais, com 227 nomes SVG incluindo aliases. Menus simbólicos recebem desenhos em contorno que acompanham a cor e o contraste do GNOME; os ícones regulares usam cartões coloridos. Recursos sem desenho próprio herdam Adwaita/hicolor.

Tudo é instalado pelo `install.sh` na conta que o executa, usando os caminhos XDG padrão. Não depende de uma VM, nome de usuário, nome traduzido das pastas ou modelo de hardware. O tema inteiro é validado antes de substituir o anterior.

A base fica em `~/.local/share/icons/Juno`; o GNOME seleciona `Juno-Auto`, que herda essa base. Seus arquivos e o tema anterior entram no backup. Os ícones de ações e estados continuam usando o fallback nativo. O VS Code usa um nome de ícone temático, mantendo uma cópia do PNG original em hicolor para funcionar também com outros temas.

O instalador também adapta os ícones de todos os lançadores encontrados, incluindo aplicativos nativos, Flatpak e exportações Snap. Desenhos Juno existentes têm prioridade; outros símbolos recebem cartão colorido e tons creme/tinta. Cópias locais dos lançadores preservam comandos, ações, traduções e associações; apenas o ícone muda. Caminhos absolutos de ícone também são tratados. Os arquivos dos pacotes permanecem intactos.

No login GNOME, um atualizador local verifica novos lançadores a cada minuto. Só reconstrói após mudanças; usa o mesmo bloqueio, backup e transação do instalador. Atualizações dos pacotes são acompanhadas, e cópias geradas de aplicativos removidos são limpas. Edições pessoais dos lançadores são preservadas. Para atualizar imediatamente, sem reinstalar:

```bash
~/.config/juno-gnome/bin/juno-icons refresh
```

Para um aplicativo manual, adicione seu `.desktop` em `~/.local/share/applications/` e execute o comando acima, ou aguarde a verificação automática. Para desenhar um ícone próprio, acrescente-o a `tools/generate_icons.py` e regenere a base. O atualizador respeita outro tema selecionado depois da instalação. Ícones embutidos dentro dos próprios aplicativos e logotipos desenhados por extensões não seguem necessariamente o tema do sistema.

Os SVGs locais têm licença CC0 e checksums; não há download de tema durante a instalação. Para gerar uma prévia ou conferir os recursos:

```bash
python3 tools/generate_icons.py --preview .cache/icons-preview.svg
python3 tools/generate_icons.py --check
```

## Terminal e aplicativos

Firefox é o navegador padrão: pacote pacman no Arch e Flatpak por usuário no Zorin, preservando Firefox nativo já instalado. HTTP, HTTPS e HTML são preparados em `.config/mimeapps.list`, preservando comentários e associações não relacionadas, com backup e rollback. Após verificar o novo padrão, o instalador remove o pacote APT `brave-browser` no Zorin ou os pacotes Brave identificados pelo pacman no Arch, preservando perfis pessoais. Um plano APT que remova outros pacotes é recusado; não se usam purge ou remoção recursiva de dependências. Essas operações não removem instalações Snap ou Flatpak do Brave.

Kitty abre `/bin/bash` com JetBrainsMono Nerd Font Mono e variantes Bold, Italic e Bold Italic. Mantém fundo tinta, texto papel e as 16 cores ANSI da paleta Juno.

Oh My Posh é instalado por usuário em `~/.local/share/juno-apps/oh-my-posh/`, a partir de uma release oficial estável. SHA-256 e versão são verificados antes da ativação; releases anteriores são preservadas. O tema local mostra diretório, branch Git e falhas de comandos, sem downloads ao abrir o terminal. O segmento Git consulta apenas o HEAD, sem varrer alterações do repositório, e tem timeout de 200 ms. Um bloco identificado em `.bashrc` inicializa o prompt apenas no Bash interativo, preservando o restante do arquivo. Se o executável não estiver disponível, o shell continua funcional. O instalador não executa o `.bashrc` existente.

O VS Code recebe JetBrains Mono no editor, Nerd Font Mono no terminal integrado e um perfil padrão **Juno Bash**. Comentários JSONC, outras preferências e outros perfis são preservados. JSONC inválido interrompe a preparação sem substituir o original. O parser JSONC da Microsoft acompanha o projeto com licença e checksums.

| Grupo | Aplicativos e ferramentas |
| --- | --- |
| Uso diário | Firefox padrão; Nautilus, mpv e pavucontrol |
| Entretenimento | Spotify, Steam e Discord |
| Editor | **Visual Studio Code original da Microsoft**, estável, com Marketplace original |
| Python | Python, pip e ambientes virtuais; uv no Arch |
| JavaScript | Node.js e npm |
| C e C++ | GCC, Make, Clang, CMake, Ninja, pkgconf, GDB e LLDB |
| Go e Rust | Go, Rust e Cargo |
| Desenvolvimento | Git, GitHub CLI, SQLite, ripgrep, fd, ShellCheck e shfmt |

No Zorin, Python, Node.js e Git integram a seleção essencial. pip, ambientes virtuais, npm, compiladores, depuradores e as demais ferramentas de desenvolvimento da tabela exigem `--with-dev-tools` quando ausentes. Qt6 Wayland não é acrescentado pelo perfil Zorin; componentes já presentes permanecem instalados.

No Arch, o VS Code fica em `~/.local/share/juno-apps/vscode/`, com versões anteriores preservadas. No Zorin, usa o pacote `.deb` oficial da Microsoft, verificado por SHA-256 e instalado via APT, sem adicionar o repositório Microsoft. O executável usa o caminho do pacote para a integração nativa de sandbox; não é aplicado `--no-sandbox`. Releases antigas instaladas por usuário são preservadas. Ambas as versões fornecem `~/.local/bin/code` e entrada nos aplicativos. Code-OSS e VSCodium não substituem a distribuição Microsoft.

Um arquivo gerenciado em `~/.config/environment.d/90-juno.conf` prepara os caminhos dos comandos locais e dos aplicativos Flatpak na próxima sessão GNOME.

Spotify é opcional e usa Flatpak por usuário via Flathub; seu empacotamento é comunitário. Cancelar a instalação ou encontrar uma falha gera um aviso e permite continuar com VS Code, Oh My Posh e o perfil GNOME. Um remote `flathub` existente com outra origem ou sem verificação de assinaturas é recusado. Para atualizar:

```bash
flatpak update --user
```

No Arch, Steam habilita `multilib` quando necessário e preserva `/etc/pacman.conf` em um backup registrado. O pacman pode pedir um provider Vulkan de 32 bits: escolha o correspondente à sua GPU. No Zorin, Steam e Discord são opcionais e usam Flatpak por usuário quando ainda não estão instalados. Instalações nativas ou Flatpak existentes são preservadas; recusa ou falha na instalação desses aplicativos permite continuar o perfil. O Juno não adiciona arquitetura i386 nem altera repositórios APT para eles. O instalador não escolhe drivers de vídeo nem habilita repositórios de teste.

Para Python, use ambientes isolados por projeto; no Zorin, a instalação dessas ferramentas faz parte de `--with-dev-tools`:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install nome-do-pacote
```

No Arch, `uv` também é instalado. No Zorin, o pacote opcional `fd-find` fornece o comando `fdfind`.

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

Backups, manifestos, diário e logs ficam em `~/.local/state/juno-desktop/`, com acesso privado. Backups **v2** da instalação incluem doze destinos gerenciados e quatorze chaves GNOME, incluindo lançadores, autostart dos ícones, Firefox padrão e atalho do terminal. Atualizações automáticas de ícones criam backups de arquivos v1 com seu próprio escopo. Backups anteriores mantêm seus destinos e o próprio escopo de preferências: não alteram arquivos ou chaves que nunca registraram. Backups **v1** legados continuam restauráveis sem exigir snapshots GNOME inexistentes.

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

Space Mono permanece em `assets/fonts/spacemono/`, com quatro arquivos originais, licença e checksums. Roboto e JetBrains Mono vêm dos pacotes da distribuição. No Arch, a Nerd Font também vem do pacote oficial. No Zorin, as quatro variantes de JetBrainsMono Nerd Font Mono acompanham o projeto em `assets/fonts/jetbrainsmono-nerd/`, provenientes da release oficial Nerd Fonts 3.5.1, com licença e SHA-256. São instaladas junto à Space Mono no destino gerenciado de fontes e entram no backup; esses TTFs locais não exigem download durante a instalação. Todas as famílias são conferidas antes da aplicação do perfil. O cache é reconstruído com força somente nesse diretório gerenciado, preservando os caches válidos das demais fontes; se o diretório estiver ausente após rollback, a atualização usa descoberta incremental.

Referências: [identidade visual](docs/IDENTIDADE-VISUAL.md), [GNOME](https://www.gnome.org/), [pacotes oficiais Arch](https://archlinux.org/packages/), [versões e ambientes do Zorin](https://zorin.com/os/details/), [Oh My Posh](https://ohmyposh.dev/docs/installation/linux), [VS Code Linux](https://code.visualstudio.com/docs/setup/linux), [Spotify no Flathub](https://flathub.org/en/apps/com.spotify.Client).
