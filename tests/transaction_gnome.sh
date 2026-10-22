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

# The tab-separated mock values stand in for validated GVariant snapshots;
# the helper's real JSON/schema validation has separate Python tests.
juno_gsettings_snapshot() {
    local first second icons animations
    MOCK_SNAPSHOT_SCOPED=0
    if [[ $# == 2 ]]; then
        MOCK_SNAPSHOT_SCOPED=1
        IFS=$'\t' read -r first second icons animations < "$2"
        if [[ -z $icons ]]; then
            printf '%s\t%s\n' "$MOCK_FIRST" "$MOCK_SECOND" > "$1"
            return 0
        fi
        if [[ -z $animations ]]; then
            printf '%s\t%s\t%s\n' "$MOCK_FIRST" "$MOCK_SECOND" "$MOCK_ICONS" > "$1"
            return 0
        fi
    elif [[ $MOCK_PERFORMANCE == 0 ]]; then
        printf '%s\t%s\t%s\n' "$MOCK_FIRST" "$MOCK_SECOND" "$MOCK_ICONS" > "$1"
        return 0
    fi
    printf '%s\t%s\t%s\t%s\n' "$MOCK_FIRST" "$MOCK_SECOND" "$MOCK_ICONS" "$MOCK_ANIMATIONS" > "$1"
}
juno_gsettings_desired() {
    if [[ $MOCK_PERFORMANCE == 1 ]]; then printf 'Roboto\tGhibli\tJuno\ttrue\n' > "$1";
    else printf 'Roboto\tGhibli\tJuno\n' > "$1"; fi
}
juno_gsettings_validate() { [[ -f $1 ]]; }
juno_gsettings_verify() {
    local first second icons animations
    [[ ${MOCK_UNAVAILABLE:-0} == 0 ]] || return 2
    IFS=$'\t' read -r first second icons animations < "$1"
    [[ $MOCK_FIRST == "$first" && $MOCK_SECOND == "$second" && ( -z $icons || $MOCK_ICONS == "$icons" ) &&
       ( -z $animations || $MOCK_ANIMATIONS == "$animations" ) ]]
}
juno_gsettings_restore() {
    local first second icons animations
    [[ ${MOCK_UNAVAILABLE:-0} == 0 ]] || return 2
    IFS=$'\t' read -r first second icons animations < "$1"
    MOCK_FIRST=$first
    if [[ $MOCK_FAIL_ONCE == 1 ]]; then MOCK_FAIL_ONCE=0; return 1; fi
    MOCK_SECOND=$second
    [[ -z $icons ]] || MOCK_ICONS=$icons
    [[ -z $animations ]] || MOCK_ANIMATIONS=$animations
    return 0
}
juno_gsettings_recovery_check() {
    local before_first before_second before_icons before_animations desired_first desired_second desired_icons desired_animations
    [[ ${MOCK_UNAVAILABLE:-0} == 0 ]] || return 2
    IFS=$'\t' read -r before_first before_second before_icons before_animations < "$1"
    IFS=$'\t' read -r desired_first desired_second desired_icons desired_animations < "$2"
    [[ ( -z $before_icons && -z $desired_icons ) || ( -n $before_icons && -n $desired_icons ) ]] || return 2
    [[ ( -z $before_animations && -z $desired_animations ) || ( -n $before_animations && -n $desired_animations ) ]] || return 2
    [[ ( $MOCK_FIRST == "$before_first" || $MOCK_FIRST == "$desired_first" ) &&
       ( $MOCK_SECOND == "$before_second" || $MOCK_SECOND == "$desired_second" ) &&
       ( -z $before_icons || $MOCK_ICONS == "$before_icons" || $MOCK_ICONS == "$desired_icons" ) &&
       ( -z $before_animations || $MOCK_ANIMATIONS == "$before_animations" || $MOCK_ANIMATIONS == "$desired_animations" ) ]]
}

fixture() {
    CASE_ROOT=$(mktemp -d "$TEST_ROOT/case.XXXXXXXX")
    mkdir "$CASE_ROOT/home with spaces" "$CASE_ROOT/source"
    JUNO_HOME=$(realpath -e "$CASE_ROOT/home with spaces")
    JUNO_STATE="$JUNO_HOME/.local/state/juno-desktop"
    JUNO_TARGETS=(.bashrc .config/juno-gnome .local/share/icons/Juno)
    JUNO_SOURCES=("$CASE_ROOT/source/bashrc" "$CASE_ROOT/source/gnome" "$CASE_ROOT/source/icons")
    printf 'new rc\n' > "${JUNO_SOURCES[0]}"
    mkdir "${JUNO_SOURCES[1]}"
    printf 'new config\n' > "${JUNO_SOURCES[1]}/value"
    mkdir "${JUNO_SOURCES[2]}"
    printf 'new icons\n' > "${JUNO_SOURCES[2]}/index.theme"
    MOCK_FIRST=null; MOCK_SECOND=original; MOCK_ICONS=Previous; MOCK_SNAPSHOT_SCOPED=0; MOCK_FAIL_ONCE=0; MOCK_UNAVAILABLE=0
    MOCK_PERFORMANCE=0; MOCK_ANIMATIONS=null
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
    [[ $(cat "$JUNO_HOME/.bashrc") == 'new rc' && $MOCK_FIRST == Roboto && $MOCK_SECOND == Ghibli && $MOCK_ICONS == Juno ]]
    [[ $(cat "$JUNO_HOME/.local/share/icons/Juno/index.theme") == 'new icons' ]]
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
    MOCK_FIRST=custom; MOCK_SECOND=photo; MOCK_ICONS=Edited
    txn_restore "$initial"
    local saved_edits=$JUNO_BACKUP_ID
    [[ $MOCK_FIRST == null && $MOCK_SECOND == original && $MOCK_ICONS == Previous && $MOCK_SNAPSHOT_SCOPED == 1 ]]
    expect_absent "$JUNO_HOME/.bashrc"
    expect_absent "$JUNO_HOME/.config/juno-gnome"
    expect_absent "$JUNO_HOME/.local/share/icons/Juno"
    txn_finalize
    txn_restore "$saved_edits"
    [[ $(cat "$JUNO_HOME/.bashrc") == 'edited rc' && $MOCK_FIRST == custom && $MOCK_SECOND == photo && $MOCK_ICONS == Edited ]]
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

prepare_legacy_v2_backup() {
    local -a current_targets=("${JUNO_TARGETS[@]}") current_sources=("${JUNO_SOURCES[@]}")
    JUNO_TARGETS=(.bashrc .config/juno-gnome)
    JUNO_SOURCES=("${current_sources[0]}" "${current_sources[1]}")
    txn_prepare
    # The pre-icons GNOME version managed two mock values and two file targets.
    printf 'null\toriginal\n' > "$JUNO_SETTINGS_STAGE/before.json"
    printf 'Roboto\tGhibli\n' > "$JUNO_SETTINGS_STAGE/desired.json"
    txn_backup; txn_apply; txn_finalize
    LEGACY_BACKUP=$JUNO_BACKUP_ID
    JUNO_TARGETS=("${current_targets[@]}")
    JUNO_SOURCES=("${current_sources[@]}")
    printf 'edited rc\n' > "$JUNO_HOME/.bashrc"
    mkdir -p "$JUNO_HOME/.local/share/icons/Juno"
    printf 'user icons\n' > "$JUNO_HOME/.local/share/icons/Juno/index.theme"
    MOCK_FIRST=custom; MOCK_SECOND=photo; MOCK_ICONS=Keep
}

test_old_v2_restore_preserves_new_icons() {
    fixture
    prepare_legacy_v2_backup
    MOCK_PERFORMANCE=1; MOCK_ANIMATIONS=true
    txn_restore "$LEGACY_BACKUP"
    [[ $MOCK_SNAPSHOT_SCOPED == 1 && $MOCK_FIRST == null && $MOCK_SECOND == original && $MOCK_ICONS == Keep ]]
    [[ $(cat "$JUNO_HOME/.local/share/icons/Juno/index.theme") == 'user icons' ]]
    [[ ${#JUNO_TARGETS[@]} == 2 ]]
    [[ $MOCK_ANIMATIONS == true ]]
    txn_finalize
}

test_old_v2_restore_interruption_preserves_new_icons() {
    fixture
    prepare_legacy_v2_backup
    MOCK_PERFORMANCE=1; MOCK_ANIMATIONS=true
    txn_restore "$LEGACY_BACKUP"
    MOCK_ICONS=Concurrent
    MOCK_ANIMATIONS=false
    txn_recover
    [[ $MOCK_FIRST == custom && $MOCK_SECOND == photo && $MOCK_ICONS == Concurrent ]]
    [[ $(cat "$JUNO_HOME/.bashrc") == 'edited rc' ]]
    [[ $(cat "$JUNO_HOME/.local/share/icons/Juno/index.theme") == 'user icons' ]]
    [[ $MOCK_ANIMATIONS == false ]]
    expect_absent "$JUNO_STATE/pending.tsv"
}

test_new_icon_preference_concurrent_edit_preserved() {
    fixture
    txn_prepare; txn_backup; txn_apply
    MOCK_ICONS=Concurrent
    if txn_recover; then fail 'edição concorrente de ícones ignorada'; fi
    [[ $MOCK_ICONS == Concurrent && -f $JUNO_STATE/pending.tsv ]]
    MOCK_ICONS=Juno
    txn_recover
    [[ $MOCK_ICONS == Previous ]]
    expect_absent "$JUNO_HOME/.local/share/icons/Juno"
}

test_performance_restore_and_reinstall() {
    local previous initial replacement
    for previous in null true false; do
        fixture
        MOCK_PERFORMANCE=1; MOCK_ANIMATIONS=$previous
        txn_prepare; txn_backup; txn_apply; txn_finalize
        initial=$JUNO_BACKUP_ID
        [[ $MOCK_ANIMATIONS == true ]]
        txn_prepare
        if txn_changed; then fail 'perfil de desempenho idêntico gerou alterações'; else [[ $? == 1 ]]; fi
        txn_cleanup_stage
        txn_restore "$initial"
        replacement=$JUNO_BACKUP_ID
        [[ $MOCK_ANIMATIONS == "$previous" ]]
        txn_finalize
        txn_restore "$replacement"; txn_finalize
        [[ $MOCK_ANIMATIONS == true ]]
    done
}

test_old_seven_key_restore_and_interruption_preserve_animations() {
    fixture
    txn_prepare; txn_backup; txn_apply; txn_finalize
    local old=$JUNO_BACKUP_ID
    MOCK_PERFORMANCE=1; MOCK_ANIMATIONS=true
    txn_restore "$old"
    [[ $MOCK_ANIMATIONS == true && $MOCK_SNAPSHOT_SCOPED == 1 ]]
    MOCK_ANIMATIONS=false
    txn_recover
    [[ $MOCK_ANIMATIONS == false && $MOCK_ICONS == Juno ]]
    expect_absent "$JUNO_STATE/pending.tsv"
}

test_performance_concurrent_animation_preserved() {
    fixture
    MOCK_PERFORMANCE=1
    txn_prepare; txn_backup; txn_apply
    MOCK_ANIMATIONS=false
    if txn_recover; then fail 'edição concorrente das animações ignorada'; fi
    [[ $MOCK_ANIMATIONS == false && -f $JUNO_STATE/pending.tsv && -f $JUNO_HOME/.bashrc ]]
    MOCK_ANIMATIONS=true
    txn_recover
    [[ $MOCK_ANIMATIONS == null ]]
    expect_absent "$JUNO_STATE/pending.tsv"
    expect_absent "$JUNO_HOME/.bashrc"
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
    test_missing_backend_preserves_journal test_old_v2_restore_preserves_new_icons \
    test_old_v2_restore_interruption_preserves_new_icons test_new_icon_preference_concurrent_edit_preserved \
    test_performance_restore_and_reinstall test_old_seven_key_restore_and_interruption_preserve_animations \
    test_performance_concurrent_animation_preserved \
    test_legacy_restore_independent_targets; do
    printf 'Teste GNOME/transação: %s\n' "$scenario"
    "$scenario"
    passed=$((passed + 1))
done
printf '%s cenários de transação GNOME passaram; backend, flock e sync simulados.\n' "$passed"
