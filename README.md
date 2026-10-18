# Juno Desktop

Ambiente para **Arch Linux x86_64 com GNOME e Wayland**. O GNOME fornece painel, aplicativos, notifica??es, capturas, bloqueio e energia. O Juno mant?m seus wallpapers, o terminal editorial e as ferramentas de desenvolvimento.

A interface usa Roboto; Kitty usa **JetBrainsMono Nerd Font Mono 12**, Bash e Oh My Posh. O GNOME conserva a apar?ncia Adwaita e seus atalhos nativos.

## Instalar

Use uma conta comum com `sudo` e os diret?rios XDG padr?o. O instalador atualiza **todo o sistema** e instala pacotes dos reposit?rios oficiais, al?m dos aplicativos descritos abaixo. Altera??es nos arquivos gerenciados e nas prefer?ncias GNOME recebem backup.

1. Extraia o projeto. Para a distribui??o, confira o checksum antes de extrair:

   ```bash
   sha256sum --check SHA256SUMS
   tar -xzf juno-desktop.tar.gz
   cd juno-desktop
   ```

2. Confira a simula??o, que n?o grava configura??es nem executa `sudo`:

   ```bash
   bash install.sh --dry-run
   ```

3. Encerre a sess?o gr?fica da sua conta. Entre em um TTY com `Ctrl + Alt + F3`, fa?a login e execute:

   ```bash
   bash install.sh
   ```

4. Confira o resultado e entre na sess?o **GNOME** pelo seletor de sess?es do gerenciador de login.

O GDM ? habilitado somente quando n?o existe outro gerenciador de login habilitado. Um gerenciador existente ? preservado. O instalador n?o reinicia o computador nem inicia ou reinicia o gerenciador de login durante a instala??o; ap?s concluir, voc? pode reiniciar quando conveniente.

N?o execute `sudo bash install.sh`. Alternar para um TTY mantendo a sess?o gr?fica aberta n?o ? suficiente. O instalador recusa a aplica??o enquanto encontra uma sess?o gr?fica da conta.

S?o necess?rios `sudo`, `curl`, `diffutils`, `tar`, `gzip`, `coreutils`, `findutils`, `util-linux`, `gawk` e `glibc` para as verifica??es iniciais. Instale ferramentas faltantes pelo pacman. Diret?rio pessoal e ancestrais dos destinos precisam pertencer ? conta e impedir grava??o por terceiros.

## GNOME e personaliza??o

O perfil prepara fontes Roboto/JetBrains Mono, apar?ncia clara Adwaita, teclado brasileiro ABNT2, anima??es desativadas e bloqueio nativo. A tela apaga e bloqueia ap?s **5 minutos**; o Juno n?o agenda suspens?o autom?tica. Configura??es, gerenciamento de janelas e monitores permanecem nas interfaces nativas do GNOME.

Nenhum atalho personalizado ? acrescentado. Alguns atalhos nativos ?teis:

| Atalho | A??o |
| --- | --- |
| `Super` | Abrir a vis?o geral e buscar aplicativos |
| `Super + A` | Mostrar aplicativos |
| `Super + L` | Bloquear a sess?o |
| `Super + V` | Abrir notifica??es |
| `Alt + Tab` | Alternar aplicativos |
| `Super + Page Up / Page Down` | Alternar espa?os de trabalho |
| `Print` | Abrir a captura interativa |
| `Shift + Print` | Capturar a tela inteira |
| `Alt + Print` | Capturar a janela ativa |
| `Ctrl + Alt + Shift + R` | Abrir grava??o de tela |

Esses s?o os padr?es do GNOME; atalhos j? personalizados pelo usu?rio s?o preservados. A captura nativa salva no diret?rio de imagens e copia a imagem para a ?rea de transfer?ncia. Use o menu do sistema para ?udio, rede, brilho, bloqueio e energia.

A migra??o preserva os arquivos e pacotes do ambiente Hyprland que j? existem no computador. A nova instala??o n?o aplica as configura??es antigas de Hyprland, Waybar, Rofi, Mako ou Hyprlock. Os arquivos hist?ricos ainda presentes no reposit?rio servem ? compatibilidade e n?o s?o iniciados pelo perfil GNOME.

## Terminal e aplicativos

Kitty abre `/bin/bash` com JetBrainsMono Nerd Font Mono e as variantes Bold, Italic e Bold Italic. O tema usa fundo tinta, texto papel e as 16 cores ANSI da paleta Juno. Oh My Posh ? instalado no diret?rio do usu?rio a partir de uma vers?o identificada e verificada; o tema ? local, sem baixar scripts durante a abertura do terminal. A integra??o preserva o restante de `.bashrc` e mant?m Bash utiliz?vel se o prompt n?o estiver dispon?vel.

| Grupo | Aplicativos e ferramentas |
| --- | --- |
| Uso di?rio | Firefox, gerenciador de arquivos, mpv e pavucontrol |
| Entretenimento | Spotify, Steam e Discord |
| Editor | **Visual Studio Code original da Microsoft**, est?vel, com Marketplace original |
| Python | Python, pip, uv e ambientes virtuais |
| JavaScript | Node.js e npm |
| C e C++ | GCC, Make, Clang, CMake, Ninja, pkgconf, GDB e LLDB |
| Go e Rust | Go, Rust e Cargo |
| Desenvolvimento | Git, GitHub CLI, SQLite, ripgrep, fd, ShellCheck e shfmt |

O VS Code mant?m prefer?ncias existentes e prepara JetBrains Mono no editor e JetBrainsMono Nerd Font Mono no terminal integrado. Fica em `~/.local/share/juno-apps/vscode/`, com vers?es anteriores preservadas, comando `~/.local/bin/code` e entrada nos aplicativos. O pacote `code` do Arch, Code-OSS e VSCodium n?o substituem a distribui??o Microsoft.

Spotify usa Flatpak por usu?rio via Flathub; seu empacotamento ? comunit?rio. Um remote `flathub` existente com outro endere?o ou sem verifica??o de assinaturas ? recusado. Para atualizar:

```bash
flatpak update --user
```

Steam habilita `multilib` quando necess?rio e preserva `/etc/pacman.conf` em um backup registrado. O pacman pode pedir um provider Vulkan de 32 bits: escolha o correspondente ? sua GPU. O instalador n?o escolhe drivers de v?deo nem habilita reposit?rios de teste.

Para Python, use ambientes isolados por projeto:

```bash
uv venv
source .venv/bin/activate
uv pip install nome-do-pacote
```

N?o s?o instaladas extens?es de editor, pacotes globais pip/npm ou servi?os de cont?iner automaticamente. Pacotes, aplicativos instalados e atualiza??es do Arch ficam fora do rollback das configura??es.

## Wallpapers

A galeria fornecida tem **32 arquivos e 31 imagens ?nicas**, preservando os pixels originais e a c?pia duplicada. **Ghibli ? Vale tranquilo** ? o padr?o inicial; o wallpaper editorial creme tamb?m acompanha o projeto.

Troque o fundo em **Configura??es ? Apar?ncia**, usando a op??o para adicionar uma imagem da galeria em `~/.local/share/juno-desktop/wallpapers/gallery/`. O bloqueio nativo acompanha o fundo do desktop, com o desfoque do GNOME. PNG, JPG, WebP e AVIF usam os decoders do sistema; `libheif` fornece o suporte AVIF.

Para acrescentar imagens ao projeto, use nomes min?sculos sem espa?os em `wallpapers/`, atualize o cat?logo e reinstale:

```bash
python3 tools/catalog_wallpapers.py
bash install.sh
```

Cat?logo e checksums s?o conferidos antes de aplicar os recursos. Fotografias e ilustra??es mant?m suas cores; a paleta editorial ? validada nos recursos controlados pelo Juno, sem impor um tema ao Shell GNOME ou aos aplicativos de terceiros.

## Backup e restaura??o

```bash
bash install.sh --list-backups
bash install.sh --rollback ID-DO-BACKUP
```

Use um ID listado. Execute a restaura??o fora da sess?o gr?fica. Ela n?o depende de internet nem de `sudo`; o estado substitu?do recebe outro backup para preservar suas edi??es.

Backups, manifestos, di?rio e logs ficam em `~/.local/state/juno-desktop/`, com acesso privado. Backups **v2** incluem os arquivos gerenciados e as prefer?ncias GNOME/integra??es alteradas pela instala??o. Backups **v1** legados continuam restaur?veis com seu conjunto original de arquivos.

O instalador salva somente as prefer?ncias que gerencia. A restaura??o n?o deve substituir toda a base dconf. Arquivos originalmente ausentes voltam a ficar ausentes e prefer?ncias sem valor pr?prio voltam ao padr?o do sistema.

Uma execu??o interrompida ? recuperada pelo di?rio antes de nova aplica??o. Se o estado n?o permitir recupera??o segura, o instalador interrompe a opera??o e preserva os arquivos envolvidos. N?o apague manualmente o di?rio ou os backups para for?ar a instala??o. Consulte [arquitetura e recupera??o](docs/ARQUITETURA.md).

**Pacotes instalados, aplicativos e atualiza??es do Arch n?o s?o revertidos.** O backup de multilib e os registros de pacotes permanecem dispon?veis separadamente.

## Verificar e distribuir

```bash
# Sintaxe Bash, ShellCheck, Python e testes com servi?os simulados.
bash tests/run.sh

# Verifica??es dispon?veis no Arch, como usu?rio comum.
bash tests/native.sh

# Distribui??o com LF, permiss?es POSIX e SHA-256.
python3 tools/package.py
```

O pacote fica em `dist/juno-desktop.tar.gz`, acompanhado de `SHA256SUMS`. Um erro na prepara??o n?o substitui uma distribui??o anterior. A reprodu??o do wallpaper compara estrutura e pixels, tolerando diferen?as de compress?o entre vers?es de zlib.

Os testes realizados no Windows n?o certificam uma sess?o GNOME real. Veja [resultados efetivos](docs/RESULTADOS.md) e [aceita??o no Arch](docs/VALIDACAO.md).

Space Mono permanece em `assets/fonts/spacemono/`, com os quatro arquivos originais, licen?a e checksums, para compatibilidade com recursos hist?ricos. Roboto e JetBrains Mono/Nerd Font v?m de pacotes oficiais do Arch.

Refer?ncias: [identidade visual](docs/IDENTIDADE-VISUAL.md), [GNOME](https://www.gnome.org/), [capturas GNOME](https://help.gnome.org/gnome-help/screen-shot-record.html), [pacotes oficiais Arch](https://archlinux.org/packages/), [Oh My Posh](https://ohmyposh.dev/docs/installation/linux), [VS Code Linux](https://code.visualstudio.com/docs/setup/linux), [Spotify no Flathub](https://flathub.org/en/apps/com.spotify.Client).
