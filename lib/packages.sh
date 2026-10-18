#!/usr/bin/env bash

JUNO_PACKAGES=(
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

juno_install_packages() {
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
