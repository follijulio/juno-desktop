#!/usr/bin/env bash
set -euo pipefail

# No Arch checks, package operations, or changes to the real HOME occur here.
# Git Bash mocks flock and sync; Linux locks/durability/permissions/symlinks
# still need native QA.
TEST_REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/juno-transaction-tests.XXXXXXXX")
TEST_ROOT=$(realpath -e -- "$TEST_ROOT")
TEST_REAL_MV=$(command -v mv)
TEST_REAL_TAR=$(command -v tar)
export TEST_REAL_MV TEST_REAL_TAR
trap '[[ -n "$TEST_ROOT" && "$TEST_ROOT" != / && "${TEST_ROOT##*/}" == juno-transaction-tests.* ]] && rm -rf -- "$TEST_ROOT"' EXIT
mkdir -- "$TEST_ROOT/mock-bin"

cat >"$TEST_ROOT/mock-bin/flock" <<'MOCK'
#!/usr/bin/env bash
[[ ${TEST_FLOCK_DENY:-0} == 0 ]]
MOCK
cat >"$TEST_ROOT/mock-bin/sync" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
count=0
[[ ! -f "$TEST_SYNC_COUNT_FILE" ]] || read -r count <"$TEST_SYNC_COUNT_FILE"
count=$((count + 1)); printf '%s\n' "$count" >"$TEST_SYNC_COUNT_FILE"
[[ ${TEST_SYNC_FAIL:-0} == 0 && $count != "${TEST_FAIL_SYNC_AT:-0}" ]]
MOCK
cat >"$TEST_ROOT/mock-bin/mv" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
count=0
[[ ! -f "$TEST_MV_COUNT_FILE" ]] || read -r count <"$TEST_MV_COUNT_FILE"
count=$((count + 1))
printf '%s\n' "$count" >"$TEST_MV_COUNT_FILE"
if [[ $count == "${TEST_FAIL_MV_AT:-0}" ]]; then exit 71; fi
exec "$TEST_REAL_MV" "$@"
MOCK
cat >"$TEST_ROOT/mock-bin/tar" <<'MOCK'
#!/usr/bin/env bash
[[ ${TEST_TAR_FAIL:-0} == 0 ]] || exit 72
exec "$TEST_REAL_TAR" "$@"
MOCK
chmod +x "$TEST_ROOT/mock-bin/"*
export PATH="$TEST_ROOT/mock-bin:$PATH"

fail() { printf 'FALHOU: %s\n' "$*" >&2; return 1; }
expect_file() { [[ -f "$1" && "$(cat -- "$1")" == "$2" ]] || fail "conteúdo inesperado: $1"; }
expect_absent() { [[ ! -e "$1" && ! -L "$1" ]] || fail "caminho deveria estar ausente: $1"; }
fixture() {
    CASE_ROOT=$(mktemp -d "$TEST_ROOT/case.XXXXXXXX")
    mkdir -- "$CASE_ROOT/home" "$CASE_ROOT/sources"
    JUNO_HOME=$(realpath -e -- "$CASE_ROOT/home")
    JUNO_STATE="$JUNO_HOME/.local/state/juno-desktop"
    JUNO_TARGETS=(.config/hypr .config/waybar .local/share/fonts/juno)
    JUNO_SOURCES=("$CASE_ROOT/sources/hypr" "$CASE_ROOT/sources/waybar" "$CASE_ROOT/sources/fonts")
    local source
    for source in "${JUNO_SOURCES[@]}"; do mkdir -- "$source"; printf 'novo\n' >"$source/value"; done
    export TEST_MV_COUNT_FILE="$CASE_ROOT/mv-count"
    export TEST_SYNC_COUNT_FILE="$CASE_ROOT/sync-count"
    export TEST_FAIL_MV_AT=0 TEST_TAR_FAIL=0 TEST_FLOCK_DENY=0 TEST_SYNC_FAIL=0 TEST_FAIL_SYNC_AT=0
    source "$TEST_REPO/lib/transaction.sh"
    txn_lock
}
old_configs() {
    local target
    for target in "${JUNO_TARGETS[@]}"; do mkdir -p -- "$JUNO_HOME/$target"; printf 'anterior\n' >"$JUNO_HOME/$target/value"; done
}
expect_old() {
    local target
    for target in "${JUNO_TARGETS[@]}"; do expect_file "$JUNO_HOME/$target/value" anterior; done
}
expect_new() {
    local target
    for target in "${JUNO_TARGETS[@]}"; do expect_file "$JUNO_HOME/$target/value" novo; done
}
full_install() { txn_prepare; txn_backup; txn_apply; txn_finalize; }

test_fresh() {
    fixture
    txn_prepare
    txn_changed || fail 'instalação nova deveria ter alterações'
    txn_backup; txn_apply; expect_new; txn_finalize
    expect_absent "$JUNO_STATE/pending.tsv"
    [[ ${#JUNO_TXN_DIRS[@]} == 0 ]] || fail 'áreas temporárias ainda registradas'
    txn_prepare
    if txn_changed; then fail 'reinstalação idêntica deveria ser inócua'; else [[ $? == 1 ]] || fail 'erro na comparação'; fi
    txn_cleanup_stage
    [[ "$(txn_list_backups | wc -l)" == 1 ]] || fail 'backup idêntico duplicado'
}
test_originals_and_restore() {
    fixture
    mkdir -p -- "$JUNO_HOME/.config/hypr"
    printf 'anterior\n' >"$JUNO_HOME/.config/hypr/value"
    full_install
    local initial=$JUNO_BACKUP_ID current
    printf 'edição posterior\n' >"$JUNO_HOME/.config/hypr/value"
    txn_restore "$initial"
    current=$JUNO_BACKUP_ID
    [[ "$current" != "$initial" ]] || fail 'estado atual não foi salvo'
    expect_file "$JUNO_HOME/.config/hypr/value" anterior
    expect_absent "$JUNO_HOME/.config/waybar"
    expect_absent "$JUNO_HOME/.local/share/fonts/juno"
    [[ -f "$JUNO_STATE/pending.tsv" ]] || fail 'restore deve aguardar verificações posteriores'
    txn_finalize
    txn_restore "$current"; txn_finalize
    expect_file "$JUNO_HOME/.config/hypr/value" 'edição posterior'
    expect_file "$JUNO_HOME/.config/waybar/value" novo
}
test_failure_points() {
    local point
    # 1 journal rename + 2 renames for each of the 3 existing targets.
    for point in 1 2 3 4 5 6 7; do
        (
            fixture; old_configs; txn_prepare; txn_backup
            printf '0\n' >"$TEST_MV_COUNT_FILE"; export TEST_FAIL_MV_AT=$point
            if txn_apply; then fail "falha $point não foi injetada"; fi
            txn_abort
            expect_old; expect_absent "$JUNO_STATE/pending.tsv"
        )
    done
}
test_abort_without_originals() {
    fixture; txn_prepare; txn_backup; txn_apply
    txn_abort
    local target
    for target in "${JUNO_TARGETS[@]}"; do expect_absent "$JUNO_HOME/$target"; done
}
test_postcheck_failure() {
    fixture; old_configs; full_install
    local backup=$JUNO_BACKUP_ID
    printf 'edição posterior\n' >"$JUNO_HOME/.config/hypr/value"
    txn_restore "$backup"
    txn_abort
    expect_file "$JUNO_HOME/.config/hypr/value" 'edição posterior'
    expect_file "$JUNO_HOME/.config/waybar/value" novo
}
test_process_recovery() {
    fixture; old_configs; txn_prepare; txn_backup; txn_apply
    # Drop all in-memory arrays, as a new installer process would.
    JUNO_TXN_DIRS=(); JUNO_STAGES=(); JUNO_ORIGINAL_KINDS=(); JUNO_DESIRED_KINDS=()
    txn_recover; expect_old; expect_absent "$JUNO_STATE/pending.tsv"
}
test_ambiguous_recovery() {
    fixture; old_configs; txn_prepare; txn_backup; txn_apply
    printf 'não apagar\n' >"$JUNO_HOME/.config/hypr/user-edit"
    if txn_recover; then fail 'recuperação ambígua deveria parar'; fi
    expect_file "$JUNO_HOME/.config/hypr/user-edit" 'não apagar'
    [[ -f "$JUNO_STATE/pending.tsv" && -d "${JUNO_TXN_DIRS[0]}/old" ]] || fail 'recuperação perdeu original ou registro'
    if txn_cleanup_stage; then fail 'limpeza não deveria apagar transação pendente'; fi
}
test_backup_failure() {
    fixture; old_configs; txn_prepare
    export TEST_TAR_FAIL=1
    if txn_backup; then fail 'backup deveria falhar'; fi
    export TEST_TAR_FAIL=0
    txn_abort; expect_old; expect_absent "$JUNO_STATE/pending.tsv"
}
test_changed_after_backup() {
    fixture; old_configs; txn_prepare; txn_backup
    printf 'edição concorrente\n' >"$JUNO_HOME/.config/hypr/value"
    if txn_apply; then fail 'alteração concorrente deveria impedir aplicação'; fi
    txn_abort
    expect_file "$JUNO_HOME/.config/hypr/value" 'edição concorrente'
    expect_file "$JUNO_HOME/.config/waybar/value" anterior
}
test_invalid_backup() {
    fixture; old_configs; full_install
    local backup=$JUNO_BACKUP_ID
    if txn_restore '../escape'; then fail 'ID inválido aceito'; fi
    printf 'corrompido\n' >"$JUNO_STATE/backups/$backup/configs.tar.gz"
    if txn_restore "$backup"; then fail 'checksum inválido aceito'; fi
    txn_abort; expect_new
}
test_traversal_archive() {
    fixture; old_configs; full_install
    local backup=$JUNO_BACKUP_ID digest
    "$TEST_REAL_TAR" -czf "$JUNO_STATE/backups/$backup/configs.tar.gz" --transform='s|.config/hypr|../escape|' -C "$JUNO_HOME" .config/hypr
    digest=$(sha256sum "$JUNO_STATE/backups/$backup/configs.tar.gz")
    printf '%s\n' "${digest%% *}" >"$JUNO_STATE/backups/$backup/archive.sha256"
    if txn_restore "$backup"; then fail 'arquivo com traversal aceito'; fi
    txn_abort; expect_new; expect_absent "$CASE_ROOT/escape"
}
test_lock_denied() {
    fixture
    export TEST_FLOCK_DENY=1
    if txn_lock; then fail 'bloqueio deveria falhar'; fi
    expect_absent "$JUNO_HOME/.config/hypr"
}
test_allowlist() {
    fixture
    JUNO_TARGETS=(../outside)
    if _txn_contract; then fail 'destino fora da lista aceito'; fi
    JUNO_TARGETS=(.config/hypr .config/hypr)
    if _txn_contract; then fail 'destino duplicado aceito'; fi
}
test_read_only_list() {
    fixture
    JUNO_LOCK_HELD=0
    txn_list_backups >/dev/null
    expect_absent "$JUNO_STATE/backups"
}
test_sync_failure() {
    fixture; old_configs; txn_prepare
    export TEST_SYNC_FAIL=1
    if txn_backup; then fail 'falha de persistência do backup foi ignorada'; fi
    export TEST_SYNC_FAIL=0
    txn_abort; expect_old; expect_absent "$JUNO_STATE/pending.tsv"
}
test_commit_sync_failure() {
    fixture; old_configs; txn_prepare; txn_backup; txn_apply
    printf '0\n' >"$TEST_SYNC_COUNT_FILE"
    export TEST_FAIL_SYNC_AT=4 # Three target flushes, then post-unlink state flush.
    txn_finalize
    [[ $JUNO_RETAIN_STAGE == 1 && -d "${JUNO_TXN_DIRS[0]}/old" ]] || fail 'falha após commit apagou material de recuperação'
    txn_abort
    [[ -d "${JUNO_TXN_DIRS[0]}/old" ]] || fail 'cleanup posterior apagou material preservado'
    expect_new; expect_absent "$JUNO_STATE/pending.tsv"
}
test_lock_special_file() {
    fixture
    rm -- "$JUNO_STATE/install.lock"
    if ! command -v mkfifo >/dev/null || ! mkfifo "$JUNO_STATE/install.lock" 2>/dev/null; then printf 'IGNORADO: FIFO indisponível; validar no Arch.\n'; return 77; fi
    if txn_lock; then fail 'FIFO aceito como arquivo de bloqueio'; fi
}
test_lock_hardlink() {
    fixture
    rm -- "$JUNO_STATE/install.lock"
    printf 'não truncar\n' >"$CASE_ROOT/important"
    if ! ln -- "$CASE_ROOT/important" "$JUNO_STATE/install.lock" 2>/dev/null; then printf 'IGNORADO: hardlink indisponível; validar no Arch.\n'; return 77; fi
    if [[ "$(stat -c %h "$JUNO_STATE/install.lock")" == 1 ]]; then printf 'IGNORADO: hardlink real indisponível; validar no Arch.\n'; return 77; fi
    if txn_lock; then fail 'hardlink aceito como arquivo de bloqueio'; fi
    expect_file "$CASE_ROOT/important" 'não truncar'
}
test_symlinks() {
    fixture
    mkdir -- "$CASE_ROOT/external"
    printf 'externo\n' >"$CASE_ROOT/external/value"
    mkdir -p -- "$JUNO_HOME/.config"
    ln -s -- "$CASE_ROOT/external" "$JUNO_HOME/.config/hypr"
    if [[ ! -L "$JUNO_HOME/.config/hypr" ]]; then printf 'IGNORADO: links simbólicos reais indisponíveis; validar no Arch.\n'; return 77; fi
    full_install
    local backup=$JUNO_BACKUP_ID
    expect_file "$CASE_ROOT/external/value" externo
    txn_restore "$backup"; txn_finalize
    [[ -L "$JUNO_HOME/.config/hypr" && "$(readlink "$JUNO_HOME/.config/hypr")" == "$CASE_ROOT/external" ]] || fail 'link original não foi restaurado'
    expect_file "$CASE_ROOT/external/value" externo
}
test_external_parent() {
    fixture
    mkdir -- "$CASE_ROOT/external"
    ln -s -- "$CASE_ROOT/external" "$JUNO_HOME/.config"
    if [[ ! -L "$JUNO_HOME/.config" ]]; then printf 'IGNORADO: links simbólicos reais indisponíveis; validar no Arch.\n'; return 77; fi
    if txn_prepare; then fail 'link ancestral externo aceito'; fi
    expect_absent "$CASE_ROOT/external/hypr"
}
test_source_symlink() {
    fixture
    printf 'fonte\n' >"$CASE_ROOT/source-file"
    ln -s -- "$CASE_ROOT/source-file" "${JUNO_SOURCES[0]}/link"
    if [[ ! -L "${JUNO_SOURCES[0]}/link" ]]; then printf 'IGNORADO: links simbólicos reais indisponíveis; validar no Arch.\n'; return 77; fi
    if txn_prepare; then fail 'link na fonte aceito'; fi
    txn_abort; expect_absent "$JUNO_HOME/.config/hypr"
}
test_archive_symlink_traversal() {
    fixture; old_configs
    mkdir -p -- "$CASE_ROOT/external" "$CASE_ROOT/evil/.config/hypr/real"
    printf 'externo\n' >"$CASE_ROOT/external/value"
    printf 'não sobrescrever\n' >"$CASE_ROOT/evil/.config/hypr/real/value"
    ln -s -- "$CASE_ROOT/external" "$CASE_ROOT/evil/.config/hypr/pivot"
    if [[ ! -L "$CASE_ROOT/evil/.config/hypr/pivot" ]]; then printf 'IGNORADO: links simbólicos reais indisponíveis; validar no Arch.\n'; return 77; fi
    full_install
    local backup=$JUNO_BACKUP_ID digest
    "$TEST_REAL_TAR" -czf "$JUNO_STATE/backups/$backup/configs.tar.gz" --transform='s|/real/|/pivot/|' -C "$CASE_ROOT/evil" .config/hypr/pivot .config/hypr/real/value
    digest=$(sha256sum "$JUNO_STATE/backups/$backup/configs.tar.gz")
    printf '%s\n' "${digest%% *}" >"$JUNO_STATE/backups/$backup/archive.sha256"
    if txn_restore "$backup"; then fail 'extração através de link simbólico foi aceita'; fi
    txn_abort; expect_new; expect_file "$CASE_ROOT/external/value" externo
}
test_resolved_aliases() {
    fixture
    mkdir -p -- "$JUNO_HOME/.local/share/fonts"
    ln -s -- "$JUNO_HOME/.local/share/fonts" "$JUNO_HOME/.config"
    if [[ ! -L "$JUNO_HOME/.config" ]]; then printf 'IGNORADO: links simbólicos reais indisponíveis; validar no Arch.\n'; return 77; fi
    JUNO_TARGETS=(.config/juno .local/share/fonts/juno)
    if _txn_contract; then fail 'destinos canônicos duplicados aceitos'; fi
    rm -- "$JUNO_HOME/.config"
    mkdir -p -- "$JUNO_HOME/.config/hypr"
    rm -r -- "$JUNO_HOME/.local/share/fonts"
    ln -s -- "$JUNO_HOME/.config/hypr" "$JUNO_HOME/.local/share/fonts"
    JUNO_TARGETS=(.config/hypr .local/share/fonts/juno)
    if _txn_contract; then fail 'destinos canônicos aninhados aceitos'; fi
    rm -- "$JUNO_HOME/.local/share/fonts"
    mv -- "$JUNO_HOME/.local/state" "$CASE_ROOT/state-save"
    ln -s -- "$JUNO_HOME/.config/hypr" "$JUNO_HOME/.local/state"
    if _txn_contract; then fail 'estado aninhado em destino gerenciado aceito'; fi
}
test_internal_parent() {
    fixture
    mkdir -- "$JUNO_HOME/configs"
    ln -s -- "$JUNO_HOME/configs" "$JUNO_HOME/.config"
    if [[ ! -L "$JUNO_HOME/.config" ]]; then printf 'IGNORADO: links simbólicos reais indisponíveis; validar no Arch.\n'; return 77; fi
    full_install; expect_new
}

passed=0; failed=0; skipped=0
for test in test_fresh test_originals_and_restore test_failure_points test_abort_without_originals test_postcheck_failure test_process_recovery test_ambiguous_recovery test_backup_failure test_changed_after_backup test_invalid_backup test_traversal_archive test_lock_denied test_allowlist test_read_only_list test_sync_failure test_commit_sync_failure test_lock_special_file test_lock_hardlink test_symlinks test_external_parent test_source_symlink test_archive_symlink_traversal test_resolved_aliases test_internal_parent; do
    printf 'Teste: %s\n' "$test"
    set +e
    ( set -euo pipefail; "$test" )
    result=$?
    set -e
    if [[ $result == 0 ]]; then passed=$((passed + 1)); elif [[ $result == 77 ]]; then skipped=$((skipped + 1)); else failed=$((failed + 1)); fi
done
printf '%s cenários passaram; %s ignorados; %s falharam. flock e sync simulados; validar concorrência e persistência reais no Arch.\n' "$passed" "$skipped" "$failed"
[[ $failed == 0 ]]
