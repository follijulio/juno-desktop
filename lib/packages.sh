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
    nss alsa-lib libxkbfile libsecret gtk3 libxss libxrandr lsof desktop-file-utils
)

JUNO_ZORIN_PACKAGES=(
    gnome-settings-daemon gnome-control-center nautilus gnome-keyring dconf-gsettings-backend
    xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk
    python3-gi dconf-cli gir1.2-glib-2.0 kitty fonts-roboto fonts-jetbrains-mono
    fontconfig jq libnotify-bin xdg-user-dirs qt6-wayland curl diffutils procps dbus-x11
    mpv pavucontrol zip unzip flatpak build-essential git gh python3 python3-pip python3-venv
    nodejs npm golang-go rustc cargo clang cmake ninja-build gdb lldb pkg-config
    ripgrep fd-find sqlite3 shellcheck shfmt libnss3 libasound2t64 libxkbfile1
    libsecret-1-0 libgtk-3-0t64 libxss1 libxrandr2 lsof desktop-file-utils
)

# Keep the Arch default for callers that inspect the package contract directly.
JUNO_PACKAGES=("${JUNO_ARCH_PACKAGES[@]}")

juno_set_packages() {
    case ${JUNO_PLATFORM:-arch} in
        arch) JUNO_PACKAGES=("${JUNO_ARCH_PACKAGES[@]}") ;;
        zorin) JUNO_PACKAGES=("${JUNO_ZORIN_PACKAGES[@]}") ;;
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
            juno_log 'APT: atualizar índices e instalar somente dependências ausentes; revisar a transação interativamente, sem remover ou atualizar pacotes já instalados explicitamente.'
            printf 'Dependências: sudo apt-get install --no-upgrade --no-remove --'
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

_juno_dpkg_installed() {
    local records architecture status
    records=$(dpkg-query -W '-f=${Architecture}\t${Status}\n' -- "$1" 2>/dev/null) || return 1
    while IFS=$'\t' read -r architecture status; do
        if [[ ( $architecture == amd64 || $architecture == all ) && $status == 'install ok installed' ]]; then
            return 0
        fi
    done <<< "$records"
    return 1
}

# Zorin already supplies its desktop and audio integration. Require that stack
# instead of replacing it with Ubuntu metapackages or changing its login manager.
juno_require_zorin_desktop() {
    local package
    for package in gnome-shell gnome-session-bin gsettings-desktop-schemas gdm3; do
        _juno_dpkg_installed "$package" ||
            juno_die "O perfil Zorin exige GNOME já instalado (Core/Pro). Componente ausente: $package. Zorin Lite/XFCE não é suportado."
    done
}

_juno_zorin_package_snapshot() {
    dpkg-query -W '-f=${binary:Package}\t${Version}\t${db:Status-Status}\n' > "$1"
}

_juno_install_zorin_packages() {
    local snapshot_dir="$JUNO_STATE/packages" snapshot_id package status candidate
    local -a missing=()
    juno_require_zorin_desktop
    for package in "${JUNO_PACKAGES[@]}"; do
        _juno_dpkg_installed "$package" || missing+=("$package")
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
    if sudo apt-get install --no-upgrade --no-remove -- "${missing[@]}"; then
        _juno_zorin_package_snapshot "$snapshot_dir/$snapshot_id.after.txt"
    else
        status=$?
        _juno_zorin_package_snapshot "$snapshot_dir/$snapshot_id.after.txt" || true
        juno_die "O APT falhou (código $status). Nenhum dotfile foi substituído. Registro: $snapshot_dir/$snapshot_id.after.txt"
    fi
    juno_require gnome-shell gsettings dbus-run-session python3 fc-cache fc-match fc-scan jq diff cmp
    for package in "${JUNO_PACKAGES[@]}"; do
        _juno_dpkg_installed "$package" || juno_die "Dependência obrigatória ausente após a instalação: $package."
    done
}

juno_install_packages() {
    juno_set_packages
    case ${JUNO_PLATFORM:-arch} in
        arch) _juno_install_arch_packages ;;
        zorin) _juno_install_zorin_packages ;;
    esac
}
