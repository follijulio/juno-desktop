#!/usr/bin/env bash

juno_validate_resources() {
    local font_dir="$JUNO_ROOT/assets/fonts/spacemono" source_path link_path
    for source_path in "${JUNO_SOURCES[@]}"; do
        [[ ( -d $source_path || -f $source_path ) && ! -L $source_path ]] || juno_die "Recurso do projeto ausente ou inválido: $source_path."
        link_path=$(find "$source_path" -type l -print -quit)
        [[ -z $link_path ]] || juno_die "Recurso distribuído contém link simbólico: $link_path."
    done
    [[ -f $font_dir/SHA256SUMS && -f $font_dir/OFL.txt && -f $font_dir/source.json ]] ||
        juno_die 'Metadados de integridade e licença da Space Mono ausentes.'
    (cd -- "$font_dir" && sha256sum --check --strict SHA256SUMS) || juno_die 'A integridade da Space Mono não foi confirmada.'
    local wallpaper_dir="$JUNO_ROOT/assets/desktop/wallpapers"
    [[ -s $wallpaper_dir/juno-paper.png && -f $wallpaper_dir/SHA256SUMS ]] || juno_die 'Wallpaper ou checksum ausente.'
    (cd -- "$wallpaper_dir" && sha256sum --check --strict SHA256SUMS) || juno_die 'A integridade do wallpaper não foi confirmada.'
    if [[ -d $JUNO_ROOT/config/juno-gnome ]]; then
        [[ -f $JUNO_ROOT/vendor/jsonc-parser/SHA256SUMS && -f $JUNO_ROOT/vendor/jsonc-parser/LICENSE.md ]] ||
            juno_die 'Parser JSONC ou licença ausente.'
        (cd -- "$JUNO_ROOT/vendor/jsonc-parser" && sha256sum --check --strict SHA256SUMS) ||
            juno_die 'A integridade do parser JSONC não foi confirmada.'
    fi
}

juno_validate_staged() {
    local stage file family fonts_stage gnome_stage
    for stage in "${JUNO_STAGES[@]}"; do
        [[ ( -d $stage || -f $stage ) && ! -L $stage ]] || juno_die "Staging indisponível: $stage."
        while IFS= read -r -d '' file; do
            if [[ $file == *.sh || $file == */bin/* ]]; then
                bash -n "$file" || juno_die "Script inválido: $file."
            elif [[ $file == *.py ]]; then
                python3 -c 'import ast, pathlib, sys; ast.parse(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))' "$file" ||
                    juno_die "Script Python inválido: $file."
            fi
        done < <(find "$stage" -type f -print0)
    done
    gnome_stage=$(txn_stage_for '.config/juno-gnome') || return 1
    for file in "$gnome_stage/oh-my-posh.json" "$gnome_stage/terminal-settings.json"; do
        jq -e 'type == "object"' "$file" >/dev/null || juno_die "Configuração JSON inválida: $file."
    done
    fonts_stage=$(txn_stage_for '.local/share/fonts/juno') || return 1
    for file in "$fonts_stage"/*.ttf; do
        family=$(fc-scan --format '%{family}\n' "$file")
        [[ $family == *'Space Mono'* ]] || juno_die "Família incorreta no arquivo: $file."
    done
    for family in Roboto 'JetBrains Mono' 'JetBrainsMono Nerd Font Mono'; do
        juno_validate_font_family "$family"
    done
    juno_gsettings_validate
}

juno_validate_font_family() {
    local expected=$1 family
    family=$(fc-match --format '%{family}\n' "$expected") || juno_die "Não foi possível consultar a fonte: $expected."
    [[ $family == "$expected" || $family == "$expected,"* ]] || juno_die "Fonte indisponível: $expected (resolvida: $family)."
}

juno_validate_installed_fonts() {
    local family
    for family in 'Space Mono' Roboto 'JetBrains Mono' 'JetBrainsMono Nerd Font Mono'; do
        juno_validate_font_family "$family"
    done
}
