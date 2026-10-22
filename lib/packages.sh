#!/usr/bin/env bash

JUNO_ARCH_PACKAGES=(
    gnome-shell gnome-session gnome-settings-daemon gnome-control-center gdm
    nautilus gnome-keyring gsettings-desktop-schemas dconf python-gobject
    kitty ttf-roboto ttf-jetbrains-mono ttf-jetbrains-mono-nerd fontconfig jq libnotify
    pipewire pipewire-audio pipewire-pulse wireplumber
    xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk
    xdg-user-dirs qt6-wayland curl diffutils procps-ng dbus
    firefox mpv pavucontrol zip unzip flatpak steam discord
    base-devel git github-cli python python-pip uv nodejs npm go rust
    clang cmake ninja gdb lldb pkgconf ripgrep fd sqlite shellcheck shfmt
    nss alsa-lib libxkbfile libsecret gtk3 librsvg libxss libxrandr lsof desktop-file-utils
)

JUNO_ZORIN_PACKAGES=(
    gnome-settings-daemon gnome-control-center nautilus gnome-keyring dconf-gsettings-backend
    xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk
    python3-gi dconf-cli gir1.2-glib-2.0 gir1.2-gtk-3.0 gir1.2-gdkpixbuf-2.0 librsvg2-common kitty fonts-roboto fonts-jetbrains-mono
    fontconfig jq libnotify-bin xdg-user-dirs xdg-utils curl diffutils procps dbus-x11
    mpv pavucontrol zip unzip flatpak git python3 nodejs libnss3 libasound2t64 libxkbfile1
    libsecret-1-0 libgtk-3-0t64 libxss1 libxrandr2 desktop-file-utils
)

# Compilers and development tools are optional on an existing Zorin desktop.
# Existing tools are preserved regardless of the selected profile.
JUNO_ZORIN_DEV_PACKAGES=(
    build-essential gh python3-pip python3-venv npm golang-go rustc cargo clang
    cmake ninja-build gdb lldb pkg-config ripgrep fd-find sqlite3 shellcheck shfmt lsof
)

# Keep the Arch default for callers that inspect the package contract directly.
JUNO_PACKAGES=("${JUNO_ARCH_PACKAGES[@]}")

juno_set_packages() {
    case ${JUNO_PLATFORM:-arch} in
        arch) JUNO_PACKAGES=("${JUNO_ARCH_PACKAGES[@]}") ;;
        zorin)
            [[ ${JUNO_WITH_DEV_TOOLS:-0} == 0 || ${JUNO_WITH_DEV_TOOLS:-0} == 1 ]] ||
                juno_die 'A seleção das ferramentas de desenvolvimento deve ser 0 ou 1.'
            JUNO_PACKAGES=("${JUNO_ZORIN_PACKAGES[@]}")
            if [[ ${JUNO_WITH_DEV_TOOLS:-0} == 1 ]]; then
                JUNO_PACKAGES+=("${JUNO_ZORIN_DEV_PACKAGES[@]}")
            fi
            ;;
        *) juno_die 'Plataforma de pacotes desconhecida.' ;;
    esac
}

juno_packages_plan() {
    juno_set_packages
    case ${JUNO_PLATFORM:-arch} in
        arch)
            printf 'Atualização: sudo pacman -Syu --needed'
            printf ' %q' "${JUNO_PACKAGES[@]}"
            printf '\n'
            ;;
        zorin)
            juno_log 'Zorin: preservar GNOME, GDM, áudio e repositórios existentes; sem atualização da distribuição.'
            if [[ ${JUNO_WITH_DEV_TOOLS:-0} == 1 ]]; then
                juno_log 'Perfil de pacotes: essencial e ferramentas de desenvolvimento (--with-dev-tools).'
            else
                juno_log 'Perfil de pacotes: essencial; compiladores e ferramentas adicionais somente com --with-dev-tools.'
            fi
            juno_log 'APT: atualizar índices e instalar somente dependências ausentes; revisar a transação interativamente, sem remover ou atualizar pacotes já instalados explicitamente.'
            printf 'Dependências: sudo apt-get install --no-install-recommends --no-upgrade --no-remove --'
            printf ' %q' "${JUNO_PACKAGES[@]}"
            printf '\n'
            ;;
    esac
}

_juno_install_arch_packages() {
    local snapshot_dir="$JUNO_STATE/packages" snapshot_id package status
    juno_private_subdir packages
    snapshot_id=$(date -u +%Y%m%dT%H%M%SZ)-$$
    pacman -Q > "$snapshot_dir/$snapshot_id.before.txt"
    for package in pulseaudio pipewire-media-session; do
        if pacman -Q "$package" >/dev/null 2>&1; then
            juno_warn "$package está instalado. Revise os conflitos de áudio apresentados pelo pacman antes de confirmar."
        fi
    done
    juno_log 'Atualizando o Arch e instalando as dependências oficiais. Revise a transação do pacman.'
    sudo -v
    juno_enable_multilib
    if sudo pacman -Syu --needed -- "${JUNO_PACKAGES[@]}"; then
        pacman -Q > "$snapshot_dir/$snapshot_id.after.txt"
    else
        status=$?
        pacman -Q > "$snapshot_dir/$snapshot_id.after.txt" || true
        juno_die "O pacman falhou (código $status). Nenhum dotfile foi substituído. Registro: $snapshot_dir/$snapshot_id.after.txt"
    fi
    juno_require gnome-shell gsettings dbus-run-session python3 fc-cache fc-match fc-scan jq diff cmp
    for package in "${JUNO_PACKAGES[@]}"; do
        pacman -Q "$package" >/dev/null 2>&1 || juno_die "Dependência obrigatória ausente após a instalação: $package."
    done
}

# Each caller owns its inventory: do not keep a process-global cache that can
# become stale after APT or between preflight and installation.
_juno_dpkg_inventory() {
    local -n inventory_result=$1
    local records package architecture status
    records=$(dpkg-query -W '-f=${binary:Package}\t${Architecture}\t${Status}\n') ||
        juno_die 'Não foi possível consultar o inventário de pacotes DPKG. Nenhum dotfile foi substituído.'
    inventory_result=()
    while IFS=$'\t' read -r package architecture status; do
        [[ -n $package ]] || continue
        # Multi-Arch records can have a :architecture suffix. Only native and
        # architecture-independent installed packages satisfy dependencies.
        package=${package%%:*}
        [[ $package =~ ^[a-z0-9][a-z0-9+.-]*$ ]] || continue
        if [[ ( $architecture == amd64 || $architecture == all ) &&
              ( $status == 'install ok installed' || $status == 'hold ok installed' ) ]]; then
            # Populates the caller's associative array through the nameref.
            # shellcheck disable=SC2034
            inventory_result["$package"]=1
        fi
    done <<< "$records"
}

# Zorin already supplies its desktop and audio integration. Require that stack
# instead of replacing it with Ubuntu metapackages or changing its login manager.
juno_require_zorin_desktop() {
    local package
    # Passed by name and consumed through desktop_packages below.
    # shellcheck disable=SC2034
    local -A desktop_inventory=()
    if (( $# == 0 )); then
        _juno_dpkg_inventory desktop_inventory
    fi
    local -n desktop_packages=${1:-desktop_inventory}
    for package in gnome-shell gnome-session-bin gsettings-desktop-schemas gdm3; do
        [[ ${desktop_packages[$package]:-} == 1 ]] ||
            juno_die "O perfil Zorin exige GNOME já instalado (Core/Pro). Componente ausente: $package. Zorin Lite/XFCE não é suportado."
    done
}

_juno_zorin_package_snapshot() {
    dpkg-query -W '-f=${binary:Package}\t${Version}\t${db:Status-Status}\n' > "$1"
}

_juno_install_zorin_packages() {
    local snapshot_dir="$JUNO_STATE/packages" snapshot_id package status candidate
    local -a missing=()
    local -A installed=()
    _juno_dpkg_inventory installed
    juno_require_zorin_desktop installed
    for package in "${JUNO_PACKAGES[@]}"; do
        [[ ${installed[$package]:-} == 1 ]] || missing+=("$package")
    done
    if (( ${#missing[@]} == 0 )); then
        juno_log 'As dependências APT já estão instaladas. Nenhum índice ou pacote foi alterado.'
        return 0
    fi
    juno_private_subdir packages
    snapshot_id=$(date -u +%Y%m%dT%H%M%SZ)-$$
    _juno_zorin_package_snapshot "$snapshot_dir/$snapshot_id.before.txt"
    juno_log 'Instalando dependências ausentes no Zorin. Revise a transação APT; GNOME, áudio e gerenciador de login serão preservados.'
    sudo -v
    if ! sudo apt-get update; then
        juno_die 'Falha ao atualizar os índices APT. Nenhum dotfile foi substituído; confira os repositórios existentes.'
    fi
    for package in "${missing[@]}"; do
        candidate=$(LC_ALL=C apt-cache policy "$package" | awk '/^[[:space:]]*Candidate:/ {print $2; exit}')
        [[ -n $candidate && $candidate != '(none)' ]] ||
            juno_die "Dependência indisponível nos repositórios APT existentes: $package. Nenhum repositório foi adicionado e nenhum dotfile foi substituído."
    done
    if sudo apt-get install --no-install-recommends --no-upgrade --no-remove -- "${missing[@]}"; then
        _juno_zorin_package_snapshot "$snapshot_dir/$snapshot_id.after.txt"
    else
        status=$?
        _juno_zorin_package_snapshot "$snapshot_dir/$snapshot_id.after.txt" || true
        juno_die "O APT falhou (código $status). Nenhum dotfile foi substituído. Registro: $snapshot_dir/$snapshot_id.after.txt"
    fi
    juno_require gnome-shell gsettings dbus-run-session python3 fc-cache fc-match fc-scan jq diff cmp
    _juno_dpkg_inventory installed
    juno_require_zorin_desktop installed
    for package in "${JUNO_PACKAGES[@]}"; do
        [[ ${installed[$package]:-} == 1 ]] || juno_die "Dependência obrigatória ausente após a instalação: $package."
    done
}

juno_install_packages() {
    juno_set_packages
    case ${JUNO_PLATFORM:-arch} in
        arch) _juno_install_arch_packages ;;
        zorin) _juno_install_zorin_packages ;;
    esac
}
