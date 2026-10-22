#!/usr/bin/env bash
# Launcher shadows and adaptive theme share the installer's file transaction.
juno_stage_icons() {
    local apps theme input config autostart
    apps=$(txn_stage_for '.local/share/applications') || return 1
    theme=$(txn_stage_for '.local/share/icons/Juno-Auto') || return 1
    input=$(txn_stage_input_for '.local/share/applications') || return 1
    python3 "$JUNO_ROOT/config/juno-gnome/lib/icon_theme.py" build --home "$JUNO_HOME" \
        --input "$input" --apps-output "$apps" --theme-output "$theme" \
        --base "$(txn_stage_for '.local/share/icons/Juno')" || return 1
    config=$(txn_stage_for '.config/juno-gnome') || return 1
    cp -- "$JUNO_ROOT/lib/common.sh" "$config/lib/icons_common.sh" || return 1
    cp -- "$JUNO_ROOT/lib/transaction.sh" "$config/lib/icons_transaction.sh" || return 1
    chmod +x -- "$config/bin/juno-icons" || return 1
    autostart=$(txn_stage_for '.config/autostart/juno-icons.desktop') || return 1
    python3 - "$autostart" "$JUNO_HOME" <<'PY'
from pathlib import Path
import sys
path, home = Path(sys.argv[1]), sys.argv[2]
# Desktop Exec escaping, followed by quote escaping; percent is field syntax.
command = home + '/.config/juno-gnome/lib/icon_theme.py'
command = command.replace('\\', '\\\\').replace('"', '\\"').replace('`', '\\`').replace('$', '\\$').replace('%', '%%')
path.write_text(path.read_text(encoding='utf-8').replace('Exec=/usr/bin/python3 .config/juno-gnome/lib/icon_theme.py watch', 'Exec=/usr/bin/python3 "' + command.replace('\\', '\\\\') + '" watch'), encoding='utf-8')
PY
}
