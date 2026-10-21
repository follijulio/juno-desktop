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
    if [[ ${JUNO_PLATFORM:-arch} == zorin ]]; then
        juno_install_zorin_app com.spotify.Client Spotify spotify spotify
        return
    fi
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

juno_install_zorin_app() {
    local app_id=$1 label=$2 executable=$3 state_name=$4 origin
    # Keep applications already supplied by Zorin, Snap or a system Flatpak.
    # A second user installation would produce duplicate menu entries.
    if command -v "$executable" >/dev/null 2>&1; then
        juno_log "$label existente preservado; instalação adicional dispensada."
        return 0
    fi
    juno_require flatpak
    if flatpak info --user "$app_id" >/dev/null 2>&1; then
        origin=$(flatpak info --user --show-origin "$app_id") ||
            juno_die "Não foi possível consultar a origem de $label."
        if [[ $origin != flathub ]]; then
            juno_log "$label existente preservado na origem Flatpak $origin."
            return 0
        fi
    elif flatpak info --system "$app_id" >/dev/null 2>&1; then
        juno_log "$label Flatpak do sistema preservado; instalação do usuário dispensada."
        return 0
    fi
    juno_private_subdir apps
    if ! juno_check_flathub; then
        flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo ||
            juno_die "Não foi possível configurar o Flathub para $label."
        juno_check_flathub || juno_die 'A configuração do Flathub não pôde ser verificada.'
    fi
    juno_log "Instalando $label para este usuário pelo Flathub (empacotamento comunitário)."
    flatpak install --user --or-update flathub "$app_id" ||
        juno_die "A instalação de $label falhou. Nenhum dotfile foi substituído."
    flatpak info --user --show-commit "$app_id" > "$JUNO_STATE/apps/$state_name.commit" ||
        juno_die "Não foi possível confirmar a instalação de $label."
}

juno_install_applications() {
    # A subshell contains juno_die: optional app failures must not abort setup.
    # shellcheck disable=SC2034
    JUNO_SPOTIFY_SKIPPED=0
    if ! (juno_install_spotify); then
        # shellcheck disable=SC2034
        JUNO_SPOTIFY_SKIPPED=1
        juno_warn 'Spotify não foi instalado ou atualizado. Continuando com VS Code e a configuração do desktop; você pode tentar instalar o Spotify depois.'
    fi
    if [[ ${JUNO_PLATFORM:-arch} == zorin ]]; then
        if ! (juno_install_zorin_app com.valvesoftware.Steam Steam steam steam); then
            juno_warn 'Steam não foi instalado ou atualizado. A configuração do desktop continuará.'
        fi
        if ! (juno_install_zorin_app com.discordapp.Discord Discord discord discord); then
            juno_warn 'Discord não foi instalado ou atualizado. A configuração do desktop continuará.'
        fi
    fi
    juno_install_vscode
}

juno_applications_plan() {
    if [[ ${JUNO_PLATFORM:-arch} == zorin ]]; then
        juno_log 'Aplicativos: Nautilus, mpv e pavucontrol pelos repositórios APT existentes. O navegador do Zorin será preservado.'
        juno_log 'Steam e Discord (opcionais): Flatpak do usuário pelo Flathub. Instalações existentes serão preservadas, sem habilitar multilib.'
    else
        juno_log 'Aplicativos: Firefox, Nautilus, mpv, pavucontrol, Steam e Discord pelo pacman.'
        juno_log 'Steam: habilitar multilib se necessário, com backup de /etc/pacman.conf. O pacman solicitará o driver Vulkan de 32 bits compatível com sua GPU.'
    fi
    juno_log 'Spotify (opcional): Flatpak do usuário, com binário upstream e empacotamento comunitário do Flathub. Recusa ou falha não interrompe a configuração do desktop.'
    if [[ ${JUNO_PLATFORM:-arch} == zorin ]]; then
        juno_log 'Visual Studio Code: pacote .deb estável original da Microsoft, versão/arquitetura/checksum verificados; sem adicionar repositório Microsoft.'
        juno_log 'Desenvolvimento: dependências dos repositórios APT existentes, sem substituir versões já instaladas.'
    else
        juno_log 'Visual Studio Code: binário estável original da Microsoft, checksum verificado, instalado para este usuário.'
        juno_log 'Desenvolvimento: Python/pip/uv, Node.js/npm, C/C++ (GCC/Clang), Go, Rust/Cargo, Git/GitHub CLI, CMake/Ninja, GDB/LLDB, SQLite, ripgrep/fd, ShellCheck/shfmt.'
    fi
}
