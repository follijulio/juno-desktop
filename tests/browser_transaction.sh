#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
source "$ROOT/lib/common.sh"
source "$ROOT/lib/transaction.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
if [[ $(uname -s) != Linux ]]; then
    mkdir "$TEST_ROOT/mock-bin"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$TEST_ROOT/mock-bin/flock"
    cp "$TEST_ROOT/mock-bin/flock" "$TEST_ROOT/mock-bin/sync"
    chmod +x "$TEST_ROOT/mock-bin/"*
    export PATH="$TEST_ROOT/mock-bin:$PATH"
fi
mkdir -p "$TEST_ROOT/home/.config"
JUNO_HOME=$(realpath -e "$TEST_ROOT/home")
JUNO_STATE="$JUNO_HOME/.local/state/juno-desktop"
JUNO_TARGETS=(.config/mimeapps.list)
JUNO_SOURCES=("$ROOT/config/juno-gnome/templates/mimeapps.list")
printf '# custom\n[Default Applications]\nx-scheme-handler/https=brave-browser.desktop;\nimage/png=viewer.desktop;\n' > "$JUNO_HOME/.config/mimeapps.list"
cp "$JUNO_HOME/.config/mimeapps.list" "$TEST_ROOT/original"
txn_lock
stage_browser() {
    txn_prepare
    python3 "$ROOT/tools/stage_mimeapps.py" "$(txn_stage_input_for .config/mimeapps.list)" \
        "$(txn_stage_for .config/mimeapps.list)" org.mozilla.firefox.desktop
}
stage_browser
txn_backup
original_backup=$JUNO_BACKUP_ID
txn_apply
txn_finalize
grep -q '^image/png=viewer.desktop;$' "$JUNO_HOME/.config/mimeapps.list"
grep -q '^x-scheme-handler/https=org.mozilla.firefox.desktop;$' "$JUNO_HOME/.config/mimeapps.list"
stage_browser
if txn_changed; then exit 1; else [[ $? == 1 ]]; fi
txn_cleanup_stage
[[ $(txn_list_backups | wc -l) == 1 ]]
printf '# later edit\n' >> "$JUNO_HOME/.config/mimeapps.list"
cp "$JUNO_HOME/.config/mimeapps.list" "$TEST_ROOT/edited"
txn_restore "$original_backup"
edited_backup=$JUNO_BACKUP_ID
txn_finalize
cmp "$TEST_ROOT/original" "$JUNO_HOME/.config/mimeapps.list"
txn_restore "$edited_backup"
txn_finalize
cmp "$TEST_ROOT/edited" "$JUNO_HOME/.config/mimeapps.list"
printf 'Navegador: merge transacional, reinstalação sem backup duplicado e rollback com preservação das edições passaram.\n'
