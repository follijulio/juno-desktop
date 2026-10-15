#!/usr/bin/env bash

juno_validate_gallery() {
    local gallery="$JUNO_ROOT/wallpapers" file
    [[ -d $gallery && ! -L $gallery && -f $gallery/catalog.json && -f $gallery/SHA256SUMS ]] ||
        juno_die 'A galeria de wallpapers está incompleta. Execute python3 tools/catalog_wallpapers.py.'
    file=$(find "$gallery" ! -type d ! -type f -print -quit)
    [[ -z $file ]] || juno_die "A galeria contém link ou arquivo especial: $file."
    (cd -- "$gallery" && sha256sum --check --strict SHA256SUMS) || juno_die 'A integridade da galeria de wallpapers não foi confirmada.'
}

juno_stage_gallery() {
    local desktop_stage=${JUNO_STAGES[8]}
    [[ -d $desktop_stage/wallpapers && ! -e $desktop_stage/wallpapers/gallery ]] ||
        juno_die 'O destino preparado da galeria é inválido.'
    cp -a -- "$JUNO_ROOT/wallpapers" "$desktop_stage/wallpapers/gallery"
    jq -e '
        .version == 1 and (.default | type == "string") and
        (.wallpapers | type == "array" and length > 0) and
        (.default as $default | any(.wallpapers[]; .id == $default)) and
        all(.wallpapers[]; (.id | test("^[a-z0-9][a-z0-9-]*$")) and
            (.file | test("^[a-z0-9][a-z0-9._-]*\\.(png|jpg|jpeg|webp|avif)$")) and (.name | type == "string"))
    ' "$desktop_stage/wallpapers/gallery/catalog.json" >/dev/null || juno_die 'Catálogo de wallpapers inválido.'
}
