#!/usr/bin/env bash

juno_validate_resources() {
    local font_dir="$JUNO_ROOT/assets/fonts/spacemono" source_path link_path
    for source_path in "${JUNO_SOURCES[@]}"; do
        [[ -d $source_path ]] || juno_die "Diretório do projeto ausente: $source_path."
        link_path=$(find "$source_path" -type l -print -quit)
        [[ -z $link_path ]] || juno_die "Recurso distribuído contém link simbólico: $link_path."
    done
    [[ -f $font_dir/SHA256SUMS && -f $font_dir/OFL.txt && -f $font_dir/source.json ]] ||
        juno_die 'Metadados de integridade e licença da Space Mono ausentes.'
    (cd -- "$font_dir" && sha256sum --check --strict SHA256SUMS) || juno_die 'A integridade da Space Mono não foi confirmada.'
    local wallpaper_dir="$JUNO_ROOT/assets/desktop/wallpapers"
    [[ -s $wallpaper_dir/juno-paper.png && -f $wallpaper_dir/SHA256SUMS ]] || juno_die 'Wallpaper ou checksum ausente.'
    (cd -- "$wallpaper_dir" && sha256sum --check --strict SHA256SUMS) || juno_die 'A integridade do wallpaper não foi confirmada.'
}

juno_validate_hyprland_version() {
    local version_output
    version_output=$(Hyprland --version 2>&1)
    [[ $version_output =~ (^|[^0-9])v?0\.56\.[0-9]+([^0-9]|$) ]] ||
        juno_die "Versão do Hyprland fora da faixa validada 0.56.x. Configurações preservadas. Versão: $version_output"
}

juno_validate_staged() {
    local stage file family runtime_dir
    for stage in "${JUNO_STAGES[@]}"; do
        [[ -d $stage ]] || juno_die "Staging indisponível: $stage."
        while IFS= read -r -d '' file; do
            if [[ $file == *.sh || $file == */bin/* ]]; then
                bash -n "$file" || juno_die "Script inválido: $file."
            fi
        done < <(find "$stage" -type f -print0)
    done
    find "${JUNO_STAGES[5]}/bin" -type f -exec chmod 755 -- {} +
    jq -e . "${JUNO_STAGES[1]}/config.jsonc" >/dev/null || juno_die 'Configuração do Waybar inválida.'
    for file in "${JUNO_STAGES[7]}"/*.ttf; do
        family=$(fc-scan --format '%{family}\n' "$file")
        [[ $family == *'Space Mono'* ]] || juno_die "Família incorreta no arquivo: $file."
    done
    family=$(fc-match --format '%{family}\n' Roboto)
    [[ $family == Roboto || $family == Roboto,* ]] || juno_die 'Roboto não está disponível para a interface.'
    runtime_dir=$(mktemp -d "$JUNO_STATE/verify-runtime.XXXXXX")
    chmod 700 -- "$runtime_dir"
    # O modo de verificação não abre compositor e não deve executar autostart.
    if ! XDG_RUNTIME_DIR="$runtime_dir" Hyprland --verify-config -c "${JUNO_STAGES[0]}/hyprland.lua"; then
        rm -rf -- "$runtime_dir"
        juno_die 'O Hyprland rejeitou a configuração preparada. Nenhum dotfile foi substituído.'
    fi
    rm -rf -- "$runtime_dir"
}

juno_validate_installed_fonts() {
    local family
    family=$(fc-match --format '%{family}\n' 'Space Mono')
    [[ $family == 'Space Mono' || $family == 'Space Mono,'* ]] || juno_die 'O cache não resolveu Space Mono. Restaurando configurações.'
    family=$(fc-match --format '%{family}\n' Roboto)
    [[ $family == Roboto || $family == Roboto,* ]] || juno_die 'O cache não resolveu Roboto. Restaurando configurações.'
}
