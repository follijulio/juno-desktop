#!/usr/bin/env bash

# Spotify usa o binário do fornecedor com empacotamento comunitário do Flathub.
juno_check_flathub() {
    local remotes name url options found=0
    remotes=$(LC_ALL=C flatpak remotes --user --columns=name,url,options) ||
        juno_die 'Não foi possível consultar os repositórios Flatpak do usuário.'
    while IFS=$'\t' read -r name url options; do
        [[ $name == flathub ]] || continue
        found=1
        case $url in
            https://dl.flathub.org/repo|https://dl.flathub.org/repo/) ;;
            *) juno_die "O repositório flathub existente usa um endereço diferente do esperado: $url. Nenhum aplicativo foi instalado por ele." ;;
        esac
        [[ $options != *no-gpg-verify* ]] || juno_die 'O repositório flathub existente desativa a verificação de assinaturas.'
    done <<< "$remotes"
    (( found == 1 ))
}

juno_install_spotify() {
    juno_require flatpak
    juno_private_subdir apps
    if ! juno_check_flathub; then
        flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo ||
            juno_die 'Não foi possível adicionar o Flathub para este usuário.'
        juno_check_flathub || juno_die 'A configuração do Flathub não pôde ser verificada.'
    fi
    juno_log 'Instalando Spotify para este usuário pelo Flathub (empacotamento comunitário).'
    flatpak install --user --or-update flathub com.spotify.Client ||
        juno_die 'A instalação do Spotify falhou. Nenhum dotfile foi substituído.'
    flatpak info --user --show-commit com.spotify.Client > "$JUNO_STATE/apps/spotify.commit" ||
        juno_die 'Não foi possível confirmar a instalação do Spotify.'
}

juno_install_applications() {
    juno_install_spotify
    juno_install_vscode
}

juno_applications_plan() {
    juno_log 'Aplicativos: Firefox, Nautilus, mpv, pavucontrol, Steam e Discord pelo pacman.'
    juno_log 'Steam: habilitar multilib se necessário, com backup de /etc/pacman.conf. O pacman solicitará o driver Vulkan de 32 bits compatível com sua GPU.'
    juno_log 'Spotify: Flatpak do usuário, com binário upstream e empacotamento comunitário do Flathub.'
    juno_log 'Visual Studio Code: binário estável original da Microsoft, checksum verificado, instalado para este usuário.'
    juno_log 'Desenvolvimento: Python/pip/uv, Node.js/npm, C/C++ (GCC/Clang), Go, Rust/Cargo, Git/GitHub CLI, CMake/Ninja, GDB/LLDB, SQLite, ripgrep/fd, ShellCheck/shfmt.'
}
