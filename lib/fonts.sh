#!/usr/bin/env bash
# Zorin has no packaged JetBrainsMono Nerd Font Mono; use verified upstream TTFs.

juno_stage_fonts() {
    [[ ${JUNO_PLATFORM:-arch} == zorin ]] || return 0
    local source="$JUNO_ROOT/assets/fonts/jetbrainsmono-nerd" stage file family
    stage=$(txn_stage_for '.local/share/fonts/juno') || return 1
    juno_validate_nerd_fonts
    for file in "$source"/*.ttf; do
        family=$(fc-scan --format '%{family}\n' "$file") || return 1
        [[ $family == 'JetBrainsMono Nerd Font Mono' || $family == 'JetBrainsMono Nerd Font Mono,'* ]] ||
            juno_die "Família incorreta na Nerd Font: $file."
        cp -- "$file" "$stage/" || return 1
    done
    cp -- "$source/OFL.txt" "$stage/JetBrainsMonoNerdFont-OFL.txt" || return 1
}

juno_validate_nerd_fonts() {
    local source="$JUNO_ROOT/assets/fonts/jetbrainsmono-nerd" file
    [[ -d $source && ! -L $source && -f $source/SHA256SUMS && -f $source/OFL.txt && -f $source/source.json ]] ||
        juno_die 'Recursos oficiais da JetBrainsMono Nerd Font Mono ausentes.'
    [[ -z $(find "$source" -type l -print -quit) ]] || juno_die 'Links não são permitidos nos recursos de fontes.'
    for file in Regular Bold Italic BoldItalic; do
        [[ -s $source/JetBrainsMonoNerdFontMono-$file.ttf ]] || juno_die "Variante Nerd Font ausente: $file."
    done
    (cd -- "$source" && sha256sum --check --strict SHA256SUMS) >/dev/null ||
        juno_die 'A integridade da JetBrainsMono Nerd Font Mono não foi confirmada.'
}
