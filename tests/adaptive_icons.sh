#!/usr/bin/env bash
# Real file transactions; only external icon decoding/locking are simulated.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=../lib/transaction.sh
source "$ROOT/lib/transaction.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
mkdir "$TEST_ROOT/bin"
if [[ $(uname -s) != Linux ]]; then
    printf '#!/usr/bin/env bash\nexit 0\n' > "$TEST_ROOT/bin/flock"
    cp "$TEST_ROOT/bin/flock" "$TEST_ROOT/bin/sync"
fi
printf '#!/usr/bin/env bash\nprintf "\\047Juno-Auto\\047\\n"\n' > "$TEST_ROOT/bin/gsettings"
chmod +x "$TEST_ROOT/bin/"*
export PATH="$TEST_ROOT/bin:$PATH"
mkdir -p "$TEST_ROOT/home/.local/share/applications" "$TEST_ROOT/system"
JUNO_HOME=$(realpath -e "$TEST_ROOT/home")
JUNO_STATE="$JUNO_HOME/.local/state/juno-desktop"
JUNO_TARGETS=(.local/share/applications .local/share/icons/Juno-Auto)
JUNO_SOURCES=("$ROOT/config/juno-gnome/templates/empty" "$ROOT/config/juno-gnome/templates/empty")
printf '[Desktop Entry]\nType=Application\nName=User\nExec=false\nIcon=user\n' > "$JUNO_HOME/.local/share/applications/user.desktop"
printf '[Desktop Entry]\nType=Application\nName=System\nExec=false\nIcon=/opt/app/logo.png\n' > "$TEST_ROOT/system/system.desktop"
cp "$JUNO_HOME/.local/share/applications/user.desktop" "$TEST_ROOT/original"
txn_lock
stage_icons() {
    txn_prepare
    python3 - "$ROOT" "$JUNO_HOME" "$(txn_stage_input_for .local/share/applications)" \
        "$(txn_stage_for .local/share/applications)" "$(txn_stage_for .local/share/icons/Juno-Auto)" "$TEST_ROOT/system" <<'PY'
import importlib.util
from pathlib import Path
import sys
root, home, original, output, theme, system = map(Path, sys.argv[1:])
spec = importlib.util.spec_from_file_location('icons', root / 'config/juno-gnome/lib/icon_theme.py')
icons = importlib.util.module_from_spec(spec)
spec.loader.exec_module(icons)
class Renderer:
    def render(self, icon, identity):
        return icons.stylize(bytes((240, 230, 200, 255)) * 16, 4, 4, identity)
icons.build(home, original, output, theme, Renderer(), [home / '.local/share/applications', system])
PY
}
stage_icons
txn_backup
original_backup=$JUNO_BACKUP_ID
txn_apply
txn_finalize
grep -q '^Icon=.*Juno-Auto' "$JUNO_HOME/.local/share/applications/user.desktop"
[[ -f $JUNO_HOME/.local/share/applications/system.desktop ]]
stage_icons
if txn_changed; then exit 1; else [[ $? == 1 ]]; fi
txn_cleanup_stage
[[ $(txn_list_backups | wc -l) == 1 ]]
stage_icons
printf '# concurrent edit\n' >> "$JUNO_HOME/.local/share/applications/user.desktop"
if txn_backup > "$TEST_ROOT/concurrent.log" 2>&1; then exit 1; fi
grep -q 'mudou durante' "$TEST_ROOT/concurrent.log"
txn_cleanup_stage
txn_restore "$original_backup"
txn_finalize
cmp "$TEST_ROOT/original" "$JUNO_HOME/.local/share/applications/user.desktop"
[[ ! -e $JUNO_HOME/.local/share/applications/system.desktop && ! -e $JUNO_HOME/.local/share/icons/Juno-Auto ]]
# Refresh must not recover a preexisting installer journal from a GUI session.
mkdir -p "$JUNO_HOME/.config/juno-gnome/lib"
cp "$ROOT/lib/common.sh" "$JUNO_HOME/.config/juno-gnome/lib/icons_common.sh"
cp "$ROOT/lib/transaction.sh" "$JUNO_HOME/.config/juno-gnome/lib/icons_transaction.sh"
printf 'juno-pending\t2\tKEEP\n' > "$JUNO_STATE/pending.tsv"
cp "$JUNO_STATE/pending.tsv" "$TEST_ROOT/pending"
flock -u "$JUNO_LOCK_FD"
exec {JUNO_LOCK_FD}>&-
if HOME="$JUNO_HOME" bash "$ROOT/config/juno-gnome/lib/icons_runtime.sh" > "$TEST_ROOT/runtime.log" 2>&1; then exit 1; fi
cmp "$TEST_ROOT/pending" "$JUNO_STATE/pending.tsv"
grep -q 'Transação pendente' "$TEST_ROOT/runtime.log"
# Exercise the actual installer staging, including installed runtime libraries
# and Desktop Exec escaping, replacing only the unavailable GI image decoder.
cat > "$TEST_ROOT/render-fixture.py" <<'PY'
import importlib.util
import os
from pathlib import Path
import sys
root = Path(os.environ['TEST_ICON_ROOT'])
spec = importlib.util.spec_from_file_location('icons', root / 'config/juno-gnome/lib/icon_theme.py')
icons = importlib.util.module_from_spec(spec)
spec.loader.exec_module(icons)
class Renderer:
    def __init__(self, *args):
        pass
    def render(self, icon, identity):
        return icons.stylize(bytes((240, 230, 200, 255)) * 16, 4, 4, identity)
icons.Renderer = Renderer
sys.exit(icons.main())
PY
# shellcheck source=../lib/icons.sh
source "$ROOT/lib/icons.sh"
export TEST_ICON_ROOT=$ROOT
# shellcheck disable=SC2329
python3() {
    local first=${1:-} argument
    local -a arguments=()
    for argument in "$@"; do
        if [[ $(uname -s) != Linux && $argument == /* && -d $(dirname -- "$argument") ]]; then
            argument=$(cygpath -m -- "$argument")
        fi
        arguments+=("$argument")
    done
    if [[ $first == "$ROOT/config/juno-gnome/lib/icon_theme.py" ]]; then
        command python3 "$TEST_ROOT/render-fixture.py" "${arguments[@]:1}"
    else
        command python3 "${arguments[@]}"
    fi
}
mkdir "$TEST_ROOT/home O'Neil % cash\$"
JUNO_HOME=$(realpath -e "$TEST_ROOT/home O'Neil % cash\$")
JUNO_STATE="$JUNO_HOME/.local/state/juno-desktop"
# shellcheck disable=SC2034
JUNO_ROOT=$ROOT
JUNO_TARGETS=(.config/juno-gnome .local/share/icons/Juno .local/share/applications .local/share/icons/Juno-Auto .config/autostart/juno-icons.desktop)
JUNO_SOURCES=("$ROOT/config/juno-gnome" "$ROOT/assets/icons/Juno" "$ROOT/config/juno-gnome/templates/empty" "$ROOT/config/juno-gnome/templates/empty" "$ROOT/config/juno-gnome/templates/icons-autostart.desktop")
txn_lock
txn_prepare
juno_stage_icons
config_stage=$(txn_stage_for .config/juno-gnome)
cmp "$ROOT/lib/transaction.sh" "$config_stage/lib/icons_transaction.sh"
cmp "$ROOT/lib/common.sh" "$config_stage/lib/icons_common.sh"
grep -Fq '%%' "$(txn_stage_for .config/autostart/juno-icons.desktop)"
grep -Fq 'cash' "$(txn_stage_for .config/autostart/juno-icons.desktop)"
bash -n "$config_stage/bin/juno-icons"
txn_cleanup_stage
printf 'Ícones: aplicação, reinstalação, concorrência, rollback e preservação do diário passaram.\n'
