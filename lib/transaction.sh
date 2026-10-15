#!/usr/bin/env bash
# Configuration-only transactions. Source this file from the non-root installer.

declare -ag JUNO_STAGES=() JUNO_TXN_DIRS=() JUNO_ORIGINAL_KINDS=() JUNO_DESIRED_KINDS=()
JUNO_LOCK_HELD=0
JUNO_BACKUP_ID=''
JUNO_RESTORE_TMP=''
JUNO_RETAIN_STAGE=0

_txn_error() { printf 'Erro de transação: %s\n' "$*" >&2; return 1; }
_txn_exists() { [[ -e "$1" || -L "$1" ]]; }
_txn_kind() {
    if [[ -L "$1" ]]; then printf 'symlink';
    elif [[ -d "$1" ]]; then printf 'directory';
    elif [[ -f "$1" ]]; then printf 'file';
    elif [[ ! -e "$1" ]]; then printf 'absent';
    else _txn_error "tipo de arquivo não suportado: $1"; fi
}
_txn_allowed() {
    case "$1" in
        .config/hypr|.config/waybar|.config/rofi|.config/mako|.config/kitty|.config/juno|.config/xdg-desktop-portal|.local/share/fonts/juno|.local/share/juno-desktop) return 0;;
        *) return 1;;
    esac
}
_txn_under_home() { [[ "$1" == "$JUNO_HOME" || "$1" == "$JUNO_HOME/"* ]]; }
_txn_contract() {
    local canonical target previous='|' uid state_expected state_canonical parent live earlier
    local -a live_paths=()
    [[ -n "${JUNO_HOME:-}" && "$JUNO_HOME" == /* && "$JUNO_HOME" != / ]] || { _txn_error 'diretório pessoal inválido'; return 1; }
    [[ "$JUNO_HOME" != *$'\n'* && "$JUNO_HOME" != *$'\t'* ]] || { _txn_error 'diretório pessoal contém caracteres não suportados'; return 1; }
    canonical=$(realpath -e -- "$JUNO_HOME") || return 1
    [[ "$canonical" == "$JUNO_HOME" && -d "$canonical" ]] || { _txn_error 'JUNO_HOME precisa ser canônico'; return 1; }
    uid=$(id -u) || return 1
    [[ "$(stat -c %u -- "$canonical")" == "$uid" ]] || { _txn_error 'diretório pessoal pertence a outro usuário'; return 1; }
    state_expected="$JUNO_HOME/.local/state/juno-desktop"
    state_canonical=$(realpath -m -- "$state_expected") || return 1
    [[ "${JUNO_STATE:-}" == "$state_expected" || "${JUNO_STATE:-}" == "$state_canonical" ]] || { _txn_error 'diretório de estado inválido'; return 1; }
    _txn_under_home "$state_canonical" || { _txn_error 'diretório de estado sai do diretório pessoal'; return 1; }
    [[ ${#JUNO_TARGETS[@]} -gt 0 ]] || { _txn_error 'nenhum destino configurado'; return 1; }
    for target in "${JUNO_TARGETS[@]}"; do
        _txn_allowed "$target" && [[ "$previous" != *"|$target|"* ]] || { _txn_error "destino inválido ou repetido: $target"; return 1; }
        previous+="$target|"
        # Resolve ancestors only: an existing target symlink is an object to
        # preserve, never a destination whose referent should be overwritten.
        parent=$(realpath -m -- "$JUNO_HOME/$(dirname -- "$target")") || return 1
        _txn_under_home "$parent" || { _txn_error "ancestral sai do diretório pessoal: $target"; return 1; }
        live="$parent/${target##*/}"
        [[ "$state_canonical" != "$live" && "$state_canonical" != "$live/"* && "$live" != "$state_canonical/"* ]] || { _txn_error "destino se sobrepõe ao estado da instalação: $target"; return 1; }
        for earlier in "${live_paths[@]}"; do
            [[ "$live" != "$earlier" && "$live" != "$earlier/"* && "$earlier" != "$live/"* ]] || { _txn_error "destinos resolvidos se sobrepõem: $target"; return 1; }
        done
        live_paths+=("$live")
    done
}

# Check each existing ancestor before mkdir can follow it. Internal home links
# are supported; a link pointing outside the home is never traversed.
_txn_mkdir_home() {
    local relative=$1 cursor=$JUNO_HOME component canonical uid
    local -a components=()
    uid=$(id -u) || return 1
    IFS=/ read -r -a components <<< "$relative"
    for component in "${components[@]}"; do
        [[ -n "$component" && "$component" != . && "$component" != .. ]] || { _txn_error 'componente de caminho inválido'; return 1; }
        cursor+="/$component"
        if _txn_exists "$cursor"; then
            [[ -d "$cursor" ]] || { _txn_error "diretório esperado: $cursor"; return 1; }
            canonical=$(realpath -e -- "$cursor") || return 1
            _txn_under_home "$canonical" || { _txn_error "caminho sai do diretório pessoal: $cursor"; return 1; }
            [[ "$(stat -c %u -- "$canonical")" == "$uid" ]] || { _txn_error "diretório pertence a outro usuário: $cursor"; return 1; }
        else
            mkdir -- "$cursor" || return 1
        fi
    done
}
_txn_parent() {
    local target=$1 parent
    _txn_allowed "$target" || { _txn_error "destino inválido: $target"; return 1; }
    parent=$(realpath -e -- "$JUNO_HOME/$(dirname -- "$target")") || return 1
    _txn_under_home "$parent" || { _txn_error "destino sai do diretório pessoal: $target"; return 1; }
    printf '%s\n' "$parent"
}
_txn_live() { local parent; parent=$(_txn_parent "$1") || return 1; printf '%s/%s\n' "$parent" "${1##*/}"; }
_txn_safe_stage() {
    local stage=$1 target=$2 parent canonical
    parent=$(_txn_parent "$target") || return 1
    [[ "${stage%/*}" == "$parent" && "${stage##*/}" =~ ^\.juno-stage\.[[:alnum:]]{8}$ && -d "$stage" && ! -L "$stage" ]] || { _txn_error "área temporária inválida: $stage"; return 1; }
    canonical=$(realpath -e -- "$stage") || return 1
    [[ "$canonical" == "$stage" && "$(stat -c %u -- "$stage")" == "$(id -u)" ]] || { _txn_error "área temporária sem propriedade válida: $stage"; return 1; }
}
_txn_require_lock() { [[ ${JUNO_LOCK_HELD:-0} == 1 ]] || { _txn_error 'a transação exige o bloqueio de instalação'; return 1; }; }

txn_lock() {
    _txn_contract || return 1
    umask 077
    _txn_mkdir_home '.local/state/juno-desktop' || return 1
    [[ ! -L "$JUNO_STATE" ]] || { _txn_error 'o diretório de estado não pode ser um link'; return 1; }
    JUNO_STATE=$(realpath -e -- "$JUNO_STATE") || return 1
    chmod 700 -- "$JUNO_STATE" || return 1
    if _txn_exists "$JUNO_STATE/install.lock"; then
        [[ -f "$JUNO_STATE/install.lock" && ! -L "$JUNO_STATE/install.lock" && "$(stat -c %u -- "$JUNO_STATE/install.lock")" == "$(id -u)" && "$(stat -c %h -- "$JUNO_STATE/install.lock")" == 1 ]] || { _txn_error 'arquivo de bloqueio precisa ser regular, próprio e sem links'; return 1; }
    fi
    # Append avoids truncating a preexisting file even before flock succeeds.
    exec {JUNO_LOCK_FD}>>"$JUNO_STATE/install.lock" || return 1
    flock -n "$JUNO_LOCK_FD" || { _txn_error 'outra instalação ou recuperação está em andamento'; return 1; }
    JUNO_LOCK_HELD=1
}

_txn_new_stage() {
    local index=$1 parent stage live
    _txn_mkdir_home "$(dirname -- "${JUNO_TARGETS[index]}")" || return 1
    parent=$(_txn_parent "${JUNO_TARGETS[index]}") || return 1
    live="$parent/${JUNO_TARGETS[index]##*/}"
    stage=$(mktemp -d "$parent/.juno-stage.XXXXXXXX") || return 1
    JUNO_TXN_DIRS[index]=$stage
    JUNO_STAGES[index]="$stage/new"
    JUNO_ORIGINAL_KINDS[index]=$(_txn_kind "$live") || return 1
    chmod 700 -- "$stage" || return 1
}
txn_prepare() {
    local index source unusual
    _txn_require_lock || return 1
    _txn_contract || return 1
    [[ ! -e "$JUNO_STATE/pending.tsv" && ! -L "$JUNO_STATE/pending.tsv" ]] || { _txn_error 'recupere a transação pendente primeiro'; return 1; }
    [[ ${#JUNO_TARGETS[@]} -eq ${#JUNO_SOURCES[@]} ]] || { _txn_error 'fontes e destinos não correspondem'; return 1; }
    JUNO_STAGES=(); JUNO_TXN_DIRS=(); JUNO_ORIGINAL_KINDS=(); JUNO_DESIRED_KINDS=(); JUNO_BACKUP_ID=''; JUNO_RETAIN_STAGE=0
    for index in "${!JUNO_TARGETS[@]}"; do
        source=${JUNO_SOURCES[index]}
        [[ -d "$source" && ! -L "$source" ]] || { _txn_error "fonte precisa ser um diretório real: $source"; return 1; }
        unusual=$(find -P "$source" ! -type d ! -type f -print -quit) || return 1
        [[ -z "$unusual" ]] || { _txn_error "fonte contém link ou arquivo especial: $unusual"; return 1; }
        _txn_new_stage "$index" || return 1
        cp -a -- "$source" "${JUNO_STAGES[index]}" || return 1
        JUNO_DESIRED_KINDS[index]=directory
    done
}

# Return 0 for equality, 1 for changes, 2 for an unreadable tree.
_txn_same() {
    local first=$1 second=$2 first_kind second_kind result first_metadata second_metadata
    first_kind=$(_txn_kind "$first") || return 2
    second_kind=$(_txn_kind "$second") || return 2
    [[ "$first_kind" == "$second_kind" ]] || return 1
    case "$first_kind" in
        absent) return 0;;
        symlink) cmp -s <(readlink -z -- "$first") <(readlink -z -- "$second"); return;;
    esac
    if diff -r --no-dereference -- "$first" "$second" >/dev/null; then :; else
        result=$?; [[ $result == 1 ]] && return 1; return 2
    fi
    if [[ "$first_kind" == file ]]; then
        [[ "$(stat -c %a -- "$first")" == "$(stat -c %a -- "$second")" ]]
    else
        first_metadata=$(find -P "$first" -printf '%P\t%y\t%m\t%l\n' | LC_ALL=C sort) || return 2
        second_metadata=$(find -P "$second" -printf '%P\t%y\t%m\t%l\n' | LC_ALL=C sort) || return 2
        [[ "$first_metadata" == "$second_metadata" ]]
    fi
}
txn_changed() {
    local index live result
    [[ ${#JUNO_STAGES[@]} -eq ${#JUNO_TARGETS[@]} ]] || { _txn_error 'a preparação está incompleta'; return 2; }
    for index in "${!JUNO_TARGETS[@]}"; do
        live=$(_txn_live "${JUNO_TARGETS[index]}") || return 2
        if _txn_same "$live" "${JUNO_STAGES[index]}"; then :; else
            result=$?; [[ $result == 1 ]] && return 0
            _txn_error "não foi possível comparar: $live"; return 2
        fi
    done
    return 1
}

txn_backup() {
    local temporary tree manifest index target live kind id digest
    local -a existing=()
    _txn_require_lock || return 1
    [[ ${#JUNO_TXN_DIRS[@]} -eq ${#JUNO_TARGETS[@]} ]] || { _txn_error 'prepare os destinos antes do backup'; return 1; }
    _txn_mkdir_home '.local/state/juno-desktop/backups' || return 1
    [[ ! -L "$JUNO_STATE/backups" ]] || { _txn_error 'diretório de backups inválido'; return 1; }
    chmod 700 -- "$JUNO_STATE/backups" || return 1
    temporary=$(mktemp -d "$JUNO_STATE/backups/.backup.XXXXXXXX") || return 1
    tree="$temporary/tree"; manifest="$temporary/manifest.tsv"
    mkdir -- "$tree" || return 1
    printf 'juno-backup\t1\t%s\t%s\n' "$(id -u)" "$JUNO_HOME" >"$manifest" || return 1
    for index in "${!JUNO_TARGETS[@]}"; do
        target=${JUNO_TARGETS[index]}; live=$(_txn_live "$target") || return 1
        kind=$(_txn_kind "$live") || return 1
        [[ "$kind" == "${JUNO_ORIGINAL_KINDS[index]}" ]] || { _txn_error "destino mudou durante a preparação: $target"; return 1; }
        printf 'target\t%s\t%s\n' "$target" "$kind" >>"$manifest" || return 1
        _txn_safe_stage "${JUNO_TXN_DIRS[index]}" "$target" || return 1
        if [[ "$kind" != absent ]]; then
            mkdir -p -- "$tree/$(dirname -- "$target")" || return 1
            cp -a -- "$live" "$tree/$target" || return 1
            cp -a -- "$tree/$target" "${JUNO_TXN_DIRS[index]}/before" || return 1
            existing+=("$target")
        fi
    done
    if [[ ${#existing[@]} -gt 0 ]]; then
        tar -czf "$temporary/configs.tar.gz" -C "$tree" -- "${existing[@]}" || return 1
    else
        tar -czf "$temporary/configs.tar.gz" -C "$tree" --files-from /dev/null || return 1
    fi
    tar -tzf "$temporary/configs.tar.gz" >/dev/null || return 1
    digest=$(sha256sum -- "$temporary/configs.tar.gz") || return 1
    printf '%s\n' "${digest%% *}" >"$temporary/archive.sha256" || return 1
    rm -rf -- "$tree" || return 1
    id="$(date -u +%Y%m%dT%H%M%SZ)-${temporary##*.}"
    mv -T -- "$temporary" "$JUNO_STATE/backups/$id" || return 1
    sync -f "$JUNO_STATE/backups" || return 1
    JUNO_BACKUP_ID=$id
    printf 'Backup criado: %s\n' "$id"
}

_txn_write_journal() {
    local temporary index
    temporary=$(mktemp "$JUNO_STATE/.pending.XXXXXXXX") || return 1
    printf 'juno-pending\t1\t%s\t%s\n' "$(id -u)" "$JUNO_HOME" >"$temporary" || return 1
    for index in "${!JUNO_TARGETS[@]}"; do
        printf 'target\t%s\t%s\t%s\t%s\n' "${JUNO_TARGETS[index]}" "${JUNO_TXN_DIRS[index]}" "${JUNO_ORIGINAL_KINDS[index]}" "${JUNO_DESIRED_KINDS[index]}" >>"$temporary" || return 1
    done
    mv -T -- "$temporary" "$JUNO_STATE/pending.tsv" || return 1
    sync -f "$JUNO_STATE" || return 1
}
txn_apply() {
    local index stage live
    _txn_require_lock || return 1
    [[ -n "$JUNO_BACKUP_ID" && -d "$JUNO_STATE/backups/$JUNO_BACKUP_ID" ]] || { _txn_error 'um backup verificado é obrigatório'; return 1; }
    [[ ! -e "$JUNO_STATE/pending.tsv" && ! -L "$JUNO_STATE/pending.tsv" ]] || { _txn_error 'já existe uma transação pendente'; return 1; }
    for index in "${!JUNO_TARGETS[@]}"; do
        stage=${JUNO_TXN_DIRS[index]}; live=$(_txn_live "${JUNO_TARGETS[index]}") || return 1
        _txn_safe_stage "$stage" "${JUNO_TARGETS[index]}" || return 1
        _txn_same "$live" "$stage/before" || { _txn_error "configuração mudou depois do backup: ${JUNO_TARGETS[index]}"; return 1; }
        if [[ "${JUNO_DESIRED_KINDS[index]}" != absent ]]; then cp -a -- "$stage/new" "$stage/reference" || return 1; fi
        sync -f "$stage" || return 1
    done
    _txn_write_journal || return 1
    for index in "${!JUNO_TARGETS[@]}"; do
        stage=${JUNO_TXN_DIRS[index]}; live=$(_txn_live "${JUNO_TARGETS[index]}") || return 1
        if [[ "${JUNO_ORIGINAL_KINDS[index]}" != absent ]]; then
            mv -T -- "$live" "$stage/old" || return 1
            sync -f "$stage" || return 1
        fi
        if [[ "${JUNO_DESIRED_KINDS[index]}" != absent ]]; then
            mv -T -- "$stage/new" "$live" || return 1
            sync -f "$stage" || return 1
        fi
    done
}

_txn_read_journal() {
    local label version uid home extra target stage original desired index=0
    local -a stages=() originals=() desireds=()
    [[ -f "$JUNO_STATE/pending.tsv" && ! -L "$JUNO_STATE/pending.tsv" ]] || { _txn_error 'registro de transação inválido'; return 1; }
    {
        IFS=$'\t' read -r label version uid home extra || return 1
        [[ "$label" == juno-pending && "$version" == 1 && "$uid" == "$(id -u)" && "$home" == "$JUNO_HOME" && -z "$extra" ]] || { _txn_error 'registro pertence a outro usuário ou ambiente'; return 1; }
        while IFS=$'\t' read -r label target stage original desired extra; do
            [[ "$label" == target && $index -lt ${#JUNO_TARGETS[@]} && "$target" == "${JUNO_TARGETS[index]}" && -z "$extra" ]] || { _txn_error 'destinos do registro não correspondem à instalação'; return 1; }
            case "$original:$desired" in
                absent:absent|absent:directory|absent:symlink|absent:file|directory:absent|directory:directory|directory:symlink|directory:file|symlink:absent|symlink:directory|symlink:symlink|symlink:file|file:absent|file:directory|file:symlink|file:file) :;;
                *) _txn_error 'tipo inválido no registro'; return 1;;
            esac
            _txn_safe_stage "$stage" "$target" || return 1
            stages+=("$stage"); originals+=("$original"); desireds+=("$desired"); index=$((index + 1))
        done
    } <"$JUNO_STATE/pending.tsv"
    [[ $index -eq ${#JUNO_TARGETS[@]} ]] || { _txn_error 'registro incompleto; áreas temporárias foram mantidas'; return 1; }
    JUNO_TXN_DIRS=("${stages[@]}"); JUNO_ORIGINAL_KINDS=("${originals[@]}"); JUNO_DESIRED_KINDS=("${desireds[@]}"); JUNO_STAGES=()
    for stage in "${stages[@]}"; do JUNO_STAGES+=("$stage/new"); done
}
_txn_recovery_safe() {
    local index stage live original desired
    for index in "${!JUNO_TARGETS[@]}"; do
        stage=${JUNO_TXN_DIRS[index]}; original=${JUNO_ORIGINAL_KINDS[index]}; desired=${JUNO_DESIRED_KINDS[index]}
        live=$(_txn_live "${JUNO_TARGETS[index]}") || return 1
        if [[ "$desired" != absent ]] && ! _txn_exists "$stage/new"; then
            [[ "$original" == absent ]] || _txn_exists "$stage/old" || return 1
            _txn_same "$live" "$stage/reference" || return 1
        elif _txn_exists "$stage/old"; then
            ! _txn_exists "$live" || return 1
        elif [[ "$original" == absent ]]; then
            ! _txn_exists "$live" || return 1
        else
            _txn_same "$live" "$stage/before" || return 1
        fi
    done
}
txn_recover() {
    local index stage live
    _txn_require_lock || return 1
    _txn_exists "$JUNO_STATE/pending.tsv" || return 0
    _txn_read_journal || return 1
    _txn_recovery_safe || { _txn_error 'recuperação ambígua: arquivos foram alterados. Registro, backup e áreas temporárias foram preservados'; return 1; }
    for ((index=${#JUNO_TARGETS[@]} - 1; index>=0; index--)); do
        stage=${JUNO_TXN_DIRS[index]}; live=$(_txn_live "${JUNO_TARGETS[index]}") || return 1
        if [[ "${JUNO_DESIRED_KINDS[index]}" != absent ]] && ! _txn_exists "$stage/new"; then
            mv -T -- "$live" "$stage/new" || return 1
            sync -f "$stage" || return 1
        fi
        if _txn_exists "$stage/old"; then
            mv -T -- "$stage/old" "$live" || return 1
            sync -f "$stage" || return 1
        fi
    done
    _txn_remove_committed_journal || return 1
    txn_cleanup_stage || return 1
    printf 'Transação interrompida recuperada; configurações anteriores restauradas.\n'
}
txn_abort() {
    [[ ${JUNO_LOCK_HELD:-0} == 1 ]] || return 0
    if _txn_exists "$JUNO_STATE/pending.tsv"; then txn_recover; else txn_cleanup_stage; fi
}
txn_cleanup_stage() {
    local index stage
    [[ ${JUNO_RETAIN_STAGE:-0} != 1 ]] || return 0
    if _txn_exists "$JUNO_STATE/pending.tsv"; then _txn_error 'áreas temporárias mantidas enquanto houver uma transação pendente'; return 1; fi
    for index in "${!JUNO_TXN_DIRS[@]}"; do
        stage=${JUNO_TXN_DIRS[index]}
        _txn_exists "$stage" || continue
        _txn_safe_stage "$stage" "${JUNO_TARGETS[index]}" || return 1
        rm -rf -- "$stage" || return 1
    done
    JUNO_TXN_DIRS=(); JUNO_STAGES=(); JUNO_ORIGINAL_KINDS=(); JUNO_DESIRED_KINDS=()
    if [[ -n "${JUNO_RESTORE_TMP:-}" && "${JUNO_RESTORE_TMP%/*}" == "$JUNO_STATE" && "${JUNO_RESTORE_TMP##*/}" =~ ^\.restore\.[[:alnum:]]{8}$ && -d "$JUNO_RESTORE_TMP" && ! -L "$JUNO_RESTORE_TMP" ]]; then
        rm -rf -- "$JUNO_RESTORE_TMP" || return 1
        JUNO_RESTORE_TMP=''
    fi
}
_txn_remove_committed_journal() {
    rm -- "$JUNO_STATE/pending.tsv" || return 1
    if ! sync -f "$JUNO_STATE"; then
        # All target filesystems have already been flushed. The journal may
        # reappear after a crash if its unlink could not be made durable; keep
        # its stages so recovery remains possible in that case.
        JUNO_RETAIN_STAGE=1
        printf 'Aviso: alterações confirmadas; não foi possível sincronizar a remoção do registro. Áreas temporárias e backups foram preservados em %s.\n' "$JUNO_STATE" >&2
    fi
}
txn_finalize() {
    local index
    _txn_require_lock || return 1
    [[ -f "$JUNO_STATE/pending.tsv" && ! -L "$JUNO_STATE/pending.tsv" ]] || { _txn_error 'não há transação aplicada para finalizar'; return 1; }
    for index in "${!JUNO_TARGETS[@]}"; do sync -f "${JUNO_TXN_DIRS[index]}" || return 1; done
    _txn_remove_committed_journal || return 1
    if ! txn_cleanup_stage; then printf 'Aviso: instalação concluída; algumas áreas temporárias foram mantidas.\n' >&2; fi
}

txn_list_backups() {
    local backup found=0 canonical
    _txn_contract || return 1
    [[ -d "$JUNO_STATE/backups" && ! -L "$JUNO_STATE/backups" ]] || { printf 'Nenhum backup disponível.\n'; return 0; }
    canonical=$(realpath -e -- "$JUNO_STATE/backups") || return 1
    _txn_under_home "$canonical" && [[ "$(stat -c %u -- "$canonical")" == "$(id -u)" ]] || { _txn_error 'diretório de backups sem propriedade válida'; return 1; }
    while IFS= read -r backup; do
        [[ "$backup" =~ ^[0-9]{8}T[0-9]{6}Z-[[:alnum:]]{8}$ ]] || continue
        printf '%s\n' "$backup"; found=1
    done < <(find "$JUNO_STATE/backups" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort -r)
    [[ $found == 1 ]] || printf 'Nenhum backup disponível.\n'
}
_txn_read_backup() {
    local backup=$1 label version uid home extra target kind index=0 digest expected member allowed candidate
    JUNO_RESTORE_KINDS=()
    [[ -d "$backup" && ! -L "$backup" && -f "$backup/manifest.tsv" && ! -L "$backup/manifest.tsv" && -f "$backup/configs.tar.gz" && ! -L "$backup/configs.tar.gz" && -f "$backup/archive.sha256" && ! -L "$backup/archive.sha256" ]] || { _txn_error 'backup incompleto ou inválido'; return 1; }
    {
        IFS=$'\t' read -r label version uid home extra || return 1
        [[ "$label" == juno-backup && "$version" == 1 && "$uid" == "$(id -u)" && "$home" == "$JUNO_HOME" && -z "$extra" ]] || { _txn_error 'backup pertence a outro usuário ou ambiente'; return 1; }
        while IFS=$'\t' read -r label target kind extra; do
            [[ "$label" == target && $index -lt ${#JUNO_TARGETS[@]} && "$target" == "${JUNO_TARGETS[index]}" && -z "$extra" ]] || { _txn_error 'manifesto de backup inválido'; return 1; }
            case "$kind" in absent|file|directory|symlink) :;; *) _txn_error 'tipo inválido no backup'; return 1;; esac
            JUNO_RESTORE_KINDS+=("$kind"); index=$((index + 1))
        done
    } <"$backup/manifest.tsv"
    [[ $index -eq ${#JUNO_TARGETS[@]} ]] || { _txn_error 'manifesto de backup incompleto'; return 1; }
    expected=$(cat -- "$backup/archive.sha256") || return 1
    [[ "$expected" =~ ^[0-9a-f]{64}$ ]] || { _txn_error 'checksum do backup inválido'; return 1; }
    digest=$(sha256sum -- "$backup/configs.tar.gz") || return 1
    [[ "${digest%% *}" == "$expected" ]] || { _txn_error 'checksum do backup não confere'; return 1; }
    tar --quoting-style=literal -tzf "$backup/configs.tar.gz" >"$JUNO_RESTORE_TMP/members" || return 1
    while IFS= read -r member; do
        member=${member%/}
        [[ -n "$member" && "$member" != /* && "$member" != .. && "$member" != ../* && "$member" != */../* && "$member" != */.. ]] || { _txn_error 'caminho inseguro no arquivo de backup'; return 1; }
        allowed=0
        for index in "${!JUNO_TARGETS[@]}"; do
            candidate=${JUNO_TARGETS[index]}
            if [[ "${JUNO_RESTORE_KINDS[index]}" != absent && ( "$member" == "$candidate" || "$member" == "$candidate/"* ) ]]; then allowed=1; break; fi
        done
        [[ $allowed == 1 ]] || { _txn_error "conteúdo fora dos destinos autorizados: $member"; return 1; }
    done <"$JUNO_RESTORE_TMP/members"
}
txn_restore() {
    local id=${1:-} backup index kind extract
    _txn_require_lock || return 1
    _txn_contract || return 1
    [[ "$id" =~ ^[0-9]{8}T[0-9]{6}Z-[[:alnum:]]{8}$ ]] || { _txn_error 'identificador de backup inválido'; return 1; }
    [[ ! -L "$JUNO_STATE/backups" ]] || { _txn_error 'diretório de backups inválido'; return 1; }
    txn_recover || return 1
    backup="$JUNO_STATE/backups/$id"
    JUNO_RESTORE_TMP=$(mktemp -d "$JUNO_STATE/.restore.XXXXXXXX") || return 1
    _txn_read_backup "$backup" || return 1
    extract="$JUNO_RESTORE_TMP/tree"; mkdir -- "$extract" || return 1
    # GNU tar rejects extraction through directory symlinks by default.
    # Unlink files before replacement, so crafted hard links cannot overwrite
    # an existing inode through a subsequent archive member.
    tar -xzf "$backup/configs.tar.gz" -C "$extract" --no-same-owner --same-permissions --unlink-first || return 1
    JUNO_STAGES=(); JUNO_TXN_DIRS=(); JUNO_ORIGINAL_KINDS=(); JUNO_DESIRED_KINDS=(); JUNO_BACKUP_ID=''; JUNO_RETAIN_STAGE=0
    for index in "${!JUNO_TARGETS[@]}"; do
        kind=$(_txn_kind "$extract/${JUNO_TARGETS[index]}") || return 1
        [[ "$kind" == "${JUNO_RESTORE_KINDS[index]}" ]] || { _txn_error 'tipo extraído não corresponde ao manifesto'; return 1; }
        _txn_new_stage "$index" || return 1
        JUNO_DESIRED_KINDS[index]=$kind
        if [[ "$kind" != absent ]]; then cp -a -- "$extract/${JUNO_TARGETS[index]}" "${JUNO_STAGES[index]}" || return 1; fi
    done
    rm -rf -- "$JUNO_RESTORE_TMP" || return 1; JUNO_RESTORE_TMP=''
    txn_backup || return 1
    txn_apply || return 1
    printf 'Backup aplicado: %s. O estado substituído também foi salvo; a finalização depende das verificações posteriores.\n' "$id"
}
