#!/usr/bin/env bash
set -eEuo pipefail
JUNO_HOME=$(realpath -e -- "$HOME")
JUNO_STATE="$JUNO_HOME/.local/state/juno-desktop"
runtime_lib="$JUNO_HOME/.config/juno-gnome/lib"
# shellcheck source=/dev/null
source "$runtime_lib/icons_common.sh"
# shellcheck source=/dev/null
source "$runtime_lib/icons_transaction.sh"
# Respect a theme chosen later by the user, including rollback to older scopes.
[[ $(gsettings get org.gnome.desktop.interface icon-theme) == "'Juno-Auto'" ]] || exit 0
# These arrays are consumed by the sourced transaction module.
# shellcheck disable=SC2034
JUNO_TARGETS=(.local/share/applications .local/share/icons/Juno-Auto)
# shellcheck disable=SC2034
JUNO_SOURCES=("$JUNO_HOME/.config/juno-gnome/templates/empty" "$JUNO_HOME/.config/juno-gnome/templates/empty")
txn_lock
# A graphical helper must never recover an installer journal with GNOME keys.
# Check before installing cleanup traps, which only own this refresh operation.
[[ ! -e $JUNO_STATE/pending.tsv && ! -L $JUNO_STATE/pending.tsv ]] || {
    juno_warn 'Transação pendente: execute novamente o instalador no TTY antes de atualizar ícones.'
    exit 1
}
icons_failed() {
    local result=$1
    trap - ERR INT TERM EXIT
    if txn_abort; then txn_cleanup_stage; fi
    exit "$result"
}
trap 'icons_failed "$?"' ERR
trap 'exit 130' INT
trap 'exit 143' TERM
icons_exit() {
    local result=$?
    [[ $result == 0 ]] || icons_failed "$result"
}
trap icons_exit EXIT
txn_prepare
python3 "$runtime_lib/icon_theme.py" build --home "$JUNO_HOME" \
    --input "$(txn_stage_input_for '.local/share/applications')" \
    --apps-output "$(txn_stage_for '.local/share/applications')" \
    --theme-output "$(txn_stage_for '.local/share/icons/Juno-Auto')" \
    --base "$JUNO_HOME/.local/share/icons/Juno"
if txn_changed; then
    txn_backup
    txn_apply
    txn_finalize
    # Absolute launcher icon paths need no mutable icon cache. Creating one
    # outside the transaction would make the next comparison spuriously differ.
else
    result=$?
    (( result == 1 )) || exit "$result"
    txn_cleanup_stage
fi
