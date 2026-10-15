#!/usr/bin/env bash
# Catalog entries are data, never shell commands or arbitrary file paths.

juno_wallpaper_catalog() {
    local canonical_data canonical_gallery
    JUNO_WALLPAPER_GALLERY=$JUNO_DATA_HOME/juno-desktop/wallpapers/gallery
    JUNO_WALLPAPER_CATALOG=$JUNO_WALLPAPER_GALLERY/catalog.json
    [[ -d $JUNO_WALLPAPER_GALLERY && ! -L $JUNO_WALLPAPER_GALLERY &&
       -f $JUNO_WALLPAPER_CATALOG && -r $JUNO_WALLPAPER_CATALOG && ! -L $JUNO_WALLPAPER_CATALOG ]] || return 1
    canonical_data=$(realpath -m -- "$JUNO_DATA_HOME") || return 1
    canonical_gallery=$(realpath -e -- "$JUNO_WALLPAPER_GALLERY") || return 1
    [[ $canonical_gallery == "$canonical_data/juno-desktop/wallpapers/gallery" ]] || return 1
    jq -e '
        .version == 1 and (.default | type == "string") and
        (.wallpapers | type == "array" and length > 0 and length <= 200) and
        all(.wallpapers[];
            (.id | type == "string" and test("^[a-z0-9][a-z0-9-]{0,63}$")) and
            (.name | type == "string" and length > 0 and length <= 100 and (test("[\u0000-\u001f\u007f]") | not)) and
            (.file | type == "string" and test("^[a-z0-9][a-z0-9._-]{0,120}\\.(png|jpg|jpeg|webp|avif)$"))) and
        ([.wallpapers[].id] | length == (unique | length)) and
        ([.wallpapers[].file] | length == (unique | length)) and
        (.default as $id | any(.wallpapers[]; .id == $id))
    ' "$JUNO_WALLPAPER_CATALOG" >/dev/null
}

juno_wallpaper_state_path() {
    local canonical_home canonical_state canonical_juno canonical_wallpaper
    JUNO_WALLPAPER_STATE=$JUNO_STATE_HOME/juno-desktop/wallpaper
    canonical_home=$(realpath -e -- "$HOME") || return 1
    canonical_state=$(realpath -m -- "$JUNO_STATE_HOME") || return 1
    canonical_juno=$(realpath -m -- "$JUNO_STATE_HOME/juno-desktop") || return 1
    canonical_wallpaper=$(realpath -m -- "$JUNO_WALLPAPER_STATE") || return 1
    [[ $canonical_state == "$canonical_home/"* &&
       $canonical_juno == "$canonical_state/juno-desktop" &&
       $canonical_wallpaper == "$canonical_juno/wallpaper" &&
       ! -L $JUNO_STATE_HOME/juno-desktop && ! -L $JUNO_WALLPAPER_STATE &&
       ( ! -e $JUNO_WALLPAPER_STATE || ( -d $JUNO_WALLPAPER_STATE && -O $JUNO_WALLPAPER_STATE ) ) ]] || return 1
    juno_safe_output "$JUNO_WALLPAPER_STATE/current"
}

juno_wallpaper_file() {
    local id=$1 name file canonical_file canonical_gallery
    [[ $id =~ ^[a-z0-9][a-z0-9-]{0,63}$ ]] || return 1
    name=$(jq -er --arg id "$id" '.wallpapers[] | select(.id == $id) | .file' "$JUNO_WALLPAPER_CATALOG") || return 1
    file=$JUNO_WALLPAPER_GALLERY/$name
    [[ -f $file && -r $file && ! -L $file ]] || return 1
    canonical_file=$(realpath -e -- "$file") || return 1
    canonical_gallery=$(realpath -e -- "$JUNO_WALLPAPER_GALLERY") || return 1
    [[ $canonical_file == "$canonical_gallery/$name" ]] || return 1
    printf '%s\n' "$file"
}

juno_wallpaper_current() {
    local id=''
    juno_wallpaper_catalog || return 1
    if juno_wallpaper_state_path && [[ -f $JUNO_WALLPAPER_STATE/current ]]; then
        IFS= read -r id < "$JUNO_WALLPAPER_STATE/current" || true
        if juno_wallpaper_file "$id" >/dev/null; then
            printf '%s\n' "$id"
            return 0
        fi
    fi
    id=$(jq -er '.default' "$JUNO_WALLPAPER_CATALOG") || return 1
    juno_wallpaper_file "$id" >/dev/null || return 1
    printf '%s\n' "$id"
}

juno_wallpaper_remember() {
    local id=$1 temporary
    juno_wallpaper_state_path || return 1
    juno_prepare_log_dir || return 1
    mkdir -p -- "$JUNO_WALLPAPER_STATE" || return 1
    chmod 700 -- "$JUNO_WALLPAPER_STATE" || return 1
    temporary=$(mktemp "$JUNO_WALLPAPER_STATE/.current.XXXXXX") || return 1
    if ! printf '%s\n' "$id" > "$temporary" || ! mv -f -- "$temporary" "$JUNO_WALLPAPER_STATE/current"; then
        rm -f -- "$temporary"
        return 1
    fi
}
