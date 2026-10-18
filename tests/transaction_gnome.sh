#!/usr/bin/env bash
# Files + per-key settings transactions. Backend/locks/durability are mocked;
# this suite never writes the real HOME or starts a desktop.
# shellcheck disable=SC2329,SC2032
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/juno-gnome-transactions.XXXXXXXX")
trap 'rm -rf -- "$TEST_ROOT"' EXIT
mkdir "$TEST_ROOT/mock-bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TEST_ROOT/mock-bin/flock"
cp "$TEST_ROOT/mock-bin/flock" "$TEST_ROOT/mock-bin/sync"
chmod +x "$TEST_ROOT/mock-bin/"*
export PATH="$TEST_ROOT/mock-bin:$PATH"

fail() { printf 'FALHOU: %s\n' "$*" >&2; return 1; }
expect_absent() { [[ ! -e $1 && ! -L $1 ]] || fail "arquivo deveria estar ausente: $1"; }

# The two tab-separated mock values stand in for validated GVariant snapshots;
# the helper's real JSON/schema validation has separate Python tests.
juno_gsettings_snapshot() { printf '%s\t%s\n' "$MOCK_FIRST" "$MOCK_SECOND" > "$1"; }
juno_gsettings_desired() { printf 'Roboto\tGhibli\n' > "$1"; }
juno_gsettings_validate() { [[ -f $1 ]]; }
juno_gsettings_verify() {
    local first second
    [[ ${MOCK_UNAVAILABLE:-0} == 0 ]] || return 2
    IFS=$'\t' read -r first second < "$1"
    [[ $MOCK_FIRST == "$first" && $MOCK_SECOND == "$second" ]]
}
juno_gsettings_restore() {
    local first second
    [[ ${MOCK_UNAVAILABLE:-0} == 0 ]] || return 2
    IFS=$'\t' read -r first second < "$1"
    MOCK_FIRST=$first
    if [[ $MOCK_FAIL_ONCE == 1 ]]; then MOCK_FAIL_ONCE=0; return 1; fi
    MOCK_SECOND=$second
}
juno_gsettings_recovery_check() {
    local before_first before_second desired_first desired_second
    [[ ${MOCK_UNAVAILABLE:-0} == 0 ]] || return 2
    IFS=$'\t' read -r before_first before_second < "$1"
    IFS=$'\t' read -r desired_first desired_second < "$2"
    [[ ( $MOCK_FIRST == "$before_first" || $MOCK_FIRST == "$desired_first" ) &&
       ( $MOCK_SECOND == "$before_second" || $MOCK_SECOND == "$desired_second" ) ]]
}

fixture() {
    CASE_ROOT=$(mktemp -d "$TEST_ROOT/case.XXXXXXXX")
    mkdir "$CASE_ROOT/home with spaces" "$CASE_ROOT/source"
    JUNO_HOME=$(realpath -e "$CASE_ROOT/home with spaces")
    JUNO_STATE="$JUNO_HOME/.local/state/juno-desktop"
    JUNO_TARGETS=(.bashrc .config/juno-gnome)
    JUNO_SOURCES=("$CASE_ROOT/source/bashrc" "$CASE_ROOT/source/gnome")
    printf 'new rc\n' > "${JUNO_SOURCES[0]}"
    mkdir "${JUNO_SOURCES[1]}"
    printf 'new config\n' > "${JUNO_SOURCES[1]}/value"
    MOCK_FIRST=null; MOCK_SECOND=original; MOCK_FAIL_ONCE=0; MOCK_UNAVAILABLE=0
    source "$ROOT/lib/transaction.sh"
    JUNO_GSETTINGS_ENABLED=1
    txn_lock
}

test_new_and_idempotent() {
    fixture
    mkdir "${JUNO_SOURCES[1]}/__pycache__"
    printf 'ignored cache\n' > "${JUNO_SOURCES[1]}/__pycache__/example.pyc"
    txn_prepare
    [[ -f $(txn_stage_for .bashrc) ]] || fail 'staging de arquivo não disponível'
    expect_absent "$(txn_stage_for .config/juno-gnome)/__pycache__"
    txn_backup; txn_apply; txn_finalize
    [[ $(cat "$JUNO_HOME/.bashrc") == 'new rc' && $MOCK_FIRST == Roboto && $MOCK_SECOND == Ghibli ]]
    grep -q $'^juno-backup\t2\t' "$JUNO_STATE/backups/$JUNO_BACKUP_ID/manifest.tsv"
    local backup=$JUNO_BACKUP_ID
    txn_prepare
    if txn_changed; then fail 'reinstalação idêntica criou alterações'; else [[ $? == 1 ]]; fi
    txn_cleanup_stage
    [[ $(find "$JUNO_STATE/backups" -mindepth 1 -maxdepth 1 -type d | wc -l) == 1 ]]
    [[ -d $JUNO_STATE/backups/$backup ]]
}

test_restore_values_and_absence() {
    fixture
    txn_prepare; txn_backup; txn_apply; txn_finalize
    local initial=$JUNO_BACKUP_ID
    printf 'edited rc\n' > "$JUNO_HOME/.bashrc"
    MOCK_FIRST=custom; MOCK_SECOND=photo
    txn_restore "$initial"
    local saved_edits=$JUNO_BACKUP_ID
    [[ $MOCK_FIRST == null && $MOCK_SECOND == original ]]
    expect_absent "$JUNO_HOME/.bashrc"
    expect_absent "$JUNO_HOME/.config/juno-gnome"
    txn_finalize
    txn_restore "$saved_edits"
    [[ $(cat "$JUNO_HOME/.bashrc") == 'edited rc' && $MOCK_FIRST == custom && $MOCK_SECOND == photo ]]
    txn_finalize
}

test_partial_settings_failure() {
    fixture
    printf 'old rc\n' > "$JUNO_HOME/.bashrc"
    txn_prepare; txn_backup
    MOCK_FAIL_ONCE=1
    if txn_apply; then fail 'falha parcial ignorada'; fi
    [[ $MOCK_FIRST == Roboto && $MOCK_SECOND == original ]]
    txn_abort
    [[ $(cat "$JUNO_HOME/.bashrc") == 'old rc' && $MOCK_FIRST == null && $MOCK_SECOND == original ]]
    expect_absent "$JUNO_STATE/pending.tsv"
}

test_concurrent_setting_preserved() {
    fixture
    txn_prepare; txn_backup; txn_apply
    MOCK_FIRST=concurrent
    if txn_recover; then fail 'edição concorrente ignorada'; fi
    [[ $MOCK_FIRST == concurrent && $(cat "$JUNO_HOME/.bashrc") == 'new rc' && -f $JUNO_STATE/pending.tsv ]]
    MOCK_FIRST=Roboto
    txn_recover
    expect_absent "$JUNO_HOME/.bashrc"
}

test_settings_changed_before_apply() {
    fixture
    txn_prepare; txn_backup
    MOCK_SECOND=concurrent
    if txn_apply; then fail 'preferência modificada após backup ignorada'; fi
    expect_absent "$JUNO_HOME/.bashrc"
    expect_absent "$JUNO_STATE/pending.tsv"
    [[ $MOCK_SECOND == concurrent ]]
    txn_cleanup_stage
}

test_merge_input_changed_before_backup() {
    fixture
    printf 'old rc\n' > "$JUNO_HOME/.bashrc"
    txn_prepare
    [[ $(cat "$(txn_stage_input_for .bashrc)") == 'old rc' ]]
    printf '# concurrent\n' >> "$JUNO_HOME/.bashrc"
    if txn_backup; then fail 'edição durante a preparação ignorada'; fi
    grep -q '# concurrent' "$JUNO_HOME/.bashrc"
    expect_absent "$JUNO_STATE/pending.tsv"
    [[ $MOCK_FIRST == null && $MOCK_SECOND == original ]]
    txn_cleanup_stage
}

test_truncated_journal() {
    fixture
    txn_prepare; txn_backup; txn_apply
    cp "$JUNO_STATE/pending.tsv" "$CASE_ROOT/complete.tsv"
    awk '!($1 == "target" && $2 == ".bashrc")' "$CASE_ROOT/complete.tsv" > "$JUNO_STATE/pending.tsv"
    if txn_recover; then fail 'registro truncado aceito'; fi
    [[ -f $JUNO_HOME/.bashrc && -f $JUNO_STATE/pending.tsv && $MOCK_FIRST == Roboto ]]
    cp "$CASE_ROOT/complete.tsv" "$JUNO_STATE/pending.tsv"
    txn_recover
}

test_missing_backend_preserves_journal() {
    fixture
    txn_prepare; txn_backup; txn_apply
    MOCK_UNAVAILABLE=1
    if txn_recover; then fail 'backend indisponível ignorado'; fi
    [[ -f $JUNO_STATE/pending.tsv && $(cat "$JUNO_HOME/.bashrc") == 'new rc' ]]
    MOCK_UNAVAILABLE=0
    txn_recover
}

test_legacy_restore_independent_targets() {
    fixture
    JUNO_GSETTINGS_ENABLED=0
    JUNO_TARGETS=(.config/hypr)
    JUNO_SOURCES=("$CASE_ROOT/source/gnome")
    mkdir -p "$JUNO_HOME/.config/hypr"
    printf 'legacy original\n' > "$JUNO_HOME/.config/hypr/value"
    txn_prepare; txn_backup; txn_apply; txn_finalize
    local legacy=$JUNO_BACKUP_ID
    JUNO_TARGETS=(.bashrc .config/juno-gnome)
    JUNO_GSETTINGS_ENABLED=1
    MOCK_FIRST=custom
    txn_restore "$legacy"
    [[ $(cat "$JUNO_HOME/.config/hypr/value") == 'legacy original' && $MOCK_FIRST == custom ]]
    [[ $JUNO_GSETTINGS_ENABLED == 0 ]]
    txn_finalize
}

passed=0
for scenario in test_new_and_idempotent test_restore_values_and_absence test_partial_settings_failure \
    test_concurrent_setting_preserved test_settings_changed_before_apply test_merge_input_changed_before_backup test_truncated_journal \
    test_missing_backend_preserves_journal test_legacy_restore_independent_targets; do
    printf 'Teste GNOME/transação: %s\n' "$scenario"
    "$scenario"
    passed=$((passed + 1))
done
printf '%s cenários de transação GNOME passaram; backend, flock e sync simulados.\n' "$passed"
